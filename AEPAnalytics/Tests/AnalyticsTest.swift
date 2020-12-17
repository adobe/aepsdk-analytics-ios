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
        analyticsProperties = AnalyticsProperties.init()
        addDataToAnalyticsProperties()
        analytics = Analytics(runtime: testableExtensionRuntime, state: analyticsState, properties: analyticsProperties)
        analytics.onRegistered()
    }

    private func addSharedStateDataToAnalyticsState() {
        var dataMap = [String: [String: Any]]()

        // add lifecycle data
        let sessionStartTimestamp: TimeInterval = 1000
        let lifecycleMaxSessionLength: TimeInterval = 2000
        let os = "Android"
        let deviceName = "Pixel"
        let deviceResolution = "1024 * 1024"
        let carrierName = "Verizon"
        let runMode = "run mode"
        let appId = "1234"

        var lifecycleContextData = [String: String]()
        lifecycleContextData[AnalyticsTestConstants.Lifecycle.EventDataKeys.OPERATING_SYSTEM] = os
        lifecycleContextData[AnalyticsTestConstants.Lifecycle.EventDataKeys.DEVICE_NAME] = deviceName
        lifecycleContextData[AnalyticsTestConstants.Lifecycle.EventDataKeys.DEVICE_RESOLUTION] = deviceResolution
        lifecycleContextData[AnalyticsTestConstants.Lifecycle.EventDataKeys.CARRIER_NAME] = carrierName
        lifecycleContextData[AnalyticsTestConstants.Lifecycle.EventDataKeys.RUN_MODE] = runMode
        lifecycleContextData[AnalyticsTestConstants.Lifecycle.EventDataKeys.APP_ID] = appId

        var lifecycleData = [String: Any]()
        lifecycleData[AnalyticsTestConstants.Lifecycle.EventDataKeys.SESSION_START_TIMESTAMP] = sessionStartTimestamp
        lifecycleData[AnalyticsTestConstants.Lifecycle.EventDataKeys.MAX_SESSION_LENGTH] = lifecycleMaxSessionLength
        lifecycleData[AnalyticsConstants.Lifecycle.EventDataKeys.LIFECYCLE_CONTEXT_DATA] = lifecycleContextData
        dataMap[AnalyticsTestConstants.Lifecycle.EventDataKeys.SHARED_STATE_NAME] = lifecycleData

        // add identity data
        let marketingCloudId = "marketingCloudId"
        let blob = "blob"
        let locationHint = "locationHint"
        let advertisingId = "advertisingId"
        var identityData = [String: Any]()
        typealias IdentityEventDataKeys = AnalyticsTestConstants.Identity.EventDataKeys
        identityData[IdentityEventDataKeys.VISITOR_ID_MID] = marketingCloudId
        identityData[IdentityEventDataKeys.VISITOR_ID_BLOB] = blob
        identityData[IdentityEventDataKeys.VISITOR_ID_LOCATION_HINT] = locationHint
        identityData[IdentityEventDataKeys.ADVERTISING_IDENTIFIER] = advertisingId
        dataMap[AnalyticsTestConstants.Identity.EventDataKeys.SHARED_STATE_NAME] = identityData

        // add places data
        let regionId = "regionId"
        let regionName = "regionName"
        typealias PlacesEventDataKeys = AnalyticsTestConstants.Places.EventDataKeys
        var placesContextData = [String: String]()
        placesContextData[PlacesEventDataKeys.REGION_ID] = regionId
        placesContextData[PlacesEventDataKeys.REGION_NAME] = regionName
        var placesData = [String: Any]()
        placesData[PlacesEventDataKeys.CURRENT_POI] =  placesContextData
        dataMap[AnalyticsTestConstants.Places.EventDataKeys.SHARED_STATE_NAME] = placesData

        // add assurance data
        let sessionId = "sessionId"
        typealias AssuranceEventDataKeys = AnalyticsTestConstants.Assurance.EventDataKeys
        var assuranceData = [String: String]()
        assuranceData[AssuranceEventDataKeys.SESSION_ID] = sessionId
        dataMap[AssuranceEventDataKeys.SHARED_STATE_NAME] = assuranceData

        // update analyticsState with the shared states
        analyticsState.update(dataMap: dataMap)
    }

    private func addDataToAnalyticsProperties() {
        let today = Date()
        let yesterday = today.addingTimeInterval(-24.0 * 3600.0)
        analyticsProperties.locale = Locale(identifier: "testLocale")
        analyticsProperties.aid = "testAid"
        analyticsProperties.vid = "testVid"
        analyticsProperties.lifecyclePreviousSessionPauseTimestamp = yesterday
        analyticsProperties.lifecyclePreviousPauseEventTimestamp = today
        analyticsProperties.referrerTimerRunning = true
        analyticsProperties.lifecycleTimerRunning = true
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

    // ==========================================================================
    // handleConfigurationResponseEvent
    // ==========================================================================
    func testHandleConfigurationResponse_HappyPath() {
        // create configuration event
        let server = "analytics_server"
        let rsids = "rsid1, rsid2"
        let privacyStatusString = "optedin"
        var configurationData = [String: Any]()
        configurationData[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_SERVER] = server
        configurationData[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_REPORT_SUITES] = rsids
        configurationData[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_AAMFORWARDING] = true
        configurationData[AnalyticsTestConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY] = privacyStatusString
        // create the configuration response content event with the data
        let event = Event(name: "Test Configuration response", type: EventType.configuration, source: EventSource.responseContent, data: configurationData)
        // setup config shared state
        testableExtensionRuntime.simulateSharedState(extensionName: AnalyticsTestConstants.Configuration.EventDataKeys.SHARED_STATE_NAME, event: event, data: (configurationData, .set))
        let _ = analytics.readyForEvent(event)

        // test
        testableExtensionRuntime.simulateComingEvent(event: event)

        // verify configuration data added to analyticsState
        XCTAssertEqual(.optedIn, analyticsState.privacyStatus) // analytics state privacy status should have updated to opt-in
        // configuration data should be present in analytics state
        XCTAssertEqual(server, analyticsState.host)
        XCTAssertEqual(rsids, analyticsState.rsids)
        XCTAssertEqual(true, analyticsState.analyticForwardingEnabled)
        // TODO: verify privacy status within AnalyticsHitsDatabse is updated as well
    }

    func testHandleConfigurationResponse_PrivacyUnknown() {
        // create configuration event
        let server = "analytics_server"
        let rsids = "rsid1, rsid2"
        let privacyStatusString = "unknown"
        var configurationData = [String: Any]()
        configurationData[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_SERVER] = server
        configurationData[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_REPORT_SUITES] = rsids
        configurationData[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_AAMFORWARDING] = true
        configurationData[AnalyticsTestConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY] = privacyStatusString
        // create the configuration response content event with the data
        let event = Event(name: "Test Configuration response", type: EventType.configuration, source: EventSource.responseContent, data: configurationData)
        // setup config shared state
        testableExtensionRuntime.simulateSharedState(extensionName: AnalyticsTestConstants.Configuration.EventDataKeys.SHARED_STATE_NAME, event: event, data: (configurationData, .set))
        let _ = analytics.readyForEvent(event)

        // test
        testableExtensionRuntime.simulateComingEvent(event: event)

        // verify configuration data added to analyticsState
        XCTAssertEqual(.unknown, analyticsState.privacyStatus) // analytics state privacy status should have updated to opt-in
        // configuration data should be present in analytics state
        XCTAssertEqual(server, analyticsState.host)
        XCTAssertEqual(rsids, analyticsState.rsids)
        XCTAssertEqual(true, analyticsState.analyticForwardingEnabled)
        // TODO: verify privacy status within AnalyticsHitsDatabse is updated as well
    }

    func testHandleConfigurationResponse_PrivacyOptedOut() {
        typealias AnalyticContextDataKeys = AnalyticsTestConstants.ContextDataKeys
        typealias PlacesEventDataKeys = AnalyticsTestConstants.Places.EventDataKeys
        // setup shared state data for lifecycle, identity, places, and assurance
        addSharedStateDataToAnalyticsState()
        // create configuration event
        let server = "analytics_server"
        let rsids = "rsid1, rsid2"
        let marketingCloudOrgId = "marketingserver"
        let privacyStatusString = "optedout"
        let launchHitDelay : TimeInterval = 300
        var configurationData = [String: Any]()
        configurationData[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_SERVER] = server
        configurationData[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_REPORT_SUITES] = rsids
        configurationData[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_AAMFORWARDING] = true
        configurationData[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_OFFLINE_TRACKING] = true
        configurationData[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_LAUNCH_HIT_DELAY] = launchHitDelay
        configurationData[AnalyticsTestConstants.Configuration.EventDataKeys.MARKETING_CLOUD_ORGID_KEY] = marketingCloudOrgId
        configurationData[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_BACKDATE_PREVIOUS_SESSION] = true
        configurationData[AnalyticsTestConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY] = privacyStatusString
        // create the configuration response content event with the data
        let event = Event(name: "Test Configuration response", type: EventType.configuration, source: EventSource.responseContent, data: configurationData)
        // setup config shared state
        testableExtensionRuntime.simulateSharedState(extensionName: AnalyticsTestConstants.Configuration.EventDataKeys.SHARED_STATE_NAME, event: event, data: (configurationData, .set))
        let _ = analytics.readyForEvent(event)

        // test
        testableExtensionRuntime.simulateComingEvent(event: event)

        // verify configuration data was added to analyticsState by privacy status being set to opt-out
        XCTAssertEqual(.optedOut, analyticsState.privacyStatus)
        // verify configuration data was cleared
        XCTAssertNil(analyticsState.host)
        XCTAssertNil(analyticsState.rsids)
        XCTAssertFalse(analyticsState.analyticForwardingEnabled)
        XCTAssertFalse(analyticsState.offlineEnabled)
        XCTAssertEqual(analyticsState.launchHitDelay, AnalyticsTestConstants.Default.LAUNCH_HIT_DELAY)
        XCTAssertNil(analyticsState.marketingCloudOrganizationId)
        XCTAssertFalse(analyticsState.backDateSessionInfoEnabled)
        // verify lifecycle data was cleared
        XCTAssertEqual(analyticsState.lifecycleSessionStartTimestamp, AnalyticsTestConstants.Default.LIFECYCLE_SESSION_START_TIMESTAMP)
        XCTAssertEqual(analyticsState.lifecycleMaxSessionLength, AnalyticsTestConstants.Default.LIFECYCLE_MAX_SESSION_LENGTH)
        XCTAssertNil(analyticsState.defaultData[AnalyticContextDataKeys.OPERATING_SYSTEM])
        XCTAssertNil(analyticsState.defaultData[AnalyticContextDataKeys.DEVICE_NAME])
        XCTAssertNil(analyticsState.defaultData[AnalyticContextDataKeys.DEVICE_RESOLUTION])
        XCTAssertNil(analyticsState.defaultData[AnalyticContextDataKeys.CARRIER_NAME])
        XCTAssertNil(analyticsState.defaultData[AnalyticContextDataKeys.RUN_MODE])
        XCTAssertNil(analyticsState.defaultData[AnalyticContextDataKeys.APPLICATION_IDENTIFIER])
        // verify identity data was cleared
        XCTAssertNil(analyticsState.marketingCloudId)
        XCTAssertNil(analyticsState.blob)
        XCTAssertNil(analyticsState.locationHint)
        XCTAssertNil(analyticsState.advertisingId)
        //verify places data was cleared
        XCTAssertNil(analyticsState.defaultData[AnalyticsTestConstants.ContextDataKeys.REGION_ID])
        XCTAssertNil(analyticsState.defaultData[AnalyticsTestConstants.ContextDataKeys.REGION_NAME])
        // verify assurance data was cleared
        XCTAssertNil(analyticsState.assuranceSessionActive)
        // verify analytics properties was cleared / reset to default
        let retrievedProperties = analytics.getAnalyticsProperties()
        XCTAssertNil(retrievedProperties.locale)
        XCTAssertNil(retrievedProperties.aid)
        XCTAssertNil(retrievedProperties.vid)
        XCTAssertNil(retrievedProperties.lifecyclePreviousSessionPauseTimestamp)
        XCTAssertNil(retrievedProperties.lifecyclePreviousPauseEventTimestamp)
        XCTAssertFalse(retrievedProperties.referrerTimerRunning)
        XCTAssertFalse(retrievedProperties.lifecycleTimerRunning)
        // TODO: verify privacy status within AnalyticsHitsDatabse is updated as well
    }
}
