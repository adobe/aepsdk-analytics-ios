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

extension AnalyticsRequestSerializeTests {

    func getCidData(source: String) -> String {
        let regex = "&cid\\.(.*)&\\.cid"
        if let range = source.range(of: regex, options: .regularExpression) {
            return String(source[range])
        }
        return ""
    }

    func getContextData(source: String) -> String {
        let regex = "(&c\\.(.*)&\\.c)"
        if let range = source.range(of: regex, options: .regularExpression) {
            return String(source[range])
        }
        return ""
    }

    func getAdditionalData(source: String) -> String {
        var additionalData = source.replacingOccurrences(of: getCidData(source: source), with: "")
        additionalData = additionalData.replacingOccurrences(of: getContextData(source: source), with: "")
        return additionalData
    }
}
