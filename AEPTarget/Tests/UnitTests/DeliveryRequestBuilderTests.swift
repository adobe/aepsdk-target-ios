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

@testable import AEPCore
@testable import AEPServices
@testable import AEPTarget
import XCTest

class DeliveryRequestBuilderTests: XCTestCase {
    func test_generateTargetIDsBy_with_vids() {
        let EXPECTED_TARGET_IDS = """
            {
              "tntId": "tntid_1",
              "thirdPartyId": "thirdPartyId_1",
              "marketingCloudVisitorId": "mid_001",
              "customerIds": [
                {
                  "authenticatedState": "authenticated",
                  "id": "vid_id_1",
                  "integrationCode": "vid_type_1"
                },
                {
                  "authenticatedState": "unknown",
                  "id": "vid_id_2",
                  "integrationCode": "vid_type_2"
                }
              ]
            }
        """
        if let data = EXPECTED_TARGET_IDS.data(using: .utf8),
           let jsonArray = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any],
           let targetIds = DeliveryRequestBuilder.generateTargetIDsBy(
               tntid: "tntid_1", thirdPartyId: "thirdPartyId_1",
               identitySharedState: [
                   "mid": "mid_001",
                   "visitoridslist": [
                       [
                           "id": "vid_id_1",
                           "id.type": "vid_type_1",
                           "authentication.state": 1,
                       ],
                       [
                           "id": "vid_id_2",
                           "id.type": "vid_type_2",
                           "authentication.state": 0,
                       ],
                   ],
               ]
           )
        {
            XCTAssertTrue(NSDictionary(dictionary: targetIds.asDictionary()!).isEqual(to: jsonArray))
            return
        }
        XCTFail()
    }

    func test_generateTargetIDsBy_with_vid_missing_keys() {
        let EXPECTED_TARGET_IDS = """
            {
              "tntId": "tntid_1",
              "thirdPartyId": "thirdPartyId_1",
              "marketingCloudVisitorId": "mid_001",
              "customerIds": [
                {
                  "authenticatedState": "authenticated",
                  "id": "vid_id_1",
                  "integrationCode": "vid_type_1"
                }
              ]
            }
        """
        if let data = EXPECTED_TARGET_IDS.data(using: .utf8),
           let jsonArray = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any],
           let targetIds = DeliveryRequestBuilder.generateTargetIDsBy(
               tntid: "tntid_1", thirdPartyId: "thirdPartyId_1",
               identitySharedState: [
                   "mid": "mid_001",
                   "visitoridslist": [
                       [
                           "id": "vid_id_1",
                           "id.type": "vid_type_1",
                           "authentication.state": 1,
                       ],
                       [
                           "id": "vid_id_2",
                           "authentication.state": 0,
                       ],
                   ],
               ]
           )
        {
            XCTAssertTrue(NSDictionary(dictionary: targetIds.asDictionary()!).isEqual(to: jsonArray))
            return
        }
        XCTFail()
    }

    func test_generateTargetIDsBy_without_vid() {
        let EXPECTED_TARGET_IDS = """
            {
              "tntId": "tntid_1",
              "thirdPartyId": "thirdPartyId_1",
              "marketingCloudVisitorId": "mid_001"
            }
        """
        if let data = EXPECTED_TARGET_IDS.data(using: .utf8),
           let jsonArray = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any],
           let targetIds = DeliveryRequestBuilder.generateTargetIDsBy(
               tntid: "tntid_1", thirdPartyId: "thirdPartyId_1",
               identitySharedState: [
                   "mid": "mid_001",
               ]
           )
        {
            print(targetIds.asDictionary() as AnyObject)
            XCTAssertTrue(NSDictionary(dictionary: targetIds.asDictionary()!).isEqual(to: jsonArray))
            return
        }
        XCTFail()
    }

    func test_generateTargetIDsBy_without_tntId() {
        let EXPECTED_TARGET_IDS = """
            {
              "thirdPartyId": "thirdPartyId_1",
              "marketingCloudVisitorId": "mid_001"
            }
        """
        if let data = EXPECTED_TARGET_IDS.data(using: .utf8),
           let jsonArray = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any],
           let targetIds = DeliveryRequestBuilder.generateTargetIDsBy(
               tntid: nil, thirdPartyId: "thirdPartyId_1",
               identitySharedState: [
                   "mid": "mid_001",
               ]
           )
        {
            print(targetIds.asDictionary() as AnyObject)
            XCTAssertTrue(NSDictionary(dictionary: targetIds.asDictionary()!).isEqual(to: jsonArray))
            return
        }
        XCTFail()
    }

    func testBuild_Prefetch() {
        ServiceProvider.shared.systemInfoService = MockedSystemInfoService()
        let request = DeliveryRequestBuilder.build(
            tntId: "tnt_id_1",
            thirdPartyId: "thirdPartyId_1",
            identitySharedState: ["mid": "mid_xxxx", "blob": "blob_xxx", "locationhint": "9"],
            lifecycleSharedState: [
                "a.OSVersion": "iOS 14.2",
                "a.DaysSinceFirstUse": "0",
                "a.CrashEvent": "CrashEvent",
                "a.CarrierName": "(nil)",
                "a.Resolution": "828x1792",
                "a.RunMode": "Application",
                "a.ignoredSessionLength": "-1605549540",
                "a.HourOfDay": "11",
                "a.AppID": "v5ManualTestApp 1.0 (1)",
                "a.DayOfWeek": "2",
                "a.DeviceName": "x86_64",
                "a.LaunchEvent": "LaunchEvent",
                "a.Launches": "2",
                "a.DaysSinceLastUse": "0",
                "a.locale": "en-US",
            ],
            targetPrefetchArray: [
                TargetPrefetch(name: "Drink_1", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
                TargetPrefetch(name: "Drink_2", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
            ],
            targetParameters: TargetParameters(profileParameters: ["name": "Smith"])
        )

        if let data = EXPECTED_PREFETCH_JSON.data(using: .utf8),
           let jsonArray = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any],
           let result = request?.asDictionary()
        {
            XCTAssertTrue(NSDictionary(dictionary: jsonArray["id"] as! [String: Any]).isEqual(to: result["id"] as! [String: Any]))
            XCTAssertTrue(NSDictionary(dictionary: jsonArray["experienceCloud"] as! [String: Any]).isEqual(to: result["experienceCloud"] as! [String: Any]))
            var context = result["context"] as! [String: Any]
            context["timeOffsetInMinutes"] = 0
            XCTAssertTrue(NSDictionary(dictionary: jsonArray["context"] as! [String: Any]).isEqual(to: context))
            XCTAssertTrue(NSDictionary(dictionary: jsonArray["prefetch"] as! [String: Any]).isEqual(to: result["prefetch"] as! [String: Any]))
            return
        }

        XCTFail()
    }

    func testBuild_Notification() {
        ServiceProvider.shared.systemInfoService = MockedSystemInfoService()
        let request = DeliveryRequestBuilder.build(
            tntId: "tnt_id_1",
            thirdPartyId: "thirdPartyId_1",
            identitySharedState: ["mid": "mid_xxxx", "blob": "blob_xxx", "locationhint": "9"],
            lifecycleSharedState: [
                "a.OSVersion": "iOS 14.2",
                "a.DaysSinceFirstUse": "0",
                "a.CrashEvent": "CrashEvent",
                "a.CarrierName": "(nil)",
                "a.Resolution": "828x1792",
                "a.RunMode": "Application",
                "a.ignoredSessionLength": "-1605549540",
                "a.HourOfDay": "11",
                "a.AppID": "v5ManualTestApp 1.0 (1)",
                "a.DayOfWeek": "2",
                "a.DeviceName": "x86_64",
                "a.LaunchEvent": "LaunchEvent",
                "a.Launches": "2",
                "a.DaysSinceLastUse": "0",
                "a.locale": "en-US",
            ],
            targetParameters: TargetParameters(profileParameters: ["name": "Smith"]),
            notifications: [
                Notification(id: "id1", timestamp: 12345, type: "display", mbox: Mbox(name: "Drink_1", state: "somestate"), tokens: ["token1"], parameters: nil),
            ]
        )

        if let data = EXPECTED_NOTIFICATION_JSON.data(using: .utf8),
           let jsonArray = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any],
           let result = request?.asDictionary()
        {
            XCTAssertTrue(NSDictionary(dictionary: jsonArray["id"] as! [String: Any]).isEqual(to: result["id"] as! [String: Any]))
            XCTAssertTrue(NSDictionary(dictionary: jsonArray["experienceCloud"] as! [String: Any]).isEqual(to: result["experienceCloud"] as! [String: Any]))
            var context = result["context"] as! [String: Any]
            context["timeOffsetInMinutes"] = 0
            XCTAssertTrue(NSDictionary(dictionary: jsonArray["context"] as! [String: Any]).isEqual(to: context))

            let arrayA = NSSet(array: jsonArray["notifications"] as! [[String: Any]])
            let arrayB = NSSet(array: result["notifications"] as! [[String: Any]])
            XCTAssertTrue(arrayA.isEqual(to: arrayB as! Set<AnyHashable>))

            return
        }

        XCTFail()
    }

    func testGetDisplayNotification_withNoState() {
        let notification = DeliveryRequestBuilder.getDisplayNotification(mboxName: "Drink_1", cachedMboxJson: ["mboxes": "mboxes1"], parameters: TargetParameters(parameters: ["p": "v"], profileParameters: ["name": "myname"], order: TargetOrder(id: "oid1"), product: TargetProduct(productId: "pid1")), timestamp: 12345, lifecycleContextData: ["a.OSVersion": "iOS 14.2"])

        XCTAssertNil(notification)
    }

    func testGetDisplayNotification_withNoTokense() {
        let notification = DeliveryRequestBuilder.getDisplayNotification(mboxName: "Drink_1", cachedMboxJson: ["state": "state1"], parameters: TargetParameters(parameters: ["p": "v"], profileParameters: ["name": "myname"], order: TargetOrder(id: "oid1"), product: TargetProduct(productId: "pid1")), timestamp: 12345, lifecycleContextData: ["a.OSVersion": "iOS 14.2"])

        XCTAssertNil(notification)
    }

    func testGetDisplayNotification() {
        let notification = DeliveryRequestBuilder.getDisplayNotification(mboxName: "Drink_1", cachedMboxJson: mockCacheMBoxJson, parameters: mockTargetParams, timestamp: 12345, lifecycleContextData: mockLifecycleContextData)

        XCTAssertNotNil(notification)
        XCTAssertNotNil(notification?.id)
        XCTAssertTrue(notification?.type == TargetConstants.TargetJson.MetricType.DISPLAY)
        XCTAssertTrue(notification?.mbox.name == "Drink_1")
        XCTAssertTrue(notification?.parameters?["a.OSVersion"] == "iOS 14.2")
    }

    func testGetClickedNotification_NoMMboxName() {
        let notification = DeliveryRequestBuilder.getClickedNotification(cachedMboxJson: mockCacheMBoxJson, parameters: mockTargetParams, timestamp: 12345, lifecycleContextData: mockLifecycleContextData)

        XCTAssertNotNil(notification)
        XCTAssertNotNil(notification?.id)
        XCTAssertTrue(notification?.type == TargetConstants.TargetJson.MetricType.CLICK)
        XCTAssertTrue(notification?.mbox.name == "")
        XCTAssertTrue(notification?.parameters?["a.OSVersion"] == "iOS 14.2")
    }

    func testGetClickedNotification() {
        var tempMockCacheMBoxJson = mockCacheMBoxJson
        tempMockCacheMBoxJson["name"] = "Drink_1"
        tempMockCacheMBoxJson["metrics"] = metrics
        let notification = DeliveryRequestBuilder.getClickedNotification(cachedMboxJson: tempMockCacheMBoxJson, parameters: mockTargetParams, timestamp: 12345, lifecycleContextData: mockLifecycleContextData)

        XCTAssertNotNil(notification)
        XCTAssertNotNil(notification?.id)
        XCTAssertTrue(notification?.mbox.name == "Drink_1")
        XCTAssertTrue(notification?.parameters?["a.OSVersion"] == "iOS 14.2")
        XCTAssertTrue(notification?.tokens?.first == "token1")
    }

    private var mockCacheMBoxJson = ["state": "state1", "options": [["eventToken": "sometoken"]]] as [String: Any]
    private var mockTargetParams = TargetParameters(parameters: ["p": "v", "__oldTargetSdkApiCompatParam__": "removeit"], profileParameters: ["name": "myname"], order: TargetOrder(id: "oid1"), product: TargetProduct(productId: "pid1"))
    private var mockLifecycleContextData = ["a.OSVersion": "iOS 14.2"]
    private var metrics = [["type": "click", "eventToken": "token1"]]

    private let EXPECTED_PREFETCH_JSON = """
    {
      "id": {
        "tntId": "tnt_id_1",
        "marketingCloudVisitorId": "mid_xxxx",
        "thirdPartyId": "thirdPartyId_1"
      },
      "experienceCloud": {
        "analytics": {
          "logging": "client_side"
        },
        "audienceManager": {
          "blob": "blob_xxx",
          "locationHint": "9"
        }
      },
      "context": {
        "userAgent": "Mozilla/5.0 (iPhone; CPU OS 14_0; en_US)",
        "mobilePlatform": {
          "deviceName": "My iPhone",
          "deviceType": "phone",
          "platformType": "ios"
        },
        "screen": {
          "colorDepth": 32,
          "width": 1125,
          "height": 2436,
          "orientation": "portrait"
        },
        "channel": "mobile",
        "application": {
          "id": "com.adobe.marketing.mobile.testing",
          "name": "test_app",
          "version": "1.2"
        },
        "timeOffsetInMinutes": 0
      },
      "prefetch": {
        "mboxes": [
          {
            "parameters": {
              "a.OSVersion": "iOS 14.2",
              "a.DaysSinceFirstUse": "0",
              "a.CrashEvent": "CrashEvent",
              "a.CarrierName": "(nil)",
              "a.Resolution": "828x1792",
              "a.RunMode": "Application",
              "a.ignoredSessionLength": "-1605549540",
              "a.HourOfDay": "11",
              "a.DeviceName": "x86_64",
              "a.DayOfWeek": "2",
              "a.LaunchEvent": "LaunchEvent",
              "a.AppID": "v5ManualTestApp 1.0 (1)",
              "a.Launches": "2",
              "a.DaysSinceLastUse": "0",
              "a.locale": "en-US"
            },
            "profileParameters": {
              "name": "Smith",
              "mbox-parameter-key1": "mbox-parameter-value1"
            },
            "name": "Drink_1",
            "index": 0
          },
          {
            "parameters": {
              "a.OSVersion": "iOS 14.2",
              "a.DaysSinceFirstUse": "0",
              "a.CrashEvent": "CrashEvent",
              "a.CarrierName": "(nil)",
              "a.Resolution": "828x1792",
              "a.RunMode": "Application",
              "a.ignoredSessionLength": "-1605549540",
              "a.HourOfDay": "11",
              "a.DeviceName": "x86_64",
              "a.DayOfWeek": "2",
              "a.LaunchEvent": "LaunchEvent",
              "a.AppID": "v5ManualTestApp 1.0 (1)",
              "a.Launches": "2",
              "a.DaysSinceLastUse": "0",
              "a.locale": "en-US"
            },
            "profileParameters": {
              "mbox-parameter-key1": "mbox-parameter-value1",
              "name": "Smith"
            },
            "name": "Drink_2",
            "index": 1
          }
        ]
      }
    }
    """

    private let EXPECTED_NOTIFICATION_JSON = """
    {
      "id": {
        "tntId": "tnt_id_1",
        "marketingCloudVisitorId": "mid_xxxx",
        "thirdPartyId": "thirdPartyId_1"
      },
      "experienceCloud": {
        "analytics": {
          "logging": "client_side"
        },
        "audienceManager": {
          "blob": "blob_xxx",
          "locationHint": "9"
        }
      },
      "context": {
        "userAgent": "Mozilla/5.0 (iPhone; CPU OS 14_0; en_US)",
        "mobilePlatform": {
          "deviceName": "My iPhone",
          "deviceType": "phone",
          "platformType": "ios"
        },
        "screen": {
          "colorDepth": 32,
          "width": 1125,
          "height": 2436,
          "orientation": "portrait"
        },
        "channel": "mobile",
        "application": {
          "id": "com.adobe.marketing.mobile.testing",
          "name": "test_app",
          "version": "1.2"
        },
        "timeOffsetInMinutes": 0
      },
      "notifications": [
          {
             "tokens": ["token1"],
             "id": "id1",
             "timestamp": 12345,
             "mbox": {
                "name": "Drink_1",
                "state": "somestate"
             },
             "type": "display"
          }
       ]
    }
    """
}

private class MockedSystemInfoService: SystemInfoService {
    func getProperty(for _: String) -> String? {
        ""
    }

    func getAsset(fileName _: String, fileType _: String) -> String? {
        ""
    }

    func getAsset(fileName _: String, fileType _: String) -> [UInt8]? {
        nil
    }

    func getDeviceName() -> String {
        "My iPhone"
    }

    func getMobileCarrierName() -> String? {
        ""
    }

    func getRunMode() -> String {
        ""
    }

    func getApplicationName() -> String? {
        "test_app"
    }

    func getApplicationBuildNumber() -> String? {
        ""
    }

    func getApplicationVersionNumber() -> String? {
        ""
    }

    func getOperatingSystemName() -> String {
        ""
    }

    func getOperatingSystemVersion() -> String {
        ""
    }

    func getCanonicalPlatformName() -> String {
        ""
    }

    func getDisplayInformation() -> (width: Int, height: Int) {
        (1125, 2436)
    }

    func getDefaultUserAgent() -> String {
        "Mozilla/5.0 (iPhone; CPU OS 14_0; en_US)"
    }

    func getActiveLocaleName() -> String {
        ""
    }

    func getDeviceType() -> AEPServices.DeviceType {
        .PHONE
    }

    func getApplicationBundleId() -> String? {
        "com.adobe.marketing.mobile.testing"
    }

    func getApplicationVersion() -> String? {
        "1.2"
    }

    func getCurrentOrientation() -> AEPServices.DeviceOrientation {
        .PORTRAIT
    }
}
