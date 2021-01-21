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
    var analytics: Analytics!
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

    func testGetVersion_HappyPath() {
        let version = analytics.getVersion()
        // verify Analytics version is 0.0.1 and MobileCore version is 3.0.0
        XCTAssertEqual(version, "IOSN000001030000")
    }

    func testGetVersion_With_XamarinWrapperType() {
        MobileCore.setWrapperType(.xamarin)
        let version = analytics.getVersion()
        // verify wrapper type is "X"
        XCTAssertEqual(version, "IOSX000001030000")
    }

    func testGetVersion_With_UnityWrapperType() {
        MobileCore.setWrapperType(.unity)
        let version = analytics.getVersion()
        // verify wrapper type is "U"
        XCTAssertEqual(version, "IOSU000001030000")
    }

    func testGetVersion_With_ReactNativeWrapperType() {
        MobileCore.setWrapperType(.reactNative)
        let version = analytics.getVersion()
        // verify wrapper type is "R"
        XCTAssertEqual(version, "IOSR000001030000")
    }

    func testBuildVersionString_With_SingleAndDoubleDigitVersionNumbers() {
        let builtVersionString = analytics.buildVersionString(osType: "TOS", analyticsVersion: "9.18.27", coreVersion: "11.12.13-" + WrapperType.cordova.rawValue)
        // verify built version string and correct wrapper type of "C"
        XCTAssertEqual(builtVersionString, "TOSC091827111213")
    }

    func testBuildVersionString_With_DoubleDigitVersionNumbers() {
        let builtVersionString = analytics.buildVersionString(osType: "WOS", analyticsVersion: "22.33.44", coreVersion: "55.66.77-" + WrapperType.flutter.rawValue)
        // verify built version string and correct wrapper type of "F"
        XCTAssertEqual(builtVersionString, "WOSF223344556677")
    }

    func testBuildVersionString_With_InvalidAnalyticsVersion() {
        let builtVersionString = analytics.buildVersionString(osType: "IOS", analyticsVersion: "33.44", coreVersion: "55.66.77-" + WrapperType.xamarin.rawValue)
        // verify version string contains fallback version of "000000" and correct wrapper type of "X"
        XCTAssertEqual(builtVersionString, "IOSX000000556677")
    }
}
