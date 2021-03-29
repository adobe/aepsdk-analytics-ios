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

class AnalyticsTrack_TargetTests : AnalyticsFunctionalTestBase {

    override func setUp() {
        super.setupBase()
    }

    // Analytics for target event triggers an internal analytics track action request
    func testAnalyticsForTargetRequestEventTriggersA4TTrackAction() {
        dispatchDefaultConfigAndIdentityStates()

        let trackData: [String: Any] = [
            AnalyticsConstants.EventDataKeys.TRACK_ACTION : "AnalyticsForTarget",
            AnalyticsConstants.EventDataKeys.TRACK_INTERNAL: true,
            AnalyticsConstants.EventDataKeys.CONTEXT_DATA : [
                "&&tnta": "285408:0:0|2",
                "&&pe": "tnt",
                "a.target.sessionId" : "8E0988F2-57C7-42CA-B5A6-6458D370F315"
            ]
        ]
        let event1 = Event(name: "A4T track action event", type: EventType.analytics, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: event1)

        waitForProcessing()

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        let payload = mockNetworkService?.calledNetworkRequests[0]?.connectPayload ?? ""
        let contextData = AnalyticsRequestHelper.getContextData(source: payload) as? [String: String]
        XCTAssertEqual("AnalyticsForTarget", contextData?["a.internalaction"])
        XCTAssertEqual("8E0988F2-57C7-42CA-B5A6-6458D370F315", contextData?["a.target.sessionId"])
        XCTAssertTrue(payload.contains("tnta=285408%3A0%3A0%7C2"))
        XCTAssertTrue(payload.contains("&pe=tnt"))
        XCTAssertTrue(payload.contains("&pev2=ADBINTERNAL%3AAnalyticsForTarget"))
    }
}
