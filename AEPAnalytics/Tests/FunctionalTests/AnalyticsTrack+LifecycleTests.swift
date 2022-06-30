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
class AnalyticsTrack_LifecycleTests : AnalyticsTrack_LifecycleTestBase {
    override func setUp() {
        runningForApp = true
        super.setupBase(forApp: true)
    }
    
    //If Lifecycle shared state is available then analytics hits contain lifecycle vars
    func testHitsContainLifecycleVars() {
        hitsContainLifecycleVarsTester()
    }

    //Lifecycle sends a crash event with previous OS version and previous app version if present in response
    func testLifecycleBackdatedCrashHit() {
        lifecycleBackdatedCrashHitTester()
    }

    func testLifecycleBackdatedSessionInfo() {
        lifecycleBackdatedSessionInfoTester()
    }

    //If Lifecycle shared state is available then analytics hits contain lifecycle vars
    func testHitsContainTimeSinceLaunch() {
        hitsContainTimeSinceLaunchTester()
    }
}
