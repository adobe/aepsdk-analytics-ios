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
    
    private let analyticsRequestSerializer = AnalyticsRequestSerializer()
    
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
    
    private(set) var marketingCloudId: String = ""
    
    private var locationHint: String = ""
    
    private var blob: String = ""
    
    private(set) var serializedVisitorIdsList: String = ""
    
    var applicationId: String = ""
    
    private(set) var advertisingId: String = ""
    
    private(set) var assuranceSessionActive: Bool = false
    
    private(set) var lifecycleMaxSessionLength: Date = Date.init()
    
    private(set) var lifecycleSessionStartTimestamp: Date = Date.init()
    
    // MARK: END: Use the defaults value from Analytics constants for variables declared below
    
    private(set) var defaultData: [String: String] = [String: String]()
    
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
    
    func extractConfigurationInfo(from configurationData: [String: Any]?) -> Void {
        
        guard let configurationData = configurationData else {
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
    
    func extractLifecycleInfo(from lifecycleData: [String: Any]?) -> Void {
        
        guard let lifecycleData = lifecycleData else {
            Log.trace(label: LOG_TAG, "ExtractLifecycleInfo - Failed to extract lifecycle data (event data was null).")
            return
        }
        
        
        if let lifecycleSessionStartTime = lifecycleData[""] as? TimeInterval {
            lifecycleSessionStartTimestamp = Date.init(timeIntervalSince1970: lifecycleSessionStartTime)
        }
        
        if let lifecycleMaxSessionLen = lifecycleData[""] as? TimeInterval {
            lifecycleMaxSessionLength = Date.init(timeIntervalSince1970: lifecycleMaxSessionLen)
        }
        
        if let lifecyleContextData = lifecycleData["lifecycle context data"] as? [String: String] {
                        
            if let operatingSystem = lifecyleContextData["operating system"] {
                defaultData["operating system"] = operatingSystem
            }
            
            if let deviceName = lifecyleContextData["device name"] {
                defaultData["device name"] = deviceName
            }
            
            if let deviceResolution = lifecyleContextData["device resolution"] {
                defaultData["device resolution"] = deviceResolution
            }
            
            if let carrierName = lifecyleContextData["carrier name"] {
                defaultData["carrier name"] = carrierName
            }
            
            if let runMode = lifecyleContextData["run mode"] {
                defaultData["run mode"] = runMode
            }
            
            if let applicationId = lifecyleContextData["application id"] {
                defaultData["application id"] = applicationId
            }
        }
    }
    
    func extractIdentityInfo(from identityData: [String: Any]?) -> Void {
         
        guard let identityData = identityData else {
            Log.trace(label: LOG_TAG, "ExtractIdentityInfo - Failed to extract identity data (event data was null).")
            return
        }
        
        if let marketingCloudId = identityData["visitor id mid"] as? String {
            self.marketingCloudId = marketingCloudId
        }
        
        if let blob = identityData["visitor id blob"] as? String {
            self.blob = blob
        }
        
        if let locationHint = identityData["visitor id location hint"] as? String {
            self.locationHint = locationHint
        }
        
        if let advertisingId = identityData["visitor id advertising id"] as? String {
            self.advertisingId = advertisingId
        }
                
        if let visitorIdArray = identityData["Visitor id array key"] as? [String] {
            // MARK: TODO:: Implement the serialization part
//            serializedVisitorIdsList = requestSerailizar.generateSerailizedVisitorIdList()
        }
    }
    
    func extractPlacesInfo(from placesData: [String: Any]?) -> Void {
        guard let placesData = placesData else {
            Log.trace(label: LOG_TAG, "ExtractPlacesInfo - Failed to extract places data (event data was null).")
            return
        }
        
        if let placesContextData = placesData["current poi key"] as? [String: String] {
            
            if let regionId = placesContextData["region id key"] {
                defaultData["region id"] = regionId
            }
            
            if let regionName = placesContextData["region name"] {
                defaultData["region name"] = regionName
            }
        }
    }
    
    func extractAssuranceInfo(from assuranceData: [String: Any]?) -> Void {
        
        guard let assuranceData = assuranceData else {
            Log.trace(label: LOG_TAG, "ExtractAssuranceInfo - Failed to extract Assurance data (event data was null).")
            return
        }
        
        if let assuranceSessionId = assuranceData["assurance session id"] as? String {
            assuranceSessionActive = !assuranceSessionId.isEmpty
        }
    }
    
    func getAnalyticsIdVisitorParameters() -> [String: String] {
        
        var analyticsIdVisitorParameters = [String: String]()
        
        guard !marketingCloudId.isEmpty else {
            return analyticsIdVisitorParameters
        }
                
        analyticsIdVisitorParameters["ANALYTICS_PARAMETER_KEY_MID"] = marketingCloudId
                
        if !blob.isEmpty {
            analyticsIdVisitorParameters["ANALYTICS_PARAMETER_KEY_Blob"] = blob
        }
        
        if !locationHint.isEmpty {
            analyticsIdVisitorParameters["ANALYTICS_PARAMETER_Location_hint"] = locationHint
        }
                        
        return analyticsIdVisitorParameters
    }
    
    func isAnalyticsConfigured() -> Bool {
        return !rsids.isEmpty && !host.isEmpty
    }
    
    func getBaseUrl(sdkVersion: String) -> URL? {

        var urlComponent = URLComponents()
        urlComponent.scheme = "https"
        urlComponent.host = host
        urlComponent.path = "\\b\\ss\\\(rsids)\\\(getAnalyticsResponseType())\\\(sdkVersion)\\s"
        guard let url = urlComponent.url else {
            Log.debug(label: LOG_TAG, "Error in creating Analytics base URL.")
            return nil
        }
        return url
    }
    
    func isVisistorIdServiceEnabled() -> Bool {
        return !marketingCloudOrganizationId.isEmpty
    }
    
    func getAnalyticsResponseType() -> String {
        return analyticForwardingEnabled ? "10" : "0"
    }
    
    func isOptIn() -> Bool {
        return privacyStatus == PrivacyStatus.optedIn
    }
}
