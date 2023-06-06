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

class AnalyticsDatabaseTest: XCTestCase {

    var database: AnalyticsDatabase!
    var analyticsState: AnalyticsState!
    var mockProcessor: MockHitProcessor!
    var mockDataQueueService: MockDataQueueService? {
        return AnalyticsDatabase.dataQueueService as? MockDataQueueService
    }

    let hit1 = AnalyticsHit(payload: "payload1", timestamp: Date().timeIntervalSince1970, eventIdentifier: UUID().uuidString)
    let hit2 = AnalyticsHit(payload: "payload2", timestamp: Date().timeIntervalSince1970, eventIdentifier: UUID().uuidString)
    let hit3 = AnalyticsHit(payload: "payload3", timestamp: Date().timeIntervalSince1970, eventIdentifier: UUID().uuidString)

    override func setUp() {
        AnalyticsDatabase.dataQueueService = MockDataQueueService()

        analyticsState = AnalyticsState()
        analyticsState.host = "test.com"
        analyticsState.rsids = "rsids"
        analyticsState.privacyStatus = .optedIn

        mockProcessor = MockHitProcessor()
        guard let database = AnalyticsDatabase(state: analyticsState, processor: mockProcessor) else {
            XCTFail("Error creating analytics database")
            return
        }

        self.database = database
    }

    private func queueHit(_ hit: AnalyticsHit, isBackdateHit: Bool = false) {
        database.queue(payload: hit.payload, timestamp: hit.timestamp, eventIdentifier: hit.eventIdentifier, isBackdateHit: isBackdateHit)
    }

    private func getHitFromDataEntityArray(hits: [DataEntity]) -> [AnalyticsHit] {
        var ret: [AnalyticsHit] = []
        for hit in hits {
            if let data = hit.data, let analyticsHit = try? JSONDecoder().decode(AnalyticsHit.self, from: data) {
                ret.append(analyticsHit)
            }
        }
        return ret
    }

    private func getHitFromDataQueue(label: String) -> [AnalyticsHit] {
        if let queue = mockDataQueueService?.getDataQueue(label: label) {
            let hitCount = queue.count()
            if hitCount > 0, let hits = queue.peek(n: hitCount) {
                return getHitFromDataEntityArray(hits: hits)
            }
        }
        return [AnalyticsHit]()
    }

    private func getReorderHits() -> [AnalyticsHit] {
        return getHitFromDataQueue(label: AnalyticsTestConstants.REORDER_QUEUE_NAME)
    }

    private func getMainHits() -> [AnalyticsHit] {
        return getHitFromDataQueue(label: AnalyticsTestConstants.DATA_QUEUE_NAME)
    }

    private func getProcessedHits() -> [AnalyticsHit] {
        return getHitFromDataEntityArray(hits: mockProcessor.processedEntities)
    }

    private func assertHit(_ expected: AnalyticsHit, _ actual: AnalyticsHit) {
        XCTAssertEqual(expected.payload, actual.payload)
        XCTAssertEqual(expected.eventIdentifier, actual.eventIdentifier)
        XCTAssertEqual(expected.timestamp, actual.timestamp, accuracy: 0.0000001)
    }

    private func assertHits(_ expected: [AnalyticsHit], _ actual: [AnalyticsHit]) {
        XCTAssertEqual(expected.count, actual.count)
        for (hit1, hit2) in zip(expected, actual) {
            assertHit(hit1, hit2)
        }
    }

    func testKickWithAdditonalData_moveToMainQueue() {
        queueHit(hit1) // Mainqueue
        database.waitForAdditionalData(type: .lifecycle)
        queueHit(hit2) // ReorderQueue

        assertHits(getMainHits(), [hit1])
        assertHits(getReorderHits(), [hit2])

        database.kickWithAdditionalData(type: .lifecycle, data: nil)
        assertHits(getMainHits(), [hit1, hit2])
        assertHits(getReorderHits(), [])

    }

    func testKickWithAdditionalData_appendDataToFirstHit() {
        queueHit(hit1) // Mainqueue
        database.waitForAdditionalData(type: .lifecycle)
        database.waitForAdditionalData(type: .referrer)

        queueHit(hit2) // ReorderQueue as we are waiting for lifecycle and referrer

        assertHits(getMainHits(), [hit1])
        assertHits(getReorderHits(), [hit2])

        database.kickWithAdditionalData(type: .lifecycle, data: ["lk1": "v1", "lk2": "v2"])

        queueHit(hit3) // ReorderQueue as we are waiting for referrer

        assertHits(getMainHits(), [hit1])
        assertHits(getReorderHits(), [hit2, hit3])

        database.kickWithAdditionalData(type: .referrer, data: ["rk1": "v1", "rk2": "v2"])

        assertHits(getReorderHits(), [])
        let mainHits = getMainHits()
        XCTAssertEqual(mainHits.count, 3)

        assertHit(mainHits[0], hit1)

        // Second hit contains additional data
        let secondHit = mainHits[1]
        XCTAssertTrue(secondHit.payload.contains("lk1=v1"))
        XCTAssertTrue(secondHit.payload.contains("lk2=v2"))
        XCTAssertTrue(secondHit.payload.contains("rk1=v1"))
        XCTAssertTrue(secondHit.payload.contains("rk2=v2"))

        assertHit(mainHits[2], hit3)
    }

    func testQueue_appendToReorderQueueWhenWaiting() {
        database.waitForAdditionalData(type: .lifecycle)

        queueHit(hit1)
        queueHit(hit2)

        assertHits(getMainHits(), [])
        assertHits(getReorderHits(), [hit1, hit2])
    }

    func testQueue_appendToMainQueueWhenNotWaiting() {
        queueHit(hit1)
        queueHit(hit2)

        assertHits(getMainHits(), [hit1, hit2])
        assertHits(getReorderHits(), [])
    }

    func testQueue_kickBatchLimit() {
        mockProcessor.processResult = true

        analyticsState.offlineEnabled = true
        analyticsState.batchLimit = 2

        queueHit(hit1)
        queueHit(hit2)

        Thread.sleep(forTimeInterval: 0.5)
        assertHits(getProcessedHits(), [])

        queueHit(hit3)
        Thread.sleep(forTimeInterval: 0.5)
        assertHits(getProcessedHits(), [hit1, hit2, hit3])
    }

    func testQueue_kickOfflineTrackingDisabled() {
        mockProcessor.processResult = true

        analyticsState.offlineEnabled = false

        queueHit(hit1)

        Thread.sleep(forTimeInterval: 0.5)
        assertHits(getProcessedHits(), [hit1])
    }

    func testQueue_kickPrivacyNotOptIn() {
        mockProcessor.processResult = true

        analyticsState.privacyStatus = .unknown

        queueHit(hit1)

        Thread.sleep(forTimeInterval: 0.5)
        assertHits(getProcessedHits(), [])

        analyticsState.privacyStatus = .optedIn

        queueHit(hit2)

        Thread.sleep(forTimeInterval: 0.5)
        assertHits(getProcessedHits(), [hit1, hit2])
    }

    func testQueue_kickAnalyticsNotConfigured() {
        mockProcessor.processResult = true

        analyticsState.host = nil
        analyticsState.rsids = nil

        queueHit(hit1)

        Thread.sleep(forTimeInterval: 0.5)
        assertHits(getProcessedHits(), [])

        analyticsState.host = "test.com"
        analyticsState.rsids = "rsids"

        queueHit(hit2)

        Thread.sleep(forTimeInterval: 0.5)
        assertHits(getProcessedHits(), [hit1, hit2])
    }

    func testQueue_DropBackdatwHitWhenNotWaiting() {
        queueHit(hit1)
        // hit2 is dropped as database is not waiting and started processing regular hits.
        queueHit(hit2, isBackdateHit: true)
        assertHits(getMainHits(), [hit1])
    }

    func testQueue_AppendBackDateHitToMainQueueWhenWaiting() {
        queueHit(hit1)

        database.waitForAdditionalData(type: .lifecycle)

        // hit2 is appened to main queue.
        queueHit(hit2, isBackdateHit: true)
        assertHits(getMainHits(), [hit1, hit2])
    }

    func testReset() {
        queueHit(hit1)
        database.waitForAdditionalData(type: .lifecycle)
        queueHit(hit2)

        database.reset()

        assertHits(getMainHits(), [])
        assertHits(getReorderHits(), [])
    }

    func testQueueCount() {
        queueHit(hit1)
        database.waitForAdditionalData(type: .lifecycle)
        queueHit(hit2)

        XCTAssertEqual(database.getQueueSize(), 2)
    }

    func testForceKickHits() {
        mockProcessor.processResult = true

        analyticsState.offlineEnabled = true
        analyticsState.batchLimit = 10

        queueHit(hit1)
        queueHit(hit2)

        Thread.sleep(forTimeInterval: 0.5)
        assertHits(getProcessedHits(), [])

        database.kick(ignoreBatchLimit: true)
        Thread.sleep(forTimeInterval: 0.5)
        assertHits(getProcessedHits(), [hit1, hit2])
    }
}
