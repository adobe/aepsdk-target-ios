# Table of Contents
- [Table of Contents](#table-of-contents)
- [Target API reference](#target-api-reference)
  - [prefetchContent](#prefetchcontent)
  - [retrieveLocationContent](#retrievelocationcontent)
  - [setThirdPartyId](#setthirdpartyid)
  - [getThirdPartyId](#getthirdpartyid)
  - [setTntId](#settntid)
  - [getTntId](#gettntid)
  - [setSessionId](#setsessionid)
  - [getSessionId](#getsessionid)
  - [resetExperience](#resetexperience)
  - [clearPrefetchCache](#clearprefetchcache)
  - [setPreviewRestartDeepLink](#setpreviewrestartdeeplink)
  - [displayedLocations](#displayedlocations)
  - [clickedLocation](#clickedlocation)
- [Target Raw API reference](#target-raw-api-reference)
  - [executeRawRequest](#executerawrequest)
  - [sendRawNotification](#sendrawnotification)
- [Visual preview](#visual-preview)

# Target API reference
This document details all the APIs provided by Target, along with sample code snippets on how to properly use the APIs.

## prefetchContent
This API sends a prefetch request to your configured Target server with the prefetch objects array and the specified target parameters. 

### Swift

#### Syntax 

```swift
static func prefetchContent(_ prefetchArray: [TargetPrefetch], with targetParameters: TargetParameters? = nil, _ completion: ((Error?) -> Void)?)
static func prefetchContent(_ prefetchArray: [TargetPrefetch], with targetParameters: TargetParameters? = nil, timeout: TimeInterval, _ completion: ((Error?) -> Void)?)
```

  - *prefetchArray* - is an array of `TargetPrefetch` objects for various mbox locations.
  - *targetParameters* - is the configured `TargetParameters` for the prefetch request.
  - *timeout* - (optional) the maximum time in seconds to wait for the prefetch response. Defaults to 1 second when not specified.
  - If the prefetch is successful, `completion` is invoked with a nil value. If the prefetch is not successful, an error message is returned.

#### Example

```swift
        let TargetParameters1 = TargetParameters(
            parameters: ["status": "platinum"],
            profileParameters: ["age": "20"],
            order: TargetOrder(id: "ADCKKIM", total: 344.30, purchasedProductIds: ["34", "125"]),
            product: TargetProduct(productId: "24D3412", categoryId:"Books")
        )
            
        let TargetParameters2 = TargetParameters(
            parameters: ["userType": "Paid"],
            profileParameters: nil,
            order: TargetOrder(id: "ADCKKIM", total: 344.30, purchasedProductIds: ["id1", "id2"]),
            product: TargetProduct(productId: "764334", categoryId:"Online")
        )
        
        let globalTargetParameters = TargetParameters(
            parameters: ["status": "progressive"],
            profileParameters: ["age": "20-32"],
            order: TargetOrder(id: "ADCKKBC", total: 400.50, purchasedProductIds: ["34", "125"]),
            product: TargetProduct(productId: "24D334", categoryId:"Stationary")
        )
        Target.prefetchContent(
            [
                TargetPrefetch(name: "mboxName1", targetParameters: TargetParameters1),
                TargetPrefetch(name: "mboxName2", targetParameters: TargetParameters2),
            ],
            with: globalTargetParameters
        ){ error in
            // do something with the callback response
        }
```

### Objective C

#### Syntax 

```objectivec
+ (void) prefetchContent: (nonnull NSArray<AEPTargetPrefetchObject*>*) targetPrefetchObjectArray 
         withParameters: (nullable AEPTargetParameters*) targetParameters 
         callback: (nullable void (^) (NSError* _Nullable error)) completion;
```

  - *prefetchObjectArray* : is an array of `TargetPrefetch` objects for various mbox locations.
  - *targetParameters* : is the configured `TargetParameters` for the prefetch request.
  - If the prefetch is successful, `completion` is invoked with a nil value. If the prefetch is not successful, an error message is returned.

#### Example

```objectivec
    NSDictionary *mboxParameters1 = @{@"status":@"platinum"};
    NSDictionary *profileParameters1 = @{@"age":@"20"};
    AEPTargetProduct *product1 = [[AEPTargetProduct alloc] initWithProductId:@"24D3412" categoryId:@"Books"];
    AEPTargetOrder *order1 = [[AEPTargetOrder alloc] initWithId:@"ADCKKIM" total:[@(344.30) doubleValue] purchasedProductIds:@[@"34", @"125"]];

    AEPTargetParameters *targetParameters1 = [[AEPTargetParameters alloc] initWithParameters:mboxParameters1 profileParameters:profileParameters1 order:order1 product:product1 ];

    NSDictionary *mboxParameters2 = @{@"userType":@"Paid"};
    AEPTargetProduct *product2 = [[AEPTargetProduct alloc] initWithProductId:@"764334" categoryId:@"Online"];
    AEPTargetOrder *order2 = [[AEPTargetOrder alloc] initWithId:@"ADCKKIM" total:[@(344.30) doubleValue] purchasedProductIds:@[@"id1",@"id2"]];
    AEPTargetParameters *targetParameters2 = [[AEPTargetParameters alloc] initWithParameters:mboxParameters2 profileParameters:nil order:order2 product:product2 ];

    // Creating Prefetch Objects
    AEPTargetPrefetchObject *prefetch1 = [[AEPTargetPrefetchObject alloc] initWithName: @"logo" targetParameters:targetParameters1];
    AEPTargetPrefetchObject *prefetch2 = [[AEPTargetPrefetchObject alloc] initWithName: @"buttonColor" targetParameters:targetParameters2];
    

    // Creating prefetch Array
    NSArray *prefetchArray = @[prefetch1,prefetch2];

    // Creating Target parameters
    NSDictionary *mboxParameters = @{@"status":@"progressive"};
    NSDictionary *profileParameters = @{@"age":@"20-32"};
    AEPTargetProduct *product = [[AEPTargetProduct alloc] initWithProductId:@"24D334" categoryId:@"Stationary"];
    AEPTargetOrder *order = [[AEPTargetOrder alloc] initWithId:@"ADCKKBC" total:[@(400.50) doubleValue] purchasedProductIds:@[@"34", @"125"]];

    AEPTargetParameters *targetParameters = [[AEPTargetParameters alloc] initWithParameters:mboxParameters
    profileParameters:profileParameters
    order:order
    product:product];

    // Target API Call
    [AEPMobileTarget prefetchContent:prefetchArray withParameters:targetParameters callback:^(NSError * _Nullable error){
    // do something with the callback response
    }];
```

## retrieveLocationContent

This API sends a batch request to the configured Target server for multiple mbox locations.

For mbox locations in the Target requests list that are not already prefetched, this API sends a batch request to the configured Target server. The content for the mbox locations that have been prefetched in a previous request are returned from the SDK, and no additional network request is made. Each Target request object in the list contains a callback function, which is invoked when content is available for its given mbox location.

When using `contentWithData` callback to instantiate TargetRequest object, the following keys can be used to read response tokens and Analytics for Target (A4T) info from the data payload if available in the Target response.

 - responseTokens (Response tokens)
 - analytics.payload (A4T payload)
 - clickmetric.analytics.payload (Click tracking A4T payload)

### Swift 

#### Syntax 

```swift
static func retrieveLocationContent(_ requestArray: [TargetRequest], with targetParameters: TargetParameters? = nil)
```

  - *requestArray* : an array of `TargetRequest` objects to retrieve content
  - *targetParameters* : a `TargetParameters` object containing parameters for all locations in the requests array

#### Example

```swift
        let TargetParameters1 = TargetParameters(
            parameters: ["status": "platinum"],
            profileParameters: ["age": "20"],
            order: TargetOrder(id: "ADCKKIM", total: 344.30, purchasedProductIds: ["34", "125"]),
            product: TargetProduct(productId: "24D3412", categoryId: "Books")
        )

        let TargetParameters2 = TargetParameters(
            parameters: ["userType": "Paid"],
            profileParameters: nil,
            order: TargetOrder(id: "ADCKKIM", total: 344.30, purchasedProductIds: ["id1", "id2"]),
            product: TargetProduct(productId: "764334", categoryId: "Online")
        )

        let globalTargetParameters = TargetParameters(
            parameters: ["status": "progressive"],
            profileParameters: ["age": "20-32"],
            order: TargetOrder(id: "ADCKKBC", total: 400.50, purchasedProductIds: ["34", "125"]),
            product: TargetProduct(productId: "24D334", categoryId: "Stationary")
        )

        let request1 = TargetRequest(mboxName: "logo", defaultContent: "BlueWhale", targetParameters: TargetParameters1) { content in
            if let content = content {
                // do something with the target content.
            }
        }
        let request2 = TargetRequest(mboxName: "logo", defaultContent: "red", targetParameters: TargetParameters2) { content, data in
            if let content = content {
                // do something with the target content.
            }

            // Read the data dictionary containing one or more of response tokens, analytics payload and click-tracking analytics payload, if available.
            if let data = data {
                let responseTokens = data["responseTokens"] as? [String: Any] ?? [:]

                let analyticsPayload = data["analytics.payload"] as? [String: String] ?? [:]

                let clickMetricAnalyticsPayload = data["clickmetric.analytics.payload"] as? [String: String] ?? [:]
                ...
            }
        }
        Target.retrieveLocationContent([request1, request2], with: globalTargetParameters)
```

### Objective C

#### Syntax 

```objectivec
+ (void) retrieveLocationContent: (nonnull NSArray<AEPTargetRequestObject*>*) requests
         withParameters: (nullable AEPTargetParameters*) parameters;
```

  - *requests* : an array of `AEPTargetRequestObject` objects to retrieve content
  - *parameters* : a `AEPTargetParameters` object containing parameters for all locations in the requests array 

#### Example

```objectivec
    NSDictionary *mboxParameters1 = @{@"status":@"platinum"};
    NSDictionary *profileParameters1 = @{@"age":@"20"};
    AEPTargetProduct *product1 = [[AEPTargetProduct alloc] initWithProductId:@"24D3412" categoryId:@"Books"];
    AEPTargetOrder *order1 = [[AEPTargetOrder alloc] initWithId:@"ADCKKIM" total:[@(344.30) doubleValue] purchasedProductIds:@[@"34", @"125"]];

    AEPTargetParameters *targetParameters1 = [[AEPTargetParameters alloc] initWithParameters:mboxParameters1 profileParameters:profileParameters1 order:order1 product:product1 ];

    NSDictionary *mboxParameters2 = @{@"userType":@"Paid"};
    AEPTargetProduct *product2 = [[AEPTargetProduct alloc] initWithProductId:@"764334" categoryId:@"Online"];
    AEPTargetOrder *order2 = [[AEPTargetOrder alloc] initWithId:@"ADCKKIM" total:[@(344.30) doubleValue] purchasedProductIds:@[@"id1",@"id2"]];
    AEPTargetParameters *targetParameters2 = [[AEPTargetParameters alloc] initWithParameters:mboxParameters2 profileParameters:nil order:order2 product:product2 ];
    
    AEPTargetRequestObject *request1 = [[AEPTargetRequestObject alloc] initWithMboxName: @"logo" defaultContent: @"BlueWhale" targetParameters: targetParameters1 contentCallback:^(NSString * _Nullable content) {
            // do something with the target content.
            NSString *targetContent = content ?: @"";
        }];
    AEPTargetRequestObject *request2 = [[AEPTargetRequestObject alloc] initWithMboxName: @"logo" defaultContent: @"red" targetParameters: targetParameters2 contentWithDataCallback:^(NSString * _Nullable content, NSDictionary<NSString *,id> * _Nullable data) {
            // do something with the target content.
            NSString *targetContent = content ?: @"";

            // Read the data dictionary containing one or more of response tokens, analytics payload and click-tracking analytics payload, if available. 
            if ([data count] > 0) {
                if ([data objectForKey:@"responseTokens"]) {
                    // read response tokens
                }

                if ([data objectForKey:@"analytics.payload"]) {
                  // read analytics payload
                }

                if ([data objectForKey:@"clickmetric.analytics.payload"]) {
                  // read click-tracking analytics payload
                }
            }   
        }];

    // Create request object array
    NSArray *requestArray = @[request1,request2];

    // Creating Target parameters
    NSDictionary *mboxParameters = @{@"status":@"progressive"};
    NSDictionary *profileParameters = @{@"age":@"20-32"};
    AEPTargetProduct *product = [[AEPTargetProduct alloc] initWithProductId:@"24D334" categoryId:@"Stationary"];
    AEPTargetOrder *order = [[AEPTargetOrder alloc] initWithId:@"ADCKKBC" total:[@(400.50) doubleValue] purchasedProductIds:@[@"34", @"125"]];

    AEPTargetParameters *targetParameters = [[AEPTargetParameters alloc] initWithParameters:mboxParameters
                                                                          profileParameters:profileParameters
                                                                                      order:order
                                                                                    product:product];
    [AEPMobileTarget retrieveLocationContent: requestArray withParameters: targetParameters];
```
## setThirdPartyId

This API sets the custom visitor ID for Target.

    This ID is preserved between app upgrades, is saved and restored during the standard application backup process, and is removed at uninstall, upon privacy status update to opted out, or when the resetExperience API is used.

### Swift 

#### Syntax 

```swift
static func setThirdPartyId(_ id: String?)
```

  - *id* : a `String` that contains the custom visitor ID to be set in Target.

#### Example

```swift
Target.setThirdPartyId("third-party-id")
```

### Objective C

#### Syntax 

```objectivec
+ (void) setThirdPartyId: (nullable NSString*) thirdPartyId;
```

  - *thirdPartyId* : a NSString that contains the custom visitor ID to be set in Target.

#### Example

```objectivec
[AEPMobileTarget setThirdPartyId:@"third-party-id"];
```

## getThirdPartyId

This API gets the custom visitor ID for Target. If no `third-party` ID was previously set, or if the ID was reset by calling resetExperience API, it will have a `null` value.

### Swift 

#### Syntax 

```swift
static func getThirdPartyId(_ completion: @escaping (String?, Error?) -> Void)
```

  - *completion* : invoked with the `thirdPartyId` value. If no `third-party` ID was set, this value will be `nil`.

#### Example

```swift
Target.getThirdPartyId({id, err in
    // read Target thirdPartyId
})
```

### Objective C

#### Syntax 

```objectivec
+ (void) getThirdPartyId: (nonnull void (^) (NSString* __nullable thirdPartyId, NSError * _nullable error)) completion;
```

  - *completion* : invoked with the `thirdPartyId` value. If no `third-party` ID was set, this value will be `nil`.

#### Example

```objectivec
    [AEPMobileTarget getThirdPartyId:^(NSString *thirdPartyID, NSError *error){
        // read Target thirdPartyId
    }];
```

## setTntId

This API sets the Target user identifier.

The provided tnt ID is persisted in the SDK and attached to subsequent Target requests. It is used to derive the edge host value in the SDK, which is also persisted and used in future Target requests.

If the provided tnt ID is nil or empty, or if the privacy status is opted out, the SDK will remove the tnt ID and edge host values from the persistence.

    This ID is preserved between app upgrades, is saved and restored during the standard application backup process, and is removed at uninstall, upon privacy status update to opted out, or when the resetExperience API is used.

### Swift 

#### Syntax 

```swift
static func setTntId(_ id: String?)
```

  - *id* : a `String` that contains the Target user identifier to be set in the SDK.

#### Example

```swift
Target.setTntId("f741a5d5-09c0-4931-bf53-b9e568c5f782.35_0")
```

### Objective C

#### Syntax 

```objectivec
+ (void) setTntId: (NSString* _Nullable) id;
```

  - *id* : a NSString that contains the Target user identifier to be set in the SDK.

#### Example

```objectivec
[AEPMobileTarget setTntId:@"f741a5d5-09c0-4931-bf53-b9e568c5f782.35_0"];
```

## getTntId

This API gets the Target user identifier. 

The tnt ID is returned in the network response from Target after a successful call to `prefetchContent` API or `retrieveLocationContent` API, which is then persisted in the SDK. The persisted tnt ID is used in subsequent Target requests until a different tnt ID is returned from Target, or a new tnt ID is set using `setTntId` API.

### Swift 

#### Syntax 

```swift
static func getTntId(_ completion: @escaping (String?, Error?) -> Void)
```

  - *completion* : invoked with the `tntId` value, or `nil` if there was an error retrieving it.

#### Example

```swift
    Target.getTntId { id, err in
        // read Target's tntId        
    }
```

### Objective C

#### Syntax 

```objectivec
+ (void) getTntId: (void (^ _Nonnull) (NSString* _Nullable tntId, NSError* _Nullable error)) completion;
```

  - *completion* : invoked with the `tntId` value, or `nil` if there was an error retrieving it.

#### Example

```objectivec
    [AEPMobileTarget getTntId:^(NSString *tntId, NSError *error){
        // read Target's tntId 
    }];
```

## setSessionId

This API sets the Target session identifier.

The provided session ID is persisted in the SDK for a period defined by `target.sessionTimeout` configuration setting. If the provided session ID is nil or empty, or if the privacy status is opted out, the SDK will remove the session ID value from the persistence.

    This ID is preserved between app upgrades, is saved and restored during the standard application backup process, and is removed at uninstall, upon privacy status update to opted out, or when the resetExperience API is used.

### Swift 

#### Syntax 

```swift
static func setSessionId(_ id: String?)
```

  - *id* : a `String` that contains the Target session identifier to be set in the SDK.

#### Example

```swift
Target.setSessionId("5568c1a2-ece1-42d1-b807-930623998ec3")
```

### Objective C

#### Syntax 

```objectivec
+ (void) setSessionId: (NSString* _Nullable) id;
```

  - *id* : a NSString that contains the Target session identifier to be set in the SDK.

#### Example

```objectivec
[AEPMobileTarget setSessionId:@"5568c1a2-ece1-42d1-b807-930623998ec3"];
```

## getSessionId

This API gets the Target session identifier. 

The session ID is generated locally in the SDK upon initial Target request and persisted for a period defined by `target.sessionTimeout` configuration setting. If the session timeout happens upon a subsequent Target request, a new session ID will be generated for use in the request and persisted in the SDK.

### Swift 

#### Syntax 

```swift
static func getSessionId(_ completion: @escaping (String?, Error?) -> Void)
```

  - *completion* : invoked with the Target `sessionId` value, or `nil` if there was an error retrieving it.

#### Example

```swift
    Target.getSessionId { id, err in
        // read Target sessionId        
    }
```

### Objective C

#### Syntax 

```objectivec
+ (void) getSessionId: (void (^ _Nonnull) (NSString* _Nullable sessionId, NSError* _Nullable error)) completion;
```

  - *completion* : invoked with the Target `sessionId` value, or `nil` if there was an error retrieving it.

#### Example

```objectivec
    [AEPMobileTarget getSessionId:^(NSString *sessionId, NSError *error){
        // read Target sessionId 
    }];
```

## resetExperience

This API resets the user's experience by removing the visitor identifiers and resetting the Target session. Invoking this API also removes previously set Target user ID and custom visitor IDs, Target Edge Host, and the session information from persistent storage.

### Swift 

#### Syntax 

```swift
static func resetExperience()
```

#### Example

```swift
Target.resetExperience()
```

### Objective C

#### Syntax 

```objectivec
+ (void) resetExperience;
```

#### Example

```objectivec
[AEPMobileTarget resetExperience];
```

## clearPrefetchCache

This API clears the in-memory cache that contains the prefetched offers.

### Swift 

#### Syntax 

```swift
static func clearPrefetchCache()
```

#### Example

```swift
Target.clearPrefetchCache()
```

### Objective C

#### Syntax 

```objectivec
+ (void) clearPrefetchCache;
```

#### Example

```objectivec
[AEPMobileTarget clearPrefetchCache];
```

## setPreviewRestartDeepLink

This API sets the Target preview URL to be displayed when the preview mode is enabled and preview selections are confirmed.

### Swift 

#### Syntax 

```swift
static func setPreviewRestartDeepLink(_ deeplink: URL)
```

  - *deeplink* : an `URL` that contains the preview restart deeplink.

#### Example

```swift
    if let url = URL(string: "myapp://HomePage") {
        Target.setPreviewRestartDeepLink(url)
    }
```

### Objective C

#### Syntax 

```objectivec
+ (void) setPreviewRestartDeeplink: (nonnull NSURL*) deeplink;
```

  - *deeplink* : an `NSURL` that contains the preview restart deeplink.

#### Example

```objectivec
[AEPMobileTarget setPreviewRestartDeepLink:@"myapp://HomePage"];
```

## displayedLocations

Use this API to send a location (mbox) display notification to the configured Target server. This API should be invoked for a prefetched mbox after the mbox content is retrieved using the `retrieveLocationContent` API. If no previous prefetch request is made, and the mbox content is retrieved using the `retrieveLocationContent` API, calling this API does not trigger a notification request to the Target server.

### Swift 

#### Syntax 

```swift
static func displayedLocations(_ names: [String], targetParameters: TargetParameters?)
```

  - *names* : is an array of the mbox locations for which the display notification will be sent to Target.
  - *targetParameters* : is the configured `TargetParameters` for the request.

#### Example

```swift
    Target.displayedLocations(
        names: ["mboxName1", "mboxName2"],
        targetParameters: TargetParameters(
            parameters: nil,
            profileParameters: nil,
            order: TargetOrder(id: "ADCKKBC", total: 400.50, purchasedProductIds: ["34", "125"]),
            product: TargetProduct(productId: "24D334", categoryId: "Stationary")
        )
    )
```

### Objective C

#### Syntax 

```objectivec
+ (void) displayedLocations: (nonnull NSArray<NSString*>*) names 
         withTargetParameters: (nullable AEPTargetParameters*) targetParameters;
```

  - *names* : is an NSArray of the mbox locations for which the display notification will be sent to Target.
  - *targetParameters* : is the configured `AEPTargetParameters` for the request. 

#### Example

```objectivec
    AEPTargetOrder *order = [[AEPTargetOrder alloc] initWithId:@"ADCKKBC" total:400.50 purchasedProductIds:@[@"34", @"125"]];
    AEPTargetProduct *product =[[AEPTargetProduct alloc] initWithProductId:@"24D334" categoryId:@"Stationary"];
    AEPTargetParameters * targetParams = [[AEPTargetParameters alloc] initWithParameters:nil profileParameters:nil order:order product:product];
    [AEPMobileTarget displayedLocations:@[@"mboxName1", @"mboxName2"] withTargetParameters:targetParams];
```


## clickedLocation

This API sends a location (mbox) click notification to the configured Target server and can be invoked in the following cases:

- For a prefetched mbox, after the mbox content is retrieved using the `retrieveLocationContent` API.

- For a regular mbox, where no previous prefetch request is made, and the mbox content is retrieved using the `retrieveLocationContent` API.

### Swift 

#### Syntax 

```swift
static func clickedLocation(_ name: String, targetParameters: TargetParameters?)
```

  - *name* : a `String` that contains the mbox location for which the click notification will be sent to Target.
  - *targetParameters* : the configured `TargetParameters` for the request.

#### Example

```swift
    Target.clickedLocation(
        name: "cartLocation",
        targetParameters: TargetParameters(
            parameters: nil,
            profileParameters: nil,
            order: TargetOrder(id: "ADCKKBC", total: 400.50, purchasedProductIds: ["34", "125"]),
            product: TargetProduct(productId: "24D334", categoryId: "Stationary")
        )
    )       
```

### Objective C

#### Syntax 

```objectivec
+ (void) clickedLocation: (nonnull NSArray<NSString*>*) names 
         withTargetParameters: (nullable AEPTargetParameters*) targetParameters;
```

  - *name* : an `NSString` that contains the mbox location for which the click notification will be sent to Target.
  - *targetParameters* : the configured `AEPTargetParameters` for the request.  

#### Example

```objectivec
    EPTargetOrder *order = [[AEPTargetOrder alloc] initWithId:@"ADCKKBC" total:400.50 purchasedProductIds:@[@"34", @"125"]];
    AEPTargetProduct *product =[[AEPTargetProduct alloc] initWithProductId:@"24D334" categoryId:@"Stationary"];
    AEPTargetParameters * targetParams = [[AEPTargetParameters alloc] initWithParameters:nil profileParameters:nil order:order product:product];
    [AEPMobileTarget displayedLocations:@[@"mboxName1", @"mboxName2"] withTargetParameters:targetParams];
```


# Target Raw API reference
This document details all the raw APIs provided by Target, along with sample code snippets on how to properly use the APIs.

## executeRawRequest
This API can be used to retrieve prefetch or execute response for mbox locations from the configured Target server. 

### Swift 

#### Syntax 

```swift
static func executeRawRequest(_ request: [[String: Any]], _ completion: @escaping ([[String: Any]]?, Error?) -> Void)
```

  - *request* - is a dictionary containing prefetch or execute request data in the Target v1 delivery API request format. 
  - *completion* - is the callback which will be invoked with the Target response data or error message after the request is completed. 

#### Example

```swift
    let request: [String: Any] = [ 
        "execute": [ 
            "mboxes": [ 
                [
                    "index": 0, 
                    "name": "mbox1", 
                    "parameters": [ 
                        "mbox_parameter_key1": "mbox_parameter_value1" 
                    ], 
                    "profileParameters": [ 
                        "subscription": "premium" 
                    ], 
                    "order": [ 
                        "id": "id1", 
                        "total": 100.34, 
                        "purchasedProductIds":[ 
                            "pId1"
                        ] 
                    ], 
                    "product": [ 
                        "id": "pId1", 
                        "categoryId": "cId1" 
                    ]
                ], 
                [
                    "index": 1, 
                    "name": "mbox2", 
                    "parameters": [ 
                        "mbox_parameter_key2": "mbox_parameter_value2" 
                    ]
                ]
            ]
        ]
    ] 

Target.executeRawRequest(request) { responseData, error in 
    if error != nil { 
        return 
    } 
    guard let responseData = responseData, 
          !responseData.isEmpty else { 
        return 
    } 

    // handle the response   

} 
```

### Objective C

#### Syntax 

```objectivec
+ (void)executeRawRequest:(nonnull NSDictionary<NSString *, id> *)request completion:(void (nonnull ^)(nullable NSDictionary<NSString *, id> *, nullable NSError *))completion; 
```

  - *request* : is a dictionary containing prefetch or execute request data in the Target v1 delivery API request format. 
  - *completion* : is the  the callback which will be invoked with the Target response data or error message after the request is completed.

#### Example

```objectivec
    NSDictionary *request = @{ 
        @"execute": @{ 
            @"mboxes": @[ 
                @{ 
                    @"index": @(0), 
                    @"name": @"mbox1", 
                    @"parameters": @{ 
                        @"mbox_parameter_key1": @"mbox_parameter_value1" 
                    }, 
                    @"profileParameters": @{ 
                        @"subscription": @"premium" 
                    }, 
                    @"order": @{ 
                        @"id": @"id1", 
                        @"total": @(100.34), 
                        @"purchasedProductIds": @[ 
                            @"pId1" 
                        ]
                    }, 
                    @"product": @{ 
                        @"id": @"pId1", 
                        @"categoryId": @"cId1" 
                    } 
                }, 
                @{ 
                    @"index": @(1), 
                    @"name": @"mbox2", 
                    @"parameters": @{ 
                        @"mbox_parameter_key2": @"mbox_parameter_value2" 
                    } 

                } 

            ] 

        } 

    }; 

    [AEPMobileTarget executeRawRequest:request completion:^(NSDictionary<NSString *,id> * _Nullable data, NSError * _Nullable err) { 
        if (err != nil) { 
            NSLog(@"Error: %@", err); 
            return; 
        } 

        NSLog(@"Target raw response >> %@", data); 

        // handle response 
    }]; 
```


## sendrawnotification
This API sends notification request(s) to the configured Target server for display or click notifications. 

The event tokens required for the Target display or click notifications can be retrieved from the response of a prior `executeRawRequest` API call for prefetch or execute.  

### Swift 

#### Syntax 

```swift
static func sendRawNotifications(_ request: [String: Any]) 
```

  - *request* - is a dictionary containing notifications data in the Target v1 delivery API request format.
 
#### Example

```swift
    var notifications: [[String: Any]] = [] 

    let notification: [String: Any] = [
        "id": "0", 
        "timestamp": Int64(Date().timeIntervalSince1970 * 1000.0), 
        "type": "click", 
        "mbox": [ 
            "name": "mbox1" 
        ], 
        "tokens": [ 
            "someClickToken" 
        ], 
        "parameters": [ 
            "mbox_parameter_key3": "mbox_parameter_value3" 
        ] 

    ] 
    notifications.append(notification) 

    Target.sendRawNotifications([ 
        "notifications": notifications 
    ]) 
```

### Objective C

#### Syntax 

```objectivec
+ (void)sendRawNotifications:(nonnull NSDictionary<NSString *, id> *)request;  
```

  - *request* : is a dictionary containing notifications data in the Target v1 delivery API request format.

#### Example

```objectivec
    NSMutableArray *notifications = [[NSMutableArray alloc] init]; 

    NSDictionary* notification = @{ 

        @"id": @"0", 
        @"timestamp": @((long)([[NSDate date] timeIntervalSince1970] * 1000.0)), 
        @"type": @"click", 
        @"mbox": @{ 
            @"name": @"mbox1", 
        }, 
        @"tokens": @[ @"someClickToken" ], 
        @"parameters": @{ 
            @"mbox_parameter_key3": @"mbox_parameter_value3" 
        } 

    }; 
    [notifications addObject:notification]; 

    NSDictionary *request = @{ 
      @"notifications": notifications 
    }; 
    [AEPMobileTarget sendRawNotifications:request];  
```

# Visual preview

The visual preview mode allows you to easily perform end-to-end QA of activities by enrolling and previewing these activities on your device. This mode does not require a specialized testing set up. To get started, set up a URL scheme and generate the preview links. For more information on setting up URL schemes, see [Defining a Custom URL Scheme for Your App](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app) for iOS and see [Create Deep Links to App Content](https://developer.android.com/training/app-links/deep-linking) for Android. You can also set an application deep link in the SDK that can be triggered when selections are made in the preview mode by using the `setPreviewRestartDeeplink` API.

To enter the preview visual mode, use the Mobile Core's `collectLaunchInfo` API to enable the mode and click the red floating button that appears on the app screen.

### Swift 

#### Example

```swift
    MobileCore.collectLaunchInfo(["adb_deeplink" : "com.adobe.targetpreview://app.adobetarget.com?at_preview_token=tokenFromTarget"])
```

### Objective C

#### Example

```objectivec
    [AEPMobileCore collectLaunchInfo: @{@"adb_deeplink":@"com.adobe.targetpreview://app.adobetarget.com?at_preview_token=tokenFromTarget"}];
```