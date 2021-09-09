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
@testable import AEPCore

@testable import AEPAnalytics

class URL_AnalyticsTests: XCTestCase {

    let version = AnalyticsVersion.getVersion()
    var analyticsState: AnalyticsState!

    override func setUp() {
        analyticsState = AnalyticsState()
    }

    func testGetBaseUrlNilWhenAnalyticsNotConfiguredEmpty() {
        XCTAssertNil(URL.getAnalyticsBaseUrl(state: analyticsState))        
    }

    func testGetBaseUrlWhenAnalyticsForwarding() {
        analyticsState.analyticForwardingEnabled = true
        analyticsState.host = "test.com"
        analyticsState.rsids = "rsid1,rsid2"

        XCTAssertEqual("https://test.com/b/ss/rsid1,rsid2/10/\(version)/s", URL.getAnalyticsBaseUrl(state: analyticsState)?.absoluteString)
    }

    func testGetBaseUrlWhenAnalyticsNotForwarding() {
        analyticsState.analyticForwardingEnabled = false
        analyticsState.host = "test.com"
        analyticsState.rsids = "rsid1,rsid2"

        XCTAssertEqual("https://test.com/b/ss/rsid1,rsid2/0/\(version)/s", URL.getAnalyticsBaseUrl(state: analyticsState)?.absoluteString)
    }
}
