/*
 Copyright 2024 Adobe. All rights reserved.
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

/// Tests that the `target.timeout` configuration value is correctly forwarded to the
/// `NetworkRequest` used in `Target.prefetchContent`.
class TargetPrefetchTimeoutTests: TargetFunctionalTestsBase {

    // MARK: - Helpers

    private let successResponseString = """
        {
          "status": 200,
          "id": {
            "tntId": "AA-11-22-33.35_0",
            "marketingCloudVisitorId": "61055260263379929267175387965071996926"
          },
          "requestId": "aabbccdd-1234-5678-abcd-000000000001",
          "client": "acopprod3",
          "edgeHost": "mboxedge35.tt.omtrdc.net",
          "prefetch": {
            "mboxes": [
              {
                "index": 0,
                "name": "mbox1",
                "options": [
                  {
                    "content": { "key": "value" },
                    "type": "json",
                    "eventToken": "someEventToken=="
                  }
                ]
              }
            ]
          }
        }
    """

    private func makePrefetchEvent() -> Event {
        let prefetchDataArray: [[String: Any]?] = [
            TargetPrefetch(name: "mbox1"),
        ].map { $0.asDictionary() }
        let data: [String: Any] = ["prefetch": prefetchDataArray]
        return Event(name: "", type: "", source: "", data: data)
    }

    private func setupSharedStates(for event: Event) {
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: event, data: (value: mockConfigSharedState, status: .set))
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.lifecycle", event: event, data: (value: mockLifecycleData, status: .set))
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: event, data: (value: mockIdentityData, status: .set))
        target.onRegistered()
    }

    // MARK: - Public API timeout parameter tests

    /// Calling the new timeout overload with an empty prefetch array must return
    /// ERROR_EMPTY_PREFETCH_LIST synchronously — before MobileCore.dispatch is reached.
    func testPrefetchContent_WithTimeout_EmptyArray_ReturnsEmptyListError() {
        var receivedError: Error?
        Target.prefetchContent([], with: nil, timeout: 5) { receivedError = $0 }
        XCTAssertEqual(TargetError.ERROR_EMPTY_PREFETCH_LIST, receivedError.map { String(describing: $0) })
    }

    /// Calling the original no-timeout overload with an empty array must also return
    /// ERROR_EMPTY_PREFETCH_LIST — verifying the delegation to the new overload didn't
    /// break the guard.
    func testPrefetchContent_WithoutTimeout_EmptyArray_ReturnsEmptyListError() {
        var receivedError: Error?
        Target.prefetchContent([], with: nil) { receivedError = $0 }
        XCTAssertEqual(TargetError.ERROR_EMPTY_PREFETCH_LIST, receivedError.map { String(describing: $0) })
    }

    // MARK: - Network timeout value tests

    /// When `target.timeout` is set in configuration, the network request must use that value
    /// for both `connectTimeout` and `readTimeout`.
    func testPrefetchContent_NetworkRequestUsesConfiguredTimeout() {
        let configuredTimeoutSeconds = 10
        mockConfigSharedState["target.timeout"] = configuredTimeoutSeconds

        let prefetchEvent = makePrefetchEvent()
        setupSharedStates(for: prefetchEvent)

        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService

        var capturedRequest: NetworkRequest?
        mockNetworkService.mock { request in
            capturedRequest = request
            let validResponse = HTTPURLResponse(url: URL(string: "https://acopprod3.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data: self.successResponseString.data(using: .utf8), response: validResponse, error: nil)
        }

        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail("Expected requestContent event listener to be registered")
            return
        }

        XCTAssertTrue(target.readyForEvent(prefetchEvent))
        eventListener(prefetchEvent)

        XCTAssertNotNil(capturedRequest, "Network request should have been made")
        XCTAssertEqual(TimeInterval(configuredTimeoutSeconds), capturedRequest?.connectTimeout,
                       "connectTimeout should match target.timeout configuration value")
        XCTAssertEqual(TimeInterval(configuredTimeoutSeconds), capturedRequest?.readTimeout,
                       "readTimeout should match target.timeout configuration value")
    }

    /// When `target.timeout` is absent from configuration, the network request must fall back
    /// to `TargetConstants.NetworkConnection.DEFAULT_CONNECTION_TIMEOUT_SEC` (5 seconds).
    func testPrefetchContent_NetworkRequestUsesDefaultTimeout_WhenNotConfigured() {
        // Explicitly remove target.timeout to simulate it being absent
        mockConfigSharedState.removeValue(forKey: "target.timeout")

        let prefetchEvent = makePrefetchEvent()
        setupSharedStates(for: prefetchEvent)

        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService

        var capturedRequest: NetworkRequest?
        mockNetworkService.mock { request in
            capturedRequest = request
            let validResponse = HTTPURLResponse(url: URL(string: "https://acopprod3.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data: self.successResponseString.data(using: .utf8), response: validResponse, error: nil)
        }

        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail("Expected requestContent event listener to be registered")
            return
        }

        XCTAssertTrue(target.readyForEvent(prefetchEvent))
        eventListener(prefetchEvent)

        XCTAssertNotNil(capturedRequest, "Network request should have been made")
        XCTAssertEqual(5.0, capturedRequest?.connectTimeout,
                       "connectTimeout should be the 5-second default when target.timeout is not configured")
        XCTAssertEqual(5.0, capturedRequest?.readTimeout,
                       "readTimeout should be the 5-second default when target.timeout is not configured")
    }

}
