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

import Foundation

///
/// Represents the DeepLinkScheme for a Preview
///
enum DeepLinkScheme {
    case cancel
    case confirm
}

extension URL {
    ///
    /// The query items extracted from the URL as a dictionary
    ///
    var queryItemsDict: [String: String]? {
        guard let urlComponents = URLComponents(url: self, resolvingAgainstBaseURL: true),
              let queryItems = urlComponents.queryItems
        else {
            return nil
        }
        return queryItems.reduce([String: String]()) { (dict, queryItem) -> [String: String] in
            var dict = dict
            dict[queryItem.name] = queryItem.value
            return dict
        }
    }

    ///
    /// The DeepLinkScheme for the URL. Nil if the scheme does not match expected Scheme.
    /// If it does match, checks host and returns the given `DeepLinkScheme`
    ///
    var deepLinkScheme: DeepLinkScheme? {
        typealias consts = TargetConstants.PreviewManager
        if scheme != consts.DEEPLINK_SCHEME {
            return nil
        }

        if host == consts.DEEPLINK_SCHEME_PATH_CANCEL {
            return .cancel
        } else if host == consts.DEEPLINK_SCHEME_PATH_CONFIRM {
            return .confirm
        } else {
            return nil
        }
    }
}
