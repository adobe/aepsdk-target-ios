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

class TargetLoadRequestsFunctionalTests: TargetFunctionalTestsBase {
    // MARK: - Load Request

    func testLoadRequestContent_withDefaultParameters() {
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
              "execute": {
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
                    ],
                    "analytics" : {
                        "payload" : {"pe" : "tnt", "tnta" : "33333:1:0|12121|1,38711:1:0|1|1"}
                    }
                  }
                ]
              }
            }
        """

        let requestDataArray: [[String: Any]?] = [
            TargetRequest(mboxName: "t_test_01", defaultContent: "default", targetParameters: TargetParameters(parameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
            TargetRequest(mboxName: "t_test_02", defaultContent: "default2", targetParameters: TargetParameters(parameters: ["mbox-parameter-key2": "mbox-parameter-value2"])),
        ].map {
            $0.asDictionary()
        }

        let data: [String: Any] = [
            "request": requestDataArray,
            "targetparams": TargetParameters(profileParameters: mockProfileParam).asDictionary() as Any,
        ]
        let loadRequestEvent = Event(name: "", type: "", source: "", data: data)

        // creates a configuration's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: loadRequestEvent, data: (value: mockConfigSharedState, status: .set))

        // creates a lifecycle's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.lifecycle", event: loadRequestEvent, data: (value: mockLifecycleData, status: .set))

        // creates an identity's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: loadRequestEvent, data: (value: mockIdentityData, status: .set))

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
                "execute",
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

            guard let executeDictionary = payloadDictionary["execute"] as? [String: Any] else {
                XCTFail()
                return nil
            }

            XCTAssertTrue(Set(executeDictionary.keys) == Set([
                "mboxes",
            ]))
            guard let mboxes = executeDictionary["mboxes"] as? [[String: Any]] else {
                XCTFail()
                return nil
            }
            XCTAssertEqual(2, mboxes.count)
            let executeJson = JSON(parseJSON: self.prettify(executeDictionary))
            XCTAssertEqual(executeJson["mboxes"][0]["index"].intValue, 0)
            XCTAssertEqual(executeJson["mboxes"][0]["name"].stringValue, "t_test_01")
            XCTAssertEqual(executeJson["mboxes"][0]["profileParameters"]["name"].stringValue, "Smith")
            XCTAssertNotNil(executeJson["mboxes"][0]["parameters"]["a.Resolution"].stringValue)
            XCTAssertNotNil(executeJson["mboxes"][0]["parameters"]["a.DeviceName"].stringValue)
            XCTAssertNotNil(executeJson["mboxes"][0]["parameters"]["a.RunMode"].stringValue)
            XCTAssertNotNil(executeJson["mboxes"][0]["parameters"]["a.locale"].stringValue)
            XCTAssertNotNil(executeJson["mboxes"][0]["parameters"]["a.OSVersion"].stringValue)
            XCTAssertNotNil(executeJson["mboxes"][0]["parameters"]["a.AppID"].stringValue)
            XCTAssertEqual(executeJson["mboxes"][0]["parameters"]["mbox-parameter-key1"].stringValue, "mbox-parameter-value1")
            XCTAssertEqual(executeJson["mboxes"][1]["index"].intValue, 1)
            XCTAssertEqual(executeJson["mboxes"][1]["name"].stringValue, "t_test_02")
            XCTAssertEqual(executeJson["mboxes"][1]["profileParameters"]["name"].stringValue, "Smith")
            XCTAssertNotNil(executeJson["mboxes"][1]["parameters"]["a.Resolution"].stringValue)
            XCTAssertNotNil(executeJson["mboxes"][1]["parameters"]["a.DeviceName"].stringValue)
            XCTAssertNotNil(executeJson["mboxes"][1]["parameters"]["a.RunMode"].stringValue)
            XCTAssertNotNil(executeJson["mboxes"][1]["parameters"]["a.locale"].stringValue)
            XCTAssertNotNil(executeJson["mboxes"][1]["parameters"]["a.OSVersion"].stringValue)
            XCTAssertNotNil(executeJson["mboxes"][1]["parameters"]["a.AppID"].stringValue)
            XCTAssertEqual(executeJson["mboxes"][1]["parameters"]["mbox-parameter-key2"].stringValue, "mbox-parameter-value2")
            let validResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
        }
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(loadRequestEvent))
        // handles the prefetch event
        eventListener(loadRequestEvent)

        // verifies the content of network response was stored correctly
        XCTAssertEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", target.targetState.tntId)
        XCTAssertEqual("mboxedge35.tt.omtrdc.net", target.targetState.edgeHost)
        XCTAssertEqual(1, target.targetState.loadedMboxJsonDicts.count)
        let mboxJson = prettify(target.targetState.loadedMboxJsonDicts["t_test_01"])
        XCTAssertTrue(mboxJson.contains("\"eventToken\" : \"uR0kIAPO+tZtIPW92S0NnWqipfsIHvVzTQxHolz2IpSCnQ9Y9OaLL2gsdrWQTvE54PwSz67rmXWmSnkXpSSS2Q==\""))

        // verifies the Target's shared state
        XCTAssertEqual(1, mockRuntime.createdSharedStates.count)
        XCTAssertEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", mockRuntime.createdSharedStates[0]?["tntid"] as? String)
    }

    func testLoadRequestContent_withOrderParameters() {
        let requestDataArray: [[String: Any]?] = [
            TargetRequest(mboxName: "t_test_01", defaultContent: "default", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"], order: TargetOrder(id: "id", total: 12.34, purchasedProductIds: ["A", "B", "C"]))),
        ].map {
            $0.asDictionary()
        }

        let data: [String: Any] = [
            "request": requestDataArray,
            "targetparams": TargetParameters(profileParameters: mockProfileParam).asDictionary() as Any,
        ]
        let loadRequestEvent = Event(name: "", type: "", source: "", data: data)

        // creates a configuration's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: loadRequestEvent, data: (value: mockConfigSharedState, status: .set))

        // creates a lifecycle's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.lifecycle", event: loadRequestEvent, data: (value: mockLifecycleData, status: .set))

        // creates an identity's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: loadRequestEvent, data: (value: mockIdentityData, status: .set))

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
                "execute",
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
            guard let prefetchDictionary = payloadDictionary["execute"] as? [String: Any] else {
                XCTFail()
                return nil
            }

            XCTAssertTrue(Set(prefetchDictionary.keys) == Set([
                "mboxes",
            ]))

            guard let mboxes = prefetchDictionary["mboxes"] as? [[String: Any]] else {
                XCTFail()
                return nil
            }

            XCTAssertEqual(1, mboxes.count)

            let requestMbox = mboxes[0]
            guard let requestOrder = requestMbox["order"] as? [String: Any] else {
                XCTFail()
                return nil
            }

            XCTAssertEqual("id", requestOrder["id"] as? String ?? "")
            XCTAssertEqual(12.34, requestOrder["total"] as? Double ?? 0.0)
            XCTAssertEqual(["A", "B", "C"], requestOrder["purchasedProductIds"] as? [String] ?? [""])
            return nil
        }
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(loadRequestEvent))
        // handles the prefetch event
        eventListener(loadRequestEvent)
    }

    func testLoadRequestContent_withProductParameters() {
        let requestDataArray: [[String: Any]?] = [
            TargetRequest(mboxName: "t_test_01", defaultContent: "default", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"], product: TargetProduct(productId: "764334", categoryId: "Online"))),
        ].map {
            $0.asDictionary()
        }

        let data: [String: Any] = [
            "request": requestDataArray,
            "targetparams": TargetParameters(profileParameters: mockProfileParam).asDictionary() as Any,
        ]
        let loadRequestEvent = Event(name: "", type: "", source: "", data: data)

        // creates a configuration's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: loadRequestEvent, data: (value: mockConfigSharedState, status: .set))

        // creates a lifecycle's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.lifecycle", event: loadRequestEvent, data: (value: mockLifecycleData, status: .set))

        // creates an identity's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: loadRequestEvent, data: (value: mockIdentityData, status: .set))

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
                "execute",
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
            guard let prefetchDictionary = payloadDictionary["execute"] as? [String: Any] else {
                XCTFail()
                return nil
            }

            XCTAssertTrue(Set(prefetchDictionary.keys) == Set([
                "mboxes",
            ]))

            guard let mboxes = prefetchDictionary["mboxes"] as? [[String: Any]] else {
                XCTFail()
                return nil
            }

            XCTAssertEqual(1, mboxes.count)

            let requestMbox = mboxes[0]
            guard let requestProduct = requestMbox["product"] as? [String: Any] else {
                XCTFail()
                return nil
            }

            XCTAssertEqual("764334", requestProduct["id"] as? String ?? "")
            XCTAssertEqual("Online", requestProduct["categoryId"] as? String ?? "")
            return nil
        }
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(loadRequestEvent))
        // handles the prefetch event
        eventListener(loadRequestEvent)
    }

    func testLoadRequestContent_withOrderAndProductParameters() {
        let requestDataArray: [[String: Any]?] = [
            TargetRequest(mboxName: "t_test_01",
                          defaultContent: "default",
                          targetParameters: TargetParameters(
                              profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"],
                              order: TargetOrder(id: "id", total: 12.34, purchasedProductIds: ["A", "B", "C"]),
                              product: TargetProduct(productId: "764334", categoryId: "Online")
                          )),
        ].map {
            $0.asDictionary()
        }

        let data: [String: Any] = [
            "request": requestDataArray,
            "targetparams": TargetParameters(profileParameters: mockProfileParam).asDictionary() as Any,
        ]
        let loadRequestEvent = Event(name: "", type: "", source: "", data: data)

        // creates a configuration's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: loadRequestEvent, data: (value: mockConfigSharedState, status: .set))

        // creates a lifecycle's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.lifecycle", event: loadRequestEvent, data: (value: mockLifecycleData, status: .set))

        // creates an identity's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: loadRequestEvent, data: (value: mockIdentityData, status: .set))

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
                "execute",
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
            guard let prefetchDictionary = payloadDictionary["execute"] as? [String: Any] else {
                XCTFail()
                return nil
            }

            XCTAssertTrue(Set(prefetchDictionary.keys) == Set([
                "mboxes",
            ]))

            guard let mboxes = prefetchDictionary["mboxes"] as? [[String: Any]] else {
                XCTFail()
                return nil
            }

            XCTAssertEqual(1, mboxes.count)

            let requestMbox = mboxes[0]
            guard let requestProduct = requestMbox["product"] as? [String: Any] else {
                XCTFail()
                return nil
            }

            XCTAssertEqual("764334", requestProduct["id"] as? String ?? "")
            XCTAssertEqual("Online", requestProduct["categoryId"] as? String ?? "")

            guard let requestOrder = requestMbox["order"] as? [String: Any] else {
                XCTFail()
                return nil
            }

            XCTAssertEqual("id", requestOrder["id"] as? String ?? "")
            XCTAssertEqual(12.34, requestOrder["total"] as? Double ?? 0.0)
            XCTAssertEqual(["A", "B", "C"], requestOrder["purchasedProductIds"] as? [String] ?? [""])

            return nil
        }
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(loadRequestEvent))
        // handles the prefetch event
        eventListener(loadRequestEvent)
    }

    func testLoadRequestContent_empty_requests() {
        MockNetworkService.request = nil
        ServiceProvider.shared.networkService = MockNetworkService()
        let data: [String: Any] = [
            "request": [String: Any](),
            "targetparams": TargetParameters(profileParameters: mockProfileParam).asDictionary() as Any,
        ]
        let loadRequestEvent = Event(name: "", type: "", source: "", data: data)
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: loadRequestEvent, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()
        if let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] {
            eventListener(loadRequestEvent)
            XCTAssertNil(MockNetworkService.request)
            return
        }
        XCTFail()
    }

    func testLoadRequestContent_bad_response() {
        // mocked network response
        let responseString = """
            {
              "message": "error_message Notifications"
            }
        """
        let requestDataArray: [[String: Any]?] = [
            TargetRequest(mboxName: "t_test_01", defaultContent: "default", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
            TargetRequest(mboxName: "t_test_02", defaultContent: "default2", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
        ].map {
            $0.asDictionary()
        }

        let data: [String: Any] = [
            "request": requestDataArray,
            "targetparams": TargetParameters(profileParameters: mockProfileParam).asDictionary() as Any,
        ]
        let loadRequestEvent = Event(name: "", type: "", source: "", data: data)

        // creates a configuration's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: loadRequestEvent, data: (value: mockConfigSharedState, status: .set))

        // creates a lifecycle's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.lifecycle", event: loadRequestEvent, data: (value: mockLifecycleData, status: .set))

        // creates an identity's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: loadRequestEvent, data: (value: mockIdentityData, status: .set))

        // registers the event listeners for Target extension
        target.onRegistered()
        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService

        mockNetworkService.mock { _ in
            let validResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 400, httpVersion: nil, headerFields: nil)

            return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
        }
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        // handles the location displayed event
        eventListener(loadRequestEvent)

        // Check the notifications are cleared
        XCTAssertTrue(target.targetState.notifications.isEmpty)

        XCTAssertEqual(0, target.targetState.loadedMboxJsonDicts.count)
    }

    func testLoadRequestContent_returnNullContent() {
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
                "mboxes": []
              }
            }
        """
        let requestDataArray: [[String: Any]?] = [
            TargetRequest(mboxName: "t_test_01", defaultContent: "default_content_123"),
        ].map {
            $0.asDictionary()
        }

        let data: [String: Any] = [
            "request": requestDataArray,
            "targetparams": TargetParameters(profileParameters: mockProfileParam).asDictionary() as Any,
        ]
        let loadRequestEvent = Event(name: "", type: "", source: "", data: data)

        // creates a configuration's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: loadRequestEvent, data: (value: mockConfigSharedState, status: .set))
        // registers the event listeners for Target extension
        target.onRegistered()

        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            // verifies network request
            XCTAssertNotNil(request)
            guard let _ = self.payloadAsDictionary(request.connectPayload) else {
                XCTFail()
                return nil
            }
            XCTAssertTrue(request.url.absoluteString.contains("https://code_123.tt.omtrdc.net/rest/v1/delivery/?client=code_123&sessionId="))
            let validResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
        }
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(loadRequestEvent))
        // handles the prefetch event
        eventListener(loadRequestEvent)

        // verifies the content of network response was stored correctly
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)
        XCTAssertNotNil(mockRuntime.dispatchedEvents[0].data)
        XCTAssertEqual("default_content_123", mockRuntime.dispatchedEvents[0].data?["content"] as? String ?? "")
    }

    func testLoadRequestContent_sendLoadRequestIfPrefetchFails() {
        // mocked network response
        let responseString = """
            {
              "message": "verify_error_message"
            }
        """

        // builds the prefetch event
        let prefetchDataArray: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_1"),
            TargetPrefetch(name: "Drink_2"),
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
        let networkRequestExpectation = XCTestExpectation(description: "monitor the prefetch request")
        networkRequestExpectation.expectedFulfillmentCount = 2
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { _ in
            let badResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 500, httpVersion: nil, headerFields: nil)
            networkRequestExpectation.fulfill()
            return (data: responseString.data(using: .utf8), response: badResponse, error: nil)
        }
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }

        // handles the prefetch event
        XCTAssertTrue(target.readyForEvent(prefetchEvent))
        eventListener(prefetchEvent)
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()
        let requestDataArray: [[String: Any]?] = [
            TargetRequest(mboxName: "t_test_01", defaultContent: "default_content_123"),
        ].map {
            $0.asDictionary()
        }

        let loadRequestData: [String: Any] = [
            "request": requestDataArray,
            "targetparams": TargetParameters(profileParameters: mockProfileParam).asDictionary() as Any,
        ]
        let loadRequestEvent = Event(name: "", type: "", source: "", data: loadRequestData)
        // handles the loadRequest event
        eventListener(loadRequestEvent)
        wait(for: [networkRequestExpectation], timeout: 1)
        // verifies the content of network response was stored correctly
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)
        XCTAssertNotNil(mockRuntime.dispatchedEvents[0].data)
        XCTAssertEqual("default_content_123", mockRuntime.dispatchedEvents[0].data?["content"] as? String ?? "")
    }

    func testLoadRequestContent_withPartialMboxPrefetched() {
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
                    "name": "Drink_1",
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
                        "tnta": "33333:1:0|12121|1,38711:1:0|1|1"
                      }
                    }
                  },
                  {
                    "index": 1,
                    "name": "Drink_2",
                    "options": [
                      {
                        "content": {
                          "key2": "value2"
                        },
                        "type": "json",
                        "eventToken": "uR0kIAPO+tZtIPW92S0NnWqipfsIHvVzTQxHolz2IpSCnQ9Y9OaLL2gsdrWQTvE54PwSz67rmXWmSnkXpSSS2Q=="
                      }
                    ],
                    "analytics": {
                      "payload": {
                        "pe": "tnt",
                        "tnta": "33333:1:0|12121|1,38711:1:0|1|1"
                      }
                    }
                  },
                  {
                    "index": 2,
                    "name": "Drink_3"
                  }
                ]
              }
            }
        """

        // builds the prefetch event
        let prefetchDataArray: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_1"),
            TargetPrefetch(name: "Drink_2"),
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
        let networkRequestExpectation = XCTestExpectation(description: "monitor the prefetch request")
        networkRequestExpectation.expectedFulfillmentCount = 2
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { _ in
            let badResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            networkRequestExpectation.fulfill()
            return (data: responseString.data(using: .utf8), response: badResponse, error: nil)
        }
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }

        // handles the prefetch event
        XCTAssertTrue(target.readyForEvent(prefetchEvent))
        eventListener(prefetchEvent)
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()
        let requestDataArray: [[String: Any]?] = [
            TargetRequest(mboxName: "Drink_1", defaultContent: "default_content"),
            TargetRequest(mboxName: "Drink_2", defaultContent: "default_content"),
            TargetRequest(mboxName: "Drink_3", defaultContent: "default_content_123"),
        ].map {
            $0.asDictionary()
        }

        let loadRequestData: [String: Any] = [
            "request": requestDataArray,
            "targetparams": TargetParameters(profileParameters: mockProfileParam).asDictionary() as Any,
        ]
        let loadRequestEvent = Event(name: "", type: "", source: "", data: loadRequestData)
        // handles the loadRequest event
        eventListener(loadRequestEvent)
        wait(for: [networkRequestExpectation], timeout: 1)
        // verifies the content of network response was stored correctly
        XCTAssertEqual(3, mockRuntime.dispatchedEvents.count)
        XCTAssertNotNil(mockRuntime.dispatchedEvents[0].data)
        XCTAssertEqual("{\n  \"key1\" : \"value1\"\n}", mockRuntime.dispatchedEvents[0].data?["content"] as? String ?? "")
        XCTAssertNotNil(mockRuntime.dispatchedEvents[1].data)
        XCTAssertEqual("{\n  \"key2\" : \"value2\"\n}", mockRuntime.dispatchedEvents[1].data?["content"] as? String ?? "")
        XCTAssertNotNil(mockRuntime.dispatchedEvents[2].data)
        XCTAssertEqual("default_content_123", mockRuntime.dispatchedEvents[2].data?["content"] as? String ?? "")
    }

    func testLoadRequestContent_withMboxPrefetched() {
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
                    ],
                    "analytics": {
                      "payload": {
                        "pe": "tnt",
                        "tnta": "33333:1:0|12121|1,38711:1:0|1|1"
                      }
                    }
                  },
                  {
                    "index": 1,
                    "name": "Drink_2",
                    "options": [
                      {
                        "content": {
                          "key2": "value2"
                        },
                        "type": "json",
                        "eventToken": "uR0kIAPO+tZtIPW92S0NnWqipfsIHvVzTQxHolz2IpSCnQ9Y9OaLL2gsdrWQTvE54PwSz67rmXWmSnkXpSSS2Q=="
                      }
                    ],
                    "analytics": {
                      "payload": {
                        "pe": "tnt",
                        "tnta": "33333:1:0|12121|1,38711:1:0|1|1"
                      }
                    }
                  }
                ]
              }
            }
        """

        // builds the prefetch event
        let prefetchDataArray: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_1"),
            TargetPrefetch(name: "Drink_2"),
        ].map {
            $0.asDictionary()
        }

        let data: [String: Any] = [
            "prefetch": prefetchDataArray,
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
        let networkRequestExpectation = XCTestExpectation(description: "monitor the prefetch request")
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { _ in
            let badResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            networkRequestExpectation.fulfill()
            return (data: responseString.data(using: .utf8), response: badResponse, error: nil)
        }
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }

        // handles the prefetch event
        XCTAssertTrue(target.readyForEvent(prefetchEvent))
        eventListener(prefetchEvent)
        wait(for: [networkRequestExpectation], timeout: 1)
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)

        mockRuntime.resetDispatchedEventAndCreatedSharedStates()
        let requestDataArray: [[String: Any]?] = [
            TargetRequest(mboxName: "Drink_1", defaultContent: "default_content"),
            TargetRequest(mboxName: "Drink_2", defaultContent: "default_content"),
        ].map {
            $0.asDictionary()
        }
        let loadRequestData: [String: Any] = [
            "request": requestDataArray,
            "targetparams": TargetParameters(profileParameters: mockProfileParam).asDictionary() as Any,
        ]
        let loadRequestEvent = Event(name: "", type: "", source: "", data: loadRequestData)
        // handles the loadRequest event
        eventListener(loadRequestEvent)
        mockNetworkService.mock { _ in
            XCTFail()
            return nil
        }
        // verifies the content of network response was stored correctly
        XCTAssertEqual(2, mockRuntime.dispatchedEvents.count)
        XCTAssertNotNil(mockRuntime.dispatchedEvents[0].data)
        XCTAssertEqual("{\n  \"key1\" : \"value1\"\n}", mockRuntime.dispatchedEvents[0].data?["content"] as? String ?? "")
        XCTAssertNotNil(mockRuntime.dispatchedEvents[1].data)
        XCTAssertEqual("{\n  \"key2\" : \"value2\"\n}", mockRuntime.dispatchedEvents[1].data?["content"] as? String ?? "")
    }
}
