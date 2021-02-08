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
import Foundation

/// Class for specifying Target order parameters
@objc(AEPTargetOrder)
public class TargetOrder: NSObject, Codable {
    public let orderId: String
    public let total: Double?
    public let purchasedProductIds: [String]?
    
    /// Initialize a `TargetOrder` with an order `id`, order `total`  and a list of `purchasedProductIds`
    /// - Parameters:
    ///   - id: `String` order id
    ///   - total: `Double` order total amount
    ///   - purchasedProductIds: a list of purchased product ids
    public init(id: String, total: Double? = nil, purchasedProductIds: [String]? = nil) {
        orderId = id
        self.total = total
        self.purchasedProductIds = purchasedProductIds
    }
}
