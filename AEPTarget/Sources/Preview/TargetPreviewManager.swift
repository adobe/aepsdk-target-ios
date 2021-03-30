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

import AEPCore
import AEPServices
import Foundation

struct TargetPreviewState {
    var clientCode: String?
    var previewQueryParameters: String?
    var token: String?
    var endpoint: String?
    var webViewHtml: String?
    var restartUrl: String?
    var fetchingWebView: Bool = false
    var previewButton: FloatingButtonPresentable?
    var fullscreenMessage: FullscreenPresentable?

    mutating func reset() {
        token = nil
        webViewHtml = nil
        endpoint = nil
        restartUrl = nil
        previewQueryParameters = nil

        if let previewButton = previewButton {
            previewButton.dismiss()
            self.previewButton = nil
        }
    }
}

class TargetPreviewManager: PreviewManager {
    private var state = TargetPreviewState()

    let LOG_TAG = "TargetPreviewManager"
    typealias previewManagerConstants = TargetConstants.PreviewManager
    typealias httpResponseConstants = HttpConnectionConstants.ResponseCodes
    typealias httpHeaderConstants = HttpConnectionConstants.Header

    public weak var floatingButtonDelegate: FloatingButtonDelegate?
    public weak var fullscreenMessageDelegate: FullscreenMessageDelegate?

    private var urlOpeningService: URLOpening {
        ServiceProvider.shared.urlService
    }

    private var networkService: Networking {
        ServiceProvider.shared.networkService
    }

    func enterPreviewModeWithDeepLink(clientCode: String, deepLink: URL) {
        state.clientCode = clientCode

        if deepLink.absoluteString.isEmpty {
            Log.debug(label: LOG_TAG, "Unable to enter preview mode with empty")
            return
        }
        guard let queryItemsDict = deepLink.queryItemsDict else {
            Log.debug(label: LOG_TAG, "Unable to enter preview mode, URL has no query items")
            return
        }

        guard let token = queryItemsDict[previewManagerConstants.PREVIEW_TOKEN], !token.isEmpty else {
            Log.debug(label: LOG_TAG, "Unable to enter preview mode without preview token")
            return
        }

        setupTargetPreviewFloatingButton()
        setupTargetPreviewQueryParameters(queryItemsDict)
        fetchWebView()
    }

    func previewConfirmedWithUrl(_ url: URL, message: FullscreenPresentable, previewLifecycleEventDispatcher: (Event) -> Void) {
        guard state.previewButton != nil else {
            Log.debug(label: LOG_TAG, "Preview button is nil")
            return
        }

        guard let deepLinkScheme = url.deepLinkScheme else {
            Log.debug(label: LOG_TAG, "Deeplink scheme does not match")
            return
        }

        switch deepLinkScheme {
        case .cancel:
            message.dismiss()
            state.reset()
            previewLifecycleEventDispatcher(createPreviewLifecycleEvent(isPreviewInitiated: false))
        case .confirm:
            if let previewQueryParams = url.queryItemsDict, !previewQueryParams.isEmpty {
                if let previewQueryParameters = previewQueryParams[previewManagerConstants.PREVIEW_PARAMETERS] {
                    state.previewQueryParameters = previewQueryParameters.removingPercentEncoding
                    previewLifecycleEventDispatcher(createPreviewLifecycleEvent(isPreviewInitiated: true))
                }
            }

            if let restartUrlString = state.restartUrl, let restartUrl = URL(string: restartUrlString) {
                urlOpeningService.openUrl(restartUrl)
            }

            message.dismiss()
        }
    }

    func fetchWebView() {
        if state.fetchingWebView {
            Log.debug(label: LOG_TAG, "Fetching web view already in progress")
            return
        }

        state.fetchingWebView = true
        guard let targetUrl = targetPreviewRequestUrl else {
            Log.debug(label: LOG_TAG, "Target preview request url was nil")
            return
        }

        Log.debug(label: LOG_TAG, "Sending preview request to url: \(targetUrl.absoluteString)")

        var requestHeaders: [String: String] = [:]
        requestHeaders[httpHeaderConstants.HTTP_HEADER_KEY_ACCEPT] = httpHeaderConstants.HTTP_HEADER_ACCEPT_TEXT_HTML
        let defaultTimeout = TargetConstants.NetworkConnection.DEFAULT_CONNECTION_TIMEOUT_SEC
        let networkRequest = NetworkRequest(url: targetUrl, httpMethod: .get, httpHeaders: requestHeaders, connectTimeout: defaultTimeout, readTimeout: defaultTimeout)
        networkService.connectAsync(networkRequest: networkRequest, completionHandler: { [weak self] httpConnection in
            guard let self = self else { return }
            guard let responseString = httpConnection.responseString, !responseString.isEmpty else {
                Log.warning(label: self.LOG_TAG, "Failed to fetch preview webview with connection status \(String(httpConnection.responseCode ?? 0)), response string was nil or empty")
                self.state.fetchingWebView = false
                return
            }
            if httpConnection.responseCode == httpResponseConstants.HTTP_OK {
                self.state.webViewHtml = responseString
                Log.debug(label: self.LOG_TAG, "Successfully fetched webview for preview mode, response body \(responseString)")
                self.createAndShowMessage()
            }
            self.state.fetchingWebView = false
        })
    }

    /// Sets the preview restart url in the target preview manager.
    /// - Parameters:
    ///     - deepLink: deepLink the `String`
    func setRestartDeepLink(_ deepLink: String) {
        state.restartUrl = deepLink
    }

    var previewParameters: String? {
        return state.previewQueryParameters
    }

    var previewToken: String? {
        return state.token
    }

    ///

    // MARK: - Private helper functions and variables

    ///

    ///
    /// Creates and shows the message using the PreviewManagerState
    ///
    private func createAndShowMessage() {
        guard let webViewHtml = state.webViewHtml else {
            Log.debug(label: LOG_TAG, "Unable to create fullscreen message, webhtml is nil")
            return
        }

        state.fullscreenMessage = ServiceProvider.shared.uiService.createFullscreenMessage(payload: webViewHtml, listener: fullscreenMessageDelegate ?? self, isLocalImageUsed: false)
        state.fullscreenMessage?.show()
    }

    ///
    /// The target preview request url
    /// Uses the TargetPreviewState's endpoint, clientCode, and token values to build the url
    ///
    private var targetPreviewRequestUrl: URL? {
        guard let host = state.endpoint, let clientCode = state.clientCode, let token = state.token else {
            return nil
        }
        guard var url = URL(string: "https://" + host) else {
            return nil
        }
        url.appendPathComponent("ui")
        url.appendPathComponent("admin")
        url.appendPathComponent(clientCode)
        url.appendPathComponent("preview")
        var urlComponents = URLComponents(string: url.absoluteString)
        let queryItems = [URLQueryItem(name: "token", value: token)]
        urlComponents?.queryItems = queryItems
        return urlComponents?.url
    }

    ///
    /// Sets up the PreviewButton
    ///
    private func setupTargetPreviewFloatingButton() {
        if state.previewButton != nil {
            Log.debug(label: LOG_TAG, "Setting up the Target preview floating button failed. Preview button already exists")
            return
        }

        state.previewButton = ServiceProvider.shared.uiService.createFloatingButton(listener: floatingButtonDelegate ?? self)
        state.previewButton?.show()
    }

    ///
    /// Sets up the query parameters (token, and endpoint)
    /// Removes the percent encoding from the values
    /// - Parameter parameters: The query parameters dictionary
    ///
    private func setupTargetPreviewQueryParameters(_ parameters: [String: String]) {
        state.token = parameters[previewManagerConstants.PREVIEW_TOKEN]?.removingPercentEncoding
        if let endpoint = parameters[previewManagerConstants.PREVIEW_ENDPOINT] {
            state.endpoint = endpoint.removingPercentEncoding
        } else {
            Log.debug(label: LOG_TAG, "Using the default preview endpoint")
            state.endpoint = previewManagerConstants.DEFAULT_TARGET_PREVIEW_ENDPOINT
        }
    }

    ///
    /// Creates and dispatches a Target Preview Lifecycle event
    /// - Parameter isPreviewInitiated: A boolean value indicating if the preview has been initiated or not
    ///
    private func createPreviewLifecycleEvent(isPreviewInitiated: Bool) -> Event {
        let eventData = [TargetConstants.EventDataKeys.PREVIEW_INITIATED: isPreviewInitiated]
        return Event(name: "Target Preview Lifecycle", type: EventType.target, source: EventSource.responseContent, data: eventData)
    }
}
