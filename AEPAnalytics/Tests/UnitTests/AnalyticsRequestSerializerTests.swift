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

class AnalyticsRequestSerializerTests: XCTestCase {

    var analyticsRequestSerializer: AnalyticsRequestSerializer!
    var analyticsState: AnalyticsState!

    override func setUp() {
        analyticsRequestSerializer = AnalyticsRequestSerializer()
        analyticsState = AnalyticsState()
    }

    func testGenerateAnalyticsCustomerIdString() {
        var visitorIdArray = [[String: Any]]()
        visitorIdArray.append(["id_origin": "d_cid_ic", "id_type": "loginidhash", "id": "97717", "authentication_state": 0])
        visitorIdArray.append(["id_origin": "d_cid_ic", "id_type": "xboxlivehash", "id": "1629158955", "authentication_state": 1])
        visitorIdArray.append(["id_origin": "d_cid_ic", "id_type": "psnidhash", "id": "1144032295", "authentication_state": 2])
        visitorIdArray.append(["id_origin": "d_cid_ic", "id_type": "pushid", "id": "testPushId", "authentication_state": 1])

        let expectedString = "&cid.&loginidhash.&id=97717&as=0&.loginidhash&xboxlivehash.&id=1629158955&as=1&.xboxlivehash&psnidhash.&id=1144032295&as=2&.psnidhash&pushid.&id=testPushId&as=1&.pushid&.cid"

        var expectedArray = expectedString.split(separator: "&")
        expectedArray.sort()

        let analyticsIdString = analyticsRequestSerializer.generateAnalyticsCustomerIdString(from: visitorIdArray)
        var testArray = analyticsIdString.split(separator: "&")
        testArray.sort()

        XCTAssertEqual(expectedArray.count, testArray.count)
        XCTAssertEqual(expectedArray.description, testArray.description)

    }

    func testGenerateAnalyticsCustomerIdStringWithEmptyIdentifiableList() {
        let visitorIdArray = [[String: Any]]()

        let expectedString = ""
        let analyticsIdString = analyticsRequestSerializer.generateAnalyticsCustomerIdString(from: visitorIdArray)
        XCTAssertEqual(expectedString, analyticsIdString)
    }

    func testBuildRequestWhenValidDataAndValidVars() {
        var vars: [String: String] = [:]
        vars["v1"] = "evar1Value"
        vars["v2"] = "evar2Value"

        var data: [String: String] = [:]
        data["testKey1"] = "val1"
        data["testKey2"] = "val2"

        let result = analyticsRequestSerializer.buildRequest(analyticsState: analyticsState, data: data, vars: vars)
        let contextData = AnalyticsRequestHelper.getContextDataString(source: result)
        XCTAssertTrue(contextData.contains("&c."))
        XCTAssertTrue(contextData.contains("&.c"))
        XCTAssertTrue(contextData.contains("&testKey1=val1"))
        XCTAssertTrue(contextData.contains("&testKey2=val2"))
        let additionalData = AnalyticsRequestHelper.getAdditionalData(source: result)
        let splitAddionalData = additionalData.split(separator: "&")
        XCTAssertTrue(splitAddionalData.count == 3)
        XCTAssertTrue(additionalData.starts(with: "ndh=1"))
        XCTAssertTrue(additionalData.contains("&v2=evar2Value"))
        XCTAssertTrue(additionalData.contains("&v1=evar1Value"))
        XCTAssertTrue(AnalyticsRequestHelper.getCidData(source: result).isEmpty)
    }

    func testBuildRequestWhenNullDataAndValidVars() {
        var vars: [String: String] = [:]
        vars["v1"] = "evar1Value"
        vars["v2"] = "evar2Value"
        let result = analyticsRequestSerializer.buildRequest(analyticsState: analyticsState, data: nil, vars: vars)
        XCTAssertTrue(AnalyticsRequestHelper.getCidData(source: result).isEmpty)
        XCTAssertTrue(AnalyticsRequestHelper.getContextDataString(source: result).isEmpty)
    }

    func testBuildRequestWhenValidDataAndNullVars() {
        var data: [String: String] = [:]
        data["testKey1"] = "val1"
        data["testKey2"] = "val2"
        let result = analyticsRequestSerializer.buildRequest(analyticsState: analyticsState, data: data, vars: nil)

        let contextData = AnalyticsRequestHelper.getContextDataString(source: result)
        XCTAssertTrue(contextData.contains("&c."))
        XCTAssertTrue(contextData.contains("&.c"))
        XCTAssertTrue(contextData.contains("&testKey1=val1"))
        XCTAssertTrue(contextData.contains("&testKey2=val2"))
        let additionalData = AnalyticsRequestHelper.getAdditionalData(source: result)
        XCTAssertEqual("ndh=1", additionalData)
        XCTAssertTrue(AnalyticsRequestHelper.getCidData(source: result).isEmpty)
    }

    func testBuildRequestWhenNullDataAndNullVars() {
        let result = analyticsRequestSerializer.buildRequest(analyticsState: analyticsState, data: nil, vars: nil)
        XCTAssertEqual("ndh=1", result)
    }

    func testBuildRequestWhenNullVisitorIdList() {

        var data: [String: String] = [:]
        data["testKey1"] = "val1"
        data["testKey2"] = "val2"

        var identityData: [String: Any] = [:]
        identityData["mid"] = "testMID"

        var configurationData: [String: Any] = [:]
        configurationData["analytics.server"] = "analyticsServer"
        configurationData["experienceCloud.org"] = "marketingServer"

        var sharedStates = [String: [String: Any]]()
        sharedStates[AnalyticsTestConstants.Identity.EventDataKeys.SHARED_STATE_NAME] = identityData
        sharedStates[AnalyticsTestConstants.Configuration.EventDataKeys.SHARED_STATE_NAME] = configurationData
        analyticsState.update(dataMap: sharedStates)

        let result = analyticsRequestSerializer.buildRequest(analyticsState: analyticsState, data: data, vars: nil)
        XCTAssertTrue(result.contains("ndh=1"))
        XCTAssertTrue(result.contains("&c."))
        XCTAssertTrue(result.contains("&.c"))
        XCTAssertTrue(result.contains("&testKey1=val1"))
        XCTAssertTrue(result.contains("&testKey2=val2"))
    }

    func testBuildRequestMovesToVarsWhenDataKeysPrefixed() {
        var data: [String: String] = [:]
        data["&&key1"] = "val1"
        data["key2"] = "val2"

        var vars = [String: String]()
        vars["v1"] = "evar1Value"

        let result = analyticsRequestSerializer.buildRequest(analyticsState: analyticsState, data: data, vars: vars)
        let additionalData = AnalyticsRequestHelper.getAdditionalData(source: result)
        let splitAddionalData = additionalData.split(separator: "&")
        XCTAssertTrue(splitAddionalData.count == 3)
        XCTAssertTrue(additionalData.starts(with: "ndh=1"))
        XCTAssertTrue(additionalData.contains("&key1=val1"))
        XCTAssertTrue(additionalData.contains("&v1=evar1Value"))
        XCTAssertEqual("&c.&key2=val2&.c", AnalyticsRequestHelper.getContextDataString(source: result))
        XCTAssertTrue(AnalyticsRequestHelper.getCidData(source: result).isEmpty)
    }

    func testBuildRequestWithVisitorIdList() {

        var vars = [String: String]()
        vars["v1"] = "evar1Value"

        var data: [String: String] = [:]
        data["key1"] = "val1"
        var visitorIdList = [[String: Any]]()
        visitorIdList.append(["id_origin": "orig1", "id_type": "type1", "id": "97717", "authentication_state": 1])

        var identityData: [String: Any] = [:]
        identityData["visitoridslist"] = visitorIdList

        var sharedStates = [String: [String: Any]]()
        sharedStates[AnalyticsTestConstants.Identity.EventDataKeys.SHARED_STATE_NAME] = identityData
        analyticsState.update(dataMap: sharedStates)
        analyticsState.marketingCloudOrganizationId = "orgID"

        let result = analyticsRequestSerializer.buildRequest(analyticsState: analyticsState, data: data, vars: vars)
        XCTAssertEqual("ndh=1&v1=evar1Value", AnalyticsRequestHelper.getAdditionalData(source: result))
        XCTAssertEqual("&c.&key1=val1&.c", AnalyticsRequestHelper.getContextDataString(source: result))
        let cidData = AnalyticsRequestHelper.getCidData(source: result)
        let splittedCidData = cidData.split(separator: "&")
        XCTAssertTrue(splittedCidData.count == 6)
        XCTAssertTrue(cidData.starts(with: "&cid."))

        XCTAssertTrue(cidData.contains("type1."))
        XCTAssertTrue(cidData.contains("as=1"))
        XCTAssertTrue(cidData.contains("id=97717"))
        XCTAssertTrue(cidData.contains(".type1"))
        XCTAssertTrue(cidData.contains("&.cid"))
    }
}
