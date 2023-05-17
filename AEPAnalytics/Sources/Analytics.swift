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

///
/// Analytics extension for the Adobe Experience Platform SDK to be used in iOS Apps.
/// This has full support for all App functionality.
/// Any functionality which is unavailable in App Extensions must be added / overriden in this class.
///
@objc(AEPMobileAnalytics)
@available(iOSApplicationExtension, unavailable)
@available(tvOSApplicationExtension, unavailable)
public class Analytics: AnalyticsBase {

    override func getApplicationStateVar() -> String? {
        return (AnalyticsHelper.getApplicationState() == .background) ? AnalyticsConstants.APP_STATE_BACKGROUND : AnalyticsConstants.APP_STATE_FOREGROUND
    }

}

///
/// Analytics extension for the Adobe Experience Platform SDK to be used in App Extensions (e.g: Action Extension).
/// Any functionality specific to App Extension support should be added to this class
///
@objc(AEPMobileAnalyticsAppExtension)
public class AnalyticsAppExtension: AnalyticsBase {}

///
/// Analytics extension for the Adobe Experience Platform SDK base class which holds all base functionality.
/// Base functionality in this case means all functionality which can be used in both Apps and App Extensions.
/// 
public class AnalyticsBase: NSObject, Extension {
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

    private let analyticsHardDependencies: [String] = [
        AnalyticsConstants.Configuration.EventDataKeys.SHARED_STATE_NAME,
        AnalyticsConstants.Identity.EventDataKeys.SHARED_STATE_NAME
    ]

    private let analyticsSoftDependencies: [String] = [
        AnalyticsConstants.Lifecycle.EventDataKeys.SHARED_STATE_NAME,
        AnalyticsConstants.Assurance.EventDataKeys.SHARED_STATE_NAME,
        AnalyticsConstants.Places.EventDataKeys.SHARED_STATE_NAME
    ]
    // The `DispatchQueue` used to process events in FIFO order and wait for Lifecycle and Acquisition response events.
    private var dispatchQueue: DispatchQueue = DispatchQueue(label: AnalyticsConstants.FRIENDLY_NAME)
    // Maintains the boot up state of sdk. The first shared state update event indicates the boot up completion.
    private var sdkBootUpCompleted = false
    // MARK: Extension

    /// Initializes Analytics extension and its dependencies
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
        /// Internal init added for tests
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

    /// Invoked when the Analytics extension has been registered by the `EventHub`
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
        registerListener(type: EventType.genericIdentity, source: EventSource.requestReset, listener: handleIncomingEvent)
    }

    /// Invoked when the Analytics extension has been unregistered by the `EventHub`, currently a no-op.
    public func onUnregistered() {}

    /// Called before each `Event` processed by Analytics extension
    /// - Parameter event: event that will be processed next
    /// - Returns: *true* if Configuration and Identity shared states are available
    public func readyForEvent(_ event: Event) -> Bool {
        let configurationStatus = getSharedState(extensionName: AnalyticsConstants.Configuration.EventDataKeys.SHARED_STATE_NAME, event: event)?.status ?? .none
        let identityStatus = getSharedState(extensionName: AnalyticsConstants.Identity.EventDataKeys.SHARED_STATE_NAME, event: event)?.status ?? .none
        return configurationStatus == .set && identityStatus == .set
    }

    /// Tries to retrieve the shared data for all the dependencies of the given event. When all the dependencies are resolved, it will update the `AnalyticsState` with the shared states.
    /// - Parameters:
    ///     - event: The `Event` for which shared state is to be retrieved.
    ///     - dependencies: An array of names of event's dependencies.
    private func updateAnalyticsState(forEvent event: Event, dependencies: [String]) {
        var sharedStates = [String: [String: Any]?]()
        for extensionName in dependencies {
            sharedStates[extensionName] = runtime.getSharedState(extensionName: extensionName, event: event, barrier: true)?.value
        }
        analyticsState.update(dataMap: sharedStates)
    }

    /// Handles all `Events` listened by the Analytics Extension. The processing of events will
    /// be done on the Analytics Extension's `DispatchQueue`.
    ///  - Parameter event: the `Event` to be processed
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
            case EventType.genericIdentity:
                if event.source == EventSource.requestReset {
                    self.handleResetIdentitiesEvent(event)
                }
            default:
                break
            }
        }
    }

    ///  Handles the following events
    /// `EventType.rulesEngine` and `EventSource.responseContent`
    ///  - Parameter event: the `Event` to be processed
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

        updateAnalyticsState(forEvent: event, dependencies: analyticsHardDependencies + analyticsSoftDependencies)

        let consequenceDetail = consequence[AnalyticsConstants.EventDataKeys.DETAIL] as? [String: Any] ?? [:]
        handleTrackRequest(event: event, eventData: consequenceDetail)
    }

    /// Handle the following events
    /// `EventType.genericTrack` and `EventSource.requestContent`
    ///  - Parameter event: the `Event` to be processed
    private func handleGenericTrackEvent(_ event: Event) {
        guard event.type == EventType.genericTrack && event.source == EventSource.requestContent else {
            Log.debug(label: LOG_TAG, "handleAnalyticsTrackEvent - Ignoring track event (event is of unexpected type or source).")
            return
        }

        updateAnalyticsState(forEvent: event, dependencies: analyticsHardDependencies + analyticsSoftDependencies)
        handleTrackRequest(event: event, eventData: event.data)
    }

    /// Handles track request from following events
    /// `EventType.genericTrack` and `EventSource.requestContent`
    /// `EventType.rulesEngine` and `EventSource.responseContent`
    /// `EventType.analytics` and `EventSource.requestContent`
    ///  - Parameter event: the `Event` to be processed
    ///  - Parameter eventData: the track state/action data.
    private func handleTrackRequest(event: Event, eventData: [String: Any]?) {
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

    /// Handle the following events
    /// `EventType.configuration` and `EventSource.responseContent`
    ///  - Parameter event: the `Event` to be processed
    private func handleConfigurationResponseEvent(_ event: Event) {
        updateAnalyticsState(forEvent: event, dependencies: analyticsHardDependencies + analyticsSoftDependencies)

        if analyticsState.privacyStatus == .optedOut {
            handleOptOut(event: event)
        } else if analyticsState.privacyStatus == .optedIn {
            analyticsDatabase?.kick(ignoreBatchLimit: false)
        }

        if !sdkBootUpCompleted {
            Log.trace(label: LOG_TAG, "handleConfigurationResponseEvent - Publish analytics shared state on bootup.")
            sdkBootUpCompleted = true
            publishAnalyticsId(event: event)
        }
    }

    /// Clears all the Analytics Properties and any queued hits in AnalyticsDatabase.
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
            updateAnalyticsState(forEvent: event, dependencies: analyticsHardDependencies + analyticsSoftDependencies)
            trackLifecycle(event: event)
        }
    }

    /// Handles the following events
    /// `EventType.acquisition` and `EventSource.responseContent`
    /// - Parameter event: The `Event` to be processed.
    private func handleAcquisitionEvent(_ event: Event) {
        if event.type == EventType.acquisition && event.source == EventSource.responseContent {
            updateAnalyticsState(forEvent: event, dependencies: analyticsHardDependencies + analyticsSoftDependencies)
            trackAcquisitionData(event: event)
        }
    }

    /// Handles the following events
    /// `EventType.analytics` and `EventSource.requestIdentity`
    /// - Parameter event: The `Event` to be processed.
    private func handleAnalyticsRequestIdentityEvent(_ event: Event) {
        if let vid = event.data?[AnalyticsConstants.EventDataKeys.VISITOR_IDENTIFIER] as? String {
            if analyticsState.privacyStatus != .optedOut {
                // Persist the visitor identifier
                analyticsProperties.setVisitorIdentifier(vid: vid)
            } else {
                Log.debug(label: LOG_TAG, "handleAnalyticsRequestIdentityEvent - Privacy is opted out, ignoring the update visitor identifier request.")
            }
        }

        publishAnalyticsId(event: event)
    }

    /// Handles the following events
    /// `EventType.analytics` and `EventSource.requestContent`
    ///  The Analytics Request Content event can contain a clearQueue, getQueueSize, sendQueuedHits, or internal track event.
    ///  If it is an internal track event, an internal track request will be queued containing the event's context data and action name.
    /// - Parameter event: The `Event` to be processed.
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
            analyticsDatabase?.kick(ignoreBatchLimit: true)
        } else { // this is an internal track action / state event
            updateAnalyticsState(forEvent: event, dependencies: analyticsHardDependencies + analyticsSoftDependencies)
            handleTrackRequest(event: event, eventData: eventData)
        }
    }

    /// Processes Reset identities event
    /// - Parameter:
    ///   - event: The Reset identities event
    private func handleResetIdentitiesEvent(_ event: Event) {
        Log.debug(label: LOG_TAG, "\(#function) - Resetting all identifiers.")
        analyticsDatabase?.reset()
        analyticsState.resetIdentities()
        analyticsProperties.reset()
        analyticsState.lastResetIdentitiesTimestamp = event.timestamp.timeIntervalSince1970
        createSharedState(data: getSharedState(), event: event)
    }

    /// Dispatches event of type `EventType.analytics` and source `EventSource.responseContent` event with persisted ids and also updates analytics shared state.
    /// - Parameters:
    ///     - event: The `Event` to publish shared state.
    private func publishAnalyticsId(event: Event) {
        let data = getSharedState()
        createSharedState(data: data, event: event)
        dispatchAnalyticsIdentityResponse(event: event, data: data)
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
    ///   - data: the event which triggered the analytics identity request.
    private func dispatchAnalyticsIdentityResponse(event: Event, data: [String: Any]) {
        let responseIdentityEvent = event.createResponseEvent(name: "TrackingIdentifierValue", type: EventType.analytics, source: EventSource.responseIdentity, data: data)
        dispatch(event: responseIdentityEvent)
    }

    /// Dispatches an analytics response content event containing the queue size.
    /// - Parameters:
    ///   - event: the analytics request content event.
    private func dispatchQueueSizeResponse(event: Event, queueSize: Int) {
        let eventData = [
            AnalyticsConstants.EventDataKeys.QUEUE_SIZE: queueSize
        ]
        Log.debug(label: self.LOG_TAG, "DispatchQueueSize - Dispatching Analytics hit queue size response event with eventdata \(eventData)")
        let responseContentEvent = event.createResponseEvent(name: "QueueSizeValue", type: EventType.analytics, source: EventSource.responseContent, data: eventData)
        dispatch(event: responseContentEvent)
    }

    /// Dispatches an analytics response content event
    /// - Parameters:
    ///   - eventData: the response event data which includes serverResponse, headers, requestEventIdentifier, hitHost and hitURL corresponding to track request.
    private func dispatchAnalyticsTrackResponse(eventData: [String: Any]) {
        let responseEvent = Event.init(name: "AnalyticsResponse", type: EventType.analytics, source: EventSource.responseContent, data: eventData)
        dispatch(event: responseEvent)
    }

    /// Converts the lifecycle event in internal analytics action. If backdate session and offline tracking are enabled,
    /// and previous session length is present in the contextData map, we send a separate hit with the previous session information and the rest of the keys as a Lifecycle action hit.
    /// If ignored session is present, it will be sent as part of the Lifecycle hit and no SessionInfo hit will be sent.
    /// - Parameters:
    ///     - event: the `Lifecycle Event` to process.
    private func trackLifecycle(event: Event) {
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
    private func trackAcquisitionData(event: Event) {
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
    private func track(eventData: [String: Any]?, timeStampInSeconds: TimeInterval, isBackdatedHit: Bool, eventUniqueIdentifier: String) {
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

        let analyticsData = processAnalyticsContextData(trackData: eventData, timestamp: timeStampInSeconds)
        let analyticsVars = processAnalyticsVars(trackData: eventData, timestamp: timeStampInSeconds)

        let payload = URL.buildAnalyticsPayload(analyticsState: analyticsState, data: analyticsData, vars: analyticsVars)

        analyticsDatabase?.queue(payload: payload, timestamp: timeStampInSeconds, eventIdentifier: eventUniqueIdentifier, isBackdateHit: isBackdatedHit)
    }

    /// Creates the context data Dictionary from the `trackData`
    /// - Parameters:
    ///     - trackData: Dictionary containing tracking data
    ///     - timestamp: timestamp to use for tracking
    ///     - Returns a `Dictionary` containing the context data.
    private func processAnalyticsContextData(trackData: [String: Any]?, timestamp: TimeInterval) -> [String: String] {
        guard let trackData = trackData else {
            Log.debug(label: LOG_TAG, "processAnalyticsContextData - trackData is nil.")
            return [:]
        }

        var analyticsData = analyticsState.defaultData
        if let contextData = cleanContextData(trackData[AnalyticsConstants.EventDataKeys.CONTEXT_DATA] as? [String: Any?]) {
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
            let timeSinceLaunchInSeconds = timestamp - lifecycleSessionStartTimestamp
            if timeSinceLaunchInSeconds > 0 && timeSinceLaunchInSeconds.isLessThanOrEqualTo(analyticsState.lifecycleMaxSessionLength) {
                analyticsData[AnalyticsConstants.ContextDataKeys.TIME_SINCE_LAUNCH_KEY] = String(Int64(timeSinceLaunchInSeconds))
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
    private func processAnalyticsVars(trackData: [String: Any]?, timestamp: TimeInterval) -> [String: String] {
        var analyticsVars: [String: String] = [:]

        guard let trackData = trackData else {
            Log.debug(label: LOG_TAG, "processAnalyticsVars - track event data is nil.")
            return analyticsVars
        }

        if let actionName = trackData[AnalyticsConstants.EventDataKeys.TRACK_ACTION] as? String, !actionName.isEmpty {
            analyticsVars[AnalyticsConstants.Request.IGNORE_PAGE_NAME_KEY] = AnalyticsConstants.IGNORE_PAGE_NAME_VALUE
            let isInternal = trackData[AnalyticsConstants.EventDataKeys.TRACK_INTERNAL] as? Bool ?? false
            let actionNameWithPrefix = "\(isInternal ? AnalyticsConstants.INTERNAL_ACTION_PREFIX : AnalyticsConstants.ACTION_PREFIX)\(actionName)"
            analyticsVars[AnalyticsConstants.Request.ACTION_NAME_KEY] = actionNameWithPrefix
        }
        analyticsVars[AnalyticsConstants.Request.PAGE_NAME_KEY] = analyticsState.applicationId
        if let stateName = trackData[AnalyticsConstants.EventDataKeys.TRACK_STATE] as? String, !stateName.isEmpty {
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
            analyticsVars[AnalyticsConstants.Request.STRING_TIMESTAMP_KEY] = String((Int64(timestamp)))
        }

        if analyticsState.isVisitorIdServiceEnabled() {
            analyticsVars.merge(analyticsState.getAnalyticsIdVisitorParameters()) { _, newValue in
                return newValue
            }
        }

        if let appState = getApplicationStateVar() {
            analyticsVars[AnalyticsConstants.Request.CUSTOMER_PERSPECTIVE_KEY] = appState
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
    private func waitForLifecycleData() {
        Log.debug(label: "Analytics", "waitForLifecycleData - Lifecycle timer scheduled with timeout \(AnalyticsConstants.Default.LIFECYCLE_RESPONSE_WAIT_TIMEOUT)")
        analyticsDatabase?.waitForAdditionalData(type: .lifecycle)
        analyticsTimer.startLifecycleTimer(timeout: AnalyticsConstants.Default.LIFECYCLE_RESPONSE_WAIT_TIMEOUT) { [weak self] in
            Log.warning(label: "Analytics", "waitForLifecycleData - Lifecycle timeout has expired without Lifecycle data")
            self?.analyticsDatabase?.cancelWaitForAdditionalData(type: .lifecycle)
        }
    }

    /// Wait for Acquisition data after receiving Acquisition Response event.
    private func waitForAcquisitionData(timeout: TimeInterval) {
        Log.debug(label: "Analytics", "waitForAcquisitionData - Referrer timer scheduled with timeout \(timeout)")
        analyticsDatabase?.waitForAdditionalData(type: .referrer)
        analyticsTimer.startReferrerTimer(timeout: timeout) { [weak self] in
            Log.warning(label: "Analytics", "WaitForAcquisitionData - Launch hit delay has expired without referrer data.")
            self?.analyticsDatabase?.cancelWaitForAdditionalData(type: .referrer)
        }
    }

    // Provide a function to override for App Extension support
    fileprivate func getApplicationStateVar() -> String? {
        return nil
    }

}

extension AnalyticsBase {
    /// Remove keys with value other than String, Character or a type convertable to NSNumber.
    /// - Parameter data: Analytics context data from track event.
    /// - Returns: Cleaned context data converted to [String: String] dictionary
    func cleanContextData(_ data: [String: Any?]?) -> [String: String]? {
        guard let data = data else {
            return nil
        }

        let cleanedData = data.filter {
            switch $0.value {
            case is NSNumber, is String, is Character:
                return true
            default:
                Log.warning(label: LOG_TAG, "cleanContextData - Dropping Key(\($0.key)) with Value(\(String(describing: $0.value))). Value should be String, Number, Bool or Character")
                return false
            }
        }.mapValues { String(describing: $0!) }
        return cleanedData
    }
}
