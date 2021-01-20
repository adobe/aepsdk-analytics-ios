/*
 Copyright 2021 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import XCTest
@testable import AEPAnalytics
@testable import AEPCore

class AnalyticsVersionTest : XCTestCase {

    var testableExtensionRuntime: TestableExtensionRuntime!
    var analytics:Analytics!
    var analyticsProperties: AnalyticsProperties!
    var analyticsState: AnalyticsState!

    override func setUp() {
        // setup test variables
        testableExtensionRuntime = TestableExtensionRuntime()
        analyticsState = AnalyticsState()
        analyticsProperties = AnalyticsProperties.init()
        analytics = Analytics(runtime: testableExtensionRuntime, state: analyticsState, properties: analyticsProperties)
        analytics.onRegistered()
    }

    func testGetVersion() {
        let version = analytics.getVersion()
        // verify Analytics version is 0.0.1 and MobileCore version is 3.0.0
        XCTAssertEqual(version, "IOSN000001030000")
    }
}
