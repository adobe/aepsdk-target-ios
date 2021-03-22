* auto-gen TOC:
{:toc}

# Target API reference
This document details all the APIs provided by Target, along with sample code snippets on how to properly use the APIs.

## prefetchContent
This API sends a prefetch request to your configured Target server with the prefetch objects array and the specified target parameters. 

### Syntax 
```swift
@objc(prefetchContent:withParameters:callback:)
    static func prefetchContent(prefetchObjectArray: [TargetPrefetch], targetParameters: TargetParameters?, completion: ((Error?) -> Void)?)
```

- *prefetchObjectArray* - is an array of `TargetPrefetch` objects for various mbox locations.
- *targetParameters* - is the configured `TargetParameters` for the prefetch request.
- If the prefetch is successful, `completion` is invoked with a nil value. If the prefetch is not successful, an error message is returned.

### Examples 

- #### Swift

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
            prefetchObjectArray: [
                TargetPrefetch(name: "mboxName1", targetParameters: TargetParameters1),
                TargetPrefetch(name: "mboxName2", targetParameters: TargetParameters2),
            ],
            targetParameters: globalTargetParameters
        ){ error in
            // do something with the callback response
        }
```

- ##### Objective-C

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
