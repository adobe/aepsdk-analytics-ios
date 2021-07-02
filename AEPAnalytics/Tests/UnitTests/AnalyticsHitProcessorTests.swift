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

@testable import AEPCore
@testable import AEPAnalytics
@testable import AEPServices
import XCTest

class AnalyticsHitProcessorTests: XCTestCase {
    var hitProcessor: AnalyticsHitProcessor!
    var analyticsState: AnalyticsState!
    var responseCallbackArgs = [[String: Any]]()
    var mockNetworkService: MockNetworking? {
        return ServiceProvider.shared.networkService as? MockNetworking
    }

    override func setUp() {
        ServiceProvider.shared.networkService = MockNetworking()

        responseCallbackArgs = [[String: Any]]()

        // Setup dummy values
        analyticsState = AnalyticsState()
        analyticsState.rsids = "rsid"
        analyticsState.host = "test.com"

        let dispatchQueue = DispatchQueue(label: "dispatchqueue")
        hitProcessor = AnalyticsHitProcessor(dispatchQueue: dispatchQueue, state: analyticsState, responseHandler: { [weak self] data in
            self?.responseCallbackArgs.append(data)
        })
    }

    /// Tests that when a `DataEntity` with bad data is passed, that it is not retried and is removed from the queue
    func testProcessHitFailedBadHit() {
        // setup
        let expectation = XCTestExpectation(description: "Callback should be invoked with true signaling this hit should not be retried")
        let entity = DataEntity(uniqueIdentifier: "test-uuid", timestamp: Date(), data: nil) // entity data does not contain an `AnalyticsHit`

        // test
        hitProcessor.processHit(entity: entity) { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 0.5)
        XCTAssertTrue(responseCallbackArgs.isEmpty) // response handler should not have been invoked
        XCTAssertFalse(mockNetworkService?.connectAsyncCalled ?? true) // no network request should have been made
    }

    func testProcessHit_NetworkFailureRecoverableError() {
        // setup
        let expectation = XCTestExpectation(description: "Callback should be invoked with true signaling this hit should not be retried")
        let expectedUrl = URL.getAnalyticsBaseUrl(state: analyticsState)
        mockNetworkService?.expectedResponse = HttpConnection(data: nil, response: HTTPURLResponse(url: expectedUrl!, statusCode: 408, httpVersion: nil, headerFields: nil), error: nil)

        let hit = AnalyticsHit(payload: "payload", timestamp: Date().timeIntervalSince1970, eventIdentifier: UUID().uuidString)

        let entity = DataEntity(uniqueIdentifier: "test-uuid", timestamp: Date(), data: try! JSONEncoder().encode(hit))

        // test
        hitProcessor.processHit(entity: entity) { success in
            XCTAssertFalse(success)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 0.5)

        XCTAssertTrue(mockNetworkService?.connectAsyncCalled ?? false) // network request should have been made
    }

    func testProcessHit_NetworkFailure() {
        // setup
        let expectation = XCTestExpectation(description: "Callback should be invoked with true signaling this hit should not be retried")
        let expectedUrl = URL.getAnalyticsBaseUrl(state: analyticsState)
        mockNetworkService?.expectedResponse = HttpConnection(data: nil, response: HTTPURLResponse(url: expectedUrl!, statusCode: 404, httpVersion: nil, headerFields: nil), error: nil)

        let hit = AnalyticsHit(payload: "payload", timestamp: Date().timeIntervalSince1970, eventIdentifier: UUID().uuidString)

        let entity = DataEntity(uniqueIdentifier: "test-uuid", timestamp: Date(), data: try! JSONEncoder().encode(hit))

        // test
        hitProcessor.processHit(entity: entity) { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 0.5)

        XCTAssertTrue(mockNetworkService?.connectAsyncCalled ?? false) // network request should have been made
    }

    // Tests that when a good hit is processed that a network request is made and the request returns 200
    func testProcessHitSuccessfulResponseEventData() {
        // setup
        let expectation = XCTestExpectation(description: "Callback should be invoked with true signaling this hit should not be retried")
        let expectedUrl = URL.getAnalyticsBaseUrl(state: analyticsState)
        mockNetworkService?.expectedResponse = HttpConnection(data: nil, response: HTTPURLResponse(url: expectedUrl!, statusCode: 200, httpVersion: nil, headerFields: nil), error: nil)

        let hit = AnalyticsHit(payload: "payload", timestamp: Date().timeIntervalSince1970, eventIdentifier: UUID().uuidString)

        let entity = DataEntity(uniqueIdentifier: "test-uuid", timestamp: Date(), data: try! JSONEncoder().encode(hit))

        // test
        hitProcessor.processHit(entity: entity) { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 1)

        XCTAssertFalse(responseCallbackArgs.isEmpty) // response handler should have been invoked
        XCTAssertTrue(mockNetworkService?.connectAsyncCalled ?? false) // network request should have been made

        let actualUrlString = mockNetworkService?.connectAsyncCalledWithNetworkRequest?.url.absoluteString ?? ""
        let expectedUrlString = expectedUrl?.absoluteString ?? ""
        XCTAssertTrue(actualUrlString.hasPrefix(expectedUrlString))
    }

    // Tests that when a good hit is processed that a network request is made and the request returns 200
    func testProcessHitOfflineEnabledOutOfOrder() {
        // setup
        let expectation = XCTestExpectation(description: "Callback should be invoked with true signaling this hit should not be retried")
        let expectedUrl = URL.getAnalyticsBaseUrl(state: analyticsState)
        mockNetworkService?.expectedResponse = HttpConnection(data: nil, response: HTTPURLResponse(url: expectedUrl!, statusCode: 200, httpVersion: nil, headerFields: nil), error: nil)

        let lastHitTimestamp = Date(timeIntervalSinceNow: 10).timeIntervalSince1970
        let hitTimestamp = Date().timeIntervalSince1970
        let payload = "payload&ts=\(Int64(hitTimestamp))"

        // Enable offline tracking
        analyticsState.offlineEnabled = true

        hitProcessor.lastHitTimestamp = lastHitTimestamp

        // For offline enabled :- if hitTimestamp is less than lastHitTimestamp, hitTimestamp is corrected to lastHitTimestamp + 1
        let expectedHitTimestamp = lastHitTimestamp + 1

        let hit = AnalyticsHit(payload: payload, timestamp: hitTimestamp, eventIdentifier: UUID().uuidString)
        let entity = DataEntity(uniqueIdentifier: "test-uuid", timestamp: Date(), data: try! JSONEncoder().encode(hit))

        // test
        hitProcessor.processHit(entity: entity) { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 0.5)

        XCTAssertEqual(mockNetworkService?.connectAsyncCalledWithNetworkRequest?.payloadAsString(), "payload&ts=\(Int64(expectedHitTimestamp))")
        XCTAssertEqual(hitProcessor.lastHitTimestamp, expectedHitTimestamp)
    }

    func testProcessHitOfflineDisabledTimestampExceeded() {
        // setup
        let expectation = XCTestExpectation(description: "Callback should be invoked with true signaling this hit should not be retried")

        // If offline disabled, the hit should be dropped if it was queued before threshold.
        let timeStamp = Date(timeIntervalSinceNow: -(AnalyticsTestConstants.Default.TIMESTAMP_DISABLED_WAIT_THRESHOLD_SECONDS + 1))

        let hit = AnalyticsHit(payload: "", timestamp: timeStamp.timeIntervalSince1970, eventIdentifier: UUID().uuidString)
        let entity = DataEntity(uniqueIdentifier: "test-uuid", timestamp: Date(), data: try! JSONEncoder().encode(hit))

        // test
        hitProcessor.processHit(entity: entity) { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 0.5)
        XCTAssertTrue(responseCallbackArgs.isEmpty)
        XCTAssertFalse(mockNetworkService?.connectAsyncCalled ?? true)
    }

    func testProcessHit_AssuranceActive() {
        // setup
        let expectation = XCTestExpectation(description: "Callback should be invoked with true signaling this hit should not be retried")
        let expectedUrl = URL.getAnalyticsBaseUrl(state: analyticsState)
        mockNetworkService?.expectedResponse = HttpConnection(data: nil, response: HTTPURLResponse(url: expectedUrl!, statusCode: 200, httpVersion: nil, headerFields: nil), error: nil)

        let hit = AnalyticsHit(payload: "payload", timestamp: Date().timeIntervalSince1970, eventIdentifier: UUID().uuidString)
        let entity = DataEntity(uniqueIdentifier: "test-uuid", timestamp: Date(), data: try! JSONEncoder().encode(hit))

        // Enable assurance
        analyticsState.assuranceSessionActive = true

        // test
        hitProcessor.processHit(entity: entity) { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 0.5)

        XCTAssertFalse(responseCallbackArgs.isEmpty) // response handler should have been invoked
        XCTAssertTrue(mockNetworkService?.connectAsyncCalled ?? false) // network request should have been made

        let actualUrlString = mockNetworkService?.connectAsyncCalledWithNetworkRequest?.url.absoluteString ?? ""
        let expectedUrlString = expectedUrl?.absoluteString ?? ""
        XCTAssertTrue(actualUrlString.hasPrefix(expectedUrlString))
        XCTAssertEqual(mockNetworkService?.connectAsyncCalledWithNetworkRequest?.payloadAsString(), "payload\(AnalyticsTestConstants.Request.DEBUG_API_PAYLOAD)")
    }
}
