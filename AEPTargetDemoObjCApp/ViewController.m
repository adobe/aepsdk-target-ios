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

#import "ViewController.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *lblThirdParty;
@property (weak, nonatomic) IBOutlet UILabel *lblTntId;
@property (weak, nonatomic) IBOutlet UITextField *textThirdPartyID;
@property (weak, nonatomic) IBOutlet UITextField *griffonUrl;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}


- (IBAction)prefetchClicked:(id)sender {
//    AEPTargetPrefetchObject *prefetch1 = [[AEPTargetPrefetchObject alloc] initWithName:@"aep-loc-1" targetParameters:nil];
//    AEPTargetPrefetchObject *prefetch2 = [[AEPTargetPrefetchObject alloc] initWithName:@"aep-loc-2" targetParameters:nil];
//    [AEPMobileTarget prefetchContent:@[prefetch1, prefetch2] withParameters:nil callback:^(NSError * _Nullable error) {
//        NSLog(@"================================================================================================");
//        NSLog(@"error? >> %@", error.localizedDescription ?: @"nope");
//    }];
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
}

- (IBAction)locationDisplayedClicked:(id)sender {
    AEPTargetOrder *order = [[AEPTargetOrder alloc] initWithId:@"id1" total:1.0 purchasedProductIds:@[@"ppId1"]];
    AEPTargetProduct *product =[[AEPTargetProduct alloc] initWithProductId:@"pId1" categoryId:@"cId1"];
    AEPTargetParameters * targetParams = [[AEPTargetParameters alloc] initWithParameters:@{@"mbox_parameter_key":@"mbox_parameter_value"} profileParameters:@{@"name":@"Smith"} order:order product:product];
    [AEPMobileTarget displayedLocations:@[@"aep-loc-1", @"aep-loc-2"] withTargetParameters:targetParams];
}

- (IBAction)locationClicked:(id)sender {
    AEPTargetOrder *order = [[AEPTargetOrder alloc] initWithId:@"id1" total:1.0 purchasedProductIds:@[@"ppId1"]];
    AEPTargetProduct *product =[[AEPTargetProduct alloc] initWithProductId:@"pId1" categoryId:@"cId1"];
    AEPTargetParameters * targetParams = [[AEPTargetParameters alloc] initWithParameters:@{@"mbox_parameter_key":@"mbox_parameter_value"} profileParameters:@{@"name":@"Smith"} order:order product:product];
    
    [AEPMobileTarget clickedLocation:@"aep-loc-1" withTargetParameters:targetParams];
}

- (IBAction)resetExperienceClicked:(id)sender {
    [AEPMobileTarget resetExperience];
}

- (IBAction)getThirdPartyClicked:(id)sender {
    [AEPMobileTarget getThirdPartyIdWithCompletion:^(NSString *thirdPartyID, NSError *error){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.lblThirdParty setText:thirdPartyID];
        });
    }];
}

- (IBAction)getTntIDClicked:(id)sender {
    [AEPMobileTarget getTntIdWithCompletion:^(NSString *tntID, NSError *error){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.lblTntId setText:tntID];
        });
    }];
}

- (IBAction)setThirdPartyClicked:(id)sender {
    if(![_textThirdPartyID.text isEqualToString:@""]) {
        [AEPMobileTarget setThirdPartyId:_textThirdPartyID.text];
    }
}

- (IBAction)startGriffon:(id)sender {
    if(![_griffonUrl.text isEqualToString:@""]) {
        [AEPAssurance startSession:[NSURL URLWithString:_griffonUrl.text]];
    }
}

@end
