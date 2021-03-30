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

@objc(AEPMobileTarget)
public class Target: NSObject, Extension {
    static let LOG_TAG = "Target"

    private(set) var targetState: TargetState

    private var networkService: Networking {
        return ServiceProvider.shared.networkService
    }

    private var isInPreviewMode: Bool {
        if let previewParameters = previewManager.previewParameters, !previewParameters.isEmpty {
            return true
        }
        return false
    }

    // MARK: - Extension

    public var name = TargetConstants.EXTENSION_NAME

    public var friendlyName = TargetConstants.FRIENDLY_NAME

    public static var extensionVersion = TargetConstants.EXTENSION_VERSION

    public var metadata: [String: String]?

    public var runtime: ExtensionRuntime

    var previewManager: PreviewManager = TargetPreviewManager()

    public required init?(runtime: ExtensionRuntime) {
        self.runtime = runtime
        TargetV5Migrator.migrate()
        targetState = TargetState()
        super.init()
    }

    public func onRegistered() {
        registerListener(type: EventType.target, source: EventSource.requestContent, listener: handleRequestContent)
        registerListener(type: EventType.target, source: EventSource.requestReset, listener: handleReset)
        registerListener(type: EventType.target, source: EventSource.requestIdentity, listener: handleRequestIdentity)
        registerListener(type: EventType.configuration, source: EventSource.responseContent, listener: handleConfigurationResponseContent)
        registerListener(type: EventType.genericData, source: EventSource.os, listener: handleGenericDataOS)
    }

    public func onUnregistered() {}

    public func readyForEvent(_ event: Event) -> Bool {
        targetState.updateConfigurationSharedState(retrieveLatestConfiguration(event))
        return targetState.storedConfigurationSharedState != nil
    }

    // MARK: - Event Listeners

    private func handle(event _: Event) {}

    private func handleGenericDataOS(event: Event) {
        if let deeplink = event.data?[TargetConstants.EventDataKeys.DEEPLINK] as? String, !deeplink.isEmpty {
            processPreviewDeepLink(event: event, deeplink: deeplink)
        }
    }

    private func handleRequestIdentity(_ event: Event) {
        if let eventData = event.data, let thirdPartyId = eventData[TargetConstants.EventDataKeys.THIRD_PARTY_ID] as? String {
            setThirdPartyId(thirdPartyId: thirdPartyId, event: event)
        } else {
            dispatchRequestIdentityResponse(triggerEvent: event)
        }
    }

    private func handleConfigurationResponseContent(_ event: Event) {
        if targetState.privacyStatusIsOptOut {
            resetIdentity()
            createSharedState(data: targetState.generateSharedState(), event: event)
            return
        }
    }

    private func handleReset(_ event: Event) {
        if event.isResetExperienceEvent {
            resetIdentity()
            createSharedState(data: targetState.generateSharedState(), event: event)
        }
        if event.isClearPrefetchCache {
            targetState.clearprefetchedMboxes()
        }
    }

    private func handleRequestContent(_ event: Event) {
        if event.isPrefetchEvent {
            prefetchContent(event)
            return
        }

        if event.isLoadRequest {
            loadRequest(event)
            return
        }

        if event.isLocationsDisplayedEvent {
            displayedLocations(event)
            return
        }

        if event.isLocationClickedEvent {
            clickedLocation(event)
            return
        }

        if let restartDeeplink = event.data?[TargetConstants.EventDataKeys.PREVIEW_RESTART_DEEP_LINK] as? String {
            previewManager.setRestartDeepLink(restartDeeplink)
        }

        Log.debug(label: Target.LOG_TAG, "Unknown event: \(event)")
    }

    // MARK: - Event Handlers

    private func processPreviewDeepLink(event: Event, deeplink: String) {
        guard let configSharedState = getSharedState(extensionName: TargetConstants.Configuration.EXTENSION_NAME, event: event)?.value else {
            Log.warning(label: Target.LOG_TAG, "Target process preview deep link failed, config data is nil")
            return
        }

        if let error = prepareForTargetRequest() {
            Log.error(label: Target.LOG_TAG, "Target is not enabled, cannot enter in preview mode. \(error)")
            return
        }

        guard let isPreviewEnabled = configSharedState[TargetConstants.Configuration.SharedState.Keys.TARGET_PREVIEW_ENABLED] as? Bool, isPreviewEnabled else {
            Log.error(label: Target.LOG_TAG, "Target preview is disabled, please change the configuration and try again.")
            return
        }

        let clientCode = targetState.clientCode ?? ""
        guard let deeplinkUrl = URL(string: deeplink) else {
            Log.error(label: Target.LOG_TAG, "Deeplink is not a valid url")
            return
        }

        previewManager.enterPreviewModeWithDeepLink(clientCode: clientCode, deepLink: deeplinkUrl)
    }

    private func getDeliveryResponse(_ data: Data?) -> TargetDeliveryResponse? {
        guard let data = data, let responseDict = try? JSONDecoder().decode([String: AnyCodable].self, from: data), let dict = AnyCodable.toAnyDictionary(dictionary: responseDict) else {
            return nil
        }
        return TargetDeliveryResponse(responseJson: dict)
    }

    /// Handle prefetch content request
    /// - Parameter event: an event of type target and  source request content is dispatched by the `EventHub`
    private func prefetchContent(_ event: Event) {
        if isInPreviewMode {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Target prefetch can't be used while in preview mode")
            return
        }

        guard let targetPrefetchArray = event.prefetchObjectArray else {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Empty or nil prefetch requests list")
            return
        }

        // Check whether request can be sent
        if let error = prepareForTargetRequest() {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: error)
            return
        }

        let lifecycleSharedState = getSharedState(extensionName: TargetConstants.Lifecycle.EXTENSION_NAME, event: event)?.value
        let identitySharedState = getSharedState(extensionName: TargetConstants.Identity.EXTENSION_NAME, event: event)?.value

        let error = sendTargetRequest(event,
                                      prefetchRequests: targetPrefetchArray,
                                      targetParameters: event.targetParameters,
                                      lifecycleData: lifecycleSharedState,
                                      identityData: identitySharedState) { connection in
            // Clear notification
            self.targetState.clearNotifications()

            let response = self.getDeliveryResponse(connection.data)

            guard connection.responseCode == 200 else {
                self.dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Errors returned in Target response with response code: \(String(describing: connection.responseCode)), error message : \(String(describing: response?.errorMessage))")
                return
            }

            guard let deliveryResponse = response else {
                self.dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Target response parser initialization failed")
                return
            }
            if let tntId = deliveryResponse.tntId { self.setTntId(tntId: tntId) }
            if let edgeHost = deliveryResponse.edgeHost { self.targetState.updateEdgeHost(edgeHost) }
            self.createSharedState(data: self.targetState.generateSharedState(), event: event)

            if let mboxes = deliveryResponse.prefetchMboxes {
                var mboxesDictionary = [String: [String: Any]]()
                for mbox in mboxes {
                    if let name = mbox[TargetResponseConstants.JSONKeys.MBOX_NAME] as? String { mboxesDictionary[name] = mbox }
                }
                if !mboxesDictionary.isEmpty { self.targetState.mergePrefetchedMboxJson(mboxesDictionary: mboxesDictionary) }
            }

            // Remove duplicate loaded mboxes
            for (k, _) in self.targetState.prefetchedMboxJsonDicts {
                self.targetState.removeLoadedMbox(mboxName: k)
            }

            self.dispatch(event: event.createResponseEvent(name: TargetConstants.EventName.PREFETCH_RESPOND, type: EventType.target, source: EventSource.responseContent, data: nil))
        }

        if let err = error {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: err)
        }
    }

    /// Request multiple Target mboxes in a single network call.
    /// - Parameter event: an event of type target and  source request content is dispatched by the `EventHub`
    private func loadRequest(_ event: Event) {
        guard let targetRequests = event.targetRequests else {
            Log.debug(label: Target.LOG_TAG, "Unable to process the batch requests, Target Batch Requests are null")
            return
        }

        let targetParameters = event.targetParameters

        let lifecycleSharedState = getSharedState(extensionName: TargetConstants.Lifecycle.EXTENSION_NAME, event: event)?.value
        let identitySharedState = getSharedState(extensionName: TargetConstants.Identity.EXTENSION_NAME, event: event)?.value

        // Check whether request can be sent
        if let error = prepareForTargetRequest() {
            Log.debug(label: Target.LOG_TAG, "\(TargetError.ERROR_BATCH_REQUEST_SEND_FAILED) \(error)")
            runDefaultCallbacks(event: event, batchRequests: targetRequests)
            return
        }

        var requestsToSend: [TargetRequest] = targetRequests

        let timestamp = Int64(event.timestamp.timeIntervalSince1970 * 1000.0)

        if !isInPreviewMode {
            Log.debug(label: Target.LOG_TAG, "Current cached mboxes : \(targetState.prefetchedMboxJsonDicts.keys.description), size: \(targetState.prefetchedMboxJsonDicts.count)")
            requestsToSend = processCachedTargetRequest(event: event, batchRequests: targetRequests, timeStamp: timestamp)
        }

        if requestsToSend.isEmpty && targetState.notifications.isEmpty {
            Log.warning(label: Target.LOG_TAG, "Unable to process the batch requests, requests and notifications are empty")
            return
        }

        let error = sendTargetRequest(event,
                                      batchRequests: requestsToSend,
                                      targetParameters: targetParameters,
                                      lifecycleData: lifecycleSharedState,
                                      identityData: identitySharedState) { connection in
            self.processTargetRequestResponse(batchRequests: requestsToSend, event: event, connection: connection)
        }

        if let err = error {
            Log.warning(label: Target.LOG_TAG, err)
        }
    }

    /// Sends display notifications to Target
    /// Reads the display tokens from the cache either {@link #prefetchedMbox} or {@link #loadedMbox} to send the display notifications.
    /// The display notification is not sent if,
    /// - Target Extension is not configured.
    /// - Privacy status is opted-out or opt-unknown.
    /// - If the mboxes are either loaded previously or not prefetched.
    private func displayedLocations(_ event: Event) {
        guard let eventData = event.data else {
            Log.warning(label: Target.LOG_TAG, "Unable to handle request content, event data is nil.")
            return
        }

        Log.trace(label: Target.LOG_TAG, "Handling Locations Displayed - event \(event.name) type: \(event.type) source: \(event.source) ")

        // Check whether request can be sent
        if let error = prepareForTargetRequest() {
            Log.warning(label: Target.LOG_TAG, TargetError.ERROR_DISPLAY_NOTIFICATION_SEND_FAILED + error)
            return
        }

        let lifecycleSharedState = getSharedState(extensionName: TargetConstants.Lifecycle.EXTENSION_NAME, event: event)?.value
        let identitySharedState = getSharedState(extensionName: TargetConstants.Identity.EXTENSION_NAME, event: event)?.value

        guard let mboxNames = eventData[TargetConstants.EventDataKeys.MBOX_NAMES] as? [String], !mboxNames.isEmpty else {
            Log.warning(label: Target.LOG_TAG, "Location displayed unsuccessful \(TargetError.ERROR_MBOX_NAMES_NULL_OR_EMPTY)")
            return
        }

        for mboxName in mboxNames {
            // If loadedMbox contains mboxName then do not send analytics request again
            if mboxName.isEmpty || targetState.loadedMboxJsonDicts[mboxName] != nil {
                continue
            }

            guard let mboxJson = targetState.prefetchedMboxJsonDicts[mboxName] else {
                Log.warning(label: Target.LOG_TAG, "\(TargetError.ERROR_NO_CACHED_MBOX_FOUND) \(mboxName).")
                continue
            }

            let timeInMills = Int64(event.timestamp.timeIntervalSince1970 * 1000.0)

            if !addDisplayNotification(mboxName: mboxName, mboxJson: mboxJson, targetParameters: event.targetParameters, lifecycleData: lifecycleSharedState, timestamp: timeInMills) {
                Log.debug(label: Target.LOG_TAG, "displayedLocations - \(mboxName) mbox not added for display notification.")
                continue
            }

            dispatchAnalyticsForTargetRequest(payload: getAnalyticsForTargetPayload(mboxJson: mboxJson, sessionId: targetState.sessionId))
        }

        if targetState.notifications.isEmpty {
            Log.debug(label: Target.LOG_TAG, "displayedLocations - \(TargetError.ERROR_DISPLAY_NOTIFICATION_NOT_SENT)")
            return
        }

        let error = sendTargetRequest(event, targetParameters: event.targetParameters, lifecycleData: lifecycleSharedState, identityData: identitySharedState) { connection in
            self.processNotificationResponse(event: event, connection: connection)
        }

        if let err = error {
            Log.warning(label: Target.LOG_TAG, err)
        }
    }

    /// Sends a click notification to Target if click metrics are enabled for the provided location name.
    /// Reads the clicked token from the cached either {@link #prefetchedMbox} or {@link #loadedMbox} to send the click notification. The clicked notification is not sent if,
    /// The click notification is not sent if,
    /// - Target Extension is not configured.
    /// - Privacy status is opted-out or opt-unknown.
    /// - If the mbox is either not prefetched or loaded previously.
    /// - If the clicked token is empty or nil for the loaded mbox.
    private func clickedLocation(_ event: Event) {
        if isInPreviewMode {
            Log.warning(label: Target.LOG_TAG, "Target location clicked notification can't be sent while in preview mode")
            return
        }

        guard let eventData = event.data else {
            Log.warning(label: Target.LOG_TAG, "Unable to handle request content, event data is nil.")
            return
        }

        guard let mboxName = eventData[TargetConstants.EventDataKeys.MBOX_NAME] as? String else {
            Log.warning(label: Target.LOG_TAG, "Location clicked unsuccessful \(TargetError.ERROR_MBOX_NAME_NULL_OR_EMPTY)")
            return
        }

        Log.trace(label: Target.LOG_TAG, "Handling Location Clicked - event \(event.name) type: \(event.type) source: \(event.source) ")

        // Check if the mbox is already prefetched or loaded.
        // if not, Log and bail out

        guard let mboxJson = targetState.prefetchedMboxJsonDicts[mboxName] ?? targetState.loadedMboxJsonDicts[mboxName] else {
            Log.warning(label: Target.LOG_TAG, "\(TargetError.ERROR_CLICK_NOTIFICATION_SEND_FAILED) \(TargetError.ERROR_NO_CACHED_MBOX_FOUND) \(mboxName).")
            return
        }

        guard let metrics = mboxJson[TargetConstants.TargetJson.METRICS] as? [[String: Any?]?] else {
            Log.warning(label: Target.LOG_TAG, "\(TargetError.ERROR_CLICK_NOTIFICATION_SEND_FAILED) \(TargetError.ERROR_NO_CLICK_METRICS) \(mboxName).")
            return
        }

        var clickMetricFound = false

        for metricItem in metrics {
            guard let metric = metricItem, TargetConstants.TargetJson.MetricType.CLICK == metric[TargetConstants.TargetJson.Metric.TYPE] as? String, let token = metric[TargetConstants.TargetJson.Metric.EVENT_TOKEN] as? String, !token.isEmpty else {
                continue
            }

            clickMetricFound = true
            break
        }

        if !clickMetricFound {
            Log.warning(label: Target.LOG_TAG, "\(TargetError.ERROR_CLICK_NOTIFICATION_SEND_FAILED) \(TargetError.ERROR_NO_CLICK_METRIC_FOUND) \(mboxName).")
            return
        }

        // bail out if the target configuration is not available or if the privacy is opted-out
        if let error = prepareForTargetRequest() {
            Log.warning(label: Target.LOG_TAG, TargetError.ERROR_CLICK_NOTIFICATION_NOT_SENT + error)
            return
        }

        let lifecycleSharedState = getSharedState(extensionName: TargetConstants.Lifecycle.EXTENSION_NAME, event: event)?.value
        let identitySharedState = getSharedState(extensionName: TargetConstants.Identity.EXTENSION_NAME, event: event)?.value

        let timeInMills = Int64(event.timestamp.timeIntervalSince1970 * 1000.0)

        // create and add click notification to the notification list
        if !addClickedNotification(mboxJson: mboxJson, targetParameters: event.targetParameters, lifecycleData: lifecycleSharedState, timestamp: timeInMills) {
            Log.debug(label: Target.LOG_TAG, "handleLocationClicked - \(mboxName) mbox not added for click notification.")
            return
        }

        let error = sendTargetRequest(event, targetParameters: event.targetParameters, lifecycleData: lifecycleSharedState, identityData: identitySharedState) { connection in
            self.processNotificationResponse(event: event, connection: connection)
        }

        if let err = error {
            Log.warning(label: Target.LOG_TAG, err)
        }
    }

    // MARK: - Helpers

    /// Process the network response after the notification network call.
    /// - Parameters:
    ///     - event: event which triggered this network call
    ///     - connection: `NetworkService.HttpConnection` instance
    private func processNotificationResponse(event: Event, connection: HttpConnection) {
        if connection.responseCode == 200 {
            targetState.clearNotifications()
        }

        guard let data = connection.data, let responseDict = try? JSONDecoder().decode([String: AnyCodable].self, from: data), let dict: [String: Any] = AnyCodable.toAnyDictionary(dictionary: responseDict) else {
            Log.debug(label: Target.LOG_TAG, "Target response parser initialization failed")
            return
        }
        let response = TargetDeliveryResponse(responseJson: dict)

        if let error = response.errorMessage {
            if error.contains(TargetError.ERROR_NOTIFICATION_TAG) {
                targetState.clearNotifications()
            }

            Log.debug(label: Target.LOG_TAG, "Errors returned in Target response: \(error)")
            return
        }

        if connection.responseCode != 200 {
            Log.debug(label: Target.LOG_TAG, "Errors returned in Target response with response code: \(String(describing: connection.responseCode))")
        }

        if let tntId = response.tntId { setTntId(tntId: tntId) }
        if let edgeHost = response.edgeHost { targetState.updateEdgeHost(edgeHost) }
        createSharedState(data: targetState.generateSharedState(), event: event)
    }

    /// Process the network response after the notification network call.
    /// - Parameters:
    ///     - batchRequests: `[TargetRequest]` representing the desired mboxes to load
    ///     - event: event which triggered this network call
    ///     - connection: `NetworkService.HttpConnection` instance
    private func processTargetRequestResponse(batchRequests: [TargetRequest], event: Event, connection: HttpConnection) {
        if connection.responseCode == 200 {
            targetState.clearNotifications()
        }

        guard let data = connection.data, let responseDict = try? JSONDecoder().decode([String: AnyCodable].self, from: data), let dict = AnyCodable.toAnyDictionary(dictionary: responseDict) else {
            Log.debug(label: Target.LOG_TAG, "Target response parser initialization failed")
            runDefaultCallbacks(event: event, batchRequests: batchRequests)
            return
        }

        let response = TargetDeliveryResponse(responseJson: dict)

        if let error = response.errorMessage {
            if error.contains(TargetError.ERROR_NOTIFICATION_TAG) {
                targetState.clearNotifications()
            }
            Log.debug(label: Target.LOG_TAG, "Errors returned in Target request response: \(error)")
            runDefaultCallbacks(event: event, batchRequests: batchRequests)
            return
        }

        if connection.responseCode != 200 {
            Log.debug(label: Target.LOG_TAG, "Errors returned in Target response with response code: \(String(describing: connection.responseCode))")
            runDefaultCallbacks(event: event, batchRequests: batchRequests)
            return
        }

        if let tntId = response.tntId { targetState.updateTntId(tntId) }
        if let edgeHost = response.edgeHost { targetState.updateEdgeHost(edgeHost) }
        createSharedState(data: targetState.generateSharedState(), event: nil)

        var mboxesDictionary = [String: [String: Any]]()
        if let mboxes = response.executeMboxes {
            for mbox in mboxes {
                if let name = mbox[TargetResponseConstants.JSONKeys.MBOX_NAME] as? String { mboxesDictionary[name] = mbox }
            }
            if !mboxesDictionary.isEmpty {
                // save the loaded mboxes from target response to be used later on for notifications
                targetState.saveLoadedMbox(mboxesDictionary: mboxesDictionary)
            }
        } else {
            runDefaultCallbacks(event: event, batchRequests: batchRequests)
            return
        }

        for targetRequest in batchRequests {
            var content = ""
            if let mboxJson = mboxesDictionary[targetRequest.name] {
                content = extractMboxContent(mboxJson: mboxJson) ?? targetRequest.defaultContent
                let payload = getAnalyticsForTargetPayload(mboxJson: mboxJson, sessionId: targetState.sessionId)
                dispatchAnalyticsForTargetRequest(payload: payload)
            }
            dispatchMboxContent(event: event, content: content, responsePairId: targetRequest.responsePairId)
        }
    }

    private func dispatchPrefetchErrorEvent(triggerEvent: Event, errorMessage: String) {
        Log.warning(label: Target.LOG_TAG, "dispatch prefetch error event, error message : \(errorMessage)")
        dispatch(event: triggerEvent.createResponseEvent(name: TargetConstants.EventName.PREFETCH_RESPOND, type: EventType.target, source: EventSource.responseContent, data: [TargetConstants.EventDataKeys.PREFETCH_ERROR: errorMessage]))
    }

    private func dispatchRequestIdentityResponse(triggerEvent: Event) {
        var eventData: [String: Any] = [:]
        if let thirdPartyId = targetState.thirdPartyId {
            eventData[TargetConstants.EventDataKeys.THIRD_PARTY_ID] = thirdPartyId
        }
        if let tntId = targetState.tntId {
            eventData[TargetConstants.EventDataKeys.TNT_ID] = tntId
        }
        dispatch(event: triggerEvent.createResponseEvent(name: TargetConstants.EventName.IDENTITY_RESPONSE, type: EventType.target, source: EventSource.responseIdentity, data: eventData))
    }

    private func getTargetDeliveryURL(targetServer: String?, clientCode: String) -> String {
        if let targetServer = targetServer, !targetServer.isEmpty {
            return String(format: TargetConstants.DELIVERY_API_URL_BASE, targetServer, clientCode, targetState.sessionId)
        }

        if let host = targetState.edgeHost, !host.isEmpty {
            return String(format: TargetConstants.DELIVERY_API_URL_BASE, host, clientCode, targetState.sessionId)
        }

        return String(format: TargetConstants.DELIVERY_API_URL_BASE, String(format: TargetConstants.API_URL_HOST_BASE, clientCode), clientCode, targetState.sessionId)
    }

    /// Prepares for the target requests and checks whether a target request can be sent.
    /// - returns: error indicating why the request can't be sent, nil otherwise
    private func prepareForTargetRequest() -> String? {
        guard let _ = targetState.clientCode else {
            Log.warning(label: Target.LOG_TAG, "Target requests failed because, \(TargetError.ERROR_NO_CLIENT_CODE)")
            return TargetError.ERROR_NO_CLIENT_CODE
        }

        guard targetState.privacyStatusIsOptIn else {
            Log.warning(label: Target.LOG_TAG, "Target requests failed because, \(TargetError.ERROR_NOT_OPTED_IN)")
            return TargetError.ERROR_NOT_OPTED_IN
        }

        return nil
    }

    private func retrieveLatestConfiguration(_ event: Event) -> [String: Any]? {
        return getSharedState(extensionName: TargetConstants.Configuration.EXTENSION_NAME, event: event)?.value
    }

    /// Adds the display notification for the given mbox to the {@link #notifications} list
    /// - Parameters:
    ///     - mboxName: the displayed mbox name
    ///     - mboxJson: the cached `Mbox` object
    ///     - targetParameters: `TargetParameters` object corresponding to the display location
    ///     - lifecycleData: the lifecycle dictionary that should be added as mbox parameters
    ///     - timestamp: timestamp associated with the notification event
    /// - Returns: `Bool` indicating the success of appending the display notification to the notification list
    private func addDisplayNotification(mboxName: String, mboxJson: [String: Any], targetParameters: TargetParameters?, lifecycleData: [String: Any]?, timestamp: Int64) -> Bool {
        let lifecycleContextData = getLifecycleDataForTarget(lifecycleData: lifecycleData)
        guard let displayNotification = TargetDeliveryRequestBuilder.getDisplayNotification(mboxName: mboxName, cachedMboxJson: mboxJson, targetParameters: targetParameters, timestamp: timestamp, lifecycleContextData: lifecycleContextData) else {
            Log.debug(label: Target.LOG_TAG, "addDisplayNotification - \(TargetError.ERROR_DISPLAY_NOTIFICATION_NULL_FOR_MBOX), \(mboxName)")
            return false
        }

        targetState.addNotification(displayNotification)
        return true
    }

    /// Adds the clicked notification for the given mbox to the {@link #notifications} list.
    /// - Parameters:
    ///     - mboxJson: the cached `Mbox` object
    ///     - targetParameters: `TargetParameters` object corresponding to the display location
    ///     - lifecycleData: the lifecycle dictionary that should be added as mbox parameters
    ///     - timestamp: timestamp associated with the notification event
    /// - Returns: `Bool` indicating the success of appending the click notification to the notification list
    private func addClickedNotification(mboxJson: [String: Any?], targetParameters: TargetParameters?, lifecycleData: [String: Any]?, timestamp: Int64) -> Bool {
        let lifecycleContextData = getLifecycleDataForTarget(lifecycleData: lifecycleData)
        guard let clickNotification = TargetDeliveryRequestBuilder.getClickedNotification(cachedMboxJson: mboxJson, targetParameters: targetParameters, timestamp: timestamp, lifecycleContextData: lifecycleContextData) else {
            Log.debug(label: Target.LOG_TAG, "addClickedNotification - \(TargetError.ERROR_CLICK_NOTIFICATION_NOT_SENT)")
            return false
        }
        targetState.addNotification(clickNotification)
        return true
    }

    /// Converts data from a lifecycle event into its form desired by Target.
    private func getLifecycleDataForTarget(lifecycleData: [String: Any]?) -> [String: String]? {
        guard var tempLifecycleContextData = lifecycleData?[TargetConstants.Lifecycle.SharedState.Keys.LIFECYCLE_CONTEXT_DATA] as? [String: String] else {
            return nil
        }

        var lifecycleContextData: [String: String] = [:]

        for (k, v) in TargetConstants.MAP_TO_CONTEXT_DATA_KEYS {
            if let value = tempLifecycleContextData[k], !value.isEmpty {
                lifecycleContextData[v] = value
                tempLifecycleContextData.removeValue(forKey: k)
            }
        }

        for (k1, v1) in tempLifecycleContextData {
            lifecycleContextData.updateValue(v1, forKey: k1)
        }

        return lifecycleContextData
    }

    private func sendTargetRequest(_: Event,
                                   batchRequests: [TargetRequest]? = nil,
                                   prefetchRequests: [TargetPrefetch]? = nil,
                                   targetParameters: TargetParameters? = nil,
                                   lifecycleData: [String: Any]? = nil,
                                   identityData: [String: Any]? = nil,
                                   completionHandler: ((HttpConnection) -> Void)?) -> String?
    {
        let tntId = targetState.tntId
        let thirdPartyId = targetState.thirdPartyId
        let environmentId = Int64(targetState.environmentId)
        let lifecycleContextData = getLifecycleDataForTarget(lifecycleData: lifecycleData)
        let propToken = targetState.propertyToken

        guard let requestJson = TargetDeliveryRequestBuilder.build(tntId: tntId, thirdPartyId: thirdPartyId, identitySharedState: identityData, lifecycleSharedState: lifecycleContextData, targetPrefetchArray: prefetchRequests, targetRequestArray: batchRequests, targetParameters: targetParameters, notifications: targetState.notifications.isEmpty ? nil : targetState.notifications, environmentId: environmentId, propertyToken: propToken)?.toJSON() else {
            return "Failed to generate request parameter(JSON) for target delivery API call"
        }

        let headers = [TargetConstants.HEADER_CONTENT_TYPE: TargetConstants.HEADER_CONTENT_TYPE_JSON]

        guard let clientCode = targetState.clientCode else {
            return "Missing client code"
        }

        guard let url = URL(string: getTargetDeliveryURL(targetServer: targetState.targetServer, clientCode: clientCode)) else {
            return "Failed to generate the url for target API call"
        }

        let timeout = targetState.networkTimeout

        // https://developers.adobetarget.com/api/delivery-api/#tag/Delivery-API
        let request = NetworkRequest(url: url, httpMethod: .post, connectPayload: requestJson, httpHeaders: headers, connectTimeout: timeout, readTimeout: timeout)

        stopEvents()
        networkService.connectAsync(networkRequest: request) { connection in
            self.targetState.updateSessionTimestamp()
            if let completionHandler = completionHandler {
                completionHandler(connection)
            }
            self.startEvents()
        }
        return nil
    }

    /// Clears identities including tntId, thirdPartyId, edgeHost, sessionId
    /// - Parameters:
    ///     - configurationSharedState: `Dictionary` Configuration shared state
    private func resetIdentity() {
        setTntId(tntId: nil)
        setThirdPartyIdInternal(thirdPartyId: nil)
        targetState.updateEdgeHost(nil)
        resetSession()
    }

    /// Saves the third party Id
    /// - Parameters:
    ///     - event: event which has the third party Id in event data
    private func setThirdPartyId(thirdPartyId: String, event: Event) {
        guard let eventData = event.data as [String: Any]? else {
            Log.error(label: Target.LOG_TAG, "Unable to set third party id, event data is nil.")
            return
        }

        setThirdPartyIdInternal(thirdPartyId: thirdPartyId)
        createSharedState(data: eventData, event: event)
    }

    /// Saves the tntId to the Target DataStore or remove its key in the dataStore if the tntId is nil.
    /// If the tntId ID is changed.
    /// - Parameters:
    ///     - tntId: new tntId that needs to be set
    private func setTntId(tntId: String?) {
        // do not set identifier if privacy is opt-out and the id is not being cleared
        if targetState.privacyStatusIsOptOut, let tntId = tntId, !tntId.isEmpty {
            Log.debug(label: Target.LOG_TAG, "setTntId - Cannot update Target tntId due to opt out privacy status.")
            return
        }

        if tntIdValuesAreEqual(newTntId: tntId, oldTntId: targetState.tntId) {
            Log.debug(label: Target.LOG_TAG, "setTntId - New tntId value is same as the existing tntId \(String(describing: targetState.tntId)).")
            return
        }

        targetState.updateTntId(tntId)
    }

    /// Saves the thirdPartyId to the Target DataStore or remove its key in the dataStore if the newThirdPartyId is nil
    /// - Parameters:
    ///     - thirdPartyId: `String` to  be set
    private func setThirdPartyIdInternal(thirdPartyId: String?) {
        if targetState.privacyStatusIsOptOut, let thirdPartyId = thirdPartyId, !thirdPartyId.isEmpty {
            Log.debug(label: Target.LOG_TAG, "setThirdPartyIdInternal - Cannot update Target thirdPartyId due to opt out privacy status.")
            return
        }

        if thirdPartyId == targetState.thirdPartyId {
            Log.debug(label: Target.LOG_TAG, "setThirdPartyIdInternal - New thirdPartyId value is same as the existing thirdPartyId \(String(describing: thirdPartyId))")
            return
        }

        targetState.updateThirdPartyId(thirdPartyId)
    }

    /// Resets current  sessionId and the sessionTimestampInSeconds
    private func resetSession() {
        targetState.resetSessionId()
        targetState.updateSessionTimestamp(reset: true)
    }

    /// Compares if the given two tntID's are equal. tntId is a concatenation of {tntId}.{tnt_sessionId}
    /// false is returned when tntID's are different.
    /// true is returned when tntID's are same.
    /// - Parameters:
    ///     - newTntId: new tntId
    ///     - oldTntId: old tntId
    private func tntIdValuesAreEqual(newTntId: String?, oldTntId: String?) -> Bool {
        if newTntId == oldTntId {
            return true
        }

        if let oldTntId = oldTntId, let newTntId = newTntId {
            let oldId = String(oldTntId.split(separator: ".").first ?? Substring(oldTntId))
            let newId = String(newTntId.split(separator: ".").first ?? Substring(newTntId))
            return oldId == newId
        }

        return false
    }

    /// Runs the default callback for each of the request in the list.
    /// - Parameters:
    ///     - batchRequests: `[TargetRequests]` to return the default content
    private func runDefaultCallbacks(event: Event, batchRequests: [TargetRequest]) {
        for request in batchRequests {
            dispatchMboxContent(event: event, content: request.defaultContent, responsePairId: request.responsePairId)
        }
    }

    /// Dispatches the Target Response Content Event.
    /// - Parameters:
    ///     - content: the target content
    ///     - pairId: the pairId of the associated target request content event.
    private func dispatchMboxContent(event: Event, content: String, responsePairId: String) {
        Log.trace(label: Target.LOG_TAG, "dispatchMboxContent - " + TargetError.ERROR_TARGET_EVENT_DISPATCH_MESSAGE)

        let responseEvent = Event(name: TargetConstants.EventName.TARGET_REQUEST_RESPONSE, type: EventType.target, source: EventSource.responseContent, data: [TargetConstants.EventDataKeys.TARGET_CONTENT: content, TargetConstants.EventDataKeys.TARGET_RESPONSE_PAIR_ID: responsePairId, TargetConstants.EventDataKeys.TARGET_RESPONSE_EVENT_ID: event.id.uuidString])

        MobileCore.dispatch(event: responseEvent)
    }

    /// Checks if the cached mboxs contain the data for each of the `TargetRequest` in the input List.
    /// If a cached mbox exists, then dispatch the mbox content.
    ///
    private func processCachedTargetRequest(event: Event, batchRequests: [TargetRequest], timeStamp _: Int64) -> [TargetRequest] {
        var requestsToSend: [TargetRequest] = []
        for request in batchRequests {
            guard let cachedMbox = targetState.prefetchedMboxJsonDicts[request.name] else {
                Log.debug(label: Target.LOG_TAG, "processCachedTargetRequest - \(TargetError.ERROR_NO_CACHED_MBOX_FOUND) \(request.name)")
                requestsToSend.append(request)
                continue
            }
            Log.debug(label: Target.LOG_TAG, "processCachedTargetRequest - Cached mbox found for \(request.name) with data \(cachedMbox.description)")

            let content = extractMboxContent(mboxJson: cachedMbox) ?? request.defaultContent
            dispatchMboxContent(event: event, content: content, responsePairId: request.responsePairId)
        }

        return requestsToSend
    }

    /// Return Mbox content from mboxJson, if any
    /// - Parameters:
    ///     - mboxJson: `[String: Any]` target response dictionary
    /// - Returns: `String` mbox content, if any otherwise returns nil
    private func extractMboxContent(mboxJson: [String: Any]) -> String? {
        guard let optionsArray = mboxJson[TargetConstants.TargetJson.OPTIONS] as? [[String: Any?]?] else {
            Log.debug(label: Target.LOG_TAG, "extractMboxContent - unable to extract mbox contents, options array is nil")
            return nil
        }

        var contentBuilder: String = ""

        for option in optionsArray {
            guard let content = option?[TargetConstants.TargetJson.Option.CONTENT] else {
                continue
            }

            guard let type = option?[TargetConstants.TargetJson.Option.TYPE] as? String, !type.isEmpty else {
                continue
            }

            if TargetConstants.TargetJson.HTML == type, let contentString = content as? String {
                contentBuilder.append(contentString)
            } else if TargetConstants.TargetJson.JSON == type, let contentDict = content as? [String: Any?] {
                guard let jsonData = try? JSONSerialization.data(withJSONObject: contentDict, options: .prettyPrinted) else {
                    continue
                }
                guard let jsonString = String(data: jsonData, encoding: .utf8) else { continue }
                contentBuilder.append(jsonString)
            }
        }

        return contentBuilder
    }

    /// Dispatches an Analytics Event containing the Analytics for Target (A4T) payload
    /// - Parameters:
    ///     - payload: analytics for target (a4t) payload
    private func dispatchAnalyticsForTargetRequest(payload: [String: String]?) {
        guard let payloadJson = payload, !payloadJson.isEmpty else {
            Log.debug(label: Target.LOG_TAG, "dispatchAnalyticsForTargetRequest - Failed to dispatch analytics. Payload is either null or empty")
            return
        }

        let eventData = [TargetConstants.EventDataKeys.Analytics.CONTEXT_DATA: payloadJson,
                         TargetConstants.EventDataKeys.Analytics.TRACK_ACTION: TargetConstants.A4T_ACTION_NAME,
                         TargetConstants.EventDataKeys.Analytics.TRACK_INTERNAL: true] as [String: Any]
        let event = Event(name: TargetConstants.EventName.ANALYTICS_FOR_TARGET_REQUEST_EVENT_NAME, type: EventType.analytics, source: EventSource.requestContent, data: eventData)
        MobileCore.dispatch(event: event)
    }

    /// Grabs the a4t payload from the target response and convert the keys to correct format
    /// Returns an empty `Dictionary` if there are no analytics payload that needs to be sent.
    /// - Parameters:
    ///     - mboxJson: A prefetched mbox dictionary
    ///     - sessionId: session id
    /// - Returns: `Dictionary` containing a4t payload
    private func getAnalyticsForTargetPayload(mboxJson: [String: Any], sessionId: String) -> [String: String]? {
        var payload: [String: String] = [:]
        guard let analyticsJson = mboxJson[TargetConstants.TargetJson.ANALYTICS_PARAMETERS] as? [String: Any] else {
            return nil
        }

        guard let payloadJson = analyticsJson[TargetConstants.TargetJson.ANALYTICS_PAYLOAD] as? [String: String] else {
            return nil
        }

        for (k, v) in payloadJson {
            payload["&&\(k)"] = v
        }

        if !sessionId.isEmpty {
            payload[TargetConstants.TargetJson.SESSION_ID] = sessionId
        }

        return payload
    }
}
