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
import AEPServices
@testable import AEPAnalytics


class AnalyticsPropertiesTest: XCTestCase {

    var analyticsProperties:AnalyticsProperties!
    var dataStore:NamedCollectionDataStore!

    override func setUp() {
        ServiceProvider.shared.namedKeyValueService = MockDataStore()
        dataStore = NamedCollectionDataStore(name: AnalyticsTestConstants.DATASTORE_NAME)
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.MOST_RECENT_HIT_TIMESTAMP, value: TimeInterval(100))
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.AID, value: "testaid")
        dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.VID, value: "testvid")
        analyticsProperties = AnalyticsProperties.init(dataStore: dataStore)
    }

    func testTimezoneOffsetFormat() {
        let timezoneOffsetString = analyticsProperties.timezoneOffset
        let range = NSRange(location: 0, length: timezoneOffsetString.count)
        let regex = try! NSRegularExpression(pattern: "00/00/0000 00:00:00 0 \\d{1,}")

        XCTAssertTrue(regex.firstMatch(in: timezoneOffsetString, options: [], range: range) != nil)
    }

    func testReset() {
        XCTAssertEqual("testvid", analyticsProperties.getVisitorIdentifier())
        XCTAssertEqual("testaid", analyticsProperties.getAnalyticsIdentifier())
        XCTAssertEqual(100, analyticsProperties.getMostRecentHitTimestamp())

        //test
        analyticsProperties.reset()

        //verify
        XCTAssertNil(analyticsProperties.getVisitorIdentifier())
        XCTAssertNil(analyticsProperties.getAnalyticsIdentifier())
        XCTAssertEqual(0, analyticsProperties.getMostRecentHitTimestamp())
        XCTAssertNil(dataStore.getString(key: AnalyticsTestConstants.DataStoreKeys.AID))
        XCTAssertNil(dataStore.getString(key: AnalyticsTestConstants.DataStoreKeys.VID))
    }
}
