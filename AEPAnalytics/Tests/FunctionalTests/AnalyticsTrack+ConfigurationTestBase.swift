/*
 Copyright 2021 Adobe. All rights reserved.
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
class AnalyticsTrack_ConfigurationTestBase : AnalyticsFunctionalTestBase {

    var runningForApp = true

    func clearQueuedHitsAndDatastoreOnOptOutTester() {
        // add data to datastore
        let dataStore = NamedCollectionDataStore(name: AnalyticsTestConstants.DATASTORE_NAME)
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.AID, value: "aid")
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.VID, value: "vid")
        resetExtension(forApp: runningForApp)
        // set privacy status to unknown
        dispatchDefaultConfigAndIdentityStates(configData: [AnalyticsTestConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY: "unknown"])
        // dispatch 3 track events
        let trackData: [String: Any] = [
            CoreConstants.Keys.STATE : "testState",
            CoreConstants.Keys.CONTEXT_DATA : [
                "k1": "v1",
                "k2": "v2"
            ]
        ]
        let trackEvent = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: trackEvent)
        mockRuntime.simulateComingEvent(event: trackEvent)
        mockRuntime.simulateComingEvent(event: trackEvent)
        waitForProcessing()

        // verify datastore values set
        XCTAssertEqual("aid", dataStore.getString(key: AnalyticsTestConstants.DataStoreKeys.AID))
        XCTAssertEqual("vid", dataStore.getString(key: AnalyticsTestConstants.DataStoreKeys.VID))
        // verify 3 hits queued
        dispatchGetQueueSize()
        waitForProcessing()
        verifyQueueSize(size: 3)
        // set privacy status to opt out
        dispatchDefaultConfigAndIdentityStates(configData: [AnalyticsTestConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY: "optedout"])
        waitForProcessing()
        // verify datastore values cleared
        XCTAssertNil(dataStore.getString(key: AnalyticsTestConstants.DataStoreKeys.AID))
        XCTAssertNil(dataStore.getString(key: AnalyticsTestConstants.DataStoreKeys.VID))
        // verify no hits are sent
        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count , 0)
        // verify 0 hits queued
        dispatchGetQueueSize()
        waitForProcessing()
        verifyQueueSize(size: 0)
    }

    //Track hits queued when Privacy Status is unknown will be sent with unknown param
    func sendTrackAfterPrivacyStatusIsUnknownToOptedInTester() {
        // set privacy status to unknown
        dispatchDefaultConfigAndIdentityStates(configData: [AnalyticsTestConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY: "unknown"])

        // dispatch track event
        let trackData: [String: Any] = [
            CoreConstants.Keys.STATE : "testState",
            CoreConstants.Keys.CONTEXT_DATA : [
                "k1": "v1",
                "k2": "v2"
            ]
        ]
        let trackEvent = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: trackEvent)
        waitForProcessing()

        // set privacy status to optin
        dispatchDefaultConfigAndIdentityStates(configData: [AnalyticsTestConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY: "optedin"])
        waitForProcessing()
        let expectedVars: [String: String]
        if runningForApp {
            expectedVars = [
                "ce": "UTF-8",
                "cp": "foreground",
                "pageName" : "testState",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        } else {
            expectedVars = [
                "ce": "UTF-8",
                "pageName" : "testState",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        }

        let expectedContextData = [
            "k1" : "v1",
            "k2" : "v2",
            "a.privacy.mode" : "unknown"
        ]

        // verify
        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }


    //Track hits sent only when configuration contains valid server and rsid(s)
    func trackHitsOnlySentOnValidConfigurationTester() {
        // setup config without analytics server and rsid
        dispatchDefaultConfigAndIdentityStates(configData: [AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_REPORT_SUITES: "", AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_SERVER: ""])

        // dispatch track event
        let trackData: [String: Any] = [
            CoreConstants.Keys.STATE : "testState",
            CoreConstants.Keys.CONTEXT_DATA : [
                "k1": "v1",
                "k2": "v2"
            ]
        ]
        let trackEvent = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: trackEvent)
        waitForProcessing()
        // verify no hits sent
        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 0)
        // setup config with analytics server and rsid
        dispatchDefaultConfigAndIdentityStates(configData: [AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_REPORT_SUITES: "rsid", AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_SERVER: "test.com"])
        // dispatch track event
        mockRuntime.simulateComingEvent(event: trackEvent)
        waitForProcessing()
        // verify
        let expectedVars: [String: String]
        if runningForApp {
            expectedVars = [
                "ce": "UTF-8",
                "cp": "foreground",
                "pageName" : "testState",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        } else {
            expectedVars = [
                "ce": "UTF-8",
                "pageName" : "testState",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        }

        let expectedContextData = [
            "k1" : "v1",
            "k2" : "v2",
        ]
        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }

    // Offline hits should not contain timestamp
    func trackHitsOfflineDisabledTester() {
        dispatchDefaultConfigAndIdentityStates(configData: ["analytics.offlineEnabled" : false])
        waitForProcessing()

        let trackData: [String: Any] = [
            CoreConstants.Keys.STATE : "testState",
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
                "pageName" : "testState",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
            ]
        } else {
            expectedVars = [
                "ce": "UTF-8",
                "pageName" : "testState",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
            ]
        }

        let expectedContextData = [
            "k1" : "v1",
            "k2" : "v2",
        ]

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }

    // Offline hits should be dropped after 60 sec
    func trackHitsOfflineDroppedAfterTimeoutTester() {
        dispatchDefaultConfigAndIdentityStates(configData: ["analytics.offlineEnabled" : false])
        waitForProcessing()

        let trackData: [String: Any] = [
            CoreConstants.Keys.STATE : "testState",
            CoreConstants.Keys.CONTEXT_DATA : [
                "k1": "v1",
                "k2": "v2"
            ]
        ]
        let trackEvent = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)

        let trackEventBefore60secs = trackEvent.copyWithNewTimeStamp(Date().addingTimeInterval(-61))


        mockRuntime.simulateComingEvent(event: trackEventBefore60secs)

        waitForProcessing()

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 0)
    }

}
