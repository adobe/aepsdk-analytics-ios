
- [Getting Started](#getting-started)
  * [Set up a Mobile Property](#set-up-a-mobile-property)
  * [Get the Swift Mobile Analytics](#get-the-swift-mobile-analytics)
  * [Initial SDK Setup](#initial-sdk-setup)
- [Analytics API reference](#analytics-api-reference)
  * [clearQueue](#clearqueue)
  * [extensionVersion](#extensionversion)
  * [getQueueSize](#getqueuesize)
  * [sendQueuedHits](#sendqueuedhits)
  * [getTrackingIdentifier](#gettrackingidentifier)
  * [getVisitorIdentifier](#getvisitoridentifier)
  * [setVisitorIdentifier](#setvisitoridentifier)
- [Related Project](#related-project)
  * [AEP SDK Compatibility for iOS](#aep-sdk-compatibility-for-ios)

# Getting Started

This section walks through how to get up and running with the AEP Swift Analytics SDK with only a few lines of code.

## Set up a Mobile Property

Set up a mobile property as outlined in the Adobe Experience Platform [docs](https://aep-sdks.gitbook.io/docs/getting-started/create-a-mobile-property)

## Get the Swift Mobile Analytics

Now that a Mobile Property is created, head over to the [install instructions](https://github.com/adobe/aepsdk-analytics-ios#installation) to install the SDK.

## Initial SDK Setup

**Swift**

1. Import each of the core extensions in the `AppDelegate` file:

```swift
import AEPCore
import AEPAnalytics
import AEPIdentity
```

2. Register the core extensions and configure the SDK with the assigned application identifier.
   To do this, add the following code to the Application Delegate's `application(_:didFinishLaunchingWithOptions:)` method:

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

 // Enable debug logging
 MobileCore.setLogLevel(level: .debug)

 MobileCore.registerExtensions([Analytics.self, Identity.self], {
 // Use the App id assigned to this application via Adobe Launch
 MobileCore.configureWith(appId: "appId") 
 })  
 return true
}
```

**Objective C**

1. Import each of the core extensions in the `AppDelegate` file:

```objective-c
@import AEPCore;
@import AEPAnalytics;
@import AEPIdentity;
```

2. Register the core extensions and configure the SDK with the assigned application identifier.
   To do this, add the following code to the Application Delegate's 
   `application didFinishLaunchingWithOptions:` method:

```objective-c
(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions

  // Enable debug logging
  [AEPMobileCore setLogLevel: AEPLogLevelDebug];
    
  [AEPMobileCore registerExtensions:@[AEPMobileAnalytics.class, AEPMobileIdentity.class] completion:^{
  // Use the App id assigned to this application via Adobe Launch
  [AEPMobileCore configureWithAppId:@"appId"];
   }];
   return YES;
}
```

### App Extension Support

If you are using AEPAnalytics from within an App Extension, make sure that you register the `AnalyticsAppExtension` class with MobileCore instead of the `Analytics` class. 

**Swift**

```swift
 MobileCore.registerExtensions([AnalyticsAppExtension.self, Identity.self], {
 // Use the App id assigned to this application via Adobe Launch
 MobileCore.configureWith(appId: "appId") 
 })  
```

**Objective C**

```objectivec
[AEPMobileCore registerExtensions:@[AEPMobileAnalyticsAppExtension.class, AEPMobileIdentity.class] completion:^{
// Use the App id assigned to this application via Adobe Launch
[AEPMobileCore configureWithAppId:@"appId"];
}];
```

# Analytics API reference

This section details all the APIs provided by AEPAnalytics, along with sample code snippets on how to properly use the APIs.

## clearQueue

Clears all hits from the tracking queue and removes them from the database.

**Warning:** Use caution when manually clearing the queue. This operation cannot be reverted.

**Syntax**

```swift
static func clearQueue()
```

**Examples**

**Swift**

```swift
Analytics.clearQueue()
```

**Objective-C**

```objectivec
[AEPMobileAnalytics clearQueue];
```



## extensionVersion

The `extensionVersion()` API returns the version of the Analytics extension that is registered with the Mobile Core extension.

**Examples**

**Swift**

```
let version = Analytics.extensionVersion
```

**Objective-C**

```
NSString *version = [AEPMobileAnalytics extensionVersion];
```



## getQueueSize

Retrieves the total number of Analytics hits in the tracking queue.

**Syntax**

```swift
static func getQueueSize(completion: @escaping (Int, Error?) -> Void)
```

**Examples**

**Swift**

```swift
Analytics.getQueueSize { (queueSize, error) in
    // Handle the error (if non-nil) or use queue size 
}
```

**Objective-C**

```objectivec
[AEPMobileAnalytics getQueueSize:^(NSInteger queueSize, NSError * _Nullable error) {
    // Handle the error (if non-nil) or use queue size 
 }];
```



## sendQueuedHits

Sends all queued hits in the offline queue to Analytics, regardless of the current hit batch settings.

**Syntax**

```swift
static func sendQueuedHits()
```

**Examples**

**Swift**

```swift
Analytics.sendQueuedHits()
```

**Objective-C**

```objectivec
[AEPMobileAnalytics sendQueueHits];
```



## getTrackingIdentifier

ℹ️ Before using this API, see [Identify unique visitors](https://experienceleague.adobe.com/docs/analytics/components/metrics/unique-visitors.html).

Retrieves the Analytics tracking identifier. The identifier is only returned for existing users who had AID persisted and migrated from earlier versions of SDK. For new users, no AID is generated and should instead use [Experience Cloud ID](https://aep-sdks.gitbook.io/docs/foundation-extensions/mobile-core/identity/identity-api-reference#getexperiencecloudid) to identify visitors.

**Syntax**

```swift
 static func getTrackingIdentifier(completion: @escaping (String?, Error?) -> Void)
```

**Examples**

**Swift**

```swift
Analytics.getTrackingIdentifier { (trackingIdentifier, error) in
   // Handle the error (if non-nil) or use the trackingIdentifier value.
}
```

**Objective-C**

```objectivec
AEPMobileAnalytics getTrackingIdentifier:^(NSString * _Nullable trackingIdentifier, NSError * _Nullable error) {
   // Handle the error (if non-nil) or use the trackingIdentifier value.
}];
```

## getVisitorIdentifier

ℹ️ Before use this API, see [Identify unique visitors](https://experienceleague.adobe.com/docs/analytics/components/metrics/unique-visitors.html).

This API gets a custom Analytics visitor identifier, which has been set previously using [setVisitorIdentifier](#setvisitoridentifier).

**Syntax**

```swift
static func getVisitorIdentifier(completion: @escaping (String?, Error?) -> Void)
```

**Examples**

**Swift**

```swift
Analytics.getVisitorIdentifier { (visitorIdentifier, error) in
   // Handle the error (if non-nil) or use the visitorIdentifier value
}
```

**Objective-C**

```objectivec
[AEPMobileAnalytics getVisitorIdentifier:^(NSString * _Nullable visitorIdentifier, NSError * _Nullable error) {
    // Handle the error (if non-nil) or use the visitorIdentifier value
}];
```

## setVisitorIdentifier

ℹ️ Before use this API, see [Identify unique visitors](https://experienceleague.adobe.com/docs/analytics/components/metrics/unique-visitors.html).

Sets a custom Analytics visitor identifier. For more information, see [Custom Visitor ID](https://experienceleague.adobe.com/docs/analytics/implementation/vars/config-vars/visitorid.html).

**Syntax**

```swift
static func setVisitorIdentifier(visitorIdentifier: String)
```

**Examples**

**Swift**

```swift
Analytics.setVisitorIdentifier(visitorIdentifier:"custom_identifier")
```

**Objective-C**

```objectivec
[AEPMobileAnalytics setVisitorIdentifier:@"custom_identifier"];
```

# Related Project

## AEP SDK Compatibility for iOS

| Project                                                      | Description                                                  |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| [AEP SDK Compatibility for iOS](https://github.com/adobe/aepsdk-compatibility-ios) | Contains code that bridges `ACPAnalytics` implementations into the AEP SDK runtime. |

