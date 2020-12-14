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
import Foundation

@objc(AEPMobileTarget)
public class Target: NSObject, Extension {
    internal static let LOG_TAG = "Target"

    // MARK: - Extension

    public var name = TargetConstants.EXTENSION_NAME

    public var friendlyName = TargetConstants.FRIENDLY_NAME

    public static var extensionVersion = TargetConstants.EXTENSION_VERSION

    public var metadata: [String: String]?

    public var runtime: ExtensionRuntime

    public required init?(runtime: ExtensionRuntime) {
        self.runtime = runtime
        super.init()
    }

    public func onRegistered() {
        registerListener(type: EventType.target, source: EventSource.requestContent, listener: handle)
        registerListener(type: EventType.target, source: EventSource.requestReset, listener: handle)
        registerListener(type: EventType.target, source: EventSource.requestIdentity, listener: handle)
        registerListener(type: EventType.configuration, source: EventSource.responseContent, listener: handle)
        registerListener(type: EventType.genericData, source: EventSource.os, listener: handle)
    }

    public func onUnregistered() {}

    public func readyForEvent(_: Event) -> Bool {
        return true
    }

    // MARK: - Event Listeners

    private func handle(event _: Event) {}
}
