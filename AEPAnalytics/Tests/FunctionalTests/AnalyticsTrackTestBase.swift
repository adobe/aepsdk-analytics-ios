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

class AnalyticsTrackTestBase: AnalyticsFunctionalTestBase {

    var runningForApp = true

    func trackStateTester() {
        let trackData: [String: Any] = [
            CoreConstants.Keys.STATE: "testState",
            CoreConstants.Keys.CONTEXT_DATA: [
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
                "pageName": "testState",
                "mid": "mid",
                "aamb": "blob",
                "aamlh": "lochint",
                "ts": String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        } else {
            expectedVars = [
                "ce": "UTF-8",
                "pageName": "testState",
                "mid": "mid",
                "aamb": "blob",
                "aamlh": "lochint",
                "ts": String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        }

        let expectedContextData = [
            "k1": "v1",
            "k2": "v2"
        ]

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }

     func trackStateEmptyTester() {
        let lifecycleSharedState: [String: Any] = [
            AnalyticsTestConstants.Lifecycle.EventDataKeys.LIFECYCLE_CONTEXT_DATA: [
                AnalyticsTestConstants.Lifecycle.EventDataKeys.APP_ID: "mockAppName"
            ]
        ]

        simulateLifecycleState(data: lifecycleSharedState)

        let trackData: [String: Any] = [
            CoreConstants.Keys.STATE: CoreConstants.Keys.STATE.isEmpty,
            CoreConstants.Keys.CONTEXT_DATA: [
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
                "pageName": "mockAppName",
                "mid": "mid",
                "aamb": "blob",
                "aamlh": "lochint",
                "ts": String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        } else {
            expectedVars = [
                "ce": "UTF-8",
                "pageName": "mockAppName",
                "mid": "mid",
                "aamb": "blob",
                "aamlh": "lochint",
                "ts": String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        }

        let expectedContextData = [
            "k1": "v1",
            "k2": "v2",
            "a.AppID": "mockAppName"
        ]

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }

    func trackActionTester() {
        let trackData: [String: Any] = [
            CoreConstants.Keys.ACTION: "testAction",
            CoreConstants.Keys.CONTEXT_DATA: [
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
                "pev2": "AMACTION:testAction",
                "pe": "lnk_o",
                "mid": "mid",
                "aamb": "blob",
                "aamlh": "lochint",
                "ts": String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        } else {
            expectedVars = [
                "ce": "UTF-8",
                "pev2": "AMACTION:testAction",
                "pe": "lnk_o",
                "mid": "mid",
                "aamb": "blob",
                "aamlh": "lochint",
                "ts": String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        }

        let expectedContextData = [
            "k1": "v1",
            "k2": "v2",
            "a.action": "testAction"
        ]

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }

    func trackActionEmptyTester() {

        let lifecycleSharedState: [String: Any] = [
            AnalyticsTestConstants.Lifecycle.EventDataKeys.LIFECYCLE_CONTEXT_DATA: [
                AnalyticsTestConstants.Lifecycle.EventDataKeys.APP_ID: "mockAppName"
            ]
        ]

        simulateLifecycleState(data: lifecycleSharedState)

        let trackData: [String: Any] = [
            CoreConstants.Keys.ACTION: CoreConstants.Keys.ACTION.isEmpty,
            CoreConstants.Keys.CONTEXT_DATA: [
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
                // no pev2 and pe
                "ce": "UTF-8",
                "cp": "foreground",
                "pageName": "mockAppName",
                "mid": "mid",
                "aamb": "blob",
                "aamlh": "lochint",
                "ts": String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        } else {
            expectedVars = [
                "ce": "UTF-8",
                "mid": "mid",
                "pageName": "mockAppName",
                "aamb": "blob",
                "aamlh": "lochint",
                "ts": String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        }

        let expectedContextData = [
            "k1": "v1",
            "k2": "v2",
            "a.AppID": "mockAppName"
        ]

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }

    func trackInternalActionTester() {
        let trackData: [String: Any] = [
            CoreConstants.Keys.ACTION: "testAction",
            AnalyticsConstants.EventDataKeys.TRACK_INTERNAL: true,
            CoreConstants.Keys.CONTEXT_DATA: [
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
                "pev2": "ADBINTERNAL:testAction",
                "pe": "lnk_o",
                "mid": "mid",
                "aamb": "blob",
                "aamlh": "lochint",
                "ts": String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        } else {
            expectedVars = [
                "ce": "UTF-8",
                "pev2": "ADBINTERNAL:testAction",
                "pe": "lnk_o",
                "mid": "mid",
                "aamb": "blob",
                "aamlh": "lochint",
                "ts": String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        }

        let expectedContextData = [
            "k1": "v1",
            "k2": "v2",
            "a.internalaction": "testAction"
        ]

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }

    func trackOnlyContextDataTester() {
        let trackData: [String: Any] = [
            CoreConstants.Keys.CONTEXT_DATA: [
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
                "mid": "mid",
                "aamb": "blob",
                "aamlh": "lochint",
                "ts": String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        } else {
            expectedVars = [
                "ce": "UTF-8",
                "mid": "mid",
                "aamb": "blob",
                "aamlh": "lochint",
                "ts": String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        }

        let expectedContextData = [
            "k1": "v1",
            "k2": "v2"
        ]

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }

    func trackOverrideExistingContextDataTester() {
        let lifecycleData = [
            AnalyticsConstants.Lifecycle.EventDataKeys.APP_ID: "originalAppID",
            AnalyticsConstants.Lifecycle.EventDataKeys.DEVICE_NAME: "originalDeviceName",
            AnalyticsConstants.Lifecycle.EventDataKeys.OPERATING_SYSTEM: "originalOS"
        ]
        simulateLifecycleState(data: lifecycleData)

        let trackData: [String: Any] = [
            CoreConstants.Keys.CONTEXT_DATA: [
                "k1": "v1",
                "k2": "v2",
                "a.AppID": "overwrittenApp",
                "a.DeviceName": "overwrittenDevice",
                "a.OSVersion": "overwrittenOS"
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
                "mid": "mid",
                "aamb": "blob",
                "aamlh": "lochint",
                "ts": String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        } else {
            expectedVars = [
                "ce": "UTF-8",
                "mid": "mid",
                "aamb": "blob",
                "aamlh": "lochint",
                "ts": String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        }
        let expectedContextData = [
            "k1": "v1",
            "k2": "v2",
            "a.AppID": "overwrittenApp",
            "a.DeviceName": "overwrittenDevice",
            "a.OSVersion": "overwrittenOS"
        ]

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }

    // TrackState and Action should populate linkTrackVars
    func trackStateAndActionTester() {
        let trackData: [String: Any] = [
            CoreConstants.Keys.ACTION: "testAction",
            CoreConstants.Keys.STATE: "testState",
            CoreConstants.Keys.CONTEXT_DATA: [
                "k1": "v1",
                "k2": "v2",
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
                "pageName": "testState",
                "pev2": "AMACTION:testAction",
                "pe": "lnk_o",
                "mid": "mid",
                "aamb": "blob",
                "aamlh": "lochint",
                "ts": String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        } else {
            expectedVars = [
                "ce": "UTF-8",
                "pageName": "testState",
                "pev2": "AMACTION:testAction",
                "pe": "lnk_o",
                "mid": "mid",
                "aamb": "blob",
                "aamlh": "lochint",
                "ts": String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        }
        let expectedContextData = [
            "k1": "v1",
            "k2": "v2",
            "a.action": "testAction"
        ]

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }

    // Track special characters
    func trackSpecialCharactersTester() {
        let trackData: [String: Any] = [
            CoreConstants.Keys.ACTION: "网页",
            CoreConstants.Keys.STATE: "~!@#$%^&*()_.-+",
            CoreConstants.Keys.CONTEXT_DATA: [
                "~!@#$%^&*()_.-+": "~!@#$%^&*()_.-+", // Characters other than _ are ignored
                "网页": "网页", // This key is ignored
                "k1": "网页"
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
                "pageName": "~!@#$%^&*()_.-+",
                "pev2": "AMACTION:网页",
                "pe": "lnk_o",
                "mid": "mid",
                "aamb": "blob",
                "aamlh": "lochint",
                "ts": String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        } else {
            expectedVars = [
                "ce": "UTF-8",
                "pageName": "~!@#$%^&*()_.-+",
                "pev2": "AMACTION:网页",
                "pe": "lnk_o",
                "mid": "mid",
                "aamb": "blob",
                "aamlh": "lochint",
                "ts": String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        }

        let expectedContextData = [
            "_": "~!@#$%^&*()_.-+",
            "a.action": "网页",
            "k1": "网页"
        ]

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }

    func trackContextDataWithNonStringValuesTester() {
        MobileCore.setLogLevel(.trace)
        let trackData: [String: Any] = [
            CoreConstants.Keys.CONTEXT_DATA: [
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
                "DictValue": [String: String]()
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
                "mid": "mid",
                "aamb": "blob",
                "aamlh": "lochint",
                "ts": String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        } else {
            expectedVars = [
                "ce": "UTF-8",
                "mid": "mid",
                "aamb": "blob",
                "aamlh": "lochint",
                "ts": String(trackEvent.timestamp.getUnixTimeInSeconds())
            ]
        }
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
