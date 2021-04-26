// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.
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

import PackageDescription

let package = Package(
    name: "AEPAnalytics",
    platforms: [.iOS(.v10)],
    products: [
        // default
        .library(name: "AEPAnalytics", targets: ["AEPAnalytics"]),
        // dynamic
        .library(name: "AEPAnalyticsDynamic", type: .dynamic, targets: ["AEPAnalytics"]),
        // static
        .library(name: "AEPAnalyticsStatic", type: .static, targets: ["AEPAnalytics"]),
    ],
    dependencies: [
        .package(url: "https://github.com/adobe/aepsdk-core-ios.git", from: "3.0.0"),
    ],
    targets: [
        .target(name: "AEPAnalytics",
                dependencies: ["AEPCore", .product(name: "AEPServices", package: "AEPCore")],
                path: "AEPAnalytics/Sources"),
        .target(name: "AEPAnalyticsTests",
                dependencies: ["AEPAnalytics", "AEPCore", .product(name: "AEPServices", package: "AEPCore")],
                path: "AEPAnalytics/Tests"),
    ]
)
