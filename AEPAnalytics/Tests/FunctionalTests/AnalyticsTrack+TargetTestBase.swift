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
class AnalyticsTrack_TargetTestBase : AnalyticsFunctionalTestBase {

    var runningForApp = true

    // Analytics for target event triggers an internal analytics track action request
    func analyticsForTargetRequestEventTriggersA4TTrackActionTester() {
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
        let expectedVars: [String: String]
        if runningForApp {
            expectedVars = [
                "ce": "UTF-8",
                "cp": "foreground",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "tnta" : "285408:0:0|2",
                "pe" : "tnt",
                "pev2" : "ADBINTERNAL:AnalyticsForTarget",
                "ts" : String(event1.timestamp.getUnixTimeInSeconds())
            ]
        } else {
            expectedVars = [
                "ce": "UTF-8",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "tnta" : "285408:0:0|2",
                "pe" : "tnt",
                "pev2" : "ADBINTERNAL:AnalyticsForTarget",
                "ts" : String(event1.timestamp.getUnixTimeInSeconds())
            ]
        }

        let expectedContextData = [
            "a.internalaction" : "AnalyticsForTarget",
            "a.target.sessionId" : "8E0988F2-57C7-42CA-B5A6-6458D370F315"
        ]

        // verify
        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }
}
