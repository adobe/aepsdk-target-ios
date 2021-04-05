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

class TargetClickedLocationFunctionalTests: TargetFunctionalTestsBase {
    // MARK: - Location Clicked

    func testLocationClicked() {
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
              "notifications": {
                    "id": "4BA0B2EF-9A20-4BDC-9F97-0B955BC5FF84",
              }
            }
        """

        // Build the location data
        let data: [String: Any] = [
            "name": "mbox1",
            "targetparams": TargetParameters(profileParameters: mockProfileParam).asDictionary() as Any,
            TargetConstants.EventDataKeys.IS_LOCATION_CLICKED: true,
        ]
        let locationClickedEvent = Event(name: "", type: "", source: "", data: data)
        // creates a configuration's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: locationClickedEvent, data: (value: mockConfigSharedState, status: .set))

        // creates a lifecycle's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.lifecycle", event: locationClickedEvent, data: (value: mockLifecycleData, status: .set))

        // creates an identity's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: locationClickedEvent, data: (value: mockIdentityData, status: .set))

        // target state has mock prefetch mboxes
        target.targetState.mergePrefetchedMboxJson(mboxesDictionary: mockMBoxJson)

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
                "notifications",
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

            // verifies payloadDictionary["notifications"]
            guard let notificationsArray = payloadDictionary["notifications"] as? [Any?] else {
                XCTFail()
                return nil
            }

            XCTAssertNotNil(notificationsArray)
            XCTAssertTrue(notificationsArray.capacity == 1)

            let notificationsJson = self.prettify(notificationsArray)
            XCTAssertTrue(notificationsJson.contains("\"eventToken\""))
            XCTAssertTrue(notificationsJson.contains("\"type\" : \"click\""))
            XCTAssertTrue(notificationsJson.contains("\"name\" : \"mbox1\""))
            XCTAssertTrue(notificationsJson.contains("\"a.OSVersion\""))
            XCTAssertTrue(notificationsJson.contains("\"a.DeviceName\""))
            XCTAssertTrue(notificationsJson.contains("\"a.AppID\""))
            XCTAssertTrue(notificationsJson.contains("\"a.locale\""))

            let validResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
        }

        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }

        XCTAssertTrue(target.readyForEvent(locationClickedEvent))
        // handles the location displayed event
        eventListener(locationClickedEvent)

        // Check the notifications are cleared
        XCTAssertTrue(target.targetState.notifications.isEmpty)

        // verifies the content of network response was stored correctly
        XCTAssertEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", target.targetState.tntId)
        XCTAssertEqual("mboxedge35.tt.omtrdc.net", target.targetState.edgeHost)

        // verifies the Target's shared state
        XCTAssertEqual(1, mockRuntime.createdSharedStates.count)
        XCTAssertEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", mockRuntime.createdSharedStates[0]?["tntid"] as? String)
    }

    func testLocationClicked_no_mbox() {
        MockNetworkService.request = nil
        ServiceProvider.shared.networkService = MockNetworkService()
        target.targetState.mergePrefetchedMboxJson(mboxesDictionary: mockMBoxJson)

        let data: [String: Any] = [
            "targetparams": TargetParameters(profileParameters: mockProfileParam).asDictionary() as Any,
            TargetConstants.EventDataKeys.IS_LOCATION_CLICKED: true,
        ]
        let event = Event(name: "", type: "", source: "", data: data)
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: event, data: (value: mockConfigSharedState, status: .set))
        target.onRegistered()

        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }
        eventListener(event)
        XCTAssertNil(MockNetworkService.request)
    }

    func testLocationClicked_bad_request() {
        // mocked network response
        let responseString = """
            {
              "message": "Notifications error"
            }
        """

        // Build the location data
        let data: [String: Any] = [
            "name": "mbox1",
            "targetparams": TargetParameters(profileParameters: mockProfileParam).asDictionary() as Any,
            TargetConstants.EventDataKeys.IS_LOCATION_DISPLAYED: true,
        ]
        let locationClickedEvent = Event(name: "", type: "", source: "", data: data)
        // creates a configuration's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: locationClickedEvent, data: (value: mockConfigSharedState, status: .set))

        // creates a lifecycle's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.lifecycle", event: locationClickedEvent, data: (value: mockLifecycleData, status: .set))

        // creates an identity's shared state
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: locationClickedEvent, data: (value: mockIdentityData, status: .set))

        // target state has mock prefetch mboxes
        target.targetState.mergePrefetchedMboxJson(mboxesDictionary: mockMBoxJson)

        target.onRegistered()

        // override network service
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        mockNetworkService.mock { _ in
            let validResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 400, httpVersion: nil, headerFields: nil)

            return (data: responseString.data(using: .utf8), response: validResponse, error: nil)
        }

        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail()
            return
        }

        // handles the location displayed event
        eventListener(locationClickedEvent)

        // Check the notifications are cleared
        XCTAssertTrue(target.targetState.notifications.isEmpty)

        // verifies the content of network response was stored correctly
        XCTAssertNotEqual("DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0", target.targetState.tntId)
        XCTAssertNotEqual("mboxedge35.tt.omtrdc.net", target.targetState.edgeHost)

        // verifies the Target's shared state
        XCTAssertNotEqual(1, mockRuntime.createdSharedStates.count)
    }
}
