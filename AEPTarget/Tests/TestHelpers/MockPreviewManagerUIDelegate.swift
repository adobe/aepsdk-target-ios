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

@testable import AEPServices
import XCTest

class MockPreviewManagerUIDelegate: FullscreenMessageDelegate, FloatingButtonDelegate {
    func onShowFailure() {}

    var onShowButtonCalled = false
    var onShowButtonExpectation: XCTestExpectation?
    // Button on show
    func onShow() {
        onShowButtonCalled = true
        onShowButtonExpectation?.fulfill()
    }

    // Button on dismiss
    var onButtonDismissCalled = false
    var onButtonDismissExpectation: XCTestExpectation?
    func onDismiss() {
        onButtonDismissCalled = true
        onButtonDismissExpectation?.fulfill()
    }

    var onShowCalled = false
    var onShowMessage: FullscreenMessage?
    // This expectation is needed because the show in FullScreenMessage is performed on the main thread
    var onShowExpectation: XCTestExpectation?
    func onShow(message: FullscreenMessage) {
        onShowCalled = true
        onShowMessage = message
        onShowExpectation?.fulfill()
    }

    var onDismissCalled = false
    var onDismissMessage: FullscreenMessage?
    // This expectation is needed because the dismiss in FullScreenMessage is performed on the main thread
    var onDismissExpectation: XCTestExpectation?
    func onDismiss(message: FullscreenMessage) {
        onDismissCalled = true
        onDismissMessage = message
        onDismissExpectation?.fulfill()
    }

    var overrideUrlLoadCalled = false
    var overrideUrlLoadMessage: FullscreenMessage?
    var overrideUrlLoadUrl: String?
    var overrideUrlLoadResult = false
    func overrideUrlLoad(message: FullscreenMessage, url: String?) -> Bool {
        overrideUrlLoadCalled = true
        overrideUrlLoadMessage = message
        overrideUrlLoadUrl = url
        return overrideUrlLoadResult
    }

    var onTapDetectedCalled = false
    func onTapDetected() {
        onTapDetectedCalled = true
    }

    var onPanDetectedCalled = false
    func onPanDetected() {
        onPanDetectedCalled = true
    }
}
