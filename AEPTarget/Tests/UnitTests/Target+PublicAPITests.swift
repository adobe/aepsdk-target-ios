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
@testable import AEPTarget
import XCTest

class TargetPublicAPITests: XCTestCase {
    override func setUp() {
        MockExtension.reset()
        EventHub.shared.start()
        registerMockExtension(MockExtension.self)
    }

    private func registerMockExtension<T: Extension>(_ type: T.Type) {
        let semaphore = DispatchSemaphore(value: 0)
        EventHub.shared.registerExtension(type) { _ in
            semaphore.signal()
        }

        semaphore.wait()
    }

    func testPrefetchContent() throws {
        let expectation = XCTestExpectation(description: "prefetchContent should dispatch an event")
        expectation.assertForOverFulfill = true
        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestContent) { event in
            guard let eventData = event.data, let prefetchArray = TargetPrefetch.from(dictionaries: eventData["prefetch"] as? [[String: Any]]) else {
                XCTFail("Event data is nil")
                // expectation.fulfill()
                return
            }
            guard let parameters = TargetParameters.from(dictionary: eventData["targetparams"] as? [String: Any]) else {
                return
            }

            XCTAssertEqual(2, prefetchArray.count)
            XCTAssertTrue([prefetchArray[0].name, prefetchArray[1].name].contains("Drink_1"))
            XCTAssertTrue([prefetchArray[0].name, prefetchArray[1].name].contains("Drink_2"))
            XCTAssertEqual("Smith", parameters.profileParameters?["name"])
            expectation.fulfill()
        }

        Target.prefetchContent(
            prefetchObjectArray: [
                TargetPrefetch(name: "Drink_1", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
                TargetPrefetch(name: "Drink_2", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
            ],
            targetParameters: TargetParameters(profileParameters: ["name": "Smith"]),
            completion: nil
        )
        wait(for: [expectation], timeout: 1)
    }

    func testPrefetchContent_with_empty_PrefetchObjectArray() throws {
        let expectation = XCTestExpectation(description: "error callback")
        expectation.assertForOverFulfill = true
        Target.prefetchContent(prefetchObjectArray: [], targetParameters: TargetParameters(profileParameters: ["name": "Smith"])) { error in
            guard let error = error as? TargetError else {
                return
            }
            XCTAssertEqual("Empty or nil prefetch requests list", error.description)
            expectation.fulfill()
        }
    }

    func testPrefetchContent_with_error_response() throws {
        let expectation = XCTestExpectation(description: "prefetchContent should dispatch an event with error response")
        expectation.assertForOverFulfill = true
        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestContent) { event in
            EventHub.shared.dispatch(event: event.createResponseEvent(name: "", type: "", source: "", data: ["prefetcherror": "unexpected error"]))
        }
        Target.prefetchContent(
            prefetchObjectArray: [
                TargetPrefetch(name: "Drink_1", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
                TargetPrefetch(name: "Drink_2", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
            ],
            targetParameters: TargetParameters(profileParameters: ["name": "Smith"])
        ) { error in
            guard let error = error as? TargetError else {
                return
            }
            XCTAssertEqual("unexpected error", error.description)
            expectation.fulfill()
        }
    }

    func testLocationDisplayed() throws {
        let expectation = XCTestExpectation(description: "Should dispatch a target request content event for locations displayed")
        expectation.assertForOverFulfill = true
        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestContent) { event in
            guard let eventData = event.data, let mboxes = eventData[TargetConstants.EventDataKeys.MBOX_NAMES] as? [String] else {
                XCTFail("Event data is nil")
                expectation.fulfill()
                return
            }
            guard let parameters = TargetParameters.from(dictionary: eventData["targetparams"] as? [String: Any]) else {
                return
            }

            let isLocationDisplayed = eventData[TargetConstants.EventDataKeys.IS_LOCATION_DISPLAYED] as? Bool ?? false
            XCTAssertTrue(isLocationDisplayed)
            XCTAssertTrue(mboxes.contains("Drink_1"))
            XCTAssertTrue(mboxes.contains("Drink_2"))
            XCTAssertEqual("Smith", parameters.profileParameters?["name"])
            expectation.fulfill()
        }

        Target.displayedLocations(names: ["Drink_1", "Drink_2"], targetParameters: TargetParameters(parameters: ["mbox_parameter_key": "mbox_parameter_value"], profileParameters: ["name": "Smith"]))
        wait(for: [expectation], timeout: 1)
    }

    func testLocationClicked() throws {
        let expectation = XCTestExpectation(description: "Should dispatch a target request content event for location clicked")
        expectation.assertForOverFulfill = true
        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestContent) { event in
            guard let eventData = event.data, let mbox = eventData[TargetConstants.EventDataKeys.MBOX_NAME] as? String else {
                XCTFail("Event data is nil")
                // expectation.fulfill()
                return
            }
            guard let parameters = TargetParameters.from(dictionary: eventData["targetparams"] as? [String: Any]) else {
                return
            }

            let isLocationClicked = eventData[TargetConstants.EventDataKeys.IS_LOCATION_CLICKED] as? Bool ?? false
            XCTAssertTrue(isLocationClicked)
            XCTAssertTrue(mbox == "Drink_1")
            XCTAssertEqual("Smith", parameters.profileParameters?["name"])
            expectation.fulfill()
        }

        Target.clickedLocation(name: "Drink_1", targetParameters: TargetParameters(parameters: ["mbox_parameter_key": "mbox_parameter_value"], profileParameters: ["name": "Smith"]))
        wait(for: [expectation], timeout: 1)
    }

    func testResetExperience() throws {
        let expectation = XCTestExpectation(description: "Should dispatch a target request reset event for reset experience")
        expectation.assertForOverFulfill = true
        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestReset) { event in
            guard let eventData = event.data else {
                XCTFail("Event data is nil")
                expectation.fulfill()
                return
            }
            let isResetExperience = eventData["resetexperience"] as? Bool ?? false
            XCTAssertTrue(isResetExperience)
            expectation.fulfill()
        }

        Target.resetExperience()
        wait(for: [expectation], timeout: 1)
    }

    func testSetThirdPartyId() throws {
        let expectation = XCTestExpectation(description: "Should dispatch a target request reset identity event for setting third party id")
        expectation.assertForOverFulfill = true
        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestIdentity) { event in
            guard let eventData = event.data else {
                XCTFail("Event data is nil")
                expectation.fulfill()
                return
            }
            let id = eventData[TargetConstants.EventDataKeys.THIRD_PARTY_ID] as? String
            XCTAssertEqual(id, "mockId")
            expectation.fulfill()
        }

        Target.setThirdPartyId("mockId")
        wait(for: [expectation], timeout: 1)
    }

    func testGetThirdPartyId() throws {
        let expectation = XCTestExpectation(description: "Should dispatch a target request reset identity event for getting third Party id")
        expectation.assertForOverFulfill = true
        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestIdentity) {
            event in
            MobileCore.dispatch(event: event.createResponseEvent(name: TargetConstants.EventName.IDENTITY_RESPONSE, type: EventType.target, source: EventSource.responseIdentity, data: [TargetConstants.EventDataKeys.THIRD_PARTY_ID: "mockId"]))
        }
        Target.getThirdPartyId(completion: { id, _ in
            XCTAssertEqual(id, "mockId")
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 1)
    }

    func testGetTntId() throws {
        let expectation = XCTestExpectation(description: "Should dispatch a target request reset identity event for getting tnt id")
        expectation.assertForOverFulfill = true
        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestIdentity) {
            event in
            MobileCore.dispatch(event: event.createResponseEvent(name: TargetConstants.EventName.IDENTITY_RESPONSE, type: EventType.target, source: EventSource.responseIdentity, data: [TargetConstants.EventDataKeys.TNT_ID: "mockId"]))
        }
        Target.getTntId(completion: { id, _ in
            XCTAssertEqual(id, "mockId")
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 1)
    }

    func test_retrieveLocationContent() throws {
        let expectation1 = XCTestExpectation(description: "retrieveLocationContent should dispatch an event with someContent")
        let expectation2 = XCTestExpectation(description: "retrieveLocationContent should dispatch an event with someContent2")

        // Mocks
        let tr1 = TargetRequest(mboxName: "Drink_1", defaultContent: "DefaultValue", targetParameters: nil, contentCallback: { content in
            XCTAssertTrue(content == "someContent")
            expectation1.fulfill()
        })
        let pairId1 = tr1.responsePairId
        let tr2 = TargetRequest(mboxName: "Drink_2", defaultContent: "DefaultValue2", targetParameters: nil, contentCallback: { content in
            XCTAssertTrue(content == "someContent2")
            expectation2.fulfill()
        })
        let pairId2 = tr2.responsePairId

        expectation1.assertForOverFulfill = true
        expectation2.assertForOverFulfill = true
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestContent) { event in
            guard let eventData = event.data, let requests = TargetRequest.from(dictionaries: eventData[TargetConstants.EventDataKeys.LOAD_REQUESTS] as? [[String: Any]]), let parameters = TargetParameters.from(dictionary: eventData[TargetConstants.EventDataKeys.TARGET_PARAMETERS] as? [String: Any])
            else {
                XCTFail()
                expectation1.fulfill()
                expectation2.fulfill()
                return
            }
            XCTAssertEqual(2, requests.count)
            XCTAssertTrue([requests[0].name, requests[1].name].contains("Drink_1"))
            XCTAssertTrue([requests[0].name, requests[1].name].contains("Drink_2"))
            XCTAssertTrue([requests[0].defaultContent, requests[1].defaultContent].contains("DefaultValue"))
            XCTAssertTrue([requests[0].defaultContent, requests[1].defaultContent].contains("DefaultValue2"))
            XCTAssertNotNil(requests[0].responsePairId)
            XCTAssertNotNil(requests[1].responsePairId)
            XCTAssertEqual("Smith", parameters.profileParameters?["name"])

            EventHub.shared.dispatch(event: event.createResponseEvent(name: TargetConstants.EventName.TARGET_REQUEST_RESPONSE, type: EventType.target, source: EventSource.responseContent, data: [TargetConstants.EventDataKeys.TARGET_CONTENT: "someContent", TargetConstants.EventDataKeys.TARGET_RESPONSE_PAIR_ID: pairId1]))

            EventHub.shared.dispatch(event: event.createResponseEvent(name: TargetConstants.EventName.TARGET_REQUEST_RESPONSE, type: EventType.target, source: EventSource.responseContent, data: [TargetConstants.EventDataKeys.TARGET_CONTENT: "someContent2", TargetConstants.EventDataKeys.TARGET_RESPONSE_PAIR_ID: pairId2]))
            expectation1.fulfill()
            expectation2.fulfill()
        }

        Target.retrieveLocationContent(requests: [tr1, tr2], targetParameters: TargetParameters(parameters: ["mbox_parameter_key": "mbox_parameter_value"], profileParameters: ["name": "Smith"]))

        wait(for: [expectation1, expectation2], timeout: 1)
    }
}
