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

import AEPIdentity
import Foundation


class AnalyticsRequestSerializer {
    
    func generateAnalyticsCustomerIdString(from identifiableList: [Identifiable?]) -> String {
        
        guard !identifiableList.isEmpty else {
            return ""
        }
                
        var visitorDataMap: [String: String] = [String: String]()
        for identifiable in identifiableList {
            if let identifiable = identifiable, let type = identifiable.type {
                visitorDataMap[serializeIdentifierKeyForAnalyticsId(idType: type)] = identifiable.identifier
                visitorDataMap[serializeAuthenticationKeyForAnalyticsId(idType: type)] = "\(identifiable.authenticationState.rawValue)"
            }
        }
        
        // MARK: TODO implement class ContextData in AEPCore. Call ContextData::EncodeContextData(visitorDataMap) in place of placeholder.
        
        return "&cid.\("Placeholder")&.cid"
    }
    
    private func serializeIdentifierKeyForAnalyticsId(idType: String) -> String {
        return "\(idType).id"
    }
    
    private func serializeAuthenticationKeyForAnalyticsId(idType: String) -> String {
        return "\(idType).as"
    }
}
