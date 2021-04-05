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

class TargetThirdPartyIdFunctionalTests: TargetFunctionalTestsBase {
    func testSetThirdPartyId() {
        let data: [String: Any] = [
            TargetConstants.EventDataKeys.THIRD_PARTY_ID: "mockId",
        ]

        let setThirdPartyIdEvent = Event(name: "", type: "", source: "", data: data)
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: setThirdPartyIdEvent, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestIdentity"] else {
            XCTFail()
            return
        }
        eventListener(setThirdPartyIdEvent)
        XCTAssertNotNil(target.targetState.thirdPartyId)
        XCTAssertEqual(target.targetState.thirdPartyId, "mockId")

        let requestDataArray: [[String: Any]?] = [
            TargetRequest(mboxName: "t_test_01", defaultContent: "default", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
        ].map {
            $0.asDictionary()
        }

        let loadRequestData: [String: Any] = [
            "request": requestDataArray,
            "targetparams": TargetParameters(profileParameters: mockProfileParam).asDictionary() as Any,
        ]
        let loadRequestEvent = Event(name: "", type: "", source: "", data: loadRequestData)

        // creates a configuration's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: loadRequestEvent, data: (value: mockConfigSharedState, status: .set))

        // creates a lifecycle's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.lifecycle", event: loadRequestEvent, data: (value: mockLifecycleData, status: .set))

        // creates an identity's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: loadRequestEvent, data: (value: mockIdentityData, status: .set))

        // registers the event listeners for Target extension
        target.onRegistered()

        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            // verifies network request
            XCTAssertNotNil(request)
            guard let payloadDictionary = self.payloadAsDictionary(request.connectPayload) else {
                XCTFail()
                return nil
            }
            let payloadJson = self.prettify(payloadDictionary)
            XCTAssertTrue(payloadJson.contains("\"thirdPartyId\" : \"mockId\""))
            return nil
        }
        guard let targetRequestListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(loadRequestEvent))
        // handles the prefetch event
        targetRequestListener(loadRequestEvent)
    }

    func testNotSetThirdPartyId() {
        XCTAssertNil(target.targetState.thirdPartyId)

        let requestDataArray: [[String: Any]?] = [
            TargetRequest(mboxName: "t_test_01", defaultContent: "default", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
        ].map {
            $0.asDictionary()
        }

        let loadRequestData: [String: Any] = [
            "request": requestDataArray,
            "targetparams": TargetParameters(profileParameters: mockProfileParam).asDictionary() as Any,
        ]
        let loadRequestEvent = Event(name: "", type: "", source: "", data: loadRequestData)

        // creates a configuration's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: loadRequestEvent, data: (value: mockConfigSharedState, status: .set))

        // creates a lifecycle's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.lifecycle", event: loadRequestEvent, data: (value: mockLifecycleData, status: .set))

        // creates an identity's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: loadRequestEvent, data: (value: mockIdentityData, status: .set))

        // registers the event listeners for Target extension
        target.onRegistered()

        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            // verifies network request
            XCTAssertNotNil(request)
            guard let payloadDictionary = self.payloadAsDictionary(request.connectPayload) else {
                XCTFail()
                return nil
            }
            let payloadJson = self.prettify(payloadDictionary)
            XCTAssertFalse(payloadJson.contains("\"thirdPartyId\" : \"mockId\""))
            return nil
        }
        guard let targetRequestListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(loadRequestEvent))
        // handles the prefetch event
        targetRequestListener(loadRequestEvent)
    }

    func testSetThirdPartyId_privacyOptOut() {
        let data: [String: Any] = [
            TargetConstants.EventDataKeys.THIRD_PARTY_ID: "mockId",
        ]

        let event = Event(name: "", type: "", source: "", data: data)
        mockConfigSharedState["global.privacy"] = "optedout"
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: event, data: (value: mockConfigSharedState, status: .set))
        target.targetState.updateConfigurationSharedState(mockConfigSharedState)
        target.onRegistered()
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestIdentity"] else {
            XCTFail()
            return
        }
        eventListener(event)
        XCTAssertNil(target.targetState.thirdPartyId)
        XCTAssertNotEqual(target.targetState.thirdPartyId, "mockId")
    }

    func testGetThirdPartyId() {
        let event = Event(name: "", type: "", source: "", data: nil)
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: event, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()
        target.targetState.updateThirdPartyId("mockId")
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestIdentity"] else {
            XCTFail()
            return
        }
        eventListener(event)
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)
        if let data = mockRuntime.dispatchedEvents[0].data, let id = data[TargetConstants.EventDataKeys.THIRD_PARTY_ID] as? String {
            XCTAssertEqual(mockRuntime.dispatchedEvents[0].type, EventType.target)
            XCTAssertEqual(id, "mockId")
            XCTAssertEqual(mockRuntime.dispatchedEvents[0].name, "TargetResponseIdentity")
            XCTAssertEqual(event.id, mockRuntime.dispatchedEvents[0].responseID)
            return
        }
        XCTFail()
    }

    func testGetThirdPartyId_withNilId() {
        XCTAssertNil(target.targetState.thirdPartyId)

        let requestIdentityEvent = Event(name: "", type: "", source: "", data: nil)
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: requestIdentityEvent, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestIdentity"] else {
            XCTFail()
            return
        }
        eventListener(requestIdentityEvent)
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)
        if let data = mockRuntime.dispatchedEvents[0].data {
            XCTAssertNil(data[TargetConstants.EventDataKeys.THIRD_PARTY_ID])
            return
        } else {
            XCTFail()
        }
    }
}
