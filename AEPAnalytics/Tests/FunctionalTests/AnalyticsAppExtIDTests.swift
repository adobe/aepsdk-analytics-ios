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
import AEPServices
@testable import AEPAnalytics
@testable import AEPCore

@available(tvOSApplicationExtension, unavailable)
class AnalyticsAppExtIDTests : AnalyticsIDTestBase {
    
    override func setUp() {
        runningForApp = false
        super.setupBase(forApp: false)
    }
    
    //If Visitor ID Service is enabled then analytics hits contain visitor ID vars
    func testHitsContainVisitorIDVars() {
        hitsContainVisitorIDVarsTester()
    }
        
    func testHitsContainAIDandVID() {
        hitsContainAIDandVIDTester()
    }
    
    func testOptOut_ShouldNotReadAidVid() {
        optOut_ShouldNotReadAidVidTester()
    }
    
    // Set visitor id should dispatch event
    func testVisitorId() {
        visitorIdTester()
    }
    
    // Set visitor id should dispatch event
    func testOptOut_ShouldNotUpdateVid() {
        optOut_ShouldNotUpdateVidTester()
    }
    
    func testAIDandVIDShouldBeClearedAfterOptOut() {
        aIDandVIDShouldBeClearedAfterOptOutTester()
    }
    
    func testHandleRequestResetEvent() {
        handleRequestResetEventTester()
    }
}
