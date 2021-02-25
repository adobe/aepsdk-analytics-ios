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

class AnalyticsTrackTests : AnalyticsFunctionalTestBase {

    override func setUp() {        
        super.setupBase()
        dispatchDefaultConfigAndIdentityStates()
    }

    // TrackState
    func testTrackState() {
        let trackData: [String: Any] = [
            CoreConstants.Keys.STATE : "testState",
            CoreConstants.Keys.CONTEXT_DATA : [
                "k1": "v1",
                "k2": "v2"
            ]
        ]
        let trackEvent = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: trackEvent)

        waitFor(interval: 1)

        let expectedVars = [
            "ce": "UTF-8",
            "cp": "foreground",
            "ndh": "1",
            "pageName" : "testState",
            "mid" : "mid",
            "aamb" : "blob",
            "aamlh" : "lochint",
            "ts" : String((Int(trackEvent.timestamp.timeIntervalSince1970)))
        ]

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

    // TrackAction
    func testTrackAction() {
        let trackData: [String: Any] = [
            CoreConstants.Keys.ACTION : "testAction",
            CoreConstants.Keys.CONTEXT_DATA : [
                "k1": "v1",
                "k2": "v2"
            ]
        ]
        let trackEvent = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: trackEvent)

        waitFor(interval: 1)

        let expectedVars = [
            "ce": "UTF-8",
            "cp": "foreground",
            "ndh": "1",
            "pev2" : "AMACTION:testAction",
            "pe" : "lnk_o",
            "mid" : "mid",
            "aamb" : "blob",
            "aamlh" : "lochint",
            "ts" : String((Int(trackEvent.timestamp.timeIntervalSince1970)))
        ]
        let expectedContextData = [
            "k1" : "v1",
            "k2" : "v2",
            "a.action" : "testAction",
        ]

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }


    // TrackInternalAction
    func testTrackInternalAction() {
        let trackData: [String: Any] = [
            CoreConstants.Keys.ACTION : "testAction",
            AnalyticsConstants.EventDataKeys.TRACK_INTERNAL : true,
            CoreConstants.Keys.CONTEXT_DATA : [
                "k1": "v1",
                "k2": "v2"
            ]
        ]
        let trackEvent = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: trackEvent)

        waitFor(interval: 1)

        let expectedVars = [
            "ce": "UTF-8",
            "cp": "foreground",
            "ndh": "1",
            "pev2" : "ADBINTERNAL:testAction",
            "pe" : "lnk_o",
            "mid" : "mid",
            "aamb" : "blob",
            "aamlh" : "lochint",
            "ts" : String((Int(trackEvent.timestamp.timeIntervalSince1970)))
        ]
        let expectedContextData = [
            "k1" : "v1",
            "k2" : "v2",
            "a.internalaction" : "testAction",
        ]

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }

    // TrackContextData
    func testTrackContextData() {
        let trackData: [String: Any] = [
            CoreConstants.Keys.CONTEXT_DATA : [
                "k1": "v1",
                "k2": "v2"
            ]
        ]
        let trackEvent = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: trackEvent)

        waitFor(interval: 1)

        let expectedVars = [
            "ce": "UTF-8",
            "cp": "foreground",
            "ndh": "1",
            "mid" : "mid",
            "aamb" : "blob",
            "aamlh" : "lochint",
            "ts" : String((Int(trackEvent.timestamp.timeIntervalSince1970)))
        ]
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

    // TrackOnlyContextData
    func testTrackOnlyContextData() {
        let trackData: [String: Any] = [
            CoreConstants.Keys.CONTEXT_DATA : [
                "k1": "v1",
                "k2": "v2"
            ]
        ]
        let trackEvent = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: trackEvent)

        waitFor(interval: 1)

        let expectedVars = [
            "ce": "UTF-8",
            "cp": "foreground",
            "ndh": "1",
            "mid" : "mid",
            "aamb" : "blob",
            "aamlh" : "lochint",
            "ts" : String((Int(trackEvent.timestamp.timeIntervalSince1970)))
        ]
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

    // TrackShouldOverrideExistingContextData
    func testTrackOverrideExistingContextData() {
        let lifecycleData = [
            AnalyticsConstants.Lifecycle.EventDataKeys.APP_ID : "originalAppID",
            AnalyticsConstants.Lifecycle.EventDataKeys.DEVICE_NAME : "originalDeviceName",
            AnalyticsConstants.Lifecycle.EventDataKeys.OPERATING_SYSTEM : "originalOS"
        ]
        simulateLifecycleState(data: lifecycleData)

        let trackData: [String: Any] = [
            CoreConstants.Keys.CONTEXT_DATA : [
                "k1": "v1",
                "k2": "v2",
                "a.AppID" : "overwrittenApp",
                "a.DeviceName" : "overwrittenDevice",
                "a.OSVersion" : "overwrittenOS",
            ]
        ]

        let trackEvent = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: trackEvent)

        waitFor(interval: 1)

        let expectedVars = [
            "ce": "UTF-8",
            "cp": "foreground",
            "ndh": "1",
            "mid" : "mid",
            "aamb" : "blob",
            "aamlh" : "lochint",
            "ts" : String((Int(trackEvent.timestamp.timeIntervalSince1970)))
        ]
        let expectedContextData = [
            "k1" : "v1",
            "k2" : "v2",
            "a.AppID" : "overwrittenApp",
            "a.DeviceName" : "overwrittenDevice",
            "a.OSVersion" : "overwrittenOS"
        ]

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }


    // TrackState and Action should populate linkTrackVars
    func testTrackStateAndAction() {
        let trackData: [String: Any] = [
            CoreConstants.Keys.ACTION : "testAction",
            CoreConstants.Keys.STATE : "testState",
            CoreConstants.Keys.CONTEXT_DATA : [
                "k1": "v1",
                "k2": "v2",
            ]
        ]

        let trackEvent = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: trackEvent)

        waitFor(interval: 1)

        let expectedVars = [
            "ce": "UTF-8",
            "cp": "foreground",
            "ndh": "1",
            "pageName" : "testState",
            "pev2" : "AMACTION:testAction",
            "pe" : "lnk_o",
            "mid" : "mid",
            "aamb" : "blob",
            "aamlh" : "lochint",
            "ts" : String((Int(trackEvent.timestamp.timeIntervalSince1970)))
        ]
        let expectedContextData = [
            "k1" : "v1",
            "k2" : "v2",
            "a.action" : "testAction",
        ]

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }


}
