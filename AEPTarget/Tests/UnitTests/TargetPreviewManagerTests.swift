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
    let mockRuntime = TestableExtensionRuntime()
    let mockUrlOpener = MockUrlOpeningService()
    let mockUIService = MockUIService()

    override func setUp() {
        target = Target(runtime: mockRuntime)
        ServiceProvider.shared.networkService = mockNetworkService
        ServiceProvider.shared.urlService = mockUrlOpener
        ServiceProvider.shared.uiService = mockUIService
        targetPreviewManager = TargetPreviewManager()
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
        let mockButton = MockFloatingButton()
        mockUIService.floatingButton = mockButton
        let expectedEndpointUrl = "https://" + TargetTestConstants.DEFAULT_TARGET_PREVIEW_ENDPOINT + "/ui/admin/" + TargetTestConstants.TEST_CLIENT_CODE + "/preview?token=abcd"
        targetPreviewManager.enterPreviewModeWithDeepLink(clientCode: TargetTestConstants.TEST_CLIENT_CODE, deepLink: testDeeplink!)
        XCTAssertTrue(mockUIService.createFloatingButtonCalled)
        XCTAssertTrue(mockButton.showCalled)
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
        let mockButton = MockFloatingButton()
        mockUIService.floatingButton = mockButton
        targetPreviewManager.enterPreviewModeWithDeepLink(clientCode: TargetTestConstants.TEST_CLIENT_CODE, deepLink: urlWithNoQueryItems)
        XCTAssertFalse(mockUIService.createFloatingButtonCalled)
        XCTAssertFalse(mockButton.showCalled)
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
        let mockButton = MockFloatingButton()
        mockUIService.floatingButton = mockButton
        targetPreviewManager.enterPreviewModeWithDeepLink(clientCode: TargetTestConstants.TEST_CLIENT_CODE, deepLink: urlWithNoTokenQuery)

        XCTAssertFalse(mockUIService.createFloatingButtonCalled)
        XCTAssertFalse(mockButton.showCalled)
        XCTAssertFalse(mockNetworkService.connectAsyncCalled)
        XCTAssertNil(mockNetworkService.connectAsyncCalledWithNetworkRequest)
        XCTAssertNil(targetPreviewManager.previewParameters)
    }

    ///
    /// Tests enterPreviewModeWithDeepLink without a token in the url
    /// No preview button is set up, no web view is fetched, and previewParameters should be nil
    ///
    func testEnterPreviewModeWithDeepLinkEmptyToken() {
        guard let urlWithEmptyTokenQuery = URL(string: "https://test?query1=abc&at_preview_token=") else {
            XCTFail()
            return
        }
        let mockButton = MockFloatingButton()
        mockUIService.floatingButton = mockButton
        targetPreviewManager.enterPreviewModeWithDeepLink(clientCode: TargetTestConstants.TEST_CLIENT_CODE, deepLink: urlWithEmptyTokenQuery)

        XCTAssertFalse(mockUIService.createFloatingButtonCalled)
        XCTAssertFalse(mockButton.showCalled)
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
        let mockButton = MockFloatingButton()
        mockUIService.floatingButton = mockButton
        targetPreviewManager.enterPreviewModeWithDeepLink(clientCode: TargetTestConstants.TEST_CLIENT_CODE, deepLink: testDeepLink!)

        XCTAssertTrue(mockUIService.createFloatingButtonCalled)
        XCTAssertTrue(mockButton.showCalled)
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
        let mockButton = MockFloatingButton()
        mockUIService.floatingButton = mockButton
        setupPreviewMode()
        // Button shown and hidden once via the setupPreviewMode
        XCTAssertEqual(mockButton.showCalledCount, 1)
        XCTAssertEqual(mockButton.dismissCalledCount, 1)
        let mockMessage = MockFullscreenMessage()
        mockUIService.fullscreenMessage = mockMessage
        targetPreviewManager.fetchWebView()
        XCTAssertTrue(mockNetworkService.connectAsyncCalled)
        XCTAssertTrue(mockUIService.createFullscreenMessageCalled)
        XCTAssertTrue(mockMessage.showCalled)
        // Button is hidden when webview is shown
        XCTAssertEqual(mockButton.dismissCalledCount, 2)
        mockButton.verify(expectedInvocations: [.SHOW, .DISMISS, .DISMISS])
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
        let mockButton = MockFloatingButton()
        mockUIService.floatingButton = mockButton
        setupPreviewMode()
        // Button shown and hidden once via the setupPreviewMode
        XCTAssertEqual(mockButton.showCalledCount, 1)
        XCTAssertEqual(mockButton.dismissCalledCount, 1)
        
        let httpConnectionWithEmptyResponse = HttpConnection(data: nil, response: nil, error: nil)
        mockNetworkService.expectedResponse = httpConnectionWithEmptyResponse
        let mockMessage = MockFullscreenMessage()
        mockUIService.fullscreenMessage = mockMessage
        targetPreviewManager.fetchWebView()
        XCTAssertTrue(mockNetworkService.connectAsyncCalled)
        // Called once via the setupPreviewMode but not in the fetchWebView call
        XCTAssertEqual(mockUIService.createFullscreenMessageCallCount, 1)
        XCTAssertFalse(mockMessage.showCalled)
        XCTAssertEqual(mockButton.showCalledCount, 1)
        XCTAssertEqual(mockButton.dismissCalledCount, 1)
    }

    ///

    // MARK: - PreviewConfirmedWithUrl Tests

    ///

    ///
    /// Tests previewConfirmedWithUrl happy path with confirm scheme
    /// Makes sure that the message is dismissed, previewLifecycle event is dispatched, method returns true, verifies the preview parameters are correct
    func testPreviewConfirmedWithUrlHappyPathConfirm() {
        let mockButton = MockFloatingButton()
        mockUIService.floatingButton = mockButton
        setupPreviewMode()
        // Button shown and hidden once via the setupPreviewMode
        XCTAssertEqual(mockButton.showCalledCount, 1)
        XCTAssertEqual(mockButton.dismissCalledCount, 1)
        let fullscreenMessage = MockFullscreenMessage()
        mockUIService.fullscreenMessage = fullscreenMessage
        let url = URL(string: TargetTestConstants.TEST_CONFIRM_DEEPLINK)
        var eventDispatched = false
        targetPreviewManager.previewConfirmedWithUrl(url!, message: fullscreenMessage, previewLifecycleEventDispatcher: { event in
            eventDispatched = true
            XCTAssertEqual(event.name, "Target Preview Lifecycle")
            XCTAssertTrue(event.data![TargetConstants.EventDataKeys.PREVIEW_INITIATED] as! Bool)

        })
        XCTAssertTrue(eventDispatched)
        verifyQaModeParams(targetPreviewManager.previewParameters ?? "")
        XCTAssertTrue(mockUIService.createFullscreenMessageCalled)
        XCTAssertTrue(fullscreenMessage.dismissCalled)
        // floating button is dismissed and shown again when webview is hidden
        XCTAssertEqual(mockButton.showCalledCount, 2)
        mockButton.verify(expectedInvocations: [.SHOW, .DISMISS, .SHOW])
    }

    ///
    /// Tests previewConfirmedWithUrl happy path with cancel scheme
    /// method returns true, event is dispatched with false value for PREVIEW_INITIATED data key, preview parameters are nil, preview token is nil, on dismiss is called
    ///
    func testPreviewConfirmedWithUrlHappyPathCancel() {
        let fullscreenMessage = MockFullscreenMessage()
        mockUIService.fullscreenMessage = fullscreenMessage
        let mockButton = MockFloatingButton()
        mockUIService.floatingButton = mockButton
        setupPreviewMode()
        // Button shown and hidden once via the setupPreviewMode
        XCTAssertEqual(mockButton.showCalledCount, 1)
        XCTAssertEqual(mockButton.dismissCalledCount, 1)
        let url = URL(string: TargetTestConstants.TEST_CANCEL_DEEPLINK)
        var eventDispatched = false
        targetPreviewManager.previewConfirmedWithUrl(url!, message: fullscreenMessage, previewLifecycleEventDispatcher: { event in
            eventDispatched = true
            XCTAssertEqual(event.name, "Target Preview Lifecycle")
            XCTAssertFalse(event.data![TargetConstants.EventDataKeys.PREVIEW_INITIATED] as! Bool)
        })

        XCTAssertTrue(eventDispatched)
        // Make sure the target preview properties have been reset
        XCTAssertNil(targetPreviewManager.previewParameters)
        XCTAssertNil(targetPreviewManager.previewToken)
        XCTAssertTrue(mockUIService.createFullscreenMessageCalled)
        XCTAssertTrue(fullscreenMessage.dismissCalled)
        // floating button is dismissed when webview is hidden
        XCTAssertEqual(mockButton.dismissCalledCount, 2)
        mockButton.verify(expectedInvocations: [.SHOW, .DISMISS, .DISMISS])
    }

    ///
    /// Tests enterPreviewModeWithDeeplink exits early when preview button has not been set up
    ///
    func testPreviewConfirmedWithUrlNoPreviewButton() {
        let fullscreenMessage = MockFullscreenMessage()
        mockUIService.fullscreenMessage = fullscreenMessage
        let url = URL(string: TargetTestConstants.TEST_CONFIRM_DEEPLINK)
        targetPreviewManager.previewConfirmedWithUrl(url!, message: fullscreenMessage, previewLifecycleEventDispatcher: { _ in
            XCTFail()
        })
        XCTAssertFalse(fullscreenMessage.dismissCalled)
    }

    ///
    /// Tests previewConfirmedWithUrl when url has no correct scheme exits early
    ///
    func testPreviewConfirmedWithUrlNoSchemeMatch() {
        let fullscreenMessage = MockFullscreenMessage()
        mockUIService.fullscreenMessage = fullscreenMessage
        let mockButton = MockFloatingButton()
        mockUIService.floatingButton = mockButton
        setupPreviewMode()
        // Button shown and hidden once via the setupPreviewMode
        XCTAssertEqual(mockButton.showCalledCount, 1)
        XCTAssertEqual(mockButton.dismissCalledCount, 1)
        let incorrectSchemeUrl = URL(string: "bbbinapp://confirm")
        targetPreviewManager.previewConfirmedWithUrl(incorrectSchemeUrl!, message: fullscreenMessage, previewLifecycleEventDispatcher: { _ in
            XCTFail()
        })

        XCTAssertFalse(fullscreenMessage.dismissCalled)
        XCTAssertEqual(mockButton.showCalledCount, 1)
        XCTAssertEqual(mockButton.dismissCalledCount, 1)
    }

    ///
    /// Tests previewConfirmedWithUrl happy path, when restart url is set
    ///
    func testPreviewConfirmedWithUrlRestartUrlSet() {
        let mockButton = MockFloatingButton()
        mockUIService.floatingButton = mockButton
        setupPreviewMode()
        // Button shown and hidden once via the setupPreviewMode
        XCTAssertEqual(mockButton.showCalledCount, 1)
        XCTAssertEqual(mockButton.dismissCalledCount, 1)
        targetPreviewManager.setRestartDeepLink(TargetTestConstants.TEST_RESTART_URL)
        let fullscreenMessage = MockFullscreenMessage()
        mockUIService.fullscreenMessage = fullscreenMessage
        let url = URL(string: TargetTestConstants.TEST_CONFIRM_DEEPLINK)
        var eventDispatched = false
        targetPreviewManager.previewConfirmedWithUrl(url!, message: fullscreenMessage, previewLifecycleEventDispatcher: { event in
            eventDispatched = true
            XCTAssertEqual(event.name, "Target Preview Lifecycle")
            XCTAssertTrue(event.data![TargetConstants.EventDataKeys.PREVIEW_INITIATED] as! Bool)
        })

        XCTAssertTrue(eventDispatched)
        verifyQaModeParams(targetPreviewManager.previewParameters ?? "")
        XCTAssertTrue(mockUIService.createFullscreenMessageCalled)
        XCTAssertTrue(fullscreenMessage.dismissCalled)
        // floating button is shown when webview is hidden
        XCTAssertEqual(mockButton.showCalledCount, 2)
        mockButton.verify(expectedInvocations: [.SHOW, .DISMISS, .SHOW])

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
