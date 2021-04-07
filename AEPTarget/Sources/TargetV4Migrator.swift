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

/// Provides functionality for migrating stored data from V4 to Swift V5
enum TargetV4Migrator {
    static let LOG_TAG = "TargetV4Migrator"
    private static var userDefaultsV4: UserDefaults {
        if let v4AppGroup = ServiceProvider.shared.namedKeyValueService.getAppGroup(), !v4AppGroup.isEmpty {
            return UserDefaults(suiteName: v4AppGroup) ?? UserDefaults.standard
        }

        return UserDefaults.standard
    }

    /// Migrates the V4 Target values into the Swift V5 Target data store
    static func migrate() {
        let targetDataStore = NamedCollectionDataStore(name: TargetConstants.DATASTORE_NAME)

        guard targetDataStore.getString(key: TargetConstants.DataStoreKeys.THIRD_PARTY_ID) == nil,
              targetDataStore.getString(key: TargetConstants.DataStoreKeys.TNT_ID) == nil,
              targetDataStore.getString(key: TargetConstants.DataStoreKeys.SESSION_ID) == nil,
              targetDataStore.getLong(key: TargetConstants.DataStoreKeys.SESSION_TIMESTAMP) == nil,
              targetDataStore.getString(key: TargetConstants.DataStoreKeys.EDGE_HOST) == nil
        else {
            Log.trace(label: Target.LOG_TAG, "Found new Target data keys, not need to do V4 data migration.")
            return
        }

        targetDataStore.set(key: TargetConstants.DataStoreKeys.THIRD_PARTY_ID, value: userDefaultsV4.string(forKey: TargetConstants.V4Migration.THIRD_PARTY_ID))
        targetDataStore.set(key: TargetConstants.DataStoreKeys.TNT_ID, value: userDefaultsV4.string(forKey: TargetConstants.V4Migration.TNT_ID))
        targetDataStore.set(key: TargetConstants.DataStoreKeys.EDGE_HOST, value: userDefaultsV4.string(forKey: TargetConstants.V4Migration.EDGE_HOST))
        let timestamp = userDefaultsV4.integer(forKey: TargetConstants.V4Migration.LAST_TIMESTAMP)
        if timestamp > 0 {
            targetDataStore.set(key: TargetConstants.DataStoreKeys.SESSION_TIMESTAMP, value: timestamp)
        }
        targetDataStore.set(key: TargetConstants.DataStoreKeys.SESSION_ID, value: userDefaultsV4.string(forKey: TargetConstants.V4Migration.SESSION_ID))

        // remove old values
        userDefaultsV4.removeObject(forKey: TargetConstants.V4Migration.THIRD_PARTY_ID)
        userDefaultsV4.removeObject(forKey: TargetConstants.V4Migration.TNT_ID)
        userDefaultsV4.removeObject(forKey: TargetConstants.V4Migration.EDGE_HOST)
        userDefaultsV4.removeObject(forKey: TargetConstants.V4Migration.SESSION_ID)
        userDefaultsV4.removeObject(forKey: TargetConstants.V4Migration.LAST_TIMESTAMP)
        userDefaultsV4.removeObject(forKey: TargetConstants.V4Migration.V4_DATA_MIGRATED)
        Log.trace(label: Target.LOG_TAG, "Target V4 data migration completed.")
    }
}
