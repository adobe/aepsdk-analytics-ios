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
@testable import AEPCore
@testable import AEPServices
import AEPAnalytics
import AEPIdentity

class AnalyticsFunctionalTests: XCTestCase {

    static let EXPERIENCE_CLOUD_ORGID = "experienceCloud.org"
    static let GLOBAL_CONFIG_PRIVACY = "global.privacy"
    static let ANALYTICS_SERVER = "analytics.server"
    static let ANALYTICS_REPORT_SUITES = "analytics.rsids"

    static let AAM_FORWARDING_ENABLED = "analytics.aamForwardingEnabled";
    static let BATCH_LIMIT = "analytics.batchLimit";
    static let OFFLINE_ENABLED = "analytics.offlineEnabled";
    static let LAUNCH_HIT_DELAY = "analytics.launchHitDelay";
    static let BACKDATE_SESSION_INFO = "analytics.backdatePreviousSessionInfo";

    static let IDENTITY_ORG_ID = "972C898555E9F7BC7F000101@AdobeOrg"
    static let LIFECYCLE_SESSION_TIMEOUT = 10

    override func setUp() {
        UserDefaults.clear()
        FileManager.default.clearCache()
        ServiceProvider.shared.reset()
        EventHub.reset()
    }

    override func tearDown() {
        let unregisterExpectation = XCTestExpectation(description: "unregister extensions")
        unregisterExpectation.expectedFulfillmentCount = 1
        MobileCore.unregisterExtension(Analytics.self) {
            unregisterExpectation.fulfill()
        }

        wait(for: [unregisterExpectation], timeout: 2)
    }

    func initExtensionsAndWait() {
        let initExpectation = XCTestExpectation(description: "init extensions")
        MobileCore.setLogLevel(.trace)
        MobileCore.registerExtensions([Analytics.self, Identity.self]) {
            initExpectation.fulfill()
        }
        wait(for: [initExpectation], timeout: 1)
    }

    func setupConfiguration(){
        MobileCore.updateConfigurationWith(configDict: [AnalyticsFunctionalTests.GLOBAL_CONFIG_PRIVACY: "optedin", AnalyticsFunctionalTests.BACKDATE_SESSION_INFO: false, AnalyticsFunctionalTests.OFFLINE_ENABLED: true, AnalyticsFunctionalTests.EXPERIENCE_CLOUD_ORGID: "testOrg@AdobeOrg", "experienceCloud.server": "identityTestServer.com", AnalyticsFunctionalTests.ANALYTICS_SERVER: "testserver.com",  AnalyticsFunctionalTests.ANALYTICS_REPORT_SUITES: "rsid1", AnalyticsFunctionalTests.AAM_FORWARDING_ENABLED: false,
                                                        AnalyticsFunctionalTests.BATCH_LIMIT: 0, AnalyticsFunctionalTests.IDENTITY_ORG_ID: "972C898555E9F7BC7F000101@AdobeOrg"])
//        MobileCore.updateConfigurationWith(configDict: [AnalyticsFunctionalTests.GLOBAL_CONFIG_PRIVACY: privacyStatus, AnalyticsFunctionalTests.IDENTITIY_ADID_ENABLED: true, AnalyticsFunctionalTests.IDENTITY_ORG_ID: "972C898555E9F7BC7F000101@AdobeOrg", AnalyticsFunctionalTests.IDENTITY_SERVER: "identity.com"])
        sleep(1)
    }

    func setupAnalyticsConfiguration(privacyStatus: String, aamForwardingEnabled: Bool, batchLimit: Int, offlineEnabled: Bool, server: String ,rsid: String , launchHitDelay: Int ) {
        MobileCore.updateConfigurationWith(configDict: [AnalyticsFunctionalTests.GLOBAL_CONFIG_PRIVACY: privacyStatus, AnalyticsFunctionalTests.AAM_FORWARDING_ENABLED: aamForwardingEnabled, AnalyticsFunctionalTests.BATCH_LIMIT: batchLimit, AnalyticsFunctionalTests.OFFLINE_ENABLED: offlineEnabled, AnalyticsFunctionalTests.ANALYTICS_SERVER: server, AnalyticsFunctionalTests.ANALYTICS_REPORT_SUITES: rsid, AnalyticsFunctionalTests.LAUNCH_HIT_DELAY: launchHitDelay, AnalyticsFunctionalTests.EXPERIENCE_CLOUD_ORGID: "testOrg@AdobeOrg", "experienceCloud.server": "identityTestServer.com",])
        sleep(1)
    }

    func setDefaultResponse(responseData: Data?, expectedUrlFragment: String, statusCode: Int, mockNetworkService: TestableNetworkService) {
        let response = HTTPURLResponse(url: URL(string: expectedUrlFragment)!, statusCode: statusCode, httpVersion: nil, headerFields: [:])
        mockNetworkService.mock { request in
            return (data: responseData, response: response, error: nil)
        }
    }

    func ignore_testAnalytics_Track_Happy() {
        // setup
        initExtensionsAndWait()
        setupAnalyticsConfiguration(privacyStatus: "optedin", aamForwardingEnabled: false, batchLimit: 0, offlineEnabled: true, server: "testserver.com", rsid: "rsid1", launchHitDelay: 0)
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService

        setDefaultResponse(responseData: nil, expectedUrlFragment: "https://testserver.com", statusCode: 200, mockNetworkService: mockNetworkService)

        // test
        MobileCore.track(action: "requestAction", data: ["mykey" : "myvalue" ])
        sleep(2)

        //verify network request
        XCTAssertEqual(1, mockNetworkService.requests.count)
        let requestUrl = mockNetworkService.getRequest(at: 0)?.url.absoluteString ?? ""
        let requestpayload = mockNetworkService.getRequest(at: 0)?.connectPayload ?? ""
        XCTAssertTrue(requestUrl.contains("https://testserver.com/b/ss/rsid1/0"))
        XCTAssertTrue(requestpayload.contains("ndh=1"))
        XCTAssertTrue(requestpayload.contains("mykey=myvalue"))
        XCTAssertTrue(requestpayload.contains("pev2=AMACTION:requestAction"))
        XCTAssertTrue(requestpayload.contains("a.&action=requestAction"))
    }

    func ignore_testAnalytics_Track_OptOut() {
        // setup
        initExtensionsAndWait()
        setupAnalyticsConfiguration(privacyStatus: "optedout", aamForwardingEnabled: false, batchLimit: 0, offlineEnabled: true, server: "testserver.com", rsid: "rsid1", launchHitDelay: 0)
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService

        setDefaultResponse(responseData: nil, expectedUrlFragment: "https://testserver.com", statusCode: 200, mockNetworkService: mockNetworkService)

        // test
        MobileCore.track(action: "requestAction", data: ["mykey" : "myvalue" ])
        sleep(2)

        //verify network request
        XCTAssertEqual(0, mockNetworkService.requests.count)
    }

    func ignore_testAnalytics_Track_Unknown_then_Optin() {
        // setup
        initExtensionsAndWait()
        setupAnalyticsConfiguration(privacyStatus: "unknown", aamForwardingEnabled: false, batchLimit: 0, offlineEnabled: true, server: "testserver.com", rsid: "rsid1", launchHitDelay: 0)
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService

        setDefaultResponse(responseData: nil, expectedUrlFragment: "https://testserver.com", statusCode: 200, mockNetworkService: mockNetworkService)

        // test
        MobileCore.track(state: "requestState", data: ["mystate" : "myvalue" ])
        sleep(2)

        // verify no network request is sent
        XCTAssertEqual(0, mockNetworkService.requests.count)

        setupAnalyticsConfiguration(privacyStatus: "optedin", aamForwardingEnabled: false, batchLimit: 0, offlineEnabled: true, server: "testserver.com", rsid: "rsid1", launchHitDelay: 0)
        Analytics.sendQueuedHits()

        // verify 2 network request (analytics and identity) sent
        XCTAssertEqual(2, mockNetworkService.requests.count)
    }

    func ignore_testAnalytics_sendQueueHits_happy() {
        // setup
        initExtensionsAndWait()
        setupAnalyticsConfiguration(privacyStatus: "optedin", aamForwardingEnabled: false, batchLimit: 0, offlineEnabled: true, server: "testserver.com", rsid: "rsid1", launchHitDelay: 0)

        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService

        setDefaultResponse(responseData: nil, expectedUrlFragment: "https://testserver.com", statusCode: 200, mockNetworkService: mockNetworkService)

        var retrievedQueueSize = 0;
        Analytics.clearQueue()


        // test
        MobileCore.track(action: "requestAction", data: ["mykey" : "myvalue" ])
        MobileCore.track(action: "requestAction", data: ["mykey" : "myvalue" ])
        MobileCore.track(action: "requestAction", data: ["mykey" : "myvalue" ])

        Analytics.getQueueSize(){ (queueSize, error) in
            retrievedQueueSize = queueSize
        }
        sleep(2)

        // verify queue size
        XCTAssertEqual(3, retrievedQueueSize)
        Analytics.sendQueuedHits()

        // verify network request
        XCTAssertEqual(3, mockNetworkService.requests.count)
    }

    func ingore_testAnalytics_sendBatchLimit() {
        // setup
        initExtensionsAndWait()
        setupAnalyticsConfiguration(privacyStatus: "optedin", aamForwardingEnabled: false, batchLimit: 2, offlineEnabled: true, server: "testserver.com", rsid: "rsid1", launchHitDelay: 0)

        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService

        setDefaultResponse(responseData: nil, expectedUrlFragment: "https://testserver.com", statusCode: 200, mockNetworkService: mockNetworkService)

        Analytics.clearQueue()

        // test
        MobileCore.track(action: "requestAction1", data: ["mykey1" : "myvalue1" ])
        MobileCore.track(action: "requestAction2", data: ["mykey2" : "myvalue2" ])
        sleep(2)

        // verify no network request has been sent since batch limit has not yet exceeded
        XCTAssertEqual(0, mockNetworkService.requests.count)

        // add more more track
        MobileCore.track(action: "requestAction3", data: ["mykey3" : "myvalue3" ])
        sleep(1)

        // verify all network request sent
        XCTAssertEqual(3, mockNetworkService.requests.count)
    }

    func ignore_testClearQueueSize() {
        let semaphore = DispatchSemaphore(value: 0)
        initExtensionsAndWait()
        setupAnalyticsConfiguration(privacyStatus: "optedin", aamForwardingEnabled: false, batchLimit: 4, offlineEnabled: true, server: "testserver.com", rsid: "rsid1", launchHitDelay: 0)

        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService

        setDefaultResponse(responseData: nil, expectedUrlFragment: "https://testserver.com", statusCode: 200, mockNetworkService: mockNetworkService)

        var retrievedQueueSize = 0;

        // test
        MobileCore.track(action: "requestAction1", data: ["mykey1" : "myvalue1" ])
        MobileCore.track(action: "requestAction2", data: ["mykey2" : "myvalue2" ])
        MobileCore.track(action: "requestAction3", data: ["mykey2" : "myvalue3" ])

        Analytics.getQueueSize(){ (queueSize, error) in
            retrievedQueueSize = queueSize
            semaphore.signal()
        }

        semaphore.wait()
        // verify queue size is 3
        XCTAssertEqual(3, retrievedQueueSize)

        Analytics.sendQueuedHits()
        Analytics.clearQueue()

        // verify no network request has been sent after clear queue
        XCTAssertEqual(0, mockNetworkService.requests.count)
    }


    func ignore_testGetQueueSize_checkDefaultQueueSize() {
        let semaphore = DispatchSemaphore(value: 0)
        initExtensionsAndWait()
        setupAnalyticsConfiguration(privacyStatus: "optedin", aamForwardingEnabled: false, batchLimit: 4, offlineEnabled: true, server: "testserver.com", rsid: "rsid1", launchHitDelay: 0)

        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService

        setDefaultResponse(responseData: nil, expectedUrlFragment: "https://testserver.com", statusCode: 200, mockNetworkService: mockNetworkService)

        var retrievedQueueSize = 0;

        // test
        Analytics.getQueueSize(){ (queueSize, error) in
            retrievedQueueSize = queueSize
            semaphore.signal()
        }

        semaphore.wait()
        // verify default queue size is 0
        XCTAssertEqual(0, retrievedQueueSize)

        Analytics.sendQueuedHits()
        Analytics.clearQueue()

        // verify no network request has been sent after clear queue
        XCTAssertEqual(0, mockNetworkService.requests.count)

    }

    func ignore_testTrackStateWithNoContextData_pingGoOut() {
        // setup
        initExtensionsAndWait()
        setupAnalyticsConfiguration(privacyStatus: "optedin", aamForwardingEnabled: false, batchLimit: 0, offlineEnabled: true, server: "testserver.com", rsid: "rsid1", launchHitDelay: 0)
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService

        setDefaultResponse(responseData: nil, expectedUrlFragment: "https://testserver.com", statusCode: 200, mockNetworkService: mockNetworkService)

        // test
        MobileCore.track(state: "requestState", data: nil)
        sleep(2)

        //verify network request still goes out with no context data
        XCTAssertEqual(1, mockNetworkService.requests.count)
        let requestUrl = mockNetworkService.getRequest(at: 0)?.url.absoluteString ?? ""
        let requestpayload = mockNetworkService.getRequest(at: 0)?.connectPayload ?? ""
        XCTAssertTrue(requestUrl.contains("https://testserver.com/b/ss/rsid1/0"))
        XCTAssertTrue(requestpayload.contains("ndh=1"))
        XCTAssertTrue(requestpayload.contains("pageName=requestState"))
    }

    func ignore_testNoAnalyticsServer() {
        // setup
        initExtensionsAndWait()
        setupAnalyticsConfiguration(privacyStatus: "optedin", aamForwardingEnabled: false, batchLimit: 0, offlineEnabled: true, server: "", rsid: "rsid1", launchHitDelay: 0)
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService

        setDefaultResponse(responseData: nil, expectedUrlFragment: "https://testserver.com", statusCode: 200, mockNetworkService: mockNetworkService)

        // test
        MobileCore.track(state: "requestState", data: nil)
        sleep(2)

        // verify no network request is sent
        XCTAssertEqual(0, mockNetworkService.requests.count)
    }

    func ignore_testSetVisitorIDWorks() {
        //setup
        let semaphore = DispatchSemaphore(value: 0)
        initExtensionsAndWait()
        setupConfiguration()

        let expectedvid = "test-vid"
        Analytics.setVisitorIdentifier(visitorIdentifier: expectedvid)
        sleep(2)

        var actualVid = ""

        // test
        Analytics.getVisitorIdentifier(){(vid, error) in
            actualVid = vid ?? ""
            semaphore.signal()
        }
        
        // verify
        semaphore.wait()
        XCTAssertEqual(expectedvid, actualVid)
    }
}



