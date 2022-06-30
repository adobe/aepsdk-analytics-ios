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
class AnalyticsAppExtConsequenceTests: AnalyticsConsequenceTestBase {
    override func setUp() {
        super.setupBase(forApp: false)
        dispatchDefaultConfigAndIdentityStates()
    }
    

    func testHandleAnalyticsConsequence() {
        MobileCore.setLogLevel(.trace)
        let eventData: [String: Any] = [
            AnalyticsConstants.EventDataKeys.TRIGGERED_CONSEQUENCE: [
                AnalyticsConstants.EventDataKeys.ID: "id",
                AnalyticsConstants.EventDataKeys.TYPE: "an",
                AnalyticsConstants.EventDataKeys.DETAIL : [
                    "action" : "testActionName",
                    "contextdata": ["k1" : "v1" , "k2" : "v2"]
                ]
            ]
        ]
        let ruleEngineEvent = Event(name: "Rule event", type: EventType.rulesEngine, source: EventSource.responseContent, data: eventData)
        mockRuntime.simulateComingEvent(event: ruleEngineEvent)
        waitForProcessing()
        
        let expectedVars = [
            "ce": "UTF-8",
            "pev2" : "AMACTION:testActionName",
            "pe" : "lnk_o",
            "mid" : "mid",
            "aamb" : "blob",
            "aamlh" : "lochint",
            "ts" : String(ruleEngineEvent.timestamp.getUnixTimeInSeconds())
        ]
        let expectedContextData = [
            "k1" : "v1",
            "k2" : "v2",
            "a.action" : "testActionName",
        ]
                
        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }
    
    func testSkipNonAnalyticsConsequence() {
        skipNonAnalyticsConsequence()
    }
}
