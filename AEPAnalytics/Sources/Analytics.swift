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
    private let LOG_TAG = "AnalyticsState"
    public let runtime: ExtensionRuntime

    public let name = AnalyticsConstants.EXTENSION_NAME
    public let friendlyName = AnalyticsConstants.FRIENDLY_NAME
    public static let extensionVersion = AnalyticsConstants.EXTENSION_VERSION
    public let metadata: [String: String]? = nil
    /// A flag that notifies the core sdk if the extension is ready to process next event. This is used as a return value of `readyForEvent` function.
    private var isReadyForNextEvent = true
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
//        registerListener(type: EventType.analytics, source: EventSource.requestIdentity, listener: handleAnalyticsRequest)
//        registerListener(type: EventType.configuration, source: EventSource.responseContent, listener: handleAnalyticsRequest)
        registerListener(type: EventType.acquisition, source: EventSource.responseContent, listener: handleAnalyticsRequest)
        registerListener(type: EventType.lifecycle, source: EventSource.responseContent, listener: handleLifecycleEvents)
        registerListener(type: EventType.genericLifecycle, source: EventSource.requestContent, listener: handleAnalyticsRequest)
//        registerListener(type: EventType.hub, source: EventSource.sharedState, listener: handleAnalyticsRequest)
    }

    public func onUnregistered() {}

    public func readyForEvent(_ event: Event) -> Bool {
        return isReadyForNextEvent
    }

    /**
     Tries to retrieve the shared data for all the dependencies of the given event. When all the dependencies are resolved, it will return the map with the shared states.
     - Parameters:
          - event: The `Event` for which shared state is to be retrieved.
          - dependencies: An array of names of event's dependencies.

     - Returns: A map with shared state of all dependecies.
     */

    func getSharedStateForEvent(event: Event? = nil, dependencies: [String]) -> [String: [String: Any]?] {
        var sharedStates = [String: [String: Any]?]()
        for extensionName in dependencies {
            sharedStates[extensionName] = runtime.getSharedState(extensionName: extensionName, event: event, barrier: true)?.value
        }

        return sharedStates
    }
}

/// Event Listeners
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
            let sharedStates: [String: [String: Any]?] = getSharedStateForEvent(event: event, dependencies: analyticsHardDependencies)

            let analyticsState = AnalyticsState.init(dataMap: sharedStates)
            let lifecycleAction = event.data?[AnalyticsConstants.Lifecycle.EventDataKeys.LIFECYCLE_ACTION_KEY] as? String
            if lifecycleAction == AnalyticsConstants.Lifecycle.EventDataKeys.LIFECYCLE_START {
                let previousLifecycleSessionTimestamp = analyticsProperties.lifecyclePreviousPauseEventTimestamp?.timeIntervalSince1970 ?? 0
                var shouldIgnoreStart: Bool = previousLifecycleSessionTimestamp != 0

                if shouldIgnoreStart {
                    let timeStampDiff = event.timestamp.timeIntervalSince1970 - previousLifecycleSessionTimestamp
                    let timeout = min(analyticsState.lifecycleMaxSessionLength, AnalyticsConstants.Default.LIFECYCLE_PAUSE_START_TIMEOUT)
                    shouldIgnoreStart = shouldIgnoreStart && (timeStampDiff < timeout)
                }

                if analyticsProperties.lifecycleTimerRunning || shouldIgnoreStart {
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

            let sharedStates: [String: [String: Any]?] = getSharedStateForEvent(event: event, dependencies: analyticsHardDependencies + softDependencies)

            analyticsProperties.lifecyclePreviousSessionPauseTimestamp = event.data?[AnalyticsConstants.Lifecycle.EventDataKeys.PREVIOUS_SESSION_PAUSE_TIMESTAMP] as? Date

            trackLifecycle(analyticsState: AnalyticsState(dataMap: sharedStates), event: event)
        }
    }

    /// Handles the following events
    /// `EventType.acquisition` and `EventSource.responseContent`
    /// - Parameter event: The `Event` to be processed.
    private func handleAcquisitionEvent(_ event: Event) {

        if analyticsProperties.referrerTimerRunning {
            Log.debug(label: LOG_TAG, "handleAcquisitionResponseEvent - Acquisition response received with referrer data.")
            let configSharedState = getSharedStateForEvent(event: event, dependencies: [AnalyticsConstants.Configuration.EventDataKeys.SHARED_STATE_NAME])
            let analyticsState = AnalyticsState.init(dataMap: configSharedState)
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
            let sharedStates = getSharedStateForEvent(event: event, dependencies: analyticsHardDependencies + softDependencies)
            if event.type == EventType.acquisition && event.source == EventSource.responseContent {
                trackAcquisitionData(analyticsState: AnalyticsState.init(dataMap: sharedStates), event: event)
            }
        }
    }
}

/// Track call functions.
extension Analytics {

    /// Processes the Acquisition event.
    /// If we are waiting for the acquisition data, then try to append it to a exiting hit. Otherwise, send a
    /// new hit for acquisition data, and cancel the acquisition timer to mark that the acquisition data has
    /// been received and processed.
    /// - Parameters:
    ///     - analyticsState: The `AnalyticsState` object representing shared states of other dependent
    ///      extensions
    ///     - event: The `acquisition event` to process
    func trackAcquisitionData(analyticsState: AnalyticsState, event: Event) {
        var acquisitionContextData = event.data?[AnalyticsConstants.EventDataKeys.CONTEXT_DATA] ?? [String: String]()

        if analyticsProperties.referrerTimerRunning {
            analyticsProperties.referrerTimerRunning = false

            /// - TODO: Implement the hit database as commented below.
//            final AnalyticsHitsDatabase analyticsHitsDatabase = getHitDatabase();
//
//                        if (analyticsHitsDatabase != null) {
//                            analyticsHitsDatabase.kickWithAdditionalData(state, acquisitionContextData);
//                        } else {
//                            Log.warning(LOG_TAG,
//                                        "trackAcquisition - Unable to kick analytic hit with referrer data. Database Service is unavailable");
//                        }
        } else {
            analyticsProperties.referrerTimerRunning = false
            var acquisitionEventData: [String: Any] = [:]
            acquisitionEventData[AnalyticsConstants.EventDataKeys.TRACK_ACTION] = AnalyticsConstants.TRACK_INTERNAL_ADOBE_LINK
            acquisitionEventData[AnalyticsConstants.EventDataKeys.CONTEXT_DATA] = acquisitionContextData
            acquisitionEventData[AnalyticsConstants.EventDataKeys.TRACK_INTERNAL] = true

            track(analyticsState: analyticsState, trackEventData: acquisitionEventData, timeStampInSeconds: event.timestamp.timeIntervalSince1970, appendToPlaceHolder: false, eventUniqueIdentifier: "\(event.id)")

        }
    }

    /// Track analytics requests for actions/states
    /// - Parameters:
    ///     - analyticsState: current `AnalyticsState` object containing shared state of dependencies.
    ///     - trackEventData: `EventData` object containing tracking data
    ///     - timeStampInSeconds: current event timestamp used for tracking
    ///     - appendToPlaceHolder: a boolean indicating whether the data should be appended to a placeholder
    ///      hit; the placeholder hit is currently used for backdated session hits
    ///     - eventUniqueIdentifier: the event unique identifier responsible for this track
    func track(analyticsState: AnalyticsState, trackEventData: [String: Any]?, timeStampInSeconds: TimeInterval, appendToPlaceHolder: Bool, eventUniqueIdentifier: String) {
        guard trackEventData != nil else {
            Log.debug(label: LOG_TAG, "track - Dropping the Analytics track request, request was null.")
            return
        }

        guard analyticsState.isAnalyticsConfigured() else {
            Log.debug(label: LOG_TAG, "track - Dropping the Analytics track request, Analytics is not configured.")
            return
        }

        analyticsProperties.setMostRecentHitTimestamp(timestampInSeconds: timeStampInSeconds)

        guard analyticsState.privacyStatus != .optedOut else {
            Log.debug(label: LOG_TAG, "track - Dropping the Analytics track request, privacy status is opted out.")
            return
        }

        let analyticsData: [String: String] = processAnalyticsContextData(analyticsState: analyticsState, trackEventData: trackEventData)
        let analyticsVars = processAnalyticsVars(analyticsState: analyticsState, trackData: trackEventData, timestamp: timeStampInSeconds)
        let builtRequest = analyticsProperties.analyticsRequestSerializer.buildRequest(analyticsState: analyticsState, data: analyticsData, vars: analyticsVars)

        /// - TODO: Get analytics hit database and perform following action.
//        if appendToPlaceHolder {
//                        analyticsHitsDatabase.updateBackdatedHit(state, builtRequest, timestampInSeconds, eventUniqueIdentifier);
//                    } else {
//                        analyticsHitsDatabase.queue(state, builtRequest, timestampInSeconds, analyticsProperties.isDatabaseWaiting(),
//                                                    false, eventUniqueIdentifier);
//                    }
    }
    ///Converts the lifecycle event in internal analytics action. If backdate session and offline tracking are
    /// enabled,
    ///and previous session length is present in the contextData map, we send a separate hit with the previous
    /// session
    /// information and the rest of the keys as a Lifecycle action hit.
    /// If ignored session is present, it will be sent as part of the Lifecycle hit and no SessionInfo hit will
    ///  be sent.
    /// - Parameters:
    ///     - analyticsState: shared state values
    ///     - event: the `Lifecycle Event` to process.
    private func trackLifecycle(analyticsState: AnalyticsState?, event: Event) {
        guard let analyticsState = analyticsState else {
            Log.debug(label: LOG_TAG, "trackLifecycle - Failed to track lifecycle event (invalid state)")
            return
        }

        guard var eventLifecycleContextData: [String: String] = event.data?[AnalyticsConstants.Lifecycle.EventDataKeys.LIFECYCLE_CONTEXT_DATA] as? [String: String], !eventLifecycleContextData.isEmpty else {
            Log.debug(label: LOG_TAG, "trackLifecycle - Failed to track lifecycle event (context data was null or empty)")
            return
        }

        let previousOsVersion: String? = eventLifecycleContextData.removeValue(forKey: AnalyticsConstants.Lifecycle.EventDataKeys.PREVIOUS_OS_VERSION)
        let previousAppIdVersion: String? = eventLifecycleContextData.removeValue(forKey: AnalyticsConstants.Lifecycle.EventDataKeys.PREVIOUS_APP_ID)

        var lifecycleContextData: [String: String] = [:]

        eventLifecycleContextData.forEach {
            eventDataKey, value in
            if AnalyticsConstants.MAP_EVENT_DATA_KEYS_TO_CONTEXT_DATA_KEYS.keys.contains(eventDataKey) {
                if let contextDataKey = AnalyticsConstants.MAP_EVENT_DATA_KEYS_TO_CONTEXT_DATA_KEYS[eventDataKey] {
                    lifecycleContextData[contextDataKey] = value
                }
            } else {
                lifecycleContextData[eventDataKey] = value
            }
        }

        if lifecycleContextData.keys.contains(AnalyticsConstants.ContextDataKeys.INSTALL_EVENT_KEY) {
            waitForAcquisitionData(state: analyticsState, timeout: TimeInterval.init(analyticsState.launchHitDelay))
        } else if lifecycleContextData.keys.contains(AnalyticsConstants.ContextDataKeys.LAUNCH_EVENT_KEY) {
            waitForAcquisitionData(state: analyticsState, timeout: AnalyticsConstants.Default.LAUNCH_DEEPLINK_DATA_WAIT_TIMEOUT)
        }

        if analyticsState.backDateSessionInfoEnabled && analyticsState.offlineEnabled {
            if lifecycleContextData.keys.contains(AnalyticsConstants.ContextDataKeys.CRASH_EVENT_KEY) {
                lifecycleContextData.removeValue(forKey: AnalyticsConstants.ContextDataKeys.CRASH_EVENT_KEY)
                backadateLifecycleCrash(analyticsState: analyticsState, previousOSVersion: previousOsVersion, previousAppIdVersion: previousAppIdVersion, eventUniqueIdentifier: "\(event.id)")
            }

            if lifecycleContextData.keys.contains(AnalyticsConstants.ContextDataKeys.PREVIOUS_SESSION_LENGTH) {
                let previousSessionLength: String? = lifecycleContextData.removeValue(forKey: AnalyticsConstants.ContextDataKeys.PREVIOUS_SESSION_LENGTH)
                backdateLifecycleSessionInfo(analyticsState: analyticsState, previousSessionLength: previousSessionLength, previousOSVersion: previousOsVersion, previousAppIdVersion: previousAppIdVersion, eventUniqueIdentifier: "\(event.id)")
            }
        }
    }

    /// Creates the context data map from the `EventData` map and the current `AnalyticsState`.
    /// - Parameters:
    ///     - analyticsState: The current `AnalyticsState`
    ///     - trackEventData: Map containing tracking data
    ///     - Returns a map contains the context data.
    func processAnalyticsContextData(analyticsState: AnalyticsState, trackEventData: [String: Any]?) -> [String: String] {
        var analyticsData: [String: String] = [:]
        guard let trackEventData = trackEventData else {
            Log.debug(label: LOG_TAG, "processAnalyticsContextData - trackevendata is nil.")
            return analyticsData
        }

        analyticsData.merge(analyticsState.defaultData) {
            key1, _ in
            return key1
        }
        if let contextData = trackEventData[AnalyticsConstants.EventDataKeys.CONTEXT_DATA] as? [String: String] {
            analyticsData.merge(contextData) {
                key1, _ in
                return key1
            }
        }
        if let actionName = trackEventData[AnalyticsConstants.EventDataKeys.TRACK_ACTION] as? String, !actionName.isEmpty {
            let isInternalAction = trackEventData[AnalyticsConstants.EventDataKeys.TRACK_INTERNAL] as? Bool ?? false
            let actionKey = isInternalAction ? AnalyticsConstants.ContextDataKeys.INTERNAL_ACTION_KEY : AnalyticsConstants.ContextDataKeys.ACTION_KEY
            analyticsData[actionKey] = actionName
        }
        var lifecycleSessionStartTimestamp = analyticsState.lifecycleSessionStartTimestamp
        if lifecycleSessionStartTimestamp > 0 {
            var timeSinceLaunchInSeconds = Date.init().timeIntervalSince1970 - lifecycleSessionStartTimestamp
            if timeSinceLaunchInSeconds > 0 && timeSinceLaunchInSeconds.isLessThanOrEqualTo( analyticsState.lifecycleMaxSessionLength) {
                analyticsData[AnalyticsConstants.ContextDataKeys.TIME_SINCE_LAUNCH_KEY] = "\(timeSinceLaunchInSeconds)"
            }
        }
        if analyticsState.privacyStatus == .unknown {
            analyticsData[AnalyticsConstants.ANALYTICS_REQUEST_PRIVACY_MODE_KEY] = AnalyticsConstants.ANALYTICS_REQUEST_PRIVACY_MODE_UNKNOWN
        }

        if let requestIndetifier = trackEventData[AnalyticsConstants.EventDataKeys.REQUEST_EVENT_IDENTIFIER] as? String {
            analyticsData[AnalyticsConstants.ContextDataKeys.EVENT_IDENTIFIER_KEY] = requestIndetifier
        }

        return analyticsData
    }

    /// Creates the vars map from the `EventData` map and the current `AnalyticsState`.
    /// - Parameters:
    ///     - analyticsState: The current `AnalyticsState`
    ///     - trackData: Map containing tracking data
    ///     - timestamp: timestamp to use for tracking
    ///     - Returns a map contains the vars data
    func processAnalyticsVars(analyticsState: AnalyticsState, trackData: [String: Any]?, timestamp: TimeInterval) -> [String: String] {
        var analyticsVars: [String: String] = [:]
        guard let trackData = trackData else {
            Log.debug(label: LOG_TAG, "processAnalyticsVars - trackevendata is nil.")
            return analyticsVars
        }
        if let actionName = trackData[AnalyticsConstants.EventDataKeys.TRACK_ACTION] as? String {
            analyticsVars[AnalyticsConstants.ANALYTICS_REQUEST_IGNORE_PAGE_NAME_KEY] = AnalyticsConstants.IGNORE_PAGE_NAME_VALUE
            let isInternal = trackData[AnalyticsConstants.EventDataKeys.TRACK_INTERNAL] as? Bool ?? false
            let actionNameWithPrefix = "\(isInternal ? AnalyticsConstants.INTERNAL_ACTION_PREFIX : AnalyticsConstants.ACTION_PREFIX)\(actionName)"
            analyticsVars[AnalyticsConstants.ANALYTICS_REQUEST_ACTION_NAME_KEY] = actionNameWithPrefix
        }
        analyticsVars[AnalyticsConstants.ANALYTICS_REQUEST_PAGE_NAME_KEY] = analyticsState.applicationId
        if let stateName = trackData[AnalyticsConstants.EventDataKeys.TRACK_STATE] as? String {
            analyticsVars[AnalyticsConstants.ANALYTICS_REQUEST_PAGE_NAME_KEY] = stateName
        }
        if let aid = analyticsProperties.aid {
            analyticsVars[AnalyticsConstants.ANALYTICS_REQUEST_ANALYTICS_ID_KEY] = aid
        }

        if let vid = analyticsProperties.vid {
            analyticsVars[AnalyticsConstants.ANALYTICS_REQUEST_VISITOR_ID_KEY] = vid
        }

        analyticsVars[AnalyticsConstants.ANALYTICS_REQUEST_CHARSET_KEY] = AnalyticsProperties.CHARSET
        analyticsVars[AnalyticsConstants.ANALYTICS_REQUEST_FORMATTED_TIMESTAMP_KEY] = analyticsProperties.timezoneOffset

        if analyticsState.offlineEnabled {
            analyticsVars[AnalyticsConstants.ANALYTICS_REQUEST_STRING_TIMESTAMP_KEY] = "\(timestamp)"
        }

        if analyticsState.isVisitorIdServiceEnabled() {
            analyticsVars.merge(analyticsState.getAnalyticsIdVisitorParameters()) {
                key1, _ in
                return key1
            }
        }

        /// - TODO: Put it on main thread.
        if UIApplication.shared.applicationState == .background {
            analyticsVars[AnalyticsConstants.ANALYTICS_REQUEST_CUSTOMER_PERSPECTIVE_KEY] =
                AnalyticsConstants.APP_STATE_BACKGROUND
        } else {
            analyticsVars[AnalyticsConstants.ANALYTICS_REQUEST_CUSTOMER_PERSPECTIVE_KEY] =
                AnalyticsConstants.APP_STATE_FOREGROUND
        }
        return analyticsVars
    }
}

/// Backdate handling.
extension Analytics {

    /// Creates an internal analytics event with the crash session data
    /// - Parameters:
    ///      - analyticsState: The current `AnalyticsState`.
    ///      - previousOSVersion: The OS version in the backdated session
    ///      - previousAppIdVersion: The App Id in the backdate session
    ///      - eventUniqueIdentifier: The event identifier of backdated Lifecycle session event.
    private func backadateLifecycleCrash(analyticsState: AnalyticsState, previousOSVersion: String?, previousAppIdVersion: String?, eventUniqueIdentifier: String) {
        Log.trace(label: LOG_TAG, "backadateLifecycleCrash - Backdating the lifecycle session crash event.")
        var crashContextData: [String: String] = [:]
        crashContextData[AnalyticsConstants.ContextDataKeys.CRASH_EVENT_KEY] = AnalyticsConstants.ContextDataValues.CRASH_EVENT

        if let previousOSVersion = previousOSVersion {
            crashContextData[AnalyticsConstants.ContextDataKeys.OPERATING_SYSTEM] = previousOSVersion
        }

        if let previousAppIdVersion = previousAppIdVersion {
            crashContextData[AnalyticsConstants.ContextDataKeys.APPLICATION_IDENTIFIER] = previousAppIdVersion
        }

        var lifecycleSessionData: [String: Any] = [:]
        lifecycleSessionData[AnalyticsConstants.EventDataKeys.TRACK_ACTION] = AnalyticsConstants.CRASH_INTERNAL_ACTION_NAME
        lifecycleSessionData[AnalyticsConstants.EventDataKeys.CONTEXT_DATA] = crashContextData
        lifecycleSessionData[AnalyticsConstants.EventDataKeys.TRACK_INTERNAL] = true

        track(analyticsState: analyticsState, trackEventData: lifecycleSessionData, timeStampInSeconds: analyticsProperties.getMostRecentHitTimestamp() + 1, appendToPlaceHolder: true, eventUniqueIdentifier: eventUniqueIdentifier)
    }

    /// Creates an internal analytics event with the previous lifecycle session info.
    /// - Parameters:
    ///      - analyticsState: The current `AnalyticsState`.
    ///      - previousSessionLength: The length of previous session
    ///      - previousOSVersion: The OS version in the backdated session
    ///      - previousAppIdVersion: The App Id in the backdate session
    ///      - eventUniqueIdentifier: The event identifier of backdated Lifecycle session event.
    private func backdateLifecycleSessionInfo(analyticsState: AnalyticsState, previousSessionLength: String?, previousOSVersion: String?, previousAppIdVersion: String?, eventUniqueIdentifier: String) {
        Log.trace(label: LOG_TAG, "backdateLifecycleSessionInfo - Backdating the previous lifecycle session.")
        var sessionContextData: [String: String] = [:]

        if let previousSessionLength = previousSessionLength {
            sessionContextData[AnalyticsConstants.ContextDataKeys.PREVIOUS_SESSION_LENGTH] = previousSessionLength
        }

        if let previousOSVersion = previousOSVersion {
            sessionContextData[AnalyticsConstants.ContextDataKeys.OPERATING_SYSTEM] = previousOSVersion
        }

        if let previousAppIdVersion = previousAppIdVersion {
            sessionContextData[AnalyticsConstants.ContextDataKeys.APPLICATION_IDENTIFIER] = previousAppIdVersion
        }

        var lifecycleSessionData: [String: Any] = [:]
        lifecycleSessionData[AnalyticsConstants.EventDataKeys.TRACK_ACTION] = AnalyticsConstants.CRASH_INTERNAL_ACTION_NAME
        lifecycleSessionData[AnalyticsConstants.EventDataKeys.CONTEXT_DATA] = sessionContextData
        lifecycleSessionData[AnalyticsConstants.EventDataKeys.TRACK_INTERNAL] = true
        let backDateTimeStamp = max(Date.init(timeIntervalSince1970: analyticsProperties.getMostRecentHitTimestamp()), analyticsProperties.lifecyclePreviousSessionPauseTimestamp ?? Date.init(timeIntervalSince1970: 0))
        track(analyticsState: analyticsState, trackEventData: lifecycleSessionData, timeStampInSeconds: backDateTimeStamp.timeIntervalSince1970 + 1, appendToPlaceHolder: true, eventUniqueIdentifier: eventUniqueIdentifier)
    }
}

/// Timeout timers.
extension Analytics {

    /// Wait for lifecycle data after receiving Lifecycle Request event.
    private func waitForLifecycleData() {
        analyticsProperties.lifecycleTimerRunning = true
        let lifecycleWorkItem = DispatchWorkItem {
            Log.warning(label: self.LOG_TAG, "waitForLifecycleData - Lifecycle timeout has expired without Lifecycle data")
            /// - TODO: Kick the database hits.
        }
        analyticsProperties.dispatchQueue.asyncAfter(deadline: DispatchTime.now() + AnalyticsConstants.Default.LIFECYCLE_RESPONSE_WAIT_TIMEOUT, execute: lifecycleWorkItem)
        analyticsProperties.lifecycleDispatchWorkItem = lifecycleWorkItem
    }

    /// Wait for Acquisition data after receiving Lifecycle Response event.
    private func waitForAcquisitionData(state: AnalyticsState, timeout: TimeInterval) {
        analyticsProperties.referrerTimerRunning = true
        let referrerDispatchWorkItem = DispatchWorkItem {
            Log.warning(label: self.LOG_TAG, "waitForAcquisitionData - Referrer timeout has expired without referrer data")
            /// - TODO: Kick the database hits.
        }
        analyticsProperties.dispatchQueue.asyncAfter(deadline: DispatchTime.now() + timeout, execute: referrerDispatchWorkItem)
        analyticsProperties.referrerDispatchWorkItem = referrerDispatchWorkItem
    }
}
