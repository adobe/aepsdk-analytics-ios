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

    private var testableExtensionRuntime = TestableExtensionRuntime()

    func testGetSharedStateForEventWithNoDependencies() {

        let analytics: Analytics = Analytics.init(runtime: testableExtensionRuntime)
        let emptyDependenciesList = [String]()
        let sharedStates : [String:[String:Any]?] = analytics.getSharedStateForEvent(dependencies: emptyDependenciesList)

        //Assert that returned shared states Dictionary is empty.
        XCTAssertEqual(sharedStates.count, 0, "Expected shared state size to be 0.")
    }

    func testGetSharedStateForEvent() {
        testableExtensionRuntime.otherSharedStates["Assurance"] = SharedStateResult.init(status: SharedStateStatus.set, value: [String:Any]())
        let analytics: Analytics = Analytics.init(runtime: testableExtensionRuntime)
        let dependenciesList : [String] = ["Assurance"]
        let sharedStates : [String:[String:Any]?] = analytics.getSharedStateForEvent(dependencies: dependenciesList)

        //Assert that the size of returned shared state should be one.
        XCTAssertEqual(sharedStates.count, 1, "Expected shared states size to be one.")
    }

    func testProcessAnalyticsContextDataShouldReturnEmpty() {
        let analytics: Analytics = Analytics.init(runtime: testableExtensionRuntime)
        let analyticsState = AnalyticsState.init(dataMap: [String:[String:Any]]())
        let analyticsData : [String:String] = analytics.processAnalyticsContextData(analyticsState: analyticsState, trackEventData: nil)

        //Assert that Analytics Data is an empty dictionary.
        XCTAssertEqual(analyticsData.count, 0, "analyticsData data is expected to be empty dictionary.")
    }

    func testProcessAnalyticsContextData() {
        let analytics: Analytics = Analytics.init(runtime: testableExtensionRuntime)
        let analyticsState = AnalyticsState.init(dataMap: [String:[String:Any]]())
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
        let analytics: Analytics = Analytics.init(runtime: testableExtensionRuntime)
        let analyticsState = AnalyticsState.init(dataMap: [String:[String:Any]]())
        let analyticsData : [String:String] = analytics.processAnalyticsVars(analyticsState: analyticsState, trackData: nil, timestamp: Date.init().timeIntervalSince1970)

        //Assert that Analytics Data is an empty dictionary.
        XCTAssertEqual(analyticsData.count, 0, "analyticsData data is expected to be empty dictionary.")
    }
    
//    func testprocessAnalyticsVars() {
//        /// - TODO: Implement this test after visitor id serialization.
//    }
}
