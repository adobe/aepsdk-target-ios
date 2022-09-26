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
        // Put setup code here. This method is called before the invocation of each test method in the class.
        EventHub.shared.start()
        registerMockExtension(MockExtension.self)
        Target.isResponseListenerRegister = false
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        MockExtension.reset()
        EventHub.reset()
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
            [
                TargetPrefetch(name: "Drink_1", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
                TargetPrefetch(name: "Drink_2", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
            ],
            with: TargetParameters(profileParameters: ["name": "Smith"]),
            nil
        )
        wait(for: [expectation], timeout: 1)
    }

    func testPrefetchContent_with_empty_PrefetchObjectArray() throws {
        let expectation = XCTestExpectation(description: "error callback")
        expectation.assertForOverFulfill = true
        Target.prefetchContent([], with: TargetParameters(profileParameters: ["name": "Smith"])) { error in
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
            [
                TargetPrefetch(name: "Drink_1", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
                TargetPrefetch(name: "Drink_2", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
            ],
            with: TargetParameters(profileParameters: ["name": "Smith"])
        ) { error in
            guard let error = error as? TargetError else {
                return
            }
            XCTAssertEqual("unexpected error", error.description)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
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

        Target.displayedLocations(["Drink_1", "Drink_2"], targetParameters: TargetParameters(parameters: ["mbox_parameter_key": "mbox_parameter_value"], profileParameters: ["name": "Smith"]))
        wait(for: [expectation], timeout: 1)
    }

    func testLocationDisplayed_withEmptyMboxName() throws {
        let expectation = XCTestExpectation(description: "displayedLocations should not dispatch an event for empty mboxes array.")
        expectation.isInverted = true

        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestContent) { _ in

            expectation.fulfill()
        }

        Target.displayedLocations([], targetParameters: nil)
        wait(for: [expectation], timeout: 1)
    }

    func testLocationClicked_withEmptyMboxName() throws {
        let expectation = XCTestExpectation(description: "clickedLocation should not dispatch an event for empty mbox name.")
        expectation.isInverted = true

        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestContent) { _ in
            expectation.fulfill()
        }

        Target.clickedLocation("", targetParameters: nil)
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

        Target.clickedLocation("Drink_1", targetParameters: TargetParameters(parameters: ["mbox_parameter_key": "mbox_parameter_value"], profileParameters: ["name": "Smith"]))
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

    func testSetThirdPartyId_withNil() throws {
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
            XCTAssertEqual(id, "")
            expectation.fulfill()
        }

        Target.setThirdPartyId(nil)
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
        Target.getThirdPartyId { id, _ in
            XCTAssertEqual(id, "mockId")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testGetThirdPartyId_withNilResponseEventData() throws {
        let expectation = XCTestExpectation(description: "Should dispatch a GetThirdPartyId event")
        expectation.assertForOverFulfill = true
        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestIdentity) {
            event in
            MobileCore.dispatch(event: event.createResponseEvent(name: TargetConstants.EventName.IDENTITY_RESPONSE, type: EventType.target, source: EventSource.responseIdentity, data: nil))
        }
        Target.getThirdPartyId { id, error in
            XCTAssertNil(id)
            XCTAssertNotNil(error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
    
    func testSetSessionId() throws {
        let expectation = XCTestExpectation(description: "Should dispatch a Target request identity event for setting the session Id.")
        expectation.assertForOverFulfill = true
        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: "com.adobe.eventType.target", source: "com.adobe.eventSource.requestIdentity") { event in
            guard let eventData = event.data else {
                XCTFail("Event data is nil.")
                expectation.fulfill()
                return
            }
            let id = eventData["sessionid"] as? String
            XCTAssertEqual(id, "mockSessionId")
            expectation.fulfill()
        }

        Target.setSessionId("mockSessionId")
        wait(for: [expectation], timeout: 1)
    }

    func testSetSessionId_withNil() throws {
        let expectation = XCTestExpectation(description: "Should dispatch a Target request identity event for setting session Id.")
        expectation.assertForOverFulfill = true
        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: "com.adobe.eventType.target", source: "com.adobe.eventSource.requestIdentity") { event in
            guard let eventData = event.data else {
                XCTFail("Event data is nil.")
                expectation.fulfill()
                return
            }
            let id = eventData["sessionid"] as? String
            XCTAssertEqual(id, "")
            expectation.fulfill()
        }

        Target.setSessionId(nil)
        wait(for: [expectation], timeout: 1)
    }

    func testGetSessionId() throws {
        let expectation = XCTestExpectation(description: "Should dispatch a Target response identity event with a valid session Id in event data.")
        expectation.assertForOverFulfill = true
        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: "com.adobe.eventType.target", source: "com.adobe.eventSource.requestIdentity") {
            event in
            MobileCore.dispatch(event: event.createResponseEvent(name: "TargetResponseIdentity", type: "com.adobe.eventType.target", source: "com.adobe.eventSource.responseIdentity", data: ["sessionid": "mockSessionId"]))
        }
        Target.getSessionId { id, _ in
            XCTAssertEqual(id, "mockSessionId")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testGetSessionId_withNilResponseEventData() throws {
        let expectation = XCTestExpectation(description: "Should dispatch a Target response identity event with nil event data.")
        expectation.assertForOverFulfill = true
        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: "com.adobe.eventType.target", source: "com.adobe.eventSource.requestIdentity") {
            event in
            MobileCore.dispatch(event: event.createResponseEvent(name: TargetConstants.EventName.IDENTITY_RESPONSE, type: "com.adobe.eventType.target", source: "com.adobe.eventSource.responseIdentity", data: nil))
        }
        Target.getSessionId { id, error in
            XCTAssertNil(id)
            XCTAssertNotNil(error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
    
    func testSetTntId() throws {
        let expectation = XCTestExpectation(description: "Should dispatch a Target request identity event for setting the tnt Id.")
        expectation.assertForOverFulfill = true
        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: "com.adobe.eventType.target", source: "com.adobe.eventSource.requestIdentity") { event in
            guard let eventData = event.data else {
                XCTFail("Event data is nil.")
                expectation.fulfill()
                return
            }
            let id = eventData["tntid"] as? String
            XCTAssertEqual(id, "mockTntId")
            expectation.fulfill()
        }

        Target.setTntId("mockTntId")
        wait(for: [expectation], timeout: 1)
    }

    func testSetTntId_withNil() throws {
        let expectation = XCTestExpectation(description: "Should dispatch a Target request identity event for setting the tnt Id.")
        expectation.assertForOverFulfill = true
        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: "com.adobe.eventType.target", source: "com.adobe.eventSource.requestIdentity") { event in
            guard let eventData = event.data else {
                XCTFail("Event data is nil.")
                expectation.fulfill()
                return
            }
            let id = eventData["tntid"] as? String
            XCTAssertEqual(id, "")
            expectation.fulfill()
        }

        Target.setTntId(nil)
        wait(for: [expectation], timeout: 1)
    }
    
    func testGetTntId() throws {
        let expectation = XCTestExpectation(description: "Should dispatch a GetTntId event")
        expectation.assertForOverFulfill = true
        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestIdentity) {
            event in
            MobileCore.dispatch(event: event.createResponseEvent(name: TargetConstants.EventName.IDENTITY_RESPONSE, type: EventType.target, source: EventSource.responseIdentity, data: [TargetConstants.EventDataKeys.TNT_ID: "mockId"]))
        }
        Target.getTntId { id, _ in
            XCTAssertEqual(id, "mockId")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testGetTntId_withNilResponseEventData() throws {
        let expectation = XCTestExpectation(description: "Should dispatch a GetTntId event")
        expectation.assertForOverFulfill = true
        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestIdentity) {
            event in
            MobileCore.dispatch(event: event.createResponseEvent(name: TargetConstants.EventName.IDENTITY_RESPONSE, type: EventType.target, source: EventSource.responseIdentity, data: nil))
        }
        Target.getTntId { id, error in
            XCTAssertNil(id)
            XCTAssertNotNil(error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testRetrieveLocationContent_withEmptyArray() throws {
        let expectation = XCTestExpectation(description: "retrieveLocationContent should not dispatch an event for empty mboxes request array.")
        expectation.isInverted = true

        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestContent) { _ in
            expectation.fulfill()
        }
        Target.retrieveLocationContent([])
        wait(for: [expectation], timeout: 1)
    }

    func testRetrieveLocationContent_withEmptyMboxName() throws {
        let expectation = XCTestExpectation(description: "retrieveLocationContent should return default content if the given mbox name is empty.")
        let retrieveExpectation = XCTestExpectation(description: "retrieveLocationContent should not dispatch an event for empty mbox name.")
        retrieveExpectation.isInverted = true

        let request1 = TargetRequest(mboxName: "", defaultContent: "DefaultValue", targetParameters: nil, contentCallback: { content in
            XCTAssertEqual("DefaultValue", content)
            expectation.fulfill()
        })

        let request2 = TargetRequest(mboxName: "", defaultContent: "DefaultValue2", targetParameters: nil, contentWithDataCallback: { content, data in
            XCTAssertEqual("DefaultValue2", content)
            XCTAssertNil(data)
            expectation.fulfill()
        })

        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestContent) { _ in
            retrieveExpectation.fulfill()
        }

        Target.retrieveLocationContent([request1, request2])
        wait(for: [expectation, retrieveExpectation], timeout: 1)
    }

    func testRetrieveLocationContent() throws {
        let expectation = XCTestExpectation(description: "retrieveLocationContent should invoke the request callbacks for the given mboxes.")
        expectation.expectedFulfillmentCount = 2
        expectation.assertForOverFulfill = true

        // Mocks
        let tr1 = TargetRequest(mboxName: "Drink_1", defaultContent: "DefaultValue", targetParameters: nil, contentCallback: { content in
            XCTAssertEqual("someContent", content)
            expectation.fulfill()
        })
        let pairId1 = tr1.responsePairId

        let tr2 = TargetRequest(mboxName: "Drink_2", defaultContent: "DefaultValue2", targetParameters: nil, contentCallback: { content in
            XCTAssertEqual("someContent2", content)
            expectation.fulfill()
        })
        let pairId2 = tr2.responsePairId

        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestContent) { event in
            guard
                let eventData = event.data,
                let requests = TargetRequest.from(dictionaries: eventData["request"] as? [[String: Any]]),
                let parameters = TargetParameters.from(dictionary: eventData["targetparams"] as? [String: Any])
            else {
                XCTFail("Event should have a valid target retrieve location content data.")
                expectation.fulfill()
                expectation.fulfill()
                return
            }
            XCTAssertEqual(2, requests.count)
            XCTAssertEqual("Drink_1", requests[0].name)
            XCTAssertEqual("DefaultValue", requests[0].defaultContent)
            XCTAssertEqual(pairId1, requests[0].responsePairId)
            XCTAssertEqual("Drink_2", requests[1].name)
            XCTAssertEqual("DefaultValue2", requests[1].defaultContent)
            XCTAssertEqual(pairId2, requests[1].responsePairId)

            XCTAssertNotNil(parameters.profileParameters)
            XCTAssertEqual(1, parameters.profileParameters?.count)
            XCTAssertEqual("Smith", parameters.profileParameters?["name"])
            XCTAssertNotNil(parameters.parameters)
            XCTAssertEqual(1, parameters.parameters?.count)
            XCTAssertEqual("mbox_parameter_value", parameters.parameters?["mbox_parameter_key"])

            let event1 = Event(name: "TargetRequestResponse",
                               type: "com.adobe.eventType.target",
                               source: "com.adobe.eventSource.responseContent",
                               data: [
                                   "content": "someContent",
                                   "responsePairId": pairId1,
                                   "responseEventId": event.id.uuidString,
                               ])
            EventHub.shared.dispatch(event: event1)

            let event2 = Event(name: "TargetRequestResponse",
                               type: "com.adobe.eventType.target",
                               source: "com.adobe.eventSource.responseContent",
                               data: [
                                   "content": "someContent2",
                                   "responsePairId": pairId2,
                                   "responseEventId": event.id.uuidString,
                               ])
            EventHub.shared.dispatch(event: event2)
        }

        Target.retrieveLocationContent([tr1, tr2], with: TargetParameters(parameters: ["mbox_parameter_key": "mbox_parameter_value"], profileParameters: ["name": "Smith"]))

        wait(for: [expectation], timeout: 2)
    }

    func testRetrieveLocationContent_contentWithDataCallback() throws {
        let expectation = XCTestExpectation(description: "retrieveLocationContent should invoke the request callbacks for the given mboxes.")
        expectation.expectedFulfillmentCount = 2
        expectation.assertForOverFulfill = true

        // Mocks
        let tr1 = TargetRequest(mboxName: "Drink_1", defaultContent: "DefaultValue", targetParameters: nil, contentWithDataCallback: { content, data in
            XCTAssertEqual("someContent", content)
            XCTAssertNil(data)
            expectation.fulfill()
        })
        let pairId1 = tr1.responsePairId
        let tr2 = TargetRequest(mboxName: "Drink_2", defaultContent: "DefaultValue2", targetParameters: nil) { content, data in
            XCTAssertEqual("someContent2", content)
            XCTAssertNil(data)
            expectation.fulfill()
        }
        let pairId2 = tr2.responsePairId

        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestContent) { event in
            guard
                let eventData = event.data,
                let requests = TargetRequest.from(dictionaries: eventData["request"] as? [[String: Any]]),
                let parameters = TargetParameters.from(dictionary: eventData["targetparams"] as? [String: Any])
            else {
                XCTFail("Event should have a valid target retrieve location content data.")
                expectation.fulfill()
                expectation.fulfill()
                return
            }

            XCTAssertEqual(2, requests.count)
            XCTAssertEqual("Drink_1", requests[0].name)
            XCTAssertEqual("DefaultValue", requests[0].defaultContent)
            XCTAssertEqual(pairId1, requests[0].responsePairId)
            XCTAssertEqual("Drink_2", requests[1].name)
            XCTAssertEqual("DefaultValue2", requests[1].defaultContent)
            XCTAssertEqual(pairId2, requests[1].responsePairId)

            XCTAssertNotNil(parameters.profileParameters)
            XCTAssertEqual(1, parameters.profileParameters?.count)
            XCTAssertEqual("Smith", parameters.profileParameters?["name"])
            XCTAssertNotNil(parameters.parameters)
            XCTAssertEqual(1, parameters.parameters?.count)
            XCTAssertEqual("mbox_parameter_value", parameters.parameters?["mbox_parameter_key"])

            let event1 = Event(name: "TargetRequestResponse",
                               type: "com.adobe.eventType.target",
                               source: "com.adobe.eventSource.responseContent",
                               data: [
                                   "content": "someContent",
                                   "responsePairId": pairId1,
                                   "responseEventId": event.id.uuidString,
                               ])
            EventHub.shared.dispatch(event: event1)

            let event2 = Event(name: "TargetRequestResponse",
                               type: "com.adobe.eventType.target",
                               source: "com.adobe.eventSource.responseContent",
                               data: [
                                   "content": "someContent2",
                                   "responsePairId": pairId2,
                                   "responseEventId": event.id.uuidString,
                               ])
            EventHub.shared.dispatch(event: event2)
        }

        Target.retrieveLocationContent([tr1, tr2], with: TargetParameters(parameters: ["mbox_parameter_key": "mbox_parameter_value"], profileParameters: ["name": "Smith"]))

        wait(for: [expectation], timeout: 2)
    }

    func testClearPrefetchCache() {
        let expectation = XCTestExpectation(description: "Should dispatch a clearPrefetchCache event")
        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: "com.adobe.eventType.target", source: "com.adobe.eventSource.requestReset") { event in
            guard let eventData = event.data else {
                XCTFail("Event data is nil")
                expectation.fulfill()
                return
            }
            XCTAssertTrue(eventData["clearcache"] as? Bool ?? false)
            expectation.fulfill()
        }

        Target.clearPrefetchCache()
        wait(for: [expectation], timeout: 1)
    }

    func testSetPreviewRestartDeepLink() {
        let expectation = XCTestExpectation(description: "Should dispatch a setPreviewRestartDeepLink event")
        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: "com.adobe.eventType.target", source: "com.adobe.eventSource.requestContent") { event in
            guard let eventData = event.data else {
                XCTFail("Event data is nil")
                expectation.fulfill()
                return
            }

            XCTAssertEqual("com.adobe.targetpreview://?at_preview_token=123_xggdfeTGa", eventData["restartdeeplink"] as? String ?? "")
            expectation.fulfill()
        }

        Target.setPreviewRestartDeepLink(URL(string: "com.adobe.targetpreview://?at_preview_token=123_xggdfeTGa")!)
        wait(for: [expectation], timeout: 1)
    }

    func testExecuteRawRequest() throws {
        let expectation = XCTestExpectation(description: "executeRawRequest should invoke the response callback for the given mboxes array.")
        expectation.assertForOverFulfill = true

        // Mocks
        let tr1: [String: Any] = [
            "name": "Drink_1",
            "parameters": [
                "mbox_parameter_key1": "mbox_parameter_value1"
            ]
        ]

        let tr2: [String: Any] = [
            "name": "Drink_2",
            "parameters": [
                "mbox_parameter_key2": "mbox_parameter_value2"
            ]
        ]
        
        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestContent) { event in
            guard
                let eventData = event.data,
                let requests = TargetRequest.from(dictionaries: eventData["request"] as? [[String: Any]]),
                let isRawEvent = eventData["israwevent"] as? Bool
            else {
                XCTFail("Event should have a valid Target raw execute request data.")
                return
            }
            
            XCTAssertTrue(isRawEvent)
            XCTAssertEqual(2, requests.count)
            XCTAssertEqual("Drink_1", requests[0].name)
            XCTAssertEqual("", requests[0].defaultContent)
            XCTAssertEqual("", requests[0].responsePairId)
            XCTAssertEqual("Drink_2", requests[1].name)
            XCTAssertEqual("", requests[1].defaultContent)
            XCTAssertEqual("", requests[1].responsePairId)

            let parameters = TargetParameters.from(dictionary: eventData["targetparams"] as? [String: Any])
            XCTAssertNil(parameters)
            
            expectation.fulfill()
        }

        Target.executeRawRequest([tr1, tr2]) { response, err in
            // process response
        }

        wait(for: [expectation], timeout: 2)
    }
    
    func testExecuteRawRequest_withEmptyMboxesArray() throws {
        let expectation = XCTestExpectation(description: "executeRawRequest should not dispatch a target request with empty mboxes array.")
        expectation.isInverted = true

        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestContent) { _ in
            expectation.fulfill()
        }

        Target.executeRawRequest([]) { response, err in
            // process response
        }

        wait(for: [expectation], timeout: 2)
    }

    func testExecuteRawRequest_withEmptyMboxName() throws {
        let expectation = XCTestExpectation(description: "executeRawRequest should not dispatch a target request with empty mbox name in the mboxes array.")
        expectation.isInverted = true

        // Mocks
        let tr1: [String: Any] = [
            "name": "",
            "parameters": [
                "mbox_parameter_key1": "mbox_parameter_value1"
            ]
        ]

        let tr2: [String: Any] = [
            "name": "Drink_2",
            "parameters": [
                "mbox_parameter_key2": "mbox_parameter_value2"
            ]
        ]
        
        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestContent) { _ in
            expectation.fulfill()
        }

        Target.executeRawRequest([tr1, tr2]) { response, err in
            // process response
        }

        wait(for: [expectation], timeout: 2)
    }

    func testSendRawNotification() throws {
        let expectation = XCTestExpectation(description: "Should dispatch a target request content event for sending raw notification")
        expectation.assertForOverFulfill = true
        
        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestContent) { event in
            guard
                let eventData = event.data,
                let notificationData = eventData["notification"] as? [String: Any],
                let isLocationClicked = eventData["islocationclicked"] as? Bool,
                let isRawEvent = eventData["israwevent"] as? Bool
            else {
                XCTFail("Event should have a valid Target raw notification data.")
                return
            }
        
            XCTAssertTrue(isLocationClicked)
            XCTAssertTrue(isRawEvent)
            XCTAssertEqual("Drink_1", notificationData["name"] as? String)
            let tokens = notificationData["tokens"] as? [String]
            XCTAssertEqual(1, tokens?.count)
            XCTAssertEqual("LgG0+YDMHn4X5HqGJVoZ5g==", tokens?[0])
            let profileParameters = notificationData["profileParameters"] as? [String: Any]
            XCTAssertEqual("premium", profileParameters?["subscription"] as? String)
            expectation.fulfill()
        }

        let notification: [String: Any] = [
            "name": "Drink_1",
            "tokens": [
                "LgG0+YDMHn4X5HqGJVoZ5g=="
            ],
            "profileParameters": [
                "subscription": "premium"
            ]
        ]
        Target.sendRawNotification(notification)
        wait(for: [expectation], timeout: 2)
    }
    
    func testSendRawNotification_withEmptyNotificationDictionary() throws {
        let expectation = XCTestExpectation(description: "Should not dispatch a target request content event for sending raw notification")
        expectation.isInverted = true
        
        EventHub.shared.getExtensionContainer(MockExtension.self)?.eventListeners.clear()
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestContent) { _ in
            expectation.fulfill()
        }

        let notification = [String: Any]()
        Target.sendRawNotification(notification)

        wait(for: [expectation], timeout: 2)
    }
}
