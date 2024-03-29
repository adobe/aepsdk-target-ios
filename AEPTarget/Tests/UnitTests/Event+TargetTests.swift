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

import AEPCore
@testable import AEPTarget
import XCTest

class TargetEventTests: XCTestCase {
    let mockTargetParameter_1 = TargetParameters(parameters: ["status": "gold"], profileParameters: ["age": "20"], order: TargetOrder(id: "order_1", total: 12.45, purchasedProductIds: ["product_1"]), product: TargetProduct(productId: "product_1", categoryId: "category_1"))
    let mockTargetParameter_2 = TargetParameters(parameters: ["status": "platinum"], profileParameters: ["age": "20"], order: TargetOrder(id: "order_1", total: 12.45, purchasedProductIds: ["product_1"]), product: TargetProduct(productId: "product_2", categoryId: "category_1"))
    let mockDefaultContent_1 = "Content_1"
    let mockDefaultContent_2 = "Content_2"

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testPrefetchObjectArray() throws {
        let prefetchDict_1 = TargetPrefetch(name: "prefetch_1", targetParameters: TargetParameters(parameters: ["status": "platinum"], profileParameters: ["age": "20"], order: TargetOrder(id: "order_1", total: 12.45, purchasedProductIds: ["product_1"]), product: TargetProduct(productId: "product_1", categoryId: "category_1"))).asDictionary()
        let prefetchDict_2 = TargetPrefetch(name: "prefetch_1", targetParameters: TargetParameters(parameters: ["status": "platinum"], profileParameters: ["age": "20"], order: TargetOrder(id: "order_1", total: 12.45, purchasedProductIds: ["product_1"]), product: TargetProduct(productId: "product_2", categoryId: "category_1"))).asDictionary()
        let eventData = [TargetConstants.EventDataKeys.PREFETCH: [prefetchDict_1, prefetchDict_2]]
        let event = Event(name: TargetConstants.EventName.PREFETCH_REQUESTS, type: EventType.target, source: EventSource.requestContent, data: eventData as [String: Any])
        guard let array: [TargetPrefetch] = event.prefetchObjectArray else {
            XCTFail()
            return
        }
        XCTAssertEqual(2, array.count)
        XCTAssertEqual("prefetch_1", array[0].name)
        XCTAssertEqual("20", array[0].targetParameters?.profileParameters?["age"])
        XCTAssertEqual("order_1", array[0].targetParameters?.order?.orderId)
        XCTAssertEqual("product_2", array[1].targetParameters?.product?.productId)
    }

    func testBatchRequestObjectArray() throws {
        let requestDict_1 = TargetRequest(mboxName: "request_1", defaultContent: mockDefaultContent_1, targetParameters: mockTargetParameter_1, contentCallback: nil).asDictionary()
        let requestDict_2 = TargetRequest(mboxName: "request_2", defaultContent: mockDefaultContent_2, targetParameters: mockTargetParameter_2, contentCallback: nil).asDictionary()
        let eventData = [TargetConstants.EventDataKeys.LOAD_REQUESTS: [requestDict_1, requestDict_2]]
        let event = Event(name: TargetConstants.EventName.LOAD_REQUEST, type: EventType.target, source: EventSource.requestContent, data: eventData as [String: Any])
        guard let array: [TargetRequest] = event.targetRequests else {
            XCTFail()
            return
        }
        XCTAssertEqual(2, array.count)
        XCTAssertEqual("request_1", array[0].name)
        XCTAssertEqual("20", array[0].targetParameters?.profileParameters?["age"])
        XCTAssertEqual("order_1", array[0].targetParameters?.order?.orderId)
        XCTAssertEqual("product_2", array[1].targetParameters?.product?.productId)
    }
    
    func testBatchRequestObjectArray_empty() throws {
        let eventData = [TargetConstants.EventDataKeys.LOAD_REQUESTS: []]
        let event = Event(name: TargetConstants.EventName.LOAD_REQUEST, type: EventType.target, source: EventSource.requestContent, data: eventData as [String: Any])
        let requestsArray = event.targetRequests
        XCTAssertNil(requestsArray)
    }

    func testTargetParameters() throws {
        let targetParameters = TargetParameters(parameters: ["status": "platinum"], profileParameters: ["age": "20"], order: TargetOrder(id: "order_1", total: 12.45, purchasedProductIds: ["product_1"]), product: TargetProduct(productId: "product_1", categoryId: "category_1"))
        let targetParametersDict = targetParameters.asDictionary()
        let eventData = [TargetConstants.EventDataKeys.TARGET_PARAMETERS: targetParametersDict]
        let event = Event(name: TargetConstants.EventName.PREFETCH_REQUESTS, type: EventType.target, source: EventSource.requestContent, data: eventData as [String: Any])
        guard let parameters = event.targetParameters else {
            XCTFail()
            return
        }
        XCTAssertEqual("20", parameters.profileParameters?["age"])
        XCTAssertEqual("order_1", parameters.order?.orderId)
    }
    
    func testTargetAtProperty() throws {
        let requestDict = TargetRequest(mboxName: "request_1", defaultContent: mockDefaultContent_1, targetParameters: mockTargetParameter_1, contentCallback: nil).asDictionary()
        let eventData = ["request": [requestDict], "at_property": "ccc8cdb3-c67a-6126-10b3-65d7f4d32b69"] as [String: Any]
        let event = Event(name: "request", type: "com.adobe.eventType.target", source: "com.adobe.eventSource.requestContent", data: eventData as [String: Any])
        XCTAssertEqual("ccc8cdb3-c67a-6126-10b3-65d7f4d32b69", event.propertyToken)
    }

    func testIsLocationDisplayedEvent() throws {
        let eventData = [TargetConstants.EventDataKeys.TARGET_PARAMETERS: nil, TargetConstants.EventDataKeys.IS_LOCATION_DISPLAYED: true] as [String: Any?]
        let event = Event(name: TargetConstants.EventName.LOCATIONS_DISPLAYED, type: EventType.target, source: EventSource.requestContent, data: eventData as [String: Any])
        XCTAssertTrue(event.isLocationsDisplayedEvent)
    }

    func testIsLocationClickedEvent() throws {
        let eventData = [TargetConstants.EventDataKeys.TARGET_PARAMETERS: nil, TargetConstants.EventDataKeys.IS_LOCATION_CLICKED: true] as [String: Any?]
        let event = Event(name: TargetConstants.EventName.LOCATION_CLICKED, type: EventType.target, source: EventSource.requestContent, data: eventData as [String: Any])
        XCTAssertTrue(event.isLocationClickedEvent)
    }

    func testIsResetExperience() throws {
        let eventData = [TargetConstants.EventDataKeys.RESET_EXPERIENCE: true] as [String: Any]
        let event = Event(name: TargetConstants.EventName.REQUEST_RESET, type: EventType.target, source: EventSource.requestReset, data: eventData as [String: Any])
        XCTAssertTrue(event.isResetExperienceEvent)
    }
    
    func testTargetEnvironmentId() throws {
        let eventData: [String: Any] = [TargetConstants.EventDataKeys.ENVIRONMENT_ID: Int64(1123)]
        let event = Event(name: TargetConstants.EventName.TARGET_RAW_REQUEST, type: EventType.target, source: EventSource.requestContent, data: eventData)
        XCTAssertEqual(Int64(1123), event.environmentId)
    }
    
    func testGetTypedData_keyInEventDataValid() {
        
        let data: [String: Any] = [
            "request": [
                [
                    "name": "testMbox1",
                    "targetParameters": [
                        "parameters": [
                            "mbox-parameter-key1": "mbox-parameter-value1"
                        ]
                    ],
                    "defaultContent": "default",
                    "responsePairId": "11111"
                ]
            ]
        ]

        let testEvent = Event(name: "Test Event",
                              type: "com.adobe.eventType.target",
                              source: "com.adobe.eventSource.requestContent",
                              data: data)

        guard let requestsArray: [TargetRequest] = testEvent.getTypedData(for: "request") else {
            XCTFail("Target request array should be valid.")
            return
        }
        XCTAssertEqual(1, requestsArray.count)
        XCTAssertEqual("testMbox1", requestsArray[0].name)
        XCTAssertEqual("default", requestsArray[0].defaultContent)
        XCTAssertEqual("11111", requestsArray[0].responsePairId)
        XCTAssertEqual(1, requestsArray[0].targetParameters?.parameters?.count)
        XCTAssertEqual("mbox-parameter-value1", requestsArray[0].targetParameters?.parameters?["mbox-parameter-key1"])
    }

    func testGetTypedData_keyInEventDataInvalid() {

        let data: [String: Any] = [
            "request": [
                [
                    "name1": "testMbox1",
                    "targetParameters": [
                        "parameters": [
                            "mbox-parameter-key1": "mbox-parameter-value1"
                        ]
                    ],
                    "defaultContent": "default",
                    "responsePairId": "11111"
                ]
            ]
        ]
        
        let testEvent = Event(name: "Test Event",
                              type: "com.adobe.eventType.target",
                              source: "com.adobe.eventSource.requestContent",
                              data: data)

        let requestsArray: [TargetRequest]? = testEvent.getTypedData(for: "request")
        XCTAssertNil(requestsArray)
    }

    func testGetTypedData_keyNotInEventData() {

        let data: [String: Any] = [
            "request1": [
                [
                    "name": "testMbox1",
                    "targetParameters": [
                        "parameters": [
                            "mbox-parameter-key1": "mbox-parameter-value1"
                        ]
                    ],
                    "defaultContent": "default",
                    "responsePairId": "11111"
                ]
            ]
        ]
        
        let testEvent = Event(name: "Test Event",
                              type: "com.adobe.eventType.target",
                              source: "com.adobe.eventSource.requestContent",
                              data: data)

        let scopesArray: [TargetRequest]? = testEvent.getTypedData(for: "request")
        XCTAssertNil(scopesArray)
    }

    func testGetTypedData_EventData() {
        let data: [String: Any] = [
            "name": "testMbox1",
            "targetParameters": [
                "parameters": [
                    "mbox-parameter-key1": "mbox-parameter-value1"
                ]
            ],
            "defaultContent": "default",
            "responsePairId": "11111"
        ]
        
        let testEvent = Event(name: "Test Event",
                              type: "com.adobe.eventType.target",
                              source: "com.adobe.eventSource.requestContent",
                              data: data)

        guard let request: TargetRequest = testEvent.getTypedData() else {
            XCTFail("TargetRequest instance should be valid.")
            return
        }
        XCTAssertEqual("testMbox1", request.name)
    }
}
