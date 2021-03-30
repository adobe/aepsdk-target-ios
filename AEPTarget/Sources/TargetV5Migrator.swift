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

import AEPServices
import Foundation

/// Provides functionality for migrating stored data from c++ V5 to Swift V5
enum TargetV5Migrator {
    private static var userDefaultsV5: UserDefaults {
        if let v5AppGroup = ServiceProvider.shared.namedKeyValueService.getAppGroup(), !v5AppGroup.isEmpty {
            return UserDefaults(suiteName: v5AppGroup) ?? UserDefaults.standard
        }
        return UserDefaults.standard
    }

    /// Migrates the c++ V5 Target values into the Swift V5 Target data store
    static func migrate() {
        let targetDataStore = NamedCollectionDataStore(name: TargetConstants.DATASTORE_NAME)

        guard targetDataStore.getString(key: TargetConstants.DataStoreKeys.THIRD_PARTY_ID) == nil,
              targetDataStore.getString(key: TargetConstants.DataStoreKeys.TNT_ID) == nil,
              targetDataStore.getString(key: TargetConstants.DataStoreKeys.SESSION_ID) == nil,
              targetDataStore.getLong(key: TargetConstants.DataStoreKeys.SESSION_TIMESTAMP) == nil,
              targetDataStore.getString(key: TargetConstants.DataStoreKeys.EDGE_HOST) == nil
        else {
            return
        }

        // save values
        targetDataStore.set(key: TargetConstants.DataStoreKeys.EDGE_HOST, value: userDefaultsV5.string(forKey: TargetConstants.V5Migration.EDGE_HOST))

        let sessionTimestamp = userDefaultsV5.integer(forKey: TargetConstants.V5Migration.SESSION_TIMESTAMP)
        if sessionTimestamp > 0 {
            targetDataStore.set(key: TargetConstants.DataStoreKeys.SESSION_TIMESTAMP, value: sessionTimestamp)
        }
        targetDataStore.set(key: TargetConstants.DataStoreKeys.SESSION_ID, value: userDefaultsV5.string(forKey: TargetConstants.V5Migration.SESSION_ID))
        targetDataStore.set(key: TargetConstants.DataStoreKeys.THIRD_PARTY_ID, value: userDefaultsV5.string(forKey: TargetConstants.V5Migration.THIRD_PARTY_ID))
        targetDataStore.set(key: TargetConstants.DataStoreKeys.TNT_ID, value: userDefaultsV5.string(forKey: TargetConstants.V5Migration.TNT_ID))

        // remove old values
        userDefaultsV5.removeObject(forKey: TargetConstants.V5Migration.EDGE_HOST)
        userDefaultsV5.removeObject(forKey: TargetConstants.V5Migration.SESSION_TIMESTAMP)
        userDefaultsV5.removeObject(forKey: TargetConstants.V5Migration.SESSION_ID)
        userDefaultsV5.removeObject(forKey: TargetConstants.V5Migration.THIRD_PARTY_ID)
        userDefaultsV5.removeObject(forKey: TargetConstants.V5Migration.TNT_ID)
    }
}
