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

@objc public extension Target {
    /// true if the response content event listener is already registered, false otherwise
    private static var isResponseListenerRegister: Bool = false
    /// `Dictionary` to keep track of pending target request
    @nonobjc
    private static var pendingTargetRequest: ThreadSafeDictionary<String, TargetRequest> = ThreadSafeDictionary()

    /// Prefetch multiple Target mboxes simultaneously.
    ///
    /// Executes a prefetch request to your configured Target server with the TargetPrefetchObject list provided
    /// in the prefetchObjectArray parameter. This prefetch request will use the provided parameters for all of
    /// the prefetches made in this request. The callback will be executed when the prefetch has been completed, returning
    /// an error object, nil if the prefetch was successful or error description if the prefetch was unsuccessful.
    /// The prefetched mboxes are cached in memory for the current application session and returned when requested.
    /// - Parameters:
    ///   - prefetchArray: an array of AEPTargetPrefetch objects representing the desired mboxes to prefetch
    ///   - targetParameters: a TargetParameters object containing parameters for all the mboxes in the request array
    ///   - completion: the callback `closure` which will be called after the prefetch is complete.  The parameter in the callback will be nil if the prefetch completed successfully, or will contain error message otherwise
    @objc(prefetchContent:withParameters:callback:)
    static func prefetchContent(_ prefetchArray: [TargetPrefetch], with targetParameters: TargetParameters? = nil, _ completion: ((Error?) -> Void)?) {
        let completion = completion ?? { _ in }

        guard !prefetchArray.isEmpty else {
            Log.error(label: Target.LOG_TAG, "Failed to prefetch Target request (the provided request list for mboxes is empty or nil)")
            completion(TargetError(message: TargetError.ERROR_EMPTY_PREFETCH_LIST))
            return
        }
        var prefetchDataArray = [[String: Any]]()
        for prefetch in prefetchArray {
            if let dict = prefetch.asDictionary() {
                prefetchDataArray.append(dict)

            } else {
                Log.error(label: Target.LOG_TAG, "Failed to prefetch Target request (the provided prefetch object can't be converted to [String: Any] dictionary), prefetch => \(prefetch)")
                completion(TargetError(message: TargetError.ERROR_INVALID_REQUEST))
                return
            }
        }

        var eventData: [String: Any] = [TargetConstants.EventDataKeys.PREFETCH_REQUESTS: prefetchDataArray]
        if let targetParametersDict = targetParameters?.asDictionary() {
            eventData[TargetConstants.EventDataKeys.TARGET_PARAMETERS] = targetParametersDict
        }

        let event = Event(name: TargetConstants.EventName.PREFETCH_REQUESTS, type: EventType.target, source: EventSource.requestContent, data: eventData)

        MobileCore.dispatch(event: event) { responseEvent in
            guard let responseEvent = responseEvent else {
                completion(TargetError(message: TargetError.ERROR_TIMEOUT))
                return
            }
            if let errorMessage = responseEvent.data?[TargetConstants.EventDataKeys.PREFETCH_ERROR] as? String {
                completion(TargetError(message: errorMessage))
                return
            }
            completion(.none)
        }
    }

    /// Retrieves content for multiple Target mbox locations at once.
    /// Executes a batch request to your configured Target server for multiple mbox locations. Any prefetched content
    /// which matches a given mbox location is returned and not included in the batch request to the Target server.
    /// Each object in the array contains a callback function, which will be invoked when content is available for
    /// its given mbox location.
    /// - Parameters:
    ///   - requestArray:  An array of AEPTargetRequestObject objects to retrieve content
    ///   - targetParameters: a TargetParameters object containing parameters for all locations in the requests array
    @objc(retrieveLocationContent:withParameters:)
    static func retrieveLocationContent(_ requestArray: [TargetRequest], with targetParameters: TargetParameters? = nil) {
        if requestArray.isEmpty {
            Log.error(label: Target.LOG_TAG, "Failed to retrieve location content target request \(TargetError.ERROR_NULL_EMPTY_REQUEST_MESSAGE)")
            return
        }

        var targetRequestsArray = [[String: Any]]()
        var tempIdToRequest: [String: TargetRequest] = [:]

        for request in requestArray {
            if request.name.isEmpty {
                // If the callback is present call with default content
                if let callback = request.contentCallback {
                    callback(request.defaultContent)
                }
                Log.debug(label: Target.LOG_TAG, "TargetRequest removed because mboxName is empty.")
                continue
            }

            guard let requestDictionary = request.asDictionary() else {
                Log.error(label: Target.LOG_TAG, "Failed to convert Target request to [String: Any] dictionary), prefetch => \(String(describing: request))")
                continue
            }

            tempIdToRequest[request.responsePairId] = request

            targetRequestsArray.append(requestDictionary)
        }

        if targetRequestsArray.isEmpty {
            Log.error(label: Target.LOG_TAG, "Failed to retrieve location content target request is empty")
            return
        }

        // Register the response content event listener
        registerResponseContentEventListener()

        var eventData = [TargetConstants.EventDataKeys.LOAD_REQUESTS: targetRequestsArray] as [String: Any]
        if let targetParametersDict = targetParameters?.asDictionary() {
            eventData[TargetConstants.EventDataKeys.TARGET_PARAMETERS] = targetParametersDict
        }
        let event = Event(name: TargetConstants.EventName.LOAD_REQUEST, type: EventType.target, source: EventSource.requestContent, data: eventData)

        // Update the pending target request dictionary with
        // key = `event.id-request.responsePairId`, value = `TargetRequest` object
        for (responsePairId, targetRequest) in tempIdToRequest {
            pendingTargetRequest["\(event.id)-\(responsePairId)"] = targetRequest
        }

        Log.trace(label: Target.LOG_TAG, "retrieveLocationContent - Event dispatched \(event.name), \(event.id.uuidString)")

        MobileCore.dispatch(event: event)
    }

    /// Sets the custom visitor ID for Target.
    /// Sets a custom ID to identify visitors (profiles). This ID is preserved between app upgrades,
    /// is saved and restored during the standard application backup process, and is removed at uninstall or
    /// when AEPTarget::resetExperience is called.
    /// - Parameter thirdPartyId: a string pointer containing the value of the third party id (custom visitor id)
    static func setThirdPartyId(_ id: String?) {
        let eventData = [TargetConstants.EventDataKeys.THIRD_PARTY_ID: id ?? ""]
        let event = Event(name: TargetConstants.EventName.REQUEST_IDENTITY, type: EventType.target, source: EventSource.requestIdentity, data: eventData)
        MobileCore.dispatch(event: event)
    }

    /// Gets the custom visitor ID for Target
    /// This ID will be reset  when the `resetExperience()` API is called.
    /// - Parameter completion:  the callback `closure` will be invoked to return the thirdPartyId value or `nil` if no third-party ID is set
    static func getThirdPartyId(_ completion: @escaping (String?, Error?) -> Void) {
        let event = Event(name: TargetConstants.EventName.REQUEST_IDENTITY, type: EventType.target, source: EventSource.requestIdentity, data: nil)
        MobileCore.dispatch(event: event) { responseEvent in
            guard let responseEvent = responseEvent else {
                let error = "Request to get third party id failed, \(TargetError.ERROR_TIMEOUT)"
                completion(nil, TargetError(message: error))
                Log.error(label: Target.LOG_TAG, error)
                return
            }
            guard let eventData = responseEvent.data else {
                let error = "Unable to handle response, event data is nil."
                completion(nil, TargetError(message: error))
                Log.error(label: Target.LOG_TAG, error)
                return
            }
            guard let thirdPartyId = eventData[TargetConstants.EventDataKeys.THIRD_PARTY_ID] as? String else {
                let error = "Unable to handle response, No third party id available."
                completion(nil, TargetError(message: error))
                Log.error(label: Target.LOG_TAG, error)
                return
            }
            completion(thirdPartyId, nil)
        }
    }

    /// Gets the Test and Target user identifier.
    /// Retrieves the TnT ID returned by the Target server for this visitor. The TnT ID is set to the
    /// Mobile SDK after a successful call to prefetch content or load requests.
    ///
    /// This ID is preserved between app upgrades, is saved and restored during the standard application
    /// backup process, and is removed at uninstall or when AEPTarget::resetExperience is called.
    ///
    /// - Parameter completion:  the callback `closure` invoked with the current tnt id or `nil` if no tnt id is set.
    static func getTntId(_ completion: @escaping (String?, Error?) -> Void) {
        let event = Event(name: TargetConstants.EventName.REQUEST_IDENTITY, type: EventType.target, source: EventSource.requestIdentity, data: nil)
        MobileCore.dispatch(event: event) { responseEvent in
            guard let responseEvent = responseEvent else {
                let error = "Request to get third party id failed, \(TargetError.ERROR_TIMEOUT)"
                completion(nil, TargetError(message: error))
                Log.error(label: Target.LOG_TAG, error)
                return
            }
            guard let eventData = responseEvent.data else {
                let error = "Unable to handle response, event data is nil."
                completion(nil, TargetError(message: error))
                Log.error(label: Target.LOG_TAG, error)
                return
            }
            guard let tntId = eventData[TargetConstants.EventDataKeys.TNT_ID] as? String else {
                let error = "Unable to handle response, No tntid available."
                completion(nil, TargetError(message: error))
                Log.error(label: Target.LOG_TAG, error)
                return
            }
            completion(tntId, nil)
        }
    }

    /// Sets the Target preview restart deep link.
    /// Set the Target preview URL to be displayed when the preview mode is restarted.
    static func resetExperience() {
        let eventData = [TargetConstants.EventDataKeys.RESET_EXPERIENCE: true]
        let event = Event(name: TargetConstants.EventName.REQUEST_RESET, type: EventType.target, source: EventSource.requestReset, data: eventData)
        MobileCore.dispatch(event: event)
    }

    /// Clears prefetched mboxes.
    /// Clears the cached prefetched AEPTargetPrefetchObject array.
    static func clearPrefetchCache() {
        let eventData = [TargetConstants.EventDataKeys.CLEAR_PREFETCH_CACHE: true]
        let event = Event(name: TargetConstants.EventName.CLEAR_PREFETCH_CACHE, type: EventType.target, source: EventSource.requestReset, data: eventData)
        MobileCore.dispatch(event: event)
    }

    /// Sets the Target preview restart deep link.
    /// Set the Target preview URL to be displayed when the preview mode is restarted.
    /// - Parameter deeplink:  the URL which will be set for preview restart
    @objc(setPreviewRestartDeepLink:)
    static func setPreviewRestartDeepLink(_ deeplink: URL) {
        let eventData = [TargetConstants.EventDataKeys.PREVIEW_RESTART_DEEP_LINK: deeplink.absoluteString]
        let event = Event(name: TargetConstants.EventName.SET_PREVIEW_DEEPLINK, type: EventType.target, source: EventSource.requestContent, data: eventData)
        MobileCore.dispatch(event: event)
    }

    /// Sends a display notification to Target for given prefetched mboxes. This helps Target record location display events.
    /// - Parameters:
    ///   - names:  (required) an array of displayed location names
    ///   - targetParameters: for the displayed location
    @objc(displayedLocations:withTargetParameters:)
    static func displayedLocations(_ names: [String], targetParameters: TargetParameters? = nil) {
        if names.isEmpty {
            Log.error(label: LOG_TAG, "Failed to send display notification, List of Mbox names must not be empty.")
            return
        }

        var eventData = [TargetConstants.EventDataKeys.MBOX_NAMES: names, TargetConstants.EventDataKeys.IS_LOCATION_DISPLAYED: true] as [String: Any]

        if let targetParametersDict = targetParameters?.asDictionary() {
            eventData[TargetConstants.EventDataKeys.TARGET_PARAMETERS] = targetParametersDict
        }

        let event = Event(name: TargetConstants.EventName.LOCATIONS_DISPLAYED, type: EventType.target, source: EventSource.requestContent, data: eventData)
        MobileCore.dispatch(event: event)
    }

    /// Sends a click notification to Target if a click metric is defined for the provided location name.
    /// Click notification can be sent for a location provided a load request has been executed for that prefetched or regular mbox
    /// location before, indicating that the mbox was viewed. This request helps Target record the clicked event for the given location or mbox.
    ///
    /// - Parameters:
    ///   - mboxName:  NSString value representing the name for location/mbox
    ///   - targetParameters:  a TargetParameters object containing parameters for the location clicked
    @objc(clickedLocation:withTargetParameters:)
    static func clickedLocation(_ name: String, targetParameters: TargetParameters? = nil) {
        if name.isEmpty {
            Log.error(label: LOG_TAG, "Failed to send click notification, Mbox name must not be empty or nil.")
            return
        }

        var eventData = [TargetConstants.EventDataKeys.MBOX_NAME: name, TargetConstants.EventDataKeys.IS_LOCATION_CLICKED: true] as [String: Any]

        if let targetParametersDict = targetParameters?.asDictionary() {
            eventData[TargetConstants.EventDataKeys.TARGET_PARAMETERS] = targetParametersDict
        }

        let event = Event(name: TargetConstants.EventName.LOCATION_CLICKED, type: EventType.target, source: EventSource.requestContent, data: eventData)
        MobileCore.dispatch(event: event)
    }

    /// Registers the response content event listener
    private static func registerResponseContentEventListener() {
        // Only register the listener once
        if !isResponseListenerRegister {
            MobileCore.registerEventListener(type: EventType.target, source: EventSource.responseContent, listener: handleResponseEvent(_:))
            isResponseListenerRegister = true
        }
    }

    /// Handles the response event with event name as `TargetConstants.EventName.TARGET_REQUEST_RESPONSE`
    /// - Parameters:
    ///     - event: Response content event with content
    private static func handleResponseEvent(_ event: Event) {
        if event.name != TargetConstants.EventName.TARGET_REQUEST_RESPONSE {
            return
        }

        guard let id = event.data?[TargetConstants.EventDataKeys.TARGET_RESPONSE_EVENT_ID] as? String,
              let responsePairId = event.data?[TargetConstants.EventDataKeys.TARGET_RESPONSE_PAIR_ID] as? String
        else {
            Log.error(label: LOG_TAG, "Missing response pair id for the target request in the response event")
            return
        }

        let searchId = "\(id)-\(responsePairId)"

        // Remove and use the target request from the map
        guard let targetRequest = pendingTargetRequest.removeValue(forKey: searchId) else {
            Log.error(label: LOG_TAG, "Missing target request for the \(searchId)")
            return
        }

        guard let callback = targetRequest.contentCallback else {
            Log.warning(label: LOG_TAG, "Missing callback for target request with pair id the \(responsePairId)")
            return
        }
        let content = event.data?[TargetConstants.EventDataKeys.TARGET_CONTENT] as? String ?? targetRequest.defaultContent
        callback(content)
    }
}
