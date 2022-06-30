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
class AnalyticsTrack_PlacesTestBase : AnalyticsFunctionalTestBase {

    var runningForApp = true
    
    //If Places shared state is available then analytics hits contain places data
    func analyticsHitsContainPlacesDataTester() {
        let placesSharedState: [String: Any] = [
            AnalyticsTestConstants.Places.EventDataKeys.CURRENT_POI : [
                AnalyticsTestConstants.Places.EventDataKeys.REGION_ID : "myRegionId",
                AnalyticsTestConstants.Places.EventDataKeys.REGION_NAME : "myRegionName"
            ]
        ]
        simulatePlacesState(data: placesSharedState)


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
                "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        } else {
            expectedVars = [
                "ce": "UTF-8",
                "pev2" : "AMACTION:testActionName",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        }
        let expectedContextData = [
            "k1" : "v1",
            "k2" : "v2",
            "a.action" : "testActionName",
            "a.loc.poi.id" : "myRegionId",
            "a.loc.poi" : "myRegionName"
        ]

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }


    // If Places shared state is updated then analytics hits contain updated places data
    func analyticsHitsContainUpdatePlacesDataTester() {
        let placesSharedState: [String: Any] = [
            AnalyticsTestConstants.Places.EventDataKeys.CURRENT_POI : [
                AnalyticsTestConstants.Places.EventDataKeys.REGION_ID : "myRegionId",
                AnalyticsTestConstants.Places.EventDataKeys.REGION_NAME : "myRegionName"
            ]
        ]
        simulatePlacesState(data: placesSharedState)


        let trackData: [String: Any] = [
            CoreConstants.Keys.ACTION : "testActionName",
            CoreConstants.Keys.CONTEXT_DATA : [
                "k1": "v1",
                "k2": "v2"
            ]
        ]
        let trackEvent = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)

        let updatedPlacesState: [String: Any] = [
            AnalyticsTestConstants.Places.EventDataKeys.CURRENT_POI : [
                AnalyticsTestConstants.Places.EventDataKeys.REGION_ID : "myRegionId2",
                AnalyticsTestConstants.Places.EventDataKeys.REGION_NAME : "myRegionName2"
            ]
        ]
        simulatePlacesState(data: updatedPlacesState)

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
                "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        } else {
            expectedVars = [
                "ce": "UTF-8",
                "pev2" : "AMACTION:testActionName",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        }
        let expectedContextData = [
            "k1" : "v1",
            "k2" : "v2",
            "a.action" : "testActionName",
            "a.loc.poi.id" : "myRegionId2",
            "a.loc.poi" : "myRegionName2"
        ]

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }
}
