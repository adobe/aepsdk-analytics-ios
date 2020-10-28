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

class ContextDataUtil {
    
    private static let contextDataMask: [Bool] = [
        false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
        false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
        false, false, false, false, false, false, false, false, false, false, false, false, false, false,  true, false,
        true,  true,  true,  true,  true,  true,  true,  true,  true,  true, false, false, false, false, false, false,
        false,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,
        true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true, false, false, false, false,  true, false,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,
        true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true, false, false, false, false, false,
        false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
        false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
        false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
        false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
        false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
        false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
        false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
        false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false
    ]
    
    static func EncodeContextData(data contextData: [String: String]) -> String {
        let cleanedDataMap: [String: String] = cleanDictionaryKeys(contextData: contextData)

        var encodedMap = [String: ContextData]()
        
        for (key, value) in cleanedDataMap {
            encodeValueIntoMap(value: value, contextDataMap: &encodedMap, keys: key.split(separator: ".", omittingEmptySubsequences: true), index: 0)
        }
        
        return serializeMapToQueryString(map: encodedMap)
    }
    
    private static func serializeMapToQueryString(map: [String: Any]) -> String {
        
        var queryParams = String.init()
        
        for (key, value) in map {
            guard !key.isEmpty else {
                continue
            }
            
            var urlEncodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            
            if let contextData = value as? ContextData {
            
                if let value = contextData.value, !value.isEmpty {
                    queryParams.append(String(format: "&%@=%@", key, value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) as! CVarArg))
                }
            
                if contextData.data.count > 0 {
                    queryParams.append(String(format: "&%@.%@&.%@", urlEncodedKey as! CVarArg, serializeMapToQueryString(map: contextData.data),urlEncodedKey as! CVarArg))
                }
            }
            else { //Value is of type String.
                queryParams.append(String(format: "&%@.%@&.%@", urlEncodedKey as! CVarArg, "\(key)=\(value)",urlEncodedKey as! CVarArg))
            }
        }
        
        return queryParams
    }
    
    private static func encodeValueIntoMap(value: String, contextDataMap: inout [String: ContextData], keys: [String.SubSequence], index: Int) {
        
        guard index < keys.count else {
            return
        }
       
        var keyName = String(keys[index])
        
        if keys.count - 1 == index {
            let contextData : ContextData = contextDataMap[keyName] ?? ContextData.init()
            contextData.value = value
            contextDataMap[keyName] = contextData
        }
        else {
            let contextData : ContextData = contextDataMap[keyName] ?? ContextData.init()
            contextDataMap[keyName] = contextData
            encodeValueIntoMap(value: value, contextDataMap: &contextDataMap, keys: keys, index: index + 1)
        }
    }
    
    private static func cleanDictionaryKeys(contextData: [String: String]) -> [String: String] {
        var cleanDictionary = [String: String]()
        for (key, value) in contextData {
            
            let cleanedKey = cleanKey(key: key)
            if !cleanedKey.isEmpty{
                cleanDictionary[cleanedKey] = value
            }
        }
        return cleanDictionary
    }
    
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
            cleanedKey.remove(at: cleanedKey.startIndex)
        }
            
        if cleanedKey.last == period {
            cleanedKey.popLast()
        }
        return cleanedKey
    }
}
