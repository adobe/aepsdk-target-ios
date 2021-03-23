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

    var mockMBox = ["mbox1", "mbox2"]
    var mockMBoxJson = ["mbox1": ["state": "state1", "options": [["eventToken": "sometoken"]], "metrics": [["type": "click", "eventToken": "eventToken"]]],
                        "mbox2": ["state": "state2", "options": [["eventToken": "sometoken2"]]]]
    var mockProfileParam = ["name": "Smith"]
    var mockConfigSharedState = ["target.clientCode": "code_123", "global.privacy": "optedin"]

    override func setUp() {
        mockRuntime = TestableExtensionRuntime()
        target = Target(runtime: mockRuntime)
    }

    private func cleanUserDefaults() {
        for _ in 0 ... 5 {
            for key in getUserDefaultsV5().dictionaryRepresentation().keys {
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

    private func getUserDefaultsV5() -> UserDefaults {
        if let v5AppGroup = ServiceProvider.shared.namedKeyValueService.getAppGroup(), !v5AppGroup.isEmpty {
            return UserDefaults(suiteName: v5AppGroup) ?? UserDefaults.standard
        }

        return UserDefaults.standard
    }

    func testRegisterExtension_registersWithoutAnyErrorOrCrash() {
        XCTAssertNoThrow(MobileCore.registerExtensions([Target.self]))
    }

    func testRegisterExtension() {
        target.onRegistered()
        XCTAssertEqual(5, mockRuntime.listeners.count)
    }

    func testTargetInitWithDataMigration() {
        let userDefaultsV5 = getUserDefaultsV5()
        let targetDataStore = getTargetDataStore()
        cleanUserDefaults()
        XCTAssertEqual(nil, targetDataStore.getBool(key: "v5.migration.complete"))

        let timestamp = Date().getUnixTimeInSeconds()
        userDefaultsV5.set("edge.host.com", forKey: "Adobe.ADOBEMOBILE_TARGET.EDGE_HOST")
        userDefaultsV5.set("id_1", forKey: "Adobe.ADOBEMOBILE_TARGET.TNT_ID")
        userDefaultsV5.set("id_2", forKey: "Adobe.ADOBEMOBILE_TARGET.THIRD_PARTY_ID")
        userDefaultsV5.set("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", forKey: "Adobe.ADOBEMOBILE_TARGET.SESSION_ID")
        userDefaultsV5.set(timestamp, forKey: "Adobe.ADOBEMOBILE_TARGET.SESSION_TIMESTAMP")

        let target = Target(runtime: mockRuntime)
        XCTAssertEqual(true, targetDataStore.getBool(key: "v5.migration.complete"))
        XCTAssertEqual("edge.host.com", target?.targetState.edgeHost)
        XCTAssertEqual("id_1", target?.targetState.tntId)
        XCTAssertEqual("id_2", target?.targetState.thirdPartyId)
        XCTAssertEqual("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", target?.targetState.sessionId)
        XCTAssertEqual(timestamp, target?.targetState.sessionTimestampInSeconds)
    }

    func testReadyForEvent() {
        let event = Event(name: "", type: "", source: "", data: nil)
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: event, data: (value: ["target.clientCode": "code_123"], status: .set))
        XCTAssertTrue(target.readyForEvent(event))
    }

    func testReadyForEvent_no_configuration() {
        XCTAssertFalse(target.readyForEvent(Event(name: "", type: "", source: "", data: nil)))
    }

    func testPrefetchContent() {
        MockNetworkService.request = nil
        ServiceProvider.shared.networkService = MockNetworkService()
        let prefetchDataArray: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_1", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
            TargetPrefetch(name: "Drink_2", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
        ].map {
            $0.asDictionary()
        }

        let data: [String: Any] = [
            "prefetch": prefetchDataArray,
            "targetparams": TargetParameters(profileParameters: mockProfileParam).asDictionary() as Any,
        ]
        let event = Event(name: "", type: "", source: "", data: data)
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: event, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()
        if let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] {
            eventListener(event)
            XCTAssertNotNil(MockNetworkService.request)
            if let url = MockNetworkService.request?.url.absoluteString {
                XCTAssertTrue(url.hasPrefix("https://code_123.tt.omtrdc.net/rest/v1/delivery/?client=code_123&sessionId="))
            } else {
                XCTFail()
            }
            return
        }
        XCTFail()
    }

    func testLocationDisplayed() {
        MockNetworkService.request = nil
        ServiceProvider.shared.networkService = MockNetworkService()
        target.targetState.mergePrefetchedMboxJson(mboxesDictionary: mockMBoxJson)

        let data: [String: Any] = [
            "names": mockMBox,
            "targetparams": TargetParameters(profileParameters: mockProfileParam).asDictionary() as Any,
            TargetConstants.EventDataKeys.IS_LOCATION_DISPLAYED: true,
        ]
        let event = Event(name: "", type: "", source: "", data: data)
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: event, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()
        if let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] {
            eventListener(event)
            XCTAssertNotNil(MockNetworkService.request)
            if let url = MockNetworkService.request?.url.absoluteString {
                XCTAssertTrue(url.hasPrefix("https://code_123.tt.omtrdc.net/rest/v1/delivery/?client=code_123&sessionId="))
            } else {
                XCTFail()
            }
            return
        }
        XCTFail()
    }

    func testLocationClicked() {
        MockNetworkService.request = nil
        ServiceProvider.shared.networkService = MockNetworkService()
        target.targetState.mergePrefetchedMboxJson(mboxesDictionary: mockMBoxJson)

        let data: [String: Any] = [
            "name": "mbox1",
            "targetparams": TargetParameters(profileParameters: mockProfileParam).asDictionary() as Any,
            TargetConstants.EventDataKeys.IS_LOCATION_CLICKED: true,
        ]
        let event = Event(name: "", type: "", source: "", data: data)
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: event, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()
        if let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] {
            eventListener(event)
            XCTAssertNotNil(MockNetworkService.request)
            if let url = MockNetworkService.request?.url.absoluteString {
                XCTAssertTrue(url.hasPrefix("https://code_123.tt.omtrdc.net/rest/v1/delivery/?client=code_123&sessionId="))
            } else {
                XCTFail()
            }
            return
        }
        XCTFail()
    }

    func testResetExperience() {
        let data: [String: Any] = [
            TargetConstants.EventDataKeys.RESET_EXPERIENCE: true,
        ]

        // Update state with mocks
        target.targetState.updateSessionTimestamp()
        target.targetState.updateEdgeHost("mockedge")
        target.targetState.updateTntId("sometnt")
        target.targetState.updateThirdPartyId("somehtirdparty")

        let event = Event(name: "", type: "", source: "", data: data)
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: event, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()
        if let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestReset"] {
            eventListener(event)
            XCTAssertNil(target.targetState.edgeHost)
            XCTAssertTrue(target.targetState.sessionTimestampInSeconds == 0)
            XCTAssertNil(target.targetState.thirdPartyId)
            XCTAssertNotNil(target.targetState.sessionId)
            return
        }
        XCTFail()
    }

    func testSetThirdPartyId() {
        let data: [String: Any] = [
            TargetConstants.EventDataKeys.THIRD_PARTY_ID: "mockId",
        ]

        let event = Event(name: "", type: "", source: "", data: data)
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: event, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()
        if let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestIdentity"] {
            eventListener(event)
            XCTAssertNotNil(target.targetState.thirdPartyId)
            XCTAssertEqual(target.targetState.thirdPartyId, "mockId")
            return
        }
        XCTFail()
    }

    func testGetThirdPartyId() {
        let event = Event(name: "", type: "", source: "", data: nil)
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: event, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()
        target.targetState.updateThirdPartyId("mockId")
        if let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestIdentity"] {
            eventListener(event)
            if let data = mockRuntime.dispatchedEvents[0].data, let id = data[TargetConstants.EventDataKeys.THIRD_PARTY_ID] as? String {
                XCTAssertEqual(mockRuntime.dispatchedEvents[0].type, EventType.target)
                XCTAssertEqual(id, "mockId")
                return
            }
            XCTFail()
        }
        XCTFail()
    }

    func testGetTntId() {
        let event = Event(name: "", type: "", source: "", data: nil)
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: event, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()
        target.targetState.updateTntId("mockId")
        if let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestIdentity"] {
            eventListener(event)
            if let data = mockRuntime.dispatchedEvents[0].data, let id = data[TargetConstants.EventDataKeys.TNT_ID] as? String {
                XCTAssertEqual(mockRuntime.dispatchedEvents[0].type, EventType.target)
                XCTAssertEqual(id, "mockId")
                return
            }
            XCTFail()
        }
        XCTFail()
    }

    func testConfigurationResponseContent() {
        let event = Event(name: "", type: "", source: "", data: nil)
        mockConfigSharedState["global.privacy"] = "optedout"
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: event, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()
        // Update state with mocks
        target.targetState.updateSessionTimestamp()
        target.targetState.updateEdgeHost("mockedge")
        target.targetState.updateTntId("sometnt")
        target.targetState.updateThirdPartyId("somehtirdparty")
        if let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.configuration-com.adobe.eventSource.responseContent"] {
            eventListener(event)
            XCTAssertNil(target.targetState.edgeHost)
            XCTAssertTrue(target.targetState.sessionTimestampInSeconds == 0)
            XCTAssertNil(target.targetState.thirdPartyId)
            XCTAssertNotNil(target.targetState.sessionId)
            return
        }
        XCTFail()
    }

    func testLoadRequestContent() {
        MockNetworkService.request = nil
        ServiceProvider.shared.networkService = MockNetworkService()
        let requestDataArray: [[String: Any]?] = [
            TargetRequest(mboxName: "Drink_1", defaultContent: "default", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
            TargetRequest(mboxName: "Drink_2", defaultContent: "default2", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
        ].map {
            $0.asDictionary()
        }

        let data: [String: Any] = [
            "request": requestDataArray,
            "targetparams": TargetParameters(profileParameters: mockProfileParam).asDictionary() as Any,
        ]
        let event = Event(name: "", type: "", source: "", data: data)
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: event, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()
        if let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] {
            eventListener(event)
            XCTAssertNotNil(MockNetworkService.request)
            if let url = MockNetworkService.request?.url.absoluteString {
                XCTAssertTrue(url.hasPrefix("https://code_123.tt.omtrdc.net/rest/v1/delivery/?client=code_123&sessionId="))
            } else {
                XCTFail()
            }
            return
        }
        XCTFail()
    }
}

private class MockNetworkService: Networking {
    static var request: NetworkRequest?
    func connectAsync(networkRequest request: NetworkRequest, completionHandler _: ((HttpConnection) -> Void)?) {
        MockNetworkService.request = request
    }
}
