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
@testable import AEPTarget
import Foundation
import XCTest

class TargetV4MigratorTests: XCTestCase {
    private let appGroup = "test_app_group"

    override func setUpWithError() throws {
        if let userDefaults = UserDefaults(suiteName: appGroup) {
            for _ in 0 ... 5 {
                for key in userDefaults.dictionaryRepresentation().keys {
                    userDefaults.removeObject(forKey: key)
                }
            }
        }
        for _ in 0 ... 5 {
            for key in UserDefaults.standard.dictionaryRepresentation().keys {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        ServiceProvider.shared.namedKeyValueService.setAppGroup(nil)
    }

    private func getTargetDataStore() -> NamedCollectionDataStore {
        return NamedCollectionDataStore(name: "com.adobe.module.target")
    }

    private func getUserDefaultsV4() -> UserDefaults {
        if let v4AppGroup = ServiceProvider.shared.namedKeyValueService.getAppGroup(), !v4AppGroup.isEmpty {
            return UserDefaults(suiteName: v4AppGroup) ?? UserDefaults.standard
        }

        return UserDefaults.standard
    }

    /// No V4 data exists
    func testNoV4Data() {
        let targetDataStore = getTargetDataStore()
        XCTAssertEqual(nil, targetDataStore.getBool(key: "v4.migration.complete"))

        TargetV4Migrator.migrate()

        // verify: didn't do data migration and no data was stored with default values
        guard targetDataStore.getString(key: "edge.host") == nil,
              targetDataStore.getString(key: "tnt.id") == nil,
              targetDataStore.getString(key: "thirdparty.id") == nil,
              targetDataStore.getString(key: "session.id") == nil,
              targetDataStore.getInt(key: "session.timestamp") == nil
        else {
            XCTFail("should not do data migration if no data was stored in V4 c++ SDK")
            return
        }
    }

    /// Migrates all of the supported V4 data keys to the new data keys
    func testDataMigration() {
        let userDefaultsV4 = getUserDefaultsV4()
        let targetDataStore = getTargetDataStore()
        XCTAssertEqual(nil, targetDataStore.getBool(key: "v4.migration.complete"))

        // V4 Target data with old keys
        userDefaultsV4.set("id_1", forKey: "ADBMOBILE_TARGET_TNT_ID")
        userDefaultsV4.set("id_2", forKey: "ADBMOBILE_TARGET_3RD_PARTY_ID")
        userDefaultsV4.set("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", forKey: "ADBMOBILE_TARGET_SESSION_ID")
        userDefaultsV4.set("edge.host.com", forKey: "ADBMOBILE_TARGET_EDGE_HOST")
        userDefaultsV4.set(1_615_436_587, forKey: "ADBMOBILE_TARGET_LAST_TIMESTAMP")
        userDefaultsV4.set(true, forKey: "ADBMOBILE_TARGET_DATA_MIGRATED")

        TargetV4Migrator.migrate()

        // V4 Target data keys should be deleted
        guard userDefaultsV4.object(forKey: "ADBMOBILE_TARGET_TNT_ID") == nil,
              userDefaultsV4.object(forKey: "ADBMOBILE_TARGET_3RD_PARTY_ID") == nil,
              userDefaultsV4.object(forKey: "ADBMOBILE_TARGET_SESSION_ID") == nil,
              userDefaultsV4.object(forKey: "ADBMOBILE_TARGET_EDGE_HOST") == nil,
              userDefaultsV4.object(forKey: "ADBMOBILE_TARGET_LAST_TIMESTAMP") == nil,
              userDefaultsV4.object(forKey: "ADBMOBILE_TARGET_DATA_MIGRATED") == nil
        else {
            XCTFail("the old V4 data is not deleted")
            return
        }
        // verify: Target data with new keys
        XCTAssertEqual("id_1", targetDataStore.getString(key: "tnt.id"))
        XCTAssertEqual("id_2", targetDataStore.getString(key: "thirdparty.id"))
        XCTAssertEqual("edge.host.com", targetDataStore.getString(key: "edge.host"))
        XCTAssertEqual("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", targetDataStore.getString(key: "session.id"))
        XCTAssertEqual(1_615_436_587, targetDataStore.getInt(key: "session.timestamp"))
        XCTAssertEqual(true, targetDataStore.getBool(key: "v4.migration.complete"))
    }

    /// Migrates part of the supported V4 data keys to the new data keys
    func testDataMigrationPartial() {
        let userDefaultsV4 = getUserDefaultsV4()
        let targetDataStore = getTargetDataStore()
        XCTAssertEqual(nil, targetDataStore.getBool(key: "v4.migration.complete"))
        // V4 Target data with old keys
        userDefaultsV4.set("id_1", forKey: "ADBMOBILE_TARGET_TNT_ID")
        userDefaultsV4.set(true, forKey: "ADBMOBILE_TARGET_DATA_MIGRATED")

        TargetV4Migrator.migrate()

        // V4 Target data keys should be deleted
        guard userDefaultsV4.object(forKey: "ADBMOBILE_TARGET_TNT_ID") == nil,
              userDefaultsV4.object(forKey: "ADBMOBILE_TARGET_3RD_PARTY_ID") == nil,
              userDefaultsV4.object(forKey: "ADBMOBILE_TARGET_DATA_MIGRATED") == nil
        else {
            XCTFail("the old V4 data is not deleted")
            return
        }

        // verify: Target data with new keys

        XCTAssertEqual("id_1", targetDataStore.getString(key: "tnt.id"))
        XCTAssertEqual(nil, targetDataStore.getString(key: "thirdparty.id"))
        XCTAssertEqual(nil, targetDataStore.getString(key: "session.id"))
        XCTAssertEqual(nil, targetDataStore.getInt(key: "session.timestamp"))
        XCTAssertEqual(true, targetDataStore.getBool(key: "v4.migration.complete"))
    }

    /// Migrate V4 data if using `app group` in the SDK
    func testDataMigrationInAppGroup() {
        ServiceProvider.shared.namedKeyValueService.setAppGroup(appGroup)
        let userDefaultsV4 = getUserDefaultsV4()
        let targetDataStore = getTargetDataStore()
        XCTAssertEqual(nil, targetDataStore.getBool(key: "v4.migration.complete"))

        // V4 Target data with old keys
        userDefaultsV4.set("id_1", forKey: "ADBMOBILE_TARGET_TNT_ID")
        userDefaultsV4.set("id_2", forKey: "ADBMOBILE_TARGET_3RD_PARTY_ID")
        userDefaultsV4.set("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", forKey: "ADBMOBILE_TARGET_SESSION_ID")
        userDefaultsV4.set("edge.host.com", forKey: "ADBMOBILE_TARGET_EDGE_HOST")
        userDefaultsV4.set(1_615_436_587, forKey: "ADBMOBILE_TARGET_LAST_TIMESTAMP")
        userDefaultsV4.set(true, forKey: "ADBMOBILE_TARGET_DATA_MIGRATED")

        TargetV4Migrator.migrate()

        // V4 Target data keys should be deleted
        guard userDefaultsV4.object(forKey: "ADBMOBILE_TARGET_TNT_ID") == nil,
              userDefaultsV4.object(forKey: "ADBMOBILE_TARGET_3RD_PARTY_ID") == nil,
              userDefaultsV4.object(forKey: "ADBMOBILE_TARGET_SESSION_ID") == nil,
              userDefaultsV4.object(forKey: "ADBMOBILE_TARGET_EDGE_HOST") == nil,
              userDefaultsV4.object(forKey: "ADBMOBILE_TARGET_LAST_TIMESTAMP") == nil,
              userDefaultsV4.object(forKey: "ADBMOBILE_TARGET_DATA_MIGRATED") == nil

        else {
            XCTFail("the old V4 data is not deleted")
            return
        }
        // verify: Target data with new keys
        XCTAssertEqual("id_1", targetDataStore.getString(key: "tnt.id"))
        XCTAssertEqual("id_2", targetDataStore.getString(key: "thirdparty.id"))
        XCTAssertEqual("edge.host.com", targetDataStore.getString(key: "edge.host"))
        XCTAssertEqual("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", targetDataStore.getString(key: "session.id"))
        XCTAssertEqual(1_615_436_587, targetDataStore.getInt(key: "session.timestamp"))
        XCTAssertEqual(true, targetDataStore.getBool(key: "v4.migration.complete"))
    }

    /// Migrate V4 data if using a new `app group` in the SDK
    /// The `app group` is not stored in V4 ACPCore code, this bug is logged in Jira (AMSDK-11223)
    func testDataMigrationInNewAppGroup() {
        let targetDataStore = getTargetDataStore()
        XCTAssertEqual(nil, targetDataStore.getBool(key: "v4.migration.complete"))

        // V4 Target data with old keys
        UserDefaults.standard.set(true, forKey: "ADBMOBILE_TARGET_DATA_MIGRATED")
        UserDefaults.standard.set("id_1", forKey: "ADBMOBILE_TARGET_TNT_ID")
        UserDefaults.standard.set("id_2", forKey: "ADBMOBILE_TARGET_3RD_PARTY_ID")
        UserDefaults.standard.set("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", forKey: "ADBMOBILE_TARGET_SESSION_ID")
        UserDefaults.standard.set("edge.host.com", forKey: "ADBMOBILE_TARGET_EDGE_HOST")
        UserDefaults.standard.set(1_615_436_587, forKey: "ADBMOBILE_TARGET_LAST_TIMESTAMP")

        // set a `app group` value and do data migration
        ServiceProvider.shared.namedKeyValueService.setAppGroup("test_app_group")
        TargetV4Migrator.migrate()

        // verify: V4 Target data will no be migrated
        guard UserDefaults.standard.object(forKey: "ADBMOBILE_TARGET_DATA_MIGRATED") != nil,
              UserDefaults.standard.object(forKey: "ADBMOBILE_TARGET_TNT_ID") != nil,
              UserDefaults.standard.object(forKey: "ADBMOBILE_TARGET_SESSION_ID") != nil,
              UserDefaults.standard.object(forKey: "ADBMOBILE_TARGET_EDGE_HOST") != nil,
              UserDefaults.standard.object(forKey: "ADBMOBILE_TARGET_LAST_TIMESTAMP") != nil,
              UserDefaults.standard.object(forKey: "ADBMOBILE_TARGET_3RD_PARTY_ID") != nil
        else {
            XCTFail("the old V4 data should not be deleted")
            return
        }

        guard targetDataStore.getString(key: "edge.host") == nil,
              targetDataStore.getString(key: "tnt.id") == nil,
              targetDataStore.getString(key: "thirdparty.id") == nil,
              targetDataStore.getString(key: "session.id") == nil,
              targetDataStore.getInt(key: "session.timestamp") == nil
        else {
            XCTFail("should not do data migration if app group changed")
            return
        }
        XCTAssertEqual(true, targetDataStore.getBool(key: "v4.migration.complete"))
    }
}
