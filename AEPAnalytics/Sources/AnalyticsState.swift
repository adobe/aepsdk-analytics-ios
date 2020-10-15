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

import AEPCore
import AEPServices
import Foundation

class AnalyticsState {
    
    private let LOG_TAG = "AnalyticsState"
    
//    std::shared_ptr<AnalyticsRequestSerializer> request_serializer_; // TODO
    
    // MARK: BEGIN: Use the defaults value from Analytics constants for variables declared below
    var analyticForwardingEnabled: Bool = false

    var offlineEnabled: Bool = false
    
    var batchLimit: Int32 = 0
    
    var privacyStatus: PrivacyStatus = PrivacyStatus.unknown
    
    var launchHitDelay: Date = Date.init()
    
    var backDateSessionInfoEnabled: Bool = false
    
    var marketingCloudOrganizationId: String = ""
    
    var rsids: String = ""
    
    var host: String = ""
    
    var marketingCloudId: String = ""
    
    var locationHint: String = ""
    
    var blob: String = ""
    
    var serializedVisitorIdsList: String = ""
    
    var applicationId: String = ""
    
    var advertisingId: String = ""
    
    var assuranceSessionActive: Bool = false
    
    var lifecycleMaxSessionLength: Date = Date.init()
    
    var lifecycleSessionStartTimestamp: Date = Date.init()
    
    // MARK: END: Use the defaults value from Analytics constants for variables declared below
    
    var defaultData: [String: String]?
    
    init(dataMap: [String: [String: Any]]) {
        
        for key in dataMap.keys {
            
            switch key {
            // MARK: TODO replace all the placeholder strings in case values with the corresponding shared state name in AnalyticsConstants.
            case "configuration shared state name":
                extractConfigurationInfo(from: dataMap[key])
                break
            case "lifecycle shared state name":
                extractLifecycleInfo(from: dataMap[key])
                break
            case "identity shared state name":
                extractIdentityInfo(from: dataMap[key])
                break
            case "places shared state name":
                extractPlacesInfo(from: dataMap[key])
                break
            case "assurance shared state name":
                extractAssuranceInfo(from: dataMap[key])
                break
            default:
                break
            }
        }
    }
    
    func extractConfigurationInfo(from data: [String: Any]?) -> Void {
        
        guard let configurationData = data else{
            Log.trace(label: LOG_TAG, "ExtractConfigurationInfo - Failed to extract configuration data (event data was null).")
            return
        }
        
        // MARK: Replace the placeholders keys with values in AnalyticsConstants.
        host = configurationData["placeholder for ANALYTICS_SERVER"] as? String ?? "placeholder default value"
        rsids = configurationData["placeholder for ANALYTICS_REPORT_SUITES"] as? String ?? "placeholder default value"
        analyticForwardingEnabled = configurationData["placeholder for ANALYTICS_AAMForwarding"] as? Bool ?? false
        offlineEnabled = configurationData["placeholder for ANALYTICS_OFFLINE_TRACKING"] as? Bool ?? false
        batchLimit = configurationData["placeholder for ANALYTICS_BATCH_LIMIT"] as? Int32 ?? 0
        launchHitDelay = Date.init(timeIntervalSince1970: TimeInterval.init(configurationData["placeholder for ANALYTICS_BATCH_LIMIT"] as? Double ?? 0))
        marketingCloudOrganizationId = configurationData["placeholder for marketingCloudOrganizationId"] as? String ?? ""
        backDateSessionInfoEnabled = configurationData["placeholder for backDateSessionInfoEnabled"] as? Bool ?? false
        privacyStatus = PrivacyStatus.init(rawValue: configurationData["placeholder for privacy status"] as? PrivacyStatus.RawValue ?? PrivacyStatus.unknown.rawValue) ?? PrivacyStatus.unknown
    }
    
    func extractLifecycleInfo(from data: [String: Any]?) -> Void {
        
    }
    
    func extractIdentityInfo(from data: [String: Any]?) -> Void {
        
    }
    
    func extractPlacesInfo(from data: [String: Any]?) -> Void {
        
    }
    
    func extractAssuranceInfo(from data: [String: Any]?) -> Void {
        
    }
}
