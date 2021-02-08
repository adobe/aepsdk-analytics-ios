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
    var analyticsState: AnalyticsState!
    var analyticsHitDatabase: AnalyticsHitDatabase!

    static let responseAid = "7A57620BB5CA4754-30BDF2392F2416C7"

    static let aidResponse = """
    {
       "id": "\(responseAid)"
    }
    """

    static let invalidAidResponse = """
    {
       "id": \(responseAid)
    }
    """

    static let noAIDResponse = """
    {
       "someValue": "value"
    }
    """

    static let referrerData = ["a.referrer.campaign.trackingcode": "1234567890","a.launch.campaign.trackingcode": "1234567890","a.referrer.campaign.name": "myLink","a.referrer.campaign.source": "mycompany","a.launch.campaign.source": "mycompany","a.acquisition.custom.amo1.key1": "amo1.value1","a.acquisition.custom.amo1.key2": "amo1.value2"]

    override func setUp() {
        // setup test variables
        ServiceProvider.shared.networkService = MockNetworking()
        testableExtensionRuntime = TestableExtensionRuntime()
        analyticsHitDatabase = AnalyticsHitDatabase()
        analyticsState = AnalyticsState()
        analyticsProperties = AnalyticsProperties.init()
        analytics = Analytics(runtime: testableExtensionRuntime, state: analyticsState, properties: analyticsProperties, hitDatabase: analyticsHitDatabase)
        dataStore = analyticsProperties.dataStore
        analytics.onRegistered()
    }

    override func tearDown() {
        // clean the defaults and cache after each test
        UserDefaults.clear()
        FileManager.default.clearCache()
    }

    // MARK: helpers
    // set a response for getVisitorIdentifier testing
    func setDefaultResponse(responseData: Data?, expectedUrlFragment: String, statusCode: Int, mockNetworkService: MockNetworking) {
        let response = HTTPURLResponse(url: URL(string: expectedUrlFragment)!, statusCode: statusCode, httpVersion: nil, headerFields: [:])
        mockNetworkService.expectedResponse = HttpConnection(data: responseData, response: response, error: nil)
    }

    private func simulateComingEventAndWait(_ event : Event) {
        testableExtensionRuntime.simulateComingEvent(event: event)
        // sleep added to ensure DispatchQueue tasks are processed in time for test verification
        sleep(1)
    }

    // add shared state data to the analytics state for testing
    private func addSharedStateDataToAnalyticsState() {
        var dataMap = [String: [String: Any]]()

        // add lifecycle data
        let sessionStartTimestamp: TimeInterval = 1000
        let lifecycleMaxSessionLength: TimeInterval = 2000
        let os = "iOS"
        let deviceName = "iPhone 12 Pro Max"
        let deviceResolution = "1284 * 2778"
        let carrierName = "Adobe"
        let runMode = "run mode"
        let appId = "1234"
        let locale = "en-US"

        var lifecycleContextData = [String: String]()
        lifecycleContextData[AnalyticsTestConstants.Lifecycle.EventDataKeys.OPERATING_SYSTEM] = os
        lifecycleContextData[AnalyticsTestConstants.Lifecycle.EventDataKeys.DEVICE_NAME] = deviceName
        lifecycleContextData[AnalyticsTestConstants.Lifecycle.EventDataKeys.DEVICE_RESOLUTION] = deviceResolution
        lifecycleContextData[AnalyticsTestConstants.Lifecycle.EventDataKeys.CARRIER_NAME] = carrierName
        lifecycleContextData[AnalyticsTestConstants.Lifecycle.EventDataKeys.RUN_MODE] = runMode
        lifecycleContextData[AnalyticsTestConstants.Lifecycle.EventDataKeys.APP_ID] = appId
        lifecycleContextData[AnalyticsTestConstants.Lifecycle.EventDataKeys.LOCALE] = locale

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

    // add data to analytics properties for testing
    private func addDataToAnalyticsProperties() {
        let today = Date()
        let yesterday = today.addingTimeInterval(-24.0 * 3600.0)
        analyticsProperties.locale = Locale(identifier: "testLocale")
        analyticsProperties.setAnalyticsIdentifier(aid: "testAid")
        analyticsProperties.setAnalyticsVisitorIdentifier(vid: "testVid")
        analyticsProperties.lifecyclePreviousSessionPauseTimestamp = yesterday
        analyticsProperties.lifecyclePreviousPauseEventTimestamp = today
        analyticsProperties.referrerTimerRunning = true
        analyticsProperties.lifecycleTimerRunning = true
    }

    // set testing settings via configuration response event
    private func dispatchConfigurationEventForTesting(rsid: String?, host: String?, privacyStatus: PrivacyStatus, backDateSession: Bool, offlineEnabled: Bool, mockNetworkService: MockNetworking?) {
        // setup configuration data
        let configData = [AnalyticsTestConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY: privacyStatus.rawValue, AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_REPORT_SUITES: rsid as Any, AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_SERVER: host as Any, AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_OFFLINE_TRACKING: offlineEnabled, AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_BACKDATE_PREVIOUS_SESSION: backDateSession] as [String: Any]
        // create a configuration event with the created event data
        let configEvent = Event(name: "configuration response event", type: EventType.configuration, source: EventSource.responseContent, data: configData)
        testableExtensionRuntime.simulateSharedState(extensionName: AnalyticsTestConstants.Configuration.EventDataKeys.SHARED_STATE_NAME, event: configEvent, data: (configData, .set))
        let _ = analytics.readyForEvent(configEvent)
        // dispatch the event
        simulateComingEventAndWait(configEvent)

        // clear network requests and created shared states as an analytics id request will be sent on the first valid configuration response event.
        sleep(1)
        if mockNetworkService != nil {
            mockNetworkService?.calledNetworkRequests.removeAll()
        }
        testableExtensionRuntime.createdSharedStates.removeAll()
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

    // ==========================================================================
    // handleConfigurationResponseEvent
    // ==========================================================================
    func testHandleConfigurationResponse_HappyPath() {
        // create configuration event
        let server = "analytics_server"
        let rsids = "rsid1, rsid2"
        let privacyStatusString = "optedin"
        var configData = [String: Any]()
        configData[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_SERVER] = server
        configData[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_REPORT_SUITES] = rsids
        configData[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_AAMFORWARDING] = true
        configData[AnalyticsTestConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY] = privacyStatusString
        // create the configuration response content event with the data
        let event = Event(name: "Test Configuration response", type: EventType.configuration, source: EventSource.responseContent, data: configData)
        let _ = analytics.readyForEvent(event)
        // setup config shared state
        testableExtensionRuntime.simulateSharedState(extensionName: AnalyticsTestConstants.Configuration.EventDataKeys.SHARED_STATE_NAME, event: event, data: (configData, .set))
        // test
        simulateComingEventAndWait(event)
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
        var configData = [String: Any]()
        configData[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_SERVER] = server
        configData[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_REPORT_SUITES] = rsids
        configData[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_AAMFORWARDING] = true
        configData[AnalyticsTestConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY] = privacyStatusString
        // create the configuration response content event with the data
        let event = Event(name: "Test Configuration response", type: EventType.configuration, source: EventSource.responseContent, data: configData)
        // setup config shared state
        testableExtensionRuntime.simulateSharedState(extensionName: AnalyticsTestConstants.Configuration.EventDataKeys.SHARED_STATE_NAME, event: event, data: (configData, .set))
        // test
        simulateComingEventAndWait(event)
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
        // add data to analytics properties
        addDataToAnalyticsProperties()
        // setup shared state data for lifecycle, identity, places, and assurance
        addSharedStateDataToAnalyticsState()
        // create configuration event
        let server = "analytics_server"
        let rsids = "rsid1, rsid2"
        let marketingCloudOrgId = "marketingserver"
        let privacyStatusString = "optedout"
        let launchHitDelay : TimeInterval = 300
        var configData = [String: Any]()
        configData[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_SERVER] = server
        configData[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_REPORT_SUITES] = rsids
        configData[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_AAMFORWARDING] = true
        configData[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_OFFLINE_TRACKING] = true
        configData[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_LAUNCH_HIT_DELAY] = launchHitDelay
        configData[AnalyticsTestConstants.Configuration.EventDataKeys.MARKETING_CLOUD_ORGID_KEY] = marketingCloudOrgId
        configData[AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_BACKDATE_PREVIOUS_SESSION] = true
        configData[AnalyticsTestConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY] = privacyStatusString
        // create the configuration response content event with the data
        let event = Event(name: "Test Configuration response", type: EventType.configuration, source: EventSource.responseContent, data: configData)
        // setup config shared state
        testableExtensionRuntime.simulateSharedState(extensionName: AnalyticsTestConstants.Configuration.EventDataKeys.SHARED_STATE_NAME, event: event, data: (configData, .set))
        // test
        simulateComingEventAndWait(event)
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
        // verify assurance data was reset to default
        XCTAssertFalse(analyticsState.assuranceSessionActive)
        // verify analytics properties was cleared / reset to default
        var retrievedProperties = analytics.getAnalyticsProperties()
        XCTAssertNil(retrievedProperties.locale)
        XCTAssertNil(retrievedProperties.getAnalyticsIdentifier())
        XCTAssertNil(retrievedProperties.getVisitorIdentifier())
        XCTAssertNil(retrievedProperties.lifecyclePreviousSessionPauseTimestamp)
        XCTAssertNil(retrievedProperties.lifecyclePreviousPauseEventTimestamp)
        XCTAssertFalse(retrievedProperties.referrerTimerRunning)
        XCTAssertFalse(retrievedProperties.lifecycleTimerRunning)
        // TODO: verify privacy status within AnalyticsHitsDatabse is updated as well
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
        simulateComingEventAndWait(event)

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
        let mockNetworkService = ServiceProvider.shared.networkService as! MockNetworking
        let data = [AnalyticsConstants.EventDataKeys.VISITOR_IDENTIFIER: "testVid"] as [String: Any]
        dispatchConfigurationEventForTesting(rsid: "testRsid", host: "testAnalyticsServer.com", privacyStatus: .optedOut, backDateSession: true, offlineEnabled: true, mockNetworkService: mockNetworkService)
        // create the analytics request identity event with the data
        let event = Event(name: "Test Analytics request identity", type: EventType.analytics, source: EventSource.requestIdentity, data: data)
        let _ = analytics.readyForEvent(event)

        // test
        simulateComingEventAndWait(event)

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
        setDefaultResponse(responseData: AnalyticsTest.aidResponse.data(using: .utf8), expectedUrlFragment: "https://testAnalyticsServer.com", statusCode: 200, mockNetworkService: mockNetworkService)
        dispatchConfigurationEventForTesting(rsid: "testRsid", host: "testAnalyticsServer.com", privacyStatus: .optedIn, backDateSession: true, offlineEnabled: true, mockNetworkService: mockNetworkService)
        // create the analytics request identity event with the data
        let event = Event(name: "Test Analytics request identity", type: EventType.analytics, source: EventSource.requestIdentity, data: nil)
        let _ = analytics.readyForEvent(event)

        // test
        simulateComingEventAndWait(event)

        // verify network request is sent
        XCTAssertEqual(1, mockNetworkService.calledNetworkRequests.count)
        XCTAssertEqual("https://testAnalyticsServer.com/id?", mockNetworkService.calledNetworkRequests[0]?.url.absoluteString)
        // verify shared state with AID was created
        XCTAssertEqual(1, testableExtensionRuntime.createdSharedStates.count)
        let sharedState = testableExtensionRuntime.createdSharedStates[0]
        XCTAssertEqual(AnalyticsTest.responseAid, (sharedState?[AnalyticsConstants.EventDataKeys.ANALYTICS_ID] as? String))
        // verify an AID was added to the datastore
        XCTAssertEqual(nil, dataStore.getString(key: AnalyticsConstants.DataStoreKeys.VISITOR_IDENTIFIER_KEY))
        XCTAssertEqual(AnalyticsTest.responseAid, (dataStore.getString(key: AnalyticsConstants.DataStoreKeys.AID_KEY)))
        // verify an analytics identity response event with identifiers was dispatched
        let responseEvent = testableExtensionRuntime.dispatchedEvents.first(where: { $0.responseID == event.id })
        XCTAssertEqual(1, responseEvent?.data?.count)
        XCTAssertEqual(AnalyticsTest.responseAid, (responseEvent?.data?[AnalyticsConstants.EventDataKeys.ANALYTICS_ID] as? String))
    }

    // getVisitorIdentifier server returns invalid json in response
    func testHandleAnalyticsRequestIdentityEventWithNoVid_InvalidAIDInResponse() {
        // setup
        let mockNetworkService = ServiceProvider.shared.networkService as! MockNetworking
        setDefaultResponse(responseData: AnalyticsTest.invalidAidResponse.data(using: .utf8), expectedUrlFragment: "https://testAnalyticsServer.com", statusCode: 200, mockNetworkService: mockNetworkService)
        dispatchConfigurationEventForTesting(rsid: "testRsid", host: "testAnalyticsServer.com", privacyStatus: .optedIn, backDateSession: true, offlineEnabled: true, mockNetworkService: mockNetworkService)
        // create the analytics request identity event with the data
        let event = Event(name: "Test Analytics request identity", type: EventType.analytics, source: EventSource.requestIdentity, data: nil)
        let _ = analytics.readyForEvent(event)

        // test
        simulateComingEventAndWait(event)

        // verify network request is sent
        XCTAssertEqual(1, mockNetworkService.calledNetworkRequests.count)
        XCTAssertEqual("https://testAnalyticsServer.com/id?", mockNetworkService.calledNetworkRequests[0]?.url.absoluteString)
        // verify an AID was added to the datastore
        let aid = dataStore.getString(key: AnalyticsConstants.DataStoreKeys.AID_KEY)
        XCTAssertEqual(nil, dataStore.getString(key: AnalyticsConstants.DataStoreKeys.VISITOR_IDENTIFIER_KEY))
        XCTAssertEqual(33, aid?.count) // anaytics identifier from generateAID method due to invalid json in response
        // verify shared state with AID was created
        XCTAssertEqual(1, testableExtensionRuntime.createdSharedStates.count)
        let sharedState = testableExtensionRuntime.createdSharedStates[0]
        XCTAssertEqual(aid, (sharedState?[AnalyticsConstants.EventDataKeys.ANALYTICS_ID] as? String))
        // verify an analytics identity response event with identifiers was dispatched
        let responseEvent = testableExtensionRuntime.dispatchedEvents.first(where: { $0.responseID == event.id })
        XCTAssertEqual(1, responseEvent?.data?.count)
        XCTAssertEqual(aid, (responseEvent?.data?[AnalyticsConstants.EventDataKeys.ANALYTICS_ID] as? String))
    }

    // getVisitorIdentifier server returns response without aid
    func testHandleAnalyticsRequestIdentityEventWithNoVid_NoAIDInResponse() {
        // setup
        let mockNetworkService = ServiceProvider.shared.networkService as! MockNetworking
        setDefaultResponse(responseData: AnalyticsTest.noAIDResponse.data(using: .utf8), expectedUrlFragment: "https://testAnalyticsServer.com", statusCode: 200, mockNetworkService: mockNetworkService)
        dispatchConfigurationEventForTesting(rsid: "testRsid", host: "testAnalyticsServer.com", privacyStatus: .optedIn, backDateSession: true, offlineEnabled: true, mockNetworkService: mockNetworkService)
        // create the analytics request identity event with the data
        let event = Event(name: "Test Analytics request identity", type: EventType.analytics, source: EventSource.requestIdentity, data: nil)
        let _ = analytics.readyForEvent(event)

        // test
        simulateComingEventAndWait(event)

        // verify network request is sent
        XCTAssertEqual(1, mockNetworkService.calledNetworkRequests.count)
        XCTAssertEqual("https://testAnalyticsServer.com/id?", mockNetworkService.calledNetworkRequests[0]?.url.absoluteString)
        // verify an AID was added to the datastore
        let aid = dataStore.getString(key: AnalyticsConstants.DataStoreKeys.AID_KEY)
        XCTAssertEqual(nil, dataStore.getString(key: AnalyticsConstants.DataStoreKeys.VISITOR_IDENTIFIER_KEY))
        XCTAssertEqual(33, aid?.count) // anaytics identifier from generateAID method due to no aid in response
        // verify shared state with AID was created
        XCTAssertEqual(1, testableExtensionRuntime.createdSharedStates.count)
        let sharedState = testableExtensionRuntime.createdSharedStates[0]
        XCTAssertEqual(aid, (sharedState?[AnalyticsConstants.EventDataKeys.ANALYTICS_ID] as? String))
        // verify an analytics identity response event with identifiers was dispatched
        let responseEvent = testableExtensionRuntime.dispatchedEvents.first(where: { $0.responseID == event.id })
        XCTAssertEqual(1, responseEvent?.data?.count)
        XCTAssertEqual(aid, (responseEvent?.data?[AnalyticsConstants.EventDataKeys.ANALYTICS_ID] as? String))
    }

    // getVisitorIdentifier when privacy opted out
    func testHandleAnalyticsRequestIdentityEventWithNoVid_WhenPrivacyOptedOut() {
        // setup
        let mockNetworkService = ServiceProvider.shared.networkService as! MockNetworking
        dispatchConfigurationEventForTesting(rsid: "testRsid", host: "testAnalyticsServer.com", privacyStatus: .optedOut, backDateSession: true, offlineEnabled: true, mockNetworkService: mockNetworkService)
        // create the analytics request identity event with the data
        let event = Event(name: "Test Analytics request identity", type: EventType.analytics, source: EventSource.requestIdentity, data: nil)
        let _ = analytics.readyForEvent(event)

        // test
        simulateComingEventAndWait(event)

        // verify no network request sent
        XCTAssertEqual(0, mockNetworkService.calledNetworkRequests.count)
        // verify 1 shared states created that has empty VID/AID
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
        dispatchConfigurationEventForTesting(rsid: "testRsid", host: "testAnalyticsServer.com", privacyStatus: .unknown, backDateSession: true, offlineEnabled: true, mockNetworkService: mockNetworkService)
        // create the analytics request identity event with the data
        let event = Event(name: "Test Analytics request identity", type: EventType.analytics, source: EventSource.requestIdentity, data: nil)
        let _ = analytics.readyForEvent(event)

        // test
        simulateComingEventAndWait(event)

        // verify no network request sent
        XCTAssertEqual(0, mockNetworkService.calledNetworkRequests.count)
        // verify an AID was added to the datastore
        let aid = dataStore.getString(key: AnalyticsConstants.DataStoreKeys.AID_KEY)
        XCTAssertEqual(nil, dataStore.getString(key: AnalyticsConstants.DataStoreKeys.VISITOR_IDENTIFIER_KEY))
        XCTAssertEqual(33, aid?.count) // anaytics identifier from generateAID method
        // verify shared state with AID was created
        XCTAssertEqual(1, testableExtensionRuntime.createdSharedStates.count)
        let sharedState = testableExtensionRuntime.createdSharedStates[0]
        XCTAssertEqual(aid, (sharedState?[AnalyticsConstants.EventDataKeys.ANALYTICS_ID] as? String))
        // verify an analytics identity response event with identifiers was dispatched
        let responseEvent = testableExtensionRuntime.dispatchedEvents.first(where: { $0.responseID == event.id })
        XCTAssertEqual(1, responseEvent?.data?.count)
        XCTAssertEqual(aid, (responseEvent?.data?[AnalyticsConstants.EventDataKeys.ANALYTICS_ID] as? String))
    }

    // verify analytics id request sent on first valid configuration response event
    func testVerifyAnalyticsIdRequestSentOnFirstValidConfigurationResponseEvent() {
        let mockNetworkService = ServiceProvider.shared.networkService as! MockNetworking
        setDefaultResponse(responseData: AnalyticsTest.aidResponse.data(using: .utf8), expectedUrlFragment: "https://testAnalyticsServer.com", statusCode: 200, mockNetworkService: mockNetworkService)
        // setup configuration data
        let configData = [AnalyticsTestConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY: PrivacyStatus.optedIn.rawValue, AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_REPORT_SUITES: "testRsid", AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_SERVER: "testAnalyticsServer.com"] as [String: Any]
        // create a configuration event with the created event data
        let event = Event(name: "configuration response event", type: EventType.configuration, source: EventSource.responseContent, data: configData)
        testableExtensionRuntime.simulateSharedState(extensionName: AnalyticsTestConstants.Configuration.EventDataKeys.SHARED_STATE_NAME, event: event, data: (configData, .set))

        // test
        simulateComingEventAndWait(event)

        // verify network request is sent
        XCTAssertEqual(1, mockNetworkService.calledNetworkRequests.count)
        XCTAssertEqual("https://testAnalyticsServer.com/id?", mockNetworkService.calledNetworkRequests[0]?.url.absoluteString)
        // verify shared state with AID was created
        XCTAssertEqual(1, testableExtensionRuntime.createdSharedStates.count)
        let sharedState = testableExtensionRuntime.createdSharedStates[0]
        XCTAssertEqual(AnalyticsTest.responseAid, (sharedState?[AnalyticsConstants.EventDataKeys.ANALYTICS_ID] as? String))
        // verify an AID was added to the datastore
        XCTAssertEqual(nil, dataStore.getString(key: AnalyticsConstants.DataStoreKeys.VISITOR_IDENTIFIER_KEY))
        XCTAssertEqual(AnalyticsTest.responseAid, (dataStore.getString(key: AnalyticsConstants.DataStoreKeys.AID_KEY)))
        // verify an analytics identity response event with identifiers was dispatched
        let responseEvent = testableExtensionRuntime.dispatchedEvents.first(where: { $0.responseID == event.id })
        XCTAssertEqual(1, responseEvent?.data?.count)
        XCTAssertEqual(AnalyticsTest.responseAid, (responseEvent?.data?[AnalyticsConstants.EventDataKeys.ANALYTICS_ID] as? String))
    }

    // ==========================================================================
    // handleAcquisitionEvent
    // ==========================================================================
    // TODO: add test case for acquisition response content event handled while referrer timer is running
    func testHandleAcquisitionResponseContentEvent() {
        // setup
        dispatchConfigurationEventForTesting(rsid: "testRsid", host: "testAnalyticsServer.com", privacyStatus: .optedIn, backDateSession: true, offlineEnabled: true, mockNetworkService: nil)
        // setup shared state data for lifecycle, identity, places, and assurance
        addSharedStateDataToAnalyticsState()
        let data = [AnalyticsConstants.EventDataKeys.CONTEXT_DATA: AnalyticsTest.referrerData] as [String: Any]
        // create the acquisition response content event with the data
        let event = Event(name: "Test Acquisition response content", type: EventType.acquisition, source: EventSource.responseContent, data: data)
        let _ = analytics.readyForEvent(event)

        // test
        simulateComingEventAndWait(event)

        // verify built request contains the expected data
        XCTAssertEqual(1, analyticsHitDatabase.trackRequests?.count)
        let contextData = AnalyticsDataProcessor.getContextData(source: analyticsHitDatabase.trackRequests?[0] ?? "")
        XCTAssertTrue(contextData.contains("&c."))
        XCTAssertTrue(contextData.contains("&.c"))
        // verify acquisition context data
        XCTAssertTrue(contextData.contains("&launch.&campaign."))
        XCTAssertTrue(contextData.contains("&trackingcode=1234567890"))
        XCTAssertTrue(contextData.contains("&source=mycompany"))
        XCTAssertTrue(contextData.contains("&.campaign&.launch"))
        XCTAssertTrue(contextData.contains("&referrer.&campaign."))
        XCTAssertTrue(contextData.contains("&trackingcode=1234567890"))
        XCTAssertTrue(contextData.contains("&source=mycompany"))
        XCTAssertTrue(contextData.contains("&name=myLink"))
        XCTAssertTrue(contextData.contains("&.campaign&.referrer"))
        XCTAssertTrue(contextData.contains("&acquisition.&custom.&amo1."))
        XCTAssertTrue(contextData.contains("&key2=amo1.value2"))
        XCTAssertTrue(contextData.contains("&key1=amo1.value1"))
        XCTAssertTrue(contextData.contains("&.amo1&.custom&.acquisition"))
        XCTAssertTrue(contextData.contains("&internalaction=AdobeLink"))
        // verify places context data
        XCTAssertTrue(contextData.contains("&loc."))
        XCTAssertTrue(contextData.contains("&poi=regionName"))
        XCTAssertTrue(contextData.contains("&poi.&id=regionId&.poi"))
        XCTAssertTrue(contextData.contains("&.loc"))
        // verify lifecycle context data
        XCTAssertTrue(contextData.contains("&a."))
        XCTAssertTrue(contextData.contains("&.a"))

        XCTAssertTrue(contextData.contains("&OSVersion=iOS"))
        XCTAssertTrue(contextData.contains("&DeviceName=iPhone%2012%20Pro%20Max"))
        XCTAssertTrue(contextData.contains("&Resolution=1284%20*%202778"))
        XCTAssertTrue(contextData.contains("&CarrierName=Adobe"))
        XCTAssertTrue(contextData.contains("&RunMode=run%20mode"))
        XCTAssertTrue(contextData.contains("&AppID=1234"))
    }

    // ==========================================================================
    // handleLifecycleEvent
    // ==========================================================================
    // TODO: add test cases for Generic Lifecycle Request Content (start / pause events)
    // TODO: add additional test cases for Lifecycle Response content events
    func testHandleLifecycleResponseContentEvent_OfflineAndBackdateSessionEnabled_SessionEvent() {
        // setup
        // set backdate session and offline enabled to true
        dispatchConfigurationEventForTesting(rsid: "testRsid", host: "testAnalyticsServer.com", privacyStatus: .optedIn, backDateSession: true, offlineEnabled: true, mockNetworkService: nil)
        // setup shared state data for lifecycle, identity, places, and assurance
        addSharedStateDataToAnalyticsState()
        // create lifecycle event data
        let lifecycleContextData = ["previoussessionpausetimestampmillis":"0","previoussessionstarttimestampmillis":"1600367248","starttimestampmillis":"1600371801","maxsessionlength":"604800","sessionevent":"start","prevsessionlength":"700000","previousosversion":"previousOsVersion","previousappid":"previousAppId"] as [String: String]
        let eventData = ["lifecyclecontextdata":lifecycleContextData] as [String: Any]
        // create the lifecycle response content event with the data
        let event = Event(name: "Test Lifecycle response content", type: EventType.lifecycle, source: EventSource.responseContent, data: eventData)
        let _ = analytics.readyForEvent(event)

        // test
        simulateComingEventAndWait(event)

        // verify built request contains the expected data
        XCTAssertEqual(1, analyticsHitDatabase.trackRequests?.count)
        let contextData = AnalyticsDataProcessor.getContextData(source: analyticsHitDatabase.trackRequests?[0] ?? "")
        XCTAssertTrue(contextData.contains("&c."))
        XCTAssertTrue(contextData.contains("&.c"))
        // verify places context data
        XCTAssertTrue(contextData.contains("&loc."))
        XCTAssertTrue(contextData.contains("&poi=regionName"))
        XCTAssertTrue(contextData.contains("&poi.&id=regionId&.poi"))
        XCTAssertTrue(contextData.contains("&.loc"))
        // verify lifecycle context data
        XCTAssertTrue(contextData.contains("&a."))
        XCTAssertTrue(contextData.contains("&.a"))
        XCTAssertTrue(contextData.contains("&OSVersion=previousOsVersion"))
        XCTAssertTrue(contextData.contains("&DeviceName=iPhone%2012%20Pro%20Max"))
        XCTAssertTrue(contextData.contains("&Resolution=1284%20*%202778"))
        XCTAssertTrue(contextData.contains("&CarrierName=Adobe"))
        XCTAssertTrue(contextData.contains("&RunMode=run%20mode"))
        XCTAssertTrue(contextData.contains("&AppID=previousAppId"))
        XCTAssertTrue(contextData.contains("&PrevSessionLength=70000"))
        XCTAssertTrue(contextData.contains("&internalaction=Session"))
    }

    func testHandleLifecycleResponseContentEvent_OfflineAndBackdateSessionEnabled_CrashEvent() {
        // setup
        // set backdate session and offline enabled to true
        dispatchConfigurationEventForTesting(rsid: "testRsid", host: "testAnalyticsServer.com", privacyStatus: .optedIn, backDateSession: true, offlineEnabled: true, mockNetworkService: nil)
        // setup shared state data for lifecycle, identity, places, and assurance
        addSharedStateDataToAnalyticsState()
        // create lifecycle event data
        let lifecycleContextData = ["crashevent":"a.CrashEvent","previousosversion":"previousOsVersion","previousappid":"previousAppId"] as [String: String]
        let eventData = ["lifecyclecontextdata":lifecycleContextData] as [String: Any]
        // create the lifecycle response content event with the data
        let event = Event(name: "Test Lifecycle response content", type: EventType.lifecycle, source: EventSource.responseContent, data: eventData)
        let _ = analytics.readyForEvent(event)

        // test
        simulateComingEventAndWait(event)

        // verify built request contains the expected data
        XCTAssertEqual(1, analyticsHitDatabase.trackRequests?.count)
        let contextData = AnalyticsDataProcessor.getContextData(source: analyticsHitDatabase.trackRequests?[0] ?? "")
        XCTAssertTrue(contextData.contains("&c."))
        XCTAssertTrue(contextData.contains("&.c"))
        // verify places context data
        XCTAssertTrue(contextData.contains("&loc."))
        XCTAssertTrue(contextData.contains("&poi=regionName"))
        XCTAssertTrue(contextData.contains("&poi.&id=regionId&.poi"))
        XCTAssertTrue(contextData.contains("&.loc"))
        // verify lifecycle context data
        XCTAssertTrue(contextData.contains("&a."))
        XCTAssertTrue(contextData.contains("&.a"))
        XCTAssertTrue(contextData.contains("&OSVersion=previousOsVersion"))
        XCTAssertTrue(contextData.contains("&DeviceName=iPhone%2012%20Pro%20Max"))
        XCTAssertTrue(contextData.contains("&Resolution=1284%20*%202778"))
        XCTAssertTrue(contextData.contains("&CarrierName=Adobe"))
        XCTAssertTrue(contextData.contains("&RunMode=run%20mode"))
        XCTAssertTrue(contextData.contains("&AppID=previousAppId"))
        XCTAssertTrue(contextData.contains("&CrashEvent=CrashEvent"))
        XCTAssertTrue(contextData.contains("&internalaction=Crash"))
    }
}
