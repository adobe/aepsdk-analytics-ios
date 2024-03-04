# Adobe Experience Platform Analytics SDK

[![CocoaPods](https://img.shields.io/github/v/release/adobe/aepsdk-analytics-ios?label=CocoaPods&logo=apple&logoColor=white&color=orange)](https://cocoapods.org/pods/AEPAnalytics) 
[![SPM](https://img.shields.io/github/v/release/adobe/aepsdk-analytics-ios?label=SPM&logo=apple&logoColor=white&color=orange)](https://github.com/adobe/aepsdk-analytics-ios/releases) 
[![CircleCI](https://img.shields.io/circleci/project/github/adobe/aepsdk-analytics-ios/main.svg?logo=circleci&label=Build)](https://circleci.com/gh/adobe/workflows/aepsdk-analytics-ios) 
[![Code Coverage](https://img.shields.io/codecov/c/github/adobe/aepsdk-analytics-ios/main.svg?logo=codecov&label=Coverage)](https://codecov.io/gh/adobe/aepsdk-analytics-ios/branch/main)

## About this project

The AEPAnalytics extension enables sending mobile application interaction data to Adobe Analytics when using the [Adobe Experience Platform SDK](https://developer.adobe.com/client-sdks).

## Requirements
- Xcode 15
- Swift 5.1

## Installation
These are currently the supported installation options:

### [CocoaPods](https://guides.cocoapods.org/using/using-cocoapods.html)
```ruby
# Podfile
use_frameworks!

# For app development, include all the following pods
target 'YOUR_TARGET_NAME' do
    pod 'AEPAnalytics'
    pod 'AEPCore'
    pod 'AEPIdentity'
end

# For extension development, include AEPAnalytics and its dependencies
target 'YOUR_TARGET_NAME' do
    pod 'AEPAnalytics'
    pod 'AEPCore'
end
```

Replace `YOUR_TARGET_NAME` and then, in the `Podfile` directory, type:

```bash
$ pod install
```

### [Swift Package Manager](https://github.com/apple/swift-package-manager)

To add the AEPAnalytics Package to your application, from the Xcode menu select:

`File > Add Packages...`

> **Note** 
> The menu options may vary depending on the version of Xcode being used.

Enter the URL for the AEPAnalytics package repository: `https://github.com/adobe/aepsdk-analytics-ios.git`.

When prompted, input a specific version or a range of versions for Version rule.

Alternatively, if your project has a `Package.swift` file, you can add AEPAnalytics directly to your dependencies:

```
dependencies: [
    .package(url: "https://github.com/adobe/aepsdk-analytics-ios.git", .upToNextMajor(from: "5.0.0"))
]
```

### Project Reference

Include `AEPAnalytics.xcodeproj` in the targeted Xcode project and link all necessary libraries to your app target.

### Binaries

Run `make archive` from the root directory to generate `.xcframeworks` for each module under the `build` folder. Drag and drop all `.xcframeworks` to your app target in Xcode.

## Documentation

Additional documentation for usage and SDK architecture can be found under the [Documentation](Documentation) directory.

## Contributing

Contributions are welcomed! Read the [Contributing Guide](./.github/CONTRIBUTING.md) for more information.

## Licensing

This project is licensed under the Apache V2 License. See [LICENSE](LICENSE) for more information.
