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

    func testExtractConfigurationInfoHappyFlow() {

        let server = "analytics_server"
        let rsids = "rsid1, rsid2"
        let marketingCloudOrgId = "marketingserver"
        let privacyStatusString = "optedout"
        let launchHitDelay : Double = 300

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
        let analyticsState = AnalyticsState.init(dataMap: dataMap)

        XCTAssertEqual(analyticsState.host, server)
        XCTAssertEqual(analyticsState.rsids, rsids)
        XCTAssertTrue(analyticsState.analyticForwardingEnabled)
        XCTAssertTrue(analyticsState.offlineEnabled)
        XCTAssertEqual(analyticsState.launchHitDelay.timeIntervalSince1970, launchHitDelay, accuracy: 0)
        XCTAssertEqual(analyticsState.marketingCloudOrganizationId, marketingCloudOrgId)
        XCTAssertTrue(analyticsState.backDateSessionInfoEnabled)
        XCTAssertEqual(analyticsState.privacyStatus, PrivacyStatus.optedOut)
    }

    func testAnalyticsStateReturnsDefaultValuesWhenConfigurationInfoIsEmpty() {

        let dataMap = [String: [String: Any]]()
        let analyticsState = AnalyticsState.init(dataMap: dataMap)

        XCTAssertNil(analyticsState.host)
        XCTAssertNil(analyticsState.rsids)
        XCTAssertTrue(analyticsState.analyticForwardingEnabled == AnalyticsTestConstants.Default.DEFAULT_FORWARDING_ENABLED)
        XCTAssertTrue(analyticsState.offlineEnabled == AnalyticsConstants.Default.DEFAULT_OFFLINE_ENABLED)
        // MARK: Fix the below commented Assert.
//        XCTAssertEqual(analyticsState.launchHitDelay.timeIntervalSince1970, launchHitDelay, accuracy: 0)
        XCTAssertNil(analyticsState.marketingCloudOrganizationId)
        XCTAssertTrue(analyticsState.backDateSessionInfoEnabled == AnalyticsTestConstants.Default.DEFAULT_BACKDATE_SESSION_INFO_ENABLED)
        XCTAssertEqual(analyticsState.privacyStatus, AnalyticsTestConstants.Default.DEFAULT_PRIVACY_STATUS)

    }

}
