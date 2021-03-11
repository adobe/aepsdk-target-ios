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

class TargetV5MigratorTests: XCTestCase {
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

    private func getUserDefaultV5() -> UserDefaults {
        if let v5AppGroup = ServiceProvider.shared.namedKeyValueService.getAppGroup(), !v5AppGroup.isEmpty {
            return UserDefaults(suiteName: v5AppGroup) ?? UserDefaults.standard
        }

        return UserDefaults.standard
    }

    func testDataMigration() {
        let userDefaultsV5 = getUserDefaultV5()
        let targetDataStore = getTargetDataStore()
        XCTAssertEqual(nil, targetDataStore.getBool(key: "v5.migration.complete"))

        userDefaultsV5.set("edge.host.com", forKey: "Adobe.ADOBEMOBILE_TARGET.EDGE_HOST")
        userDefaultsV5.set("id_1", forKey: "Adobe.ADOBEMOBILE_TARGET.TNT_ID")
        userDefaultsV5.set("id_2", forKey: "Adobe.ADOBEMOBILE_TARGET.THIRD_PARTY_ID")
        userDefaultsV5.set("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", forKey: "Adobe.ADOBEMOBILE_TARGET.SESSION_ID")
        userDefaultsV5.set(1_615_436_587, forKey: "Adobe.ADOBEMOBILE_TARGET.SESSION_TIMESTAMP")
        TargetV5Migrator.migrate()

        guard userDefaultsV5.object(forKey: "Adobe.ADOBEMOBILE_TARGET.EDGE_HOST") == nil,
              userDefaultsV5.object(forKey: "Adobe.ADOBEMOBILE_TARGET.TNT_ID") == nil,
              userDefaultsV5.object(forKey: "Adobe.ADOBEMOBILE_TARGET.THIRD_PARTY_ID") == nil,
              userDefaultsV5.object(forKey: "Adobe.ADOBEMOBILE_TARGET.SESSION_ID") == nil,
              userDefaultsV5.object(forKey: "Adobe.ADOBEMOBILE_TARGET.SESSION_TIMESTAMP") == nil
        else {
            XCTFail()
            return
        }
        XCTAssertEqual("edge.host.com", targetDataStore.getString(key: "edge.host"))
        XCTAssertEqual("id_1", targetDataStore.getString(key: "tnt.id"))
        XCTAssertEqual("id_2", targetDataStore.getString(key: "third.party.id"))
        XCTAssertEqual("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", targetDataStore.getString(key: "session.id"))
        XCTAssertEqual(1_615_436_587, targetDataStore.getDouble(key: "session.timestamp"))
        XCTAssertEqual(true, targetDataStore.getBool(key: "v5.migration.complete"))
    }

    func testDataMigrationPartial() {
        let userDefaultsV5 = getUserDefaultV5()
        let targetDataStore = getTargetDataStore()
        XCTAssertEqual(nil, targetDataStore.getBool(key: "v5.migration.complete"))

        userDefaultsV5.set("edge.host.com", forKey: "Adobe.ADOBEMOBILE_TARGET.EDGE_HOST")
        userDefaultsV5.set("id_1", forKey: "Adobe.ADOBEMOBILE_TARGET.TNT_ID")
        userDefaultsV5.set("id_2", forKey: "Adobe.ADOBEMOBILE_TARGET.THIRD_PARTY_ID")

        TargetV5Migrator.migrate()

        guard userDefaultsV5.object(forKey: "Adobe.ADOBEMOBILE_TARGET.EDGE_HOST") == nil,
              userDefaultsV5.object(forKey: "Adobe.ADOBEMOBILE_TARGET.TNT_ID") == nil,
              userDefaultsV5.object(forKey: "Adobe.ADOBEMOBILE_TARGET.THIRD_PARTY_ID") == nil,
              userDefaultsV5.object(forKey: "Adobe.ADOBEMOBILE_TARGET.SESSION_ID") == nil,
              userDefaultsV5.object(forKey: "Adobe.ADOBEMOBILE_TARGET.SESSION_TIMESTAMP") == nil
        else {
            XCTFail()
            return
        }
        XCTAssertEqual("edge.host.com", targetDataStore.getString(key: "edge.host"))
        XCTAssertEqual("id_1", targetDataStore.getString(key: "tnt.id"))
        XCTAssertEqual("id_2", targetDataStore.getString(key: "third.party.id"))
        XCTAssertEqual(nil, targetDataStore.getString(key: "session.id"))
        XCTAssertEqual(nil, targetDataStore.getDouble(key: "session.timestamp"))
        XCTAssertEqual(true, targetDataStore.getBool(key: "v5.migration.complete"))
    }

    func testDataMigrationInAppGroup() {
        ServiceProvider.shared.namedKeyValueService.setAppGroup(appGroup)
        let userDefaultsV5 = getUserDefaultV5()
        let targetDataStore = getTargetDataStore()
        XCTAssertEqual(nil, targetDataStore.getBool(key: "v5.migration.complete"))

        userDefaultsV5.set("edge.host.com", forKey: "Adobe.ADOBEMOBILE_TARGET.EDGE_HOST")
        userDefaultsV5.set("id_1", forKey: "Adobe.ADOBEMOBILE_TARGET.TNT_ID")
        userDefaultsV5.set("id_2", forKey: "Adobe.ADOBEMOBILE_TARGET.THIRD_PARTY_ID")
        userDefaultsV5.set("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", forKey: "Adobe.ADOBEMOBILE_TARGET.SESSION_ID")
        userDefaultsV5.set(1_615_436_587, forKey: "Adobe.ADOBEMOBILE_TARGET.SESSION_TIMESTAMP")
        TargetV5Migrator.migrate()

        guard userDefaultsV5.object(forKey: "Adobe.ADOBEMOBILE_TARGET.EDGE_HOST") == nil,
              userDefaultsV5.object(forKey: "Adobe.ADOBEMOBILE_TARGET.TNT_ID") == nil,
              userDefaultsV5.object(forKey: "Adobe.ADOBEMOBILE_TARGET.THIRD_PARTY_ID") == nil,
              userDefaultsV5.object(forKey: "Adobe.ADOBEMOBILE_TARGET.SESSION_ID") == nil,
              userDefaultsV5.object(forKey: "Adobe.ADOBEMOBILE_TARGET.SESSION_TIMESTAMP") == nil
        else {
            XCTFail()
            return
        }
        XCTAssertEqual("edge.host.com", targetDataStore.getString(key: "edge.host"))
        XCTAssertEqual("id_1", targetDataStore.getString(key: "tnt.id"))
        XCTAssertEqual("id_2", targetDataStore.getString(key: "third.party.id"))
        XCTAssertEqual("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", targetDataStore.getString(key: "session.id"))
        XCTAssertEqual(1_615_436_587, targetDataStore.getDouble(key: "session.timestamp"))
        XCTAssertEqual(true, targetDataStore.getBool(key: "v5.migration.complete"))
    }

    func testDataMigrationInNewAppGroup() {
        let targetDataStore = getTargetDataStore()
        UserDefaults.standard.set("edge.host.com", forKey: "Adobe.ADOBEMOBILE_TARGET.EDGE_HOST")
        UserDefaults.standard.set("id_1", forKey: "Adobe.ADOBEMOBILE_TARGET.TNT_ID")
        UserDefaults.standard.set("id_2", forKey: "Adobe.ADOBEMOBILE_TARGET.THIRD_PARTY_ID")
        UserDefaults.standard.set("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", forKey: "Adobe.ADOBEMOBILE_TARGET.SESSION_ID")
        UserDefaults.standard.set(1_615_436_587, forKey: "Adobe.ADOBEMOBILE_TARGET.SESSION_TIMESTAMP")

        ServiceProvider.shared.namedKeyValueService.setAppGroup("test_app_group")
        XCTAssertEqual(nil, targetDataStore.getBool(key: "v5.migration.complete"))

        TargetV5Migrator.migrate()

        guard UserDefaults.standard.object(forKey: "Adobe.ADOBEMOBILE_TARGET.EDGE_HOST") != nil,
              UserDefaults.standard.object(forKey: "Adobe.ADOBEMOBILE_TARGET.TNT_ID") != nil,
              UserDefaults.standard.object(forKey: "Adobe.ADOBEMOBILE_TARGET.THIRD_PARTY_ID") != nil,
              UserDefaults.standard.object(forKey: "Adobe.ADOBEMOBILE_TARGET.SESSION_ID") != nil,
              UserDefaults.standard.double(forKey: "Adobe.ADOBEMOBILE_TARGET.SESSION_TIMESTAMP") > 0
        else {
            XCTFail()
            return
        }

        guard targetDataStore.getString(key: "edge.host") == nil,
              targetDataStore.getString(key: "tnt.id") == nil,
              targetDataStore.getString(key: "third.party.id") == nil,
              targetDataStore.getString(key: "session.id") == nil,
              targetDataStore.getDouble(key: "session.timestamp") == nil
        else {
            XCTFail()
            return
        }
        XCTAssertEqual(true, targetDataStore.getBool(key: "v5.migration.complete"))
    }
}
