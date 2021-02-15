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

enum TargetError: Error, CustomStringConvertible {
    case emptyPrefetchListError
    case invalidRequestError
    case timeoutError
    case configNilError
    case clientCodeEmptyError
    case optedOutError
    case custom(String)

    var description: String {
        switch self {
        case .emptyPrefetchListError:
            return "Empty or nill prefetch requests list"
        case .invalidRequestError:
            return "Invalid request error"
        case .timeoutError:
            return "API call timeout"
        case .configNilError:
            return "Configuration was nil"
        case .clientCodeEmptyError:
            return "Client code was nil or empty"
        case .optedOutError:
            return "Opted out"
        case let .custom(message):
            return message
        }
    }
}
