/*
 Copyright 2020 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import AEPCore
import AEPServices
import Foundation

/// Analytics extension for the Adobe Experience Platform SDK
@objc(AEPMobileAnalytics)
public class Analytics: NSObject, Extension {
    private let LOG_TAG = "Analytics"
    public let runtime: ExtensionRuntime

    public let name = AnalyticsConstants.EXTENSION_NAME
    public let friendlyName = AnalyticsConstants.FRIENDLY_NAME
    public static let extensionVersion = AnalyticsConstants.EXTENSION_VERSION
    public let metadata: [String: String]? = nil
    private var analyticsProperties = AnalyticsProperties.init()
    private let analyticsHardDependencies: [String] = [AnalyticsConstants.Configuration.EventDataKeys.SHARED_STATE_NAME, AnalyticsConstants.Identity.EventDataKeys.SHARED_STATE_NAME]
    // MARK: Extension

    public required init(runtime: ExtensionRuntime) {
        self.runtime = runtime
        super.init()
    }

    public func onRegistered() {
        registerListener(type: EventType.genericTrack, source: EventSource.requestContent, listener: handleAnalyticsRequest)
//        registerListener(type: EventType.rulesEngine, source: EventSource.responseContent, listener: handleAnalyticsRequest)
//        registerListener(type: EventType.analytics, source: EventSource.requestContent, listener: handleAnalyticsRequest)
        registerListener(type: EventType.analytics, source: EventSource.requestIdentity, listener: handleAnalyticsRequest)
//        registerListener(type: EventType.configuration, source: EventSource.responseContent, listener: handleAnalyticsRequest)
        registerListener(type: EventType.acquisition, source: EventSource.responseContent, listener: handleAnalyticsRequest)
        registerListener(type: EventType.lifecycle, source: EventSource.responseContent, listener: handleLifecycleEvents)
        registerListener(type: EventType.genericLifecycle, source: EventSource.requestContent, listener: handleAnalyticsRequest)
//        registerListener(type: EventType.hub, source: EventSource.sharedState, listener: handleAnalyticsRequest)
    }

    public func onUnregistered() {}

    public func readyForEvent(_ event: Event) -> Bool {
        return true
    }

    /**
     Tries to retrieve the shared data for all the dependencies of the given event. When all the dependencies are resolved, it will return the Dictionary with the shared states.
     - Parameters:
          - event: The `Event` for which shared state is to be retrieved.
          - dependencies: An array of names of event's dependencies.

     - Returns: A `Dictionary` with shared state of all dependecies.
     */

    func createAnalyticsState(forEvent event: Event, dependencies: [String]) -> AnalyticsState {
        var sharedStates = [String: [String: Any]?]()
        for extensionName in dependencies {
            sharedStates[extensionName] = runtime.getSharedState(extensionName: extensionName, event: event, barrier: true)?.value
        }

        return AnalyticsState.init(dataMap: sharedStates)
    }
}

/// Event Listeners_object    Builtin.BridgeObject    0x8000000126eca620
extension Analytics {

    /// Listener for handling Analytics `Events`.
    /// - Parameter event: The instance of `Event` that needs to be processed.
    private func handleAnalyticsRequest(event: Event) {
        switch event.type {
        case EventType.lifecycle:
            analyticsProperties.dispatchQueue.async {
                self.handleLifecycleEvents(event)
            }
            break
        case EventType.acquisition:
            analyticsProperties.dispatchQueue.async {
                self.handleAcquisitionEvent(event)
            }
            break
        case EventType.analytics:
            if event.source == EventSource.requestIdentity {
                analyticsProperties.dispatchQueue.async {
                    self.handleAnalyticsRequestIdentityEvent(event)
                }
            }
            break
        default:
            break
        }
    }

    ///  Handles the following events
    /// `EventType.genericLifecycle` and `EventSource.requestContent`
    /// `EventType.lifecycle` and `EventSource.responseContent`
    ///  - Parameter event: the `Event` to be processed
    private func handleLifecycleEvents(_ event: Event) {

        if event.type == EventType.genericLifecycle && event.source == EventSource.requestContent {
            let analyticsState = createAnalyticsState(forEvent: event, dependencies: analyticsHardDependencies)

            let lifecycleAction = event.data?[AnalyticsConstants.Lifecycle.EventDataKeys.LIFECYCLE_ACTION_KEY] as? String
            if lifecycleAction == AnalyticsConstants.Lifecycle.EventDataKeys.LIFECYCLE_START {
                let previousLifecycleSessionTimestamp = analyticsProperties.lifecyclePreviousPauseEventTimestamp?.timeIntervalSince1970 ?? 0
                var shouldIgnoreLifecycleStart = previousLifecycleSessionTimestamp != 0

                if shouldIgnoreLifecycleStart {
                    let timeStampDiff = event.timestamp.timeIntervalSince1970 - previousLifecycleSessionTimestamp
                    let timeout = min(analyticsState.lifecycleMaxSessionLength, AnalyticsConstants.Default.LIFECYCLE_PAUSE_START_TIMEOUT)
                    shouldIgnoreLifecycleStart = shouldIgnoreLifecycleStart && (timeStampDiff < timeout)
                }

                if analyticsProperties.lifecycleTimerRunning || shouldIgnoreLifecycleStart {
                    return
                }

                waitForLifecycleData()
                /// - TODO: Implement the code for adding a placeholder hit in db using AnalyticsHitDB.

            } else if lifecycleAction == AnalyticsConstants.Lifecycle.EventDataKeys.LIFECYCLE_PAUSE {
                analyticsProperties.lifecycleTimerRunning = false
                analyticsProperties.referrerTimerRunning = false
                analyticsProperties.lifecyclePreviousPauseEventTimestamp = event.timestamp
            }

        } else if event.type == EventType.lifecycle && event.source == EventSource.responseContent {
            //Soft dependecies list.
            var softDependencies: [String] = [AnalyticsConstants.Lifecycle.EventDataKeys.SHARED_STATE_NAME, AnalyticsConstants.Assurance.EventDataKeys.SHARED_STATE_NAME,
                                              AnalyticsConstants.Places.EventDataKeys.SHARED_STATE_NAME]

            analyticsProperties.lifecyclePreviousSessionPauseTimestamp = event.data?[AnalyticsConstants.Lifecycle.EventDataKeys.PREVIOUS_SESSION_PAUSE_TIMESTAMP] as? Date

            trackLifecycle(analyticsState: createAnalyticsState(forEvent: event, dependencies: analyticsHardDependencies + softDependencies), event: event, analyticsProperties: &analyticsProperties)
        }
    }

    /// Handles the following events
    /// `EventType.acquisition` and `EventSource.responseContent`
    /// - Parameter event: The `Event` to be processed.
    private func handleAcquisitionEvent(_ event: Event) {

        if analyticsProperties.referrerTimerRunning {
            Log.debug(label: LOG_TAG, "handleAcquisitionResponseEvent - Acquisition response received with referrer data.")
            let analyticsState = createAnalyticsState(forEvent: event, dependencies: [AnalyticsConstants.Configuration.EventDataKeys.SHARED_STATE_NAME])
            analyticsProperties.cancelReferrerTimer()

            /// - TODO: Implement the AnalyticsHitDatabase operation below.
//                        final AnalyticsHitsDatabase analyticsHitsDatabase = getHitDatabase();
//
//                        if (analyticsHitsDatabase != null) {
//                            analyticsHitsDatabase.kickWithAdditionalData(state, acquisitionEvent.getData() != null ?
//                                    acquisitionEvent.getData().optStringMap(AnalyticsConstants.EventDataKeys.Analytics.CONTEXT_DATA, null) : null);
//                        } else {
//                            Log.warning(LOG_TAG,
//                                        "handleAcquisitionResponseEvent - Unable to kick analytic hit with referrer data. Database Service is unavailable");
//                        }

        } else {
            let softDependencies: [String] = [
                AnalyticsConstants.Lifecycle.EventDataKeys.SHARED_STATE_NAME,
                AnalyticsConstants.Assurance.EventDataKeys.SHARED_STATE_NAME]
            if event.type == EventType.acquisition && event.source == EventSource.responseContent {
                trackAcquisitionData(analyticsState: createAnalyticsState(forEvent: event, dependencies: analyticsHardDependencies + softDependencies), event: event, analyticsProperties: &analyticsProperties)
            }
        }
    }

    /// Handles the following events
    /// `EventType.analytics` and `EventSource.requestIdentity`
    /// - Parameter event: The `Event` to be processed.
    private func handleAnalyticsRequestIdentityEvent(_ event: Event) {
        if let eventData = event.data ?? [:], !eventData.isEmpty {
            if let vid = eventData[AnalyticsConstants.EventDataKeys.VISITOR_IDENTIFIER] as? String, !vid.isEmpty {
                // Update VID request
                handleVisitorIdentifierRequest(event: event, vid: vid)
            } else { // AID/VID request
                handleAnalyticsIdRequest(event: event)
            }
        }
    }

    private func handleVisitorIdentifierRequest(event: Event, vid: String) {
        let analyticsState = createAnalyticsState(forEvent: event, dependencies: [AnalyticsConstants.Configuration.EventDataKeys.SHARED_STATE_NAME])
        if analyticsState.privacyStatus == .optedOut {
            Log.debug(label: LOG_TAG, "handleVisitorIdentifierRequest - Privacy is opted out, ignoring the Visitor Identifier Request.")
            return
        }

        // persist the visitor identifier
        analyticsProperties.updateAnalyticsVisitorIdentifier(vid: vid)

        // update analytics shared state
        let stateData = getStateData()
        createSharedState(data: stateData, event: event)

        // dispatch unpaired response for any extensions listening for AID/VID change
        let responseIdentityEvent = event.createResponseEvent(name: "TrackingIdentifierValue", type: EventType.analytics, source: EventSource.responseIdentity, data: stateData)
        dispatch(event: responseIdentityEvent)
    }

    private func handleAnalyticsIdRequest(event: Event) {

    }

    /// Get the data for the Analytics extension share with other extensions.
    /// The state data is only populated if the set privacy status is not `PrivacyStatus.optedOut`.
    /// - Returns: A dictionary containing the event data to store in the analytics shared state
    func getStateData() -> [String: Any] {
        var data = [String: Any]()
        if let aid = analyticsProperties.getAnalyticsIdentifier() ?? "", !aid.isEmpty {
            data[AnalyticsConstants.EventDataKeys.ANALYTICS_ID] = aid
        }

        if let vid = analyticsProperties.getVisitorIdentifier() ?? "", !vid.isEmpty {
            data[AnalyticsConstants.EventDataKeys.VISITOR_IDENTIFIER] = vid
        }

        return data
    }

}

/// Timeout timers.
extension Analytics {

    /// Wait for lifecycle data after receiving Lifecycle Request event.
    func waitForLifecycleData() {
        analyticsProperties.lifecycleTimerRunning = true
        let lifecycleWorkItem = DispatchWorkItem {
            Log.warning(label: self.LOG_TAG, "waitForLifecycleData - Lifecycle timeout has expired without Lifecycle data")
            /// - TODO: Kick the database hits.
        }
        analyticsProperties.dispatchQueue.asyncAfter(deadline: DispatchTime.now() + AnalyticsConstants.Default.LIFECYCLE_RESPONSE_WAIT_TIMEOUT, execute: lifecycleWorkItem)
        analyticsProperties.lifecycleDispatchWorkItem = lifecycleWorkItem
    }

    /// Wait for Acquisition data after receiving Lifecycle Response event.
    func waitForAcquisitionData(state: AnalyticsState, timeout: TimeInterval) {
        analyticsProperties.referrerTimerRunning = true
        let referrerDispatchWorkItem = DispatchWorkItem {
            Log.warning(label: self.LOG_TAG, "waitForAcquisitionData - Referrer timeout has expired without referrer data")
            /// - TODO: Kick the database hits.
        }
        analyticsProperties.dispatchQueue.asyncAfter(deadline: DispatchTime.now() + timeout, execute: referrerDispatchWorkItem)
        analyticsProperties.referrerDispatchWorkItem = referrerDispatchWorkItem
    }
}
