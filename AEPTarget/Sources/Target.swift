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
    internal let LOG_TAG = "Target"

    // MARK: - Extension

    public var name = TargetConstants.EXTENSION_NAME

    public var friendlyName = TargetConstants.FRIENDLY_NAME

    public static var extensionVersion = TargetConstants.EXTENSION_VERSION

    public var metadata: [String: String]?

    public var runtime: ExtensionRuntime

    static var previewManager = TargetPreviewManager()

    public required init?(runtime: ExtensionRuntime) {
        self.runtime = runtime
        super.init()
    }

    public func onRegistered() {
        registerListener(type: EventType.target, source: EventSource.requestContent, listener: handle)
        registerListener(type: EventType.target, source: EventSource.requestReset, listener: handle)
        registerListener(type: EventType.target, source: EventSource.requestIdentity, listener: handle)
        registerListener(type: EventType.configuration, source: EventSource.responseContent, listener: handle)
        registerListener(type: EventType.genericData, source: EventSource.os, listener: handleGenericDataOS)
    }

    public func onUnregistered() {}

    public func readyForEvent(_: Event) -> Bool {
        return true
    }

    // MARK: - Event Listeners

    private func handle(event: Event) {
        if let restartDeeplink = event.data?[TargetConstants.EventDataKeys.PREVIEW_RESTART_DEEP_LINK] as? String, let restartDeeplinkUrl = URL(string: restartDeeplink) {
            Target.setPreviewRestartDeepLink(restartDeeplinkUrl)
        }
    }

    private func handleGenericDataOS(event: Event) {
        if let deeplink = event.data?[TargetConstants.EventDataKeys.DEEPLINK] as? String, !deeplink.isEmpty {
            processPreviewDeepLink(event: event, deeplink: deeplink)
        }
    }

    // MARK: - Event Handlers

    private func processPreviewDeepLink(event: Event, deeplink: String) {
        guard let configSharedState = getSharedState(extensionName: TargetConstants.Configuration.EXTENSION_NAME, event: event)?.value else {
            Log.warning(label: LOG_TAG, "Target process preview deep link failed, config data is nil")
            return
        }

        if !prepareForTargetRequest(configSharedState: configSharedState) {
            Log.warning(label: LOG_TAG, "Target is not enabled, cannot enter in preview mode.")
            return
        }

        guard let isPreviewEnabled = configSharedState[TargetConstants.EventDataKeys.Configuration.TARGET_PREVIEW_ENABLED] as? Bool, !isPreviewEnabled else {
            Log.error(label: LOG_TAG, "Target preview is disabled, please change the configuration and try again.")
            return
        }
        
        // TODO: - Get client code from state once state is merged in.
        let clientCode = ""
        guard let deeplinkUrl = URL(string: deeplink) else {
            Log.error(label: LOG_TAG, "Deeplink is not a valid url")
            return
        }
        
        Target.previewManager.enterPreviewModeWithDeepLink(clientCode: clientCode, deepLink: deeplinkUrl)
    }

    // MARK: - Helpers
    private var isInPreviewMode: Bool {
        get {
            guard let previewParameters = Target.previewManager.previewParameters, !previewParameters.isEmpty else {
                return false
            }
            return true
        }
    }

    private func prepareForTargetRequest(configSharedState: [String: Any]) -> Bool {
        guard let clientCode = configSharedState[TargetConstants.EventDataKeys.Configuration.TARGET_CLIENT_CODE] as? String, !clientCode.isEmpty else {
            Log.warning(label: LOG_TAG, "Target request preparation failed, client code was empty")
            return false
        }

        // TODO: logic in here. Yansong is adding to his PR
        return true
    }
}
