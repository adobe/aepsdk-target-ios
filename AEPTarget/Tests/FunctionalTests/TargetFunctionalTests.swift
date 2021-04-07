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
import SwiftyJSON
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

    // MARK: - Edge host

    func testUsingEdgeHostInPrefetchRequest() {
        let responseString = """
            {
              "status": 200,
              "id": {
                "tntId": "DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0",
                "marketingCloudVisitorId": "61055260263379929267175387965071996926"
              },
              "requestId": "01d4a408-6978-48f7-95c6-03f04160b257",
              "client": "acopprod3",
              "edgeHost": "mboxedge35.tt.omtrdc.net",
              "prefetch": {
                "mboxes": [
                  {
                    "index": 0,
                    "name": "Drink_1",
                    "options": [
                      {
                        "content": {
                          "key1": "value1"
                        },
                        "type": "json",
                        "eventToken": "uR0kIAPO+tZtIPW92S0NnWqipfsIHvVzTQxHolz2IpSCnQ9Y9OaLL2gsdrWQTvE54PwSz67rmXWmSnkXpSSS2Q=="
                      }
                    ]
                  }
                ]
              }
            }
        """

        let prefetchDataArray: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_1"),
        ].map {
            $0.asDictionary()
        }

        let prefetchData: [String: Any] = [
            "prefetch": prefetchDataArray,
        ]
        let prefetchEvent1 = Event(name: "", type: "", source: "", data: prefetchData)
        let prefetchEvent2 = Event(name: "", type: "", source: "", data: prefetchData)

        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            // verifies network request
            XCTAssertNotNil(request)
            guard let _ = self.payloadAsDictionary(request.connectPayload) else {
                XCTFail()
                return nil
            }
            XCTAssertTrue(request.url.absoluteString.contains("https://code_123.tt.omtrdc.net/rest/v1/delivery/?client=code_123&sessionId="))
            let validResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
        }

        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }

        // creates a configuration's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: prefetchEvent1, data: (value: mockConfigSharedState, status: .set))

        // creates a lifecycle's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.lifecycle", event: prefetchEvent1, data: (value: mockLifecycleData, status: .set))

        // creates an identity's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: prefetchEvent1, data: (value: mockIdentityData, status: .set))

        // registers the event listeners for Target extension
        target.onRegistered()

        XCTAssertTrue(target.readyForEvent(prefetchEvent1))

        XCTAssertEqual(target.targetState.edgeHost, "")
        // handles the prefetch event
        eventListener(prefetchEvent1)
        XCTAssertEqual(target.targetState.edgeHost, "mboxedge35.tt.omtrdc.net")

        mockNetworkService.resolvers.removeAll()
        mockNetworkService.mock { request in
            // verifies network request
            XCTAssertNotNil(request)
            guard let _ = self.payloadAsDictionary(request.connectPayload) else {
                XCTFail()
                return nil
            }
            XCTAssertTrue(request.url.absoluteString.contains("https://mboxedge35.tt.omtrdc.net/rest/v1/delivery/?client=code_123&sessionId="))
            return nil
        }
        eventListener(prefetchEvent2)
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

    func testGetTntId_withoutCachedTntId() {
        let event = Event(name: "", type: "", source: "", data: nil)
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: event, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()
        XCTAssertNil(target.targetState.tntId)
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestIdentity"] else {
            XCTFail()
            return
        }
        eventListener(event)
        if let data = mockRuntime.dispatchedEvents[0].data {
            XCTAssertNil(data[TargetConstants.EventDataKeys.TNT_ID])
            XCTAssertEqual(mockRuntime.dispatchedEvents[0].type, EventType.target)
            XCTAssertEqual(mockRuntime.dispatchedEvents[0].name, "TargetResponseIdentity")
            XCTAssertEqual(event.id, mockRuntime.dispatchedEvents[0].responseID)
            return
        }
        XCTFail()
    }

    func testTntIdIsPresentInRequest_ifNoThirdPartyIds() {
        let responseString = """
            {
              "status": 200,
              "id": {
                "tntId": "DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0",
                "marketingCloudVisitorId": "61055260263379929267175387965071996926"
              },
              "requestId": "01d4a408-6978-48f7-95c6-03f04160b257",
              "client": "acopprod3",
              "edgeHost": "mboxedge35.tt.omtrdc.net",
              "prefetch": {
                "mboxes": [
                  {
                    "index": 0,
                    "name": "Drink_1",
                    "options": [
                      {
                        "content": {
                          "key1": "value1"
                        },
                        "type": "json",
                        "eventToken": "uR0kIAPO+tZtIPW92S0NnWqipfsIHvVzTQxHolz2IpSCnQ9Y9OaLL2gsdrWQTvE54PwSz67rmXWmSnkXpSSS2Q=="
                      }
                    ]
                  }
                ]
              }
            }
        """
        let prefetchDataArray: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_1"),
        ].map {
            $0.asDictionary()
        }

        let data: [String: Any] = [
            "prefetch": prefetchDataArray,
        ]
        let prefetchEvent = Event(name: "", type: "", source: "", data: data)
        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { _ in
            let validResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
        }
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: prefetchEvent, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()
        XCTAssertNil(target.targetState.tntId)

        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(prefetchEvent))
        // handles the prefetch event
        eventListener(prefetchEvent)

        XCTAssertEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", target.targetState.tntId)
        XCTAssertNil(target.targetState.thirdPartyId)
        mockNetworkService.resolvers.removeAll()
        mockNetworkService.mock { request in
            XCTAssertNotNil(request)
            let requestJson = JSON(parseJSON: request.connectPayload)
            XCTAssertEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", requestJson["id"]["tntId"].stringValue)
            XCTAssertFalse(requestJson["id"]["thirdPartyId"].exists())
            XCTAssertFalse(requestJson["id"]["customerIds"].exists())
            let validResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
        }
        let prefetchEvent2 = Event(name: "", type: "", source: "", data: data)
        eventListener(prefetchEvent2)
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

    // MARK: - Session testing

    func testIfSessionTimeOut_useNewSessionIdAndDefaultEdgeHostInTargetReqeust() {
        cleanUserDefaults()
        getUserDefaults().setValue(1_617_825_969, forKey: "Adobe.com.adobe.module.target.session.timestamp")
        getUserDefaults().setValue("mboxedge35.tt.omtrdc.net", forKey: "Adobe.com.adobe.module.target.edge.host")
        mockRuntime = TestableExtensionRuntime()
        target = Target(runtime: mockRuntime)
        target.onRegistered()
        let storedSessionId = target.targetState.storedSessionId
        XCTAssertFalse(storedSessionId.isEmpty)
        XCTAssertEqual("mboxedge35.tt.omtrdc.net", target.targetState.storedEdgeHost)
        let prefetchDataArray: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_1"),
        ].map {
            $0.asDictionary()
        }

        let data: [String: Any] = [
            "prefetch": prefetchDataArray,
        ]
        let prefetchEvent = Event(name: "", type: "", source: "", data: data)
        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            XCTAssertNotNil(request)
            let queryMap = self.getQueryMap(url: request.url.absoluteString)
            XCTAssertNotEqual(queryMap["sessionId"] ?? "", storedSessionId)
            XCTAssertFalse(request.url.absoluteString.contains("mboxedge35.tt.omtrdc.net"))
            return nil
        }
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: prefetchEvent, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()
        XCTAssertNil(target.targetState.tntId)

        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(prefetchEvent))
        // handles the prefetch event
        eventListener(prefetchEvent)
    }

    func testIfNotSessionTimeOut_useSameSessionIdAndNewEdgeHostInTargetReqeust() {
        cleanUserDefaults()
        getUserDefaults().setValue(Date().getUnixTimeInSeconds(), forKey: "Adobe.com.adobe.module.target.session.timestamp")
        mockRuntime = TestableExtensionRuntime()
        target = Target(runtime: mockRuntime)
        target.onRegistered()
        let storedSessionId = target.targetState.storedSessionId
        XCTAssertFalse(storedSessionId.isEmpty)

        let responseString = """
            {
              "status": 200,
              "id": {
                "tntId": "DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0",
                "marketingCloudVisitorId": "61055260263379929267175387965071996926"
              },
              "requestId": "01d4a408-6978-48f7-95c6-03f04160b257",
              "client": "acopprod3",
              "edgeHost": "mboxedge35.tt.omtrdc.net",
              "prefetch": {
                "mboxes": [
                  {
                    "index": 0,
                    "name": "Drink_1",
                    "options": [
                      {
                        "content": {
                          "key1": "value1"
                        },
                        "type": "json",
                        "eventToken": "uR0kIAPO+tZtIPW92S0NnWqipfsIHvVzTQxHolz2IpSCnQ9Y9OaLL2gsdrWQTvE54PwSz67rmXWmSnkXpSSS2Q=="
                      }
                    ]
                  }
                ]
              }
            }
        """

        let prefetchDataArray: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_1"),
        ].map {
            $0.asDictionary()
        }

        let prefetchData: [String: Any] = [
            "prefetch": prefetchDataArray,
        ]
        let prefetchEvent1 = Event(name: "", type: "", source: "", data: prefetchData)
        let prefetchEvent2 = Event(name: "", type: "", source: "", data: prefetchData)

        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { request in
            // verifies network request
            XCTAssertNotNil(request)
            let queryMap = self.getQueryMap(url: request.url.absoluteString)
            XCTAssertEqual(queryMap["sessionId"] ?? "", storedSessionId)
            XCTAssertTrue(request.url.absoluteString.contains("https://code_123.tt.omtrdc.net/rest/v1/delivery/?client=code_123&sessionId="))
            let validResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
        }

        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }

        // creates a configuration's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: prefetchEvent1, data: (value: mockConfigSharedState, status: .set))

        // creates a lifecycle's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.lifecycle", event: prefetchEvent1, data: (value: mockLifecycleData, status: .set))

        // creates an identity's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: prefetchEvent1, data: (value: mockIdentityData, status: .set))

        // registers the event listeners for Target extension
        target.onRegistered()

        XCTAssertTrue(target.readyForEvent(prefetchEvent1))

        XCTAssertEqual(target.targetState.edgeHost, "")
        // handles the prefetch event
        eventListener(prefetchEvent1)
        XCTAssertEqual(target.targetState.edgeHost, "mboxedge35.tt.omtrdc.net")

        mockNetworkService.resolvers.removeAll()
        mockNetworkService.mock { request in
            // verifies network request
            XCTAssertNotNil(request)
            let queryMap = self.getQueryMap(url: request.url.absoluteString)
            XCTAssertEqual(queryMap["sessionId"] ?? "", storedSessionId)
            XCTAssertTrue(request.url.absoluteString.contains("https://mboxedge35.tt.omtrdc.net/rest/v1/delivery/?client=code_123&sessionId="))
            return nil
        }
        eventListener(prefetchEvent2)
    }

    func testSessionTimestampIsNotUpdatedWhenSendingRequestFails() {
        cleanUserDefaults()
        let sessionTimestamp = Date().getUnixTimeInSeconds()
        getUserDefaults().setValue(sessionTimestamp, forKey: "Adobe.com.adobe.module.target.session.timestamp")
        mockRuntime = TestableExtensionRuntime()
        target = Target(runtime: mockRuntime)
        target.onRegistered()
        XCTAssertEqual(sessionTimestamp, target.targetState.sessionTimestampInSeconds)
        let responseString = """
            {
              "message": "verify_error_message"
            }
        """
        let prefetchDataArray: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_1"),
        ].map {
            $0.asDictionary()
        }

        let data: [String: Any] = [
            "prefetch": prefetchDataArray,
        ]
        let prefetchEvent = Event(name: "", type: "", source: "", data: data)
        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { _ in
            let badResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 400, httpVersion: nil, headerFields: nil)
            return (data: responseString.data(using: .utf8), response: badResponse, error: nil)
        }
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: prefetchEvent, data: (value: mockConfigSharedState, status: .set))

        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        XCTAssertTrue(target.readyForEvent(prefetchEvent))
        // handles the prefetch event
        eventListener(prefetchEvent)
        XCTAssertEqual(sessionTimestamp, target.targetState.sessionTimestampInSeconds)
    }
}
