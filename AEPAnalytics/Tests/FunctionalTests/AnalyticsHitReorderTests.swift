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
class AnlyticsHitReorderTests: AnalyticsHitReorderTestBase {
    override func setUp() {
        runningForAppTests = true
        super.setupBase(forApp: true)
    }
    
    //Lifecycle data and acquisition data appended to the first custom analytics hit
    func testDataAppendedToFirstCustomHit() {
        dataAppendedToFirstCustomHitTester()
    }

    // Verify acquisition data sent out on second hit if referrer timer is exceeded
    func testAcquisitionDataTimeOutForInstall() {
        acquisitionDataTimeOutForInstallTester()
    }

    // Verify if custom track occurs first then lifecycle and acquisition data are included on second custom track
    func testAnalyticsRequestMadePriorToCollectionOfLifecycleAndAcquisition() {
        analyticsRequestMadePriorToCollectionOfLifecycleAndAcquisitionTester()
    }

    // Verify no custom track occurs until lifecycle and acquisition data are processed
    func testCustomTrackWaitsForProcessingOfLifecycleAndAcquisition() {
        customTrackWaitsForProcessingOfLifecycleAndAcquisitionTester()
    }

    // Acquisition as seperate hit
    func testAcquisitionSentAsSeperateHit() {
        acquisitionSentAsSeperateHitTester()
    }

}

