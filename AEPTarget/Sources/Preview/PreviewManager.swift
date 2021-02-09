/*
 Copyright 2020 Adobe. All rights reserved.
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

///
/// Preview Manager manages Target Preview Modes
///
protocol PreviewManager {
    ///
    /// Starts the preview mode by parsing the preview deep link, fetching the webview from target, displaying the preview button and creating a new custom message for the preview view
    /// - Parameters:
    ///     - clientCode: The client code as a `String`
    ///     - deepLink: The deep link `URL`
    ///
    func enterPreviewModeWithDeepLink(clientCode: String, deepLink: URL)

    ///
    /// This will process the given Url. If it is a cancel url, it dismisses the message and exits preview mode.
    /// If it is a confirm url, it dismisses the message, updates preview parameters and starts a new view if preview restart url is set
    /// - Parameters:
    ///     - url: `URL` to be processed
    ///     - message: The `FullScreenMessage` to be displayed
    ///     - previewLifecycleEventDispatcher: The event dispatcher closure which handles the preview lifecycle event dispatching
    func previewConfirmedWithUrl(_ url: URL, message: FullscreenPresentable, previewLifecycleEventDispatcher: (Event) -> Void) -> Bool

    ///
    /// If there is no other fetching in progress, it initiates a new async request to target.
    /// If the connection is successful and a valid response is received, a full screen message will be created and displayed.
    /// This method will be called for preview deeplinks or preview button tap detection
    ///
    func fetchWebView()

    ///
    /// Sets the restart deeplink
    /// - Parameter restartDeepLink: The restart deep link url
    ///
    func setRestartDeepLink(_ restartDeepLink: URL)

    ///
    /// The current preview parameters representing the json received from target servers as a string, or
    /// nil if preview mode was reset or not started
    ///
    var previewParameters: String? { get }

    ///
    /// The current preview token if available or empty string if preview mode was reset
    ///
    var previewToken: String? { get }
}
