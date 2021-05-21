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
        super.setupBase(disableIdRequest: false)
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
                
        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 2)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[1],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }
        
    func testHitsContainAIDandVID() {
        let dataStore = NamedCollectionDataStore(name: AnalyticsTestConstants.DATASTORE_NAME)
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.IGNORE_AID, value: false)
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.AID, value: "testaid")
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.VID, value: "testvid")
        
        mockNetworkService?.reset()
        resetExtension()
        
        dispatchDefaultConfigAndIdentityStates()
        waitForProcessing()
        
        
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
    
    //Request to get AID should return the fetched AID if privacy OPT_IN
    func testFetchAID() {
        let aidResponse = """
        {
            "id": "7A57620BB5CA4754-30BDF2392F2416C7"
        }
        """
        mockNetworkService?.expectedResponse = HttpConnection(data: aidResponse.data(using: .utf8) , response: HTTPURLResponse(url: URL(string: "test.com")!, statusCode: 200, httpVersion: nil, headerFields: nil), error: nil)
        
        dispatchDefaultConfigAndIdentityStates()
                
        waitForProcessing()
        
        // Id request was succesfully sent
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0], host: "https://test.com/id?mcorgid=orgid&mid=mid")
        
        // Analytics response context with AID was dispatched
        verifyIdentityChange(aid: "7A57620BB5CA4754-30BDF2392F2416C7", vid: nil)
    }
    
    //Request to get AID should return generated AID if privacy UNKNOWN and no stored AID
    func testAIDOptUnknown() {
        dispatchDefaultConfigAndIdentityStates(configData: [
            AnalyticsTestConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY : "optunknown"
        ])
        waitForProcessing()
        
        // No id request should be sent
        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 0)
        
        // Analytics response context with AID was dispatched
        verifyIdentityChange(aid: "*", vid: nil)
    }
    
    //Request to get AID should return the stored AID if privacy UNKNOWN
    func testAIDPersistence() {
        let aidResponse = """
        {
            "id": "7A57620BB5CA4754-30BDF2392F2416C7"
        }
        """
        mockNetworkService?.expectedResponse = HttpConnection(data: aidResponse.data(using: .utf8) , response: HTTPURLResponse(url: URL(string: "test.com")!, statusCode: 200, httpVersion: nil, headerFields: nil), error: nil)
        
        dispatchDefaultConfigAndIdentityStates()
                
        waitForProcessing()
                
        // Id request was succesfully sent
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0], host: "https://test.com/id?mcorgid=orgid&mid=mid")
        
        verifyIdentityChange(aid: "7A57620BB5CA4754-30BDF2392F2416C7", vid: nil)
        
        // 2nd launch
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()
        mockNetworkService?.reset()
        resetExtension()
        
        dispatchDefaultConfigAndIdentityStates()
        waitForProcessing()
        
        // No id request should be sent
        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 0)
        
        verifyIdentityChange(aid: "7A57620BB5CA4754-30BDF2392F2416C7", vid: nil)
    }
        
    //Request to get AID should return empty AID if privacy OPT_OUT
    func testAIDOptOut() {
        dispatchDefaultConfigAndIdentityStates(configData: [
            AnalyticsTestConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY : "optedout"
        ])
        
        waitForProcessing()
                                
        // No id request should be sent
        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 0)
        // Shared state should be cleared
        verifyIdentityChange(aid: nil, vid: nil)
    }
    
    //Request to get AID should return empty string if the server returned an invalid AID and Visitor ID Service is enabled
    func testInvalidAIDResponseVisitorEnabled() {
        let aidResponse = """
        {
            "id": "Not33Length"
        }
        """
        mockNetworkService?.expectedResponse = HttpConnection(data: aidResponse.data(using: .utf8) , response: HTTPURLResponse(url: URL(string: "test.com")!, statusCode: 200, httpVersion: nil, headerFields: nil), error: nil)
        
        dispatchDefaultConfigAndIdentityStates()
                
        waitForProcessing()
                                
        // No id request should be sent
        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        // Should not generate aid as visitor service is configured
        verifyIdentityChange(aid: nil, vid: nil)
    }
    
    //Request to get AID should return generated AID if the server returned an invalid AID and Visitor ID Service is disabled
    func testInvalidAIDResponseVisitorDisabled() {
        let aidResponse = """
        {
            "id": "Not33Length"
        }
        """
        mockNetworkService?.expectedResponse = HttpConnection(data: aidResponse.data(using: .utf8) , response: HTTPURLResponse(url: URL(string: "test.com")!, statusCode: 200, httpVersion: nil, headerFields: nil), error: nil)
        
        dispatchDefaultConfigAndIdentityStates(configData: [
            AnalyticsTestConstants.Configuration.EventDataKeys.MARKETING_CLOUD_ORGID_KEY : ""
        ])
                
        waitForProcessing()
        
        verifyIdentityChange(aid: "*", vid: nil)
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
    
    func testHandleRequestResetEvent() {
        let dataStore = NamedCollectionDataStore(name: AnalyticsTestConstants.DATASTORE_NAME)
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.MOST_RECENT_HIT_TIMESTAMP, value: TimeInterval(100))
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.IGNORE_AID, value: true)
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.AID, value: "testaid")
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.VID, value: "testvid")
        
        mockNetworkService?.reset()
        resetExtension()
        
        dispatchDefaultConfigAndIdentityStates()
        waitForProcessing()
        
        let analyticsProperties = analytics.analyticsProperties
        let analyticsState = analytics.analyticsState
        
        XCTAssertEqual(true, analyticsProperties.getIgnoreAidStatus())
        XCTAssertEqual("testvid", analyticsProperties.getVisitorIdentifier())
        XCTAssertEqual("testaid", analyticsProperties.getAnalyticsIdentifier())
        XCTAssertEqual(100, analyticsProperties.getMostRecentHitTimestamp())
        
        XCTAssertEqual(analyticsState.host, "test.com")
        XCTAssertEqual(analyticsState.rsids, "rsid")
        XCTAssertFalse(analyticsState.analyticForwardingEnabled)
        XCTAssertTrue(analyticsState.offlineEnabled)
        XCTAssertEqual(analyticsState.launchHitDelay, 0 , accuracy: 0)
        XCTAssertEqual(analyticsState.marketingCloudOrganizationId, "orgid")
        XCTAssertTrue(analyticsState.backDateSessionInfoEnabled)
        XCTAssertEqual(analyticsState.privacyStatus, PrivacyStatus.optedIn)
        XCTAssertEqual(analyticsState.marketingCloudId, "mid")
        XCTAssertEqual(analyticsState.blob, "blob")
        XCTAssertEqual(analyticsState.locationHint, "lochint")
        
        let resetEvent = Event(name: "test reset event", type: EventType.genericIdentity, source: EventSource.requestReset, data: nil)

        // test
        mockRuntime.simulateComingEvent(event: resetEvent)
        
        waitForProcessing()
        
        // should reset
        XCTAssertEqual(false, analyticsProperties.getIgnoreAidStatus())
        XCTAssertNil(analyticsProperties.getVisitorIdentifier())
        XCTAssertNil(analyticsProperties.getAnalyticsIdentifier())
        XCTAssertEqual(0, analyticsProperties.getMostRecentHitTimestamp())
        
        XCTAssertNil(analyticsState.marketingCloudId)
        XCTAssertNil(analyticsState.blob)
        XCTAssertNil(analyticsState.locationHint)
        XCTAssertNil(analyticsState.advertisingId)
        XCTAssertNil(analyticsState.serializedVisitorIdsList)
        XCTAssertNil(analyticsState.marketingCloudOrganizationId)
        XCTAssertTrue(analyticsState.defaultData.isEmpty)
        
        //should not reset
        XCTAssertEqual(analyticsState.host, "test.com")
        XCTAssertEqual(analyticsState.rsids, "rsid")
        XCTAssertFalse(analyticsState.analyticForwardingEnabled)
        XCTAssertTrue(analyticsState.offlineEnabled)
        XCTAssertEqual(analyticsState.launchHitDelay, 0 , accuracy: 0)
        XCTAssertTrue(analyticsState.backDateSessionInfoEnabled)
        XCTAssertEqual(analyticsState.privacyStatus, PrivacyStatus.optedIn)
    }
}
