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

class TargetFunctionalTests: XCTestCase {
    var target: Target!
    var mockRuntime: TestableExtensionRuntime!
    var mockPreviewManager = MockTargetPreviewManager()

    var mockMBox = ["mbox1", "mbox2"]
    var mockMBoxJson = ["mbox1": ["state": "state1", "options": [["eventToken": "sometoken"]], "metrics": [["type": "click", "eventToken": "eventToken"]]],
                        "mbox2": ["state": "state2", "options": [["eventToken": "sometoken2"]]]]
    var mockProfileParam = ["name": "Smith"]
    var mockConfigSharedState = ["target.clientCode": "code_123", "global.privacy": "optedin"]

    override func setUp() {
        cleanUserDefaults()
        mockRuntime = TestableExtensionRuntime()
        target = Target(runtime: mockRuntime)
        target.previewManager = mockPreviewManager
        target.onRegistered()
    }

    // MARK: - Private helper methods

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

    private func prettify(_ eventData: [String: Any]?) -> String {
        guard let eventData = eventData else {
            return ""
        }
        guard JSONSerialization.isValidJSONObject(eventData),
              let data = try? JSONSerialization.data(withJSONObject: eventData, options: .prettyPrinted),
              let prettyPrintedString = String(data: data, encoding: String.Encoding.utf8)
        else {
            return " \(eventData as AnyObject)"
        }
        return prettyPrintedString
    }

    private func payloadAsDictionary(_ payload: String?) -> [String: Any]? {
        if let payload = payload, let data = payload.data(using: .utf8),
           let dictionary = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
        {
            return dictionary
        }
        return nil
    }

    // MARK: - Functional Tests

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

        target = Target(runtime: mockRuntime)
        XCTAssertEqual(true, targetDataStore.getBool(key: "v5.migration.complete"))
        XCTAssertEqual("edge.host.com", target?.targetState.edgeHost)
        XCTAssertEqual("id_1", target?.targetState.tntId)
        XCTAssertEqual("id_2", target?.targetState.thirdPartyId)
        XCTAssertEqual("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", target?.targetState.sessionId)
        XCTAssertEqual(timestamp, target?.targetState.sessionTimestampInSeconds)
    }

    func testPrefetchContent() {
        // mocked network response
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
                    "name": "t_test_01",
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

        // builds the prefetch event
        let prefetchDataArray: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_1", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
            TargetPrefetch(name: "Drink_2", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
        ].map {
            $0.asDictionary()
        }

        let data: [String: Any] = [
            "prefetch": prefetchDataArray,
            "targetparams": TargetParameters(profileParameters: ["name": "Smith"]).asDictionary() as Any,
        ]
        let prefetchEvent = Event(name: "", type: "", source: "", data: data)

        // creates a configuration's shared state
        let configuration = [
            "target.clientCode": "code_123",
            "global.privacy": "optedin",
        ]
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: prefetchEvent, data: (value: configuration, status: .set))

        // creates a lifecycle's shared state
        let lifecycle = [
            "lifecyclecontextdata":
                [
                    "appid": "appid_1",
                    "devicename": "devicename_1",
                    "locale": "en-US",
                    "osversion": "iOS 14.4",
                    "resolution": "1125x2436",
                    "runmode": "Application",
                ] as Any,
        ]
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.lifecycle", event: prefetchEvent, data: (value: lifecycle, status: .set))

        // creates an identity's shared state
        let identity = [
            "mid": "38209274908399841237725561727471528301",
            "visitoridslist":
                [
                    [
                        "authentication_state": 0,
                        "id": "vid_id_1",
                        "id_origin": "d_cid_ic",
                        "id_type": "vid_type_1",
                    ],
                ] as Any,
        ]
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: prefetchEvent, data: (value: identity, status: .set))

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
            XCTAssertTrue(request.url.absoluteString.contains("https://code_123.tt.omtrdc.net/rest/v1/delivery/?client=code_123&sessionId="))
            XCTAssertTrue(Set(payloadDictionary.keys) == Set([
                "id",
                "experienceCloud",
                "context",
                "prefetch",
                "environmentId",
            ]))

            // verifies payloadDictionary["id"]
            guard let idDictionary = payloadDictionary["id"] as? [String: Any] else {
                XCTFail()
                return nil
            }
            XCTAssertEqual("38209274908399841237725561727471528301", idDictionary["marketingCloudVisitorId"] as? String)
            guard let vids = idDictionary["customerIds"] as? [[String: Any]] else {
                XCTFail()
                return nil
            }
            XCTAssertEqual(1, vids.count)
            XCTAssertEqual("unknown", vids[0]["authenticatedState"] as? String)
            XCTAssertEqual("vid_id_1", vids[0]["id"] as? String)
            XCTAssertEqual("vid_type_1", vids[0]["integrationCode"] as? String)

            // verifies payloadDictionary["context"]
            guard let context = payloadDictionary["context"] as? [String: Any] else {
                XCTFail()
                return nil
            }
            XCTAssertTrue(Set(context.keys) == Set([
                "userAgent",
                "mobilePlatform",
                "screen",
                "channel",
                "application",
                "timeOffsetInMinutes",
            ]))

            // verifies payloadDictionary["prefetch"]
            guard let prefetchDictionary = payloadDictionary["prefetch"] as? [String: Any] else {
                XCTFail()
                return nil
            }

            XCTAssertTrue(Set(prefetchDictionary.keys) == Set([
                "mboxes",
            ]))
            let prefetchJson = self.prettify(prefetchDictionary)
            XCTAssertTrue(prefetchJson.contains("\"name\" : \"Drink_2\""))
            XCTAssertTrue(prefetchJson.contains("\"name\" : \"Drink_1\""))
            XCTAssertTrue(prefetchJson.contains("\"mbox-parameter-key1\" : \"mbox-parameter-value1\""))
            XCTAssertTrue(prefetchJson.contains("\"a.OSVersion\""))
            XCTAssertTrue(prefetchJson.contains("\"a.DeviceName\""))
            XCTAssertTrue(prefetchJson.contains("\"a.AppID\""))
            XCTAssertTrue(prefetchJson.contains("\"a.locale\""))
            let validResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
        }
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }

        // handles the prefetch event
        eventListener(prefetchEvent)

        // verifies the content of network response was stored correctly
        XCTAssertEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", target.targetState.tntId)
        XCTAssertEqual("mboxedge35.tt.omtrdc.net", target.targetState.edgeHost)
        XCTAssertEqual(1, target.targetState.prefetchedMboxJsonDicts.count)
        let mboxJson = prettify(target.targetState.prefetchedMboxJsonDicts["t_test_01"])
        XCTAssertTrue(mboxJson.contains("\"eventToken\" : \"uR0kIAPO+tZtIPW92S0NnWqipfsIHvVzTQxHolz2IpSCnQ9Y9OaLL2gsdrWQTvE54PwSz67rmXWmSnkXpSSS2Q==\""))

        // verifies the Target's shared state
        XCTAssertEqual(1, mockRuntime.createdSharedStates.count)
        XCTAssertEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", mockRuntime.createdSharedStates[0]?["tntid"] as? String)

        // verifies the dispatched event
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)
        XCTAssertEqual("TargetPrefetchResponse", mockRuntime.dispatchedEvents[0].name)
        XCTAssertEqual("com.adobe.eventType.target", mockRuntime.dispatchedEvents[0].type)
        XCTAssertEqual("com.adobe.eventSource.responseContent", mockRuntime.dispatchedEvents[0].source)
    }

    func testPrefetchContent_in_PreviewMode() {
        // TODO: fix this after the preview PR got merged
    }

    func testPrefetchContent_empty_prefetch_array() {
        MockNetworkService.request = nil
        ServiceProvider.shared.networkService = MockNetworkService()

        let data: [String: Any] = [
            "prefetch": [String: Any](),
            "targetparams": TargetParameters(profileParameters: mockProfileParam).asDictionary() as Any,
        ]
        let prefetchEvent = Event(name: "", type: "", source: "", data: data)
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: prefetchEvent, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()

        if let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] {
            eventListener(prefetchEvent)
            XCTAssertNil(MockNetworkService.request)
            XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)
            XCTAssertEqual("TargetPrefetchResponse", mockRuntime.dispatchedEvents[0].name)
            XCTAssertEqual("com.adobe.eventType.target", mockRuntime.dispatchedEvents[0].type)
            XCTAssertEqual("com.adobe.eventSource.responseContent", mockRuntime.dispatchedEvents[0].source)
            XCTAssertNotNil(mockRuntime.dispatchedEvents[0].data?["prefetcherror"])
            return
        }
        XCTFail()
    }

    func testPrefetchContent_bad_response() {
        // mocked network response
        let responseString = """
            {
              "message": "verify_error_message"
            }
        """

        // builds the prefetch event
        let prefetchDataArray: [[String: Any]?] = [
            TargetPrefetch(name: "Drink_1", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
            TargetPrefetch(name: "Drink_2", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
        ].map {
            $0.asDictionary()
        }

        let data: [String: Any] = [
            "prefetch": prefetchDataArray,
            "targetparams": TargetParameters(profileParameters: ["name": "Smith"]).asDictionary() as Any,
        ]
        let prefetchEvent = Event(name: "", type: "", source: "", data: data)

        // creates a configuration's shared state
        let configuration = [
            "target.clientCode": "code_123",
            "global.privacy": "optedin",
        ]
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: prefetchEvent, data: (value: configuration, status: .set))

        // registers the event listeners for Target extension
        target.onRegistered()

        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { _ in
            let badResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 400, httpVersion: nil, headerFields: nil)
            return (data: responseString.data(using: .utf8), response: badResponse, error: nil)
        }
        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }

        // handles the prefetch event
        eventListener(prefetchEvent)

        // TODO: need to enable the following testing code after fixed the bug in source code
        // verifies the Target's shared state
        // XCTAssertEqual(0, mockRuntime.createdSharedStates.count)

        // verifies the dispatched event
//        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)
//        XCTAssertEqual("TargetPrefetchResponse", mockRuntime.dispatchedEvents[0].name)
//        XCTAssertEqual("com.adobe.eventType.target", mockRuntime.dispatchedEvents[0].type)
//        XCTAssertEqual("com.adobe.eventSource.responseContent", mockRuntime.dispatchedEvents[0].source)
//        guard let errorMessage = mockRuntime.dispatchedEvents[0].data?["prefetcherror"] as? String else {
//            XCTFail()
//            return
//        }
//        errorMessage.contains("verify_error_message")
//        XCTAssertEqual("com.adobe.eventSource.responseContent", errorMessage)
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

    func testHandleRestartDeeplink() {
        let testRestartDeeplink = "testUrl://test"
        let eventData = [TargetConstants.EventDataKeys.PREVIEW_RESTART_DEEP_LINK: testRestartDeeplink]
        let event = Event(name: "testRestartDeeplinkEvent", type: EventType.target, source: EventSource.requestContent, data: eventData)
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: event, data: (value: ["target.clientCode": "code_123", "global.privacy": "optedin"], status: .set))
        target.onRegistered()
        mockRuntime.simulateComingEvent(event: event)
        if let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] {
            eventListener(event)
            XCTAssertTrue(mockPreviewManager.setRestartDeepLinkCalled)
            XCTAssertEqual(mockPreviewManager.restartDeepLink, testRestartDeeplink)
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
