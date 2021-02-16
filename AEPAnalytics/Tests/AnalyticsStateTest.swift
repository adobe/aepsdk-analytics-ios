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

import XCTest
import Foundation
@testable import AEPAnalytics
@testable import AEPCore


class AnalyticsStateTest : XCTestCase {

    private var analyticsState: AnalyticsState!

    override func setUp() {
        analyticsState = AnalyticsState()
    }

    func testExtractConfigurationInfoHappyFlow() {

        let server = "analytics_server"
        let rsids = "rsid1, rsid2"
        let marketingCloudOrgId = "marketingserver"
        let privacyStatusString = "optedin"
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

        var dataMap = [String: [String: Any]]()
        dataMap[AnalyticsTestConstants.Configuration.EventDataKeys.SHARED_STATE_NAME] = configurationData
        analyticsState.update(dataMap: dataMap)

        XCTAssertEqual(analyticsState.host, server)
        XCTAssertEqual(analyticsState.rsids, rsids)
        XCTAssertTrue(analyticsState.analyticForwardingEnabled)
        XCTAssertTrue(analyticsState.offlineEnabled)
        XCTAssertEqual(analyticsState.launchHitDelay, launchHitDelay, accuracy: 0)
        XCTAssertEqual(analyticsState.marketingCloudOrganizationId, marketingCloudOrgId)
        XCTAssertTrue(analyticsState.backDateSessionInfoEnabled)
        XCTAssertEqual(analyticsState.privacyStatus, PrivacyStatus.optedIn)
    }

    func testExtractConfigurationInfoWhenPrivacyStatusIsOptedOut() {
        let server = "analytics_server"
        let rsids = "rsid1, rsid2"
        let marketingCloudOrgId = "marketingserver"
        let privacyStatusString = "optedin"
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

        var dataMap = [String: [String: Any]]()
        dataMap[AnalyticsTestConstants.Configuration.EventDataKeys.SHARED_STATE_NAME] = configurationData
        analyticsState.update(dataMap: dataMap)

        XCTAssertEqual(analyticsState.host, server)
        XCTAssertEqual(analyticsState.rsids, rsids)
        XCTAssertTrue(analyticsState.analyticForwardingEnabled)
        XCTAssertTrue(analyticsState.offlineEnabled)
        XCTAssertEqual(analyticsState.launchHitDelay, launchHitDelay, accuracy: 0)
        XCTAssertEqual(analyticsState.marketingCloudOrganizationId, marketingCloudOrgId)
        XCTAssertTrue(analyticsState.backDateSessionInfoEnabled)
        XCTAssertEqual(analyticsState.privacyStatus, PrivacyStatus.optedIn)

        // opt out then check that data in state is either nil or default values
        configurationData[AnalyticsTestConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY] = "optedout"
        dataMap = [String: [String: Any]]()
        dataMap[AnalyticsTestConstants.Configuration.EventDataKeys.SHARED_STATE_NAME] = configurationData
        analyticsState.update(dataMap: dataMap)

        XCTAssertNil(analyticsState.host)
        XCTAssertNil(analyticsState.rsids)
        XCTAssertEqual(analyticsState.analyticForwardingEnabled, AnalyticsTestConstants.Default.FORWARDING_ENABLED)
        XCTAssertEqual(analyticsState.offlineEnabled, AnalyticsTestConstants.Default.OFFLINE_ENABLED)
        XCTAssertEqual(analyticsState.launchHitDelay, AnalyticsTestConstants.Default.LAUNCH_HIT_DELAY)
        XCTAssertNil(analyticsState.marketingCloudOrganizationId)
        XCTAssertEqual(analyticsState.backDateSessionInfoEnabled, AnalyticsTestConstants.Default.BACKDATE_SESSION_INFO_ENABLED)
        XCTAssertEqual(analyticsState.privacyStatus, PrivacyStatus.optedOut)
    }

    func testAnalyticsStateReturnsDefaultValuesWhenConfigurationInfoIsEmpty() {

        let dataMap = [String: [String: Any]]()
        analyticsState.update(dataMap: dataMap)

        XCTAssertNil(analyticsState.host)
        XCTAssertNil(analyticsState.rsids)
        XCTAssertTrue(analyticsState.analyticForwardingEnabled == AnalyticsTestConstants.Default.FORWARDING_ENABLED)
        XCTAssertTrue(analyticsState.offlineEnabled == AnalyticsConstants.Default.OFFLINE_ENABLED)
        XCTAssertEqual(analyticsState.launchHitDelay, 0, accuracy: 0)
        XCTAssertNil(analyticsState.marketingCloudOrganizationId)
        XCTAssertTrue(analyticsState.backDateSessionInfoEnabled == AnalyticsTestConstants.Default.BACKDATE_SESSION_INFO_ENABLED)
        XCTAssertEqual(analyticsState.privacyStatus, AnalyticsTestConstants.Default.PRIVACY_STATUS)

    }

    func testExtractLifecycleInfoHappyFlow() {

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

        var dataMap = [String: [String: Any]]()
        dataMap[AnalyticsTestConstants.Lifecycle.EventDataKeys.SHARED_STATE_NAME] = lifecycleData
        analyticsState.update(dataMap: dataMap)

        typealias AnalyticContextDataKeys = AnalyticsTestConstants.ContextDataKeys

        XCTAssertEqual(analyticsState.lifecycleSessionStartTimestamp, sessionStartTimestamp)

        XCTAssertEqual(analyticsState.lifecycleMaxSessionLength, lifecycleMaxSessionLength)
        XCTAssertEqual(analyticsState.defaultData[AnalyticContextDataKeys.OPERATING_SYSTEM], os)
        XCTAssertEqual(analyticsState.defaultData[AnalyticContextDataKeys.DEVICE_NAME], deviceName)
        XCTAssertEqual(analyticsState.defaultData[AnalyticContextDataKeys.DEVICE_RESOLUTION], deviceResolution)
        XCTAssertEqual(analyticsState.defaultData[AnalyticContextDataKeys.CARRIER_NAME], carrierName)
        XCTAssertEqual(analyticsState.defaultData[AnalyticContextDataKeys.RUN_MODE], runMode)
        XCTAssertEqual(analyticsState.defaultData[AnalyticContextDataKeys.APPLICATION_IDENTIFIER], appId)
    }

    func testAnalyticsStateReturnsDefaultLifecycleValuesWhenLifeycleDataIsEmpty() {

        var dataMap = [String: [String: Any]]()
        dataMap[AnalyticsTestConstants.Lifecycle.EventDataKeys.SHARED_STATE_NAME] = [String: Any]()
        analyticsState.update(dataMap: dataMap)

        XCTAssertTrue(analyticsState.defaultData.isEmpty)
        XCTAssertEqual(analyticsState.lifecycleSessionStartTimestamp, TimeInterval.init())
        XCTAssertEqual(analyticsState.lifecycleMaxSessionLength, TimeInterval.init())
    }

    func testExtractIdentityInfoHappyFlow() {

        let marketingCloudId = "marketingCloudId"
        let blob = "blob"
        let locationHint = "locationHint"
        let advertisingId = "advertisingId"

        typealias IdentityEventDataKeys = AnalyticsTestConstants.Identity.EventDataKeys
        var identityData = [String: Any]()

        identityData[IdentityEventDataKeys.VISITOR_ID_MID] = marketingCloudId
        identityData[IdentityEventDataKeys.VISITOR_ID_BLOB] = blob
        identityData[IdentityEventDataKeys.VISITOR_ID_LOCATION_HINT] = locationHint
        identityData[IdentityEventDataKeys.ADVERTISING_IDENTIFIER] = advertisingId
        //MARK: TODO update the unit test below.
//        if let identifiableArray = identityData[IdentityEventDataKeys.VISITOR_IDS_LIST] as? [Identifiable] {
//            serializedVisitorIdsList = analyticsRequestSerializer.generateAnalyticsCustomerIdString(from: identifiableArray)
//        }
        var dataMap = [String: [String: Any]]()
        dataMap[AnalyticsTestConstants.Identity.EventDataKeys.SHARED_STATE_NAME] = identityData
        analyticsState.update(dataMap: dataMap)

        XCTAssertEqual(analyticsState.marketingCloudId, marketingCloudId)
        XCTAssertEqual(analyticsState.blob, blob)
        XCTAssertEqual(analyticsState.locationHint, locationHint)
        XCTAssertEqual(analyticsState.advertisingId, advertisingId)
    }

    func testAnalyticsStateReturnsDefaultIdentityValuesWhenIdentityInfoIsEmpty() {
        var dataMap = [String: [String: Any]]()
        dataMap[AnalyticsTestConstants.Identity.EventDataKeys.SHARED_STATE_NAME] = [String: Any]()
        analyticsState.update(dataMap: dataMap)

        XCTAssertNil(analyticsState.marketingCloudId)
        XCTAssertNil(analyticsState.blob)
        XCTAssertNil(analyticsState.locationHint)
        XCTAssertNil(analyticsState.advertisingId)
        XCTAssertNil(analyticsState.serializedVisitorIdsList)
    }

    func testExtractPlacesInfoHappyFlow() {

        let regionId = "regionId"
        let regionName = "regionName"
        typealias PlacesEventDataKeys = AnalyticsTestConstants.Places.EventDataKeys

        var placesContextData = [String: String]()
        placesContextData[PlacesEventDataKeys.REGION_ID] = regionId
        placesContextData[PlacesEventDataKeys.REGION_NAME] = regionName

        var placesData = [String: Any]()
        placesData[PlacesEventDataKeys.CURRENT_POI] =  placesContextData

        var dataMap = [String: [String: Any]]()
        dataMap[AnalyticsTestConstants.Places.EventDataKeys.SHARED_STATE_NAME] = placesData

        analyticsState.update(dataMap: dataMap)
        XCTAssertEqual(analyticsState.defaultData[AnalyticsTestConstants.ContextDataKeys.REGION_ID], regionId)
        XCTAssertEqual(analyticsState.defaultData[AnalyticsTestConstants.ContextDataKeys.REGION_NAME], regionName)

    }

    func testAnalyticsStateReturnsDefaultPlacesValueWhenPlacesInfoIsEmpty() {

        var dataMap = [String: [String: Any]]()
        dataMap[AnalyticsTestConstants.Places.EventDataKeys.SHARED_STATE_NAME] = [String: Any]()

        analyticsState.update(dataMap: dataMap)

        XCTAssertNil(analyticsState.defaultData[AnalyticsTestConstants.ContextDataKeys.REGION_ID])
        XCTAssertNil(analyticsState.defaultData[AnalyticsTestConstants.ContextDataKeys.REGION_NAME])
    }

    func testExtractAssuranceInfoHappyFlow() {

        let sessionId = "sessionId"
        typealias AssuranceEventDataKeys = AnalyticsTestConstants.Assurance.EventDataKeys

        var assuranceData = [String: String]()
        assuranceData[AssuranceEventDataKeys.SESSION_ID] = sessionId

        var dataMap = [String: [String: Any]]()
        dataMap[AssuranceEventDataKeys.SHARED_STATE_NAME] = assuranceData

        analyticsState.update(dataMap: dataMap)

        XCTAssertTrue(analyticsState.assuranceSessionActive)
    }

    func testAnalyticsStateReturnsAssuranceStateInactiveWithEmptyAssuranceInfo() {

        typealias AssuranceEventDataKeys = AnalyticsTestConstants.Assurance.EventDataKeys

        var dataMap = [String: [String: Any]]()
        dataMap[AssuranceEventDataKeys.SHARED_STATE_NAME] = [String: String]()

        analyticsState.update(dataMap: dataMap)

        XCTAssertFalse(analyticsState.assuranceSessionActive)
    }

    func testGetBaseUrlWhenSSLAndForwarding() {
        analyticsState.analyticForwardingEnabled = true
        analyticsState.host = "test.com"
        analyticsState.rsids = "rsid1,rsid2"

        XCTAssertEqual("https://test.com/b/ss/rsid1,rsid2/10/version1.0/s", analyticsState.getBaseUrl(sdkVersion: "version1.0")?.absoluteString)
    }

    func testGetBaseUrlWhenSSLAndNotForwarding() {
        analyticsState.analyticForwardingEnabled = false
        analyticsState.host = "test.com"
        analyticsState.rsids = "rsid1,rsid2"

        XCTAssertEqual("https://test.com/b/ss/rsid1,rsid2/0/version1.0/s", analyticsState.getBaseUrl(sdkVersion: "version1.0")?.absoluteString)
    }

    func testIsAnalyticsConfiguredHappyFlow() {
        analyticsState.host = "test.com"
        analyticsState.rsids = "rsid1,rsid2"
        XCTAssertTrue(analyticsState.isAnalyticsConfigured())
    }

    func testIsAnalyticsConfiguredReturnsFalseWhenNoServerIds() {
        analyticsState.host = ""
        analyticsState.rsids = "rsid1,rsid2"
        XCTAssertFalse(analyticsState.isAnalyticsConfigured())
    }

//    var analyticsIdVisitorParameters = [String: String]()
//    guard let marketingCloudId = marketingCloudId, !marketingCloudId.isEmpty else {
//        return analyticsIdVisitorParameters
//    }
//    analyticsIdVisitorParameters[AnalyticsConstants.ParameterKeys.KEY_MID] = marketingCloudId
//    if let blob = blob, !blob.isEmpty {
//        analyticsIdVisitorParameters[AnalyticsConstants.ParameterKeys.KEY_BLOB] = blob
//    }
//    if let locationHint = locationHint, !locationHint.isEmpty {
//        analyticsIdVisitorParameters[AnalyticsConstants.ParameterKeys.KEY_LOCATION_HINT] = locationHint
//    }
//    return analyticsIdVisitorParameters

    func testIsAnalyticsConfiguredReturnsFalseWhenNoRsids() {
        analyticsState.host = "serverId"
        analyticsState.rsids = ""
        XCTAssertFalse(analyticsState.isAnalyticsConfigured())
    }

    func testGetAnalyticsIdVisitorParameters() {

        let marketingCloudId = "marketingCloudId"
        let blob = "blob"
        let locationHint = "locationHint"

        analyticsState.marketingCloudId = marketingCloudId
        analyticsState.blob = blob
        analyticsState.locationHint = locationHint

        let visitorParameterMap = analyticsState.getAnalyticsIdVisitorParameters()

        XCTAssertEqual(visitorParameterMap[AnalyticsTestConstants.ParameterKeys.KEY_MID], marketingCloudId)
        XCTAssertEqual(visitorParameterMap[AnalyticsTestConstants.ParameterKeys.KEY_BLOB], blob)
        XCTAssertEqual(visitorParameterMap[AnalyticsTestConstants.ParameterKeys.KEY_LOCATION_HINT], locationHint)

    }

    func testGetAnalyticsIdVisitorParametersWhenVisitorDataIsAbsent() {
        XCTAssertTrue(analyticsState.getAnalyticsIdVisitorParameters().isEmpty)

    }
}
