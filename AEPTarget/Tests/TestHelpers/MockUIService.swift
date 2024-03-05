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

import AEPServices
import Foundation
import XCTest

class MockFullscreenMessage: FullscreenPresentable {
    var showCalled = false
    func show() {
        showCalled = true
    }

    var dismissCalled = false
    func dismiss() {
        dismissCalled = true
    }
}

class MockFloatingButton: FloatingButtonPresentable {
    enum Invocation {
        case SHOW
        case DISMISS
    }
    private var invocations: [Invocation] = []

    var showCalled = false
    var showCalledCount = 0
    func show() {
        showCalled = true
        showCalledCount += 1
        invocations.append(.SHOW)
    }

    var dismissCalled = false
    var dismissCalledCount = 0
    func dismiss() {
        dismissCalled = true
        dismissCalledCount += 1
        invocations.append(.DISMISS)
    }

    var setButtonImageCalled = false
    func setButtonImage(imageData _: Data) {
        setButtonImageCalled = true
    }

    var setInitialCalled = false
    func setInitial(position _: FloatingButtonPosition) {
        setInitialCalled = true
    }
    
    func verify(expectedInvocations: [Invocation], file: StaticString = #file, line: UInt = #line) {
        if invocations != expectedInvocations {
            XCTFail("Expected \(expectedInvocations), but got \(invocations)", file: file, line: line)
        }
    }
}

class MockUIService: UIService {
    public init() {}

    var createFullscreenMessageCalled = false
    var createFullscreenMessageCallCount = 0
    var fullscreenMessage: FullscreenPresentable?
    public func createFullscreenMessage(payload _: String, listener _: FullscreenMessageDelegate?, isLocalImageUsed _: Bool) -> FullscreenPresentable {
        createFullscreenMessageCalled = true
        createFullscreenMessageCallCount += 1
        return fullscreenMessage ?? MockFullscreenMessage()
    }

    var createFloatingButtonCalled = false
    var floatingButton: FloatingButtonPresentable?
    public func createFloatingButton(listener _: FloatingButtonDelegate) -> FloatingButtonPresentable {
        createFloatingButtonCalled = true
        return floatingButton ?? MockFloatingButton()
    }
}
