/*
 Copyright 2020 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import Foundation
import XCTest
@testable import AEPCore
@testable import AEPAnalytics


class AnalyticsTest : XCTestCase {

    private var testableExtensionRuntime: TestableExtensionRuntime!
    private var analyticsState: AnalyticsState!
    private var analyticsProperties: AnalyticsProperties!
    private var analytics: Analytics!

    override func setUp() {
        MobileCore.setLogLevel(.error) // reset log level to error before each test
        testableExtensionRuntime = TestableExtensionRuntime()
        analyticsState = AnalyticsState()
        analyticsProperties = AnalyticsProperties()
        analytics = Analytics(runtime: testableExtensionRuntime, state: analyticsState)
        analytics.onRegistered()
    }

    func testGetSharedStateForEventWithNoDependencies() {
        let event = Event.init(name: "", type: "", source: "", data: nil)
        let emptyDependenciesList = [String]()
        analytics.updateAnalyticsState(forEvent: event, dependencies: emptyDependenciesList)

        //Assert that returned shared states Dictionary is empty.
        XCTAssertNotNil(analyticsState)
    }

    func testGetSharedStateForEvent() {
        let data = [AnalyticsTestConstants.Assurance.EventDataKeys.SESSION_ID: "assuranceId"] as [String: Any]
        let event = Event.init(name: "", type: "", source: "", data: data)
        testableExtensionRuntime.simulateSharedState(extensionName: AnalyticsTestConstants.Assurance.EventDataKeys.SHARED_STATE_NAME, event: event, data: (data, .set))
        let dependenciesList = [AnalyticsTestConstants.Assurance.EventDataKeys.SHARED_STATE_NAME]
        analytics.updateAnalyticsState(forEvent: event, dependencies: dependenciesList)

        //Assert that the size of returned shared state should be one.
        XCTAssertNotNil(analyticsState)
        XCTAssertTrue(analyticsState.assuranceSessionActive ?? false)
    }

    func testProcessAnalyticsContextDataShouldReturnEmpty() {
        let analyticsData : [String:String] = analytics.processAnalyticsContextData(analyticsState: analyticsState, trackEventData: nil)

        //Assert that Analytics Data is an empty dictionary.
        XCTAssertEqual(analyticsData.count, 0, "analyticsData data is expected to be empty dictionary.")
    }

    func testProcessAnalyticsContextData() {
        let defaultDataKey = "defaultDataKey"
        let defaultDataValue = "defaultDatavalue"
        let contextDataKey = "contextDataKey"
        let contextDataValue = "contextDatavalue"
        let isInternal = true
        let action = "action"
        let requestEventIdentifier = "requestEventIdentifier"
        let defaultData : [String:String] = [defaultDataKey:defaultDataValue]
        analyticsState.defaultData = defaultData


        var trackEventData : [String:Any] = [:]
        trackEventData[AnalyticsTestConstants.EventDataKeys.CONTEXT_DATA] = [contextDataKey:contextDataValue]

        trackEventData[AnalyticsTestConstants.EventDataKeys.TRACK_ACTION] = action
        trackEventData[AnalyticsConstants.EventDataKeys.TRACK_INTERNAL] = isInternal
        analyticsState.lifecycleSessionStartTimestamp = Date.init().timeIntervalSince1970
        analyticsState.lifecycleMaxSessionLength = analyticsState.lifecycleSessionStartTimestamp
        trackEventData[AnalyticsTestConstants.EventDataKeys.REQUEST_EVENT_IDENTIFIER] = requestEventIdentifier

        let analyticsData = analytics.processAnalyticsContextData(analyticsState: analyticsState, trackEventData: trackEventData)

        //Asserting for analytics data returned.

        XCTAssertEqual(analyticsData[defaultDataKey], defaultDataValue)
        XCTAssertEqual(analyticsData[contextDataKey], contextDataValue)
        XCTAssertEqual(analyticsData[AnalyticsTestConstants.ContextDataKeys.INTERNAL_ACTION_KEY], action)
        XCTAssertNotNil(analyticsData[AnalyticsConstants.ContextDataKeys.TIME_SINCE_LAUNCH_KEY])
        XCTAssertEqual(analyticsData[AnalyticsConstants.ContextDataKeys.EVENT_IDENTIFIER_KEY], requestEventIdentifier)
    }

    func testProcessAnalyticsVarsShouldReturnEmpty() {
        let analyticsData : [String:String] = analytics.processAnalyticsVars(analyticsState: analyticsState, trackData: nil, timestamp: Date.init().timeIntervalSince1970, analyticsProperties: &analyticsProperties)

        //Assert that Analytics Data is an empty dictionary.
        XCTAssertEqual(analyticsData.count, 0, "analyticsData data is expected to be empty dictionary.")
    }

//    func testprocessAnalyticsVars() {
//        /// - TODO: Implement this test after visitor id serialization.
//    }
}
