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

        waitForProcessing()

        let expectedVars = [
            "ce": "UTF-8",
            "cp": "foreground",
            "pageName" : "testState",
            "mid" : "mid",
            "aamb" : "blob",
            "aamlh" : "lochint",
            "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds())
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

        waitForProcessing()

        let expectedVars = [
            "ce": "UTF-8",
            "cp": "foreground",
            "pev2" : "AMACTION:testAction",
            "pe" : "lnk_o",
            "mid" : "mid",
            "aamb" : "blob",
            "aamlh" : "lochint",
            "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds())
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

        waitForProcessing()

        let expectedVars = [
            "ce": "UTF-8",
            "cp": "foreground",
            "pev2" : "ADBINTERNAL:testAction",
            "pe" : "lnk_o",
            "mid" : "mid",
            "aamb" : "blob",
            "aamlh" : "lochint",
            "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds())
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

    func testTrackOnlyContextData() {
        let trackData: [String: Any] = [
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
            "mid" : "mid",
            "aamb" : "blob",
            "aamlh" : "lochint",
            "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds())
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

        waitForProcessing()

        let expectedVars = [
            "ce": "UTF-8",
            "cp": "foreground",
            "mid" : "mid",
            "aamb" : "blob",
            "aamlh" : "lochint",
            "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds())
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

        waitForProcessing()

        let expectedVars = [
            "ce": "UTF-8",
            "cp": "foreground",
            "pageName" : "testState",
            "pev2" : "AMACTION:testAction",
            "pe" : "lnk_o",
            "mid" : "mid",
            "aamb" : "blob",
            "aamlh" : "lochint",
            "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds())
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

    // Track special characters
    func testTrackSpecialCharacters() {
        let trackData: [String: Any] = [
            CoreConstants.Keys.ACTION : "网页",
            CoreConstants.Keys.STATE : "~!@#$%^&*()_.-+",
            CoreConstants.Keys.CONTEXT_DATA : [
                "~!@#$%^&*()_.-+": "~!@#$%^&*()_.-+", // Characters other than _ are ignored
                "网页": "网页", // This key is ignored
                "k1" : "网页"
            ]
        ]

        let trackEvent = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: trackEvent)

        waitForProcessing()

        let expectedVars = [
            "ce": "UTF-8",
            "cp": "foreground",
            "pageName" : "~!@#$%^&*()_.-+",
            "pev2" : "AMACTION:网页",
            "pe" : "lnk_o",
            "mid" : "mid",
            "aamb" : "blob",
            "aamlh" : "lochint",
            "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds())
        ]
        let expectedContextData = [
            "_": "~!@#$%^&*()_.-+",
            "a.action" : "网页",
            "k1" : "网页"
        ]

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }

    func testTrackContextDataWithNonStringValues() {
        MobileCore.setLogLevel(.trace)
        let trackData: [String: Any] = [
            CoreConstants.Keys.CONTEXT_DATA : [
                "StringValue": "v1",
                "IntValue": 1,
                "UIntValue": UInt(2),
                "FloatValue": 3.3,
                "BoolValue": true,
                "CharValue": Character("c"),
                "NSNumberValue": NSNumber(4),
                "NSNumberValue1": NSNumber(5.5),
                "OptionalInt": Optional(Int(6)),
                "OptionalString": Optional("v2"),
                // Keys whose values are not String, Number or Character are dropped
                "Nil": nil,
                "ArrayValue": [String](),
                "ObjValue": NSObject(),
                "DictValue": [String:String]()
            ]
        ]
        let trackEvent = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: trackEvent)

        waitForProcessing()

        let expectedVars = [
            "ce": "UTF-8",
            "cp": "foreground",
            "mid" : "mid",
            "aamb" : "blob",
            "aamlh" : "lochint",
            "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds())
        ]
        let expectedContextData = [
            "StringValue": "v1",
            "IntValue": "1",
            "UIntValue": "2",
            "FloatValue": "3.3",
            "BoolValue": "true",
            "CharValue": "c",
            "NSNumberValue": "4",
            "NSNumberValue1": "5.5",
            "OptionalInt": "6",
            "OptionalString": "v2"
        ]

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }
}
