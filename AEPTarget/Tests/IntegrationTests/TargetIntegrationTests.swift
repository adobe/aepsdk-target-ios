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

import AEPAnalytics
@testable import AEPCore
import AEPIdentity
import AEPLifecycle
@testable import AEPServices
@testable import AEPTarget

import Foundation
import XCTest

class TargetIntegrationTests: XCTestCase {
    private let T_LOG_TAG = "TargetIntegrationTests"
    private let dispatchQueue = DispatchQueue(label: "com.adobe.target.test")
    override func setUp() {
        FileManager.default.clear()
        UserDefaults.clear()
        ServiceProvider.shared.reset()
        EventHub.reset()
    }

    override func tearDown() {
        let unregisterExpectation = XCTestExpectation(description: "unregister extensions")
        unregisterExpectation.expectedFulfillmentCount = 1
        MobileCore.unregisterExtension(Target.self) {
            unregisterExpectation.fulfill()
        }

        wait(for: [unregisterExpectation], timeout: 2)
    }

    private func waitForLatestSettledSharedState(_ extensionName: String, timeout: Double = 1) -> [String: Any]? {
        var sharedState: [String: Any]?
        let sharedStateExpectation = XCTestExpectation(description: "wait for the latest shared state of \(extensionName)")
        sharedStateExpectation.expectedFulfillmentCount = 1
        MobileCore.registerEventListener(type: "com.adobe.eventType.hub", source: "com.adobe.eventSource.sharedState") { event in
            if let data = event.data, data["stateowner"] as? String == extensionName {
                self.dispatchQueue.async {
                    let result = EventHub.shared.getSharedState(extensionName: extensionName, event: event)
                    if let result = result, result.status == .set {
                        sharedState = result.value
                        sharedStateExpectation.fulfill()
                    } else {
                        Log.error(label: self.T_LOG_TAG, "[\(extensionName)'s shared state: \n status = \(String(describing: result?.status.rawValue)) \n value = \(String(describing: result?.value))]")
                    }
                }
            }
        }
        wait(for: [sharedStateExpectation], timeout: timeout)
        return sharedState
    }

    private func getLastValidSharedState(_ extensionName: String) -> SharedStateResult? {
        let event = Event(name: "name_test", type: "type_test", source: "source_test", data: nil)
        MobileCore.dispatch(event: event)
        return EventHub.shared.getSharedState(extensionName: extensionName, event: event)
    }

    private func jsonStringToDictionary(_ json: String) -> [String: Any] {
        guard let data = json.data(using: .utf8), let jsonDictionary = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            return [String: Any]()
        }
        return jsonDictionary
    }

    private func prettify(_ eventData: [String: Any]?) -> String {
        guard let eventData = eventData else {
            return ""
        }
        guard JSONSerialization.isValidJSONObject(eventData),
              let data = try? JSONSerialization.data(withJSONObject: eventData, options: .prettyPrinted),
              let prettyPrintedString = String(data: data, encoding: String.Encoding.utf8)
        else {
            return " \(eventData as AnyObject)"
        }
        return prettyPrintedString
    }

    private func prettifyJsonArray(_ eventData: [[String: Any]]?) -> String {
        guard let eventData = eventData else {
            return ""
        }
        guard JSONSerialization.isValidJSONObject(eventData),
              let data = try? JSONSerialization.data(withJSONObject: eventData, options: .prettyPrinted),
              let prettyPrintedString = String(data: data, encoding: String.Encoding.utf8)
        else {
            return " \(eventData as AnyObject)"
        }
        return prettyPrintedString
    }

    func testPrefetch() {
        // mocked network response
        let responseString = """
            {
              "status": 200,
              "id": {
                "tntId": "DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0",
                "marketingCloudVisitorId": "61055260263379929267175387965071996926"
              },
              "requestId": "01d4a408-6978-48f7-95c6-03f04160b257",
              "client": "acopprod3",
              "edgeHost": "mboxedge35.tt.omtrdc.net",
              "prefetch": {
                "mboxes": [
                  {
                    "index": 0,
                    "name": "t_test_01",
                    "options": [
                      {
                        "content": {
                          "key1": "value1"
                        },
                        "type": "json",
                        "eventToken": "uR0kIAPO+tZtIPW92S0NnWqipfsIHvVzTQxHolz2IpSCnQ9Y9OaLL2gsdrWQTvE54PwSz67rmXWmSnkXpSSS2Q=="
                      }
                    ]
                  }
                ]
              }
            }
        """
        let validResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)

        // init mobile SDK, register extensions
        let initExpectation = XCTestExpectation(description: "init extensions")
        MobileCore.setLogLevel(.trace)
        MobileCore.registerExtensions([Identity.self, Lifecycle.self, Target.self]) {
            initExpectation.fulfill()
        }
        wait(for: [initExpectation], timeout: 1)

        // update configurationverify the configuration's shared state
        MobileCore.updateConfigurationWith(configDict: [
            "experienceCloud.org": "orgid",
            "experienceCloud.server": "test.com",
            "global.privacy": "optedin",
            "target.server": "amsdk.tt.omtrdc.net",
            "target.clientCode": "amsdk",
        ])
        guard let config = waitForLatestSettledSharedState("com.adobe.module.configuration", timeout: 1) else {
            XCTFail("failed to retrieve the latest configuration (.set)")
            return
        }
        Log.debug(label: T_LOG_TAG, "configuration :\n \(config as AnyObject)")

        // verify the configuration's shared state
        XCTAssertTrue(config.keys.contains("target.server"))
        XCTAssertTrue(config.keys.contains("target.clientCode"))
        XCTAssertTrue(config.keys.contains("global.privacy"))

        // verify the lifecycle's shared state
        guard let lifecycle = getLastValidSharedState("com.adobe.module.lifecycle")?.value?["lifecyclecontextdata"] as? [String: Any] else {
            XCTFail("failed to retrieve the last valid lifecycle")
            return
        }
        Log.debug(label: T_LOG_TAG, "lifecycle :\n \(lifecycle as AnyObject)")
        XCTAssertTrue(lifecycle.keys.contains("appid"))
        XCTAssertTrue(lifecycle.keys.contains("locale"))
        XCTAssertTrue(lifecycle.keys.contains("osversion"))

        // syncIdentifiers (v_ids)
        Identity.syncIdentifiers(identifiers: ["vid_type_1": "vid_id_1", "vid_type_2": "vid_id_2"], authenticationState: .authenticated)

        // verify the identity's shared state
        guard let identity = waitForLatestSettledSharedState("com.adobe.module.identity", timeout: 1) else {
            XCTFail()
            return
        }
        Log.debug(label: T_LOG_TAG, "identity :\n \(identity as AnyObject)")
        XCTAssertTrue(identity.keys.contains("mid"))
        XCTAssertTrue(identity.keys.contains("visitoridslist"))
        let prettyIdentity = prettify(identity)
        XCTAssertTrue(prettyIdentity.contains("vid_type_2"))
        XCTAssertTrue(prettyIdentity.contains("vid_id_1"))

        // override network service
        let networkRequestExpectation = XCTestExpectation(description: "monitor the prefetch request")
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            Log.debug(label: self.T_LOG_TAG, "request url is: \(request.url.absoluteString)")
            if request.url.absoluteString.contains("https://amsdk.tt.omtrdc.net/rest/v1/delivery/?client=amsdk&sessionId=") {
                if let data = request.connectPayload.data(using: .utf8),
                   let payloadDictionary = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
                {
                    Log.debug(label: self.T_LOG_TAG, "request payload is: \n \(self.prettify(payloadDictionary))")

                    // verify payloadDictionary.keys
                    XCTAssertTrue(Set(payloadDictionary.keys) == Set([
                        "id",
                        "experienceCloud",
                        "context",
                        "prefetch",
                        "environmentId",
                    ]))

                    // verify payloadDictionary["id"]
                    guard let idDictionary = payloadDictionary["id"] as? [String: Any] else {
                        XCTFail()
                        return nil
                    }
                    XCTAssertEqual(identity["mid"] as? String ?? "x", idDictionary["marketingCloudVisitorId"] as? String ?? "y")
                    guard let customerIds = idDictionary["customerIds"] as? [[String: Any]] else {
                        XCTFail()
                        return nil
                    }
//                    {
//                      "customerIds": [
//                        {
//                          "id": "vid_id_1",
//                          "integrationCode": "vid_type_1",
//                          "authenticatedState": "unknown"
//                        },
//                        {
//                          "id": "vid_id_2",
//                          "integrationCode": "vid_type_2",
//                          "authenticatedState": "unknown"
//                        }
//                      ]
//                    }
                    let customerIdsJson = self.prettifyJsonArray(customerIds)
                    XCTAssertTrue(customerIdsJson.contains("\"integrationCode\" : \"vid_type_1\""))
                    XCTAssertTrue(customerIdsJson.contains("\"id\" : \"vid_id_2\""))
                    XCTAssertTrue(customerIdsJson.contains("\"authenticatedState\" : \"unknown\""))

                    // verify payloadDictionary["context"]
                    guard let contextDictionary = payloadDictionary["context"] as? [String: Any] else {
                        XCTFail()
                        return nil
                    }
                    XCTAssertTrue(Set(contextDictionary.keys) == Set([
                        "userAgent",
                        "mobilePlatform",
                        "screen",
                        "channel",
                        "application",
                        "timeOffsetInMinutes",
                    ]))
//                    {
//                      "context": {
//                        "userAgent": "Mozilla/5.0 (iPhone; CPU OS 14_0 like Mac OS X; en_US)",
//                        "mobilePlatform": {
//                          "deviceName": "x86_64",
//                          "deviceType": "phone",
//                          "platformType": "ios"
//                        },
//                        "screen": {
//                          "colorDepth": 32,
//                          "width": 1125,
//                          "height": 2436,
//                          "orientation": "portrait"
//                        },
//                        "channel": "mobile",
//                        "application": {
//                          "id": "com.apple.dt.xctest.tool",
//                          "name": "xctest",
//                          "version": "17161"
//                        },
//                        "timeOffsetInMinutes": 1615345147
//                      }
//                    }
                    let contextJson = self.prettify(contextDictionary)
                    XCTAssertTrue(contextJson.contains("\"channel\" : \"mobile\""))
                    XCTAssertTrue(contextJson.contains("\"orientation\" : \"portrait\""))

                    // verify payloadDictionary["prefetch"]
                    guard let prefetchDictionary = payloadDictionary["prefetch"] as? [String: Any] else {
                        XCTFail()
                        return nil
                    }
//                    {
//                      "prefetch": {
//                        "mboxes": [
//                          {
//                            "index": 0,
//                            "profileParameters": {
//                              "mbox-parameter-key1": "mbox-parameter-value1",
//                              "name": "Smith"
//                            },
//                            "name": "Drink_1",
//                            "parameters": {
//                              "a.Resolution": "1125x2436",
//                              "a.RunMode": "Application",
//                              "a.DayOfWeek": "3",
//                              "a.LaunchEvent": "LaunchEvent",
//                              "a.OSVersion": "iOS 14.0",
//                              "a.HourOfDay": "20",
//                              "a.DeviceName": "x86_64",
//                              "a.AppID": "xctest (17161)",
//                              "a.locale": "en-US"
//                            }
//                          },
//                          {
//                            "index": 1,
//                            "profileParameters": {
//                              "name": "Smith",
//                              "mbox-parameter-key1": "mbox-parameter-value1"
//                            },
//                            "name": "Drink_2",
//                            "parameters": {
//                              "a.Resolution": "1125x2436",
//                              "a.RunMode": "Application",
//                              "a.HourOfDay": "20",
//                              "a.DayOfWeek": "3",
//                              "a.OSVersion": "iOS 14.0",
//                              "a.LaunchEvent": "LaunchEvent",
//                              "a.DeviceName": "x86_64",
//                              "a.AppID": "xctest (17161)",
//                              "a.locale": "en-US"
//                            }
//                          }
//                        ]
//                      }
//                    }
                    XCTAssertTrue(Set(prefetchDictionary.keys) == Set([
                        "mboxes",
                    ]))
                    let prefetchJson = self.prettify(prefetchDictionary)
                    XCTAssertTrue(prefetchJson.contains("\"name\" : \"Drink_2\""))
                    XCTAssertTrue(prefetchJson.contains("\"name\" : \"Drink_1\""))
                    XCTAssertTrue(prefetchJson.contains("\"mbox-parameter-key1\" : \"mbox-parameter-value1\""))
                    XCTAssertTrue(prefetchJson.contains("\"a.OSVersion\""))
                    XCTAssertTrue(prefetchJson.contains("\"a.DeviceName\""))
                    XCTAssertTrue(prefetchJson.contains("\"a.AppID\""))
                    XCTAssertTrue(prefetchJson.contains("\"a.locale\""))

                } else {
                    Log.error(label: self.T_LOG_TAG, "Failed to parse the request payload [\(request.connectPayload)] to JSON object")
                    XCTFail("Failed to parse the request payload [\(request.connectPayload)] to JSON object")
                }
                networkRequestExpectation.fulfill()
            } // end if request.url.absoluteString.contains("https://amsdk.tt.omtrdc.net/rest/v1/delivery/?client=amsdk&sessionId=")
            return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
        }

        Target.prefetchContent(
            prefetchObjectArray: [
                TargetPrefetch(name: "Drink_1", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
                TargetPrefetch(name: "Drink_2", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
            ],
            targetParameters: TargetParameters(profileParameters: ["name": "Smith"])
        ) { error in
            if let error = error {
                Log.error(label: self.T_LOG_TAG, "Target.prefetchContent - failed, error:  \(String(describing: error))")
                XCTFail("Target.prefetchContent - failed, error: \(String(describing: error))")
            }
        }
        wait(for: [networkRequestExpectation], timeout: 1)
    }

    func skip_testRetrieveLocationContent() {
        let responseString = """
            {
              "status": 200,
              "id": {
                "tntId": "DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0",
                "marketingCloudVisitorId": "61055260263379929267175387965071996926"
              },
              "requestId": "01d4a408-6978-48f7-95c6-03f04160b257",
              "client": "acopprod3",
              "edgeHost": "mboxedge35.tt.omtrdc.net",
              "prefetch": {
                "mboxes": [
                  {
                    "index": 0,
                    "name": "t_test_01",
                    "options": [
                      {
                        "content": {
                          "key1": "value1"
                        },
                        "type": "json",
                        "eventToken": "uR0kIAPO+tZtIPW92S0NnWqipfsIHvVzTQxHolz2IpSCnQ9Y9OaLL2gsdrWQTvE54PwSz67rmXWmSnkXpSSS2Q=="
                      }
                    ]
                  }
                ]
              }
            }
        """
        let validResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)

        // init mobile SDK, register extensions
        let initExpectation = XCTestExpectation(description: "init extensions")
        MobileCore.setLogLevel(.trace)
        MobileCore.registerExtensions([Target.self, Identity.self, Lifecycle.self]) {
            initExpectation.fulfill()
        }
        wait(for: [initExpectation], timeout: 1)

        // update the configuration's shared state
        MobileCore.updateConfigurationWith(configDict: [
            "experienceCloud.org": "orgid",
            "experienceCloud.server": "test.com",
            "global.privacy": "optedin",
            "target.server": "amsdk.tt.omtrdc.net",
            "target.clientCode": "amsdk",
            "analytics.server": "test.analytics.net",
            "analytics.rsids": "abc",
            "analytics.batchLimit": 0,
            "analytics.aamForwardingEnabled": true,
            "analytics.backdatePreviousSessionInfo": true,
            "analytics.offlineEnabled": false,
            "analytics.launchHitDelay": 0,
        ])

        let targetRequestExpectation = XCTestExpectation(description: "monitor the target request")
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            if request.url.absoluteString.contains("https://amsdk.tt.omtrdc.net/rest/v1/delivery/?client=amsdk&sessionId=") {
//                targetRequestExpectation.fulfill()
                return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
            }
            return nil
        }
        let retrieveRequest = TargetRequest(mboxName: "t_test_01", defaultContent: "content") { content in
            print(content)
        }
        Target.retrieveLocationContent(requests: [retrieveRequest], targetParameters: nil)
        wait(for: [targetRequestExpectation], timeout: 1)
    }

    func testThirdPartyId() {
        // init mobile SDK, register extensions
        let initExpectation = XCTestExpectation(description: "init extensions")
        MobileCore.setLogLevel(.trace)
        MobileCore.registerExtensions([Target.self]) {
            initExpectation.fulfill()
        }
        wait(for: [initExpectation], timeout: 1)

        // update the configuration's shared state
        MobileCore.updateConfigurationWith(configDict: [
            "experienceCloud.org": "orgid",
            "experienceCloud.server": "test.com",
            "global.privacy": "optedin",
            "target.server": "amsdk.tt.omtrdc.net",
            "target.clientCode": "amsdk",
        ])

        let getErrorExpectation = XCTestExpectation(description: "init extensions")
        Target.getThirdPartyId { id, error in
            if id == nil, let _ = error {
                getErrorExpectation.fulfill()
                return
            }
            XCTFail("should return error if no third party id exists")
        }
        wait(for: [getErrorExpectation], timeout: 1)
        Target.setThirdPartyId("third_party_id")
        let getThirdPartyIdExpectation = XCTestExpectation(description: "init extensions")
        Target.getThirdPartyId { id, error in
            if error == nil, let id = id {
                XCTAssertEqual("third_party_id", id)
                getThirdPartyIdExpectation.fulfill()
                return
            }
            XCTFail("should return the stored third part id if exists")
        }
        wait(for: [getThirdPartyIdExpectation], timeout: 1)
    }

    func testGetTntId() {
        // init mobile SDK, register extensions
        let initExpectation = XCTestExpectation(description: "init extensions")
        MobileCore.setLogLevel(.trace)
        MobileCore.registerExtensions([Target.self]) {
            initExpectation.fulfill()
        }
        wait(for: [initExpectation], timeout: 1)

        // update the configuration's shared state
        MobileCore.updateConfigurationWith(configDict: [
            "experienceCloud.org": "orgid",
            "experienceCloud.server": "test.com",
            "global.privacy": "optedin",
            "target.server": "amsdk.tt.omtrdc.net",
            "target.clientCode": "amsdk",
        ])

        let getErrorExpectation = XCTestExpectation(description: "init extensions")
        Target.getTntId { id, error in
            if id == nil, let _ = error {
                getErrorExpectation.fulfill()
                return
            }
            XCTFail("should return error if no tnt id exists")
        }
        wait(for: [getErrorExpectation], timeout: 1)
    }

    func testResetExperience() {
        // init mobile SDK, register extensions
        let initExpectation = XCTestExpectation(description: "init extensions")
        MobileCore.setLogLevel(.trace)
        MobileCore.registerExtensions([Target.self]) {
            initExpectation.fulfill()
        }
        wait(for: [initExpectation], timeout: 1)

        // update the configuration's shared state
        MobileCore.updateConfigurationWith(configDict: [
            "experienceCloud.org": "orgid",
            "experienceCloud.server": "test.com",
            "global.privacy": "optedin",
            "target.server": "amsdk.tt.omtrdc.net",
            "target.clientCode": "amsdk",
        ])

        Target.setThirdPartyId("third_party_id")
        let getThirdPartyIdExpectation = XCTestExpectation(description: "init extensions")
        Target.getThirdPartyId { id, error in
            if error == nil, let id = id {
                XCTAssertEqual("third_party_id", id)
                getThirdPartyIdExpectation.fulfill()
                return
            }
            XCTFail("should return the stored third part id if exists")
        }
        wait(for: [getThirdPartyIdExpectation], timeout: 1)

        Target.resetExperience()

        let getErrorExpectation = XCTestExpectation(description: "init extensions")
        Target.getThirdPartyId { id, error in
            if id == nil, let _ = error {
                getErrorExpectation.fulfill()
                return
            }
            XCTFail("should return error if no third party id exists")
        }
        wait(for: [getErrorExpectation], timeout: 1)
    }

//    func testClearPrefetchCache() {}

//    func testSetPreviewRestartDeepLink() {}

    func testDisplayedLocations() {
        let responseString = """
            {
              "status": 200,
              "id": {
                "tntId": "DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0",
                "marketingCloudVisitorId": "61055260263379929267175387965071996926"
              },
              "requestId": "01d4a408-6978-48f7-95c6-03f04160b257",
              "client": "acopprod3",
              "edgeHost": "mboxedge35.tt.omtrdc.net",
              "prefetch": {
                "mboxes": [
                  {
                    "index": 0,
                    "name": "mboxName1",
                    "options": [
                      {
                        "content": {
                          "key1": "value1"
                        },
                        "type": "json",
                        "eventToken": "uR0kIAPO+tZtIPW92S0NnWqipfsIHvVzTQxHolz2IpSCnQ9Y9OaLL2gsdrWQTvE54PwSz67rmXWmSnkXpSSS2Q=="
                      }
                    ],
                    "state": "state1",
                    "analytics": {
                      "payload": {
                        "pe": "tnt",
                        "tnta": "285408:0:0|2"
                      }
                    }
                  },
                  {
                    "index": 1,
                    "name": "mboxName2",
                    "options": [
                      {
                        "content": {
                          "key1": "value1"
                        },
                        "type": "json",
                        "eventToken": "uR0kIAPO+tZtIPW92S0NnWqipfsIHvVzTQxHolz2IpSCnQ9Y9OaLL2gsdrWQTvE54PwSz67rmXWmSnkXpSSS2Q=="
                      }
                    ],
                    "state": "state2",
                    "analytics": {
                      "payload": {
                        "pe": "tnt",
                        "tnta": "285408:0:0|2"
                      }
                    }
                  }
                ]
              }
            }
        """
        let validResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)

        // init mobile SDK, register extensions
        let initExpectation = XCTestExpectation(description: "init extensions")
        MobileCore.setLogLevel(.trace)
        MobileCore.registerExtensions([Target.self, Analytics.self, Identity.self, Lifecycle.self]) {
            initExpectation.fulfill()
        }
        wait(for: [initExpectation], timeout: 1)

        // update the configuration's shared state
        MobileCore.updateConfigurationWith(configDict: [
            "experienceCloud.org": "orgid",
            "experienceCloud.server": "test.com",
            "global.privacy": "optedin",
            "target.server": "amsdk.tt.omtrdc.net",
            "target.clientCode": "amsdk",
            "analytics.server": "test.analytics.net",
            "analytics.rsids": "abc",
            "analytics.batchLimit": 0,
            "analytics.aamForwardingEnabled": true,
            "analytics.backdatePreviousSessionInfo": true,
            "analytics.offlineEnabled": false,
            "analytics.launchHitDelay": 0,
        ])

        let targetRequestExpectation = XCTestExpectation(description: "monitor the target request")
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            if request.url.absoluteString.contains("https://amsdk.tt.omtrdc.net/rest/v1/delivery/?client=amsdk&sessionId=") {
                if request.connectPayload.contains("ADCKKBC") {
                    targetRequestExpectation.fulfill()
                    return nil
                } else {
                    return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
                }
            }
            if request.url.absoluteString.contains("https://test.analytics.net/b/ss/abc") {
                /// https://git.corp.adobe.com/dms-mobile/bourbon-core-cpp-analytics/blob/be9e093adae276617e984bf4ecf4934d196c149a/code/src/analytics/Analytics.cpp#L103
                /// https://github.com/adobe/aepsdk-analytics-ios/blob/ec25108e075c6f0b24b64f0dcfe0c808fc501c9e/AEPAnalytics/Sources/Analytics.swift#L287
                /// a4t event not being processed in Analytics extension
            }

            return nil
        }
        Target.prefetchContent(
            prefetchObjectArray: [TargetPrefetch(name: "mboxName1", targetParameters: nil), TargetPrefetch(name: "mboxName2", targetParameters: nil)],
            targetParameters: nil,
            completion: nil
        )
        Target.displayedLocations(
            names: ["mboxName1", "mboxName2"],
            targetParameters: TargetParameters(
                parameters: nil,
                profileParameters: nil,
                order: TargetOrder(id: "ADCKKBC", total: 400.50, purchasedProductIds: ["34", "125"]),
                product: TargetProduct(productId: "24D334", categoryId: "Stationary")
            )
        )
        wait(for: [targetRequestExpectation], timeout: 1)
    }

    func testClickedLocation() {
        let responseString = """
            {
              "status": 200,
              "id": {
                "tntId": "DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0",
                "marketingCloudVisitorId": "61055260263379929267175387965071996926"
              },
              "requestId": "01d4a408-6978-48f7-95c6-03f04160b257",
              "client": "acopprod3",
              "edgeHost": "mboxedge35.tt.omtrdc.net",
              "prefetch": {
                "mboxes": [
                  {
                    "index": 0,
                    "name": "mboxName1",
                    "options": [
                      {
                        "content": {
                          "key1": "value1"
                        },
                        "type": "json",
                        "eventToken": "uR0kIAPO+tZtIPW92S0NnWqipfsIHvVzTQxHolz2IpSCnQ9Y9OaLL2gsdrWQTvE54PwSz67rmXWmSnkXpSSS2Q=="
                      }
                    ],
                    "metrics": [
                      {
                        "type": "click",
                        "selector": "#app > DIV:nth-of-type(1) > DIV:nth-of-type(2) > SECTION.section:eq(0) > DIV.container:eq(0) > FORM.col-md-4:eq(0) > DIV.form-group:eq(0) > BUTTON.btn:eq(0)",
                        "eventToken": "QPaLjCeI9qKCBUylkRQKBg=="
                      }
                    ],
                    "state": "state1",
                    "analytics": {
                      "payload": {
                        "pe": "tnt",
                        "tnta": "285408:0:0|2"
                      }
                    }
                  },
                  {
                    "index": 1,
                    "name": "mboxName2",
                    "options": [
                      {
                        "content": {
                          "key1": "value1"
                        },
                        "type": "json",
                        "eventToken": "uR0kIAPO+tZtIPW92S0NnWqipfsIHvVzTQxHolz2IpSCnQ9Y9OaLL2gsdrWQTvE54PwSz67rmXWmSnkXpSSS2Q=="
                      }
                    ],
                    "state": "state2",
                    "analytics": {
                      "payload": {
                        "pe": "tnt",
                        "tnta": "285408:0:0|2"
                      }
                    }
                  }
                ]
              }
            }
        """
        let validResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)

        // init mobile SDK, register extensions
        let initExpectation = XCTestExpectation(description: "init extensions")
        MobileCore.setLogLevel(.trace)
        MobileCore.registerExtensions([Target.self, Analytics.self, Identity.self, Lifecycle.self]) {
            initExpectation.fulfill()
        }
        wait(for: [initExpectation], timeout: 1)

        // update the configuration's shared state
        MobileCore.updateConfigurationWith(configDict: [
            "experienceCloud.org": "orgid",
            "experienceCloud.server": "test.com",
            "global.privacy": "optedin",
            "target.server": "amsdk.tt.omtrdc.net",
            "target.clientCode": "amsdk",
            "analytics.server": "test.analytics.net",
            "analytics.rsids": "abc",
            "analytics.batchLimit": 0,
            "analytics.aamForwardingEnabled": true,
            "analytics.backdatePreviousSessionInfo": true,
            "analytics.offlineEnabled": false,
            "analytics.launchHitDelay": 0,
        ])

        let targetRequestExpectation = XCTestExpectation(description: "monitor the target request")
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            if request.url.absoluteString.contains("https://amsdk.tt.omtrdc.net/rest/v1/delivery/?client=amsdk&sessionId=") {
                if request.connectPayload.contains("ADCKKBC") {
                    targetRequestExpectation.fulfill()
                    return nil
                } else {
                    return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
                }
            }
            return nil
        }
        Target.prefetchContent(
            prefetchObjectArray: [TargetPrefetch(name: "mboxName1", targetParameters: nil), TargetPrefetch(name: "mboxName2", targetParameters: nil)],
            targetParameters: nil,
            completion: nil
        )

        Target.clickedLocation(
            name: "mboxName1",
            targetParameters: TargetParameters(
                parameters: nil,
                profileParameters: nil,
                order: TargetOrder(id: "ADCKKBC", total: 400.50, purchasedProductIds: ["34", "125"]),
                product: TargetProduct(productId: "24D334", categoryId: "Stationary")
            )
        )
        wait(for: [targetRequestExpectation], timeout: 1)
    }
}
