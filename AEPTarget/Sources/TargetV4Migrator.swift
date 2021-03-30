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
    private static var userDefaultV4: UserDefaults {
        if let v4AppGroup = ServiceProvider.shared.namedKeyValueService.getAppGroup(), !v4AppGroup.isEmpty {
            return UserDefaults(suiteName: v4AppGroup) ?? UserDefaults.standard
        }

        return UserDefaults.standard
    }

    /// Migrates the V4 Target values into the Swift V5 Target data store
    static func migrate() {
        let targetDataStore = NamedCollectionDataStore(name: TargetConstants.DATASTORE_NAME)

        guard targetDataStore.getBool(key: TargetConstants.DataStoreKeys.V4_MIGRATION_COMPLETE) == nil else {
            return
        }

        // save values
        if targetDataStore.getString(key: TargetConstants.DataStoreKeys.THIRD_PARTY_ID) == nil,
           targetDataStore.getString(key: TargetConstants.DataStoreKeys.TNT_ID) == nil,
           targetDataStore.getString(key: TargetConstants.DataStoreKeys.SESSION_ID) == nil,
           targetDataStore.getLong(key: TargetConstants.DataStoreKeys.SESSION_TIMESTAMP) == nil,
           targetDataStore.getString(key: TargetConstants.DataStoreKeys.EDGE_HOST) == nil
        {
            if let thirdPartyId = userDefaultV4.string(forKey: TargetConstants.V4Migration.THIRD_PARTY_ID) {
                targetDataStore.set(key: TargetConstants.DataStoreKeys.THIRD_PARTY_ID, value: thirdPartyId)
            }
            if let tntId = userDefaultV4.string(forKey: TargetConstants.V4Migration.TNT_ID) {
                targetDataStore.set(key: TargetConstants.DataStoreKeys.TNT_ID, value: tntId)
            }
            if let edgeHost = userDefaultV4.string(forKey: TargetConstants.V4Migration.EDGE_HOST) {
                targetDataStore.set(key: TargetConstants.DataStoreKeys.EDGE_HOST, value: edgeHost)
            }
            let timestamp = userDefaultV4.integer(forKey: TargetConstants.V4Migration.LAST_TIMESTAMP)
            if timestamp > 0 {
                targetDataStore.set(key: TargetConstants.DataStoreKeys.SESSION_TIMESTAMP, value: timestamp)
            }
            if let sessionId = userDefaultV4.string(forKey: TargetConstants.V4Migration.SESSION_ID) {
                targetDataStore.set(key: TargetConstants.DataStoreKeys.SESSION_ID, value: sessionId)
            }
        }

        // remove old values
        userDefaultV4.removeObject(forKey: TargetConstants.V4Migration.THIRD_PARTY_ID)
        userDefaultV4.removeObject(forKey: TargetConstants.V4Migration.TNT_ID)
        userDefaultV4.removeObject(forKey: TargetConstants.V4Migration.EDGE_HOST)
        userDefaultV4.removeObject(forKey: TargetConstants.V4Migration.SESSION_ID)
        userDefaultV4.removeObject(forKey: TargetConstants.V4Migration.LAST_TIMESTAMP)
        userDefaultV4.removeObject(forKey: TargetConstants.V4Migration.V4_DATA_MIGRATED)

        targetDataStore.set(key: TargetConstants.DataStoreKeys.V4_MIGRATION_COMPLETE, value: true)
    }
}
