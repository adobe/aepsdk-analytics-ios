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

            let scalars = String(char).unicodeScalars
            if contextDataMask[Int(scalars[scalars.startIndex].value)] {
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

            if let urlEncodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                if let contextData = value as? ContextData {
                    if let urlEncodedValue = contextData.value?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), !urlEncodedKey.isEmpty {
                        requestString.append("&\(urlEncodedKey)=\(urlEncodedValue)")
                    }

                    if !contextData.data.isEmpty {
                        requestString.append("&\(urlEncodedKey).")
                        serializeToQueryString(parameters: contextData.data, requestString: &requestString)
                        requestString.append("&.\(urlEncodedKey)")
                    }
                } else if let urlEncodedValue = (value as? String)?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), !urlEncodedKey.isEmpty, !urlEncodedValue.isEmpty {
                    requestString.append("&\(urlEncodedKey)=\(urlEncodedValue)")
                }
            }
        }
    }

    static func appendContextData(data: [String: Any]?, payload: String) -> String {
        return payload
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
}
