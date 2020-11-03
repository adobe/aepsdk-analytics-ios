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
    public let runtime: ExtensionRuntime

    public let name = AnalyticsConstants.EXTENSION_NAME
    public let friendlyName = AnalyticsConstants.FRIENDLY_NAME
    public static let extensionVersion = AnalyticsConstants.EXTENSION_VERSION
    public let metadata: [String: String]? = nil
    /// A flag that notifies the core sdk if the extension is ready to process next event. This is used as a return value of `readyForEvent` function.
    private var isReadyToForNextEvent = true
    private var analyticsProperties = AnalyticsProperties.init()
    private let analyticsHardDependencies : [String] = [AnalyticsConstants.Configuration.EventDataKeys.SHARED_STATE_NAME, AnalyticsConstants.Identity.EventDataKeys.SHARED_STATE_NAME]
    private let analyticsSoftDependecies : [String] = []
    private var dispatchQueue: DispatchQueue
    //private(set) var state: AnalyticsState?
    // MARK: Extension

    public required init(runtime: ExtensionRuntime) {
        self.runtime = runtime
        dispatchQueue = DispatchQueue(label: name)
        super.init()
    }

    public func onRegistered() {
        registerListener(type: EventType.genericTrack, source: EventSource.requestContent, listener: handleAnalyticsRequest)
//        registerListener(type: EventType.rulesEngine, source: EventSource.responseContent, listener: handleAnalyticsRequest)
//        registerListener(type: EventType.analytics, source: EventSource.requestContent, listener: handleAnalyticsRequest)
//        registerListener(type: EventType.analytics, source: EventSource.requestIdentity, listener: handleAnalyticsRequest)
//        registerListener(type: EventType.configuration, source: EventSource.responseContent, listener: handleAnalyticsRequest)
        registerListener(type: EventType.acquisition, source: EventSource.responseContent, listener: handleAcquisitionEvent)
        registerListener(type: EventType.lifecycle, source: EventSource.responseContent, listener: handleLifecycleEvents)
        registerListener(type: EventType.genericLifecycle, source: EventSource.requestContent, listener: handleLifecycleEvents)
//        registerListener(type: EventType.hub, source: EventSource.sharedState, listener: handleAnalyticsRequest)
    }

    public func onUnregistered() {}

    public func readyForEvent(_ event: Event) -> Bool {
        return isReadyToForNextEvent
    }

    // MARK: Event Listeners
    private func handleAnalyticsRequest(event: Event) {


    }

    /// Handles the following events
    /// `EventType.genericLifecycle` and `EventSource.requestContent`
    /// `EventType.lifecycle` and `EventSource.responseContent`
    /// - Parameter event: the `Event` object to be handled
    private func handleLifecycleEvents(_ event: Event) {

        if event.type == EventType.genericLifecycle && event.source == EventSource.requestContent {
            let sharedStates : [String: [String: Any]?] = getSharedStateForEvent(extensionNames: analyticsHardDependencies + analyticsSoftDependecies, event: event)

            let analyticsState = AnalyticsState.init(dataMap: sharedStates)
            let lifecycleAction = event.data?[AnalyticsConstants.Lifecycle.EventDataKeys.LIFECYCLE_ACTION_KEY] as? String
            if lifecycleAction == AnalyticsConstants.Lifecycle.EventDataKeys.LIFECYCLE_START {
                let previousLifecycleSessionTimestamp = analyticsProperties.lifecyclePreviousSessionPauseTimestamp?.timeIntervalSince1970 ?? 0
                var shouldIgnoreStart : Bool = previousLifecycleSessionTimestamp != 0

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


            }
            else if lifecycleAction == AnalyticsConstants.Lifecycle.EventDataKeys.LIFECYCLE_PAUSE {

            }



        } else if event.type == EventType.lifecycle && event.source == EventSource.responseContent {


        }
    }

    private func getSharedStateForEvent(extensionNames: [String], event: Event? = nil) -> [String: [String: Any]?] {
        var sharedStates = [String: [String: Any]?]()
        for extensionName in extensionNames {
            sharedStates[extensionName] = runtime.getSharedState(extensionName: extensionName, event: event, barrier: true)?.value
        }

        return sharedStates
    }

    /// Handles the following events
    /// `EventType.acquisition` and `EventSource.responseContent`
    /// - Parameter event: The `Event` object to be handled
    private func handleAcquisitionEvent(_ event: Event){
    }

    func waitForLifecycleData() {
        analyticsProperties.lifecycleTimerRunning = true
        dispatchQueue.asyncAfter(deadline: DispatchTime.now() + AnalyticsConstants.Default.LIFECYCLE_RESPONSE_WAIT_TIMEOUT){
            /// - TODO: Kick the database hits.
        }
    }
}
