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

extension UserDefaults {
    static func clear(appGroup: String? = nil) {
        if let appGroup = appGroup,
           !appGroup.isEmpty,
           let userDefaults = UserDefaults(suiteName: appGroup) {
                for _ in 0 ... 5 {
                    for key in userDefaults.dictionaryRepresentation().keys {
                        userDefaults.removeObject(forKey: key)
                    }
                }
        } else {
            for _ in 0 ... 5 {
                for key in UserDefaults.standard.dictionaryRepresentation().keys {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        }
    }
}
