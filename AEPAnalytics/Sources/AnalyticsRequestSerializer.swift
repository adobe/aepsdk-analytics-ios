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

class AnalyticsRequestSerializer {

    private let TAG = "AnalyticsRequestSerializer"

    /// Creates a Dictionary having the VisitorIDs information (types, ids and authentication state) and serializes it.
    /// - Parameter visitorIdArray an array containing synced VisitorIDs Dictionaries that we want to process in the analytics format.
    /// - Returns the serialized String of VisitorId's. Retuns an empty string if the VisitorID Array is empty.
    func generateAnalyticsCustomerIdString(from visitorIDArray: [[String: Any]]?) -> String {
        var analyticsCustomerIdString = ""
        guard let visitorIDs = visitorIDArray, !visitorIDs.isEmpty else {
            Log.debug(label: TAG, "generateAnalyticsCustomerIdString - Visitor ID's are nil. Returning empty string.")
            return analyticsCustomerIdString
        }
        var visitorDataDict = [String: String]()
        for id in visitorIDs {
            if let type = id[AnalyticsConstants.Identity.EventDataKeys.VISITOR_ID_TYPE] as? String, !type.isEmpty {
                visitorDataDict[serializeIdentifierKeyForAnalyticsId(idType: type)] = id[AnalyticsConstants.Identity.EventDataKeys.VISITOR_ID] as? String
                visitorDataDict[serializeAuthenticationKeyForAnalyticsId(idType: type)] = "\(id[AnalyticsConstants.Identity.EventDataKeys.VISITOR_ID_AUTHENTICATION_STATE] ?? "")"
            }
        }

        var translateIds: [String: ContextData] = [:]
        translateIds[AnalyticsConstants.Request.CUSTOMER_ID_KEY] = ContextDataUtil.translateContextData(data: visitorDataDict)

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

        var data: [String: String] = data ?? [:]
        if !data.isEmpty {
            for (key, value) in data where key.hasPrefix(AnalyticsConstants.VAR_ESCAPE_PREFIX) {
                analyticsVars[String(key.suffix(from: AnalyticsConstants.VAR_ESCAPE_PREFIX.endIndex))] = value
                data.removeValue(forKey: key)
            }
        }

        analyticsVars[AnalyticsConstants.Request.CONTEXT_DATA_KEY] = ContextDataUtil.translateContextData(data: data)

        var requestString = AnalyticsConstants.Request.REQUEST_STRING_PREFIX
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
