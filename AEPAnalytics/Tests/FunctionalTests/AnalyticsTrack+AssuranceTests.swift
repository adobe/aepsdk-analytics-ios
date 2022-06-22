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
class AnalyticsTrack_AssuranceTests : AnalyticsFunctionalTestBase {

    override func setUp() {        
        super.setupBase(forApp: true)
    }
    
    //Track with non null assurance session id should append debug flag.
    func testAppendDebugParamInHit() {
        dispatchDefaultConfigAndIdentityStates()
        simulateAssuranceState()
        
        let trackData: [String: Any] = [
            CoreConstants.Keys.ACTION : "testActionName"
        ]
        let event1 = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: event1)
        
        waitForProcessing()
        
        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        let payload = mockNetworkService?.calledNetworkRequests[0]?.payloadAsString()
        XCTAssertTrue(payload?.contains("&p.&debug=true&.p") ?? false)
    }
    
    //Track with non null assurance session id should append debug flag to queued hits.
    func testAppendDebugParamInQueuedHit() {
        dispatchDefaultConfigAndIdentityStates(configData: [
            AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_BATCH_LIMIT : 1
        ])
                
        let trackData: [String: Any] = [
            CoreConstants.Keys.ACTION : "testActionName"
        ]
        let event1 = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: event1)
        
        waitForProcessing()
        
        simulateAssuranceState()
        let event2 = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: event2)
        waitForProcessing()
                
        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 2)
        let payload1 = mockNetworkService?.calledNetworkRequests[0]?.payloadAsString()
        XCTAssertTrue(payload1?.contains("&p.&debug=true&.p") ?? false)
        let payload2 = mockNetworkService?.calledNetworkRequests[0]?.payloadAsString()
        XCTAssertTrue(payload2?.contains("&p.&debug=true&.p") ?? false)
    }
}
