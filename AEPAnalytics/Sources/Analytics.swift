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
    private var analyticsProperties: AnalyticsProperties
    private var analyticsState: AnalyticsState
    private let analyticsHardDependencies: [String] = [AnalyticsConstants.Configuration.EventDataKeys.SHARED_STATE_NAME, AnalyticsConstants.Identity.EventDataKeys.SHARED_STATE_NAME]

    //Maintains the boot up state of sdk. The first shared state update event indicates the boot up completion.
    private var sdkBootUpCompleted = false
    // MARK: Extension

    public required init(runtime: ExtensionRuntime) {
        self.runtime = runtime
        self.analyticsState = AnalyticsState()
        self.analyticsProperties = AnalyticsProperties.init()
        super.init()
    }

    #if DEBUG
        // internal init added for tests
        internal init(runtime: ExtensionRuntime, state: AnalyticsState, properties: AnalyticsProperties) {
            self.runtime = runtime
            self.analyticsState = state
            self.analyticsProperties = properties
            super.init()
        }

        // analytics properties getter added for tests
        internal func getAnalyticsProperties() -> AnalyticsProperties {
            return analyticsProperties
        }
    #endif

    public func onRegistered() {
        registerListener(type: EventType.genericTrack, source: EventSource.requestContent, listener: handleIncomingEvent)
//        registerListener(type: EventType.rulesEngine, source: EventSource.responseContent, listener: handleIncomingEvent)
//        registerListener(type: EventType.analytics, source: EventSource.requestContent, listener: handleIncomingEvent)
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
    func updateAnalyticsState(forEvent event: Event, dependencies: [String]) {
        var sharedStates = [String: [String: Any]?]()
        for extensionName in dependencies {
            sharedStates[extensionName] = runtime.getSharedState(extensionName: extensionName, event: event, barrier: true)?.value
        }
        analyticsState.update(dataMap: sharedStates)
    }
}

/// Event Listeners
extension Analytics {

    /// Handles all `Events` heard by the Analytics Extension. The processing of events will
    /// be done on the Analytics Extension's `DispatchQueue`.
    /// - Parameter event: The instance of `Event` that needs to be processed.
    private func handleIncomingEvent(event: Event) {
        analyticsProperties.dispatchQueue.async {
            switch event.type {
            // case EventType.rulesEngine:
            // TODO: implement handler
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
                } else { // EventSource == requestContent
                    // TODO: implement handler
                }
            case EventType.hub:
                if event.source == EventSource.sharedState {
                    self.handleSharedStateUpdateEvent(event)
                }
            default:
                break
            }
        }
    }

    /// Processes Configuration Response content events to retrieve the configuration data and privacy status settings.
    /// - Parameter:
    ///   - event: The configuration response event
    private func handleConfigurationResponseEvent(_ event: Event) {
        guard let configSharedState = getSharedState(extensionName: AnalyticsConstants.Configuration.EventDataKeys.SHARED_STATE_NAME, event: event)?.value else { return }
        Log.debug(label: LOG_TAG, "Received Configuration Response event, attempting to retrieve configuration settings.")
        analyticsState.extractConfigurationInfo(from: configSharedState)
        if analyticsState.privacyStatus == .optedOut {
            handleOptOut(event: event)
        }
    }

    /// Clears all the Analytics Properties and any queued hits in the HitsDatabase.
    private func handleOptOut(event: Event) {
        Log.debug(label: LOG_TAG, "Privacy status is opted-out. Queued Analytics hits, stored state data, and properties will be cleared.")
        // Clear / reset to default values any properties stored in the AnalyticsProperties
        analyticsProperties.reset()
        // TODO: clear hits database
        let sharedState = getSharedState()
        createSharedState(data: sharedState, event: event)
    }

    ///  Handles the following events
    /// `EventType.genericLifecycle` and `EventSource.requestContent`
    /// `EventType.lifecycle` and `EventSource.responseContent`
    ///  - Parameter event: the `Event` to be processed
    private func handleLifecycleEvents(_ event: Event) {
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

    /// Handles the shared state change `Event`
    /// - Parameter event: The `Event` to be processed. The event this listener process is of
    /// `EventType.Hub` and `EventSource.sharedState`.
    private func handleSharedStateUpdateEvent(_ event: Event) {

        guard event.type == EventType.hub && event.source == EventSource.sharedState else {
            Log.debug(label: LOG_TAG, "handleSharedStateUpdateEvent - Ignoring shared state update event (event is of unexpected Type).")
            return
        }

        if !sdkBootUpCompleted {
            sdkBootUpCompleted.toggle()
            Log.trace(label: LOG_TAG, "handleSharedStateUpdateEvent - Boot Completion detected.")
            handleAnalyticsRequestIdentityEvent(event)
        }

        guard let data = event.data else {
            Log.debug(label: LOG_TAG, "handleSharedStateUpdateEvent - Ignoring shared state update event (event data was nil).")
            return
        }

        guard let stateOwner = data[AnalyticsConstants.EventDataKeys.STATE_OWNER] as? String else {
            Log.debug(label: LOG_TAG, "handleSharedStateUpdateEvent - Ignoring shared state update event (state owner is missing).")
            return
        }

        if analyticsHardDependencies.contains(stateOwner) {
            //TODO: Call the process event function.
        }
    }

    /// Handles the following events
    /// `EventType.analytics` and `EventSource.requestIdentity`
    /// - Parameter event: The `Event` to be processed.
    private func handleAnalyticsRequestIdentityEvent(_ event: Event) {
        if let eventData = event.data, event.source == EventSource.requestIdentity && !eventData.isEmpty {
            if let vid = eventData[AnalyticsConstants.EventDataKeys.VISITOR_IDENTIFIER] as? String, !vid.isEmpty {
                // set VID request
                updateVisitorIdentifier(event: event, vid: vid)
            }
        } else { // get AID/VID request
            sendAnalyticsIdRequest(event: event)
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
        analyticsProperties.setAnalyticsVisitorIdentifier(vid: vid)

        // create a new analytics shared state and dispatch response for any extensions listening for AID/VID change
        dispatchAnalyticsIdentityResponse(event: event)
    }

    /// Sends an analytics id request and processes the response from the server.
    /// - Parameters:
    ///     - event: The `Event` which triggered the sending of the analytics id request.
    private func sendAnalyticsIdRequest(event: Event) {
        // check if analytics state contains an RSID and host OR if privacy opt-out. if so, update shared state with empty id.
        if !analyticsState.isAnalyticsConfigured() || analyticsState.privacyStatus == .optedOut {
            Log.debug(label: LOG_TAG, "sendAnalyticsIdRequest - Analytics is not configured or privacy is opted out, the analytics identifier request will not be sent.")
            analyticsProperties.setAnalyticsIdentifier(aid: nil)
            analyticsProperties.setAnalyticsVisitorIdentifier(vid: nil)
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

            guard let url = analyticsState.buildAnalyticsIdRequestURL(properties: analyticsProperties) else {
                Log.warning(label: self.LOG_TAG, "sendAnalyticsIdRequest - Failed to build the Analytics ID Request URL.")
                return
            }

            Log.debug(label: LOG_TAG, "sendAnalyticsIdRequest - Sending Analytics ID call (\(url)).")
            ServiceProvider.shared.networkService.connectAsync(networkRequest: buildAnalyticsIdentityRequest(url: url)) { (connection) in
                if connection.response == nil {
                    Log.debug(label: self.LOG_TAG, "sendAnalyticsIdRequest - Unable to read response for AID request, connection was nil.")
                } else if connection.responseCode != 200 {
                    Log.debug(label: self.LOG_TAG, "sendAnalyticsIdRequest - Unable to read response for AID request. Connection response code = \(String(describing: connection.responseCode)).")
                } else {
                    guard let responseData = connection.data else {
                        Log.debug(label: self.LOG_TAG, "sendAnalyticsIdRequest - Unable to retrieve connection date from the AID request.")
                        return
                    }
                    let aid = self.parseIdentifier(state: self.analyticsState, response: responseData)
                    Log.debug(label: self.LOG_TAG, "sendAnalyticsIdRequest - Successfully sent the AID request, received response: \(aid)")
                    self.analyticsProperties.setAnalyticsIdentifier(aid: aid)
                    self.dispatchAnalyticsIdentityResponse(event: event)
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
        data[AnalyticsConstants.EventDataKeys.ANALYTICS_ID] = analyticsProperties.getAnalyticsIdentifier()
        data[AnalyticsConstants.EventDataKeys.VISITOR_IDENTIFIER] = analyticsProperties.getVisitorIdentifier()

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
    private func parseIdentifier(state: AnalyticsState, response: Data) -> String {
        var aid = String()
        guard let jsonResponse = try? JSONDecoder().decode(AnalyticsHitResponse.self, from: response) else {
            Log.debug(label: self.LOG_TAG, "parseIdentifier - Failed to parse analytics server response. Generating an AID.")
            return generateAID()
        }
        aid = jsonResponse.aid ?? ""
        if aid.isEmpty {
            aid = state.isVisitorIdServiceEnabled() ? "" : generateAID()
        }
        return aid
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
