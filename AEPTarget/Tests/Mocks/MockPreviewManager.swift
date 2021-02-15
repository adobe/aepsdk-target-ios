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
@testable import AEPTarget
import Foundation

class MockTargetPreviewManager: PreviewManager {
    var enterPreviewModeWithDeepLinkCalled = false
    func enterPreviewModeWithDeepLink(clientCode _: String, deepLink _: URL) {
        enterPreviewModeWithDeepLinkCalled = true
    }

    var previewConfirmedWithUrlCalled = false
    var previewConfirmedWithUrlReturnVal = false
    func previewConfirmedWithUrl(_: URL, message _: FullscreenPresentable, previewLifecycleEventDispatcher _: (Event) -> Void) -> Bool {
        previewConfirmedWithUrlCalled = true
        return previewConfirmedWithUrlReturnVal
    }

    var fetchWebViewCalled = false
    func fetchWebView() {
        fetchWebViewCalled = true
    }

    var setRestartDeepLinkCalled = false
    var restartDeepLink = ""
    func setRestartDeepLink(_ restartDeepLink: String) {
        self.restartDeepLink = restartDeepLink
        setRestartDeepLinkCalled = true
    }

    var previewParameters: String?

    var previewToken: String?
}
