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
import SwiftyJSON
import XCTest

class TargetPrefetchFunctionalTests: TargetFunctionalTestsBase {
    // MARK: - Prefetch

    func testPrefetchContent() {
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
                    "name": "Drink_1",
                    "options": [
                      {
                        "content": {
                          "key1": "value1"
                        },
                        "type": "json",
                        "eventToken": "uR0kIAPO+tZtIPW92S0NnWqipfsIHvVzTQxHolz2IpSCnQ9Y9OaLL2gsdrWQTvE54PwSz67rmXWmSnkXpSSS2Q=="
                      }
                    ]
                  },
                  {
                    "index": 1,
                    "name": "Drink_2"
                  }
                ]
              }
            }
        """

        // builds the prefetch event
        let prefetchDataArray: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_1", targetParameters: TargetParameters(parameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
            TargetPrefetch(name: "Drink_2", targetParameters: TargetParameters(parameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
        ].map {
            $0.asDictionary()
        }

        let data: [String: Any] = [
            "prefetch": prefetchDataArray,
            "targetparams": TargetParameters(profileParameters: ["name": "Smith"]).asDictionary() as Any,
        ]
        let prefetchEvent = Event(name: "", type: "", source: "", data: data)

        // creates a configuration's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: prefetchEvent, data: (value: mockConfigSharedState, status: .set))

        // creates a lifecycle's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.lifecycle", event: prefetchEvent, data: (value: mockLifecycleData, status: .set))

        // creates an identity's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: prefetchEvent, data: (value: mockIdentityData, status: .set))

        // registers the event listeners for Target extension
        target.onRegistered()

        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            // verifies network request
            XCTAssertNotNil(request)
            guard let payloadDictionary = self.payloadAsDictionary(request.connectPayload) else {
                XCTFail()
                return nil
            }
            XCTAssertTrue(request.url.absoluteString.contains("https://code_123.tt.omtrdc.net/rest/v1/delivery/?client=code_123&sessionId="))
            XCTAssertTrue(Set(payloadDictionary.keys) == Set([
                "id",
                "experienceCloud",
                "context",
                "prefetch",
                "environmentId",
            ]))

            // verifies payloadDictionary["id"]
            guard let idDictionary = payloadDictionary["id"] as? [String: Any] else {
                XCTFail()
                return nil
            }
            XCTAssertEqual("38209274908399841237725561727471528301", idDictionary["marketingCloudVisitorId"] as? String)
            guard let vids = idDictionary["customerIds"] as? [[String: Any]] else {
                XCTFail()
                return nil
            }
            XCTAssertEqual(1, vids.count)
            XCTAssertEqual("unknown", vids[0]["authenticatedState"] as? String)
            XCTAssertEqual("vid_id_1", vids[0]["id"] as? String)
            XCTAssertEqual("vid_type_1", vids[0]["integrationCode"] as? String)

            // verifies payloadDictionary["context"]
            guard let context = payloadDictionary["context"] as? [String: Any] else {
                XCTFail()
                return nil
            }
            XCTAssertTrue(Set(context.keys) == Set([
                "userAgent",
                "mobilePlatform",
                "screen",
                "channel",
                "application",
                "timeOffsetInMinutes",
            ]))

            // verifies payloadDictionary["prefetch"]
            guard let prefetchDictionary = payloadDictionary["prefetch"] as? [String: Any] else {
                XCTFail()
                return nil
            }

            XCTAssertTrue(Set(prefetchDictionary.keys) == Set([
                "mboxes",
            ]))

            let prefetchJson = JSON(parseJSON: self.prettify(prefetchDictionary))
            XCTAssertEqual(prefetchJson["mboxes"][0]["name"].stringValue, "Drink_1")
            XCTAssertEqual(prefetchJson["mboxes"][0]["index"].intValue, 0)
            XCTAssertEqual(prefetchJson["mboxes"][0]["parameters"]["mbox-parameter-key1"].stringValue, "mbox-parameter-value1")
            XCTAssertNotNil(prefetchJson["mboxes"][0]["parameters"]["a.OSVersion"].stringValue)
            XCTAssertNotNil(prefetchJson["mboxes"][0]["parameters"]["a.Resolution"].stringValue)
            XCTAssertNotNil(prefetchJson["mboxes"][0]["parameters"]["a.DeviceName"].stringValue)
            XCTAssertNotNil(prefetchJson["mboxes"][0]["parameters"]["a.RunMode"].stringValue)
            XCTAssertNotNil(prefetchJson["mboxes"][0]["parameters"]["a.AppID"].stringValue)
            XCTAssertNotNil(prefetchJson["mboxes"][0]["parameters"]["a.locale"].stringValue)
            XCTAssertEqual(prefetchJson["mboxes"][1]["name"].stringValue, "Drink_2")
            XCTAssertEqual(prefetchJson["mboxes"][1]["index"].intValue, 1)
            XCTAssertEqual(prefetchJson["mboxes"][0]["parameters"]["mbox-parameter-key1"].stringValue, "mbox-parameter-value1")
            XCTAssertNotNil(prefetchJson["mboxes"][0]["parameters"]["a.OSVersion"].stringValue)
            XCTAssertNotNil(prefetchJson["mboxes"][0]["parameters"]["a.Resolution"].stringValue)
            XCTAssertNotNil(prefetchJson["mboxes"][0]["parameters"]["a.DeviceName"].stringValue)
            XCTAssertNotNil(prefetchJson["mboxes"][0]["parameters"]["a.RunMode"].stringValue)
            XCTAssertNotNil(prefetchJson["mboxes"][0]["parameters"]["a.AppID"].stringValue)
            XCTAssertNotNil(prefetchJson["mboxes"][0]["parameters"]["a.locale"].stringValue)
            let validResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
        }
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(prefetchEvent))
        // handles the prefetch event
        eventListener(prefetchEvent)

        // verifies the content of network response was stored correctly
        XCTAssertEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", target.targetState.tntId)
        XCTAssertEqual("mboxedge35.tt.omtrdc.net", target.targetState.edgeHost)
        XCTAssertEqual(2, target.targetState.prefetchedMboxJsonDicts.count)
        let mboxJson = prettify(target.targetState.prefetchedMboxJsonDicts["Drink_1"])
        let drink1Json = JSON(parseJSON: mboxJson)
        XCTAssertEqual(drink1Json["options"][0]["content"]["key1"].stringValue, "value1")
        XCTAssertEqual(drink1Json["options"][0]["type"].stringValue, "json")
        XCTAssertEqual(drink1Json["options"][0]["eventToken"].stringValue, "uR0kIAPO+tZtIPW92S0NnWqipfsIHvVzTQxHolz2IpSCnQ9Y9OaLL2gsdrWQTvE54PwSz67rmXWmSnkXpSSS2Q==")
        XCTAssertEqual(drink1Json["name"].stringValue, "Drink_1")
        // verifies the Target's shared state
        XCTAssertEqual(1, mockRuntime.createdSharedStates.count)
        XCTAssertEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", mockRuntime.createdSharedStates[0]?["tntid"] as? String)

        // verifies the dispatched event
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)
        XCTAssertEqual("TargetPrefetchResponse", mockRuntime.dispatchedEvents[0].name)
        XCTAssertEqual("com.adobe.eventType.target", mockRuntime.dispatchedEvents[0].type)
        XCTAssertEqual("com.adobe.eventSource.responseContent", mockRuntime.dispatchedEvents[0].source)
    }

    func testPrefetchContent_withMboxParametersOverrodeByGlobalMboxParameters() {
        // builds the prefetch event
        let prefetchDataArray: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_1", targetParameters: TargetParameters(parameters: ["mbox_parameter_key": "mbox_parameter_value"])),
        ].map {
            $0.asDictionary()
        }

        let data: [String: Any] = [
            "prefetch": prefetchDataArray,
            "targetparams": TargetParameters(parameters: ["mbox_parameter_key": "mbox_parameter_value_global"]).asDictionary() as Any,
        ]
        let prefetchEvent = Event(name: "", type: "", source: "", data: data)

        // creates a configuration's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: prefetchEvent, data: (value: mockConfigSharedState, status: .set))

        // registers the event listeners for Target extension
        target.onRegistered()

        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            // verifies network request
            XCTAssertNotNil(request)
            guard let payloadDictionary = self.payloadAsDictionary(request.connectPayload) else {
                XCTFail()
                return nil
            }
            let payloadJson = JSON(parseJSON: self.prettify(payloadDictionary))
            XCTAssertEqual(payloadJson["prefetch"]["mboxes"][0]["parameters"]["mbox_parameter_key"].stringValue, "mbox_parameter_value_global")
            return nil
        }
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(prefetchEvent))
        // handles the prefetch event
        eventListener(prefetchEvent)
    }

    func testPrefetchContent_withProfileParametersOverrodeByGlobalProfileParameters() {
        // builds the prefetch event
        let prefetchDataArray: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_1", targetParameters: TargetParameters(profileParameters: ["name": "Jackson"])),
        ].map {
            $0.asDictionary()
        }

        let data: [String: Any] = [
            "prefetch": prefetchDataArray,
            "targetparams": TargetParameters(profileParameters: ["name": "Smith"]).asDictionary() as Any,
        ]
        let prefetchEvent = Event(name: "", type: "", source: "", data: data)

        // creates a configuration's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: prefetchEvent, data: (value: mockConfigSharedState, status: .set))

        // registers the event listeners for Target extension
        target.onRegistered()

        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            // verifies network request
            XCTAssertNotNil(request)
            guard let payloadDictionary = self.payloadAsDictionary(request.connectPayload) else {
                XCTFail()
                return nil
            }

            let payloadJson = JSON(parseJSON: self.prettify(payloadDictionary))
            XCTAssertEqual(payloadJson["prefetch"]["mboxes"][0]["profileParameters"]["name"].stringValue, "Smith")
            return nil
        }
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(prefetchEvent))
        // handles the prefetch event
        eventListener(prefetchEvent)
    }

    func testPrefetchContent_withOrderOverrodeByGlobalOrder() {
        // builds the prefetch event
        let prefetchDataArray: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_1", targetParameters: TargetParameters(order: TargetOrder(id: "o_id", total: 10.0, purchasedProductIds: ["A", "B", "C"]))),
        ].map {
            $0.asDictionary()
        }

        let data: [String: Any] = [
            "prefetch": prefetchDataArray,
            "targetparams": TargetParameters(order: TargetOrder(id: "o_id_1", total: 11.0, purchasedProductIds: ["D", "E", "F"])).asDictionary() as Any,
        ]
        let prefetchEvent = Event(name: "", type: "", source: "", data: data)

        // creates a configuration's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: prefetchEvent, data: (value: mockConfigSharedState, status: .set))

        // registers the event listeners for Target extension
        target.onRegistered()

        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            // verifies network request
            XCTAssertNotNil(request)
            guard let payloadDictionary = self.payloadAsDictionary(request.connectPayload) else {
                XCTFail()
                return nil
            }
            let payloadJson = JSON(parseJSON: self.prettify(payloadDictionary))
            XCTAssertEqual(payloadJson["prefetch"]["mboxes"][0]["order"]["id"].stringValue, "o_id_1")
            XCTAssertEqual(payloadJson["prefetch"]["mboxes"][0]["order"]["total"].doubleValue, 11.0)
            XCTAssertEqual(payloadJson["prefetch"]["mboxes"][0]["order"]["purchasedProductIds"].arrayValue, ["D", "E", "F"])
            return nil
        }
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(prefetchEvent))
        // handles the prefetch event
        eventListener(prefetchEvent)
    }

    func testPrefetchContent_withProductOverrodeByGlobalProduct() {
        // builds the prefetch event
        let prefetchDataArray: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_1", targetParameters: TargetParameters(product: TargetProduct(productId: "p_id", categoryId: "Online"))),
        ].map {
            $0.asDictionary()
        }

        let data: [String: Any] = [
            "prefetch": prefetchDataArray,
            "targetparams": TargetParameters(product: TargetProduct(productId: "p_id_1", categoryId: "Offline")).asDictionary() as Any,
        ]
        let prefetchEvent = Event(name: "", type: "", source: "", data: data)

        // creates a configuration's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: prefetchEvent, data: (value: mockConfigSharedState, status: .set))

        // registers the event listeners for Target extension
        target.onRegistered()

        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            // verifies network request
            XCTAssertNotNil(request)
            guard let payloadDictionary = self.payloadAsDictionary(request.connectPayload) else {
                XCTFail()
                return nil
            }
            let payloadJson = JSON(parseJSON: self.prettify(payloadDictionary))
            XCTAssertEqual(payloadJson["prefetch"]["mboxes"][0]["name"].stringValue, "Drink_1")
            XCTAssertEqual(payloadJson["prefetch"]["mboxes"][0]["product"]["id"].stringValue, "p_id_1")
            XCTAssertEqual(payloadJson["prefetch"]["mboxes"][0]["product"]["categoryId"].stringValue, "Offline")
            return nil
        }
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(prefetchEvent))
        // handles the prefetch event
        eventListener(prefetchEvent)
    }

    func testPrefetchContent_checkMergedMboxWithMultipleCalls() {
        let responseString1 = """
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
                    "name": "Drink_1",
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
        let responseString2 = """
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
                    "name": "Drink_2",
                    "options": [
                      {
                        "content": {
                          "key2": "value2"
                        },
                        "type": "json",
                        "eventToken": "uR0kIAPO+tZtIPW92S0NnWqipfsIHvVzTQxHolz2IpSCnQ9Y9OaLL2gsdrWQTvE54PwSz67rmXWmSnkXpSSS2Q=="
                      }
                    ]
                  },
                  {
                    "index": 1,
                    "name": "Drink_3",
                    "options": [
                      {
                        "content": {
                          "key3": "value3"
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
        let prefetchDataArray1: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_1"),
        ].map {
            $0.asDictionary()
        }
        let prefetchDataArray2: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_2"),
            TargetPrefetch(name: "Drink_3"),
        ].map {
            $0.asDictionary()
        }

        let prefetchData1: [String: Any] = [
            "prefetch": prefetchDataArray1,
        ]
        let prefetchData2: [String: Any] = [
            "prefetch": prefetchDataArray2,
        ]
        let prefetchEvent1 = Event(name: "", type: "", source: "", data: prefetchData1)
        let prefetchEvent2 = Event(name: "", type: "", source: "", data: prefetchData2)

        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { _ in
            let validResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data: responseString1.data(using: .utf8), response: validResponse, error: nil)
        }

        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }

        // creates a configuration's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: prefetchEvent1, data: (value: mockConfigSharedState, status: .set))

        // creates a lifecycle's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.lifecycle", event: prefetchEvent1, data: (value: mockLifecycleData, status: .set))

        // creates an identity's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: prefetchEvent1, data: (value: mockIdentityData, status: .set))

        // registers the event listeners for Target extension
        target.onRegistered()

        XCTAssertTrue(target.readyForEvent(prefetchEvent1))
        // handles the prefetch event
        eventListener(prefetchEvent1)

        // verifies the content of network response was stored correctly
        XCTAssertEqual(1, target.targetState.prefetchedMboxJsonDicts.count)
        let mboxJson = JSON(parseJSON: prettify(target.targetState.prefetchedMboxJsonDicts["Drink_1"]))
        XCTAssertEqual(mboxJson["options"][0]["content"]["key1"].stringValue, "value1")
        XCTAssertEqual(mboxJson["name"].stringValue, "Drink_1")

        // verifies the Target's shared state
        XCTAssertEqual(1, mockRuntime.createdSharedStates.count)

        // verifies the dispatched event
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)
        XCTAssertEqual("TargetPrefetchResponse", mockRuntime.dispatchedEvents[0].name)
        XCTAssertEqual("com.adobe.eventType.target", mockRuntime.dispatchedEvents[0].type)
        XCTAssertEqual("com.adobe.eventSource.responseContent", mockRuntime.dispatchedEvents[0].source)

        mockNetworkService.resolvers.removeAll()
        mockNetworkService.mock { _ in
            let validResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data: responseString2.data(using: .utf8), response: validResponse, error: nil)
        }
        eventListener(prefetchEvent2)
        XCTAssertEqual(3, target.targetState.prefetchedMboxJsonDicts.count)
        XCTAssertTrue(Set(target.targetState.prefetchedMboxJsonDicts.keys) == Set([
            "Drink_1",
            "Drink_2",
            "Drink_3",
        ]))
    }

    func testPrefetchContent_checkOverrodeMboxWithMultipleCalls() {
        let responseString1 = """
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
                    "name": "Drink_1",
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
        let responseString2 = """
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
                    "name": "Drink_1",
                    "options": [
                      {
                        "content": {
                          "key2": "value2"
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
        let prefetchDataArray1: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_1"),
        ].map {
            $0.asDictionary()
        }
        let prefetchDataArray2: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_1"),
        ].map {
            $0.asDictionary()
        }

        let prefetchData1: [String: Any] = [
            "prefetch": prefetchDataArray1,
        ]
        let prefetchData2: [String: Any] = [
            "prefetch": prefetchDataArray2,
        ]
        let prefetchEvent1 = Event(name: "", type: "", source: "", data: prefetchData1)
        let prefetchEvent2 = Event(name: "", type: "", source: "", data: prefetchData2)

        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { _ in
            let validResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data: responseString1.data(using: .utf8), response: validResponse, error: nil)
        }

        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }

        // creates a configuration's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: prefetchEvent1, data: (value: mockConfigSharedState, status: .set))

        // creates a lifecycle's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.lifecycle", event: prefetchEvent1, data: (value: mockLifecycleData, status: .set))

        // creates an identity's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: prefetchEvent1, data: (value: mockIdentityData, status: .set))

        // registers the event listeners for Target extension
        target.onRegistered()

        XCTAssertTrue(target.readyForEvent(prefetchEvent1))
        // handles the prefetch event
        eventListener(prefetchEvent1)

        // verifies the content of network response was stored correctly
        XCTAssertEqual(1, target.targetState.prefetchedMboxJsonDicts.count)
        let mboxJson = JSON(parseJSON: prettify(target.targetState.prefetchedMboxJsonDicts["Drink_1"]))
        XCTAssertEqual(mboxJson["options"][0]["content"]["key1"].stringValue, "value1")
        XCTAssertEqual(mboxJson["name"].stringValue, "Drink_1")

        mockNetworkService.resolvers.removeAll()
        mockNetworkService.mock { _ in
            let validResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data: responseString2.data(using: .utf8), response: validResponse, error: nil)
        }
        eventListener(prefetchEvent2)
        XCTAssertEqual(1, target.targetState.prefetchedMboxJsonDicts.count)
        let mboxJsonNew = JSON(parseJSON: prettify(target.targetState.prefetchedMboxJsonDicts["Drink_1"]))
        XCTAssertEqual(mboxJsonNew["options"][0]["content"]["key2"].stringValue, "value2")
        XCTAssertFalse(mboxJsonNew["options"][0]["content"]["key1"].exists())
        XCTAssertEqual(mboxJsonNew["name"].stringValue, "Drink_1")
    }

    func testPrefetchContent_in_PreviewMode() {
        MockNetworkService.request = nil
        ServiceProvider.shared.networkService = MockNetworkService()

        let data: [String: Any] = [
            "prefetch": [String: Any](),
            "targetparams": TargetParameters(profileParameters: mockProfileParam).asDictionary() as Any,
        ]
        let prefetchEvent = Event(name: "", type: "", source: "", data: data)
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: prefetchEvent, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()
        let mockedPreviewManager = MockTargetPreviewManager()
        mockedPreviewManager.previewParameters = "none empty"
        target.previewManager = mockedPreviewManager

        if let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] {
            eventListener(prefetchEvent)
            XCTAssertNil(MockNetworkService.request)
            XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)
            XCTAssertEqual("TargetPrefetchResponse", mockRuntime.dispatchedEvents[0].name)
            XCTAssertEqual("com.adobe.eventType.target", mockRuntime.dispatchedEvents[0].type)
            XCTAssertEqual("com.adobe.eventSource.responseContent", mockRuntime.dispatchedEvents[0].source)
            XCTAssertNotNil(mockRuntime.dispatchedEvents[0].data?["prefetcherror"])
            let errorMessage = mockRuntime.dispatchedEvents[0].data?["prefetcherror"] as? String ?? ""
            XCTAssertTrue(errorMessage.contains("in preview mode"))
            return
        }
        XCTFail()
    }

    func testPrefetchContent_empty_prefetch_array() {
        MockNetworkService.request = nil
        ServiceProvider.shared.networkService = MockNetworkService()

        let data: [String: Any] = [
            "prefetch": [String: Any](),
            "targetparams": TargetParameters(profileParameters: mockProfileParam).asDictionary() as Any,
        ]
        let prefetchEvent = Event(name: "", type: "", source: "", data: data)
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: prefetchEvent, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()

        if let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] {
            eventListener(prefetchEvent)
            XCTAssertNil(MockNetworkService.request)
            XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)
            XCTAssertEqual("TargetPrefetchResponse", mockRuntime.dispatchedEvents[0].name)
            XCTAssertEqual("com.adobe.eventType.target", mockRuntime.dispatchedEvents[0].type)
            XCTAssertEqual("com.adobe.eventSource.responseContent", mockRuntime.dispatchedEvents[0].source)
            XCTAssertNotNil(mockRuntime.dispatchedEvents[0].data?["prefetcherror"])
            return
        }
        XCTFail()
    }

    func testPrefetchContent_error_response() {
        // mocked network response
        let responseString = """
            {
              "message": "verify_error_message"
            }
        """

        // builds the prefetch event
        let prefetchDataArray: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_1", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
            TargetPrefetch(name: "Drink_2", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
        ].map {
            $0.asDictionary()
        }

        let data: [String: Any] = [
            "prefetch": prefetchDataArray,
            "targetparams": TargetParameters(profileParameters: ["name": "Smith"]).asDictionary() as Any,
        ]
        let prefetchEvent = Event(name: "", type: "", source: "", data: data)

        // creates a configuration's shared state
        let configuration = [
            "target.clientCode": "code_123",
            "global.privacy": "optedin",
        ]
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: prefetchEvent, data: (value: configuration, status: .set))

        // registers the event listeners for Target extension
        target.onRegistered()

        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { _ in
            let badResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 400, httpVersion: nil, headerFields: nil)
            return (data: responseString.data(using: .utf8), response: badResponse, error: nil)
        }
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }

        // handles the prefetch event
        XCTAssertTrue(target.readyForEvent(prefetchEvent))
        eventListener(prefetchEvent)

        // verifies the Target's shared state
        XCTAssertEqual(0, mockRuntime.createdSharedStates.count)

        // verifies the dispatched event
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)
        XCTAssertEqual("TargetPrefetchResponse", mockRuntime.dispatchedEvents[0].name)
        XCTAssertEqual("com.adobe.eventType.target", mockRuntime.dispatchedEvents[0].type)
        XCTAssertEqual("com.adobe.eventSource.responseContent", mockRuntime.dispatchedEvents[0].source)
        let errorMessage = mockRuntime.dispatchedEvents[0].data?["prefetcherror"] as? String ?? ""
        XCTAssertTrue(errorMessage.contains("verify_error_message"))
    }

    func testPrefetchContent_bad_response_payload() {
        // mocked network response
        let responseString = "not a json string"

        // builds the prefetch event
        let prefetchDataArray: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_1", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
            TargetPrefetch(name: "Drink_2", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
        ].map {
            $0.asDictionary()
        }

        let data: [String: Any] = [
            "prefetch": prefetchDataArray,
            "targetparams": TargetParameters(profileParameters: ["name": "Smith"]).asDictionary() as Any,
        ]
        let prefetchEvent = Event(name: "", type: "", source: "", data: data)

        // creates a configuration's shared state
        let configuration = [
            "target.clientCode": "code_123",
            "global.privacy": "optedin",
        ]
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: prefetchEvent, data: (value: configuration, status: .set))

        // registers the event listeners for Target extension
        target.onRegistered()

        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { _ in
            let validResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
        }
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }

        // handles the prefetch event
        XCTAssertTrue(target.readyForEvent(prefetchEvent))
        eventListener(prefetchEvent)

        // verifies the Target's shared state
        XCTAssertEqual(0, mockRuntime.createdSharedStates.count)

        // verifies the dispatched event
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)
        XCTAssertEqual("TargetPrefetchResponse", mockRuntime.dispatchedEvents[0].name)
        XCTAssertEqual("com.adobe.eventType.target", mockRuntime.dispatchedEvents[0].type)
        XCTAssertEqual("com.adobe.eventSource.responseContent", mockRuntime.dispatchedEvents[0].source)
        XCTAssertEqual("Target response parser initialization failed", mockRuntime.dispatchedEvents[0].data?["prefetcherror"] as? String ?? "")
    }

    func testPrefetchContent_network_timeout() {
        // builds the prefetch event
        let prefetchDataArray: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_1", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
            TargetPrefetch(name: "Drink_2", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
        ].map {
            $0.asDictionary()
        }

        let data: [String: Any] = [
            "prefetch": prefetchDataArray,
            "targetparams": TargetParameters(profileParameters: ["name": "Smith"]).asDictionary() as Any,
        ]
        let prefetchEvent = Event(name: "", type: "", source: "", data: data)

        // creates a configuration's shared state
        let configuration = [
            "target.clientCode": "code_123",
            "global.privacy": "optedin",
            "target.timeout": 1,
        ] as [String: Any]
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: prefetchEvent, data: (value: configuration, status: .set))

        // registers the event listeners for Target extension
        target.onRegistered()

        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService

        mockNetworkService.mock { request in
            XCTAssertEqual(1, request.readTimeout)
            sleep(2)
            return nil
        }

        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }

        // handles the prefetch event
        XCTAssertTrue(target.readyForEvent(prefetchEvent))
        eventListener(prefetchEvent)

        // verifies the Target's shared state
        XCTAssertEqual(0, mockRuntime.createdSharedStates.count)

        // verifies the dispatched event
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)
        XCTAssertEqual("TargetPrefetchResponse", mockRuntime.dispatchedEvents[0].name)
        XCTAssertEqual("com.adobe.eventType.target", mockRuntime.dispatchedEvents[0].type)
        XCTAssertEqual("com.adobe.eventSource.responseContent", mockRuntime.dispatchedEvents[0].source)
        XCTAssertNotNil(mockRuntime.dispatchedEvents[0].data?["prefetcherror"])
    }

    func testPrefetchContent_no_client_code() {
        // builds the prefetch event
        let prefetchDataArray: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_1", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
            TargetPrefetch(name: "Drink_2", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
        ].map {
            $0.asDictionary()
        }

        let data: [String: Any] = [
            "prefetch": prefetchDataArray,
            "targetparams": TargetParameters(profileParameters: ["name": "Smith"]).asDictionary() as Any,
        ]
        let prefetchEvent = Event(name: "", type: "", source: "", data: data)

        // creates a configuration's shared state
        let configuration = [
            "global.privacy": "optedin",
        ]
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: prefetchEvent, data: (value: configuration, status: .set))

        // registers the event listeners for Target extension
        target.onRegistered()

        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService

        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }

        // handles the prefetch event
        XCTAssertTrue(target.readyForEvent(prefetchEvent))
        eventListener(prefetchEvent)

        // verifies the Target's shared state
        XCTAssertEqual(0, mockRuntime.createdSharedStates.count)

        // verifies the dispatched event
        XCTAssertEqual(0, mockNetworkService.requests.count)
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)
        XCTAssertEqual("TargetPrefetchResponse", mockRuntime.dispatchedEvents[0].name)
        XCTAssertEqual("com.adobe.eventType.target", mockRuntime.dispatchedEvents[0].type)
        XCTAssertEqual("com.adobe.eventSource.responseContent", mockRuntime.dispatchedEvents[0].source)
        let errorMessage = mockRuntime.dispatchedEvents[0].data?["prefetcherror"] as? String ?? ""
        XCTAssertEqual("Missing client code", errorMessage)
    }

    func testPrefetchContent_not_opt_in() {
        // builds the prefetch event
        let prefetchDataArray: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_1", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
            TargetPrefetch(name: "Drink_2", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
        ].map {
            $0.asDictionary()
        }

        let data: [String: Any] = [
            "prefetch": prefetchDataArray,
            "targetparams": TargetParameters(profileParameters: ["name": "Smith"]).asDictionary() as Any,
        ]
        let prefetchEvent = Event(name: "", type: "", source: "", data: data)

        // creates a configuration's shared state
        let configuration = [
            "target.clientCode": "code_123",
        ]
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: prefetchEvent, data: (value: configuration, status: .set))

        // registers the event listeners for Target extension
        target.onRegistered()

        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }

        // handles the prefetch event
        XCTAssertTrue(target.readyForEvent(prefetchEvent))
        eventListener(prefetchEvent)

        // verifies the Target's shared state
        XCTAssertEqual(0, mockRuntime.createdSharedStates.count)

        // verifies the dispatched event
        XCTAssertEqual(0, mockNetworkService.requests.count)
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)
        XCTAssertEqual("TargetPrefetchResponse", mockRuntime.dispatchedEvents[0].name)
        XCTAssertEqual("com.adobe.eventType.target", mockRuntime.dispatchedEvents[0].type)
        XCTAssertEqual("com.adobe.eventSource.responseContent", mockRuntime.dispatchedEvents[0].source)
        let errorMessage = mockRuntime.dispatchedEvents[0].data?["prefetcherror"] as? String ?? ""
        XCTAssertEqual("Privacy status is not opted in", errorMessage)
    }
}
