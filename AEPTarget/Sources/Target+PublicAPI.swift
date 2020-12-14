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

@objc public extension Target {
    /// Prefetch multiple Target mboxes simultaneously.
    /// Executes a prefetch request to your configured Target server with the ACPTargetPrefetchObject list provided
    /// in the prefetchObjectArray parameter. This prefetch request will use the provided parameters for all of
    /// the prefetches made in this request. The callback will be executed when the prefetch has been completed, returning
    /// an error object, nil if the prefetch was successful or error description if the prefetch was unsuccessful.
    /// The prefetched mboxes are cached in memory for the current application session and returned when requested.
    /// - Parameters:
    ///   - prefetchObjectArray: an array of ACPTargetPrefetchObject representing the desired mboxes to prefetch
    ///   - targetParameters: a TargetParameters object containing parameters for all the mboxes in the request array
    ///   - completion: the callback `closure` which will be called after the prefetch is complete.  The error parameter in the callback will be nil if the prefetch completed successfully, or will contain error message otherwise
    static func prefetchContent(prefetchObjectArray _: [TargetPrefetch], targetParameters: TargetParameters, completion _: @escaping (AEPError) -> Void) {
        // TODO: need to verify input parameters
        // TODO: need to convert "targetParameters" to [String:Any] array
        let eventData = [TargetConstants.EventDataKeys.TARGET_PARAMETERS: targetParameters]
        let event = Event(name: TargetConstants.EventName.PREFETCH_REQUESTS, type: EventType.target, source: EventSource.requestContent, data: eventData)
        MobileCore.dispatch(event: event) { _ in
            // TODO:
        }
    }

    /// Retrieves content for multiple Target mbox locations at once.
    /// Executes a batch request to your configured Target server for multiple mbox locations. Any prefetched content
    /// which matches a given mbox location is returned and not included in the batch request to the Target server.
    /// Each object in the array contains a callback function, which will be invoked when content is available for
    /// its given mbox location.
    /// - Parameters:
    ///   - requests:  An array of ACPTargetRequestObject objects to retrieve content
    ///   - targetParameters: a TargetParameters object containing parameters for all locations in the requests array
    static func retrieveLocationContent(requests: [TargetRequest], targetParameters: TargetParameters) {
        // TODO: need to verify input parameters
        // TODO: need to convert "requests" to [String:Any] array
        let eventData = [TargetConstants.EventDataKeys.LOAD_REQUESTS: requests, TargetConstants.EventDataKeys.LOAD_REQUESTS: targetParameters] as [String: Any]
        let event = Event(name: TargetConstants.EventName.LOAD_REQUEST, type: EventType.target, source: EventSource.requestContent, data: eventData)
        MobileCore.dispatch(event: event)
    }

    /// Sets the custom visitor ID for Target.
    /// Sets a custom ID to identify visitors (profiles). This ID is preserved between app upgrades,
    /// is saved and restored during the standard application backup process, and is removed at uninstall or
    /// when ACPTarget::resetExperience is called.
    /// - Parameter thirdPartyId: a string pointer containing the value of the third party id (custom visitor id)
    static func setThirdPartyId(_ id: String) {
        // TODO: need to verify input parameters
        let eventData = [TargetConstants.EventDataKeys.THIRD_PARTY_ID: id]
        let event = Event(name: TargetConstants.EventName.REQUEST_IDENTITY, type: EventType.target, source: EventSource.requestIdentity, data: eventData)
        MobileCore.dispatch(event: event)
    }

    /// Gets the custom visitor ID for Target
    /// - Parameter completion:  the callback `closure` will be invoked to return the thirdPartyId value or `nil` if no third-party ID is set
    static func getThirdPartyId(completion _: (String) -> Void) {
        let event = Event(name: TargetConstants.EventName.REQUEST_IDENTITY, type: EventType.target, source: EventSource.requestIdentity, data: nil)
        MobileCore.dispatch(event: event) { _ in
            // TODO:
        }
    }

    /// Gets the Test and Target user identifier.
    /// Retrieves the TnT ID returned by the Target server for this visitor. The TnT ID is set to the
    /// Mobile SDK after a successful call to prefetch content or load requests.
    ///
    /// This ID is preserved between app upgrades, is saved and restored during the standard application
    /// backup process, and is removed at uninstall or when ACPTarget::resetExperience is called.
    ///
    /// - Parameter completion:  the callback `closure` invoked with the current tnt id or `nil` if no tnt id is set.
    static func getTntId(completion _: (String) -> Void) {
        let event = Event(name: TargetConstants.EventName.REQUEST_IDENTITY, type: EventType.target, source: EventSource.requestIdentity, data: nil)
        MobileCore.dispatch(event: event) { _ in
            // TODO:
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
    /// Clears the cached prefetched ACPTargetPrefetchObject array.
    static func clearPrefetchCache() {
        let eventData = [TargetConstants.EventDataKeys.CLEAR_PREFETCH_CACHE: true]
        let event = Event(name: TargetConstants.EventName.CLEAR_PREFETCH_CACHE, type: EventType.target, source: EventSource.requestReset, data: eventData)
        MobileCore.dispatch(event: event)
    }

    /// Sets the Target preview restart deep link.
    /// Set the Target preview URL to be displayed when the preview mode is restarted.
    /// - Parameter deeplink:  the URL which will be set for preview restart
    static func setPreviewRestartDeepLink(_ deeplink: URL) {
        // TODO: need to verify input parameters
        let eventData = [TargetConstants.EventDataKeys.PREVIEW_RESTART_DEEP_LINK: deeplink.absoluteString]
        let event = Event(name: TargetConstants.EventName.SET_PREVIEW_DEEPLINK, type: EventType.target, source: EventSource.requestContent, data: eventData)
        MobileCore.dispatch(event: event)
    }

    /// Sends a display notification to Target for given prefetched mboxes. This helps Target record location display events.
    /// - Parameters:
    ///   - mboxNames:  (required) an array of displayed location names
    ///   - targetParameters: for the displayed location
    static func locationsDisplayed(mboxNames: [String], targetParameters: TargetParameters) {
        // TODO: need to verify input parameters
        // TODO: need to convert "targetParameters" to [String:Any] array
        let eventData = [TargetConstants.EventDataKeys.MBOX_NAMES: mboxNames, TargetConstants.EventDataKeys.IS_LOCATION_DISPLAYED: true, TargetConstants.EventDataKeys.TARGET_PARAMETERS: targetParameters] as [String: Any]
        let event = Event(name: TargetConstants.EventName.LOCATIONS_DISPLAYED, type: EventType.target, source: EventSource.requestContent, data: eventData)
        MobileCore.dispatch(event: event)
    }

    /// Sends a click notification to Target if a click metric is defined for the provided location name.
    /// Click notification can be sent for a location provided a load request has been executed for that prefetched or regular mbox
    /// location before, indicating that the mbox was viewed. This request helps Target record the clicked event for the given location or mbox.
    ///
    /// - Parameters:
    ///   - name:  NSString value representing the name for location/mbox
    ///   - targetParameters:  a TargetParameters object containing parameters for the location clicked
    static func locationClicked(name _: String, targetParameters _: TargetParameters?) {
        // TODO: need to verify input parameters
        // TODO: need to convert "targetParameters" to [String:Any] array
        let eventData = [TargetConstants.EventDataKeys.IS_LOCATION_DISPLAYED: true, TargetConstants.EventDataKeys.MBOX_NAMES: "", TargetConstants.EventDataKeys.MBOX_PARAMETERS: "", TargetConstants.EventDataKeys.ORDER_PARAMETERS: "", TargetConstants.EventDataKeys.PRODUCT_PARAMETERS: "", TargetConstants.EventDataKeys.PROFILE_PARAMETERS: ""] as [String: Any]
        let event = Event(name: TargetConstants.EventName.LOCATION_CLICKED, type: EventType.target, source: EventSource.requestContent, data: eventData)
        MobileCore.dispatch(event: event)
    }
}
