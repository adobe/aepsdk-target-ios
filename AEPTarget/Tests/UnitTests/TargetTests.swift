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

class TargetTests: XCTestCase {
    var target: Target!
    var mockRuntime: TestableExtensionRuntime!

    override func setUp() {
        mockRuntime = TestableExtensionRuntime()
        target = Target(runtime: mockRuntime)
        target.onRegistered()
    }

    private func cleanUserDefaults() {
        for _ in 0 ... 5 {
            for key in getUserDefaults().dictionaryRepresentation().keys {
                UserDefaults.standard.removeObject(forKey: key)
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

    private func getUserDefaults() -> UserDefaults {
        if let appGroup = ServiceProvider.shared.namedKeyValueService.getAppGroup(), !appGroup.isEmpty {
            return UserDefaults(suiteName: appGroup) ?? UserDefaults.standard
        }

        return UserDefaults.standard
    }

    // MARK: - Unit Tests

    func testRegisterExtension() {
        target.onRegistered()
        XCTAssertEqual(5, mockRuntime.listeners.count)
    }

    func testReadyForEvent() {
        let event = Event(name: "", type: "", source: "", data: nil)
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: event, data: (value: ["target.clientCode": "code_123"], status: .set))
        XCTAssertTrue(target.readyForEvent(event))
    }

    func testReadyForEvent_no_configuration() {
        XCTAssertFalse(target.readyForEvent(Event(name: "", type: "", source: "", data: nil)))
    }
}
