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

class TargetStateTests: XCTestCase {
    func testUpdateConfigurationSharedState() {
        let targetState = TargetState()
        XCTAssertNil(targetState.storedConfigurationSharedState)
        targetState.updateConfigurationSharedState([
            "target.clientCode": "code_123",
            "global.privacy": "optedin",
        ])
        XCTAssertTrue(NSDictionary(dictionary: ["target.clientCode": "code_123", "global.privacy": "optedin"]).isEqual(to: targetState.storedConfigurationSharedState ?? [:]))
    }

    func testUpdateConfigurationSharedStateWithNewClientCode() {
        let targetState = TargetState()
        targetState.updateConfigurationSharedState([
            "target.clientCode": "code_123",
            "global.privacy": "optedin",
        ])
        targetState.updateEdgeHost("edge-host-1")
        targetState.updateSessionTimestamp()
        targetState.updateConfigurationSharedState([
            "target.clientCode": "code_456",
            "global.privacy": "optedin",
        ])
        XCTAssertTrue(NSDictionary(dictionary: ["target.clientCode": "code_456", "global.privacy": "optedin"]).isEqual(to: targetState.storedConfigurationSharedState ?? [:]))
        XCTAssertTrue(targetState.edgeHost != nil && targetState.edgeHost!.isEmpty)
    }

    func testPrivacyStatus() {
        let targetState = TargetState()
        targetState.updateConfigurationSharedState([
            "target.clientCode": "code_123",
            "global.privacy": "optedin",
        ])
        XCTAssertTrue(targetState.privacyStatusIsOptIn)
        targetState.updateConfigurationSharedState([
            "target.clientCode": "code_123",
            "global.privacy": "optedout",
        ])
        XCTAssertTrue(targetState.privacyStatusIsOptOut)
    }

    func testClientCode() {
        let targetState = TargetState()
        XCTAssertEqual(nil, targetState.clientCode)
        targetState.updateConfigurationSharedState([
            "target.clientCode": "code_123",
            "global.privacy": "optedin",
        ])
        XCTAssertEqual("code_123", targetState.clientCode)
        targetState.updateConfigurationSharedState([
            "target.clientCode": "code_456",
            "global.privacy": "optedin",
        ])
        XCTAssertEqual("code_456", targetState.clientCode)
    }

    func testEnvironmentId() {
        let targetState = TargetState()
        XCTAssertEqual(0, targetState.environmentId)
        targetState.updateConfigurationSharedState([
            "target.clientCode": "code_123",
            "global.privacy": "optedin",
            "target.environmentId": 45,
        ])
        XCTAssertEqual(45, targetState.environmentId)
    }

    func testPropertyToken() {
        let targetState = TargetState()
        XCTAssertTrue(targetState.propertyToken.isEmpty)
        targetState.updateConfigurationSharedState([
            "target.clientCode": "code_123",
            "global.privacy": "optedin",
            "target.environmentId": 45,
            "target.propertyToken": "configAtProperty",
        ])
        XCTAssertEqual("configAtProperty", targetState.propertyToken)
    }

    func testTargetServer() {
        let targetState = TargetState()
        XCTAssertNil(targetState.targetServer)
        targetState.updateConfigurationSharedState([
            "target.clientCode": "code_123",
            "global.privacy": "optedin",
            "target.environmentId": 45,
            "target.server": "myHost.here.com",
        ])
        XCTAssertEqual("myHost.here.com", targetState.targetServer)
    }

    func testNetworkTimeout() {
        let targetState = TargetState()
        XCTAssertEqual(2.0, targetState.networkTimeout)
        targetState.updateConfigurationSharedState([
            "target.clientCode": "code_123",
            "global.privacy": "optedin",
            "target.environmentId": 45,
            "target.timeout": 10,
        ])
        XCTAssertEqual(10.0, targetState.networkTimeout)
    }
}
