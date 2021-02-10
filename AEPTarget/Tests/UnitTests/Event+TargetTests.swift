/*
 Copyright 2020 Adobe. All rights reserved.
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
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testPrefetchObjectArray() throws {
        let prefetchDict_1 = TargetPrefetch(name: "prefetch_1", targetParameters: TargetParameters(parameters: ["status": "platinum"], profileParameters: ["age": "20"], order: TargetOrder(id: "order_1", total: 12.45, purchasedProductIds: ["product_1"]), product: TargetProduct(productId: "product_1", categoryId: "category_1"))).asDictionary()
        let prefetchDict_2 = TargetPrefetch(name: "prefetch_1", targetParameters: TargetParameters(parameters: ["status": "platinum"], profileParameters: ["age": "20"], order: TargetOrder(id: "order_1", total: 12.45, purchasedProductIds: ["product_1"]), product: TargetProduct(productId: "product_2", categoryId: "category_1"))).asDictionary()
        let eventData = [TargetConstants.EventDataKeys.PREFETCH_REQUESTS: [prefetchDict_1, prefetchDict_2]]
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
}
