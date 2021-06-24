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

import Foundation
import AEPServices

extension CharacterSet {
    static let rfc3986Unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
}

class ContextDataUtil {

    static let LOG_TAG = "ContextDataUtil"

    private static let contextDataMask: [Bool] = [
        false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
        false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
        false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false,
        true, true, true, true, true, true, true, true, true, true, false, false, false, false, false, false,
        false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true,
        true, true, true, true, true, true, true, true, true, true, true, false, false, false, false, true, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true,
        true, true, true, true, true, true, true, true, true, true, true, false, false, false, false, false,
        false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
        false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
        false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
        false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
        false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
        false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
        false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
        false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false
    ]

    /**
     Takes dictionary as an argument, clean the keys and returns the dictionary with cleaned keys.
     - Parameters contextData: The dictionary to be cleaned.
     - Returns: Dictionary with clean keys.
     */
    private static func cleanDictionaryKeys(contextData: [String: String]) -> [String: String] {
        var cleanDictionary = [String: String]()
        for (key, value) in contextData {

            let cleanedKey = cleanKey(key: key)
            if !cleanedKey.isEmpty {
                cleanDictionary[cleanedKey] = value
            }
        }
        return cleanDictionary
    }

    /**
     Cleans the `key` passed as an arguement using the contextDataMask. Only the characters which are enabled in `contextDataMask` are allowed in the cleaned key.
     - Parameters key: The key to be cleaned.
     - Returns: The cleaned key.
     */
    private static func cleanKey(key: String) -> String {
        guard !key.isEmpty else {
            return ""
        }

        var cleanedKey = ""
        let period: Character = "."

        for char in key {
            if char == period && cleanedKey.last == period {
                continue
            }

            let scalarValue = Int(char.unicodeScalars.first?.value ?? 0)
            if scalarValue >= 0 && scalarValue < contextDataMask.count, contextDataMask[scalarValue] {
                cleanedKey.append(char)
            }

        }
        if cleanedKey.first == period {
            cleanedKey.removeFirst()
        }

        if cleanedKey.last == period {
            cleanedKey.removeLast()
        }
        return cleanedKey
    }

    /**
     Translates string based context data into a nested dictionary format for serializing to query string.
     This method contains a recursive block.
     - Parameters:
         - data: the data Dictionary that we want to process.
     - Returns: a new `ContextData` object containing the provided data.
     */
    static func translateContextData(data: [String: String]?) -> ContextData {
        var contextData = ContextData()
        guard let data = data else {
            Log.debug(label: LOG_TAG, "translateContextData - data is nil.")
            return contextData
        }
        let cleanData = cleanDictionaryKeys(contextData: data)
        cleanData.forEach { key, value in
            let subKeys = key.split(separator: ".")
            addValueToContextData(value: value, inContextData: &contextData, subkeys: subKeys, index: 0)
        }
        return contextData
    }

    /**
     Serializes a Dictionary to key value pairs for url string.
     This method is recursive to handle the nested data objects.
     - Parameters:
          - parameters: the query parameters that we want to serialize
          - requestString: The query String. Used for recursivity.
     */
    static func serializeToQueryString(parameters: [String: Any]?, requestString: inout String) {

        guard let parameters = parameters else {
            Log.debug(label: LOG_TAG, "serializeToQueryString - parameters is nil.")
            return
        }

        parameters.keys.sorted().forEach { key in
            let value = parameters[key]

            if let urlEncodedKey = key.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved) {
                if let contextData = value as? ContextData {
                    if let urlEncodedValue = contextData.value?.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved), !urlEncodedKey.isEmpty {
                        requestString.append("&\(urlEncodedKey)=\(urlEncodedValue)")
                    }

                    if !contextData.data.isEmpty {
                        requestString.append("&\(urlEncodedKey).")
                        serializeToQueryString(parameters: contextData.data, requestString: &requestString)
                        requestString.append("&.\(urlEncodedKey)")
                    }
                } else if let urlEncodedValue = (value as? String)?.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved), !urlEncodedKey.isEmpty, !urlEncodedValue.isEmpty {
                    requestString.append("&\(urlEncodedKey)=\(urlEncodedValue)")
                }
            }
        }
    }

    /**
     Recursively add the `subkeys` and `value` to `contextData` passed as an arguement.
     - Parameters:
         - value: The `String` value to be added.
         - inContextData: The `ContextData` object in which subkeys and value has to be added.
         - subkeys: An `Array` of keys to be added.
         - index: The index pointing to `subkeys` array elements.
     */
    private static func addValueToContextData(value: String, inContextData contextData: inout ContextData, subkeys: [Substring]?, index: Int) {
        guard let subkeys = subkeys, index < subkeys.count else {
            Log.debug(label: LOG_TAG, "addValueToContextData - subkeys is nil.")
            return
        }

        let keyName = subkeys[index].description
        var data: ContextData = contextData.data[keyName] ?? ContextData.init()

        if subkeys.count - 1 == index {
            // last node in the array
            data.value = value
            contextData.data[keyName] = data
        } else {
            // more nodes to go through, add a ContextData to the caller if necessary
            contextData.data[keyName] = data
            addValueToContextData(value: value, inContextData: &data, subkeys: subkeys, index: index + 1)
        }
    }

    /**
     Gets the url fragment, it deserialize it, appends the given map inside the context data node if that one
     exists and serialize it back to the initial format. Otherwise it returns the initial url fragment

     - Parameters:
        - contextData: the `Dictionary` that we want to append to the initial url fragment
        - source: the url fragment as `String`
     - Returns: the url fragment that has the given `Dictionary` merged inside the context data node
     */
    static func appendContextData(contextData: [String: String]?, source: String) -> String {

        guard let contextData = contextData, !contextData.isEmpty else {
            Log.debug(label: LOG_TAG, "\(#function) - Returning early. Context data passed is nil or empty.")
            return source
        }

        let contextDataPattern = ".*(&c\\.(.*)&\\.c).*"
        var regex: NSRegularExpression?

        do {
            regex = try NSRegularExpression(pattern: contextDataPattern, options: [])
        } catch {
            Log.debug(label: LOG_TAG, "\(#function) - Context data regular expression failed with exception:  (\(error.localizedDescription))")
        }

        let result = regex?.firstMatch(in: source, options: [], range: NSRange.init(location: 0, length: source.count))
        if let regexResult = result, regexResult.numberOfRanges >= 2 {
            let innerContextDataRange = regexResult.range(at: 2)  // It excludes the context data &c.&.c for ex: in &c.abc&.c will return abc
            let start = innerContextDataRange.lowerBound
            let end = innerContextDataRange.upperBound
            let contextDataString = source[source.index(source.startIndex, offsetBy: start)..<source.index(source.startIndex, offsetBy: end)]
            var deserializedContextData = deserializeContextDataKeyValuePairs(serializedContextData: String(contextDataString))
            contextData.forEach { key, value in
                deserializedContextData[key] = value
            }

            let outerContextDataRange = regexResult.range(at: 1) // It includes the context data &c.&.c for ex: in &c.abc&.c will return &c.abc&.c
            let startOuter = outerContextDataRange.lowerBound
            let endOuter = outerContextDataRange.upperBound

            var serializedUrl = String(source[source.startIndex..<source.index(source.startIndex, offsetBy: startOuter)])
            var contextMap: [String: Any] = [:]
            contextMap["c"] = translateContextData(data: deserializedContextData)
            serializeToQueryString(parameters: contextMap, requestString: &serializedUrl)
            if endOuter < source.count {
                serializedUrl += String(source[source.index(source.startIndex, offsetBy: endOuter)..<source.index(source.startIndex, offsetBy: source.count)])
            }
            return serializedUrl

        } else {
            var serializedUrl = source
            var contextMap: [String: Any] = [:]
            contextMap["c"] = translateContextData(data: contextData)
            serializeToQueryString(parameters: contextMap, requestString: &serializedUrl)
            return serializedUrl
        }
    }

    /**
     Splits the context data string into key value pairs parameters and returns them as a `Dictionary`

     - Parameter contextDataString: the context data url fragment that we want to deserialize
     - Returns: context data as `Dictionary`
     */
    static func deserializeContextDataKeyValuePairs(serializedContextData data: String) -> [String: String] {
        var contextData: [String: String] = [:]
        var keyPath = [String]()

        let subString = data.split(separator: "&")
        for substring in subString {
            if substring.hasSuffix(".") && !substring.contains("=") {
                keyPath.append(String(substring))
            } else if substring.hasPrefix(".") {
                if !keyPath.isEmpty {
                    keyPath.remove(at: keyPath.count - 1)
                }
            } else {
                let kvPair = substring.split(separator: "=")
                if kvPair.count != 2 {
                    continue
                }
                let contextDataKey = contextDataStringPath(keyPath: keyPath, lastComponent: String(kvPair[0]))
                contextData[contextDataKey] = URLEncoder.decode(value: String(kvPair[1]))
            }
        }

        return contextData
    }

    private static func contextDataStringPath(keyPath: [String], lastComponent: String) -> String {
        var stringPath = ""

        for path in keyPath {
            stringPath += "\(path)"
        }

        stringPath += "\(lastComponent)"
        return stringPath
    }
}
