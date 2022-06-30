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
class AnalyticsTrack_LifecycleTestBase : AnalyticsFunctionalTestBase {

    var runningForApp = true

    //If Lifecycle shared state is available then analytics hits contain lifecycle vars
    func hitsContainLifecycleVarsTester() {
        dispatchDefaultConfigAndIdentityStates()

        let lifecycleSharedState: [String: Any] = [
            AnalyticsTestConstants.Lifecycle.EventDataKeys.LIFECYCLE_CONTEXT_DATA : [
                AnalyticsTestConstants.Lifecycle.EventDataKeys.OPERATING_SYSTEM : "mockOSName",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.LOCALE : "en-US",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.DEVICE_RESOLUTION : "0x0",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.CARRIER_NAME : "mockMobileCarrier",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.DEVICE_NAME : "mockDeviceBuildId",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.APP_ID : "mockAppName",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.RUN_MODE : "Application"
            ]
        ]
        simulateLifecycleState(data: lifecycleSharedState)

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
                "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds()),
                "pageName" : "mockAppName",
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        } else {
            expectedVars = [
                "ce": "UTF-8",
                "pev2" : "AMACTION:testActionName",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds()),
                "pageName" : "mockAppName",
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        }
        let expectedContextData = [
            "k1" : "v1",
            "k2" : "v2",
            "a.action" : "testActionName",
            "a.AppID" : "mockAppName",
            "a.CarrierName" : "mockMobileCarrier",
            "a.DeviceName"  : "mockDeviceBuildId",
            "a.OSVersion" :  "mockOSName",
            "a.Resolution" : "0x0",
            "a.RunMode" : "Application"
        ]

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }

    //Lifecycle sends a crash event with previous OS version and previous app version if present in response
    func lifecycleBackdatedCrashHitTester() {
        let ts:TimeInterval = 12345678
        let dataStore = NamedCollectionDataStore(name: AnalyticsTestConstants.DATASTORE_NAME)
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.MOST_RECENT_HIT_TIMESTAMP, value: ts)
        resetExtension(forApp: runningForApp)

        dispatchDefaultConfigAndIdentityStates()

        let lifecycleStartData = [
            AnalyticsConstants.Lifecycle.EventDataKeys.LIFECYCLE_ACTION_KEY:
                AnalyticsConstants.Lifecycle.EventDataKeys.LIFECYCLE_START
        ]
        let lifecycleStartEvent = Event(name: "", type: EventType.genericLifecycle, source: EventSource.requestContent, data: lifecycleStartData)
        mockRuntime.simulateComingEvent(event: lifecycleStartEvent)

        let lifecycleSharedState: [String: Any] = [
            AnalyticsTestConstants.Lifecycle.EventDataKeys.LIFECYCLE_CONTEXT_DATA : [
                AnalyticsTestConstants.Lifecycle.EventDataKeys.OPERATING_SYSTEM : "mockOSName",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.LOCALE : "en-US",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.DEVICE_RESOLUTION : "0x0",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.CARRIER_NAME : "mockMobileCarrier",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.DEVICE_NAME : "mockDeviceBuildId",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.APP_ID : "mockAppName",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.RUN_MODE : "Application",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.CRASH_EVENT : "CrashEvent",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.PREVIOUS_OS_VERSION : "previousOSVersion",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.PREVIOUS_APP_ID : "previousAppId"
            ]
        ]
        simulateLifecycleState(data: lifecycleSharedState)
        let lifecycleResponse = Event(name: "", type: EventType.lifecycle, source: EventSource.responseContent, data: lifecycleSharedState)
        mockRuntime.simulateComingEvent(event: lifecycleResponse)
        waitForProcessing()

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 2)
        let crashVars: [String: String]
        if runningForApp {
            // Lifecycle crash hit
            crashVars = [
                "ce": "UTF-8",
                "cp": "foreground",
                "pev2" : "ADBINTERNAL:Crash",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : "12345679", //Most recent timestamp + 1
                "pageName" : "mockAppName",
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        } else {
            // Lifecycle crash hit
            crashVars = [
                "ce": "UTF-8",
                "pev2" : "ADBINTERNAL:Crash",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : "12345679", //Most recent timestamp + 1
                "pageName" : "mockAppName",
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        }

        let crashContextData = [
            "a.CrashEvent" : "CrashEvent",
            "a.internalaction" : "Crash",
            "a.AppID" : "previousAppId",
            "a.CarrierName" : "mockMobileCarrier",
            "a.DeviceName"  : "mockDeviceBuildId",
            "a.OSVersion" :  "previousOSVersion",
            "a.Resolution" : "0x0",
            "a.RunMode" : "Application"
        ]

        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: crashVars,
                  contextData: crashContextData)
        let lifecycleVars: [String: String]
        if runningForApp {
            // Lifecycle hit
            lifecycleVars = [
                "ce": "UTF-8",
                "cp": "foreground",
                "pev2" : "ADBINTERNAL:Lifecycle",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(lifecycleResponse.timestamp.getUnixTimeInSeconds()),
                "pageName" : "mockAppName",
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        } else {
            // Lifecycle hit
            lifecycleVars = [
                "ce": "UTF-8",
                "pev2" : "ADBINTERNAL:Lifecycle",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(lifecycleResponse.timestamp.getUnixTimeInSeconds()),
                "pageName" : "mockAppName",
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        }

        let lifecycleContextData = [
            "a.internalaction" : "Lifecycle",
            "a.AppID" : "mockAppName",
            "a.CarrierName" : "mockMobileCarrier",
            "a.DeviceName"  : "mockDeviceBuildId",
            "a.OSVersion" :  "mockOSName",
            "a.Resolution" : "0x0",
            "a.RunMode" : "Application",
            "a.locale" : "en-US"
        ]

        verifyHit(request: mockNetworkService?.calledNetworkRequests[1],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: lifecycleVars,
                  contextData: lifecycleContextData)
    }

    func lifecycleBackdatedSessionInfoTester() {
        dispatchDefaultConfigAndIdentityStates()
        MobileCore.setLogLevel(.trace)
        // Lifecycle start
        let lifecycleStartData = [
            AnalyticsConstants.Lifecycle.EventDataKeys.LIFECYCLE_ACTION_KEY:
                AnalyticsConstants.Lifecycle.EventDataKeys.LIFECYCLE_START
        ]
        let lifecycleStartEvent = Event(name: "", type: EventType.genericLifecycle, source: EventSource.requestContent, data: lifecycleStartData)
        mockRuntime.simulateComingEvent(event: lifecycleStartEvent)

        let sessionStartTs = Date().timeIntervalSince1970 - 10
        let previousSessionPauseTs = Date().timeIntervalSince1970 - 20

        let lifecycleEventData: [String: Any] = [
            AnalyticsTestConstants.Lifecycle.EventDataKeys.LIFECYCLE_CONTEXT_DATA : [
                AnalyticsTestConstants.Lifecycle.EventDataKeys.OPERATING_SYSTEM : "mockOSName",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.LOCALE : "en-US",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.DEVICE_RESOLUTION : "0x0",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.CARRIER_NAME : "mockMobileCarrier",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.DEVICE_NAME : "mockDeviceBuildId",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.APP_ID : "mockAppName",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.RUN_MODE : "Application",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.PREVIOUS_SESSION_LENGTH : "100",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.PREVIOUS_OS_VERSION : "previousOSVersion",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.PREVIOUS_APP_ID : "previousAppId"
            ],
            AnalyticsTestConstants.Lifecycle.EventDataKeys.SESSION_START_TIMESTAMP : sessionStartTs,
            AnalyticsTestConstants.Lifecycle.EventDataKeys.PREVIOUS_SESSION_PAUSE_TIMESTAMP : previousSessionPauseTs
        ]
        let lifecycleResponse = Event(name: "", type: EventType.lifecycle, source: EventSource.responseContent, data: lifecycleEventData)
        simulateLifecycleState(data: lifecycleEventData)
        mockRuntime.simulateComingEvent(event: lifecycleResponse)

        waitForProcessing()

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 2)
        let sessionInfoVars: [String: String]
        if runningForApp {
            // Lifecycle session hit
            sessionInfoVars = [
                "ce": "UTF-8",
                "cp": "foreground",
                "pev2" : "ADBINTERNAL:SessionInfo",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(Int64(previousSessionPauseTs + 1)),
                "pageName" : "mockAppName",
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        } else {
            // Lifecycle session hit
            sessionInfoVars = [
                "ce": "UTF-8",
                "pev2" : "ADBINTERNAL:SessionInfo",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(Int64(previousSessionPauseTs + 1)),
                "pageName" : "mockAppName",
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        }
        let sessionInfoContextData = [
            "a.internalaction" : "SessionInfo",
            "a.AppID" : "previousAppId",
            "a.CarrierName" : "mockMobileCarrier",
            "a.DeviceName"  : "mockDeviceBuildId",
            "a.OSVersion" :  "previousOSVersion",
            "a.Resolution" : "0x0",
            "a.RunMode" : "Application",
            "a.PrevSessionLength" : "100"
        ]

        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: sessionInfoVars,
                  contextData: sessionInfoContextData)
        let lifecycleVars: [String: String]
        if runningForApp {
            // Lifecycle hit
            lifecycleVars = [
                "ce": "UTF-8",
                "cp": "foreground",
                "pev2" : "ADBINTERNAL:Lifecycle",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(lifecycleResponse.timestamp.getUnixTimeInSeconds()),

                "pageName" : "mockAppName",
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        } else {
            // Lifecycle hit
            lifecycleVars = [
                "ce": "UTF-8",
                "pev2" : "ADBINTERNAL:Lifecycle",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(lifecycleResponse.timestamp.getUnixTimeInSeconds()),

                "pageName" : "mockAppName",
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        }

        let lifecycleContextData = [
            "a.internalaction" : "Lifecycle",
            "a.AppID" : "mockAppName",
            "a.CarrierName" : "mockMobileCarrier",
            "a.DeviceName"  : "mockDeviceBuildId",
            "a.OSVersion" :  "mockOSName",
            "a.Resolution" : "0x0",
            "a.RunMode" : "Application",
            "a.locale" : "en-US"
        ]

        verifyHit(request: mockNetworkService?.calledNetworkRequests[1],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: lifecycleVars,
                  contextData: lifecycleContextData)

    }

    //If Lifecycle shared state is available then analytics hits contain lifecycle vars
    func hitsContainTimeSinceLaunchTester() {
        dispatchDefaultConfigAndIdentityStates()

        let now = Date().timeIntervalSince1970

        let lifecycleSharedState: [String: Any] = [
            AnalyticsTestConstants.Lifecycle.EventDataKeys.LIFECYCLE_CONTEXT_DATA : [
                AnalyticsTestConstants.Lifecycle.EventDataKeys.OPERATING_SYSTEM : "mockOSName",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.LOCALE : "en-US",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.DEVICE_RESOLUTION : "0x0",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.CARRIER_NAME : "mockMobileCarrier",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.DEVICE_NAME : "mockDeviceBuildId",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.APP_ID : "mockAppName",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.RUN_MODE : "Application"
            ],
            AnalyticsTestConstants.Lifecycle.EventDataKeys.SESSION_START_TIMESTAMP : now,
            AnalyticsTestConstants.Lifecycle.EventDataKeys.MAX_SESSION_LENGTH : 300.0
        ]
        simulateLifecycleState(data: lifecycleSharedState)

        let trackData: [String: Any] = [
            CoreConstants.Keys.ACTION : "testActionName",
            CoreConstants.Keys.CONTEXT_DATA : [
                "k1": "v1",
                "k2": "v2"
            ]
        ]
        let trackEvent = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        let trackEventAfter10Sec = trackEvent.copyWithNewTimeStamp(Date(timeIntervalSince1970: now + 10))

        mockRuntime.simulateComingEvent(event: trackEventAfter10Sec)

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
                "ts" : String(trackEventAfter10Sec.timestamp.getUnixTimeInSeconds()),
                "pageName" : "mockAppName",
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        } else {
            expectedVars = [
                "ce": "UTF-8",
                "pev2" : "AMACTION:testActionName",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(trackEventAfter10Sec.timestamp.getUnixTimeInSeconds()),
                "pageName" : "mockAppName",
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        }
        let expectedContextData = [
            "k1" : "v1",
            "k2" : "v2",
            "a.action" : "testActionName",
            "a.AppID" : "mockAppName",
            "a.CarrierName" : "mockMobileCarrier",
            "a.DeviceName"  : "mockDeviceBuildId",
            "a.OSVersion" :  "mockOSName",
            "a.Resolution" : "0x0",
            "a.RunMode" : "Application",
            "a.TimeSinceLaunch" : "10"
        ]

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: expectedVars,
                  contextData: expectedContextData)
    }
}
