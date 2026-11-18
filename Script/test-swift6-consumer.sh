#!/bin/bash

set -e # Any subsequent(*) commands which fail will cause the shell script to exit immediately

# Builds a minimal Swift 6 consumer of AEPAnalytics to continuously protect the
# @Sendable / @preconcurrency public completion-handler contract.
#
# The consumer calls Analytics.getQueueSize, Analytics.getTrackingIdentifier and
# Analytics.getVisitorIdentifier with *plain* closures from @MainActor code.
# Because the public completions are declared @Sendable, the compiler must accept
# these calls from a main-actor context without inferring main-actor isolation on
# the closure (the inference that causes the libdispatch "expected on main queue"
# crash at runtime). If the @Sendable annotation were dropped, this Swift 6 build
# would fail.

PROJECT_NAME=Swift6Consumer

# Clean up.
rm -rf $PROJECT_NAME

mkdir -p $PROJECT_NAME && cd $PROJECT_NAME

# Create the package.
swift package init

# Create the Package.swift. The consumer target is compiled in Swift 6 language
# mode; dependencies keep their own declared language modes.
echo "// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription
let package = Package(
    name: \"Swift6Consumer\",
    defaultLocalization: \"en-US\",
    platforms: [
        .iOS(.v15), .tvOS(.v15)
    ],
    products: [
        .library(
            name: \"Swift6Consumer\",
            targets: [\"Swift6Consumer\"]
        )
    ],
    dependencies: [
        .package(name: \"AEPCore\", url: \"https://github.com/adobe/aepsdk-core-ios.git\", .branch(\"main\")),
        .package(name: \"AEPAnalytics\", path: \"../\")
    ],
    targets: [
        .target(
            name: \"Swift6Consumer\",
            dependencies: [
                .product(name: \"AEPCore\", package: \"AEPCore\"),
                .product(name: \"AEPServices\", package: \"AEPCore\"),
                .product(name: \"AEPAnalytics\", package: \"AEPAnalytics\"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ])
    ]
)
" >Package.swift

# Replace the generated source with a @MainActor consumer that exercises the
# public completion-handler APIs with plain (non-@Sendable-annotated) closures.
rm -rf Sources/Swift6Consumer
mkdir -p Sources/Swift6Consumer
echo "import AEPAnalytics
import Foundation

@MainActor
final class Swift6Consumer {
    var lastQueueSize = 0
    var lastTrackingIdentifier: String?
    var lastVisitorIdentifier: String?
    var lastError: Error?

    func exercise() {
        // Plain closures from @MainActor code: compile only because the public
        // completions are @Sendable. Each covers the success and error/timeout
        // paths, then hands UI work to the main actor.
        Analytics.getQueueSize { size, error in
            Task { @MainActor in
                self.lastQueueSize = size
                self.lastError = error
            }
        }

        Analytics.getTrackingIdentifier { identifier, error in
            Task { @MainActor in
                self.lastTrackingIdentifier = identifier
                self.lastError = error
            }
        }

        Analytics.getVisitorIdentifier { identifier, error in
            Task { @MainActor in
                self.lastVisitorIdentifier = identifier
                self.lastError = error
            }
        }
    }
}
" >Sources/Swift6Consumer/Swift6Consumer.swift

swift package update
swift package resolve

# This is necessary to avoid internal PIF error
swift package dump-pif > /dev/null
(xcodebuild clean -scheme Swift6Consumer -destination 'generic/platform=iOS' > /dev/null) || :

# Build for generic iOS device in Swift 6 language mode
echo '############# Build Swift 6 consumer for generic iOS device ###############'
xcodebuild build -scheme Swift6Consumer -destination 'generic/platform=iOS'

# Build for generic tvOS device in Swift 6 language mode
echo '############# Build Swift 6 consumer for generic tvOS device ###############'
xcodebuild build -scheme Swift6Consumer -destination 'generic/platform=tvOS'

# Clean up.
cd ../
rm -rf $PROJECT_NAME
