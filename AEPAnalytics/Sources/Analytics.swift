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

/// Analytics extension for the Adobe Experience Platform SDK
@objc(AEPMobileAnalytics)
public class Analytics: NSObject, Extension {
    public let runtime: ExtensionRuntime

    public let name = AnalyticsConstants.EXTENSION_NAME
    public let friendlyName = AnalyticsConstants.FRIENDLY_NAME
    public static let extensionVersion = AnalyticsConstants.EXTENSION_VERSION
    public let metadata: [String: String]? = nil

    // MARK: Extension

    public required init(runtime: ExtensionRuntime) {
        self.runtime = runtime
        super.init()
    }

    /// Invoked when the `EventHub` has successfully registered the Analytics extension.
    public func onRegistered() {}

    public func onUnregistered() {}

    public func readyForEvent(_ event: Event) -> Bool {
        return true
    }

    // MARK: Event Listeners
}
