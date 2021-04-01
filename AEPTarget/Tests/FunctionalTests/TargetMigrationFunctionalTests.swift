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

@testable import AEPCore
@testable import AEPServices
@testable import AEPTarget
import XCTest

class TargetMigrationFunctionalTests: TargetFunctionalTests {
    // MARK: - Data Migration

    func testRegisterExtension_registersWithoutAnyErrorOrCrash() {
        XCTAssertNoThrow(MobileCore.registerExtensions([Target.self]))
    }

    func testTargetInitWithDataMigrationFromV5() {
        let userDefaultsV5 = getUserDefaults()
        cleanUserDefaults()

        let timestamp = Date().getUnixTimeInSeconds()
        userDefaultsV5.set("edge.host.com", forKey: "Adobe.ADOBEMOBILE_TARGET.EDGE_HOST")
        userDefaultsV5.set("id_1", forKey: "Adobe.ADOBEMOBILE_TARGET.TNT_ID")
        userDefaultsV5.set("id_2", forKey: "Adobe.ADOBEMOBILE_TARGET.THIRD_PARTY_ID")
        userDefaultsV5.set("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", forKey: "Adobe.ADOBEMOBILE_TARGET.SESSION_ID")
        userDefaultsV5.set(timestamp, forKey: "Adobe.ADOBEMOBILE_TARGET.SESSION_TIMESTAMP")

        let target = Target(runtime: mockRuntime)
        XCTAssertEqual("edge.host.com", target?.targetState.edgeHost)
        XCTAssertEqual("id_1", target?.targetState.tntId)
        XCTAssertEqual("id_2", target?.targetState.thirdPartyId)
        XCTAssertEqual("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", target?.targetState.sessionId)
        XCTAssertEqual(timestamp, target?.targetState.sessionTimestampInSeconds)
    }

    func testTargetInitWithDataMigrationFromV4() {
        let userDefaultsV4 = getUserDefaults()
        let targetDataStore = getTargetDataStore()
        cleanUserDefaults()

        userDefaultsV4.set("id_1", forKey: "ADBMOBILE_TARGET_TNT_ID")
        userDefaultsV4.set("id_2", forKey: "ADBMOBILE_TARGET_3RD_PARTY_ID")
        userDefaultsV4.set(true, forKey: "ADBMOBILE_TARGET_DATA_MIGRATED")
        userDefaultsV4.set("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", forKey: "ADBMOBILE_TARGET_SESSION_ID")
        userDefaultsV4.set("edge.host.com", forKey: "ADBMOBILE_TARGET_EDGE_HOST")
        userDefaultsV4.set(1_615_436_587, forKey: "ADBMOBILE_TARGET_LAST_TIMESTAMP")

        let target = Target(runtime: mockRuntime)
        XCTAssertEqual("id_1", target?.targetState.tntId)
        XCTAssertEqual("id_2", target?.targetState.thirdPartyId)
        XCTAssertEqual("edge.host.com", targetDataStore.getString(key: "edge.host"))
        XCTAssertEqual("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", targetDataStore.getString(key: "session.id"))
        XCTAssertEqual(1_615_436_587, targetDataStore.getInt(key: "session.timestamp"))
    }
}
