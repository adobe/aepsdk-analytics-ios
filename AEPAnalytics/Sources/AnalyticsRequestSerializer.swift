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
import AEPIdentity

class AnalyticsRequestSerializer {

    /// Creates a Map having the VisitorIDs information (types, ids and authentication state) and serializes it.
    /// - Parameter identifiableList an array of Identifiable Type that we want to process in the analytics format.
    /// - Returns the serialized String of Indentifiable VisitorId's. Retuns empty string if Identifiable Array is empty.
    func generateAnalyticsCustomerIdString(from identifiableList: [Identifiable?]) -> String {
        var analyticsCustomerIdString = ""
        guard !identifiableList.isEmpty else {
            return analyticsCustomerIdString
        }
        var visitorDataMap = [String: String]()
        for identifiable in identifiableList {
            if let identifiable = identifiable, let type = identifiable.type {
                visitorDataMap[serializeIdentifierKeyForAnalyticsId(idType: type)] = identifiable.identifier
                visitorDataMap[serializeAuthenticationKeyForAnalyticsId(idType: type)] = "\(identifiable.authenticationState.rawValue)"
            }
        }

        var translateIds : [String:ContextData] = [:]
        translateIds["cid"] = ContextDataUtil.translateContextData(data: visitorDataMap)

        ContextDataUtil.serializeToQueryString(parameters: translateIds, requestString: &analyticsCustomerIdString)
        return analyticsCustomerIdString
    }

    /**
     Serializes the analytics data and vars into the request string that will be later on stored in
     database as a new hit to be processed.
     - Parameters:
        - analyticsState: object represents the shared state of other dependent modules.
        - data: Analytics data map computed with `Analytics.processAnalyticsContextData`.
        - vars: analytics vars map computed with  `Analytics.processAnalyticsVars`.
     - Returns: A serialized String.
     */
    func buildRequest(analyticsState: AnalyticsState, data: [String: String]?, vars: [String: String]?) -> String {
        var analyticsVars: [String: Any] = [:]

        if let vars = vars, !vars.isEmpty {
            vars.forEach { key, value in
                if !key.isEmpty {
                    analyticsVars[key] = value
                }
            }
        }

        if let data = data, !data.isEmpty {
            for (key, value) in data {
                if !key.isEmpty && key.hasPrefix(AnalyticsConstants.VAR_ESCAPE_PREFIX) {
                    analyticsVars[String(key.suffix(from: AnalyticsConstants.VAR_ESCAPE_PREFIX.endIndex))] = value
                }
            }
        }

        analyticsVars[AnalyticsConstants.Request.CONTEXT_DATA_KEY] = ContextDataUtil.translateContextData(data: data)

        var requestString = "ndh=1"
        if analyticsState.isVisitorIdServiceEnabled(), let serializedVisitorIdList = analyticsState.serializedVisitorIdsList {
            requestString += serializedVisitorIdList
        }

        ContextDataUtil.serializeToQueryString(parameters: analyticsVars, requestString: &requestString)
        return requestString
    }

    /// Serialize data into analytics format.
    /// - Parameter idType the idType value from the visitor ID service.
    /// - Returns idType.id, serialized indentifier key for AID
    private func serializeIdentifierKeyForAnalyticsId(idType: String) -> String {
        return "\(idType).id"
    }

    /// Serialize data into analytics format.
    /// - Parameter idType the idType value from the visitor id dervice.
    /// - Returns idType.as, serialized authentication key for AID
    private func serializeAuthenticationKeyForAnalyticsId(idType: String) -> String {
        return "\(idType).as"
    }
}
