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
    static let LOG_TAG = "Target"

    private var DEFAULT_NETWORK_TIMEOUT: TimeInterval = 2.0

    private let targetState: TargetState

    private var networkService: Networking {
        return ServiceProvider.shared.networkService
    }

    // MARK: - Extension

    public var name = TargetConstants.EXTENSION_NAME

    public var friendlyName = TargetConstants.FRIENDLY_NAME

    public static var extensionVersion = TargetConstants.EXTENSION_VERSION

    public var metadata: [String: String]?

    public var runtime: ExtensionRuntime

    public required init?(runtime: ExtensionRuntime) {
        self.runtime = runtime
        targetState = TargetState()
        super.init()
    }

    public func onRegistered() {
        registerListener(type: EventType.target, source: EventSource.requestContent) { event in
            if event.isPrefetchEvent {
                self.prefetchContent(event)
                return
            }
            Log.debug(label: Target.LOG_TAG, "Unknown event: \(event)")
        }
        registerListener(type: EventType.target, source: EventSource.requestReset, listener: handle)
        registerListener(type: EventType.target, source: EventSource.requestIdentity, listener: handle)
        registerListener(type: EventType.configuration, source: EventSource.responseContent, listener: handle)
        registerListener(type: EventType.genericData, source: EventSource.os, listener: handle)
    }

    public func onUnregistered() {}

    public func readyForEvent(_ event: Event) -> Bool {
        guard let configuration = getSharedState(extensionName: TargetConstants.Configuration.EXTENSION_NAME, event: event), configuration.status == .set else { return false }
        guard let clientCode = configuration.value?[TargetConstants.Configuration.SharedState.Keys.TARGET_CLIENT_CODE] as? String, !clientCode.isEmpty else {
            return false
        }
        return true
    }

    // MARK: - Event Listeners

    private func handle(event _: Event) {}

    /// Handle prefetch content request
    /// - Parameter event: an event of type target and  source request content is dispatched by the `EventHub`
    private func prefetchContent(_ event: Event) {
        if isInPreviewMode() {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Target prefetch can't be used while in preview mode")
            return
        }

        guard let targetPrefetchArray = event.prefetchObjectArray else {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Empty or null prefetch requests list")
            return
        }

        let targetParameters = event.targetParameters

        guard let configurationSharedState = getSharedState(extensionName: TargetConstants.Configuration.EXTENSION_NAME, event: event)?.value else {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Missing shared state - configuration")
            return
        }

        let lifecycleSharedState = getSharedState(extensionName: TargetConstants.Lifecycle.EXTENSION_NAME, event: event)?.value
        let identitySharedState = getSharedState(extensionName: TargetConstants.Identity.EXTENSION_NAME, event: event)?.value

        guard let privacy = configurationSharedState[TargetConstants.Configuration.SharedState.Keys.GLOBAL_CONFIG_PRIVACY] as? String, privacy == TargetConstants.Configuration.SharedState.Values.GLOBAL_CONFIG_PRIVACY_OPT_IN else {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Privacy status is opted out")
            return
        }

        guard let requestJson = DeliveryRequestBuilder.build(tntId: targetState.tntId, thirdPartyId: targetState.thirdPartyId, identitySharedState: identitySharedState, lifecycleSharedState: lifecycleSharedState, targetPrefetchArray: targetPrefetchArray, targetParameters: targetParameters)?.toJSON() else {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Failed to generate request parameter(JSON) for target delivery API call")
            return
        }
        let headers = [TargetConstants.HEADER_CONTENT_TYPE: TargetConstants.HEADER_CONTENT_TYPE_JSON]

        let targetServer = configurationSharedState[TargetConstants.Configuration.SharedState.Keys.TARGET_SERVER] as? String
        guard let clientCode = configurationSharedState[TargetConstants.Configuration.SharedState.Keys.TARGET_CLIENT_CODE] as? String else {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Missing client code")
            return
        }

        guard let url = URL(string: generateTargetDeliveryURL(targetServer: targetServer, clientCode: clientCode)) else {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Failed to generate the url for target API call")
            return
        }
        // https://developers.adobetarget.com/api/delivery-api/#tag/Delivery-API
        let request = NetworkRequest(url: url, httpMethod: .post, connectPayload: requestJson, httpHeaders: headers, connectTimeout: DEFAULT_NETWORK_TIMEOUT, readTimeout: DEFAULT_NETWORK_TIMEOUT)
        stopEvents()
        networkService.connectAsync(networkRequest: request) { connection in
            guard let data = connection.data, let responseDict = try? JSONDecoder().decode([String: AnyCodable].self, from: data), let dict: [String: Any] = AnyCodable.toAnyDictionary(dictionary: responseDict) else {
                self.dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Target response parser initialization failed")
                return
            }
            let response = DeliveryResponse(responseJson: dict)

            if connection.responseCode != 200, let error = response.errorMessage {
                self.dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Errors returned in Target response: \(error)")
            }

            self.targetState.updateSessionTimestamp()

            if let tntId = response.tntId { self.targetState.updateTntId(tntId) }
            if let edgeHost = response.edgeHost { self.targetState.updateEdgeHost(edgeHost) }
            self.createSharedState(data: self.targetState.generateSharedState(), event: nil)

            if let mboxes = response.mboxes {
                var mboxesDictionary = [String: [String: Any]]()
                for mbox in mboxes {
                    if let name = mbox[TargetResponseConstants.JSONKeys.MBOX_NAME] as? String { mboxesDictionary[name] = mbox }
                }
                if !mboxesDictionary.isEmpty { self.targetState.mergePrefetchedMboxJson(mboxesDictionary: mboxesDictionary) }
            }

            self.dispatch(event: event.createResponseEvent(name: TargetConstants.EventName.PREFETCH_RESPOND, type: EventType.target, source: EventSource.responseContent, data: nil))
            // TODO: removeDuplicateLoadedMboxes
            // TODO: notifications.clear()
            self.startEvents()
        }
    }

    // MARK: - Helpers

    private func dispatchPrefetchErrorEvent(triggerEvent: Event, errorMessage: String) {
        Log.warning(label: Target.LOG_TAG, "dispatch prefetch error event")
        dispatch(event: triggerEvent.createResponseEvent(name: TargetConstants.EventName.PREFETCH_RESPOND, type: EventType.target, source: EventSource.responseContent, data: [TargetConstants.EventDataKeys.PREFETCH_ERROR: errorMessage]))
    }

    private func generateTargetDeliveryURL(targetServer: String?, clientCode: String) -> String {
        if let targetServer = targetServer {
            return String(format: TargetConstants.DELIVERY_API_URL_BASE, targetServer, clientCode, targetState.sessionId)
        }

        if let host = targetState.edgeHost {
            return String(format: TargetConstants.DELIVERY_API_URL_BASE, host, clientCode, targetState.sessionId)
        }

        return String(format: TargetConstants.DELIVERY_API_URL_BASE, String(format: TargetConstants.API_URL_HOST_BASE, clientCode), clientCode, targetState.sessionId)
    }

    private func isInPreviewMode() -> Bool {
        // TODO:
        return false
    }
}
