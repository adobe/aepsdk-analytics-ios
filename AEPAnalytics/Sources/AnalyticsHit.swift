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
import Foundation

/// Struct which represents an Analytics hit
struct AnalyticsHit: Codable {
    /// URL to be requested for this Analytics hit
    let url: URL
    // TimeStamp to be requested for this Analytics hit
    let timestamp: TimeInterval
    // URL playload info
    let payload: String
//    // Analytics Host Info to be requested for this Analytics hit
    let host: URL
//    // offline tracking status
    let offlineTrackingEnabled: Bool
//    // audience forwarding status
    let aamForwardingEnabled: Bool
//    // Queue waiting status
    let isWaiting: Bool
//    // back dated status
    let isBackDatePlaceHolder: Bool
//    // Analytics event Identifier
    let uniqueEventIdentifier: String
}
