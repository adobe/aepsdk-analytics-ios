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

extension URL {
    private static let LOG_TAG = "URL+Analytics"

    private static let version = AnalyticsVersion.getVersion()
    private static let analyticsSerializer = AnalyticsRequestSerializer()

    /// Creates and returns the base url for analytics requests.
    /// - Returns: the base URL for analytics requests.
    /// - Parameters:
    ///   - state: the analytics state
    static func getAnalyticsBaseUrl(state: AnalyticsState) -> URL? {
        guard state.isAnalyticsConfigured() else {
            return nil
        }

        var urlComponent = URLComponents()
        urlComponent.scheme = "https"
        urlComponent.host = state.host
        urlComponent.path = "/b/ss/\(state.rsids ?? "")/\(getAnalyticsResponseType(state: state))/\(version)/s"
        guard let url = urlComponent.url else {
            Log.debug(label: LOG_TAG, "Error in creating Analytics base URL.")
            return nil
        }
        return url
    }

    /// Creates a new Analytics ID Request URL
    /// - Returns: the analytics ID request URL
    /// - Parameters:
    ///   - state: the analytics state
    static func getAnalyticsIdRequestURL(state: AnalyticsState) -> URL? {
        guard state.host != nil else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = state.host
        components.path = "/id"
        components.queryItems = getMarketingCloudIdQueryParameters(state: state)

        guard let url = components.url else {
            Log.error(label: LOG_TAG, "getAnalyticsIdRequestURL - Building Analytics Identity Request URL failed, returning nil.")
            return nil
        }
        return url
    }

    /// Build analytics payload from analytics context data and vars
    /// - Returns: the payload sent in analytics requests
    /// - Parameters:
    ///   - state: the analytics state
    ///   - data : dictionary containing analytics context data
    ///   - vars : dictionary containing analytics vars
    static func buildAnalyticsPayload(analyticsState: AnalyticsState, data: [String: String]?, vars: [String: String]?) -> String {
        return analyticsSerializer.buildRequest(analyticsState: analyticsState, data: data, vars: vars)
    }

    /// Append context data to analytics payload
    /// - Returns: the payload with contextData appended
    /// - Parameters:
    ///   - contextData: Dictionary containing context data
    ///   - payload: String representing analytics payload
    static func appendContextDataToAnalyticsPayload(contextData: [String: String]?, payload: String) -> String {
        return ContextDataUtil.appendContextData(contextData: contextData, source: payload)
    }

    /// Generates query string to be appended in analytics requests for custom ids from Identity extension
    /// - Returns: the query string representing custom ids
    /// - Parameters:
    ///   - visitorIDArray: Dictionary containing information about custom identifiers
    static func generateAnalyticsCustomerIdString(from visitorIDArray: [[String: Any]]?) -> String {
        return analyticsSerializer.generateAnalyticsCustomerIdString(from: visitorIDArray)
    }

    /// Returns the response type for analytics request url on basis of whether aam forwarding is enabled or not.
    /// - Returns: 10 if aam forwarding is enabled in configuration else returns 0
    private static func getAnalyticsResponseType(state: AnalyticsState) -> String {
        return state.analyticForwardingEnabled ? "10" : "0"
    }

    private static func getMarketingCloudIdQueryParameters(state: AnalyticsState) -> [URLQueryItem] {
        var queryItems: [URLQueryItem] = []
        guard let marketingCloudId = state.marketingCloudId else {
            Log.debug(label: LOG_TAG, "getMarketingCloudIdQueryParameters - Experience Cloud ID is nil, no query items to return.")
            return queryItems
        }

        queryItems += [URLQueryItem(name: AnalyticsConstants.ParameterKeys.KEY_ORG, value: state.marketingCloudOrganizationId)]
        queryItems += [URLQueryItem(name: AnalyticsConstants.ParameterKeys.KEY_MID, value: marketingCloudId)]

        return queryItems
    }
}
