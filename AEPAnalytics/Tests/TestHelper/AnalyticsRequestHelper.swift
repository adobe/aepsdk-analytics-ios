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

@testable import AEPAnalytics

class AnalyticsRequestHelper {
    static func getCidData(source: String) -> String {
        let regex = "&cid\\.(.*)&\\.cid"
        if let range = source.range(of: regex, options: .regularExpression) {
            return String(source[range])
        }
        return ""
    }

    static func getContextDataString(source: String) -> String {
        let regex = "(&c\\.(.*)&\\.c)"
        if let range = source.range(of: regex, options: .regularExpression) {
            return String(source[range])
        }
        return ""
    }

    static func getContextData(source: String) -> [String: Any] {
        let contextDataString = getContextDataString(source: source)
        // Strip &c. and &.c
        let strippedString = contextDataString.dropFirst("&c.".count).dropLast("&.c".count)
        return ContextDataUtil.deserializeContextDataKeyValuePairs(serializedContextData: String(strippedString))

    }

    static func getQueryParams(source: String) -> [String: Any] {
        let contextDataString = getContextDataString(source: source)
        let queryString = source.replacingOccurrences(of: contextDataString, with: "")
        var ret = [String: String]()

        if !queryString.isEmpty {
            for item in queryString.components(separatedBy: "&") {
                let pairs = item.components(separatedBy: "=")
                let key = pairs[0]
                let value = pairs.count > 1 ? pairs[1] : ""
                ret[key] = value.removingPercentEncoding
            }
        }
        return ret            
    }

    static func getAdditionalData(source: String) -> String {
        var additionalData = source.replacingOccurrences(of: getCidData(source: source), with: "")
        additionalData = additionalData.replacingOccurrences(of: getContextDataString(source: source), with: "")
        return additionalData
    }
}
