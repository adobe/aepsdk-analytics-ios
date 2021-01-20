/*
 Copyright 2021 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0
 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import AEPCore

/// Builds a version string for Analytics.
extension Analytics {

    /// Builds a version string to be used for Analytics pings.
    /// - Returns a `String` containing the Analytics version.
    func getVersion() -> String {
        return String(getOSType() + AnalyticsConstants.WRAPPER_TYPE + getFormattedAnalyticsVersion() + getFormattedMobileCoreVersion())
    }

    /// Determines which OS is present on the device and returns the
    /// appropriate OS type string.
    /// - Returns a `String` containing the device's OS type.
    private func getOSType() -> String {
        #if os(iOS)
            return "IOS"
        #elseif os(tvOS)
            return "TOS"
        #else
            return "WOS"
        #endif
    }

    /// Creates a zero padded representation of the Analytics extension version.
    /// - Returns a `String` containing a zero padded representation of the Analytics version.
    private func getFormattedAnalyticsVersion() -> String {
        var formattedVersionString = String()
        let analyticsVersionArray = Analytics.extensionVersion.components(separatedBy: ".")
        for version in analyticsVersionArray {
            if version.count == 2 {
                formattedVersionString.append(version)
            } else {
                formattedVersionString.append("0" + version)
            }
        }
        return formattedVersionString
    }

    /// Creates a zero padded representation of the Core extension version.
    /// - Returns a `String` containing a zero padded representation of the Analytics version.
    private func getFormattedMobileCoreVersion() -> String {
        var formattedVersionString = String()
        let mobileCoreVersionArray = MobileCore.extensionVersion.components(separatedBy: ".")
        for version in mobileCoreVersionArray {
            if version.count == 2 {
                formattedVersionString.append(version)
            } else {
                formattedVersionString.append("0" + version)
            }
        }
        return formattedVersionString
    }
}