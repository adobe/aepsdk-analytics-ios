/*
 Copyright 2022 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import XCTest
import AEPServices
@testable import AEPAnalytics
@testable import AEPCore

@available(tvOSApplicationExtension, unavailable)
class AnalyticsIDTestBase : AnalyticsFunctionalTestBase {

    var runningForApp = true

    //If Visitor ID Service is enabled then analytics hits contain visitor ID vars
    func hitsContainVisitorIDVarsTester() {
        dispatchDefaultConfigAndIdentityStates()

        let trackData: [String: Any] = [
            CoreConstants.Keys.ACTION : "testActionName",
            CoreConstants.Keys.CONTEXT_DATA : [
                "k1": "v1",
                "k2": "v2"
            ]
        ]
        let trackEvent = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)

        mockRuntime.simulateComingEvent(event: trackEvent)

        waitForProcessing()
        let expectedVars: [String: String]
        if runningForApp {
            expectedVars = [
                "ce": "UTF-8",
                "cp": "foreground",
                "pev2" : "AMACTION:testActionName",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds()),
            ]
        } else {
            expectedVars = [
                "ce": "UTF-8",
                "pev2" : "AMACTION:testActionName",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds()),
            ]
        }
        let expectedContextData = [
            "k1" : "v1",
            "k2" : "v2",
            "a.action" : "testActionName"
        ]

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }

    func hitsContainAIDandVIDTester() {
        let dataStore = NamedCollectionDataStore(name: AnalyticsTestConstants.DATASTORE_NAME)
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.AID, value: "testaid")
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.VID, value: "testvid")

        mockNetworkService?.reset()
        resetExtension(forApp: runningForApp)

        dispatchDefaultConfigAndIdentityStates()
        waitForProcessing()

        verifyIdentityChange(aid: "testaid", vid: "testvid")

        let trackData: [String: Any] = [
            CoreConstants.Keys.ACTION : "testActionName",
            CoreConstants.Keys.CONTEXT_DATA : [
                "k1": "v1",
                "k2": "v2"
            ]
        ]
        let trackEvent = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)

        mockRuntime.simulateComingEvent(event: trackEvent)

        waitForProcessing()
        let expectedVars: [String: String]
        if runningForApp {
            expectedVars = [
                "ce": "UTF-8",
                "cp": "foreground",
                "pev2" : "AMACTION:testActionName",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aid" : "testaid",
                "vid" : "testvid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds()),
            ]
        } else {
            expectedVars = [
                "ce": "UTF-8",
                "pev2" : "AMACTION:testActionName",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aid" : "testaid",
                "vid" : "testvid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds()),
            ]
        }
        let expectedContextData = [
            "k1" : "v1",
            "k2" : "v2",
            "a.action" : "testActionName"
        ]

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }

    func optOut_ShouldNotReadAidVidTester() {
        let dataStore = NamedCollectionDataStore(name: AnalyticsTestConstants.DATASTORE_NAME)
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.AID, value: "testaid")
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.VID, value: "testvid")

        dispatchDefaultConfigAndIdentityStates(configData: [
            AnalyticsTestConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY : "optedout"
        ])

        waitForProcessing()

        verifyIdentityChange(aid: nil, vid: nil)
    }

    // Set visitor id should dispatch event
    func visitorIdTester() {
        dispatchDefaultConfigAndIdentityStates()

        // Set VID
        let data = [AnalyticsTestConstants.EventDataKeys.VISITOR_IDENTIFIER : "myvid"]
        let event = Event(name: "", type: EventType.analytics, source: EventSource.requestIdentity, data: data)
        mockRuntime.simulateComingEvent(event: event)

        waitForProcessing()

        verifyIdentityChange(aid: nil, vid: "myvid")
    }

    // Set visitor id should dispatch event
    func optOut_ShouldNotUpdateVidTester() {
        dispatchDefaultConfigAndIdentityStates(configData: [
            AnalyticsTestConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY : "optedout"
        ])

        // Set VID
        let data = [AnalyticsTestConstants.EventDataKeys.VISITOR_IDENTIFIER : "myvid"]
        let event = Event(name: "", type: EventType.analytics, source: EventSource.requestIdentity, data: data)
        mockRuntime.simulateComingEvent(event: event)

        waitForProcessing()

        verifyIdentityChange(aid: nil, vid: nil)
    }

    func aIDandVIDShouldBeClearedAfterOptOutTester() {
        let dataStore = NamedCollectionDataStore(name: AnalyticsTestConstants.DATASTORE_NAME)
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.AID, value: "testaid")
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.VID, value: "testvid")

        mockNetworkService?.reset()
        resetExtension(forApp: runningForApp)

        dispatchDefaultConfigAndIdentityStates()
        waitForProcessing()

        verifyIdentityChange(aid: "testaid", vid: "testvid")

        dispatchDefaultConfigAndIdentityStates(configData: [
            AnalyticsTestConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY : "optedout"
        ])

        waitForProcessing()
        verifyIdentityChange(aid: nil, vid: nil)
    }

    func handleRequestResetEventTester() {
        let placesSharedState: [String: Any] = [
            AnalyticsTestConstants.Places.EventDataKeys.CURRENT_POI : [
                AnalyticsTestConstants.Places.EventDataKeys.REGION_ID : "myRegionId",
                AnalyticsTestConstants.Places.EventDataKeys.REGION_NAME : "myRegionName"
            ]
        ]
        let lifecycleSharedState: [String: Any] = [
            AnalyticsTestConstants.Lifecycle.EventDataKeys.LIFECYCLE_CONTEXT_DATA : [
                AnalyticsTestConstants.Lifecycle.EventDataKeys.OPERATING_SYSTEM : "mockOSName",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.APP_ID : "mockAppName",
            ]
        ]

        let dataStore = NamedCollectionDataStore(name: AnalyticsTestConstants.DATASTORE_NAME)
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.MOST_RECENT_HIT_TIMESTAMP, value: TimeInterval(100))
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.AID, value: "testaid")
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.VID, value: "testvid")

        mockNetworkService?.reset()
        resetExtension(forApp: runningForApp)


        simulateLifecycleState(data: lifecycleSharedState)
        simulatePlacesState(data: placesSharedState)
        dispatchDefaultConfigAndIdentityStates()
        waitForProcessing()


        verifyIdentityChange(aid: "testaid", vid: "testvid")

        // test
        let resetEvent = Event(name: "test reset event", type: EventType.genericIdentity, source: EventSource.requestReset, data: nil)

        mockRuntime.simulateComingEvent(event: resetEvent)

        waitForProcessing()

        //verify
        verifyIdentityChange(aid: nil, vid: nil)
    }
}
