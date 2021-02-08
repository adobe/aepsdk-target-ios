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

import Foundation

enum TargetConstants {
    static let EXTENSION_NAME = "com.adobe.module.target"
    static let FRIENDLY_NAME = "Target"
    static let EXTENSION_VERSION = "3.0.0-beta.1"
    static let LOG_PREFIX = FRIENDLY_NAME

    enum EventName {
        static let LOAD_REQUEST = "TargetLoadRequest"
        static let PREFETCH_REQUESTS = "prefetch"
        static let REQUEST_IDENTITY = "TargetRequestIdentity"
        static let REQUEST_RESET = "TargetRequestReset"
        static let CLEAR_PREFETCH_CACHE = "TargetClearPrefetchCache"
        static let SET_PREVIEW_DEEPLINK = "TargetSetPreviewRestartDeeplink"
        static let LOCATIONS_DISPLAYED = "TargetLocationsDisplayed"
        static let LOCATION_CLICKED = "TargetLocationClicked"
    }

    enum EventDataKeys {
        static let TARGET_PARAMETERS = "targetparams"
        static let LOAD_REQUESTS = "request"
        static let THIRD_PARTY_ID = "thirdpartyid"
        static let RESET_EXPERIENCE = "resetexperience"
        static let CLEAR_PREFETCH_CACHE = "clearcache"
        static let PREVIEW_RESTART_DEEP_LINK = "restartdeeplink"
        static let MBOX_NAMES = "mboxnames"
        static let IS_LOCATION_DISPLAYED = "islocationdisplayed"
        static let IS_LOCATION_CLICKED = "islocationclicked"
        static let MBOX_PARAMETERS = "mboxparameters"
        static let ORDER_PARAMETERS = "orderparameters"
        static let PRODUCT_PARAMETERS = "productparameters"
        static let PROFILE_PARAMETERS = "profileparams"
    }
}
