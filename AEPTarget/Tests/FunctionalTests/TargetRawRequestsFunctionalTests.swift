/*
 Copyright 2022 Adobe. All rights reserved.
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

class TargetRawRequestsFunctionalTests: TargetFunctionalTestsBase {
    func testExecuteRawRequest() {
        // mocked network response
        let responseString = """
            {
              "status": 200,
              "id": {
                "tntId": "DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0",
                "marketingCloudVisitorId": "38209274908399841237725561727471528301"
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
                        "type": "json"
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

        let data: [String: Any] = [
            "request": [
                [
                    "name": "t_test_01",
                    "targetParameters": [
                        "parameters": [
                            "mbox-parameter-key1": "mbox-parameter-value1"
                        ],
                        "profileParameters": [
                            "subscription": "premium"
                        ],
                        "order": [
                            "orderId": "id1",
                            "total": 100.34,
                            "purchasedProductIds":[
                                "pId1"
                            ]
                        ],
                        "product": [
                            "productId": "pId1",
                            "categoryId": "cId1"
                        ]
                    ],
                    "defaultContent": "",
                    "responsePairId": ""
                    
                ],
                [
                    "name": "t_test_02",
                    "targetParameters": [
                        "parameters": [
                            "mbox-parameter-key2": "mbox-parameter-value2"
                        ],
                        "profileParameters": [
                            "subscription": "basic"
                        ]
                    ],
                    "defaultContent": "",
                    "responsePairId": ""
                ]
            ],
            "israwevent": true,
            "targetparams": [
                "parameters": [
                    "mbox-parameter-key3": "mbox-parameter-value3"
                ]
            ]
        ]
        let executeRawRequestEvent = Event(name: "TargetRawExecuteRequest", type: "com.adobe.eventType.target", source: "com.adobe.eventSource.requestContent", data: data)

        // creates a configuration shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: executeRawRequestEvent, data: (value: mockConfigSharedState, status: .set))

        // creates a lifecycle shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.lifecycle", event: executeRawRequestEvent, data: (value: mockLifecycleData, status: .set))

        // creates an identity shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: executeRawRequestEvent, data: (value: mockIdentityData, status: .set))

        // registers the event listeners for Target extension
        target.onRegistered()

        let targetRequestExpectation = XCTestExpectation(description: "Target raw execute request expectation")
        
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
            XCTAssertTrue(request.url.absoluteString.contains("https://acopprod3.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId="))
            XCTAssertTrue(Set(payloadDictionary.keys) == Set([
                "id",
                "experienceCloud",
                "context",
                "property",
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

            // verifies payloadDictionary["property"]
            guard let propertyDictionary = payloadDictionary["property"] as? [String: Any] else {
                XCTFail()
                return nil
            }
            XCTAssertEqual("67444eb4-3681-40b4-831d-e082f5ccddcd", propertyDictionary["token"] as? String)
            
            // verifies payloadDictionary["execute"]
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
            XCTAssertEqual(1, executeJson["mboxes"][0]["profileParameters"].count)
            XCTAssertEqual(executeJson["mboxes"][0]["profileParameters"]["subscription"].stringValue, "premium")
            XCTAssertEqual(8, executeJson["mboxes"][0]["parameters"].count)
            XCTAssertNotNil(executeJson["mboxes"][0]["parameters"]["a.Resolution"].stringValue)
            XCTAssertNotNil(executeJson["mboxes"][0]["parameters"]["a.DeviceName"].stringValue)
            XCTAssertNotNil(executeJson["mboxes"][0]["parameters"]["a.RunMode"].stringValue)
            XCTAssertNotNil(executeJson["mboxes"][0]["parameters"]["a.locale"].stringValue)
            XCTAssertNotNil(executeJson["mboxes"][0]["parameters"]["a.OSVersion"].stringValue)
            XCTAssertNotNil(executeJson["mboxes"][0]["parameters"]["a.AppID"].stringValue)
            XCTAssertEqual(executeJson["mboxes"][0]["parameters"]["mbox-parameter-key1"].stringValue, "mbox-parameter-value1")
            XCTAssertEqual(executeJson["mboxes"][0]["parameters"]["mbox-parameter-key3"].stringValue, "mbox-parameter-value3")
            XCTAssertEqual(3, executeJson["mboxes"][0]["order"].count)
            XCTAssertEqual(executeJson["mboxes"][0]["order"]["id"].stringValue, "id1")
            XCTAssertEqual(executeJson["mboxes"][0]["order"]["total"].doubleValue, 100.34)
            XCTAssertEqual(executeJson["mboxes"][0]["order"]["purchasedProductIds"], ["pId1"])
            XCTAssertEqual(2, executeJson["mboxes"][0]["product"].count)
            XCTAssertEqual(executeJson["mboxes"][0]["product"]["id"].stringValue, "pId1")
            XCTAssertEqual(executeJson["mboxes"][0]["product"]["categoryId"].stringValue, "cId1")
            
            XCTAssertEqual(executeJson["mboxes"][1]["index"].intValue, 1)
            XCTAssertEqual(executeJson["mboxes"][1]["name"].stringValue, "t_test_02")
            XCTAssertEqual(1, executeJson["mboxes"][1]["profileParameters"].count)
            XCTAssertEqual(executeJson["mboxes"][1]["profileParameters"]["subscription"].stringValue, "basic")
            XCTAssertEqual(8, executeJson["mboxes"][1]["parameters"].count)
            XCTAssertNotNil(executeJson["mboxes"][1]["parameters"]["a.Resolution"].stringValue)
            XCTAssertNotNil(executeJson["mboxes"][1]["parameters"]["a.DeviceName"].stringValue)
            XCTAssertNotNil(executeJson["mboxes"][1]["parameters"]["a.RunMode"].stringValue)
            XCTAssertNotNil(executeJson["mboxes"][1]["parameters"]["a.locale"].stringValue)
            XCTAssertNotNil(executeJson["mboxes"][1]["parameters"]["a.OSVersion"].stringValue)
            XCTAssertNotNil(executeJson["mboxes"][1]["parameters"]["a.AppID"].stringValue)
            XCTAssertEqual(executeJson["mboxes"][1]["parameters"]["mbox-parameter-key2"].stringValue, "mbox-parameter-value2")
            XCTAssertEqual(executeJson["mboxes"][1]["parameters"]["mbox-parameter-key3"].stringValue, "mbox-parameter-value3")
            
            targetRequestExpectation.fulfill()
            let validResponse = HTTPURLResponse(url: URL(string: "https://acopprod3.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
        }
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(executeRawRequestEvent))

        // handles the execute raw request event
        eventListener(executeRawRequestEvent)
        wait(for: [targetRequestExpectation], timeout: 1)

        // verifies the content of network response was stored correctly
        XCTAssertEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", target.targetState.tntId)
        XCTAssertEqual("mboxedge35.tt.omtrdc.net", target.targetState.edgeHost)
        XCTAssertEqual(0, target.targetState.loadedMboxJsonDicts.count)

        // verifies the Target's shared state
        XCTAssertEqual(1, mockRuntime.createdSharedStates.count)
        XCTAssertEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", mockRuntime.createdSharedStates[0]?["tntid"] as? String)
    }
    
    func testExecuteRawRequest_withPropertyTokenInEventData() {
        mockConfigSharedState = ["target.clientCode": "acopprod3", "global.privacy": "optedin"]

        // mocked network response
        let responseString = """
            {
              "status": 200,
              "id": {
                "tntId": "DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0",
                "marketingCloudVisitorId": "38209274908399841237725561727471528301"
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
                        "type": "json"
                      }
                    ]
                  }
                ]
              }
            }
        """

        let data: [String: Any] = [
            "request": [
                [
                    "name": "t_test_01",
                    "targetParameters": [
                        "parameters": [
                            "mbox-parameter-key1": "mbox-parameter-value1"
                        ]
                    ],
                    "defaultContent": "",
                    "responsePairId": ""
                    
                ]
            ],
            "israwevent": true,
            "targetparams": [
                "parameters": [
                    "mbox-parameter-key3": "mbox-parameter-value3"
                ]
            ],
            "at_property": "a2ec61d0-fab8-42f9-bf0f-699d169b48d8"
        ]
        
        let executeRawRequestEvent = Event(name: "TargetRawExecuteRequest", type: "com.adobe.eventType.target", source: "com.adobe.eventSource.requestContent", data: data)

        // creates a configuration shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: executeRawRequestEvent, data: (value: mockConfigSharedState, status: .set))

        // creates an identity shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: executeRawRequestEvent, data: (value: mockIdentityData, status: .set))

        // registers the event listeners for Target extension
        target.onRegistered()

        let targetRequestExpectation = XCTestExpectation(description: "Target raw execute request expectation")
        
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
            XCTAssertTrue(request.url.absoluteString.contains("https://acopprod3.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId="))
            XCTAssertTrue(Set(payloadDictionary.keys) == Set([
                "id",
                "experienceCloud",
                "context",
                "property",
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

            // verifies payloadDictionary["property"]
            guard let propertyDictionary = payloadDictionary["property"] as? [String: Any] else {
                XCTFail()
                return nil
            }
            XCTAssertEqual("a2ec61d0-fab8-42f9-bf0f-699d169b48d8", propertyDictionary["token"] as? String)
            
            // verifies payloadDictionary["execute"]
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
            XCTAssertEqual(1, mboxes.count)
            let executeJson = JSON(parseJSON: self.prettify(executeDictionary))
            XCTAssertEqual(executeJson["mboxes"][0]["index"].intValue, 0)
            XCTAssertEqual(executeJson["mboxes"][0]["name"].stringValue, "t_test_01")
            XCTAssertEqual(2, executeJson["mboxes"][0]["parameters"].count)
            XCTAssertEqual(executeJson["mboxes"][0]["parameters"]["mbox-parameter-key1"].stringValue, "mbox-parameter-value1")
            XCTAssertEqual(executeJson["mboxes"][0]["parameters"]["mbox-parameter-key3"].stringValue, "mbox-parameter-value3")
            
            targetRequestExpectation.fulfill()
            let validResponse = HTTPURLResponse(url: URL(string: "https://acopprod3.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
        }
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(executeRawRequestEvent))
        
        // handles the execute raw request event
        eventListener(executeRawRequestEvent)
        wait(for: [targetRequestExpectation], timeout: 1)

        // verifies the content of network response was stored correctly
        XCTAssertEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", target.targetState.tntId)
        XCTAssertEqual("mboxedge35.tt.omtrdc.net", target.targetState.edgeHost)
        XCTAssertEqual(0, target.targetState.loadedMboxJsonDicts.count)

        // verifies the Target's shared state
        XCTAssertEqual(1, mockRuntime.createdSharedStates.count)
        XCTAssertEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", mockRuntime.createdSharedStates[0]?["tntid"] as? String)
    }
    
    func testLoadRequestContent_withPropertyTokenInConfigurationAndEventData() {
        // mocked network response
        let responseString = """
            {
              "status": 200,
              "id": {
                "tntId": "DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0",
                "marketingCloudVisitorId": "38209274908399841237725561727471528301"
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
                        "type": "json"
                      }
                    ]
                  }
                ]
              }
            }
        """

        let data: [String: Any] = [
            "request": [
                [
                    "name": "t_test_01",
                    "targetParameters": [
                        "parameters": [
                            "mbox-parameter-key1": "mbox-parameter-value1"
                        ]
                    ],
                    "defaultContent": "",
                    "responsePairId": ""
                    
                ]
            ],
            "israwevent": true,
            "targetparams": [
                "parameters": [
                    "mbox-parameter-key3": "mbox-parameter-value3"
                ]
            ],
            "at_property": "a2ec61d0-fab8-42f9-bf0f-699d169b48d8"
        ]
        
        let executeRawRequestEvent = Event(name: "TargetRawExecuteRequest", type: "com.adobe.eventType.target", source: "com.adobe.eventSource.requestContent", data: data)

        // creates a configuration shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: executeRawRequestEvent, data: (value: mockConfigSharedState, status: .set))

        // creates an identity shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: executeRawRequestEvent, data: (value: mockIdentityData, status: .set))

        // registers the event listeners for Target extension
        target.onRegistered()

        let targetRequestExpectation = XCTestExpectation(description: "Target raw execute request expectation")
        
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
            XCTAssertTrue(request.url.absoluteString.contains("https://acopprod3.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId="))
            XCTAssertTrue(Set(payloadDictionary.keys) == Set([
                "id",
                "experienceCloud",
                "context",
                "property",
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

            // verifies payloadDictionary["property"]
            guard let propertyDictionary = payloadDictionary["property"] as? [String: Any] else {
                XCTFail()
                return nil
            }
            XCTAssertEqual("67444eb4-3681-40b4-831d-e082f5ccddcd", propertyDictionary["token"] as? String)
            
            // verifies payloadDictionary["execute"]
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
            XCTAssertEqual(1, mboxes.count)
            let executeJson = JSON(parseJSON: self.prettify(executeDictionary))
            XCTAssertEqual(executeJson["mboxes"][0]["index"].intValue, 0)
            XCTAssertEqual(executeJson["mboxes"][0]["name"].stringValue, "t_test_01")
            XCTAssertEqual(2, executeJson["mboxes"][0]["parameters"].count)
            XCTAssertEqual(executeJson["mboxes"][0]["parameters"]["mbox-parameter-key1"].stringValue, "mbox-parameter-value1")
            XCTAssertEqual(executeJson["mboxes"][0]["parameters"]["mbox-parameter-key3"].stringValue, "mbox-parameter-value3")
            
            targetRequestExpectation.fulfill()
            let validResponse = HTTPURLResponse(url: URL(string: "https://acopprod3.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
        }
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(executeRawRequestEvent))
        
        // handles the load request event
        eventListener(executeRawRequestEvent)
        wait(for: [targetRequestExpectation], timeout: 1)

        // verifies the content of network response was stored correctly
        XCTAssertEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", target.targetState.tntId)
        XCTAssertEqual("mboxedge35.tt.omtrdc.net", target.targetState.edgeHost)
        XCTAssertEqual(0, target.targetState.loadedMboxJsonDicts.count)

        // verifies the Target's shared state
        XCTAssertEqual(1, mockRuntime.createdSharedStates.count)
        XCTAssertEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", mockRuntime.createdSharedStates[0]?["tntid"] as? String)
    }

    func testExecuteRawRequest_emptyRequestsArray() {
        MockNetworkService.request = nil
        ServiceProvider.shared.networkService = MockNetworkService()
    
        let data: [String: Any] = [
            "request": [],
            "israwevent": true,
        ]
        let executeRawRequestEvent = Event(name: "TargetRawExecuteRequest", type: "com.adobe.eventType.target", source: "com.adobe.eventSource.requestContent", data: data)
        
        // creates a configuration shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: executeRawRequestEvent, data: (value: mockConfigSharedState, status: .set))
        
        target.onRegistered()
        
        let targetRequestExpectation = XCTestExpectation(description: "monitor the prefetch request")
        targetRequestExpectation.isInverted = true
        
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            // verifies network request
            if request.url.absoluteString.contains("https://acopprod3.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId=") {
                targetRequestExpectation.fulfill()
            }
            return nil
        }

        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(executeRawRequestEvent))
        
        // handles the execute raw request event
        eventListener(executeRawRequestEvent)
        wait(for: [targetRequestExpectation], timeout: 1)
    }

    func testExecuteRawRequest_errorResponse() {
        target.targetState.addNotification(Notification(id: UUID().uuidString, timestamp: Int64(Date().timeIntervalSince1970 * 1000.0), type: "click", mbox: Mbox(name: "t_test_02"), tokens: ["LgG0+YDMHn4X5HqGJVoZ5g=="], parameters: nil, profileParameters: nil, order: nil, product: nil))
        
        // mocked network response
        let responseString = """
            {
              "message": "error_message Notifications"
            }
        """

        let data: [String: Any] = [
            "request": [
                [
                    "name": "t_test_01",
                    "targetParameters": [
                        "parameters": [
                            "mbox-parameter-key1": "mbox-parameter-value1"
                        ]
                    ],
                    "defaultContent": "",
                    "responsePairId": ""
                ]
            ],
            "israwevent": true
        ]
        let executeRawRequestEvent = Event(name: "TargetRawExecuteRequest", type: "com.adobe.eventType.target", source: "com.adobe.eventSource.requestContent", data: data)

        // creates a configuration shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: executeRawRequestEvent, data: (value: mockConfigSharedState, status: .set))

        // creates a lifecycle shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.lifecycle", event: executeRawRequestEvent, data: (value: mockLifecycleData, status: .set))

        // creates an identity shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: executeRawRequestEvent, data: (value: mockIdentityData, status: .set))

        // registers the event listeners for Target extension
        target.onRegistered()
        
        let targetRequestExpectation = XCTestExpectation(description: "Target raw execute request expectation")
        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService

        mockNetworkService.mock { request in
            XCTAssertNotNil(request)
            if request.url.absoluteString.contains("https://acopprod3.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId=") {
                targetRequestExpectation.fulfill()
                
                let validResponse = HTTPURLResponse(url: URL(string: "https://acopprod3.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 400, httpVersion: nil, headerFields: nil)

                return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
            }
            return nil
        }
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        
        XCTAssertTrue(target.readyForEvent(executeRawRequestEvent))
        
        // handles the execute raw request event
        eventListener(executeRawRequestEvent)
        wait(for: [targetRequestExpectation], timeout: 2)

        // Check the notifications are cleared
        XCTAssertTrue(target.targetState.notifications.isEmpty)
        XCTAssertEqual(0, target.targetState.loadedMboxJsonDicts.count)
    }

    func testExecuteRawRequest_emptyExecuteMboxesResponse() {
        let responseString = """
            {
              "status": 200,
              "id": {
                "tntId": "DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0",
                "marketingCloudVisitorId": "38209274908399841237725561727471528301"
              },
              "requestId": "01d4a408-6978-48f7-95c6-03f04160b257",
              "client": "acopprod3",
              "edgeHost": "mboxedge35.tt.omtrdc.net",
              "execute": {
                "mboxes": []
              }
            }
        """

        let data: [String: Any] = [
            "request": [
                [
                    "name": "t_test_01",
                    "targetParameters": [
                        "parameters": [
                            "mbox-parameter-key1": "mbox-parameter-value1"
                        ]
                    ],
                    "defaultContent": "",
                    "responsePairId": ""
                ]
            ],
            "israwevent": true
        ]
        let executeRawRequestEvent = Event(name: "TargetRawExecuteRequest", type: "com.adobe.eventType.target", source: "com.adobe.eventSource.requestContent", data: data)

        // creates a configuration shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: executeRawRequestEvent, data: (value: mockConfigSharedState, status: .set))
        
        // registers the event listeners for Target extension
        target.onRegistered()

        let targetRequestExpectation = XCTestExpectation(description: "Target raw execute request expectation")
        
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
            
            if request.url.absoluteString.contains("https://acopprod3.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId=") {
                targetRequestExpectation.fulfill()
                
                let validResponse = HTTPURLResponse(url: URL(string: "https://acopprod3.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
                return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
            }
            return nil
        }
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(executeRawRequestEvent))
        
        // handles the execute raw request event
        eventListener(executeRawRequestEvent)
        wait(for: [targetRequestExpectation], timeout: 2)

        // verifies the content of network response was stored correctly
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)
        XCTAssertNotNil(mockRuntime.dispatchedEvents[0].data)
        let responseData = mockRuntime.dispatchedEvents[0].data?["executemboxes"] as? [[String: Any]]
        XCTAssertEqual(true, responseData?.isEmpty)
    }
    
    func testSendRawNotification() {
        // mocked network response
        let responseString = """
            {
              "status": 200,
              "id": {
                "tntId": "DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0",
                "marketingCloudVisitorId": "38209274908399841237725561727471528301"
              },
              "requestId": "01d4a408-6978-48f7-95c6-03f04160b257",
              "client": "acopprod3",
              "edgeHost": "mboxedge35.tt.omtrdc.net",
              "notifications": {
                    "id": "4BA0B2EF-9A20-4BDC-9F97-0B955BC5FF84",
              }
            }
        """

        // Build the location data
        let data: [String: Any] = [
            "notification": [
                "name": "t_test_01",
                "tokens": ["QPaLjCeI9qKCBUylkRQKBg=="],
                "parameters": [
                    "mbox-parameter-key1": "mbox-parameter-value1"
                ],
                "profileParameters": [
                    "subscription": "premium"
                ],
                "order": [
                    "orderId": "id1",
                    "total": 100.34,
                    "purchasedProductIds":[
                        "pId1"
                    ]
                ],
                "product": [
                    "productId": "pId1",
                    "categoryId": "cId1"
                ]
            ],
            "targetparams": [
                "parameters": [
                    "mbox-parameter-key3": "mbox-parameter-value3"
                ]
            ],
            "islocationclicked": true,
            "israwevent": true
        ]
        
        let sendRawNotificationEvent = Event(name: "TargetRawNotification", type: "com.adobe.eventType.target", source: "com.adobe.eventSource.requestContent", data: data)
        
        // creates a configuration shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: sendRawNotificationEvent, data: (value: mockConfigSharedState, status: .set))

        // creates a lifecycle shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.lifecycle", event: sendRawNotificationEvent, data: (value: mockLifecycleData, status: .set))

        // creates an identity shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: sendRawNotificationEvent, data: (value: mockIdentityData, status: .set))

        target.onRegistered()

        let notificationExpectation = XCTestExpectation(description: "Target raw notification expectation")
        
        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            // verifies network request
            XCTAssertNotNil(request)
            guard let payloadDictionary = self.payloadAsDictionary(request.connectPayload) else {
                XCTFail()
                return (data: nil, response: nil, error: nil)
            }

            XCTAssertTrue(request.url.absoluteString.contains("https://acopprod3.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId="))
            XCTAssertTrue(Set(payloadDictionary.keys) == Set([
                "id",
                "experienceCloud",
                "context",
                "property",
                "notifications",
                "environmentId",
            ]))

            // verifies payloadDictionary["id"]
            guard let idDictionary = payloadDictionary["id"] as? [String: Any] else {
                XCTFail()
                return (data: nil, response: nil, error: nil)
            }
            XCTAssertEqual("38209274908399841237725561727471528301", idDictionary["marketingCloudVisitorId"] as? String)
            guard let vids = idDictionary["customerIds"] as? [[String: Any]] else {
                XCTFail()
                return (data: nil, response: nil, error: nil)
            }
            XCTAssertEqual(1, vids.count)
            XCTAssertEqual("unknown", vids[0]["authenticatedState"] as? String)
            XCTAssertEqual("vid_id_1", vids[0]["id"] as? String)
            XCTAssertEqual("vid_type_1", vids[0]["integrationCode"] as? String)

            // verifies payloadDictionary["context"]
            guard let context = payloadDictionary["context"] as? [String: Any] else {
                XCTFail()
                return (data: nil, response: nil, error: nil)
            }
            XCTAssertTrue(Set(context.keys) == Set([
                "userAgent",
                "mobilePlatform",
                "screen",
                "channel",
                "application",
                "timeOffsetInMinutes",
            ]))

            // verifies payloadDictionary["property"]
            guard let propertyDictionary = payloadDictionary["property"] as? [String: Any] else {
                XCTFail()
                return (data: nil, response: nil, error: nil)
            }
            XCTAssertEqual("67444eb4-3681-40b4-831d-e082f5ccddcd", propertyDictionary["token"] as? String)
            
            // verifies payloadDictionary["notifications"]
            guard let notificationsArray = payloadDictionary["notifications"] as? [[String: Any]] else {
                XCTFail()
                return (data: nil, response: nil, error: nil)
            }
            
            XCTAssertNotNil(notificationsArray)
            XCTAssertEqual(1, notificationsArray.count)

            let notificationsJson = JSON(parseJSON: self.prettify(notificationsArray))
            XCTAssertNotNil(notificationsJson[0]["id"])
            XCTAssertNotNil(notificationsJson[0]["timestamp"])
            XCTAssertEqual("t_test_01", notificationsJson[0]["mbox"]["name"])
            XCTAssertEqual(1, notificationsJson[0]["tokens"].count)
            XCTAssertEqual("QPaLjCeI9qKCBUylkRQKBg==", notificationsJson[0]["tokens"][0])
            XCTAssertEqual("click", notificationsJson[0]["type"])
            XCTAssertEqual(8, notificationsJson[0]["parameters"].count)
            XCTAssertNotNil(notificationsJson[0]["parameters"]["a.Resolution"].stringValue)
            XCTAssertNotNil(notificationsJson[0]["parameters"]["a.DeviceName"].stringValue)
            XCTAssertNotNil(notificationsJson[0]["parameters"]["a.RunMode"].stringValue)
            XCTAssertNotNil(notificationsJson[0]["parameters"]["a.locale"].stringValue)
            XCTAssertNotNil(notificationsJson[0]["parameters"]["a.OSVersion"].stringValue)
            XCTAssertNotNil(notificationsJson[0]["parameters"]["a.AppID"].stringValue)
            XCTAssertEqual("mbox-parameter-value1", notificationsJson[0]["parameters"]["mbox-parameter-key1"].stringValue)
            XCTAssertEqual("mbox-parameter-value3", notificationsJson[0]["parameters"]["mbox-parameter-key3"].stringValue)
            XCTAssertEqual(1, notificationsJson[0]["profileParameters"].count)
            XCTAssertEqual("premium", notificationsJson[0]["profileParameters"]["subscription"])
            XCTAssertEqual(3, notificationsJson[0]["order"].count)
            XCTAssertEqual(notificationsJson[0]["order"]["id"].stringValue, "id1")
            XCTAssertEqual(notificationsJson[0]["order"]["total"].doubleValue, 100.34)
            XCTAssertEqual(notificationsJson[0]["order"]["purchasedProductIds"], ["pId1"])
            XCTAssertEqual(2, notificationsJson[0]["product"].count)
            XCTAssertEqual(notificationsJson[0]["product"]["id"].stringValue, "pId1")
            XCTAssertEqual(notificationsJson[0]["product"]["categoryId"].stringValue, "cId1")

            notificationExpectation.fulfill()
            let validResponse = HTTPURLResponse(url: URL(string: "https://acopprod3.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
        }

        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }

        XCTAssertTrue(target.readyForEvent(sendRawNotificationEvent))
        
        // handles the send raw notification event
        eventListener(sendRawNotificationEvent)
        wait(for: [notificationExpectation], timeout: 2)

        // Check the notifications are cleared
        XCTAssertTrue(target.targetState.notifications.isEmpty)

        // verifies the content of network response was stored correctly
        XCTAssertEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", target.targetState.tntId)
        XCTAssertEqual("mboxedge35.tt.omtrdc.net", target.targetState.edgeHost)

        // verifies the Target's shared state
        XCTAssertEqual(1, mockRuntime.createdSharedStates.count)
        XCTAssertEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", mockRuntime.createdSharedStates[0]?["tntid"] as? String)
    }

    func testSendRawNotification_withPropertyTokenInEventData() {
        mockConfigSharedState = ["target.clientCode": "acopprod3", "global.privacy": "optedin"]
        
        // mocked network response
        let responseString = """
            {
              "status": 200,
              "id": {
                "tntId": "DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0",
                "marketingCloudVisitorId": "38209274908399841237725561727471528301"
              },
              "requestId": "01d4a408-6978-48f7-95c6-03f04160b257",
              "client": "acopprod3",
              "edgeHost": "mboxedge35.tt.omtrdc.net",
              "notifications": {
                    "id": "4BA0B2EF-9A20-4BDC-9F97-0B955BC5FF84",
              }
            }
        """

        // Build the location data
        let data: [String: Any] = [
            "notification": [
                "name": "t_test_01",
                "tokens": ["QPaLjCeI9qKCBUylkRQKBg=="],
                "parameters": [
                    "mbox-parameter-key1": "mbox-parameter-value1"
                ]
            ],
            "targetparams": [
                "parameters": [
                    "mbox-parameter-key3": "mbox-parameter-value3"
                ]
            ],
            "at_property": "a2ec61d0-fab8-42f9-bf0f-699d169b48d8",
            "islocationclicked": true,
            "israwevent": true
        ]
        
        let sendRawNotificationEvent = Event(name: "TargetRawNotification", type: "com.adobe.eventType.target", source: "com.adobe.eventSource.requestContent", data: data)
        
        // creates a configuration shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: sendRawNotificationEvent, data: (value: mockConfigSharedState, status: .set))

        // creates an identity shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: sendRawNotificationEvent, data: (value: mockIdentityData, status: .set))

        target.onRegistered()

        let notificationExpectation = XCTestExpectation(description: "Target raw notification expectation")
        
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
            XCTAssertTrue(request.url.absoluteString.contains("https://acopprod3.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId="))
            XCTAssertTrue(Set(payloadDictionary.keys) == Set([
                "id",
                "experienceCloud",
                "context",
                "property",
                "notifications",
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
            
            // verifies payloadDictionary["property"]
            guard let propertyDictionary = payloadDictionary["property"] as? [String: Any] else {
                XCTFail()
                return nil
            }
            XCTAssertEqual("a2ec61d0-fab8-42f9-bf0f-699d169b48d8", propertyDictionary["token"] as? String)

            // verifies payloadDictionary["notifications"]
            guard let notificationsArray = payloadDictionary["notifications"] as? [[String: Any]] else {
                XCTFail()
                return nil
            }

            XCTAssertNotNil(notificationsArray)
            XCTAssertEqual(1, notificationsArray.count)

            let notificationsJson = JSON(parseJSON: self.prettify(notificationsArray))
            XCTAssertNotNil(notificationsJson[0]["id"])
            XCTAssertNotNil(notificationsJson[0]["timestamp"])
            XCTAssertEqual("t_test_01", notificationsJson[0]["mbox"]["name"])
            XCTAssertEqual(1, notificationsJson[0]["tokens"].count)
            XCTAssertEqual("QPaLjCeI9qKCBUylkRQKBg==", notificationsJson[0]["tokens"][0])
            XCTAssertEqual("click", notificationsJson[0]["type"])
            XCTAssertEqual(2, notificationsJson[0]["parameters"].count)
            XCTAssertEqual("mbox-parameter-value1", notificationsJson[0]["parameters"]["mbox-parameter-key1"].stringValue)
            XCTAssertEqual("mbox-parameter-value3", notificationsJson[0]["parameters"]["mbox-parameter-key3"].stringValue)
            
            notificationExpectation.fulfill()
            let validResponse = HTTPURLResponse(url: URL(string: "https://acopprod3.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
        }

        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }

        XCTAssertTrue(target.readyForEvent(sendRawNotificationEvent))
        // handles the send raw notification event
        eventListener(sendRawNotificationEvent)
        wait(for: [notificationExpectation], timeout: 2)

        // Check the notifications are cleared
        XCTAssertTrue(target.targetState.notifications.isEmpty)

        // verifies the content of network response was stored correctly
        XCTAssertEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", target.targetState.tntId)
        XCTAssertEqual("mboxedge35.tt.omtrdc.net", target.targetState.edgeHost)

        // verifies the Target's shared state
        XCTAssertEqual(1, mockRuntime.createdSharedStates.count)
        XCTAssertEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", mockRuntime.createdSharedStates[0]?["tntid"] as? String)
    }
    
    func testSendRawNotification_withPropertyTokenInConfigurationAndEventData() {
        // mocked network response
        let responseString = """
            {
              "status": 200,
              "id": {
                "tntId": "DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0",
                "marketingCloudVisitorId": "38209274908399841237725561727471528301"
              },
              "requestId": "01d4a408-6978-48f7-95c6-03f04160b257",
              "client": "acopprod3",
              "edgeHost": "mboxedge35.tt.omtrdc.net",
              "notifications": {
                    "id": "4BA0B2EF-9A20-4BDC-9F97-0B955BC5FF84",
              }
            }
        """

        // Build the location data
        let data: [String: Any] = [
            "notification": [
                "name": "t_test_01",
                "tokens": ["QPaLjCeI9qKCBUylkRQKBg=="],
                "parameters": [
                    "mbox-parameter-key1": "mbox-parameter-value1"
                ]
            ],
            "targetparams": [
                "parameters": [
                    "mbox-parameter-key3": "mbox-parameter-value3"
                ]
            ],
            "islocationclicked": true,
            "israwevent": true
        ]
        
        let sendRawNotificationEvent = Event(name: "TargetRawNotification", type: "com.adobe.eventType.target", source: "com.adobe.eventSource.requestContent", data: data)
        
        // creates a configuration shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: sendRawNotificationEvent, data: (value: mockConfigSharedState, status: .set))

        // creates an identity shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: sendRawNotificationEvent, data: (value: mockIdentityData, status: .set))

        target.onRegistered()

        let notificationExpectation = XCTestExpectation(description: "Target raw notification expectation")
        
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
            XCTAssertTrue(request.url.absoluteString.contains("https://acopprod3.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId="))
            XCTAssertTrue(Set(payloadDictionary.keys) == Set([
                "id",
                "experienceCloud",
                "context",
                "property",
                "notifications",
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
            
            // verifies payloadDictionary["property"]
            guard let propertyDictionary = payloadDictionary["property"] as? [String: Any] else {
                XCTFail()
                return nil
            }
            XCTAssertEqual("67444eb4-3681-40b4-831d-e082f5ccddcd", propertyDictionary["token"] as? String)

            // verifies payloadDictionary["notifications"]
            guard let notificationsArray = payloadDictionary["notifications"] as? [[String: Any]] else {
                XCTFail()
                return nil
            }

            XCTAssertNotNil(notificationsArray)
            XCTAssertEqual(1, notificationsArray.count)

            let notificationsJson = JSON(parseJSON: self.prettify(notificationsArray))
            XCTAssertNotNil(notificationsJson[0]["id"])
            XCTAssertNotNil(notificationsJson[0]["timestamp"])
            XCTAssertEqual("t_test_01", notificationsJson[0]["mbox"]["name"])
            XCTAssertEqual(1, notificationsJson[0]["tokens"].count)
            XCTAssertEqual("QPaLjCeI9qKCBUylkRQKBg==", notificationsJson[0]["tokens"][0])
            XCTAssertEqual("click", notificationsJson[0]["type"])
            XCTAssertEqual(2, notificationsJson[0]["parameters"].count)
            XCTAssertEqual("mbox-parameter-value1", notificationsJson[0]["parameters"]["mbox-parameter-key1"].stringValue)
            XCTAssertEqual("mbox-parameter-value3", notificationsJson[0]["parameters"]["mbox-parameter-key3"].stringValue)
            
            notificationExpectation.fulfill()
            let validResponse = HTTPURLResponse(url: URL(string: "https://acopprod3.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
        }

        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }

        XCTAssertTrue(target.readyForEvent(sendRawNotificationEvent))
        // handles the send raw notification event
        eventListener(sendRawNotificationEvent)
        wait(for: [notificationExpectation], timeout: 2)

        // Check the notifications are cleared
        XCTAssertTrue(target.targetState.notifications.isEmpty)

        // verifies the content of network response was stored correctly
        XCTAssertEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", target.targetState.tntId)
        XCTAssertEqual("mboxedge35.tt.omtrdc.net", target.targetState.edgeHost)

        // verifies the Target's shared state
        XCTAssertEqual(1, mockRuntime.createdSharedStates.count)
        XCTAssertEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", mockRuntime.createdSharedStates[0]?["tntid"] as? String)
    }

    func testSendRawNotification_afterRawExecuteRequest() {
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
                        "type": "json"
                      }
                    ],
                    "metrics": [
                     {
                        "type":"click",
                        "eventToken":"ABPi/uih7s0vo6/8kqyxjA=="
                     }
                    ]
                  }
                ]
              }
            }
        """

        let data: [String: Any] = [
            "request": [
                [
                    "name": "t_test_01",
                    "targetParameters": [
                        "parameters": [
                            "mbox-parameter-key1": "mbox-parameter-value1"
                        ]
                    ],
                    "defaultContent": "",
                    "responsePairId": ""
                    
                ]
            ],
            "israwevent": true,
            "targetparams": [
                "parameters": [
                    "mbox-parameter-key3": "mbox-parameter-value3"
                ]
            ]
        ]
        let executeRawRequestEvent = Event(name: "TargetRawExecuteRequest", type: "com.adobe.eventType.target", source: "com.adobe.eventSource.requestContent", data: data)

        // creates a configuration shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: executeRawRequestEvent, data: (value: mockConfigSharedState, status: .set))

        // creates an identity shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: executeRawRequestEvent, data: (value: mockIdentityData, status: .set))

        // registers the event listeners for Target extension
        target.onRegistered()

        let targetRequestExpectation = XCTestExpectation(description: "Target raw execute request expectation")
        
        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            XCTAssertNotNil(request)
            if request.url.absoluteString.contains("https://acopprod3.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId=") {
                targetRequestExpectation.fulfill()
                let validResponse = HTTPURLResponse(url: URL(string: "https://acopprod3.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
                return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
            }
            return nil
        }

        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }

        XCTAssertTrue(target.readyForEvent(executeRawRequestEvent))
        
        // handles execute raw request event
        eventListener(executeRawRequestEvent)
        wait(for: [targetRequestExpectation], timeout: 2)

        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)
        guard
            let data = mockRuntime.dispatchedEvents[0].data,
            let executeMboxesArray = data["executemboxes"] as? [[String: Any]]
        else {
            XCTFail()
            return
        }
           
        XCTAssertEqual(1, executeMboxesArray.count)
        XCTAssertEqual("t_test_01", executeMboxesArray[0]["name"] as? String)
        let metrics = executeMboxesArray[0]["metrics"] as? [[String: Any]]
        XCTAssertEqual(1, metrics?.count)
        XCTAssertEqual("click", metrics?[0]["type"] as? String)
        let notificationToken = metrics?[0]["eventToken"] as? String
        XCTAssertEqual("ABPi/uih7s0vo6/8kqyxjA==", notificationToken)
        
        mockRuntime.createdSharedStates = []
        let notificationResponseString = """
            {
              "status": 200,
              "id": {
                "tntId": "DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0",
                "marketingCloudVisitorId": "38209274908399841237725561727471528301"
              },
              "requestId": "01d4a408-6978-48f7-95c6-03f04160b257",
              "client": "acopprod3",
              "edgeHost": "mboxedge35.tt.omtrdc.net",
              "notifications": {
                    "id": "4BA0B2EF-9A20-4BDC-9F97-0B955BC5FF84",
              }
            }
        """
        
        // Build the notification data
        let notificationData: [String: Any] = [
            "notification": [
                "name": "t_test_01",
                "tokens": [notificationToken],
                "parameters": [
                    "mbox-parameter-key2": "mbox-parameter-value2"
                ]
            ],
            "targetparams": [
                "parameters": [
                    "mbox-parameter-key4": "mbox-parameter-value4"
                ]
            ],
            "islocationclicked": true,
            "israwevent": true
        ]
        let sendRawNotificationEvent = Event(name: "TargetRawNotification", type: "com.adobe.eventType.target", source: "com.adobe.eventSource.requestContent", data: notificationData)
        
        let notificationExpectation = XCTestExpectation(description: "Target raw notification expectation")
        
        mockNetworkService.resolvers.removeAll()
        mockNetworkService.mock { request in
            XCTAssertNotNil(request)
            if !request.url.absoluteString.contains("https://mboxedge35.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId=") {
                XCTFail()
                return nil
            }

            guard let payloadDictionary = self.payloadAsDictionary(request.connectPayload) else {
                XCTFail()
                return nil
            }

            guard let notificationsArray = payloadDictionary["notifications"] as? [[String: Any]] else {
                XCTFail()
                return nil
            }

            XCTAssertEqual(1, notificationsArray.count)
            let notificationsJson = JSON(parseJSON: self.prettify(notificationsArray))
            XCTAssertNotNil(notificationsJson[0]["id"])
            XCTAssertNotNil(notificationsJson[0]["timestamp"])
            XCTAssertEqual("t_test_01", notificationsJson[0]["mbox"]["name"])
            XCTAssertEqual(1, notificationsJson[0]["tokens"].count)
            XCTAssertEqual("ABPi/uih7s0vo6/8kqyxjA==", notificationsJson[0]["tokens"][0])
            XCTAssertEqual("click", notificationsJson[0]["type"])
            XCTAssertEqual(2, notificationsJson[0]["parameters"].count)
            XCTAssertEqual("mbox-parameter-value2", notificationsJson[0]["parameters"]["mbox-parameter-key2"].stringValue)
            XCTAssertEqual("mbox-parameter-value4", notificationsJson[0]["parameters"]["mbox-parameter-key4"].stringValue)
            
            notificationExpectation.fulfill()
            
            let validResponse = HTTPURLResponse(url: URL(string: "https://acopprod3.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data: notificationResponseString.data(using: .utf8), response: validResponse, error: nil)
        }

        // simulate send raw notification event
        mockRuntime.simulateComingEvent(event: sendRawNotificationEvent)
        wait(for: [notificationExpectation], timeout: 2)
        
        // Check the notifications are cleared
        XCTAssertTrue(target.targetState.notifications.isEmpty)
        
        // verifies the content of network response was stored correctly
        XCTAssertEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", target.targetState.tntId)
        XCTAssertEqual("mboxedge35.tt.omtrdc.net", target.targetState.edgeHost)

        // verifies the Target's shared state
        XCTAssertEqual(1, mockRuntime.createdSharedStates.count)
        XCTAssertEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", mockRuntime.createdSharedStates[0]?["tntid"] as? String)
    }

    func testSendRawNotification_noNotificationMboxName() {
        MockNetworkService.request = nil
        ServiceProvider.shared.networkService = MockNetworkService()
        
        let data: [String: Any] = [
            "notification": [
                "tokens": ["QPaLjCeI9qKCBUylkRQKBg=="],
                "parameters": [
                    "mbox-parameter-key1": "mbox-parameter-value1"
                ]
            ],
            "islocationclicked": true,
            "israwevent": true
        ]
        
        let sendRawNotificationEvent = Event(name: "TargetRawNotification", type: "com.adobe.eventType.target", source: "com.adobe.eventSource.requestContent", data: data)
        
        // creates a configuration shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: sendRawNotificationEvent, data: (value: mockConfigSharedState, status: .set))
        
        target.onRegistered()

        let notificationExpectation = XCTestExpectation(description: "Target raw notification expectation")
        notificationExpectation.isInverted = true
        
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            // verifies network request
            if request.url.absoluteString.contains("https://acopprod3.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId=") {
                notificationExpectation.fulfill()
            }
            return nil
        }

        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(sendRawNotificationEvent))
        
        // handles the send raw notification event
        eventListener(sendRawNotificationEvent)
        wait(for: [notificationExpectation], timeout: 1)
    }

    func testSendRawNotification_noNotificationToken() {
        // mocked network response
        let data: [String: Any] = [
            "notification": [
                "name": "t_test_01",
                "parameters": [
                    "mbox-parameter-key1": "mbox-parameter-value1"
                ]
            ],
            "islocationclicked": true,
            "israwevent": true
        ]
        
        let sendRawNotificationEvent = Event(name: "TargetRawNotification", type: "com.adobe.eventType.target", source: "com.adobe.eventSource.requestContent", data: data)
        
        // creates a configuration shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: sendRawNotificationEvent, data: (value: mockConfigSharedState, status: .set))

        // registers the event listeners for Target extension
        target.onRegistered()
        
        let notificationExpectation = XCTestExpectation(description: "Target raw notification expectation")
        notificationExpectation.isInverted = true

        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            // verifies network request
            if request.url.absoluteString.contains("https://acopprod3.tt.omtrdc.net/rest/v1/delivery/?client=acopprod3&sessionId=") {
                notificationExpectation.fulfill()
            }
            return nil
        }
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(sendRawNotificationEvent))
        
        // handles the send raw notification event
        eventListener(sendRawNotificationEvent)
        wait(for: [notificationExpectation], timeout: 1)
    }
    
    func testSendRawNotification_notificationErrorResponse() {
        // mocked network response
        let responseString = """
            {
              "message": "Notifications error"
            }
        """

        // Build the location data
        let data: [String: Any] = [
            "notification": [
                "name": "t_test_01",
                "tokens": ["QPaLjCeI9qKCBUylkRQKBg=="],
                "parameters": [
                    "mbox-parameter-key1": "mbox-parameter-value1"
                ]
            ],
            "islocationclicked": true,
            "israwevent": true
        ]
        
        let sendRawNotificationEvent = Event(name: "TargetRawNotification", type: "com.adobe.eventType.target", source: "com.adobe.eventSource.requestContent", data: data)
        
        // creates a configuration shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: sendRawNotificationEvent, data: (value: mockConfigSharedState, status: .set))

        // creates an identity shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: sendRawNotificationEvent, data: (value: mockIdentityData, status: .set))

        target.onRegistered()

        let notificationExpectation = XCTestExpectation(description: "Target raw notification expectation")
        
        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            XCTAssertNotNil(request)
            notificationExpectation.fulfill()
            let targetResponse = HTTPURLResponse(url: URL(string: "https://acopprod3.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 400, httpVersion: nil, headerFields: nil)

            return (data: responseString.data(using: .utf8), response: targetResponse, error: nil)
        }

        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(sendRawNotificationEvent))

        // handles the send raw notification event
        eventListener(sendRawNotificationEvent)
        wait(for: [notificationExpectation], timeout: 2)

        // Check the notifications are cleared
        XCTAssertTrue(target.targetState.notifications.isEmpty)

        // verifies the content of network response was stored correctly
        XCTAssertNotEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", target.targetState.tntId)
        XCTAssertNotEqual("mboxedge35.tt.omtrdc.net", target.targetState.edgeHost)

        // verifies the Target shared state
        XCTAssertEqual(0, mockRuntime.createdSharedStates.count)
    }
}
