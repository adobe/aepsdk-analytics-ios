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
import AEPIdentity
import Foundation

/// This class encapsulates the analytics config properties used across the analytics handlers.
/// These properties are retrieved from the shared states.
class AnalyticsState {
    
    private let LOG_TAG = "AnalyticsState"
    
    /// Instance of AnalyticsRequestSerializer, use to serialize visitor id's.
    private let analyticsRequestSerializer = AnalyticsRequestSerializer()
    
    var analyticForwardingEnabled: Bool = AnalyticsConstants.Default.DEFAULT_FORWARDING_ENABLED

    var offlineEnabled: Bool = AnalyticsConstants.Default.DEFAULT_OFFLINE_ENABLED
    
    var batchLimit: Int = AnalyticsConstants.Default.DEFAULT_BATCH_LIMIT
    
    var privacyStatus: PrivacyStatus = AnalyticsConstants.Default.DEFAULT_PRIVACY_STATUS
    
    var launchHitDelay: Date = AnalyticsConstants.Default.DEFAULT_LAUNCH_HIT_DELAY
    
    var backDateSessionInfoEnabled: Bool = AnalyticsConstants.Default.DEFAULT_BACKDATE_SESSION_INFO_ENABLED
    
    var marketingCloudOrganizationId: String?
    
    var rsids: String?
    
    var host: String?
    
    private(set) var marketingCloudId: String?
    
    private var locationHint: String?
    
    private var blob: String?
    
    private(set) var serializedVisitorIdsList: String?
    
    var applicationId: String?
    
    private(set) var advertisingId: String?
    
    private(set) var assuranceSessionActive: Bool?
    
    private(set) var lifecycleMaxSessionLength: Date = AnalyticsConstants.Default.DEFAULT_LIFECYCLE_MAX_SESSION_LENGTH
    
    private(set) var lifecycleSessionStartTimestamp: Date = AnalyticsConstants.Default.DEFAULT_LIFECYCLE_SESSION_START_TIMESTAMP
    
    private(set) var defaultData: [String: String] = [String: String]()
    
    init(dataMap: [String: [String: Any]]) {
        
        for key in dataMap.keys {
            
            switch key {            
            case AnalyticsConstants.Configuration.EventDataKeys.SHARED_STATE_NAME:
                extractConfigurationInfo(from: dataMap[key])
                break
            case AnalyticsConstants.Lifecycle.EventDataKeys.SHARED_STATE_NAME:
                extractLifecycleInfo(from: dataMap[key])
                break
            case AnalyticsConstants.Identity.EventDataKeys.SHARED_STATE_NAME:
                extractIdentityInfo(from: dataMap[key])
                break
            case AnalyticsConstants.Places.EventDataKeys.SHARED_STATE_NAME:
                extractPlacesInfo(from: dataMap[key])
                break
            case AnalyticsConstants.Assurance.EventDataKeys.SHARED_STATE_NAME:
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
        
        host = configurationData[AnalyticsConstants.Configuration.EventDataKeys.ANALYTICS_SERVER] as? String ?? "placeholder default value"
        rsids = configurationData[AnalyticsConstants.Configuration.EventDataKeys.ANALYTICS_REPORT_SUITES] as? String ?? "placeholder default value"
        analyticForwardingEnabled = configurationData[AnalyticsConstants.Configuration.EventDataKeys.ANALYTICS_AAMFORWARDING] as? Bool ?? false
        offlineEnabled = configurationData[AnalyticsConstants.Configuration.EventDataKeys.ANALYTICS_OFFLINE_TRACKING] as? Bool ?? false
        batchLimit = configurationData[AnalyticsConstants.Configuration.EventDataKeys.ANALYTICS_BATCH_LIMIT] as? Int ?? 0
        launchHitDelay = Date.init(timeIntervalSince1970: TimeInterval.init(configurationData[AnalyticsConstants.Configuration.EventDataKeys.ANALYTICS_LAUNCH_HIT_DELAY] as? Double ?? 0))
        marketingCloudOrganizationId = configurationData[AnalyticsConstants.Configuration.EventDataKeys.MARKETING_CLOUD_ORGID_KEY] as? String ?? ""
        backDateSessionInfoEnabled = configurationData[AnalyticsConstants.Configuration.EventDataKeys.ANALYTICS_BACKDATE_PREVIOUS_SESSION] as? Bool ?? false
        privacyStatus = PrivacyStatus.init(rawValue: configurationData[AnalyticsConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY] as? PrivacyStatus.RawValue ?? PrivacyStatus.unknown.rawValue) ?? PrivacyStatus.unknown
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
                   
        if let identifiableArray = identityData["Visitor id array key"] as? [Identifiable] {
            serializedVisitorIdsList = analyticsRequestSerializer.generateAnalyticsCustomerIdString(from: identifiableArray)
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
        
        guard let marketingCloudId = marketingCloudId, !marketingCloudId.isEmpty else {
            return analyticsIdVisitorParameters
        }
                
        analyticsIdVisitorParameters["ANALYTICS_PARAMETER_KEY_MID"] = marketingCloudId
                
        if let blob = blob, !blob.isEmpty {
            analyticsIdVisitorParameters["ANALYTICS_PARAMETER_KEY_Blob"] = blob
        }
        
        if let locationHint = locationHint, !locationHint.isEmpty {
            analyticsIdVisitorParameters["ANALYTICS_PARAMETER_Location_hint"] = locationHint
        }
                        
        return analyticsIdVisitorParameters
    }
    
    func isAnalyticsConfigured() -> Bool {
        guard let rsids = rsids, let host = host else {
            return false
        }
        return !rsids.isEmpty && !host.isEmpty
    }
    
    func getBaseUrl(sdkVersion: String) -> URL? {

        var urlComponent = URLComponents()
        urlComponent.scheme = "https"
        urlComponent.host = host
        urlComponent.path = "\\b\\ss\\\(String(describing:rsids))\\\(getAnalyticsResponseType())\\\(sdkVersion)\\s"
        guard let url = urlComponent.url else {
            Log.debug(label: LOG_TAG, "Error in creating Analytics base URL.")
            return nil
        }
        return url
    }
    
    func isVisistorIdServiceEnabled() -> Bool {
        guard let marketingCloudOrganizationId = marketingCloudOrganizationId else {
            return false
        }
        return !marketingCloudOrganizationId.isEmpty
    }
    
    func getAnalyticsResponseType() -> String {
        return analyticForwardingEnabled ? "10" : "0"
    }
    
    func isOptIn() -> Bool {        
        return privacyStatus == PrivacyStatus.optedIn
    }
}
