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

    /// Returns the built Analytics version string.
    /// - Returns a `String` containing the built Analytics version string.
    internal func getVersion() -> String {
        let builtVersionString = buildVersionString(osType: getOSType(), analyticsVersion: Analytics.extensionVersion, coreVersion: MobileCore.extensionVersion)
        return builtVersionString
    }

    /// Builds a version string to be used for Analytics pings.
    /// - Returns a `String` containing the built Analytics version string.
    internal func buildVersionString(osType: String, analyticsVersion: String, coreVersion: String) -> String {
        var wrapperType = String()
        // split core version into version number and wrapper type if possible
        let coreVersionComponents = coreVersion.components(separatedBy: "-")
        if coreVersionComponents.count == 2 {
            wrapperType = coreVersionComponents[1]
        } else {
            wrapperType = WrapperType.none.rawValue
        }
        return "\(osType)\(wrapperType)\(getFormattedExtensionVersion(analyticsVersion))\(getFormattedExtensionVersion(coreVersionComponents[0]))"
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

    /// Creates a zero padded representation from the provided extension version.
    /// - Returns a `String` containing a zero padded representation of the provided version.
    private func getFormattedExtensionVersion(_ version: String) -> String {
        var formattedVersionString = String()
        let versionArray = version.components(separatedBy: ".")
        if versionArray.count == 3 {
            for versionComponent in versionArray {
                if versionComponent.count == 2 {
                    formattedVersionString.append(versionComponent)
                } else {
                    formattedVersionString.append("0" + versionComponent)
                }
            }
            return formattedVersionString
        } else {
            return "000000"
        }
    }
}
