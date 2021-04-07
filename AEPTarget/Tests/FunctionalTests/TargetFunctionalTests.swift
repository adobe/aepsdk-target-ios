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

class TargetFunctionalTests: TargetFunctionalTestsBase {
    // MARK: - Functional Tests

    // MARK: - Reset Experiences

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

    // MARK: - Clear prefetch

    func testClearPrefetchExperience() {
        let data: [String: Any] = [
            TargetConstants.EventDataKeys.CLEAR_PREFETCH_CACHE: true,
        ]

        // Update state with mocks
        target.targetState.mergePrefetchedMboxJson(mboxesDictionary: ["mbox1": ["name": "mbox1"]])

        let event = Event(name: "", type: "", source: "", data: data)
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: event, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()
        if let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestReset"] {
            eventListener(event)
            XCTAssertEqual(0, target.targetState.prefetchedMboxJsonDicts.count)
            return
        }
        XCTFail()
    }

    // MARK: - Set Third Party id

    func testSetThirdPartyId() {
        let data: [String: Any] = [
            TargetConstants.EventDataKeys.THIRD_PARTY_ID: "mockId",
        ]

        let event = Event(name: "", type: "", source: "", data: data)
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: event, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestIdentity"] else {
            XCTFail()
            return
        }
        eventListener(event)
        XCTAssertNotNil(target.targetState.thirdPartyId)
        XCTAssertEqual(target.targetState.thirdPartyId, "mockId")
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

    // MARK: - Get Third Party id

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

    // MARK: - Set Tnt id

    func testGetTntId() {
        let event = Event(name: "", type: "", source: "", data: nil)
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: event, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()
        target.targetState.updateTntId("mockId")
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestIdentity"] else {
            XCTFail()
            return
        }
        eventListener(event)
        if let data = mockRuntime.dispatchedEvents[0].data, let id = data[TargetConstants.EventDataKeys.TNT_ID] as? String {
            XCTAssertEqual(mockRuntime.dispatchedEvents[0].type, EventType.target)
            XCTAssertEqual(id, "mockId")
            XCTAssertEqual(mockRuntime.dispatchedEvents[0].name, "TargetResponseIdentity")
            XCTAssertEqual(event.id, mockRuntime.dispatchedEvents[0].responseID)
            return
        }
        XCTFail()
    }

    // MARK: - Configuration response content

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
        let sessionId = target.targetState.sessionId
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.configuration-com.adobe.eventSource.responseContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(event))
        eventListener(event)
        XCTAssertNil(target.targetState.edgeHost)
        XCTAssertTrue(target.targetState.sessionTimestampInSeconds == 0)
        XCTAssertNil(target.targetState.thirdPartyId)
        XCTAssertNotEqual(sessionId, target.targetState.sessionId)
    }

    func testConfigurationResponseContent_privacyOptedIn() {
        let event = Event(name: "", type: "", source: "", data: nil)
        mockConfigSharedState["global.privacy"] = "optedin"
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: event, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()
        // Update state with mocks
        target.targetState.updateSessionTimestamp()
        target.targetState.updateEdgeHost("mockedge")
        target.targetState.updateTntId("sometnt")
        target.targetState.updateThirdPartyId("somehtirdparty")
        let sessionId = target.targetState.sessionId
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.configuration-com.adobe.eventSource.responseContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(event))
        eventListener(event)
        XCTAssertNotNil(target.targetState.edgeHost)
        XCTAssertFalse(target.targetState.sessionTimestampInSeconds == 0)
        XCTAssertNotNil(target.targetState.thirdPartyId)
        XCTAssertEqual(sessionId, target.targetState.sessionId)
    }

    // MARK: - Handle restart Deeplink

    func testHandleRestartDeeplink() {
        let testRestartDeeplink = "testUrl://test"
        let eventData = [TargetConstants.EventDataKeys.PREVIEW_RESTART_DEEP_LINK: testRestartDeeplink]
        let event = Event(name: "testRestartDeeplinkEvent", type: EventType.target, source: EventSource.requestContent, data: eventData)
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: event, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()
        mockRuntime.simulateComingEvent(event: event)

        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        eventListener(event)
        XCTAssertTrue(mockPreviewManager.setRestartDeepLinkCalled)
        XCTAssertEqual(mockPreviewManager.restartDeepLink, testRestartDeeplink)
    }
}
