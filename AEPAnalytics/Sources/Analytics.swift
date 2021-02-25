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

    private let dataStore = NamedCollectionDataStore(name: AnalyticsConstants.DATASTORE_NAME)
    private var analyticsTimer: AnalyticsTimer
    private var analyticsDatabase: AnalyticsDatabase?
    private var analyticsProperties: AnalyticsProperties
    private var analyticsState: AnalyticsState
    private let analyticsHardDependencies: [String] = [AnalyticsConstants.Configuration.EventDataKeys.SHARED_STATE_NAME, AnalyticsConstants.Identity.EventDataKeys.SHARED_STATE_NAME]
    private let analyticsRequestSerializer = AnalyticsRequestSerializer()
    // The `DispatchQueue` used to process events in FIFO order and wait for Lifecycle and Acquisition response events.
    private var dispatchQueue: DispatchQueue = DispatchQueue(label: AnalyticsConstants.FRIENDLY_NAME)
    // Maintains the boot up state of sdk. The first shared state update event indicates the boot up completion.
    private var sdkBootUpCompleted = false
    // MARK: Extension

    public required init?(runtime: ExtensionRuntime) {
        self.runtime = runtime
        // Migrate datastore for apps switching from v4 or v5 implementations.
        AnalyticsMigrator.migrateLocalStorage(dataStore: dataStore)

        self.analyticsTimer = AnalyticsTimer.init(dispatchQueue: dispatchQueue)
        self.analyticsState = AnalyticsState()
        self.analyticsProperties = AnalyticsProperties.init(dataStore: dataStore)
        super.init()

        let processor = AnalyticsHitProcessor(dispatchQueue: dispatchQueue, state: analyticsState, responseHandler: dispatchAnalyticsTrackResponse(eventData:))
        self.analyticsDatabase = AnalyticsDatabase(state: analyticsState, processor: processor)

    }

    #if DEBUG
        // Internal init added for tests
        init(runtime: ExtensionRuntime, state: AnalyticsState, properties: AnalyticsProperties) {
            self.runtime = runtime
            self.analyticsTimer = AnalyticsTimer(dispatchQueue: dispatchQueue)
            self.analyticsState = state
            self.analyticsProperties = properties
            super.init()

            let processor = AnalyticsHitProcessor(dispatchQueue: dispatchQueue, state: analyticsState, responseHandler: dispatchAnalyticsTrackResponse(eventData:))
            self.analyticsDatabase = AnalyticsDatabase(state: analyticsState, processor: processor)
        }
    #endif

    public func onRegistered() {
        registerListener(type: EventType.genericTrack, source: EventSource.requestContent, listener: handleIncomingEvent)
        registerListener(type: EventType.rulesEngine, source: EventSource.responseContent, listener: handleIncomingEvent)
        registerListener(type: EventType.analytics, source: EventSource.requestContent, listener: handleIncomingEvent)
        registerListener(type: EventType.configuration, source: EventSource.responseContent, listener: handleIncomingEvent)
        registerListener(type: EventType.analytics, source: EventSource.requestIdentity, listener: handleIncomingEvent)
        registerListener(type: EventType.acquisition, source: EventSource.responseContent, listener: handleIncomingEvent)
        registerListener(type: EventType.lifecycle, source: EventSource.responseContent, listener: handleIncomingEvent)
        registerListener(type: EventType.genericLifecycle, source: EventSource.requestContent, listener: handleIncomingEvent)
        registerListener(type: EventType.hub, source: EventSource.sharedState, listener: handleIncomingEvent)
    }

    public func onUnregistered() {}

    public func readyForEvent(_ event: Event) -> Bool {
        let configurationStatus = getSharedState(extensionName: AnalyticsConstants.Configuration.EventDataKeys.SHARED_STATE_NAME, event: event)?.status ?? .none
        let identityStatus = getSharedState(extensionName: AnalyticsConstants.Identity.EventDataKeys.SHARED_STATE_NAME, event: event)?.status ?? .none
        return configurationStatus == .set && identityStatus == .set
    }

    /**
     Tries to retrieve the shared data for all the dependencies of the given event. When all the dependencies are resolved, it will update the `AnalyticsState` with the shared states.
     - Parameters:
          - event: The `Event` for which shared state is to be retrieved.
          - dependencies: An array of names of event's dependencies.
     */
    private func updateAnalyticsState(forEvent event: Event, dependencies: [String]) {
        var sharedStates = [String: [String: Any]?]()
        for extensionName in dependencies {
            sharedStates[extensionName] = runtime.getSharedState(extensionName: extensionName, event: event, barrier: true)?.value
        }
        analyticsState.update(dataMap: sharedStates)
    }

    /// Handles all `Events` heard by the Analytics Extension. The processing of events will
    /// be done on the Analytics Extension's `DispatchQueue`.
    /// - Parameter event: The instance of `Event` that needs to be processed.
    private func handleIncomingEvent(event: Event) {
        dispatchQueue.async {
            switch event.type {
            case EventType.genericTrack:
                self.handleGenericTrackEvent(event)
            case EventType.rulesEngine:
                self.handleRuleEngineResponse(event)
            case EventType.configuration:
                self.handleConfigurationResponseEvent(event)
            case EventType.lifecycle:
                self.handleLifecycleEvents(event)
            case EventType.genericLifecycle:
                self.handleLifecycleEvents(event)
            case EventType.acquisition:
                self.handleAcquisitionEvent(event)
            case EventType.analytics:
                if event.source == EventSource.requestIdentity {
                    self.handleAnalyticsRequestIdentityEvent(event)
                } else if event.source == EventSource.requestContent {
                    self.handleAnalyticsRequestContentEvent(event)
                }
            default:
                break
            }
        }
    }

    private func handleRuleEngineResponse(_ event: Event) {
        if event.data == nil {
            Log.trace(label: LOG_TAG, "Event with id \(event.id.uuidString) contained no data, ignoring.")
            return
        }
        Log.trace(label: LOG_TAG, "handleRulesEngineResponse - Processing event with id \(event.id.uuidString).")
        guard let consequence = event.data?[AnalyticsConstants.EventDataKeys.TRIGGERED_CONSEQUENCE] as? [String: Any] else {
            Log.trace(label: LOG_TAG, "handleRulesEngineResponse - Ignoring as missing consequence data for \(event.id.uuidString).")
            return
        }
        guard let consequenceType = consequence[AnalyticsConstants.EventDataKeys.TYPE] as? String, consequenceType == AnalyticsConstants.ConsequenceTypes.TRACK else {
            Log.trace(label: LOG_TAG, "handleRulesEngineResponse - Ignoring as consequence type is not analytics for \(event.id.uuidString).")
            return
        }
        guard let _ = consequence[AnalyticsConstants.EventDataKeys.ID] as? String else {
            Log.trace(label: LOG_TAG, "handleRulesEngineResponse - Ignoring as consequence id is missing for \(event.id.uuidString).")
            return
        }

        let softDependencies: [String] = [
            AnalyticsConstants.Lifecycle.EventDataKeys.SHARED_STATE_NAME,
            AnalyticsConstants.Assurance.EventDataKeys.SHARED_STATE_NAME,
            AnalyticsConstants.Places.EventDataKeys.SHARED_STATE_NAME
        ]
        updateAnalyticsState(forEvent: event, dependencies: analyticsHardDependencies + softDependencies)

        let consequenceDetail = consequence[AnalyticsConstants.EventDataKeys.DETAIL] as? [String: Any] ?? [:]
        handleTrackRequest(event: event, eventData: consequenceDetail)
    }

    /// Handle the following events
    ///`EventType.genericTrack` and `EventSource.requestContent`
    /// - Parameter event: an event containing track data for processing
    private func handleGenericTrackEvent(_ event: Event) {
        guard event.type == EventType.genericTrack && event.source == EventSource.requestContent else {
            Log.debug(label: LOG_TAG, "handleAnalyticsTrackEvent - Ignoring track event (event is of unexpected type or source).")
            return
        }

        let softDependencies: [String] = [
            AnalyticsConstants.Lifecycle.EventDataKeys.SHARED_STATE_NAME,
            AnalyticsConstants.Assurance.EventDataKeys.SHARED_STATE_NAME,
            AnalyticsConstants.Places.EventDataKeys.SHARED_STATE_NAME
        ]
        updateAnalyticsState(forEvent: event, dependencies: analyticsHardDependencies + softDependencies)
        handleTrackRequest(event: event, eventData: event.data)
    }

    func handleTrackRequest(event: Event, eventData: [String: Any]?) {
        guard let eventData = eventData, !eventData.isEmpty else {
            Log.debug(label: LOG_TAG, "track - event data is nil or empty.")
            return
        }
        if eventData.keys.contains(AnalyticsConstants.EventDataKeys.TRACK_ACTION) ||
            eventData.keys.contains(AnalyticsConstants.EventDataKeys.TRACK_STATE) ||
            eventData.keys.contains(AnalyticsConstants.EventDataKeys.CONTEXT_DATA) {
            track(eventData: eventData, timeStampInSeconds: event.timestamp.timeIntervalSince1970, isBackdatedHit: false, eventUniqueIdentifier: "\(event.id)")
        }
    }

    /// Processes Configuration Response content events to retrieve the configuration data and privacy status settings.
    /// - Parameter:
    ///   - event: The configuration response event
    private func handleConfigurationResponseEvent(_ event: Event) {
        updateAnalyticsState(forEvent: event, dependencies: analyticsHardDependencies)

        if analyticsState.privacyStatus == .optedOut {
            handleOptOut(event: event)
        }

        // send an analytics id request on boot if the analytics configuration is valid
        if !sdkBootUpCompleted {
            if analyticsState.isAnalyticsConfigured() {
                sdkBootUpCompleted.toggle()
                Log.trace(label: LOG_TAG, "handleConfigurationResponseEvent - Configuration ready, sending analytics id request.")
                retrieveAnalyticsId(event: event)
            }
        }
    }

    /// Clears all the Analytics Properties and any queued hits in the HitsDatabase.
    private func handleOptOut(event: Event) {
        Log.debug(label: LOG_TAG, "handleOptOut - Privacy status is opted-out. Queued Analytics hits, stored state data, and properties will be cleared.")
        analyticsDatabase?.reset()
        analyticsProperties.reset()
        // Clear shared state for analytics extension
        createSharedState(data: getSharedState(), event: event)
    }

    ///  Handles the following events
    /// `EventType.genericLifecycle` and `EventSource.requestContent`
    /// `EventType.lifecycle` and `EventSource.responseContent`
    ///  - Parameter event: the `Event` to be processed
    private func handleLifecycleEvents(_ event: Event) {
        if event.type == EventType.genericLifecycle && event.source == EventSource.requestContent {
            let lifecycleAction = event.data?[AnalyticsConstants.Lifecycle.EventDataKeys.LIFECYCLE_ACTION_KEY] as? String
            if lifecycleAction == AnalyticsConstants.Lifecycle.EventDataKeys.LIFECYCLE_START {

                // If we receive duplicate lifecycle start events when waiting for lifecycle.responseContext, ignore them.
                if analyticsTimer.isLifecycleTimerRunning() {
                    Log.debug(label: LOG_TAG, "handleLifecycleEvents - Exiting, Lifecycle timer is already running and this is a duplicate request")
                    return
                }

                // For apps coming from background, manually flush any queued hits before waiting for lifecycle data.
                analyticsDatabase?.cancelWaitForAdditionalData(type: .lifecycle)
                analyticsDatabase?.cancelWaitForAdditionalData(type: .referrer)

                waitForLifecycleData()

            } else if lifecycleAction == AnalyticsConstants.Lifecycle.EventDataKeys.LIFECYCLE_PAUSE {
                analyticsTimer.cancelLifecycleTimer()
                analyticsTimer.cancelReferrerTimer()
            }
        } else if event.type == EventType.lifecycle && event.source == EventSource.responseContent {
            let softDependencies: [String] = [
                AnalyticsConstants.Lifecycle.EventDataKeys.SHARED_STATE_NAME,
                AnalyticsConstants.Assurance.EventDataKeys.SHARED_STATE_NAME,
                AnalyticsConstants.Places.EventDataKeys.SHARED_STATE_NAME
            ]
            updateAnalyticsState(forEvent: event, dependencies: analyticsHardDependencies + softDependencies)

            trackLifecycle(event: event)
        }
    }

    /// Handles the following events
    /// `EventType.acquisition` and `EventSource.responseContent`
    /// - Parameter event: The `Event` to be processed.
    private func handleAcquisitionEvent(_ event: Event) {
        if event.type == EventType.acquisition && event.source == EventSource.responseContent {
            let softDependencies: [String] = [
                AnalyticsConstants.Lifecycle.EventDataKeys.SHARED_STATE_NAME,
                AnalyticsConstants.Assurance.EventDataKeys.SHARED_STATE_NAME
            ]
            updateAnalyticsState(forEvent: event, dependencies: analyticsHardDependencies + softDependencies)

            trackAcquisitionData(event: event)
        }
    }

    /// Handles the following events
    /// `EventType.analytics` and `EventSource.requestIdentity`
    /// - Parameter event: The `Event` to be processed.
    private func handleAnalyticsRequestIdentityEvent(_ event: Event) {
        if let eventData = event.data, !eventData.isEmpty {
            if let vid = eventData[AnalyticsConstants.EventDataKeys.VISITOR_IDENTIFIER] as? String, !vid.isEmpty {
                // set VID request
                updateVisitorIdentifier(event: event, vid: vid)
            }
        } else { // get AID/VID request
            retrieveAnalyticsId(event: event)
        }
    }

    private func handleAnalyticsRequestContentEvent(_ event: Event) {
        guard let eventData = event.data, !eventData.isEmpty else {
            Log.debug(label: LOG_TAG, "handleAnalyticsRequestContentEvent - Returning early, event data is nil or empty.")
            return
        }

        if eventData.keys.contains(AnalyticsConstants.EventDataKeys.CLEAR_HITS_QUEUE) {
            analyticsDatabase?.reset()
        } else if eventData.keys.contains(AnalyticsConstants.EventDataKeys.GET_QUEUE_SIZE) {
            let queueSize = analyticsDatabase?.getQueueSize() ?? 0
            dispatchQueueSizeResponse(event: event, queueSize: queueSize)
        } else if eventData.keys.contains(AnalyticsConstants.EventDataKeys.FORCE_KICK_HITS) {
            analyticsDatabase?.forceKickHits()
        }
    }

    /// Stores the passed in visitor identifier in the analytics datastore via the `AnalyticsProperties`.
    /// - Parameters:
    ///     - event: The `Event` which triggered the visitor identifier update.
    ///     - vid: The visitor identifier that was set.
    private func updateVisitorIdentifier(event: Event, vid: String) {
        if analyticsState.privacyStatus == .optedOut {
            Log.debug(label: LOG_TAG, "updateVisitorIdentifier - Privacy is opted out, ignoring the update visitor identifier request.")
            return
        }

        // persist the visitor identifier
        analyticsProperties.setVisitorIdentifier(vid: vid)

        // create a new analytics shared state and dispatch response for any extensions listening for AID/VID change
        dispatchAnalyticsIdentityResponse(event: event)
    }

    /// Sends an analytics id request and processes the response from the server if there
    /// is no currently stored AID. If an AID is already present in AnalyticsProperties,
    /// the stored AID is dispatched and no network request is made.
    /// - Parameters:
    ///     - event: The `Event` which triggered the sending of the analytics id request.
    private func retrieveAnalyticsId(event: Event) {
        // check if analytics state contains an RSID and host OR if privacy opt-out. if so, update shared state with empty id.
        if !analyticsState.isAnalyticsConfigured() || analyticsState.privacyStatus == .optedOut {
            Log.debug(label: LOG_TAG, "sendAnalyticsIdRequest - Analytics is not configured or privacy is opted out, the analytics identifier request will not be sent.")
            analyticsProperties.setAnalyticsIdentifier(aid: nil)
            analyticsProperties.setVisitorIdentifier(vid: nil)
            // create nil shared state  and dispatch this data in a response event for any extensions listening for AID/VID change
            dispatchAnalyticsIdentityResponse(event: event)
            return
        }

        // two conditions where we need to retrieve aid
        // 1. no saved AID & no marketing cloud org id, we need to get one from visitor ID service  (otherwise we should be using ECID from AAM)
        // 2. isVisitorIdServiceEnabled is false and ignoreAidStatus is true
        let ignoreAidStatus = analyticsProperties.getIgnoreAidStatus()
        var aid = analyticsProperties.getAnalyticsIdentifier()
        if (!ignoreAidStatus && aid == nil)
            || (ignoreAidStatus && !analyticsState.isVisitorIdServiceEnabled()) {
            // if privacy is unknown, don't initiate network call with AID
            // return current stored AID if have one, otherwise generate one
            if analyticsState.privacyStatus == .unknown {
                if aid == nil {
                    aid = generateAID()
                    analyticsProperties.setAnalyticsIdentifier(aid: aid)
                }

                dispatchAnalyticsIdentityResponse(event: event)
                return
            }

            guard let url = analyticsState.buildAnalyticsIdRequestURL() else {
                Log.warning(label: self.LOG_TAG, "sendAnalyticsIdRequest - Failed to build the Analytics ID Request URL.")
                return
            }

            Log.debug(label: LOG_TAG, "sendAnalyticsIdRequest - Sending Analytics ID call (\(url)).")
            ServiceProvider.shared.networkService.connectAsync(networkRequest: buildAnalyticsIdentityRequest(url: url)) {[weak self] (connection) in
                if connection.response == nil {
                    Log.debug(label: "Analytics", "sendAnalyticsIdRequest - Unable to read response for AID request, response is nil.")
                } else if connection.responseCode != 200 {
                    Log.debug(label: "Analytics", "sendAnalyticsIdRequest - Unable to read response for AID request. response code = \(String(describing: connection.responseCode)).")
                } else {
                    // Execute this on dispatch queue as it mutates analytics property.
                    self?.dispatchQueue.async {
                        guard let self = self else { return }
                        var aid: String = self.parseIdentifier(response: connection.data)
                        if aid.count != AnalyticsConstants.AID_LENGTH {
                            aid = self.analyticsState.isVisitorIdServiceEnabled() ? "" : self.generateAID()
                        }
                        self.analyticsProperties.setAnalyticsIdentifier(aid: aid)
                        self.dispatchAnalyticsIdentityResponse(event: event)
                    }

                }
            }
        } else {
            dispatchAnalyticsIdentityResponse(event: event)
        }
    }

    /// Get the data for the analytics extension to be shared with other extensions.
    /// - Returns: The analytics data to be shared.
    private func getSharedState() -> [String: Any] {
        var data = [String: Any]()
        if let aid = analyticsProperties.getAnalyticsIdentifier() {
            data[AnalyticsConstants.EventDataKeys.ANALYTICS_ID] = aid
        }
        if let vid = analyticsProperties.getVisitorIdentifier() {
            data[AnalyticsConstants.EventDataKeys.VISITOR_IDENTIFIER] = vid
        }
        return data
    }

    /// Creates a new analytics shared state then dispatches an analytics response identity event.
    /// - Parameters:
    ///   - event: the event which triggered the analytics identity request.
    private func dispatchAnalyticsIdentityResponse(event: Event) {
        let sharedState = getSharedState()
        createSharedState(data: sharedState, event: event)
        let responseIdentityEvent = event.createResponseEvent(name: "TrackingIdentifierValue", type: EventType.analytics, source: EventSource.responseIdentity, data: sharedState)
        dispatch(event: responseIdentityEvent)
    }

    /// Creates a new analytics shared state then dispatches an analytics response identity event.
    /// - Parameters:
    ///   - event: the event which triggered the analytics identity request.
    private func dispatchQueueSizeResponse(event: Event, queueSize: Int) {
        let eventData = [
            AnalyticsConstants.EventDataKeys.QUEUE_SIZE: queueSize
        ]
        Log.debug(label: self.LOG_TAG, "DispatchQueueSize - Dispatching Analytics hit queue size response event with eventdata \(eventData)")
        let responseContentEvent = event.createResponseEvent(name: "QueueSizeValue", type: EventType.analytics, source: EventSource.responseContent, data: eventData)
        dispatch(event: responseContentEvent)
    }

    private func dispatchAnalyticsTrackResponse(eventData: [String: Any]) {
        let responseEvent = Event.init(name: "AnalyticsResponse", type: EventType.analytics, source: EventSource.responseContent, data: eventData)
        dispatch(event: responseEvent)
    }

    /// Builds an analytics identity `NetworkRequest`.
    /// - Parameters:
    ///   - url: the url of the analytics identity request.
    /// - Returns: the built analytics identity `NetworkRequest`.
    private func buildAnalyticsIdentityRequest(url: URL) -> NetworkRequest {
        var headers = [String: String]()
        let locale = ServiceProvider.shared.systemInfoService.getActiveLocaleName()
        if !locale.isEmpty {
            headers[AnalyticsConstants.HttpConnection.HEADER_KEY_ACCEPT_LANGUAGE] = locale
        }

        return NetworkRequest(url: url, httpMethod: .get, connectPayload: "", httpHeaders: headers, connectTimeout: AnalyticsConstants.Default.CONNECTION_TIMEOUT, readTimeout: AnalyticsConstants.Default.CONNECTION_TIMEOUT)
    }

    /// Parses the analytics id present in a response received from analytics.
    /// - Parameters:
    ///     - state: The current `AnalyticsState`.
    ///     - response: The response received from analytics.
    /// - Returns: a string containing the analytcs id contained in the response or a generated analytics id if non was found.
    private func parseIdentifier(response: Data?) -> String {
        guard let response = response else {
            Log.debug(label: self.LOG_TAG, "parseIdentifier - Response is nil for analytics id request.")
            return ""
        }
        guard let jsonResponse = try? JSONDecoder().decode(AnalyticsHitResponse.self, from: response) else {
            Log.debug(label: self.LOG_TAG, "parseIdentifier - Failed to parse analytics server response.")
            return ""
        }
        return jsonResponse.aid ?? ""
    }

    /// Generates a random Analytics ID.
    /// This method should be used if the analytics server response will be null or invalid.
    /// - Returns: a string containing a random analytics identifier.
    private func generateAID() -> String {
        let halfAidLength = AnalyticsConstants.AID_LENGTH / 2
        let highBound = 7
        let lowBound = 3
        var uuid = UUID().uuidString

        uuid = uuid.replacingOccurrences(of: "-", with: "", options: .literal, range: nil).uppercased()

        guard let firstPattern = try? NSRegularExpression(pattern: "^[89A-F]") else { return "" }
        guard let secondPattern = try? NSRegularExpression(pattern: "^[4-9A-F]") else { return "" }

        var substring = uuid.prefix(halfAidLength)
        var firstPartUuid = String(substring)
        substring = uuid.suffix(halfAidLength)
        var secondPartUuid = String(substring)

        var matches = firstPattern.matches(in: firstPartUuid, range: NSRange(0..<firstPartUuid.count-1))
        if matches.count != 0 {
            let range = firstPartUuid.startIndex..<firstPartUuid.index(after: firstPartUuid.startIndex)
            firstPartUuid = firstPartUuid.replacingCharacters(in: range, with: String(Int.random(in: 1 ..< highBound)))
        }

        matches = secondPattern.matches(in: secondPartUuid, range: NSRange(0..<secondPartUuid.count-1))
        if matches.count != 0 {
            let range = firstPartUuid.startIndex..<firstPartUuid.index(after: firstPartUuid.startIndex)
            secondPartUuid = secondPartUuid.replacingCharacters(in: range, with: String(Int.random(in: 1 ..< lowBound)))
        }

        return firstPartUuid + "-" + secondPartUuid
    }

    ///Converts the lifecycle event in internal analytics action. If backdate session and offline tracking are enabled,
    ///and previous session length is present in the contextData map, we send a separate hit with the previous session information and the rest of the keys as a Lifecycle action hit.
    /// If ignored session is present, it will be sent as part of the Lifecycle hit and no SessionInfo hit will be sent.
    /// - Parameters:
    ///     - event: the `Lifecycle Event` to process.
    func trackLifecycle(event: Event) {
        guard var eventLifecycleContextData: [String: String] = event.data?[AnalyticsConstants.Lifecycle.EventDataKeys.LIFECYCLE_CONTEXT_DATA] as? [String: String], !eventLifecycleContextData.isEmpty else {
            Log.debug(label: LOG_TAG, "trackLifecycle - Failed to track lifecycle event (context data was null or empty)")
            return
        }

        let previousOsVersion: String? = eventLifecycleContextData.removeValue(forKey: AnalyticsConstants.Lifecycle.EventDataKeys.PREVIOUS_OS_VERSION)
        let previousAppIdVersion: String? = eventLifecycleContextData.removeValue(forKey: AnalyticsConstants.Lifecycle.EventDataKeys.PREVIOUS_APP_ID)

        var lifecycleContextData: [String: String] = [:]

        eventLifecycleContextData.forEach { eventDataKey, value in
            if AnalyticsConstants.MAP_EVENT_DATA_KEYS_TO_CONTEXT_DATA_KEYS.keys.contains(eventDataKey) {
                if let contextDataKey = AnalyticsConstants.MAP_EVENT_DATA_KEYS_TO_CONTEXT_DATA_KEYS[eventDataKey] {
                    lifecycleContextData[contextDataKey] = value
                }
            } else {
                lifecycleContextData[eventDataKey] = value
            }
        }

        if lifecycleContextData.keys.contains(AnalyticsConstants.ContextDataKeys.INSTALL_EVENT_KEY) {
            waitForAcquisitionData(timeout: TimeInterval.init(analyticsState.launchHitDelay))
        } else if lifecycleContextData.keys.contains(AnalyticsConstants.ContextDataKeys.LAUNCH_EVENT_KEY) {
            waitForAcquisitionData(timeout: AnalyticsConstants.Default.LAUNCH_DEEPLINK_DATA_WAIT_TIMEOUT)
        }

        if analyticsState.backDateSessionInfoEnabled && analyticsState.offlineEnabled {
            if lifecycleContextData.keys.contains(AnalyticsConstants.ContextDataKeys.CRASH_EVENT_KEY) {
                lifecycleContextData.removeValue(forKey: AnalyticsConstants.ContextDataKeys.CRASH_EVENT_KEY)
                backdateLifecycleCrash(previousOSVersion: previousOsVersion, previousAppIdVersion: previousAppIdVersion, eventUniqueIdentifier: "\(event.id)")
            }

            if lifecycleContextData.keys.contains(AnalyticsConstants.ContextDataKeys.PREVIOUS_SESSION_LENGTH) {
                let previousSessionLength: String? = lifecycleContextData.removeValue(forKey: AnalyticsConstants.ContextDataKeys.PREVIOUS_SESSION_LENGTH)
                let previousSessionPauseTimestamp: TimeInterval? = event.data?[AnalyticsConstants.Lifecycle.EventDataKeys.PREVIOUS_SESSION_PAUSE_TIMESTAMP] as? TimeInterval
                backdateLifecycleSessionInfo(previousSessionLength: previousSessionLength, previousSessionPauseTimestamp: previousSessionPauseTimestamp, previousOSVersion: previousOsVersion, previousAppIdVersion: previousAppIdVersion, eventUniqueIdentifier: "\(event.id)")
            }
        }

        if analyticsTimer.isLifecycleTimerRunning() {
            Log.debug(label: LOG_TAG, "trackLifecycle - Cancelling lifecycle timer")
            analyticsTimer.cancelLifecycleTimer()
        }
        if analyticsDatabase?.isHitWaiting() ?? false {
            Log.debug(label: LOG_TAG, "trackLifecycle - Append lifecycle data to pending hit")
            analyticsDatabase?.kickWithAdditionalData(type: .lifecycle, data: lifecycleContextData)
        } else {
            // Signal the database, it does not have to wait for lifecyle data.
            analyticsDatabase?.cancelWaitForAdditionalData(type: .lifecycle)

            Log.debug(label: LOG_TAG, "trackLifecycle - Sending lifecycle data as seperate tracking hit")
            // Send Lifecycle data as a seperate tracking hit.
            var lifecycleEventData: [String: Any] = [:]
            lifecycleEventData[AnalyticsConstants.EventDataKeys.TRACK_ACTION] = AnalyticsConstants.LIFECYCLE_INTERNAL_ACTION_NAME
            lifecycleEventData[AnalyticsConstants.EventDataKeys.CONTEXT_DATA] = lifecycleContextData
            lifecycleEventData[AnalyticsConstants.EventDataKeys.TRACK_INTERNAL] = true

            track(eventData: lifecycleEventData, timeStampInSeconds: event.timestamp.timeIntervalSince1970, isBackdatedHit: false, eventUniqueIdentifier: "\(event.id)")
        }
    }

    /// Processes the Acquisition event.
    /// If we are waiting for the acquisition data, then try to append it to a existing hit. Otherwise, send a
    /// new hit for acquisition data, and cancel the acquisition timer to mark that the acquisition data has
    /// been received and processed.
    /// - Parameters:
    ///     - analyticsState: The `AnalyticsState` object representing shared states of other dependent
    ///      extensions
    ///     - event: The `acquisition event` to process
    func trackAcquisitionData(event: Event) {
        let acquisitionContextData = event.data?[AnalyticsConstants.EventDataKeys.CONTEXT_DATA] as? [String: String]

        if analyticsTimer.isReferrerTimerRunning() {
            Log.debug(label: LOG_TAG, "trackAcquisition - Cancelling referrer timer")
            analyticsTimer.cancelReferrerTimer()
        }

        if analyticsDatabase?.isHitWaiting() ?? false {
            Log.debug(label: LOG_TAG, "trackAcquisition - Append referrer data to pending hit")
            analyticsDatabase?.kickWithAdditionalData(type: .referrer, data: acquisitionContextData)
        } else {
            // Signal that the database, it does not have to wait for referrer data.
            analyticsDatabase?.cancelWaitForAdditionalData(type: .referrer)

            Log.debug(label: LOG_TAG, "trackAcquisition - Sending referrer data as seperate tracking hit")
            // Send Acquisition data as a seperate tracking hit.
            var acquisitionEventData: [String: Any] = [:]
            acquisitionEventData[AnalyticsConstants.EventDataKeys.TRACK_ACTION] = AnalyticsConstants.TRACK_INTERNAL_ADOBE_LINK
            acquisitionEventData[AnalyticsConstants.EventDataKeys.CONTEXT_DATA] = acquisitionContextData
            acquisitionEventData[AnalyticsConstants.EventDataKeys.TRACK_INTERNAL] = true

            track(eventData: acquisitionEventData, timeStampInSeconds: event.timestamp.timeIntervalSince1970, isBackdatedHit: false, eventUniqueIdentifier: "\(event.id)")
        }
    }

    /// Track analytics requests for actions/states
    /// - Parameters:
    ///     - eventData: `EventData` object containing tracking data
    ///     - timeStampInSeconds: current event timestamp used for tracking
    ///     - isBackdatedHit: boolean indicating whether the data corresponds to backdated session hit
    ///     - eventUniqueIdentifier: the event unique identifier responsible for this track
    func track(eventData: [String: Any]?, timeStampInSeconds: TimeInterval, isBackdatedHit: Bool, eventUniqueIdentifier: String) {
        guard eventData != nil else {
            Log.debug(label: LOG_TAG, "track - Dropping the request, eventData is nil.")
            return
        }

        guard analyticsState.privacyStatus != .optedOut else {
            Log.debug(label: LOG_TAG, "track - Dropping the request, privacy status is opted out.")
            return
        }

        guard analyticsState.isAnalyticsConfigured() else {
            Log.debug(label: LOG_TAG, "track - Dropping the request, Analytics is not configured.")
            return
        }

        analyticsProperties.setMostRecentHitTimestamp(timestampInSeconds: timeStampInSeconds)

        let analyticsData = processAnalyticsContextData(trackData: eventData)
        let analyticsVars = processAnalyticsVars(trackData: eventData, timestamp: timeStampInSeconds)

        let builtRequest = analyticsRequestSerializer.buildRequest(analyticsState: analyticsState, data: analyticsData, vars: analyticsVars)

        analyticsDatabase?.queue(payload: builtRequest, timestamp: timeStampInSeconds, eventIdentifier: eventUniqueIdentifier, isBackdateHit: isBackdatedHit)
    }

    /// Creates the context data Dictionary from the `trackData`
    /// - Parameters:
    ///     - trackData: Dictionary containing tracking data
    ///     - Returns a `Dictionary` containing the context data.
    func processAnalyticsContextData(trackData: [String: Any]?) -> [String: String] {
        guard let trackData = trackData else {
            Log.debug(label: LOG_TAG, "processAnalyticsContextData - trackData is nil.")
            return [:]
        }

        var analyticsData = analyticsState.defaultData
        if let contextData = trackData[AnalyticsConstants.EventDataKeys.CONTEXT_DATA] as? [String: String] {
            analyticsData.merge(contextData) { _, newValue in
                return newValue
            }
        }
        if let actionName = trackData[AnalyticsConstants.EventDataKeys.TRACK_ACTION] as? String, !actionName.isEmpty {
            let isInternalAction = trackData[AnalyticsConstants.EventDataKeys.TRACK_INTERNAL] as? Bool ?? false
            let actionKey = isInternalAction ? AnalyticsConstants.ContextDataKeys.INTERNAL_ACTION_KEY : AnalyticsConstants.ContextDataKeys.ACTION_KEY
            analyticsData[actionKey] = actionName
        }
        let lifecycleSessionStartTimestamp = analyticsState.lifecycleSessionStartTimestamp
        if lifecycleSessionStartTimestamp > 0 {
            let timeSinceLaunchInSeconds = Date().timeIntervalSince1970 - lifecycleSessionStartTimestamp
            if timeSinceLaunchInSeconds > 0 && timeSinceLaunchInSeconds.isLessThanOrEqualTo( analyticsState.lifecycleMaxSessionLength) {
                analyticsData[AnalyticsConstants.ContextDataKeys.TIME_SINCE_LAUNCH_KEY] = "\(timeSinceLaunchInSeconds)"
            }
        }
        if analyticsState.privacyStatus == .unknown {
            analyticsData[AnalyticsConstants.Request.PRIVACY_MODE_KEY] = AnalyticsConstants.Request.PRIVACY_MODE_UNKNOWN
        }

        if let requestIdentifier = trackData[AnalyticsConstants.EventDataKeys.REQUEST_EVENT_IDENTIFIER] as? String {
            analyticsData[AnalyticsConstants.ContextDataKeys.EVENT_IDENTIFIER_KEY] = requestIdentifier
        }

        return analyticsData
    }

    /// Creates the vars Dictionary from the `trackData`
    /// - Parameters:
    ///     - trackData: Dictionary containing tracking data
    ///     - timestamp: timestamp to use for tracking
    ///     - Returns a `Dictionary` containing the vars data
    func processAnalyticsVars(trackData: [String: Any]?, timestamp: TimeInterval) -> [String: String] {
        var analyticsVars: [String: String] = [:]

        guard let trackData = trackData else {
            Log.debug(label: LOG_TAG, "processAnalyticsVars - track event data is nil.")
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

        if let aid = analyticsProperties.getAnalyticsIdentifier() {
            analyticsVars[AnalyticsConstants.Request.ANALYTICS_ID_KEY] = aid
        }

        if let vid = analyticsProperties.getVisitorIdentifier() {
            analyticsVars[AnalyticsConstants.Request.VISITOR_ID_KEY] = vid
        }

        analyticsVars[AnalyticsConstants.Request.CHARSET_KEY] = AnalyticsProperties.CHARSET
        analyticsVars[AnalyticsConstants.Request.FORMATTED_TIMESTAMP_KEY] = analyticsProperties.timezoneOffset

        if analyticsState.offlineEnabled {
            analyticsVars[AnalyticsConstants.Request.STRING_TIMESTAMP_KEY] = "\(Int(timestamp))"
        }

        if analyticsState.isVisitorIdServiceEnabled() {
            analyticsVars.merge(analyticsState.getAnalyticsIdVisitorParameters()) { _, newValue in
                return newValue
            }
        }

        if let appState = AnalyticsHelper.getApplicationState() {
            analyticsVars[AnalyticsConstants.Request.CUSTOMER_PERSPECTIVE_KEY] =
                (appState == .background) ? AnalyticsConstants.APP_STATE_BACKGROUND : AnalyticsConstants.APP_STATE_FOREGROUND
        }

        return analyticsVars
    }

    /// Creates an internal analytics event with the crash session data
    /// - Parameters:
    ///      - previousOSVersion: The OS version in the backdated session
    ///      - previousAppIdVersion: The App Id in the backdated session
    ///      - eventUniqueIdentifier: The event identifier of backdated Lifecycle session event.
    private func backdateLifecycleCrash(previousOSVersion: String?, previousAppIdVersion: String?, eventUniqueIdentifier: String) {
        Log.trace(label: LOG_TAG, "backdateLifecycleCrash - Backdating the lifecycle session crash event.")
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

        track(eventData: lifecycleSessionData, timeStampInSeconds: analyticsProperties.getMostRecentHitTimestamp() + 1, isBackdatedHit: true, eventUniqueIdentifier: eventUniqueIdentifier)
    }

    /// Creates an internal analytics event with the previous lifecycle session info.
    /// - Parameters:
    ///      - previousSessionLength: The length of previous session
    ///      - previousOSVersion: The OS version in the backdated session
    ///      - previousAppIdVersion: The App Id in the backdated session
    ///      - eventUniqueIdentifier: The event identifier of backdated Lifecycle session event.
    private func backdateLifecycleSessionInfo(previousSessionLength: String?, previousSessionPauseTimestamp: TimeInterval?, previousOSVersion: String?, previousAppIdVersion: String?, eventUniqueIdentifier: String) {
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
        lifecycleSessionData[AnalyticsConstants.EventDataKeys.TRACK_ACTION] = AnalyticsConstants.SESSION_INFO_INTERNAL_ACTION_NAME
        lifecycleSessionData[AnalyticsConstants.EventDataKeys.CONTEXT_DATA] = sessionContextData
        lifecycleSessionData[AnalyticsConstants.EventDataKeys.TRACK_INTERNAL] = true

        let backDateTimeStamp = max(analyticsProperties.getMostRecentHitTimestamp(), previousSessionPauseTimestamp ?? 0)

        track(eventData: lifecycleSessionData, timeStampInSeconds: backDateTimeStamp + 1, isBackdatedHit: true, eventUniqueIdentifier: eventUniqueIdentifier)
    }

    /// Wait for lifecycle data after receiving Lifecycle Request event.
    func waitForLifecycleData() {
        Log.debug(label: "Analytics", "waitForLifecycleData - Lifecycle timer scheduled with timeout \(AnalyticsConstants.Default.LIFECYCLE_RESPONSE_WAIT_TIMEOUT)")
        analyticsDatabase?.waitForAdditionalData(type: .lifecycle)
        analyticsTimer.startLifecycleTimer(timeout: AnalyticsConstants.Default.LIFECYCLE_RESPONSE_WAIT_TIMEOUT) { [weak self] in
            Log.warning(label: "Analytics", "waitForLifecycleData - Lifecycle timeout has expired without Lifecycle data")
            self?.analyticsDatabase?.cancelWaitForAdditionalData(type: .lifecycle)
        }
    }

    /// Wait for Acquisition data after receiving Acquisition Response event.
    func waitForAcquisitionData(timeout: TimeInterval) {
        Log.debug(label: "Analytics", "waitForAcquisitionData - Referrer timer scheduled with timeout \(timeout)")
        analyticsDatabase?.waitForAdditionalData(type: .referrer)
        analyticsTimer.startReferrerTimer(timeout: timeout) { [weak self] in
            Log.warning(label: "Analytics", "WaitForAcquisitionData - Launch hit delay has expired without referrer data.")
            self?.analyticsDatabase?.cancelWaitForAdditionalData(type: .referrer)
        }
    }
}
