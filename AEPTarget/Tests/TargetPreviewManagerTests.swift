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

class TargetPreviewManagerTests: XCTestCase {
    var target: Target!
    var targetPreviewManager: TargetPreviewManager!
    let mockNetworkService = TargetNetworkServiceMock()
    let mockUIDelegate = MockPreviewManagerUIDelegate()
    let mockRuntime = TestableExtensionRuntime()
    let mockUrlOpener = MockUrlOpeningService()

    override func setUp() {
        target = Target(runtime: mockRuntime)
        ServiceProvider.shared.networkService = mockNetworkService
        ServiceProvider.shared.urlService = mockUrlOpener
        targetPreviewManager = TargetPreviewManager()
        targetPreviewManager.floatingButtonDelegate = mockUIDelegate
        targetPreviewManager.fullscreenMessageDelegate = mockUIDelegate
    }

    ///

    // MARK: - EnterPreviewModeWithDeepLink tests

    ///

    ///
    /// Tests enterPreviewModeWithDeepLink's happy path
    /// Sets up preview floating button, preview token is set in state, fetchwebview is called with network request
    ///
    func testEnterPreviewModeWithDeepLinkHappy() {
        let testToken = "abcd"
        let testDeeplink = URL(string: "test://path?at_preview_token=\(testToken)&key1=val1")
        let expectedEndpointUrl = "https://" + TargetTestConstants.DEFAULT_TARGET_PREVIEW_ENDPOINT + "/ui/admin/" + TargetTestConstants.TEST_CLIENT_CODE + "/preview?token=abcd"
        targetPreviewManager.enterPreviewModeWithDeepLink(clientCode: TargetTestConstants.TEST_CLIENT_CODE, deepLink: testDeeplink!)
        let expectation = XCTestExpectation(description: "On show button called expectation")
        mockUIDelegate.onShowButtonExpectation = expectation
        wait(for: [expectation], timeout: 0.5)
        XCTAssertTrue(mockUIDelegate.onShowButtonCalled)
        XCTAssertEqual(targetPreviewManager.previewToken, testToken)
        let networkRequest = mockNetworkService.connectAsyncCalledWithNetworkRequest
        XCTAssertEqual(networkRequest?.url.absoluteString, expectedEndpointUrl)
        XCTAssertEqual(networkRequest?.httpMethod, .get)
        XCTAssertEqual(networkRequest?.readTimeout, 5)
        XCTAssertEqual(networkRequest?.connectTimeout, 5)
        XCTAssertTrue(mockNetworkService.connectAsyncCalled)
    }

    ///
    /// Tests enterPreviewModeWithDeepLink with no query items (params) in the deep link url
    /// No preview button is set up, no web view is fetched, and previewParameters should be nil
    func testEnterPreviewModeWithDeepLinkNoParams() {
        guard let urlWithNoQueryItems = URL(string: "https://testUrl.com") else {
            XCTFail()
            return
        }
        targetPreviewManager.enterPreviewModeWithDeepLink(clientCode: TargetTestConstants.TEST_CLIENT_CODE, deepLink: urlWithNoQueryItems)
        let expectation = XCTestExpectation(description: "On show button called expectation")
        expectation.isInverted = true
        mockUIDelegate.onShowButtonExpectation = expectation
        wait(for: [expectation], timeout: 0.5)
        XCTAssertFalse(mockUIDelegate.onShowButtonCalled)
        XCTAssertFalse(mockNetworkService.connectAsyncCalled)
        XCTAssertNil(mockNetworkService.connectAsyncCalledWithNetworkRequest)
        XCTAssertNil(targetPreviewManager.previewParameters)
    }

    ///
    /// Tests enterPreviewModeWithDeepLink without a token in the url
    /// No preview button is set up, no web view is fetched, and previewParameters should be nil
    ///
    func testEnterPreviewModeWithDeepLinkNoToken() {
        guard let urlWithNoTokenQuery = URL(string: "https://test?query1=abc") else {
            XCTFail()
            return
        }

        targetPreviewManager.enterPreviewModeWithDeepLink(clientCode: TargetTestConstants.TEST_CLIENT_CODE, deepLink: urlWithNoTokenQuery)

        let expectation = XCTestExpectation(description: "On show button called expectation")
        expectation.isInverted = true
        mockUIDelegate.onShowButtonExpectation = expectation
        wait(for: [expectation], timeout: 0.5)
        XCTAssertFalse(mockUIDelegate.onShowButtonCalled)
        XCTAssertFalse(mockNetworkService.connectAsyncCalled)
        XCTAssertNil(mockNetworkService.connectAsyncCalledWithNetworkRequest)
        XCTAssertNil(targetPreviewManager.previewParameters)
    }

    ///
    /// Tests enterPreviewModeWithDeepLink with a custom endpoint
    /// Sets up preview floating button, preview token is set in state, fetchwebview is called with network request, and new endpoint is used
    ///
    func testEnterPreviewModeWithDeepLinkParamsWithCustomEndpoint() {
        let testToken = "abcd"
        let testDeepLink = URL(string: "test://path?at_preview_token=\(testToken)&key1=val1&at_preview_endpoint=awesomeendpoint")
        let expectedUrl = "https://awesomeendpoint/ui/admin/" + TargetTestConstants.TEST_CLIENT_CODE + "/preview?token=\(testToken)"
        targetPreviewManager.enterPreviewModeWithDeepLink(clientCode: TargetTestConstants.TEST_CLIENT_CODE, deepLink: testDeepLink!)

        let expectation = XCTestExpectation(description: "On show button called expectation")
        mockUIDelegate.onShowButtonExpectation = expectation
        wait(for: [expectation], timeout: 0.5)
        XCTAssertTrue(mockUIDelegate.onShowButtonCalled)
        XCTAssertEqual(targetPreviewManager.previewToken, testToken)
        let networkRequest = mockNetworkService.connectAsyncCalledWithNetworkRequest
        XCTAssertEqual(networkRequest?.url.absoluteString, expectedUrl)
        XCTAssertEqual(networkRequest?.httpMethod, .get)
        XCTAssertEqual(networkRequest?.readTimeout, 5)
        XCTAssertEqual(networkRequest?.connectTimeout, 5)
        XCTAssertTrue(mockNetworkService.connectAsyncCalled)
    }

    ///

    // MARK: - fetchWebView tests

    ///

    /// Tests fetchWebView happy path (targetPreviewRequest url is set up, network request is successful)
    /// fullscreen message is shown
    ///
    func testFetchWebViewHappyPath() {
        setupPreviewMode()
        targetPreviewManager.fetchWebView()
        XCTAssertTrue(mockNetworkService.connectAsyncCalled)
        let expectation = XCTestExpectation(description: "Show fullscreen message expectation")
        mockUIDelegate.onShowExpectation = expectation
        wait(for: [expectation], timeout: 0.5)
        XCTAssertTrue(mockUIDelegate.onShowCalled)
    }

    ///
    /// Tests fetchWebView when the targetPreviewRequest url is nil
    /// Exits early and network request is not performed
    func testFetchWebViewTargetPreviewRequestUrlNil() {
        // Don't setup targetPreviewRequestUrl state
        targetPreviewManager.fetchWebView()
        XCTAssertFalse(mockNetworkService.connectAsyncCalled)
    }

    ///
    /// Tests fetchWebView with empty response string
    /// exits early (create and show message not called)
    ///
    func testFetchWebViewEmptyResponse() {
        setupPreviewMode()
        let httpConnectionWithEmptyResponse = HttpConnection(data: nil, response: nil, error: nil)
        mockNetworkService.expectedResponse = httpConnectionWithEmptyResponse
        targetPreviewManager.fetchWebView()
        XCTAssertTrue(mockNetworkService.connectAsyncCalled)
        let expectation = XCTestExpectation(description: "Fullscreen message not shown expectation")
        expectation.isInverted = true
        mockUIDelegate.onShowExpectation = expectation
        wait(for: [expectation], timeout: 0.5)
        XCTAssertFalse(mockUIDelegate.onShowCalled)
    }

    ///

    // MARK: - PreviewConfirmedWithUrl Tests

    ///

    ///
    /// Tests previewConfirmedWithUrl happy path with confirm scheme
    /// Makes sure that the message is dismissed, previewLifecycle event is dispatched, method returns true, verifies the preview parameters are correct
    func testPreviewConfirmedWithUrlHappyPathConfirm() {
        setupPreviewMode()
        let fullscreenMessage = FullscreenMessage(payload: "", listener: mockUIDelegate)
        let url = URL(string: TargetTestConstants.TEST_CONFIRM_DEEPLINK)
        var eventDispatched = false
        let expectation = XCTestExpectation(description: "Fullscreen message dismiss called expectation")
        mockUIDelegate.onDismissExpectation = expectation
        XCTAssertTrue(targetPreviewManager.previewConfirmedWithUrl(url!, message: fullscreenMessage, previewLifecycleEventDispatcher: { event in
            eventDispatched = true
            XCTAssertEqual(event.name, "Target Preview Lifecycle")
            XCTAssertTrue(event.data![TargetConstants.EventDataKeys.PREVIEW_INITIATED] as! Bool)
        }))

        XCTAssertTrue(eventDispatched)
        verifyQaModeParams(targetPreviewManager.previewParameters ?? "")
        wait(for: [expectation], timeout: 0.5)
        XCTAssertTrue(mockUIDelegate.onDismissCalled)
    }

    ///
    /// Tests previewConfirmedWithUrl happy path with cancel scheme
    /// method returns true, event is dispatched with false value for PREVIEW_INITIATED data key, preview parameters are nil, preview token is nil, on dismiss is called
    ///
    func testPreviewConfirmedWithUrlHappyPathCancel() {
        setupPreviewMode()
        let fullscreenMessage = FullscreenMessage(payload: "", listener: mockUIDelegate)
        let url = URL(string: TargetTestConstants.TEST_CANCEL_DEEPLINK)
        var eventDispatched = false
        let expectation = XCTestExpectation(description: "Fullscreen message dismiss called expectation")
        mockUIDelegate.onDismissExpectation = expectation
        XCTAssertTrue(targetPreviewManager.previewConfirmedWithUrl(url!, message: fullscreenMessage, previewLifecycleEventDispatcher: { event in
            eventDispatched = true
            XCTAssertEqual(event.name, "Target Preview Lifecycle")
            XCTAssertFalse(event.data![TargetConstants.EventDataKeys.PREVIEW_INITIATED] as! Bool)
        }))

        XCTAssertTrue(eventDispatched)
        // Make sure the target preview properties have been reset
        XCTAssertNil(targetPreviewManager.previewParameters)
        XCTAssertNil(targetPreviewManager.previewToken)
        wait(for: [expectation], timeout: 0.5)
        XCTAssertTrue(mockUIDelegate.onDismissCalled)
    }

    ///
    /// Tests enterPreviewModeWithDeeplink exits early when preview button has not been set up
    ///
    func testPreviewConfirmedWithUrlNoPreviewButton() {
        let fullscreenMessage = FullscreenMessage(payload: "", listener: mockUIDelegate)
        let url = URL(string: TargetTestConstants.TEST_CONFIRM_DEEPLINK)
        XCTAssertFalse(targetPreviewManager.previewConfirmedWithUrl(url!, message: fullscreenMessage, previewLifecycleEventDispatcher: { _ in
            XCTFail()
        }))
    }

    ///
    /// Tests previewConfirmedWithUrl when url has no correct scheme exits early
    ///
    func testPreviewConfirmedWithUrlNoSchemeMatch() {
        setupPreviewMode()
        let fullscreenMessage = FullscreenMessage(payload: "", listener: mockUIDelegate)
        let incorrectSchemeUrl = URL(string: "bbbinapp://confirm")
        XCTAssertFalse(targetPreviewManager.previewConfirmedWithUrl(incorrectSchemeUrl!, message: fullscreenMessage, previewLifecycleEventDispatcher: { _ in
            XCTFail()
        }))
    }

    ///
    /// Tests previewConfirmedWithUrl happy path, when restart url is set
    ///
    func testPreviewConfirmedWithUrlRestartUrlSet() {
        setupPreviewMode()
        targetPreviewManager.setRestartDeepLink(TargetTestConstants.TEST_RESTART_URL)
        let fullscreenMessage = FullscreenMessage(payload: "", listener: mockUIDelegate)
        let url = URL(string: TargetTestConstants.TEST_CONFIRM_DEEPLINK)
        var eventDispatched = false
        let expectation = XCTestExpectation(description: "Fullscreen message dismiss called expectation")
        mockUIDelegate.onDismissExpectation = expectation
        XCTAssertTrue(targetPreviewManager.previewConfirmedWithUrl(url!, message: fullscreenMessage, previewLifecycleEventDispatcher: { event in
            eventDispatched = true
            XCTAssertEqual(event.name, "Target Preview Lifecycle")
            XCTAssertTrue(event.data![TargetConstants.EventDataKeys.PREVIEW_INITIATED] as! Bool)
        }))

        XCTAssertTrue(eventDispatched)
        verifyQaModeParams(targetPreviewManager.previewParameters ?? "")
        wait(for: [expectation], timeout: 0.5)
        XCTAssertTrue(mockUIDelegate.onDismissCalled)

        XCTAssertTrue(mockUrlOpener.openUrlCalled)
        XCTAssertEqual(mockUrlOpener.openUrlParam?.absoluteString, TargetTestConstants.TEST_RESTART_URL)
    }

    ///

    // MARK: - Helper functions

    ///
    private func setupPreviewMode() {
        let testDeeplink = URL(string: "test://path?at_preview_token=abcd&key1=val1")
        let expectedUrl = URL(string: "https://" + TargetTestConstants.DEFAULT_TARGET_PREVIEW_ENDPOINT + "/ui/admin/" + "/preview?token=abcd")
        let urlResponse = HTTPURLResponse(url: expectedUrl!, statusCode: 200, httpVersion: nil, headerFields: ["test": "test"])
        let data = "htmlContent".data(using: .utf8)
        let expectedHttpResponse = HttpConnection(data: data, response: urlResponse, error: nil)
        mockNetworkService.expectedResponse = expectedHttpResponse
        targetPreviewManager.enterPreviewModeWithDeepLink(clientCode: TargetTestConstants.TEST_CLIENT_CODE, deepLink: testDeeplink!)
    }

    private func verifyQaModeParams(_ params: String) {
        guard let expectedResultData = TargetTestConstants.JSON_PREVIEW_PARAMS.data(using: .utf8) else {
            XCTFail()
            return
        }
        guard let expectedResultJson = (try? JSONSerialization.jsonObject(with: expectedResultData, options: [])) as? [String: Any] else {
            XCTFail()
            return
        }
        guard let actualData = params.data(using: .utf8) else {
            XCTFail()
            return
        }
        guard let actualJson = (try? JSONSerialization.jsonObject(with: actualData, options: [])) as? [String: Any] else {
            XCTFail()
            return
        }
        guard let expectedQaMode = expectedResultJson[TargetTestConstants.PREVIEW_QA_MODE] as? [String: Any] else {
            XCTFail()
            return
        }
        guard let actualQaMode = actualJson[TargetTestConstants.PREVIEW_QA_MODE] as? [String: Any] else {
            XCTFail()
            return
        }
        XCTAssertEqual(expectedQaMode.count, actualQaMode.count)

        XCTAssertEqual(expectedQaMode["token"] as? String, actualQaMode["token"] as? String)
        XCTAssertEqual(expectedQaMode["bypassEntryAudience"] as? Bool, actualQaMode["bypassEntryAudience"] as? Bool)
        XCTAssertEqual(expectedQaMode["bypassEntryAudience"] as? Bool, actualQaMode["bypassEntryAudience"] as? Bool)
        XCTAssertEqual(expectedQaMode["listedActivitiesOnly"] as? Bool, actualQaMode["listedActivitiesOnly"] as? Bool)
        let expectedEvaluateAsTrueAudienceIds = expectedQaMode["evaluateAsTrueAudienceIds"] as? [String: Any]
        let actualEvaluateAsTrueAudienceIds = actualQaMode["evaluateAsTrueAudienceIds"] as? [String: Any]
        XCTAssertEqual(expectedEvaluateAsTrueAudienceIds?.count, actualEvaluateAsTrueAudienceIds?.count)
        let expectedEvaluateAsFalseAudienceIds = expectedQaMode["evaluateAsFalseAudienceIds"] as? [String: Any]
        let actualEvaluateAsFalseAudienceIds = actualQaMode["evaluateAsFalseAudienceIds"] as? [String: Any]
        XCTAssertEqual(expectedEvaluateAsFalseAudienceIds?.count, actualEvaluateAsFalseAudienceIds?.count)
        let expectedPreviewIndexes = expectedQaMode["previewIndexes"] as? [String: Any]
        let actualPreviewIndexes = actualQaMode["previewIndexes"] as? [String: Any]
        XCTAssertEqual(expectedPreviewIndexes?.count, actualPreviewIndexes?.count)
    }
}
