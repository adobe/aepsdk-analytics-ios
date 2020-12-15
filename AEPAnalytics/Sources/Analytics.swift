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
    private var analyticsState: AnalyticsState
    private let analyticsHardDependencies: [String] = [AnalyticsConstants.Configuration.EventDataKeys.SHARED_STATE_NAME, AnalyticsConstants.Identity.EventDataKeys.SHARED_STATE_NAME]
    // MARK: Extension

    public required init(runtime: ExtensionRuntime) {
        self.runtime = runtime
        self.analyticsState = AnalyticsState()
        super.init()
    }

    // internal init added for tests
    #if DEBUG
        internal init(runtime: ExtensionRuntime, state: AnalyticsState) {
            self.runtime = runtime
            self.analyticsState = state
            super.init()
        }
    #endif

    public func onRegistered() {
        registerListener(type: EventType.genericTrack, source: EventSource.requestContent, listener: handleAnalyticsRequest)
//        registerListener(type: EventType.rulesEngine, source: EventSource.responseContent, listener: handleAnalyticsRequest)
//        registerListener(type: EventType.analytics, source: EventSource.requestContent, listener: handleAnalyticsRequest)
//        registerListener(type: EventType.analytics, source: EventSource.requestIdentity, listener: handleAnalyticsRequest)
        registerListener(type: EventType.configuration, source: EventSource.responseContent, listener: handleConfigurationResponse)
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
     Tries to retrieve the shared data for all the dependencies of the given event. When all the dependencies are resolved, it will update the `AnalyticsState` with the shared states.
     - Parameters:
          - event: The `Event` for which shared state is to be retrieved.
          - dependencies: An array of names of event's dependencies.
     - Returns: The `AnalyticsState` instance which contains the shared state of all dependecies.
     */
    func updateAnalyticsState(forEvent event: Event, dependencies: [String]) {
        var sharedStates = [String: [String: Any]?]()
        for extensionName in dependencies {
            sharedStates[extensionName] = runtime.getSharedState(extensionName: extensionName, event: event, barrier: true)?.value
        }
        analyticsState.update(dataMap: sharedStates)
    }
}

/// Event Listeners_object    Builtin.BridgeObject    0x8000000126eca620
extension Analytics {

    /// Processes Configuration Response content events to retrieve the configuration data and privacy status settings.
    /// - Parameter:
    ///   - event: The configuration response event
    private func handleConfigurationResponse(event: Event) {
        Log.debug(label: LOG_TAG, "Received Configuration Response event, attempting to retrieve configuration settings.")
        updateAnalyticsState(forEvent: event, dependencies: analyticsHardDependencies)
    }

    /// Listener for handling Analytics `Events`.
    /// - Parameter event: The instance of `Event` that needs to be processed.
    private func handleAnalyticsRequest(event: Event) {
        switch event.type {
        case EventType.lifecycle:
            analyticsProperties.dispatchQueue.async {
                self.handleLifecycleEvents(event)
            }
        case EventType.acquisition:
            analyticsProperties.dispatchQueue.async {
                self.handleAcquisitionEvent(event)
            }
        default:
            break
        }
    }

    ///  Handles the following events
    /// `EventType.genericLifecycle` and `EventSource.requestContent`
    /// `EventType.lifecycle` and `EventSource.responseContent`
    ///  - Parameter event: the `Event` to be processed
    private func handleLifecycleEvents(_ event: Event) {
        if analyticsState.areHardDependenciesReady() == false {
            Log.debug(label: LOG_TAG, "Analytics State is not ready, ignoring the lifecycle event.")
            return
        }

        if event.type == EventType.genericLifecycle && event.source == EventSource.requestContent {

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
            let softDependencies: [String] = [AnalyticsConstants.Lifecycle.EventDataKeys.SHARED_STATE_NAME, AnalyticsConstants.Assurance.EventDataKeys.SHARED_STATE_NAME,
                                              AnalyticsConstants.Places.EventDataKeys.SHARED_STATE_NAME]

            analyticsProperties.lifecyclePreviousSessionPauseTimestamp = event.data?[AnalyticsConstants.Lifecycle.EventDataKeys.PREVIOUS_SESSION_PAUSE_TIMESTAMP] as? Date
            updateAnalyticsState(forEvent: event, dependencies: analyticsHardDependencies + softDependencies)
            trackLifecycle(analyticsState: analyticsState, event: event, analyticsProperties: &analyticsProperties)
        }
    }

    /// Handles the following events
    /// `EventType.acquisition` and `EventSource.responseContent`
    /// - Parameter event: The `Event` to be processed.
    private func handleAcquisitionEvent(_ event: Event) {
        if analyticsState.areHardDependenciesReady() == false {
            Log.debug(label: LOG_TAG, "Analytics State is not ready, ignoring the acquisiton event.")
            return
        }

        if analyticsProperties.referrerTimerRunning {
            Log.debug(label: LOG_TAG, "handleAcquisitionResponseEvent - Acquisition response received with referrer data.")
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
            if event.type == EventType.acquisition && event.source == EventSource.responseContent {
                let softDependencies: [String] = [
                    AnalyticsConstants.Lifecycle.EventDataKeys.SHARED_STATE_NAME,
                    AnalyticsConstants.Assurance.EventDataKeys.SHARED_STATE_NAME]
                updateAnalyticsState(forEvent: event, dependencies: analyticsHardDependencies + softDependencies)
                trackAcquisitionData(analyticsState: analyticsState, event: event, analyticsProperties: &analyticsProperties)
            }
        }
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
