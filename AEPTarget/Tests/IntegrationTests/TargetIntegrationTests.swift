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
        Target.isResponseListenerRegister = false
        let unregisterExpectation = XCTestExpectation(description: "Unregister extension.")
        unregisterExpectation.expectedFulfillmentCount = 1
        MobileCore.unregisterExtension(Target.self) {
            unregisterExpectation.fulfill()
        }
        wait(for: [unregisterExpectation], timeout: 1)
    }

    private func waitForLatestSettledSharedState(_ extensionName: String, timeout: Double = 1, triggerEvent: Event? = nil) -> [String: Any]? {
        var sharedState: [String: Any]?
        let sharedStateExpectation = XCTestExpectation(description: "wait for the latest shared state of \(extensionName)")
        sharedStateExpectation.expectedFulfillmentCount = 1
        MobileCore.registerEventListener(type: "com.adobe.eventType.hub", source: "com.adobe.eventSource.sharedState") { event in
            if let data = event.data, data["stateowner"] as? String == extensionName {
                let result = EventHub.shared.getSharedState(extensionName: extensionName, event: triggerEvent != nil ? triggerEvent : event)
                if let result = result, result.status == .set {
                    sharedState = result.value
                    sharedStateExpectation.fulfill()
                } else {
                    Log.error(label: self.T_LOG_TAG, "[\(extensionName)'s shared state: \n status = \(String(describing: result?.status.rawValue)) \n value = \(String(describing: result?.value))]")
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
            "target.clientCode": "acopprod3",
        ])
        guard let config = waitForLatestSettledSharedState("com.adobe.module.configuration", timeout: 2) else {
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
        let triggerEvent = Event(name: "trigger event", type: "test.type", source: "test.source", data: nil)
        MobileCore.dispatch(event: triggerEvent)
        // verify the identity's shared state
        guard let identity = waitForLatestSettledSharedState("com.adobe.module.identity", timeout: 2, triggerEvent: triggerEvent) else {
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
            if request.url.absoluteString.contains("https://amsdk.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId=") {
                if let payloadDictionary = try? JSONSerialization.jsonObject(with: request.connectPayload, options: .allowFragments) as? [String: Any]
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
//                          "authenticatedState": "authenticated"
//                        },
//                        {
//                          "id": "vid_id_2",
//                          "integrationCode": "vid_type_2",
//                          "authenticatedState": "authenticated"
//                        }
//                      ]
//                    }
                    let customerIdsJson = self.prettifyJsonArray(customerIds)
                    XCTAssertTrue(customerIdsJson.contains("\"integrationCode\" : \"vid_type_1\""))
                    XCTAssertTrue(customerIdsJson.contains("\"id\" : \"vid_id_2\""))
                    XCTAssertTrue(customerIdsJson.contains("\"authenticatedState\" : \"authenticated\""))

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
            } // end if request.url.absoluteString.contains("https://acopprod3.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId=")
            return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
        }

        Target.prefetchContent(
            [
                TargetPrefetch(name: "Drink_1", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
                TargetPrefetch(name: "Drink_2", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
            ],
            with: TargetParameters(profileParameters: ["name": "Smith"])
        ) { error in
            if let error = error {
                Log.error(label: self.T_LOG_TAG, "Target.prefetchContent - failed, error:  \(String(describing: error))")
                XCTFail("Target.prefetchContent - failed, error: \(String(describing: error))")
            }
        }
        wait(for: [networkRequestExpectation], timeout: 1)
    }

    func testRetrieveLocationContent() {
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
              "execute": {
                "mboxes": [
                  {
                    "index": 0,
                    "name": "t_test_01",
                    "options": [
                      {
                        "content": "someContent1",
                        "type": "html"
                      }
                    ]
                  },
                  {
                    "index": 0,
                    "name": "t_test_02",
                    "options": [
                      {
                        "content": "someContent2",
                        "type": "html"
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
            "target.clientCode": "acopprod3",
        ])

        let targetRequestExpectation = XCTestExpectation(description: "monitor the target request")
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            if request.url.absoluteString.contains("https://amsdk.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId=") {
                return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
            }
            return nil
        }
        let retrieveRequest1 = TargetRequest(mboxName: "t_test_01",
                                             defaultContent: "default_content1") { content in
            XCTAssertEqual("someContent1", content)
            targetRequestExpectation.fulfill()
        }
        let retrieveRequest2 = TargetRequest(mboxName: "t_test_02",
                                             defaultContent: "default_content2") { content, data in
            XCTAssertEqual("someContent2", content)
            XCTAssertNil(data)
            targetRequestExpectation.fulfill()
        }
        Target.retrieveLocationContent([retrieveRequest1, retrieveRequest2])
        wait(for: [targetRequestExpectation], timeout: 1)
    }

    func testRetrieveLocationContent_defaultContentWhenNoTargetResponseContent() {
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
              "execute": {
                "mboxes": [
                  {
                    "index": 0,
                    "name": "t_test_01"
                  },
                  {
                    "index": 1,
                    "name": "t_test_02"
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
            "target.clientCode": "acopprod3",
        ])

        let targetRequestExpectation = XCTestExpectation(description: "Should return default content when no content is returned from Target.")
        targetRequestExpectation.expectedFulfillmentCount = 2
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            if request.url.absoluteString.contains("https://amsdk                                                                                            .tt.omtrdc.net/rest/v1/delivery/?client=amsdk&sessionId=") {
                return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
            }
            return nil
        }
        let retrieveRequest1 = TargetRequest(mboxName: "t_test_01",
                                             defaultContent: "default_content1") { content in
            XCTAssertEqual("default_content1", content)
            targetRequestExpectation.fulfill()
        }
        let retrieveRequest2 = TargetRequest(mboxName: "t_test_02",
                                             defaultContent: "default_content2") { content, data in
            XCTAssertEqual("default_content2", content)
            XCTAssertNil(data)
            targetRequestExpectation.fulfill()
        }
        Target.retrieveLocationContent([retrieveRequest1, retrieveRequest2])
        wait(for: [targetRequestExpectation], timeout: 1)
    }

    func testRetrieveLocationContent_defaultContentOnTargetServerError() {
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
            "target.clientCode": "acopprod3",
        ])

        let targetRequestExpectation = XCTestExpectation(description: "retrieveLocationContent should return default content when response indicates server error.")
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            if request.url.absoluteString.contains("https://amsdk                                                                   .tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId=") {
                let response = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 500, httpVersion: nil, headerFields: nil)
                return (data: nil, response: response, error: nil)
            }
            return nil
        }
        let retrieveRequest = TargetRequest(mboxName: "t_test_01",
                                            defaultContent: "default_content1") { content, data in
            XCTAssertEqual("default_content1", content)
            XCTAssertNil(data)
            targetRequestExpectation.fulfill()
        }

        Target.retrieveLocationContent([retrieveRequest])
        wait(for: [targetRequestExpectation], timeout: 1)
    }

    func testRetrieveLocationContent_afterPrefetch() {
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
                        "content": "someContent1",
                        "type": "html"
                      }
                    ],
                    "eventToken": "uR0kIAPO+tZtIPW92S0NnWqipfsIHvVzTQxHolz2IpSCnQ9Y9OaLL2gsdrWQTvE54PwSz67rmXWmSnkXpSSS2Q=="
                  },
                  {
                    "index": 1,
                    "name": "t_test_02",
                    "options": [
                      {
                        "content": "someContent2",
                        "type": "html"
                      }
                    ],
                    "eventToken": "mKH481kPwvU9+su+8rbG4GqipfsIHvVzTQxHolz2IpSCnQ9Y9OaLL2gsdrWQTvE54PwSz67rmXWmSnkXpSSS2Q=="
                  }
                ]
              }
            }
        """
        let validResponse = HTTPURLResponse(url: URL(string: "https://acopprod3.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)

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
            "target.clientCode": "acopprod3",
        ])

        let prefetchExpectation = XCTestExpectation(description: "prefetchContent should prefetch content without error.")
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            if request.url.absoluteString.contains("https://acopprod3.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId=") {
                return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
            }

            if request.url.absoluteString.contains("https://mboxedge35.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId=") {
                XCTFail("retrieveLocationContant should not send a network request to Target if requested mboxes are already prefetched.")
                return nil
            }
            return nil
        }

        Target.prefetchContent([
            TargetPrefetch(name: "t_test_01", targetParameters: nil),
            TargetPrefetch(name: "t_test_02", targetParameters: nil),
        ]) { error in
            if let error = error {
                Log.error(label: self.T_LOG_TAG, "Target.prefetchContent - failed, error:  \(String(describing: error))")
                XCTFail("Target.prefetchContent - failed, error: \(String(describing: error))")
            }
            prefetchExpectation.fulfill()
        }
        wait(for: [prefetchExpectation], timeout: 1)

        let targetRequestExpectation = XCTestExpectation(description: "retrieveLocationContent should return prefetched content for the given mboxes.")
        targetRequestExpectation.expectedFulfillmentCount = 2
        let retrieveRequest1 = TargetRequest(mboxName: "t_test_01",
                                             defaultContent: "default_content1") { content in
            XCTAssertEqual("someContent1", content)
            targetRequestExpectation.fulfill()
        }
        let retrieveRequest2 = TargetRequest(mboxName: "t_test_02",
                                             defaultContent: "default_content2") { content, data in
            XCTAssertEqual("someContent2", content)
            XCTAssertNil(data)
            targetRequestExpectation.fulfill()
        }
        Target.retrieveLocationContent([retrieveRequest1, retrieveRequest2])
        wait(for: [targetRequestExpectation], timeout: 1)
    }

    func testRetrieveLocationContent_withA4TAndResponseTokens() {
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
              "execute": {
                "mboxes": [
                  {
                    "index": 0,
                    "name": "t_test_01",
                    "options": [
                      {
                        "content": "someContent",
                        "type": "html",
                        "responseTokens":{
                            "activity.name":"My test activity"
                        }
                      }
                    ],
                    "analytics":{
                        "payload":{
                            "pe":"tnt",
                            "tnta":"331289:0:0|2|1,331289:0:0|32767|1"
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
            "target.clientCode": "acopprod3",
        ])

        let targetRequestExpectation = XCTestExpectation(description: "retrieveLocationContent should return A4T payload and response tokens.")
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            if request.url.absoluteString.contains("https://amsdk.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId=") {
                return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
            }
            return nil
        }

        let retrieveRequest = TargetRequest(mboxName: "t_test_01",
                                            defaultContent: "default_content") { content, data in
            XCTAssertEqual("someContent", content)

            guard let data = data else {
                XCTFail("Data containing A4T payload and response tokens should be valid.")
                return
            }
            let analyticsPayload = data["analytics.payload"] as? [String: String]
            XCTAssertEqual(2, analyticsPayload?.count)
            XCTAssertEqual("tnt", analyticsPayload?["pe"])
            XCTAssertEqual("331289:0:0|2|1,331289:0:0|32767|1", analyticsPayload?["tnta"])

            let responseTokens = data["responseTokens"] as? [String: String]
            XCTAssertEqual(1, responseTokens?.count)
            XCTAssertEqual("My test activity", responseTokens?["activity.name"])
            targetRequestExpectation.fulfill()
        }

        Target.retrieveLocationContent([retrieveRequest])
        wait(for: [targetRequestExpectation], timeout: 1)
    }

    func testRetrieveLocationContent_afterPrefetchwithA4TAndResponseTokens() {
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
                        "content": "someContent",
                        "type": "html",
                        "responseTokens":{
                            "activity.name":"My test activity"
                        },
                        "eventToken": "uR0kIAPO+tZtIPW92S0NnWqipfsIHvVzTQxHolz2IpSCnQ9Y9OaLL2gsdrWQTvE54PwSz67rmXWmSnkXpSSS2Q=="
                      }
                    ],
                    "analytics":{
                        "payload":{
                            "pe":"tnt",
                            "tnta":"331289:0:0|2|1,331289:0:0|32767|1"
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
            "target.clientCode": "acopprod3",
        ])

        let prefetchExpectation = XCTestExpectation(description: "Should return A4T payload and response tokens")
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            if request.url.absoluteString.contains("https://amsdk.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId=") {
                return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
            }
            return nil
        }

        Target.prefetchContent([
            TargetPrefetch(name: "t_test_01", targetParameters: nil),
        ],
                               with: TargetParameters(profileParameters: ["name": "Smith"])) { error in
            if let error = error {
                Log.error(label: self.T_LOG_TAG, "Target.prefetchContent - failed, error:  \(String(describing: error))")
                XCTFail("Target.prefetchContent - failed, error: \(String(describing: error))")
            }
            prefetchExpectation.fulfill()
        }
        wait(for: [prefetchExpectation], timeout: 1)

        let targetRequestExpectation = XCTestExpectation(description: "retrieveLocationContent should return A4T payload and response tokens cached on prefetch.")
        let retrieveRequest = TargetRequest(mboxName: "t_test_01",
                                            defaultContent: "default_content") { content, data in
            XCTAssertEqual("someContent", content)

            guard let data = data else {
                XCTFail("Data containing A4T payload and response tokens should be valid.")
                return
            }
            let analyticsPayload = data["analytics.payload"] as? [String: String]
            XCTAssertEqual(2, analyticsPayload?.count)
            XCTAssertEqual("tnt", analyticsPayload?["pe"])
            XCTAssertEqual("331289:0:0|2|1,331289:0:0|32767|1", analyticsPayload?["tnta"])

            let responseTokens = data["responseTokens"] as? [String: String]
            XCTAssertEqual(1, responseTokens?.count)
            XCTAssertEqual("My test activity", responseTokens?["activity.name"])
            targetRequestExpectation.fulfill()
        }
        Target.retrieveLocationContent([retrieveRequest])
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
            "target.clientCode": "acopprod3",
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
    
    func testSessionId() {
        // init mobile SDK, register extensions
        let initExpectation = XCTestExpectation(description: "init extensions")
        MobileCore.setLogLevel(.trace)
        MobileCore.registerExtensions([Target.self]) {
            initExpectation.fulfill()
        }
        wait(for: [initExpectation], timeout: 1)

        // update the configuration shared state
        MobileCore.updateConfigurationWith(configDict: [
            "experienceCloud.org": "orgid",
            "experienceCloud.server": "test.com",
            "global.privacy": "optedin",
            "target.server": "acopprod3.tt.omtrdc.net",
            "target.clientCode": "acopprod3",
        ])

        let getSessionIdExpectation = XCTestExpectation(description: "get session Id")
        Target.getSessionId { id, error in
            if error == nil, let id = id {
                XCTAssertNotEqual("", id)
                getSessionIdExpectation.fulfill()
                return
            }
            XCTFail("Should return a valid Target session Id.")
        }
        wait(for: [getSessionIdExpectation], timeout: 1)
        
        Target.setSessionId("mockSessionId")
        
        let getNewSessionIdExpectation = XCTestExpectation(description: "get new session Id")
        Target.getSessionId { id, error in
            if error == nil, let id = id {
                XCTAssertEqual("mockSessionId", id)
                getNewSessionIdExpectation.fulfill()
                return
            }
            XCTFail("Should return the previously set session Id.")
        }
        wait(for: [getNewSessionIdExpectation], timeout: 1)
    }

    func testTntId() {
        // init mobile SDK, register extensions
        let initExpectation = XCTestExpectation(description: "init extensions")
        MobileCore.setLogLevel(.trace)
        MobileCore.registerExtensions([Target.self]) {
            initExpectation.fulfill()
        }
        wait(for: [initExpectation], timeout: 1)

        // update the configuration shared state
        MobileCore.updateConfigurationWith(configDict: [
            "experienceCloud.org": "orgid",
            "experienceCloud.server": "test.com",
            "global.privacy": "optedin",
            "target.server": "acopprod3.tt.omtrdc.net",
            "target.clientCode": "acopprod3",
        ])

        let getErrorExpectation = XCTestExpectation(description: "error expectation")
        Target.getTntId { id, error in
            if id == nil, let _ = error {
                getErrorExpectation.fulfill()
                return
            }
            XCTFail("should return error if no tnt Id exists")
        }
        wait(for: [getErrorExpectation], timeout: 1)

        Target.setTntId("66E5C681-4F70-41A2-86AE-F1E151443B10.35_0")
        let getTntIdExpectation = XCTestExpectation(description: "get tnt Id expectation")
        Target.getTntId { id, error in
            if error == nil, let id = id {
                XCTAssertEqual("66E5C681-4F70-41A2-86AE-F1E151443B10.35_0", id)
                getTntIdExpectation.fulfill()
                return
            }
            XCTFail("should return the stored tnt Id if it exists")
        }
        wait(for: [getTntIdExpectation], timeout: 1)
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
            "target.clientCode": "acopprod3",
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
            "target.clientCode": "acopprod3",
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
            if request.url.absoluteString.contains("https://amsdk.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId=") {
                let connectPayloadString = String(decoding: request.connectPayload, as: UTF8.self)
                if connectPayloadString.contains("ADCKKBC") {
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
            [TargetPrefetch(name: "mboxName1", targetParameters: nil), TargetPrefetch(name: "mboxName2", targetParameters: nil)],
            nil
        )
        Target.displayedLocations(
            ["mboxName1", "mboxName2"],
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
            "target.clientCode": "acopprod3",
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
            if request.url.absoluteString.contains("https://amsdk.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId=") {
                let connectPayloadString = String(decoding: request.connectPayload, as: UTF8.self)
                if connectPayloadString.contains("ADCKKBC") {
                    targetRequestExpectation.fulfill()
                    return nil
                } else {
                    return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
                }
            }
            return nil
        }
        Target.prefetchContent(
            [TargetPrefetch(name: "mboxName1", targetParameters: nil), TargetPrefetch(name: "mboxName2", targetParameters: nil)],
            nil
        )

        Target.clickedLocation(
            "mboxName1",
            targetParameters: TargetParameters(
                parameters: nil,
                profileParameters: nil,
                order: TargetOrder(id: "ADCKKBC", total: 400.50, purchasedProductIds: ["34", "125"]),
                product: TargetProduct(productId: "24D334", categoryId: "Stationary")
            )
        )
        wait(for: [targetRequestExpectation], timeout: 1)
    }

    func testClickedLocation_withA4TClickMetricForPrefetchedMbox() {
        let responseString = """
            {
               "status":200,
               "requestId":"602c9986-ae9e-48e9-b35b-45b14d589703",
               "client":"acopprod3",
               "id":{
                  "tntId":"55508C70-F530-4E33-AAD2-F09BB99C5C3E.35_0",
                  "marketingCloudVisitorId":"32943535451574954856183504879211787972"
               },
               "edgeHost":"mboxedge35.tt.omtrdc.net",
               "prefetch":{
                  "mboxes":[
                     {
                        "index":0,
                        "name":"mboxName1",
                        "state":"HGGFUlY2Hmffsj5VuZfIKvOoZVgDVZNvMSVRJkhvV+1BQzL9/VYMJF0oT8y0dzKFFVP/IVnGUuOesmpjkWvCWA==",
                        "options":[
                           {
                              "content":"someContent1",
                              "type":"html",
                              "eventToken":"mKH481kPwvU9+su+8rbG4GqipfsIHvVzTQxHolz2IpSCnQ9Y9OaLL2gsdrWQTvE54PwSz67rmXWmSnkXpSSS2Q==",
                              "sourceType":"target"
                           }
                        ],
                        "metrics":[
                           {
                              "type":"click",
                              "eventToken":"ABPi/uih7s0vo6/8kqyxjA==",
                              "analytics":{
                                 "payload":{
                                    "pe":"tnt",
                                    "tnta":"409277:0:0|32767"
                                 }
                              }
                           }
                        ],
                        "analytics":{
                           "payload":{
                              "pe":"tnt",
                              "tnta":"409277:0:0|2,409277:0:0|1"
                           }
                        }
                     },
                     {
                        "index":1,
                        "name":"mboxName2",
                        "state":"HGGFUlY2Hmffsj5VuZfIKvOoZVgDVZNvMSVRJkhvV+1BQzL9/VYMJF0oT8y0dzKFFVP/IVnGUuOesmpjkWvCWA==",
                        "options":[
                           {
                              "content":"someContent2",
                              "type":"html",
                              "eventToken":"/CB0Gnng3tuikitYzXjtYGqipfsIHvVzTQxHolz2IpSCnQ9Y9OaLL2gsdrWQTvE54PwSz67rmXWmSnkXpSSS2Q==",
                              "sourceType":"target"
                           }
                        ],
                        "analytics":{
                           "payload":{
                              "pe":"tnt",
                              "tnta":"331289:0:0|2,331289:0:0|32767,331289:0:0|1"
                           }
                        }
                     }
                  ]
               }
            }
        """

        // init mobile SDK, register extensions
        let initExpectation = XCTestExpectation(description: "Init extensions")
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
            "target.clientCode": "acopprod3",
            "target.server": "",
            "analytics.server": "test.analytics.net",
            "analytics.rsids": "abc",
            "analytics.batchLimit": 0,
            "analytics.aamForwardingEnabled": false,
            "analytics.backdatePreviousSessionInfo": false,
            "analytics.offlineEnabled": false,
            "analytics.launchHitDelay": 0,
        ])

        Analytics.clearQueue()
        sleep(2)

        let notificationExpectation = XCTestExpectation(description: "clickedLocation should send click notification to Target and hit containing a4t payload to Analytics.")
        notificationExpectation.expectedFulfillmentCount = 2
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            if request.url.absoluteString.contains("https://acopprod3.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId=") {
                let validResponse = HTTPURLResponse(url: URL(string: "https://acopprod3.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)

                return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
            }

            if request.url.absoluteString.contains("https://mboxedge35.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId=") {
                notificationExpectation.fulfill()
                return nil
            }

            if request.url.absoluteString.contains("https://test.analytics.net/b/ss/abc/0") {
                notificationExpectation.fulfill()
                return (data: nil,
                        response: HTTPURLResponse(url: URL(string: "https://test.analytics.net/b/ss/abc/0")!,
                                                  statusCode: 200,
                                                  httpVersion: nil,
                                                  headerFields: nil),
                        error: nil)
            }
            return nil
        }

        let prefetchExpectation = XCTestExpectation(description: "prefetchContent should prefetch content without error.")
        Target.prefetchContent([
            TargetPrefetch(name: "mboxName1", targetParameters: nil),
            TargetPrefetch(name: "mboxName2", targetParameters: nil),
        ]) { error in
            if let error = error {
                Log.error(label: self.T_LOG_TAG, "Target.prefetchContent - failed, error:  \(String(describing: error))")
                XCTFail("Target.prefetchContent - failed, error: \(String(describing: error))")
                return
            }
            prefetchExpectation.fulfill()
        }
        wait(for: [prefetchExpectation], timeout: 1)

        // In real customer scenario, there will be a display location notification request before click.

        Target.clickedLocation(
            "mboxName1",
            targetParameters: TargetParameters(
                parameters: nil,
                profileParameters: nil,
                order: TargetOrder(id: "ADCKKBC", total: 400.50, purchasedProductIds: ["34", "125"]),
                product: TargetProduct(productId: "24D334", categoryId: "Stationary")
            )
        )
        wait(for: [notificationExpectation], timeout: 2)
    }

    func testClickedLocation_withA4TClickMetricForLoadedMbox() {
        let responseString = """
            {
               "status":200,
               "requestId":"bce9dfed-5caf-41e7-9926-d84947c874fa",
               "client":"acopprod3",
               "id":{
                  "tntId":"55508C70-F530-4E33-AAD2-F09BB99C5C3E.35_0",
                  "marketingCloudVisitorId":"32943535451574954856183504879211787972"
               },
               "edgeHost":"mboxedge35.tt.omtrdc.net",
               "execute":{
                  "mboxes":[
                     {
                        "index":0,
                        "name":"mboxName1",
                        "options":[
                           {
                              "content":"someContent1",
                              "type":"html",
                              "sourceType":"target"
                           }
                        ],
                        "metrics":[
                           {
                              "type":"click",
                              "eventToken":"ABPi/uih7s0vo6/8kqyxjA==",
                              "analytics":{
                                 "payload":{
                                    "pe":"tnt",
                                    "tnta":"409277:0:0|32767|1"
                                 }
                              }
                           }
                        ],
                        "analytics":{
                           "payload":{
                              "pe":"tnt",
                              "tnta":"409277:0:0|2|1,409277:0:0|1|1"
                           }
                        }
                     },
                     {
                        "index":1,
                        "name":"mboxName2",
                        "options":[
                           {
                              "content":"someContent2",
                              "type":"html",
                              "sourceType":"target"
                           }
                        ],
                        "analytics":{
                           "payload":{
                              "pe":"tnt",
                              "tnta":"331289:0:0|2|1,331289:0:0|32767|1,331289:0:0|1|1"
                           }
                        }
                     }
                  ]
               }
            }
        """

        // init mobile SDK, register extensions
        let initExpectation = XCTestExpectation(description: "init extensions")
        MobileCore.setLogLevel(.trace)
        MobileCore.registerExtensions([Target.self, Analytics.self, Identity.self, Lifecycle.self]) {
            initExpectation.fulfill()
        }
        wait(for: [initExpectation], timeout: 2)

        // update the configuration's shared state
        MobileCore.updateConfigurationWith(configDict: [
            "experienceCloud.org": "orgid",
            "experienceCloud.server": "test.com",
            "global.privacy": "optedin",
            "target.server": "",
            "target.clientCode": "acopprod3",
            "analytics.server": "test.analytics.net",
            "analytics.rsids": "abc",
            "analytics.batchLimit": 0,
            "analytics.aamForwardingEnabled": false,
            "analytics.backdatePreviousSessionInfo": false,
            "analytics.offlineEnabled": false,
            "analytics.launchHitDelay": 0,
        ])

        Analytics.clearQueue()
        sleep(2)

        let notificationExpectation = XCTestExpectation(description: "clickedLocation should send click notification to Target and hit containing a4t payload to Analytics.")
        notificationExpectation.expectedFulfillmentCount = 2
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            if request.url.absoluteString.contains("https://acopprod3.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId=") {
                let validResponse = HTTPURLResponse(url: URL(string: "https://acopprod3.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)

                return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
            }

            if request.url.absoluteString.contains("https://mboxedge35.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId=") {
                notificationExpectation.fulfill()
                return nil
            }

            if request.url.absoluteString.contains("https://test.analytics.net/b/ss/abc/0") {
                notificationExpectation.fulfill()

                return (data: nil,
                        response: HTTPURLResponse(url: URL(string: "https://test.analytics.net/b/ss/abc/0")!,
                                                  statusCode: 200,
                                                  httpVersion: nil,
                                                  headerFields: nil),
                        error: nil)
            }
            return nil
        }

        let retrieveExpectation = XCTestExpectation(description: "retrieveLocationContent should return content and data from Target.")
        retrieveExpectation.expectedFulfillmentCount = 2
        retrieveExpectation.assertForOverFulfill = true

        Target.retrieveLocationContent([
            TargetRequest(mboxName: "mboxName1", defaultContent: "DefaultContent1") { content, data in
                XCTAssertEqual("someContent1", content)

                guard let data = data else {
                    XCTFail("Data containing A4T payload should be valid.")
                    return
                }
                XCTAssertEqual(2, data.count)

                guard let a4tPayload = data["analytics.payload"] as? [String: String] else {
                    XCTFail("Analytics payload should be present.")
                    return
                }
                XCTAssertEqual(2, a4tPayload.count)
                XCTAssertEqual("tnt", a4tPayload["pe"])
                XCTAssertEqual("409277:0:0|2|1,409277:0:0|1|1", a4tPayload["tnta"])

                guard let clickMetricA4tPayload = data["clickmetric.analytics.payload"] as? [String: String] else {
                    XCTFail("Click metric Analytics payload should be present.")
                    return
                }
                XCTAssertEqual(2, clickMetricA4tPayload.count)
                XCTAssertEqual("tnt", clickMetricA4tPayload["pe"])
                XCTAssertEqual("409277:0:0|32767|1", clickMetricA4tPayload["tnta"])

                retrieveExpectation.fulfill()
            },
            TargetRequest(mboxName: "mboxName2", defaultContent: "DefaultContent2") { content, data in
                XCTAssertEqual("someContent2", content)

                guard let data = data else {
                    XCTFail("Data containing A4T payload should be valid.")
                    return
                }
                XCTAssertEqual(1, data.count)

                guard let a4tPayload = data["analytics.payload"] as? [String: String] else {
                    XCTFail("Analytics payload should be present.")
                    return
                }
                XCTAssertEqual(2, a4tPayload.count)
                XCTAssertEqual("tnt", a4tPayload["pe"])
                XCTAssertEqual("331289:0:0|2|1,331289:0:0|32767|1,331289:0:0|1|1", a4tPayload["tnta"])

                retrieveExpectation.fulfill()
            },
        ],
                                       with: nil)
        wait(for: [retrieveExpectation], timeout: 1)

        Target.clickedLocation(
            "mboxName1",
            targetParameters: TargetParameters(
                parameters: nil,
                profileParameters: nil,
                order: TargetOrder(id: "ADCKKBC", total: 400.50, purchasedProductIds: ["34", "125"]),
                product: TargetProduct(productId: "24D334", categoryId: "Stationary")
            )
        )
        wait(for: [notificationExpectation], timeout: 2)
    }
    
    func testExecuteRawRequest() {
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
              "execute": {
                "mboxes": [
                  {
                    "index": 0,
                    "name": "t_test_01",
                    "options": [
                      {
                        "content": "someContent1",
                        "type": "html"
                      }
                    ]
                  },
                  {
                    "index": 0,
                    "name": "t_test_02",
                    "options": [
                      {
                        "content": "someContent2",
                        "type": "html"
                      }
                    ]
                  }
                ]
              }
            }
        """
        let validResponse = HTTPURLResponse(url: URL(string: "https://acopprod3.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)

        // init mobile SDK, register extensions
        let initExpectation = XCTestExpectation(description: "Init extensions expectation")
        MobileCore.setLogLevel(.trace)
        MobileCore.registerExtensions([Target.self, Identity.self, Lifecycle.self]) {
            initExpectation.fulfill()
        }
        wait(for: [initExpectation], timeout: 1)

        // update the configuration shared state
        MobileCore.updateConfigurationWith(configDict: [
            "experienceCloud.org": "orgid",
            "experienceCloud.server": "test.com",
            "global.privacy": "optedin",
            "target.clientCode": "acopprod3",
        ])

        let targetRequestExpectation = XCTestExpectation(description: "Target raw execute request expectation")
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            if request.url.absoluteString.contains("https://acopprod3.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId=") {
                return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
            }
            return nil
        }
        
        let rawRequest1: [String: Any] = [
            "name": "t_test_01",
            "parameters": [
                "mbox_parameter_key1": "mbox_parameter_value1"
            ]
        ]

        let rawRequest2: [String: Any] = [
            "name": "t_test_02",
            "parameters": [
                "mbox_parameter_key2": "mbox_parameter_value2"
            ]
        ]
        
        Target.executeRawRequest([rawRequest1, rawRequest2]) { response, err in
            if let err = err {
                XCTFail("Received error in execute response: \(err)")
                return
            }
            guard let response = response,
                  !response.isEmpty else {
                XCTFail("Received null or empty execute response")
                return
            }
            XCTAssertEqual(2, response.count)
            XCTAssertNotNil(response[0])
            XCTAssertEqual("t_test_01", response[0]["name"] as? String)
            let optionsArray_0 = response[0]["options"] as? [[String: Any]]
            XCTAssertEqual(1, optionsArray_0?.count)
            XCTAssertEqual("someContent1", optionsArray_0?[0]["content"] as? String)
            
            XCTAssertEqual("t_test_02", response[1]["name"] as? String)
            XCTAssertNotNil(response[1])
            let optionsArray_1 = response[1]["options"] as? [[String: Any]]
            XCTAssertEqual(1, optionsArray_1?.count)
            XCTAssertEqual("someContent2", optionsArray_1?[0]["content"] as? String)
            
            targetRequestExpectation.fulfill()
        }
        wait(for: [targetRequestExpectation], timeout: 2)
    }
    
    func testSendRawNotification() {
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
              "execute": {
                "mboxes": [
                  {
                    "index": 0,
                    "name": "mboxName1",
                    "options": [
                      {
                        "content": {
                          "key1": "value1"
                        },
                        "type": "json"
                      }
                    ],
                    "metrics": [
                      {
                        "type": "click",
                        "eventToken": "QPaLjCeI9qKCBUylkRQKBg==",
                        "analytics": {
                            "payload": {
                                "pe": "tnt",
                                "tnta": "285408:1:0|32767|1"
                            }
                        }
                      }
                    ],
                    "analytics": {
                      "payload": {
                        "pe": "tnt",
                        "tnta": "285408:1:0|2|1"
                      }
                    }
                  }
                ]
              }
            }
        """
        let validResponse = HTTPURLResponse(url: URL(string: "https://acopprod3.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)

        // init mobile SDK, register extensions
        let initExpectation = XCTestExpectation(description: "Init extensions expectation")
        MobileCore.setLogLevel(.trace)
        MobileCore.registerExtensions([Target.self, Analytics.self, Identity.self, Lifecycle.self]) {
            initExpectation.fulfill()
        }
        wait(for: [initExpectation], timeout: 1)

        // update the configuration shared state
        MobileCore.updateConfigurationWith(configDict: [
            "experienceCloud.org": "orgid",
            "experienceCloud.server": "test.com",
            "global.privacy": "optedin",
            "target.clientCode": "acopprod3",
            "analytics.server": "test.analytics.net",
            "analytics.rsids": "abc",
            "analytics.batchLimit": 0,
            "analytics.aamForwardingEnabled": true,
            "analytics.backdatePreviousSessionInfo": true,
            "analytics.offlineEnabled": false,
            "analytics.launchHitDelay": 0,
        ])
        
        Analytics.clearQueue()
        sleep(2)

        let targetNotificationExpectation = XCTestExpectation(description: "Target raw notification request expectation")
        targetNotificationExpectation.assertForOverFulfill = true
        
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            if request.url.absoluteString.contains("https://acopprod3.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId=") {
                return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
            }
            
            if request.url.absoluteString.contains("https://mboxedge35.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId=") {
                targetNotificationExpectation.fulfill()
                return nil
            }

            if request.url.absoluteString.contains("https://test.analytics.net/b/ss/abc/0") {
                targetNotificationExpectation.fulfill()
                return (data: nil,
                        response: HTTPURLResponse(url: URL(string: "https://test.analytics.net/b/ss/abc/0")!,
                                                  statusCode: 200,
                                                  httpVersion: nil,
                                                  headerFields: nil),
                        error: nil)
            }
            return nil
        }
        
        let targetRequestExpectation = XCTestExpectation(description: "Target raw execute request expectation")
        
        let rawRequest1: [String: Any] = [
            "name": "mboxName1"
        ]
        Target.executeRawRequest([rawRequest1]) { response, err in
            if let err = err {
                XCTFail("Received error in execute response: \(err)")
                return
            }
            guard let response = response,
                  !response.isEmpty else {
                XCTFail("Received null or empty execute response")
                return
            }
            targetRequestExpectation.fulfill()
        }
        wait(for: [targetRequestExpectation], timeout: 2)
        
        let notification: [String: Any] = [
            "name": "mboxName1",
            "tokens": [
                "QPaLjCeI9qKCBUylkRQKBg=="
            ]
        ]
        Target.sendRawNotification(notification)
        wait(for: [targetNotificationExpectation], timeout: 2)
    }
}
