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
import AEPIdentity
import AEPLifecycle
@testable import AEPServices
@testable import AEPTarget
import XCTest

/// A network service that accepts requests but never calls the completion handler,
/// simulating a hung/stalled network connection so the EventHub timeout fires.
private class HangingNetworkService: Networking {
    func connectAsync(networkRequest _: NetworkRequest, completionHandler _: ((HttpConnection) -> Void)?) {
        // Intentionally never calls completionHandler — simulates a hung network call.
    }
}

/// End-to-end integration tests for the `timeout` parameter on `Target.prefetchContent`.
/// These tests go through the real MobileCore / EventHub stack so the timeout parameter
/// is actually forwarded to `MobileCore.dispatch(event:timeout:responseCallback:)`.
class TargetPrefetchTimeoutIntegrationTests: XCTestCase {

    private let successResponseString = """
        {
          "status": 200,
          "id": {
            "tntId": "DE03D4AD-1FFE-421F-B2F2-303BF26822C1.35_0",
            "marketingCloudVisitorId": "61055260263379929267175387965071996926"
          },
          "requestId": "01d4a408-6978-48f7-95c6-03f04160b257",
          "client": "acopprod3",
          "prefetch": {
            "mboxes": [
              {
                "index": 0,
                "name": "mbox1",
                "options": [{ "content": { "key": "value" }, "type": "json", "eventToken": "token==" }]
              }
            ]
          }
        }
    """

    override func setUp() {
        FileManager.default.clear()
        NamedCollectionDataStore.clear()
        ServiceProvider.shared.reset()
        EventHub.reset()
    }

    override func tearDown() {
        Target.isResponseListenerRegister = false
        let unregisterExpectation = XCTestExpectation(description: "unregister")
        MobileCore.unregisterExtension(Target.self) { unregisterExpectation.fulfill() }
        wait(for: [unregisterExpectation], timeout: 2)
    }

    // MARK: - Helpers

    private func initSDK(completion: @escaping () -> Void) {
        MobileCore.registerExtensions([Target.self, Identity.self, Lifecycle.self]) {
            completion()
        }
    }

    private func setValidConfiguration() {
        MobileCore.updateConfigurationWith(configDict: [
            "experienceCloud.org": "orgid",
            "experienceCloud.server": "test.com",
            "global.privacy": "optedin",
            "target.server": "amsdk.tt.omtrdc.net",
            "target.clientCode": "acopprod3",
        ])
    }

    // MARK: - Tests

    /// Case 1: Network responds immediately within timeout → completion called with nil error.
    func testPrefetchContent_WithCustomTimeout_CallsCompletionWithNoError_WhenResponseArrivesInTime() {
        let initExpectation = XCTestExpectation(description: "init")
        initSDK { initExpectation.fulfill() }
        wait(for: [initExpectation], timeout: 2)
        setValidConfiguration()

        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        let validResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        mockNetworkService.mock { _ in
            return (data: self.successResponseString.data(using: .utf8), response: validResponse, error: nil)
        }

        let completionExpectation = XCTestExpectation(description: "completion called")
        Target.prefetchContent(
            [TargetPrefetch(name: "mbox1")],
            with: nil,
            timeout: 5
        ) { error in
            XCTAssertNil(error, "Expected no error when network responds within timeout, got: \(error?.localizedDescription ?? "")")
            completionExpectation.fulfill()
        }
        wait(for: [completionExpectation], timeout: 6)
    }

    /// Case 2: Network never responds and timeout expires → completion called with ERROR_TIMEOUT.
    func testPrefetchContent_WithCustomTimeout_CallsCompletionWithTimeoutError_WhenNetworkDoesNotRespond() {
        let initExpectation = XCTestExpectation(description: "init")
        initSDK { initExpectation.fulfill() }
        wait(for: [initExpectation], timeout: 2)
        setValidConfiguration()

        // HangingNetworkService never calls the completion handler — simulates a stalled network.
        ServiceProvider.shared.networkService = HangingNetworkService()

        let completionExpectation = XCTestExpectation(description: "completion called with timeout error")
        // Use a short timeout so the test runs fast.
        Target.prefetchContent(
            [TargetPrefetch(name: "mbox1")],
            with: nil,
            timeout: 1
        ) { error in
            XCTAssertNotNil(error, "Expected a timeout error when network does not respond")
            XCTAssertEqual(error.map { String(describing: $0) }, TargetError.ERROR_TIMEOUT,
                           "Expected ERROR_TIMEOUT, got: \(error.map { String(describing: $0) } ?? "nil")")
            completionExpectation.fulfill()
        }
        // Allow a little extra headroom beyond the 1-second timeout.
        wait(for: [completionExpectation], timeout: 3)
    }

    /// Case 3: Network responds with an error status → completion called with a non-timeout error message.
    func testPrefetchContent_WithCustomTimeout_CallsCompletionWithError_WhenNetworkReturnsErrorStatus() {
        let initExpectation = XCTestExpectation(description: "init")
        initSDK { initExpectation.fulfill() }
        wait(for: [initExpectation], timeout: 2)
        setValidConfiguration()

        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        let errorResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 500, httpVersion: nil, headerFields: nil)
        mockNetworkService.mock { _ in
            return (data: nil, response: errorResponse, error: nil)
        }

        let completionExpectation = XCTestExpectation(description: "completion called with network error")
        Target.prefetchContent(
            [TargetPrefetch(name: "mbox1")],
            with: nil,
            timeout: 5
        ) { error in
            XCTAssertNotNil(error, "Expected an error on 500 response")
            XCTAssertNotEqual(error.map { String(describing: $0) }, TargetError.ERROR_TIMEOUT,
                              "Error should be a network error, not a timeout error")
            completionExpectation.fulfill()
        }
        wait(for: [completionExpectation], timeout: 6)
    }

    /// Case 4: Original API (no timeout param) still works — backward compatibility check.
    func testPrefetchContent_WithoutTimeoutParam_CallsCompletionWithNoError_WhenResponseArrivesInTime() {
        let initExpectation = XCTestExpectation(description: "init")
        initSDK { initExpectation.fulfill() }
        wait(for: [initExpectation], timeout: 2)
        setValidConfiguration()

        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        let validResponse = HTTPURLResponse(url: URL(string: "https://amsdk.tt.omtrdc.net/rest/v1/delivery")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        mockNetworkService.mock { _ in
            return (data: self.successResponseString.data(using: .utf8), response: validResponse, error: nil)
        }

        let completionExpectation = XCTestExpectation(description: "completion called")
        // Original API — no timeout parameter
        Target.prefetchContent([TargetPrefetch(name: "mbox1")], with: nil) { error in
            XCTAssertNil(error, "Original API should still work with no timeout param")
            completionExpectation.fulfill()
        }
        wait(for: [completionExpectation], timeout: 3)
    }
}
