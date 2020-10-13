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

class AnalyticsAPITests: XCTestCase {
    override func setUp() {
        EventHub.reset()
        MockExtension.reset()
    }

    private func registerMockExtension<T: Extension>(_ type: T.Type) {
        let semaphore = DispatchSemaphore(value: 0)
        EventHub.shared.registerExtension(type) { error in
            XCTAssertNil(error)
            semaphore.signal()
        }

        semaphore.wait()
    }


    func testClearQueue() {
        // setup
        let expectation = XCTestExpectation(description: "clearQueue should dispatch an event")
        expectation.assertForOverFulfill = true

        registerMockExtension(MockExtension.self)
        EventHub.shared.start()


        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.analytics, source: EventSource.requestContent) { (event) in
            XCTAssertTrue(event.data?[AnalyticsConstants.EventDataKeys.CLEAR_HITS_QUEUE] as! Bool)
            expectation.fulfill()
        }

        // test
        Analytics.clearQueue()

        // verify
        wait(for: [expectation], timeout: 1.0)
    }

    func testGetQueueSize() {
        // setup
        let expectation = XCTestExpectation(description: "getQueueSize should dispatch an event")
        expectation.assertForOverFulfill = true

        registerMockExtension(MockExtension.self)
        EventHub.shared.start()


        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.analytics, source: EventSource.requestContent) { (event) in
            XCTAssertTrue(event.data?[AnalyticsConstants.EventDataKeys.GET_QUEUE_SIZE] as! Bool)
            expectation.fulfill()
        }

        // test
        Analytics.getQueueSize(){ (queueSize, error) in }

        // verify
        wait(for: [expectation], timeout: 1.0)
    }

    func testSendQueuedHits() {
        // setup
        let expectation = XCTestExpectation(description: "sendQueuedHits should dispatch an event")
        expectation.assertForOverFulfill = true

        registerMockExtension(MockExtension.self)
        EventHub.shared.start()


        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.analytics, source: EventSource.requestContent) { (event) in
            XCTAssertTrue(event.data?[AnalyticsConstants.EventDataKeys.FORCE_KICK_HITS] as! Bool)
            expectation.fulfill()
        }

        // test
        Analytics.sendQueuedHits()

        // verify
        wait(for: [expectation], timeout: 1.0)
    }

    func testGetTrackingIdentifier() {
        // setup
        let expectation = XCTestExpectation(description: "getTrackingIdentifier should dispatch an event")
        expectation.assertForOverFulfill = true

        registerMockExtension(MockExtension.self)
        EventHub.shared.start()


        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.analytics, source: EventSource.requestIdentity) { (event) in
            expectation.fulfill()
        }

        // test
        Analytics.getTrackingIdentifier(){(identifier, error) in }

        // verify
        wait(for: [expectation], timeout: 1.0)
    }

    func testGetVisitorIdentifier() {
        // setup
        let expectation = XCTestExpectation(description: "getVisitoridentifier should dispatch an event")
        expectation.assertForOverFulfill = true

        registerMockExtension(MockExtension.self)
        EventHub.shared.start()


        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.analytics, source: EventSource.requestIdentity) { (event) in
            expectation.fulfill()
        }

        // test
        Analytics.getVisitorIdentifier(){(identifier, error) in }

        // verify
        wait(for: [expectation], timeout: 1.0)
    }

    func testSetVisitorIdentifier() {
        // setup
        let expectation = XCTestExpectation(description: "setVisitoridentifier should dispatch an event")
        expectation.assertForOverFulfill = true

        registerMockExtension(MockExtension.self)
        EventHub.shared.start()


        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.analytics, source: EventSource.requestIdentity) { (event) in
            XCTAssertEqual(event.data?[AnalyticsConstants.EventDataKeys.VISITOR_IDENTIFIER] as! String, "vid")
            expectation.fulfill()
        }

        // test
        Analytics.setVisitorIdentifier(visitorIdentifier: "vi")

        // verify
        wait(for: [expectation], timeout: 1.0)
    }
}
