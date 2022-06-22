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

@available(tvOSApplicationExtension, unavailable)
class AnalyticsAPITests: XCTestCase {
    override func setUp() {
        EventHub.reset()
        MockExtension.reset()

        registerMockExtension(MockExtension.self)
        EventHub.shared.start()
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

        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.analytics, source: EventSource.requestContent) { (event) in
            XCTAssertTrue(event.data?[AnalyticsConstants.EventDataKeys.CLEAR_HITS_QUEUE] as! Bool)
            expectation.fulfill()
        }

        // test
        Analytics.clearQueue()

        // verify
        wait(for: [expectation], timeout: 1.0)
    }

    func testSendQueuedHits() {
        // setup
        let expectation = XCTestExpectation(description: "sendQueuedHits should dispatch an event")
        expectation.assertForOverFulfill = true

        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.analytics, source: EventSource.requestContent) { (event) in
            XCTAssertTrue(event.data?[AnalyticsConstants.EventDataKeys.FORCE_KICK_HITS] as! Bool)
            expectation.fulfill()
        }

        // test
        Analytics.sendQueuedHits()

        // verify
        wait(for: [expectation], timeout: 1.0)
    }

    func testGetQueueSize() {
        // setup
        let expectation = XCTestExpectation(description: "getQueueSize should dispatch an event")
        expectation.assertForOverFulfill = true

        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.analytics, source: EventSource.requestContent) { (event) in
            XCTAssertTrue(event.data?[AnalyticsConstants.EventDataKeys.GET_QUEUE_SIZE] as! Bool)
            expectation.fulfill()
        }

        // test
        Analytics.getQueueSize(){ (queueSize, error) in }

        // verify
        wait(for: [expectation], timeout: 1.0)
    }

    func testGetQueueSize_CorrectResponse() {
        // setup
        let expectation = XCTestExpectation(description: "getQueueSize should return correct value")
        expectation.assertForOverFulfill = true

        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.analytics, source: EventSource.requestContent) { (event) in
            let responseData = [
                AnalyticsTestConstants.EventDataKeys.QUEUE_SIZE: 10
            ]
            let responseEvent = event.createResponseEvent(name: "ResponseEvent", type: EventType.analytics, source: EventSource.responseContent, data: responseData)
            EventHub.shared.dispatch(event: responseEvent)
        }

        // test
        Analytics.getQueueSize(){ (queueSize, error) in
            XCTAssertEqual(queueSize, 10)
            XCTAssertNil(error)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 1.0)
    }

    func testGetQueueSize_IncorrectResponse() {
        // setup
        let expectation = XCTestExpectation(description: "getQueueSize should return error with invalid response")
        expectation.assertForOverFulfill = true

        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.analytics, source: EventSource.requestContent) { (event) in
            let responseEvent = event.createResponseEvent(name: "ResponseEvent", type: EventType.analytics, source: EventSource.responseContent, data: nil)
            EventHub.shared.dispatch(event: responseEvent)
        }

        // test
        Analytics.getQueueSize(){ (queueSize, error) in
            XCTAssertEqual(queueSize, 0)
            XCTAssertEqual(error as? AEPError, .unexpected)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 1.0)
    }

    func testGetQueueSize_Timeout() {
        // setup
        let expectation = XCTestExpectation(description: "getQueueSize should timeout without response")
        expectation.assertForOverFulfill = true

        // test
        Analytics.getQueueSize(){ (queueSize, error) in
            XCTAssertEqual(queueSize, 0)
            XCTAssertEqual(error as? AEPError, .callbackTimeout)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 1.5)
    }

    func testGetTrackingIdentifier() {
        // setup
        let expectation = XCTestExpectation(description: "getTrackingIdentifier should dispatch an event")
        expectation.assertForOverFulfill = true

        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.analytics, source: EventSource.requestIdentity) { (event) in
            expectation.fulfill()
        }

        // test
        Analytics.getTrackingIdentifier(){(identifier, error) in }

        // verify
        wait(for: [expectation], timeout: 1.0)
    }

    func testGetTrackingIdentifier_CorrectResponse() {
        // setup
        let expectation = XCTestExpectation(description: "getTrackingIdentifier should return correct response")
        expectation.assertForOverFulfill = true

        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.analytics, source: EventSource.requestIdentity) { (event) in
            let responseData = [
                AnalyticsTestConstants.EventDataKeys.ANALYTICS_ID: "aidvalue"
            ]
            let responseEvent = event.createResponseEvent(name: "ResponseEvent", type: EventType.analytics, source: EventSource.responseContent, data: responseData)
            EventHub.shared.dispatch(event: responseEvent)
        }


        // test
        Analytics.getTrackingIdentifier(){(identifier, error) in
            XCTAssertEqual(identifier, "aidvalue")
            XCTAssertNil(error)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 1.0)
    }

    func testGetTrackingIdentifier_MissingIdentifierInResponse() {
        // setup
        let expectation = XCTestExpectation(description: "getTrackingIdentifier should return error with invalid response")
        expectation.assertForOverFulfill = true

        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.analytics, source: EventSource.requestIdentity) { (event) in
            let responseEvent = event.createResponseEvent(name: "ResponseEvent", type: EventType.analytics, source: EventSource.responseContent, data: nil)
            EventHub.shared.dispatch(event: responseEvent)
        }

        // test
        Analytics.getTrackingIdentifier(){(identifier, error) in
            XCTAssertNil(identifier)
            XCTAssertNil(error)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 1.0)
    }

    func testGetTrackingIdentifier_IncorrectResponse() {
        // setup
        let expectation = XCTestExpectation(description: "getTrackingIdentifier should return error with invalid response")
        expectation.assertForOverFulfill = true

        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.analytics, source: EventSource.requestIdentity) { (event) in
            let responseData = [
                AnalyticsTestConstants.EventDataKeys.ANALYTICS_ID: 12345
            ]
            let responseEvent = event.createResponseEvent(name: "ResponseEvent", type: EventType.analytics, source: EventSource.responseContent, data: responseData)
            EventHub.shared.dispatch(event: responseEvent)
        }

        // test
        Analytics.getTrackingIdentifier(){(identifier, error) in
            XCTAssertNil(identifier)
            XCTAssertEqual(error as? AEPError, .unexpected)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 1.0)
    }

    func testGetTrackingIdentifier_Timeout() {
        // setup
        let expectation = XCTestExpectation(description: "getTrackingIdentifier should timeout without response")
        expectation.assertForOverFulfill = true

        // test
        Analytics.getTrackingIdentifier(){(identifier, error) in
            XCTAssertNil(identifier)
            XCTAssertEqual(error as? AEPError, .callbackTimeout)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 1.5)
    }

    func testSetVisitorIdentifier() {
        // setup
        let expectation = XCTestExpectation(description: "setVisitoridentifier should dispatch an event")
        expectation.assertForOverFulfill = true

        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.analytics, source: EventSource.requestIdentity) { (event) in
            XCTAssertEqual(event.data?[AnalyticsConstants.EventDataKeys.VISITOR_IDENTIFIER] as! String, "vid")
            expectation.fulfill()
        }

        // test
        Analytics.setVisitorIdentifier(visitorIdentifier: "vid")

        // verify
        wait(for: [expectation], timeout: 1.0)
    }

    func testGetVisitorIdentifier() {
        // setup
        let expectation = XCTestExpectation(description: "getVisitoridentifier should dispatch an event")
        expectation.assertForOverFulfill = true

        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.analytics, source: EventSource.requestIdentity) { (event) in
            expectation.fulfill()
        }

        // test
        Analytics.getVisitorIdentifier(){(identifier, error) in }

        // verify
        wait(for: [expectation], timeout: 1.0)
    }

    func testGetVisitorIdentifier_CorrectResponse() {
        // setup
        let expectation = XCTestExpectation(description: "getVisitoridentifier should return correct response")
        expectation.assertForOverFulfill = true

        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.analytics, source: EventSource.requestIdentity) { (event) in
            let responseData = [
                AnalyticsTestConstants.EventDataKeys.VISITOR_IDENTIFIER: "vidvalue"
            ]
            let responseEvent = event.createResponseEvent(name: "ResponseEvent", type: EventType.analytics, source: EventSource.responseContent, data: responseData)
            EventHub.shared.dispatch(event: responseEvent)
        }

        // test
        Analytics.getVisitorIdentifier(){(identifier, error) in
            XCTAssertEqual(identifier, "vidvalue")
            XCTAssertNil(error)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 1.0)
    }

    func testGetVisitorIdentifier_MissingIdentifierInResponse() {
        // setup
        let expectation = XCTestExpectation(description: "getVisitoridentifier should return error with invalid response")
        expectation.assertForOverFulfill = true

        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.analytics, source: EventSource.requestIdentity) { (event) in
            let responseEvent = event.createResponseEvent(name: "ResponseEvent", type: EventType.analytics, source: EventSource.responseContent, data: nil)
            EventHub.shared.dispatch(event: responseEvent)
        }

        // test
        Analytics.getVisitorIdentifier(){(identifier, error) in
            XCTAssertNil(identifier)
            XCTAssertNil(error)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 1.0)
    }

    func testGetVisitorIdentifier_IncorrectResponse() {
        // setup
        let expectation = XCTestExpectation(description: "getVisitoridentifier should return error with invalid response")
        expectation.assertForOverFulfill = true

        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.analytics, source: EventSource.requestIdentity) { (event) in
            let responseData = [
                AnalyticsTestConstants.EventDataKeys.VISITOR_IDENTIFIER: 12345
            ]
            let responseEvent = event.createResponseEvent(name: "ResponseEvent", type: EventType.analytics, source: EventSource.responseContent, data: responseData)
            EventHub.shared.dispatch(event: responseEvent)
        }

        // test
        Analytics.getVisitorIdentifier(){(identifier, error) in
            XCTAssertNil(identifier)
            XCTAssertEqual(error as? AEPError, .unexpected)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 1.0)
    }


    func testGetVisitorIdentifier_Timeout() {
        // setup
        let expectation = XCTestExpectation(description: "getVisitoridentifier should timeout without response")
        expectation.assertForOverFulfill = true

        // test
        Analytics.getVisitorIdentifier(){(identifier, error) in
            XCTAssertNil(identifier)
            XCTAssertEqual(error as? AEPError, .callbackTimeout)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 1.5)
    }



}
