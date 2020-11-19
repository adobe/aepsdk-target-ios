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

@objc(AEPTargetParameters)
public class TargetParameters: NSObject, Codable {
    public let parameters: [String: String]?
    public let profileParameters: [String: String]?
    public let order: TargetOrder?
    public let product: TargetProduct?
    public init(parameters: [String: String]? = nil, profileParameters: [String: String]? = nil, order: TargetOrder? = nil, product: TargetProduct? = nil) {
        self.parameters = parameters
        self.profileParameters = profileParameters
        self.order = order
        self.product = product
    }

    public func toDictionary() -> [String: Any]? {
        asDictionary()
    }

    public static func from(dictionary: [String: Any]) -> TargetParameters? {
        if let jsonData = try? JSONSerialization.data(withJSONObject: dictionary), let prefetchObject = try? JSONDecoder().decode(TargetParameters.self, from: jsonData) {
            return prefetchObject
        }
        return nil
    }
}
