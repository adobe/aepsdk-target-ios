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
import AEPIdentity
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
        registerListener(type: EventType.target, source: EventSource.requestContent, listener: handleRequestContent)
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

    private func handle(_ event: Event) {
        print(event)
    }

    private func handleRequestContent(_ event: Event) {
        if event.isPrefetchEvent {
            prefetchContent(event)
            return
        }

        if event.isLocationDisplayedEvent {
            locationDisplayed(event)
            return
        }

        Log.debug(label: Target.LOG_TAG, "Unknown event: \(event)")
    }

    /// Sends display notifications to Target
    /// Reads the display tokens from the cache either {@link #prefetchedMbox} or {@link #loadedMbox} to send the display notifications.
    /// The display notification is not sent if,
    /// - Target Extension is not configured.
    /// - Privacy status is opted-out or opt-unknown.
    /// - If the mboxes are either loaded previously or not prefetched.
    private func locationDisplayed(_ event: Event) {
        guard let eventData = event.data as [String: Any]? else {
            Log.error(label: Target.LOG_TAG, "Unable to handle request content, event data is null.")
            return
        }

        guard let mBoxNames: [String] = eventData[TargetConstants.EventDataKeys.MBOX_NAMES] as? [String] else {
            Log.error(label: Target.LOG_TAG, "Location displayed unsuccessful \(TargetError.ERROR_MBOX_NAMES_NULL_OR_EMPTY)")
            return
        }

        Log.trace(label: Target.LOG_TAG, "Handling Locations Displayed - event \(event.name) type: \(event.type) source: \(event.source) ")

        // Get the configuration shared state
        guard let configuration = getSharedState(extensionName: TargetConstants.Configuration.EXTENSION_NAME, event: event)?.value else {
            Log.error(label: Target.LOG_TAG, "Location displayed unsuccessful, configuration is null")
            return
        }

        // Check whether request can be sent
        if let error = prepareForTargetRequest(configData: configuration) {
            Log.error(label: Target.LOG_TAG, TargetError.ERROR_DISPLAY_NOTIFICATION_SEND_FAILED + error)
            return
        }

        let lifecycleSharedState = getSharedState(extensionName: TargetConstants.Lifecycle.EXTENSION_NAME, event: event)?.value
        let identitySharedState = getSharedState(extensionName: TargetConstants.Identity.EXTENSION_NAME, event: event)?.value

        for mBoxName: String in mBoxNames {
            // If loadedMbox contains mboxName then do not send analytics request again
            if mBoxName.isEmpty || targetState.loadedMboxJsonDicts[mBoxName] != nil {
                continue
            }

            guard let mBoxJson: [String: Any] = targetState.prefetchedMboxJsonDicts[mBoxName] else {
                Log.error(label: Target.LOG_TAG, "\(TargetError.ERROR_NO_CACHED_MBOX_FOUND) \(mBoxName) For more details refer to https://aep-sdks.gitbook.io/docs/using-mobile-extensions/adobe-target/target-api-reference#send-an-mbox-display-notification")
                continue
            }

            if !addDisplayNotification(mBoxName: mBoxName, mBoxJson: mBoxJson, targetParameters: event.targetParameters, lifecycleData: lifecycleSharedState, timestamp: UInt64(event.timestamp.timeIntervalSince1970)) {
                Log.debug(label: Target.LOG_TAG, "handleLocationsDisplayed - \(mBoxName) mBox not added for display notification. For more details refer to https://aep-sdks.gitbook.io/docs/using-mobile-extensions/adobe-target/target-api-reference#send-an-mbox-display-notification")
                continue
            }

            // - TODO: dispatchAnalyticsForTargetRequest

            if targetState.notifications.isEmpty {
                Log.debug(label: Target.LOG_TAG, "locationDisplayed - \(TargetError.ERROR_DISPLAY_NOTIFICATION_NOT_SENT)")
                return
            }

            sendTargetRequest(event, targetParameters: event.targetParameters, configData: configuration, lifecycleData: lifecycleSharedState, identityData: identitySharedState, propertyToken: nil) { connection in
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
            }
        }
    }

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

        sendTargetRequest(event, prefetchRequests: targetPrefetchArray, targetParameters: targetParameters, configData: configurationSharedState, lifecycleData: lifecycleSharedState, identityData: identitySharedState) { connection in

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
            self.createSharedState(data: self.targetState.generateSharedState(), event: event)

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

        if let host = targetState.edgeHost, !host.isEmpty {
            return String(format: TargetConstants.DELIVERY_API_URL_BASE, host, clientCode, targetState.sessionId)
        }

        return String(format: TargetConstants.DELIVERY_API_URL_BASE, String(format: TargetConstants.API_URL_HOST_BASE, clientCode), clientCode, targetState.sessionId)
    }

    private func isInPreviewMode() -> Bool {
        // TODO:
        return false
    }

    /// Prepares for the target requests and checks whether a target request can be sent.
    /// - parameters: configData the shared state of configuration extension
    /// - returns: error indicating why the request can't be sent, nil otherwise
    private func prepareForTargetRequest(configData: [String: Any]) -> String? {
        guard let newClientCode = configData[TargetConstants.Configuration.SharedState.Keys.TARGET_CLIENT_CODE] as? String, !newClientCode.isEmpty else {
            Log.error(label: Target.LOG_TAG, "Location displayed unsuccessful, \(TargetError.ERROR_NO_CLIENT_CODE)")
            return TargetError.ERROR_NO_CLIENT_CODE
        }

        if newClientCode != targetState.clientCode {
            targetState.updateClientCode(newClientCode)
            targetState.updateEdgeHost("")
        }

        guard let privacy = configData[TargetConstants.Configuration.SharedState.Keys.GLOBAL_CONFIG_PRIVACY] as? String, privacy == TargetConstants.Configuration.SharedState.Values.GLOBAL_CONFIG_PRIVACY_OPT_IN
        else {
            Log.error(label: Target.LOG_TAG, "Location displayed unsuccessful, \(TargetError.ERROR_OPTED_OUT)")
            return TargetError.ERROR_OPTED_OUT
        }

        return nil
    }

    /// Adds the display notification for the given mbox to the {@link #notifications} list
    private func addDisplayNotification(mBoxName: String, mBoxJson: [String: Any], targetParameters: TargetParameters?, lifecycleData: [String: Any]?, timestamp: UInt64) -> Bool {
        let lifecycleContextData = getLifecycleDataForTarget(lifecycleData: lifecycleData)
        guard let displayNotification = TargetRequestBuilder.getDisplayNotification(mboxName: mBoxName, cachedMboxJson: mBoxJson, parameters: targetParameters, timestamp: timestamp, lifecycleContextData: lifecycleContextData) as Notification? else {
            Log.debug(label: Target.LOG_TAG, "addDisplayNotification - \(TargetError.ERROR_DISPLAY_NOTIFICATION_NULL_FOR_MBOX), \(mBoxName)")
            return false
        }

        targetState.addNotification(notification: displayNotification)
        return true
    }

    /// Converts data from a lifecycle event into its form desired by Target.
    private func getLifecycleDataForTarget(lifecycleData: [String: Any]?) -> [String: String]? {
        guard var tempLifecycleContextData: [String: Any] = lifecycleData else {
            return nil
        }
        var lifecycleContextData: [String: String] = [:]

        for (k, v) in TargetConstants.MAP_TO_CONTEXT_DATA_KEYS {
            if let value = tempLifecycleContextData[k] as? String, !value.isEmpty {
                lifecycleContextData[v] = value
                tempLifecycleContextData.removeValue(forKey: k)
            }
        }

        for (k1, v1) in tempLifecycleContextData {
            if let v1Value = v1 as? String {
                lifecycleContextData.updateValue(v1Value, forKey: k1)
            }
        }

        return lifecycleContextData
    }

    private func sendTargetRequest(_ event: Event,
                                   batchRequests _: [TargetRequest]? = nil,
                                   prefetchRequests: [TargetPrefetch]? = nil,
                                   targetParameters: TargetParameters? = nil,
                                   configData: [String: Any],
                                   lifecycleData: [String: Any]? = nil,
                                   identityData: [String: Any]? = nil,
                                   propertyToken: String? = nil,
                                   completionHandler: ((HttpConnection) -> Void)?)
    {
        let tntId = targetState.tntId
        let thirdPartyId = targetState.thirdPartyId
        let environmentId: Int64 = configData[TargetConstants.Configuration.SharedState.Keys.TARGET_ENVIRONMENT_ID] as? Int64 ?? 0
        let tempLifecycleContextData: [String: String]? = lifecycleData?[TargetConstants.Lifecycle.Keys.LIFECYCLE_CONTEXT_DATA] as? [String: String] ?? nil
        let lifecycleContextData = getLifecycleDataForTarget(lifecycleData: tempLifecycleContextData)
        let propToken = propertyToken != nil ? propertyToken : (configData[TargetConstants.Configuration.SharedState.Keys.TARGET_PROPERTY_TOKEN] as? String ?? "")

        guard let requestJson = TargetRequestBuilder.build(tntId: tntId, thirdPartyId: thirdPartyId, identitySharedState: identityData, lifecycleSharedState: lifecycleContextData, targetPrefetchArray: prefetchRequests, targetParameters: targetParameters, notifications: targetState.notifications, environmentId: environmentId, propertyToken: propToken)?.toJSON() else {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Failed to generate request parameter(JSON) for target delivery API call")
            return
        }

        let headers = [TargetConstants.HEADER_CONTENT_TYPE: TargetConstants.HEADER_CONTENT_TYPE_JSON]

        let targetServer = configData[TargetConstants.Configuration.SharedState.Keys.TARGET_SERVER] as? String
        guard let clientCode = configData[TargetConstants.Configuration.SharedState.Keys.TARGET_CLIENT_CODE] as? String else {
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
        networkService.connectAsync(networkRequest: request, completionHandler: completionHandler)
    }

    private func updateStateWithDeliveryResponse(event: Event, connection: HttpConnection) -> DeliveryResponse? {
        guard let data = connection.data, let responseDict = try? JSONDecoder().decode([String: AnyCodable].self, from: data), let dict: [String: Any] = AnyCodable.toAnyDictionary(dictionary: responseDict) else {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Target response parser initialization failed")
            return nil
        }
        let response = DeliveryResponse(responseJson: dict)

        if connection.responseCode != 200, let error = response.errorMessage {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Errors returned in Target response: \(error)")
        }

        targetState.updateSessionTimestamp()

        if let tntId = response.tntId { targetState.updateTntId(tntId) }
        if let edgeHost = response.edgeHost { targetState.updateEdgeHost(edgeHost) }
        createSharedState(data: targetState.generateSharedState(), event: nil)

        return response
    }
}
