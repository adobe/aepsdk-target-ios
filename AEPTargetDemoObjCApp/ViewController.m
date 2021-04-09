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
    AEPTargetPrefetchObject *prefetch1 = [[AEPTargetPrefetchObject alloc] initWithName:@"aep-loc-1" targetParameters:nil];
    AEPTargetPrefetchObject *prefetch2 = [[AEPTargetPrefetchObject alloc] initWithName:@"aep-loc-2" targetParameters:nil];
    [AEPMobileTarget prefetchContent:@[prefetch1, prefetch2] withParameters:nil callback:^(NSError * _Nullable error) {
        NSLog(@"================================================================================================");
        NSLog(@"error? >> %@", error.localizedDescription ?: @"nope");
    }];
}

- (IBAction)loadRequest:(id)sender {
    AEPTargetRequestObject *request1 = [[AEPTargetRequestObject alloc] initWithMboxName:@"aep-loc-1" defaultContent:@"defaultContent" targetParameters:nil contentCallback:^(NSString * _Nullable content) {
        NSLog(@"Content is >> %@", content ?: @"nope");
    }];
    AEPTargetRequestObject *request2 = [[AEPTargetRequestObject alloc] initWithMboxName:@"aep-loc-2" defaultContent:@"defaultContent2" targetParameters:nil contentCallback:^(NSString * _Nullable content) {
        NSLog(@"Content is >> %@", content ?: @"nope");
    }];
    [AEPMobileTarget retrieveLocationContent:@[request1, request2] withParameters:nil];
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

- (IBAction)clearPrefetch:(id)sender {
    [AEPMobileTarget clearPrefetchCache];
}

- (IBAction)getThirdPartyClicked:(id)sender {
    [AEPMobileTarget getThirdPartyId:^(NSString *thirdPartyID, NSError *error){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.lblThirdParty setText:thirdPartyID];
        });
    }];
}

- (IBAction)getTntIDClicked:(id)sender {
    [AEPMobileTarget getTntId:^(NSString *tntID, NSError *error){
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

- (IBAction)enterPreviewMode:(id)sender {
    [AEPMobileCore collectLaunchInfo:@{@"adb_deeplink":@""}];
}

- (IBAction)setPreviewRestartDeeplink:(id)sender {
    [AEPMobileTarget setPreviewRestartDeepLink:[NSURL URLWithString:(@"http://www.adobe.com")]];
}

@end
