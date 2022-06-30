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
class AnalyticsHitReorderTestBase : AnalyticsFunctionalTestBase {

    internal var runningForAppTests = true

    //Lifecycle data and acquisition data appended to the first custom analytics hit
    func dataAppendedToFirstCustomHitTester() {
        dispatchDefaultConfigAndIdentityStates(configData: [
            AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_LAUNCH_HIT_DELAY : 1
        ])

        MobileCore.setLogLevel(.trace)
        // LifecycleStart
        simulateLifecycleStartEvent()

        // Generic track call
        let trackData: [String: Any] = [
            CoreConstants.Keys.STATE : "testState",
            CoreConstants.Keys.CONTEXT_DATA : [
                "k1": "v1"
            ]
        ]
        let trackEvent = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: trackEvent)

        // LifecycleResponse comes after a delay
        let lifecycleResponseData: [String: Any] = [
            AnalyticsTestConstants.Lifecycle.EventDataKeys.LIFECYCLE_CONTEXT_DATA : [
                AnalyticsTestConstants.Lifecycle.EventDataKeys.INSTALL_EVENT : "InstallEvent",
                "lifecyclekey" : "value"
            ]
        ]
        let lifecycleResponseEvent = Event(name: "", type: EventType.lifecycle, source: EventSource.responseContent, data: lifecycleResponseData)
        simulateLifecycleState(data: lifecycleResponseData)
        mockRuntime.simulateComingEvent(event: lifecycleResponseEvent)


        // Acquistion event
        let acquisitionData = [
            AnalyticsTestConstants.Acquisition.CONTEXT_DATA : [
                "a.referrerkey" : "value"
            ]
        ]
        let _ = simulateAcquisitionState(data: acquisitionData)
        waitForProcessing(interval: 1.0)

        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)

        let hitVars: [String: String]

        if runningForAppTests {
            hitVars = [
                "ce": "UTF-8",
                "cp": "foreground",
                "pageName" : "testState",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds()),
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        } else {
            hitVars = [
                "ce": "UTF-8",
                "pageName" : "testState",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds()),
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        }

        let hitContextData = [
            "a.InstallEvent" : "InstallEvent",
            "a.referrerkey" : "value",
            "k1" : "v1",
            "lifecyclekey" : "value"
        ]

        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: hitVars,
                  contextData: hitContextData)
    }

    // Verify acquisition data sent out on second hit if referrer timer is exceeded
    func acquisitionDataTimeOutForInstallTester() {
        dispatchDefaultConfigAndIdentityStates(configData: [AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_LAUNCH_HIT_DELAY : 1])

        // LifecycleStart
        simulateLifecycleStartEvent()

        // Track call
        let trackData: [String: Any] = [
            CoreConstants.Keys.ACTION : "start",
            CoreConstants.Keys.CONTEXT_DATA : [
                "k1": "v1",
            ]
        ]
        let trackEvent = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: trackEvent)

        // LifecycleResponse comes after a delay
        let lifecycleResponseData: [String: Any] = [
            AnalyticsTestConstants.Lifecycle.EventDataKeys.LIFECYCLE_CONTEXT_DATA : [
                AnalyticsTestConstants.Lifecycle.EventDataKeys.INSTALL_EVENT : "InstallEvent",
                "lifecyclekey" : "value"
            ]
        ]
        let lifecycleResponseEvent = Event(name: "", type: EventType.lifecycle, source: EventSource.responseContent, data: lifecycleResponseData)
        simulateLifecycleState(data: lifecycleResponseData)
        mockRuntime.simulateComingEvent(event: lifecycleResponseEvent)

        // Lifecycle timer times out
        waitForProcessing(interval: 1.5)

        // Acquisition response is received
        let acquisitionData: [String: Any] = [
            AnalyticsTestConstants.Acquisition.CONTEXT_DATA: [
                "test_key_1": "test_value_1",
                "a.deeplink.id": "test_deeplinkId",
                "test_key_0": "test_value_0"
            ]
        ]
        let acquisitionEvent = simulateAcquisitionState(data: acquisitionData)
        waitForProcessing()

        // We receive 2 hits
        // First hit contains track and lifecycle data
        // Second hit contains acquition data
        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 2)

        let firstHitExpectedVars: [String: String]
        if runningForAppTests {
            firstHitExpectedVars = [
                "ce": "UTF-8",
                "cp": "foreground",
                "pev2" : "AMACTION:start",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(Int64(trackEvent.timestamp.getUnixTimeInSeconds())),
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        } else {
            firstHitExpectedVars = [
                "ce": "UTF-8",
                "pev2" : "AMACTION:start",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(Int64(trackEvent.timestamp.getUnixTimeInSeconds())),
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        }

        let firstHitContextData = [
            "k1" : "v1",
            "a.action" : "start",
            "a.InstallEvent" : "InstallEvent",
            "lifecyclekey" : "value"
        ]
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: firstHitExpectedVars,
                  contextData: firstHitContextData)

        let secondHitExpectedVars: [String: String]
        if runningForAppTests {
            secondHitExpectedVars = [
                "ce": "UTF-8",
                "cp": "foreground",
                "pev2" : "ADBINTERNAL:AdobeLink",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(acquisitionEvent.timestamp.getUnixTimeInSeconds()),
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        } else {
            secondHitExpectedVars = [
                "ce": "UTF-8",
                "pev2" : "ADBINTERNAL:AdobeLink",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(acquisitionEvent.timestamp.getUnixTimeInSeconds()),
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        }

        let secondHitContextData = [
            "a.internalaction" : "AdobeLink",
            "a.deeplink.id" : "test_deeplinkId",
            "test_key_0" : "test_value_0",
            "test_key_1" : "test_value_1",
        ]

        verifyHit(request: mockNetworkService?.calledNetworkRequests[1],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: secondHitExpectedVars,
                  contextData: secondHitContextData)
    }

    // Verify if custom track occurs first then lifecycle and acquisition data are included on second custom track
    func analyticsRequestMadePriorToCollectionOfLifecycleAndAcquisitionTester() {
        dispatchDefaultConfigAndIdentityStates(configData: [
            AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_LAUNCH_HIT_DELAY : 1
        ])

        // Track call
        let trackData: [String: Any] = [
            CoreConstants.Keys.ACTION : "start",
            CoreConstants.Keys.CONTEXT_DATA : [
                "k1": "v1",
            ]
        ]
        let trackEvent = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: trackEvent)


        // LifecycleStart
        simulateLifecycleStartEvent()

        // LifecycleResponse comes after a delay
        let lifecycleResponseData: [String: Any] = [
            AnalyticsTestConstants.Lifecycle.EventDataKeys.LIFECYCLE_CONTEXT_DATA : [
                AnalyticsTestConstants.Lifecycle.EventDataKeys.INSTALL_EVENT : "InstallEvent",
                "lifecyclekey" : "value"
            ]
        ]
        let lifecycleResponseEvent = Event(name: "", type: EventType.lifecycle, source: EventSource.responseContent, data: lifecycleResponseData)
        simulateLifecycleState(data: lifecycleResponseData)
        mockRuntime.simulateComingEvent(event: lifecycleResponseEvent)

        // Acquisition response is received
        let acquisitionData: [String: Any] = [
            AnalyticsTestConstants.Acquisition.CONTEXT_DATA: [
                "test_key_1": "test_value_1",
                "a.deeplink.id": "test_deeplinkId",
                "test_key_0": "test_value_0"
            ]
        ]
        _ = simulateAcquisitionState(data: acquisitionData)
        waitForProcessing()

        // We receive 2 hits
        // First hit contains track data
        // Second hit contains lifecycle and acquisition
        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 2)
        let firstHitExpectedVars: [String: String]
        if runningForAppTests {
            firstHitExpectedVars = [
                "ce": "UTF-8",
                "cp": "foreground",
                "pev2" : "AMACTION:start",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(Int64(trackEvent.timestamp.getUnixTimeInSeconds())),
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        } else {
            firstHitExpectedVars = [
                "ce": "UTF-8",
                "pev2" : "AMACTION:start",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(Int64(trackEvent.timestamp.getUnixTimeInSeconds())),
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        }
        let firstHitContextData = [
            "k1" : "v1",
            "a.action" : "start",
        ]
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: firstHitExpectedVars,
                  contextData: firstHitContextData)
        let secondHitExpectedVars: [String: String]
        if runningForAppTests {
            secondHitExpectedVars = [
                "ce": "UTF-8",
                "cp": "foreground",
                "pev2" : "ADBINTERNAL:Lifecycle",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(lifecycleResponseEvent.timestamp.getUnixTimeInSeconds()),
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        } else {
            secondHitExpectedVars = [
                "ce": "UTF-8",
                "pev2" : "ADBINTERNAL:Lifecycle",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(lifecycleResponseEvent.timestamp.getUnixTimeInSeconds()),
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        }
        let secondHitContextData = [
            "a.InstallEvent" : "InstallEvent",
            "lifecyclekey" : "value",
            "a.internalaction" : "Lifecycle",
            "a.deeplink.id" : "test_deeplinkId",
            "test_key_0" : "test_value_0",
            "test_key_1" : "test_value_1",
        ]
        verifyHit(request: mockNetworkService?.calledNetworkRequests[1],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: secondHitExpectedVars,
                  contextData: secondHitContextData)
    }

    // Verify no custom track occurs until lifecycle and acquisition data are processed
    func customTrackWaitsForProcessingOfLifecycleAndAcquisitionTester() {
        dispatchDefaultConfigAndIdentityStates(
            configData:[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_LAUNCH_HIT_DELAY : 5]
        )

        simulateLifecycleStartEvent()

        let lifecycleSharedState: [String: Any] = [
            AnalyticsTestConstants.Lifecycle.EventDataKeys.LIFECYCLE_CONTEXT_DATA : [
                AnalyticsTestConstants.Lifecycle.EventDataKeys.OPERATING_SYSTEM : "mockOSName",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.LOCALE : "en-US",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.DEVICE_RESOLUTION : "0x0",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.CARRIER_NAME : "mockMobileCarrier",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.DEVICE_NAME : "mockDeviceBuildId",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.APP_ID : "mockAppName",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.RUN_MODE : "Application",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.INSTALL_EVENT : "InstallEvent",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.LAUNCH_EVENT : "LaunchEvent",
                AnalyticsTestConstants.Lifecycle.EventDataKeys.MONTHLY_ENGAGED_EVENT : "MonthlyEngUserEvent"
            ]
        ]
        let lifecycleResponseEvent = Event(name: "", type: EventType.lifecycle, source: EventSource.responseContent, data: lifecycleSharedState)
        simulateLifecycleState(data: lifecycleSharedState)
        mockRuntime.simulateComingEvent(event: lifecycleResponseEvent)

        let acquisitionData = [
            "test_key_1": "test_value_1",
            "a.deeplink.id": "test_deeplinkId",
            "test_key_0": "test_value_0"
        ]

        let acquisitionSharedState: [String: Any] = [
            AnalyticsTestConstants.Acquisition.CONTEXT_DATA: acquisitionData
        ]
        let _ = simulateAcquisitionState(data: acquisitionSharedState)

        let trackData: [String: Any] = [
            CoreConstants.Keys.ACTION : "start",
            CoreConstants.Keys.CONTEXT_DATA : [
                "k1": "v1",
            ]
        ]
        let trackEvent = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: trackEvent)
        waitForProcessing()

        // 2 hits.
        // First hit contains install and acquisition data
        // Second hit contains track data
        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 2)
        let installHitExpectedVars: [String: String]
        if runningForAppTests {

            installHitExpectedVars = [
                "ce": "UTF-8",
                "cp": "foreground",
                "pev2" : "ADBINTERNAL:Lifecycle",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(lifecycleResponseEvent.timestamp.getUnixTimeInSeconds()),
                "pageName" : "mockAppName",
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        } else {
            installHitExpectedVars = [
                "ce": "UTF-8",
                "pev2" : "ADBINTERNAL:Lifecycle",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(lifecycleResponseEvent.timestamp.getUnixTimeInSeconds()),
                "pageName" : "mockAppName",
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        }

        let installHitExpectedContextData = [
            "a.locale" : "en-US",
            "a.AppID" : "mockAppName",
            "a.CarrierName" : "mockMobileCarrier",
            "a.DeviceName"  : "mockDeviceBuildId",
            "a.OSVersion" :  "mockOSName",
            "a.Resolution" : "0x0",
            "a.RunMode" : "Application",
            "a.internalaction" : "Lifecycle",
            "a.LaunchEvent" : "LaunchEvent",
            "a.InstallEvent" : "InstallEvent",
            "a.MonthlyEngUserEvent" : "MonthlyEngUserEvent",
            "a.deeplink.id" : "test_deeplinkId",
            "test_key_0" : "test_value_0",
            "test_key_1" : "test_value_1"
        ]
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: installHitExpectedVars,
                  contextData: installHitExpectedContextData)
        let trackHitExpectedVars: [String: String]
        if runningForAppTests {
            trackHitExpectedVars = [
                "ce": "UTF-8",
                "cp": "foreground",
                "pev2" : "AMACTION:start",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds()),
                "pageName" : "mockAppName",
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        } else {
            trackHitExpectedVars = [
                "ce": "UTF-8",
                "pev2" : "AMACTION:start",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(trackEvent.timestamp.getUnixTimeInSeconds()),
                "pageName" : "mockAppName",
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        }
        let trackHitExpectedContextData = [
            "k1" : "v1",
            "a.action" : "start",
            "a.AppID" : "mockAppName",
            "a.CarrierName" : "mockMobileCarrier",
            "a.DeviceName"  : "mockDeviceBuildId",
            "a.OSVersion" :  "mockOSName",
            "a.Resolution" : "0x0",
            "a.RunMode" : "Application"
        ]

        verifyHit(request: mockNetworkService?.calledNetworkRequests[1],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: trackHitExpectedVars,
                  contextData: trackHitExpectedContextData)
    }

    // Acquisition as seperate hit
    func acquisitionSentAsSeperateHitTester() {
        dispatchDefaultConfigAndIdentityStates()

        let acquisitionData = [
            "test_key_1": "test_value_1",
            "a.deeplink.id": "test_deeplinkId",
            "test_key_0": "test_value_0"
        ]

        let acquisitionSharedState: [String: Any] = [
            AnalyticsTestConstants.Acquisition.CONTEXT_DATA: acquisitionData
        ]
        let acquisitionResponseEvent = simulateAcquisitionState(data: acquisitionSharedState)

        waitForProcessing()

        // 1 hits.
        // First hit contains acquisition data
        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        let acquisitionExpectedVars: [String: String]
        if runningForAppTests {
            acquisitionExpectedVars = [
                "ce": "UTF-8",
                "cp": "foreground",
                "pev2" : "ADBINTERNAL:AdobeLink",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(acquisitionResponseEvent.timestamp.getUnixTimeInSeconds()),
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        } else {
            acquisitionExpectedVars = [
                "ce": "UTF-8",
                "pev2" : "ADBINTERNAL:AdobeLink",
                "pe" : "lnk_o",
                "mid" : "mid",
                "aamb" : "blob",
                "aamlh" : "lochint",
                "ts" : String(acquisitionResponseEvent.timestamp.getUnixTimeInSeconds()),
                "t" : TimeZone.current.getOffsetFromGmtInMinutes()
            ]
        }
        let acquisitionContextData = [
            "a.internalaction" : "AdobeLink",
            "a.deeplink.id" : "test_deeplinkId",
            "test_key_0" : "test_value_0",
            "test_key_1" : "test_value_1"
        ]
        verifyHit(request: mockNetworkService?.calledNetworkRequests[0],
                  host: "https://test.com/b/ss/rsid/0/",
                  vars: acquisitionExpectedVars,
                  contextData: acquisitionContextData)

    }
}
