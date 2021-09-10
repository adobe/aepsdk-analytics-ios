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

class AnalyticsIDTests : AnalyticsFunctionalTestBase {
    
    override func setUp() {
        super.setupBase()
    }
    
    //If Visitor ID Service is enabled then analytics hits contain visitor ID vars
    func testHitsContainVisitorIDVars() {
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
        
        let expectedVars = [
            "ce": "UTF-8",
            "cp": "foreground",
            "pev2" : "AMACTION:testActionName",
            "pe" : "lnk_o",
            "mid" : "mid",
            "aamb" : "blob",
            "aamlh" : "lochint",
            "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds()),
        ]
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
        
    func testHitsContainAIDandVID() {
        let dataStore = NamedCollectionDataStore(name: AnalyticsTestConstants.DATASTORE_NAME)
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.AID, value: "testaid")
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.VID, value: "testvid")
        
        mockNetworkService?.reset()
        resetExtension()
        
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
        
        let expectedVars = [
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
    
    func testOptOut_ShouldNotReadAidVid() {
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
    func testVisitorId() {        
        dispatchDefaultConfigAndIdentityStates()

        // Set VID
        let data = [AnalyticsTestConstants.EventDataKeys.VISITOR_IDENTIFIER : "myvid"]
        let event = Event(name: "", type: EventType.analytics, source: EventSource.requestIdentity, data: data)
        mockRuntime.simulateComingEvent(event: event)
        
        waitForProcessing()
        
        verifyIdentityChange(aid: nil, vid: "myvid")
    }
    
    // Set visitor id should dispatch event
    func testOptOut_ShouldNotUpdateVid() {
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
    
    func testAIDandVIDShouldBeClearedAfterOptOut() {
        let dataStore = NamedCollectionDataStore(name: AnalyticsTestConstants.DATASTORE_NAME)
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.AID, value: "testaid")
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.VID, value: "testvid")
        
        mockNetworkService?.reset()
        resetExtension()
        
        dispatchDefaultConfigAndIdentityStates()
        waitForProcessing()
        
        verifyIdentityChange(aid: "testaid", vid: "testvid")

        dispatchDefaultConfigAndIdentityStates(configData: [
            AnalyticsTestConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY : "optedout"
        ])
        
        waitForProcessing()
        verifyIdentityChange(aid: nil, vid: nil)
    }

}
