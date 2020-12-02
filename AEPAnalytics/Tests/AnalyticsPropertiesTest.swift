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
@testable import AEPAnalytics


class AnalyticsPropertiesTest: XCTestCase {
        
    var analyticsProperties = AnalyticsProperties()
    
    override func setUp() {}
    
    func testTimezoneOffsetFormat() {
        
        let timezoneOffsetString = analyticsProperties.timezoneOffset
        let range = NSRange(location: 0, length: timezoneOffsetString.count)
        let regex = try! NSRegularExpression(pattern: "00/00/0000 00:00:00 0 \\d{1,}")
        
        XCTAssertTrue(regex.firstMatch(in: timezoneOffsetString, options: [], range: range) != nil)
    }
    
    func testCancelReffererTimer() {
        
        analyticsProperties.referrerTimerRunning = true
        analyticsProperties.referrerDispatchWorkItem = DispatchWorkItem{}
        
        XCTAssertNotNil(analyticsProperties.referrerDispatchWorkItem)
        XCTAssertTrue(analyticsProperties.referrerTimerRunning)
                                
        analyticsProperties.cancelReferrerTimer()
        
        XCTAssertNil(analyticsProperties.referrerDispatchWorkItem)
        XCTAssertFalse(analyticsProperties.referrerTimerRunning)
    }
    
    func testCancelLifecycleTimer() {

        analyticsProperties.lifecycleTimerRunning = true
        analyticsProperties.lifecycleDispatchWorkItem = DispatchWorkItem{}
        
        XCTAssertNotNil(analyticsProperties.lifecycleDispatchWorkItem)
        XCTAssertTrue(analyticsProperties.lifecycleTimerRunning)
                                
        analyticsProperties.cancelLifecycleTimer()
        
        XCTAssertNil(analyticsProperties.lifecycleDispatchWorkItem)
        XCTAssertFalse(analyticsProperties.lifecycleTimerRunning)
    }
}
