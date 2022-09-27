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
import Foundation

extension Event {
    /// Reads an array`TargetPrefetch` from the event data
    var prefetchObjectArray: [TargetPrefetch]? {
        TargetPrefetch.from(dictionaries: data?[TargetConstants.EventDataKeys.PREFETCH_REQUESTS] as? [[String: Any]])
    }

    /// Reads the `TargetParameters` from the event data
    var targetParameters: TargetParameters? {
        TargetParameters.from(dictionary: data?[TargetConstants.EventDataKeys.TARGET_PARAMETERS] as? [String: Any])
    }

    /// Reads the Target `at_property` from the event data
    var propertyToken: String {
        data?[TargetConstants.EventDataKeys.AT_PROPERTY] as? String ?? ""
    }

    /// Returns true if this event is a prefetch request event
    var isPrefetchEvent: Bool {
        data?[TargetConstants.EventDataKeys.PREFETCH_REQUESTS] != nil
    }

    /// Returns true if this event is a load request event
    var isLoadRequest: Bool {
        data?[TargetConstants.EventDataKeys.LOAD_REQUESTS] != nil
    }

    /// Reads an array`TargetRequest` from the event data
    var targetRequests: [TargetRequest]? {
        TargetRequest.from(dictionaries: data?[TargetConstants.EventDataKeys.LOAD_REQUESTS] as? [[String: Any]])
    }

    /// Returns true if the event is location display request event
    var isLocationsDisplayedEvent: Bool {
        data?[TargetConstants.EventDataKeys.IS_LOCATION_DISPLAYED] as? Bool ?? false
    }

    /// Returns true if the event is location clicked request event
    var isLocationClickedEvent: Bool {
        data?[TargetConstants.EventDataKeys.IS_LOCATION_CLICKED] as? Bool ?? false
    }

    /// Returns true if the event is a raw execute or notification event
    var isRawEvent: Bool {
        data?[TargetConstants.EventDataKeys.IS_RAW_EVENT] as? Bool ?? false
    }

    /// Returns true if this event is a reset experience request event
    var isResetExperienceEvent: Bool {
        data?[TargetConstants.EventDataKeys.RESET_EXPERIENCE] as? Bool ?? false
    }

    /// Returns true if this event is a clear prefetch request event
    var isClearPrefetchCache: Bool {
        data?[TargetConstants.EventDataKeys.CLEAR_PREFETCH_CACHE] as? Bool ?? false
    }

    /// Returns error message in the response event
    var error: String {
        data?[TargetConstants.EventDataKeys.RESPONSE_ERROR] as? String ?? ""
    }
}
