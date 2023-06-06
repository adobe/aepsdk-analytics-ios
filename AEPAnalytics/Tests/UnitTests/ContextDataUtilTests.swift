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
import Foundation
@testable import AEPAnalytics

class ContextDataUtilTests: XCTestCase {

    func testAppendContextData_When_EmptySource() {
        let emptySource = ""
        var data = [String: String]()
        data["new-key"] = "value"
        let serializedContextDataQuery = "&c.&newkey=value&.c"
        XCTAssertEqual(serializedContextDataQuery, ContextDataUtil.appendContextData(contextData: data, source: emptySource))
    }

    func testAppendContextData_When_NoContextDataInSource() {
        let sourceUrl = "http://abc.com"
        var data = [String: String]()
        data["new-key"] = "value"
        XCTAssertEqual("\(sourceUrl)&c.&newkey=value&.c", ContextDataUtil.appendContextData(contextData: data, source: sourceUrl))
    }

    func testAppendContextData_When_ContextDataIsNullOrEmpty() {
        let sourceUrl = "http://abc.com"
        XCTAssertEqual(sourceUrl, ContextDataUtil.appendContextData(contextData: nil, source: sourceUrl))
        let data = [String: String]()
        XCTAssertEqual(sourceUrl, ContextDataUtil.appendContextData(contextData: data, source: sourceUrl))
    }

    func testAppendContextData_When_KeyHasInvalidCharacters() {
        let sourceUrl = "http://abc.com"
        var data = [String: String]()
        data["网页"] = "value"
        XCTAssertEqual("\(sourceUrl)", ContextDataUtil.appendContextData(contextData: data, source: sourceUrl))
    }

    func testAppendContextData_When_UnicodeValues() {
        let sourceUrl = "http://abc.com"
        var data = [String: String]()
        data["key"] = "网页"

        let encodedValue = "网页".addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved)!
        XCTAssertEqual("\(sourceUrl)&c.&key=\(encodedValue)&.c", ContextDataUtil.appendContextData(contextData: data, source: sourceUrl))
    }

    func testAppendContextData_When_ContextDataOnePair() {
        let data: [String: String] = ["key": "value"]
        XCTAssertEqual("&c.&key=value&.c", ContextDataUtil.appendContextData(contextData: data, source: "&c.&.c"))
    }

    func testAppendContextData_When_ContextDataTwoPair() {
        let data: [String: String] = ["key": "value", "key1": "value1"]

        let result = ContextDataUtil.appendContextData(contextData: data, source: "&c.&.c")
        XCTAssertTrue(contextDataInCorrectSequence(source: result, target: "key=value", start: "&c.", end: "&.c"))
        XCTAssertTrue(contextDataInCorrectSequence(source: result, target: "key1=value1", start: "&c.", end: "&.c"))
    }

    func testAppendContextData_When_ContextDataWithNestedKeyName() {
        let data: [String: String] = ["key": "value", "key.nest": "value1"]

        let result = ContextDataUtil.appendContextData(contextData: data, source: "&c.&.c")
        XCTAssertTrue(contextDataInCorrectSequence(source: result, target: "key=value", start: "&c.", end: "&.c"))
        XCTAssertTrue(contextDataInCorrectSequence(source: result, target: "nest=value1", start: "&key.", end: "&.key"))
    }

    func testAppendContextData_When_NestedKeyNameOverrideOldValue() {
        let data: [String: String] = ["key": "new-value", "key.nest": "new-value1"]

        let result = ContextDataUtil.appendContextData(contextData: data, source: "&c.&key=value&key.&nest=value1&.key&.c")
        XCTAssertTrue(contextDataInCorrectSequence(source: result, target: "key=new-value", start: "&c.", end: "&.c"))
        XCTAssertTrue(contextDataInCorrectSequence(source: result, target: "nest=new-value1", start: "&key.", end: "&.key"))
    }

    func testAppendContextData_When_NestedKeyNameAppendToExistingLevel() {
        let data: [String: String] = ["key2.new2": "value2", "key1.new3": "value3"]

        let result = ContextDataUtil.appendContextData(contextData: data, source: "&c.&key=value&key2.&nest=value1&.key2&key1.&nest1=value2&.key1&.c")

        XCTAssertTrue(contextDataInCorrectSequence(source: result, target: "new3=value3", start: "&key1.", end: "&.key1"))
        XCTAssertTrue(contextDataInCorrectSequence(source: result, target: "nest1=value2", start: "&key1.", end: "&.key1"))
        XCTAssertTrue(contextDataInCorrectSequence(source: result, target: "key=value", start: "&c.", end: "&.c"))

        XCTAssertTrue(contextDataInCorrectSequence(source: result, target: "new2=value2", start: "&key2.", end: "&.key2"))
        XCTAssertTrue(contextDataInCorrectSequence(source: result, target: "nest=value1", start: "&key2.", end: "&.key2"))
    }

    func testAppendContextData_When_NestedKeyNameAppendToExistingLevel_4Level() {
        let data: [String: String] = ["level1.level2.level3.level4.new": "new", "key1.new": "value", "key.new": "value"]

        let result = ContextDataUtil.appendContextData(contextData: data, source: "&c.&key=value&key.&nest=value1&.key&key1.&nest=value1&.key1&level1.&level2.&level3.&level4.&old=old&.level4&.level3&.level2&.level1&.c")

        XCTAssertTrue(contextDataInCorrectSequence(source: result, target: "&level2.", start: "&level1.", end: "&.level1"))
        XCTAssertTrue(contextDataInCorrectSequence(source: result, target: "&level3.", start: "&level2.", end: "&.level2"))
        XCTAssertTrue(contextDataInCorrectSequence(source: result, target: "&level4.", start: "&level3.", end: "&.level3"))
        XCTAssertTrue(contextDataInCorrectSequence(source: result, target: "old=old", start: "&level4.", end: "&.level4"))
        XCTAssertTrue(contextDataInCorrectSequence(source: result, target: "new=new", start: "&level4.", end: "&.level4"))
    }

    func testAppendContextData_When_ContextDataWithUTF8() {
        let data: [String: String] = ["level1.level2.level3.level4.new": "中文", "key1.new": "value", "key.new": "value"]

        let result = ContextDataUtil.appendContextData(contextData: data, source: "&c.&key=value&key.&nest=value1&.key&key1.&nest=value1&.key1&level1.&level2.&level3.&level4.&old=old&.level4&.level3&.level2&.level1&.c")

        XCTAssertTrue(contextDataInCorrectSequence(source: result, target: "new=%E4%B8%AD%E6%96%87", start: "&level4.", end: "&.level4"))
    }

    func testAppendContextData_When_ContextDataUTF8_And_SourceContainsUTF8() {
        let data: [String: String] = ["level1.level2.level3.level4.new": "中文", "key1.new": "value", "key.new": "value"]

        let result = ContextDataUtil.appendContextData(contextData: data, source: "&c.&key=value&key.&nest=value1&.key&key1.&nest=%E4%B8%AD%E6%96%87&.key1&level1.&level2.&level3.&level4.&old=old&.level4&.level3&.level2&.level1&.c")

        XCTAssertTrue(contextDataInCorrectSequence(source: result, target: "new=%E4%B8%AD%E6%96%87", start: "&level4.", end: "&.level4"))
        XCTAssertTrue(contextDataInCorrectSequence(source: result, target: "nest=%E4%B8%AD%E6%96%87", start: "&key1.", end: "&.key1"))
    }

    func testAppendContextData_When_SourceIsARealHit() {
        let data: [String: String] = ["key1.new1": "value1", "key2.new2": "value2"]

        let result = ContextDataUtil.appendContextData(contextData: data, source: "ndh=1&pe=lnk_o&pev2=ADBINTERNAL%3ALifecycle&pageName=My%20Application%201.0%20%281%29&t=00%2F00%2F0000%2000%3A00%3A00%200%20360&ts=1432159549&c.&a.&DeviceName=SAMSUNG-SGH-I337&Resolution=1080x1920&OSVersion=Android%204.3&CarrierName=&internalaction=Lifecycle&AppID=My%20Application%201.0%20%281%29&Launches=1&InstallEvent=InstallEvent&DayOfWeek=4&InstallDate=5%2F20%2F2015&LaunchEvent=LaunchEvent&DailyEngUserEvent=DailyEngUserEvent&RunMode=Application&HourOfDay=16&MonthlyEngUserEvent=MonthlyEngUserEvent&.a&.c&mid=45872199741202307594993613744306256830&ce=UTF-8")

        XCTAssertTrue(contextDataInCorrectSequence(source: result, target: "new1=value1", start: "&key1.", end: "&.key1"))
        XCTAssertTrue(contextDataInCorrectSequence(source: result, target: "new2=value2", start: "&key2.", end: "&.key2"))
    }

    private func contextDataInCorrectSequence(source: String, target: String, start: String, end: String) -> Bool {
        guard let startRange = source.range(of: start), let targetRange = source.range(of: target), let endRange = source.range(of: end) else {
            return false
        }

        return source.distance(from: startRange.upperBound, to: targetRange.lowerBound) >= 0 && source.distance(from: targetRange.upperBound, to: endRange.lowerBound) >= 0
    }

}
