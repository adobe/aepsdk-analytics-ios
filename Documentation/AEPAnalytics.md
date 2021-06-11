
- [Getting Started](#getting-started)
  * [Set up a Mobile Property](#set-up-a-mobile-property)
  * [Get the Swift Mobile Analytics](#get-the-swift-mobile-analytics)
  * [Initial SDK Setup](#initial-sdk-setup)
- [Analytics API reference](#analytics-api-reference)
  * [extensionVersion](#extensionversion)
  * [clearQueue](#clearqueue)
  * [getQueueSize](#getqueuesize)
  * [sendQueuedHits](#sendqueuedhits)
  * [getTrackingIdentifier](#gettrackingidentifier)
  * [setVisitorIdentifier](#setvisitoridentifier)
  * [getVisitorIdentifier](#getvisitoridentifier)
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
  [AEPMobileCore setLogLevel: AEPLogLevelTrace];
    
  [AEPMobileCore registerExtensions:@[AEPMobileAnalytics.class, AEPMobileIdentity.class] completion:^{
  // Use the App id assigned to this application via Adobe Launch
  [AEPMobileCore configureWithAppId:@"appId"];
   }];
   return YES;
}
```




# Analytics API reference

This section details all the APIs provided by AEPAnalytics, along with sample code snippets on how to properly use the APIs.

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



## clearQueue

Clears all hits from the tracking queue and removes them from the database.

**Warning:** Use caution when manually clearing the queue. This process cannot be reversed.

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



## getQueueSize

Retrieves the total number of Analytics hits in the tracking queue.

**Syntax**

```swift
static func getQueueSize(completion: @escaping (Int, Error?) -> Void)
```

**Examples**

**Swift**

```swift
Analytics.getQueueSize { (queueSize, _) in
    // handle queue size 
}
```

**Objective-C**

```objectivec
[AEPMobileAnalytics getQueueSize:^(NSInteger queueSize, NSError * _Nullable error) {
    //  queue size
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

ℹ️ Before use this API, see [Identify unique visitors](https://experienceleague.adobe.com/docs/analytics/components/metrics/unique-visitors.html?lang=en).

Retrieves the Analytics tracking identifier that is generated for this app/device instance. This identifier is an app-specific, unique visitor ID that is generated at the initial launch and is stored and used after the initial launch. The ID is preserved between app upgrades and is removed when the app is uninstalled.

⚠️ If you have an [Experience Cloud ID](https://app.gitbook.com/@aep-sdks/s/docs/using-mobile-extensions/mobile-core/identity/identity-api-reference#get-experience-cloud-ids), and have not yet configured a visitor ID grace period, the value returned by `getTrackingIdentifier` might be null.

**Syntax**

```swift
 static func getTrackingIdentifier(completion: @escaping (String?, Error?) -> Void)
```

**Examples**

**Swift**

```swift
Analytics.getTrackingIdentifier { (trackingId, _) in
   // check the trackingIdentifier value  
}
```

**Objective-C**

```objectivec
AEPMobileAnalytics getTrackingIdentifier:^(NSString * _Nullable trackingIdentifier, NSError * _Nullable error) {
   // check the trackingIdentifier value  
}];
```



## setVisitorIdentifier

ℹ️ Before use this API, see [Identify unique visitors](https://experienceleague.adobe.com/docs/analytics/components/metrics/unique-visitors.html?lang=en).
Sets a custom Analytics visitor identifier

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



## getVisitorIdentifier

ℹ️ Before use this API, see [Identify unique visitors](https://experienceleague.adobe.com/docs/analytics/components/metrics/unique-visitors.html?lang=en).

This API gets a custom Analytics visitor identifier, which has been set previously using [setVisitorIdentifier](#setvisitoridentifier).

**Syntax**

```swift
static func getVisitorIdentifier(completion: @escaping (String?, Error?) -> Void)
```

**Examples**

**Swift**

```swift
Analytics.getVisitorIdentifier { (visitorId, _) in
   // check the visitorIdentifier value or handle error
}
```

**Objective-C**

```objectivec
[AEPMobileAnalytics getVisitorIdentifier:^(NSString * _Nullable visitorIdentifier, NSError * _Nullable error) {
    // check the visitorIdentifier value or handle error
}];
```



# Related Project

## AEP SDK Compatibility for iOS

| Project                                                      | Description                                                  |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| [AEP SDK Compatibility for iOS](https://github.com/adobe/aepsdk-compatibility-ios) | Contains code that bridges `ACPAnalytics` implementations into the AEP SDK runtime. |

