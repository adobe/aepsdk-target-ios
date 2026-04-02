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

/// Unit tests for the timeout parameter introduced in `Target.prefetchContent(_:with:timeout:_:)`.
///
/// Each test exercises exactly one decision point of the change:
///  - Guard conditions in the new timeout overload (before MobileCore.dispatch is reached)
///  - `calculateTimeout` priority: explicit API value > `target.timeout` config > 5-second default
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

    /// Returns a prefetch `Event` with the given optional `apiTimeout` stored in its data,
    /// mirroring exactly what `Target.prefetchContent(_:with:timeout:_:)` dispatches.
    private func makePrefetchEvent(apiTimeout: TimeInterval? = nil) -> Event {
        let prefetchDataArray: [[String: Any]?] = [
            TargetPrefetch(name: "mbox1"),
        ].map { $0.asDictionary() }
        var data: [String: Any] = ["prefetch": prefetchDataArray]
        if let apiTimeout = apiTimeout {
            data[TargetConstants.EventDataKeys.API_TIMEOUT] = apiTimeout
        }
        return Event(name: TargetConstants.EventName.PREFETCH_REQUESTS,
                     type: EventType.target,
                     source: EventSource.requestContent,
                     data: data)
    }

    private func setupSharedStates(for event: Event) {
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.configuration", event: event, data: (value: mockConfigSharedState, status: .set))
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.lifecycle", event: event, data: (value: mockLifecycleData, status: .set))
        mockRuntime.simulateSharedState(extensionName: "com.adobe.module.identity", event: event, data: (value: mockIdentityData, status: .set))
        target.onRegistered()
    }

    /// Captures the first `NetworkRequest` made when the given event is processed by the extension.
    private func capturedNetworkRequest(for event: Event) -> NetworkRequest? {
        setupSharedStates(for: event)

        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService

        var capturedRequest: NetworkRequest?
        mockNetworkService.mock { request in
            capturedRequest = request
            let validResponse = HTTPURLResponse(
                url: URL(string: "https://acopprod3.tt.omtrdc.net/rest/v1/delivery")!,
                statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data: self.successResponseString.data(using: .utf8), response: validResponse, error: nil)
        }

        guard let eventListener: EventListener = mockRuntime.listeners["com.adobe.eventType.target-com.adobe.eventSource.requestContent"] else {
            XCTFail("Expected requestContent event listener to be registered")
            return nil
        }

        XCTAssertTrue(target.readyForEvent(event))
        eventListener(event)
        return capturedRequest
    }

    // MARK: - Guard condition tests (new timeout overload)

    /// The new timeout overload must return `ERROR_EMPTY_PREFETCH_LIST` immediately for an empty
    /// array — before reaching `MobileCore.dispatch`. This verifies the guard inside the new
    /// overload itself still fires correctly.
    func testPrefetchContent_WithExplicitTimeout_EmptyArray_ReturnsEmptyListError() {
        var receivedError: Error?
        Target.prefetchContent([], with: nil, timeout: 5) { receivedError = $0 }
        XCTAssertEqual(TargetError.ERROR_EMPTY_PREFETCH_LIST, receivedError.map { String(describing: $0) },
                       "Empty array should return ERROR_EMPTY_PREFETCH_LIST before MobileCore.dispatch is called")
    }

    /// The original no-timeout overload delegates to the new one; the same guard must still fire.
    func testPrefetchContent_WithoutTimeout_EmptyArray_ReturnsEmptyListError() {
        var receivedError: Error?
        Target.prefetchContent([], with: nil) { receivedError = $0 }
        XCTAssertEqual(TargetError.ERROR_EMPTY_PREFETCH_LIST, receivedError.map { String(describing: $0) },
                       "Delegation to the timeout overload must not lose the empty-array guard")
    }

    // MARK: - calculateTimeout priority tests

    /// When the event carries an explicit finite API timeout, `calculateTimeout` must use it for
    /// the network request — overriding whatever `target.timeout` is in configuration.
    func testCalculateTimeout_ExplicitApiTimeout_OverridesConfig() {
        let explicitTimeout: TimeInterval = 12
        mockConfigSharedState["target.timeout"] = 3   // config says 3 s — should be ignored

        let event = makePrefetchEvent(apiTimeout: explicitTimeout)
        let request = capturedNetworkRequest(for: event)

        XCTAssertNotNil(request, "A network request should have been made")
        XCTAssertEqual(explicitTimeout, request?.connectTimeout,
                       "Explicit API timeout should override target.timeout config for connectTimeout")
        XCTAssertEqual(explicitTimeout, request?.readTimeout,
                       "Explicit API timeout should override target.timeout config for readTimeout")
    }

    /// When the event carries `.infinity` (the sentinel emitted by the no-timeout public API),
    /// `calculateTimeout` must fall back to `target.timeout` from configuration.
    func testCalculateTimeout_InfinityApiTimeout_FallsBackToConfig() {
        let configuredTimeout = 8
        mockConfigSharedState["target.timeout"] = configuredTimeout

        let event = makePrefetchEvent(apiTimeout: .infinity)
        let request = capturedNetworkRequest(for: event)

        XCTAssertNotNil(request, "A network request should have been made")
        XCTAssertEqual(TimeInterval(configuredTimeout), request?.connectTimeout,
                       "Infinity sentinel should cause calculateTimeout to use target.timeout config")
        XCTAssertEqual(TimeInterval(configuredTimeout), request?.readTimeout,
                       "Infinity sentinel should cause calculateTimeout to use target.timeout config")
    }

    /// When the event carries no API timeout at all and `target.timeout` is absent from config,
    /// `calculateTimeout` must fall back to the SDK default of 5 seconds.
    func testCalculateTimeout_NoApiTimeout_NoConfig_UsesSdkDefault() {
        mockConfigSharedState.removeValue(forKey: "target.timeout")

        let event = makePrefetchEvent()   // no apiTimeout stored in event data
        let request = capturedNetworkRequest(for: event)

        XCTAssertNotNil(request, "A network request should have been made")
        XCTAssertEqual(5.0, request?.connectTimeout,
                       "Missing config should fall back to the 5-second SDK default")
        XCTAssertEqual(5.0, request?.readTimeout,
                       "Missing config should fall back to the 5-second SDK default")
    }
}
