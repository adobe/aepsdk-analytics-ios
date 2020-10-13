//
//  AnalyticsPropertiesTest.swift
//  AEPAnalyticsTests
//
//  Created by shtomar on 10/12/20.
//  Copyright © 2020 Adobe. All rights reserved.
//

import XCTest
@testable import AEPAnalytics


class AnalyticsPropertiesTest: XCTestCase {
        
    var analyticsProperties = AnalyticsProperties()
    
    override func setUp() {}
    
    func testTimezoneOffsetFormat() {
        
        XCTAssertTrue(analyticsProperties.timezoneOffset.starts(with: "00/00/0000 00:00:00 0"))
    }
    
    func testCancelReffererTimer() {
        
        analyticsProperties.referrerTimerRunning = true
        analyticsProperties.referrerTimer = Timer.init(fire: Date.init(), interval: 1000, repeats: false, block: {timer in })
        
        XCTAssertNotNil(analyticsProperties.referrerTimer)
        XCTAssertTrue(analyticsProperties.referrerTimerRunning)
                                
        analyticsProperties.cancelReferrerTimer()
        
        XCTAssertNil(analyticsProperties.referrerTimer)
        XCTAssertFalse(analyticsProperties.referrerTimerRunning)
    }
    
    func testCancelLifecycleTimer() {

        analyticsProperties.lifecycleTimerRunning = true
        analyticsProperties.lifecycleTimer = Timer.init(fire: Date.init(), interval: 1000, repeats: false, block: {timer in })
        
        XCTAssertNotNil(analyticsProperties.lifecycleTimer)
        XCTAssertTrue(analyticsProperties.lifecycleTimerRunning)
                                
        analyticsProperties.cancelLifecycleTimer()
        
        XCTAssertNil(analyticsProperties.lifecycleTimer)
        XCTAssertFalse(analyticsProperties.lifecycleTimerRunning)
    }
}
