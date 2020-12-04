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
@testable import AEPServices

class AnalyticsTest : XCTestCase {

    var testableExtensionRuntime: TestableExtensionRuntime!
    var analytics:Analytics!
    var dataStore: NamedCollectionDataStore!
    var analyticsProperties: AnalyticsProperties!

    override func setUp() {
        ServiceProvider.shared.networkService = MockNetworking()
        MobileCore.setLogLevel(.error) // reset log level to error before each test
        testableExtensionRuntime = TestableExtensionRuntime()
        analyticsProperties = AnalyticsProperties.init()
        analytics = Analytics.init(runtime: testableExtensionRuntime)
        dataStore = analyticsProperties.dataStore
        analytics.onRegistered()
    }

    override func tearDown() {
        // clean the defaults after each test
        UserDefaults.clear()
    }

    func testGetSharedStateForEventWithNoDependencies() {
        let emptyDependenciesList = [String]()
        let analyticsState = analytics.createAnalyticsState(forEvent: Event.init(name: "", type: "", source: "", data: nil), dependencies: emptyDependenciesList)

        //Assert that returned shared states Dictionary is empty.
        XCTAssertNotNil(analyticsState)
    }

    func testGetSharedStateForEvent() {
        let event : Event? = Event.init(name: "", type: "", source: "", data: nil)
        testableExtensionRuntime.otherSharedStates["\(AnalyticsTestConstants.Assurance.EventDataKeys.SHARED_STATE_NAME)-\(String(describing: event?.id))"] = SharedStateResult.init(status: SharedStateStatus.set, value: [AnalyticsTestConstants.Assurance.EventDataKeys.SESSION_ID:"assuranceId"])
        let dependenciesList : [String] = [AnalyticsTestConstants.Assurance.EventDataKeys.SHARED_STATE_NAME]
        let analyticsState : AnalyticsState = analytics.createAnalyticsState(forEvent: event!, dependencies: dependenciesList)

        //Assert that the size of returned shared state should be one.
        XCTAssertNotNil(analyticsState)
        XCTAssertTrue(analyticsState.assuranceSessionActive ?? false)
    }

    func testProcessAnalyticsContextDataShouldReturnEmpty() {
        let analyticsState = AnalyticsState.init(dataMap: [String:[String:Any]]())
        let analyticsData : [String:String] = analytics.processAnalyticsContextData(analyticsState: analyticsState, trackEventData: nil)

        //Assert that Analytics Data is an empty dictionary.
        XCTAssertEqual(analyticsData.count, 0, "analyticsData data is expected to be empty dictionary.")
    }

    func testProcessAnalyticsContextData() {
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
        let analyticsState = AnalyticsState.init(dataMap: [String:[String:Any]]())
        let analyticsData : [String:String] = analytics.processAnalyticsVars(analyticsState: analyticsState, trackData: nil, timestamp: Date.init().timeIntervalSince1970, analyticsProperties: &analyticsProperties)

        //Assert that Analytics Data is an empty dictionary.
        XCTAssertEqual(analyticsData.count, 0, "analyticsData data is expected to be empty dictionary.")
    }

    // ==========================================================================
    // handleAnalyticsRequestIdentityEvent
    // ==========================================================================
    // setVisitorIdentifier happy path test
    func testHandleAnalyticsRequestIdentityEventWithValidVid() {
        // setup
        let data = [AnalyticsConstants.EventDataKeys.VISITOR_IDENTIFIER: "testVid"] as [String: Any]
        // create the analytics request identity event with the data
        let event = Event(name: "Test Analytics request identity", type: EventType.analytics, source: EventSource.requestIdentity, data: data)
        let _ = analytics.readyForEvent(event)

        // test
        testableExtensionRuntime.simulateComingEvent(event: event)
        sleep(1)

        // verify shared state was created
        XCTAssertEqual(1, testableExtensionRuntime.createdSharedStates.count)
        // verify vid was added to the datastore
        XCTAssertEqual("testVid", dataStore.getString(key: AnalyticsConstants.DataStoreKeys.VISITOR_IDENTIFIER_KEY))
        // verify the analytics identity response event was dispatched
        let responseEvent = testableExtensionRuntime.dispatchedEvents.first(where: { $0.responseID == event.id })
        XCTAssertNotNil(responseEvent)
        XCTAssertEqual("testVid", responseEvent?.data?[AnalyticsConstants.EventDataKeys.VISITOR_IDENTIFIER] as? String)
    }

    // setVisitorIdentifier when privacy status = opted out
    func testHandleAnalyticsRequestIdentityEventWithValidVid_WhenPrivacyOptedOut() {
        // setup
        let configData = [AnalyticsConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY: PrivacyStatus.optedOut.rawValue] as [String: Any]
        let data = [AnalyticsConstants.EventDataKeys.VISITOR_IDENTIFIER: "testVid"] as [String: Any]
        // create the analytics request identity event with the data
        let event = Event(name: "Test Analytics request identity", type: EventType.analytics, source: EventSource.requestIdentity, data: data)
        testableExtensionRuntime.simulateSharedState(extensionName: AnalyticsConstants.Configuration.EventDataKeys.SHARED_STATE_NAME, event: event, data: (configData, .set))

        let _ = analytics.readyForEvent(event)

        // test
        testableExtensionRuntime.simulateComingEvent(event: event)
        sleep(1)

        // verify shared state was not created
        XCTAssertEqual(0, testableExtensionRuntime.createdSharedStates.count)
        // verify vid was not added to the datastore
        XCTAssertEqual(nil, dataStore.getString(key: AnalyticsConstants.DataStoreKeys.VISITOR_IDENTIFIER_KEY))
        // verify the analytics identity response event was not dispatched
        let responseEvent = testableExtensionRuntime.dispatchedEvents.first(where: { $0.responseID == event.id })
        XCTAssertNil(responseEvent)
    }

    // getVisitorIdentifier happy path test
    func testHandleAnalyticsRequestIdentityEventWithNoVid() {
        // setup
        let mockNetworkService = ServiceProvider.shared.networkService as! MockNetworking
        let configData = [AnalyticsConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY: PrivacyStatus.optedIn.rawValue, AnalyticsConstants.Configuration.EventDataKeys.ANALYTICS_REPORT_SUITES: "testRsid", AnalyticsConstants.Configuration.EventDataKeys.ANALYTICS_SERVER: "testAnalyticsServer.com"] as [String: Any]
        // create the analytics request identity event with the data
        let event = Event(name: "Test Analytics request identity", type: EventType.analytics, source: EventSource.requestIdentity, data: nil)
        testableExtensionRuntime.simulateSharedState(extensionName: AnalyticsConstants.Configuration.EventDataKeys.SHARED_STATE_NAME, event: event, data: (configData, .set))
        let _ = analytics.readyForEvent(event)

        // test
        testableExtensionRuntime.simulateComingEvent(event: event)
        sleep(1)

        // verify network request is sent
        XCTAssertEqual(1, mockNetworkService.calledNetworkRequests.count)
        XCTAssertEqual("https://testAnalyticsServer.com/id?", mockNetworkService.calledNetworkRequests[0]?.url.absoluteString)
    }

    // getVisitorIdentifier when privacy opted out
    func testHandleAnalyticsRequestIdentityEventWithNoVid_WhenPrivacyOptedOut() {
        // setup
        let mockNetworkService = ServiceProvider.shared.networkService as! MockNetworking
        let configData = [AnalyticsConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY: PrivacyStatus.optedOut.rawValue, AnalyticsConstants.Configuration.EventDataKeys.ANALYTICS_REPORT_SUITES: "testRsid", AnalyticsConstants.Configuration.EventDataKeys.ANALYTICS_SERVER: "testAnalyticsServer.com"] as [String: Any]
        // create the analytics request identity event with the data
        let event = Event(name: "Test Analytics request identity", type: EventType.analytics, source: EventSource.requestIdentity, data: nil)
        testableExtensionRuntime.simulateSharedState(extensionName: AnalyticsConstants.Configuration.EventDataKeys.SHARED_STATE_NAME, event: event, data: (configData, .set))
        let _ = analytics.readyForEvent(event)

        // test
        testableExtensionRuntime.simulateComingEvent(event: event)
        sleep(1)

        // verify no network request sent
        XCTAssertEqual(0, mockNetworkService.calledNetworkRequests.count)
        // verify shared state with empty VID/AID was created
        XCTAssertEqual(1, testableExtensionRuntime.createdSharedStates.count)
        let sharedState = testableExtensionRuntime.createdSharedStates[0]
        XCTAssertNil(sharedState?[AnalyticsConstants.EventDataKeys.ANALYTICS_ID])
        XCTAssertNil(sharedState?[AnalyticsConstants.EventDataKeys.VISITOR_IDENTIFIER])
        // verify nil identifiers were added to the datastore
        XCTAssertEqual(nil, dataStore.getString(key: AnalyticsConstants.DataStoreKeys.VISITOR_IDENTIFIER_KEY))
        XCTAssertEqual(nil, dataStore.getString(key: AnalyticsConstants.DataStoreKeys.AID_KEY))
        // verify an analytics identity response event with no data was dispatched
        let responseEvent = testableExtensionRuntime.dispatchedEvents.first(where: { $0.responseID == event.id })
        XCTAssertEqual(0, responseEvent?.data?.count)
    }

    // getVisitorIdentifier when privacy unknown
    func testHandleAnalyticsRequestIdentityEventWithNoVid_WhenPrivacyUnknown() {
        // setup
        let mockNetworkService = ServiceProvider.shared.networkService as! MockNetworking
        let configData = [AnalyticsConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY: PrivacyStatus.unknown.rawValue, AnalyticsConstants.Configuration.EventDataKeys.ANALYTICS_REPORT_SUITES: "testRsid", AnalyticsConstants.Configuration.EventDataKeys.ANALYTICS_SERVER: "testAnalyticsServer.com"] as [String: Any]
        // create the analytics request identity event with the data
        let event = Event(name: "Test Analytics request identity", type: EventType.analytics, source: EventSource.requestIdentity, data: nil)
        testableExtensionRuntime.simulateSharedState(extensionName: AnalyticsConstants.Configuration.EventDataKeys.SHARED_STATE_NAME, event: event, data: (configData, .set))
        let _ = analytics.readyForEvent(event)

        // test
        testableExtensionRuntime.simulateComingEvent(event: event)
        sleep(1)

        // verify no network request sent
        XCTAssertEqual(0, mockNetworkService.calledNetworkRequests.count)
        // verify shared state with AID was created
        XCTAssertEqual(1, testableExtensionRuntime.createdSharedStates.count)
        let sharedState = testableExtensionRuntime.createdSharedStates[0]
        XCTAssertEqual(33, (sharedState?[AnalyticsConstants.EventDataKeys.ANALYTICS_ID] as? String)?.count)
        // verify an AID was added to the datastore
        XCTAssertEqual(nil, dataStore.getString(key: AnalyticsConstants.DataStoreKeys.VISITOR_IDENTIFIER_KEY))
        XCTAssertEqual(33, (dataStore.getString(key: AnalyticsConstants.DataStoreKeys.AID_KEY)?.count))
        // verify an analytics identity response event with identifiers was dispatched
        let responseEvent = testableExtensionRuntime.dispatchedEvents.first(where: { $0.responseID == event.id })
        XCTAssertEqual(1, responseEvent?.data?.count)
        XCTAssertEqual(33, (responseEvent?.data?[AnalyticsConstants.EventDataKeys.ANALYTICS_ID] as? String)?.count)
    }

    // handle eventhub booted
    func testHandleEventHubSharedStateEvent() {
        // setup
        let mockNetworkService = ServiceProvider.shared.networkService as! MockNetworking
        let configData = [AnalyticsConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY: PrivacyStatus.optedIn.rawValue, AnalyticsConstants.Configuration.EventDataKeys.ANALYTICS_REPORT_SUITES: "testRsid", AnalyticsConstants.Configuration.EventDataKeys.ANALYTICS_SERVER: "testAnalyticsServer.com"] as [String: Any]
        // create the event hub shared state event
        let event = Event(name: "Test Event Hub Shared State Update", type: EventType.hub, source: EventSource.sharedState, data: nil)
        testableExtensionRuntime.simulateSharedState(extensionName: AnalyticsConstants.Configuration.EventDataKeys.SHARED_STATE_NAME, event: event, data: (configData, .set))
        let _ = analytics.readyForEvent(event)

        // test
        testableExtensionRuntime.simulateComingEvent(event: event)
        sleep(1)

        // verify network request is sent
        XCTAssertEqual(1, mockNetworkService.calledNetworkRequests.count)
        XCTAssertEqual("https://testAnalyticsServer.com/id?", mockNetworkService.calledNetworkRequests[0]?.url.absoluteString)
    }
}
