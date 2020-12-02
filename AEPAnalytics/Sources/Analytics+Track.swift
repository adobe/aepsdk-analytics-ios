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

/// Track call functions.
extension Analytics {

    private static let LOG_TAG = "Analytics+Track"

    /// Processes the Acquisition event.
    /// If we are waiting for the acquisition data, then try to append it to a existing hit. Otherwise, send a
    /// new hit for acquisition data, and cancel the acquisition timer to mark that the acquisition data has
    /// been received and processed.
    /// - Parameters:
    ///     - analyticsState: The `AnalyticsState` object representing shared states of other dependent
    ///      extensions
    ///     - event: The `acquisition event` to process
    func trackAcquisitionData(analyticsState: AnalyticsState, event: Event, analyticsProperties: inout AnalyticsProperties) {
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

            track(analyticsState: analyticsState, trackEventData: acquisitionEventData, timeStampInSeconds: event.timestamp.timeIntervalSince1970, appendToPlaceHolder: false, eventUniqueIdentifier: "\(event.id)", analyticsProperties: &analyticsProperties)

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
    func track(analyticsState: AnalyticsState, trackEventData: [String: Any]?, timeStampInSeconds: TimeInterval, appendToPlaceHolder: Bool, eventUniqueIdentifier: String, analyticsProperties: inout AnalyticsProperties) {
        guard trackEventData != nil else {
            Log.debug(label: Analytics.LOG_TAG , "track - Dropping the Analytics track request, request was null.")
            return
        }

        guard analyticsState.isAnalyticsConfigured() else {
            Log.debug(label: Analytics.LOG_TAG, "track - Dropping the Analytics track request, Analytics is not configured.")
            return
        }

        analyticsProperties.setMostRecentHitTimestamp(timestampInSeconds: timeStampInSeconds)

        guard analyticsState.privacyStatus != .optedOut else {
            Log.debug(label: Analytics.LOG_TAG, "track - Dropping the Analytics track request, privacy status is opted out.")
            return
        }

        let analyticsData: [String: String] = processAnalyticsContextData(analyticsState: analyticsState, trackEventData: trackEventData)
        let analyticsVars = processAnalyticsVars(analyticsState: analyticsState, trackData: trackEventData, timestamp: timeStampInSeconds, analyticsProperties: &analyticsProperties)
        let builtRequest = analyticsProperties.analyticsRequestSerializer.buildRequest(analyticsState: analyticsState, data: analyticsData, vars: analyticsVars)

        /// - TODO: Get analytics hit database and perform following action.
//        if appendToPlaceHolder {
//                        analyticsHitsDatabase.updateBackdatedHit(state, builtRequest, timestampInSeconds, eventUniqueIdentifier);
//                    } else {
//                        analyticsHitsDatabase.queue(state, builtRequest, timestampInSeconds, analyticsProperties.isDatabaseWaiting(),
//                                                    false, eventUniqueIdentifier);
//                    }
    }

    ///Converts the lifecycle event in internal analytics action. If backdate session and offline tracking are enabled,
    ///and previous session length is present in the contextData map, we send a separate hit with the previous session information and the rest of the keys as a Lifecycle action hit.
    /// If ignored session is present, it will be sent as part of the Lifecycle hit and no SessionInfo hit will be sent.
    /// - Parameters:
    ///     - analyticsState: shared state values
    ///     - event: the `Lifecycle Event` to process.
    func trackLifecycle(analyticsState: AnalyticsState?, event: Event, analyticsProperties: inout AnalyticsProperties) {
        guard let analyticsState = analyticsState else {
            Log.debug(label: Analytics.LOG_TAG, "trackLifecycle - Failed to track lifecycle event (invalid state)")
            return
        }

        guard var eventLifecycleContextData: [String: String] = event.data?[AnalyticsConstants.Lifecycle.EventDataKeys.LIFECYCLE_CONTEXT_DATA] as? [String: String], !eventLifecycleContextData.isEmpty else {
            Log.debug(label: Analytics.LOG_TAG, "trackLifecycle - Failed to track lifecycle event (context data was null or empty)")
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
                backdateLifecycleCrash(analyticsState: analyticsState, previousOSVersion: previousOsVersion, previousAppIdVersion: previousAppIdVersion, eventUniqueIdentifier: "\(event.id)", analyticsProperties: &analyticsProperties)
            }

            if lifecycleContextData.keys.contains(AnalyticsConstants.ContextDataKeys.PREVIOUS_SESSION_LENGTH) {
                let previousSessionLength: String? = lifecycleContextData.removeValue(forKey: AnalyticsConstants.ContextDataKeys.PREVIOUS_SESSION_LENGTH)
                backdateLifecycleSessionInfo(analyticsState: analyticsState, previousSessionLength: previousSessionLength, previousOSVersion: previousOsVersion, previousAppIdVersion: previousAppIdVersion, eventUniqueIdentifier: "\(event.id)", analyticsProperties: &analyticsProperties)
            }
        }
    }

    /// Creates the context data Dictionary from the `EventData` Dictionary and the current `AnalyticsState`.
    /// - Parameters:
    ///     - analyticsState: The current `AnalyticsState`
    ///     - trackEventData: Dictionary containing tracking data
    ///     - Returns a `Dictionary` containing the context data.
    func processAnalyticsContextData(analyticsState: AnalyticsState, trackEventData: [String: Any]?) -> [String: String] {
        var analyticsData: [String: String] = [:]
        guard let trackEventData = trackEventData else {
            Log.debug(label: Analytics.LOG_TAG, "processAnalyticsContextData - trackevendata is nil.")
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
            analyticsData[AnalyticsConstants.Request.PRIVACY_MODE_KEY] = AnalyticsConstants.Request.PRIVACY_MODE_UNKNOWN
        }

        if let requestIdentifier = trackEventData[AnalyticsConstants.EventDataKeys.REQUEST_EVENT_IDENTIFIER] as? String {
            analyticsData[AnalyticsConstants.ContextDataKeys.EVENT_IDENTIFIER_KEY] = requestIdentifier
        }

        return analyticsData
    }

    /// Creates the vars Dictionary from the `EventData` Dictionary and the current `AnalyticsState`.
    /// - Parameters:
    ///     - analyticsState: The current `AnalyticsState`
    ///     - trackData: Dictionary containing tracking data
    ///     - timestamp: timestamp to use for tracking
    ///     - Returns a `Dictionary` containing the vars data
    func processAnalyticsVars(analyticsState: AnalyticsState, trackData: [String: Any]?, timestamp: TimeInterval, analyticsProperties: inout AnalyticsProperties) -> [String: String] {
        var analyticsVars: [String: String] = [:]
        guard let trackData = trackData else {
            Log.debug(label: Analytics.LOG_TAG, "processAnalyticsVars - track event data is nil.")
            return analyticsVars
        }
        if let actionName = trackData[AnalyticsConstants.EventDataKeys.TRACK_ACTION] as? String {
            analyticsVars[AnalyticsConstants.Request.IGNORE_PAGE_NAME_KEY] = AnalyticsConstants.IGNORE_PAGE_NAME_VALUE
            let isInternal = trackData[AnalyticsConstants.EventDataKeys.TRACK_INTERNAL] as? Bool ?? false
            let actionNameWithPrefix = "\(isInternal ? AnalyticsConstants.INTERNAL_ACTION_PREFIX : AnalyticsConstants.ACTION_PREFIX)\(actionName)"
            analyticsVars[AnalyticsConstants.Request.ACTION_NAME_KEY] = actionNameWithPrefix
        }
        analyticsVars[AnalyticsConstants.Request.PAGE_NAME_KEY] = analyticsState.applicationId
        if let stateName = trackData[AnalyticsConstants.EventDataKeys.TRACK_STATE] as? String {
            analyticsVars[AnalyticsConstants.Request.PAGE_NAME_KEY] = stateName
        }
        if let aid = analyticsProperties.aid {
            analyticsVars[AnalyticsConstants.Request.ANALYTICS_ID_KEY] = aid
        }

        if let vid = analyticsProperties.vid {
            analyticsVars[AnalyticsConstants.Request.VISITOR_ID_KEY] = vid
        }

        analyticsVars[AnalyticsConstants.Request.CHARSET_KEY] = AnalyticsProperties.CHARSET
        analyticsVars[AnalyticsConstants.Request.FORMATTED_TIMESTAMP_KEY] = analyticsProperties.timezoneOffset

        if analyticsState.offlineEnabled {
            analyticsVars[AnalyticsConstants.Request.STRING_TIMESTAMP_KEY] = "\(timestamp)"
        }

        if analyticsState.isVisitorIdServiceEnabled() {
            analyticsVars.merge(analyticsState.getAnalyticsIdVisitorParameters()) {
                key1, _ in
                return key1
            }
        }

        DispatchQueue.main.sync {
            if UIApplication.shared.applicationState == .background {
                analyticsVars[AnalyticsConstants.Request.CUSTOMER_PERSPECTIVE_KEY] =
                    AnalyticsConstants.APP_STATE_BACKGROUND
            } else {
                analyticsVars[AnalyticsConstants.Request.CUSTOMER_PERSPECTIVE_KEY] =
                    AnalyticsConstants.APP_STATE_FOREGROUND
            }
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
    private func backdateLifecycleCrash(analyticsState: AnalyticsState, previousOSVersion: String?, previousAppIdVersion: String?, eventUniqueIdentifier: String, analyticsProperties: inout AnalyticsProperties) {
        Log.trace(label: Analytics.LOG_TAG, "backdateLifecycleCrash - Backdating the lifecycle session crash event.")
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

        track(analyticsState: analyticsState, trackEventData: lifecycleSessionData, timeStampInSeconds: analyticsProperties.getMostRecentHitTimestamp() + 1, appendToPlaceHolder: true, eventUniqueIdentifier: eventUniqueIdentifier, analyticsProperties: &analyticsProperties)
    }

    /// Creates an internal analytics event with the previous lifecycle session info.
    /// - Parameters:
    ///      - analyticsState: The current `AnalyticsState`.
    ///      - previousSessionLength: The length of previous session
    ///      - previousOSVersion: The OS version in the backdated session
    ///      - previousAppIdVersion: The App Id in the backdate session
    ///      - eventUniqueIdentifier: The event identifier of backdated Lifecycle session event.
    private func backdateLifecycleSessionInfo(analyticsState: AnalyticsState, previousSessionLength: String?, previousOSVersion: String?, previousAppIdVersion: String?, eventUniqueIdentifier: String, analyticsProperties: inout AnalyticsProperties) {
        Log.trace(label: Analytics.LOG_TAG, "backdateLifecycleSessionInfo - Backdating the previous lifecycle session.")
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
        track(analyticsState: analyticsState, trackEventData: lifecycleSessionData, timeStampInSeconds: backDateTimeStamp.timeIntervalSince1970 + 1, appendToPlaceHolder: true, eventUniqueIdentifier: eventUniqueIdentifier, analyticsProperties: &analyticsProperties)
    }
}

