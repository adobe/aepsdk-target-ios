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
    static let DATASTORE_NAME = EXTENSION_NAME
    static let DEFAULT_SESSION_TIMEOUT: Int = 30 * 60 // 30 mins
    static let DELIVERY_API_URL_BASE = "https://%@/rest/v1/delivery/?client=%@&sessionId=%@"
    static let API_URL_HOST_BASE = "%@.tt.omtrdc.net"
    static let HEADER_CONTENT_TYPE = "Content-Type"
    static let HEADER_CONTENT_TYPE_JSON = "application/json"

    enum DataStoreKeys {
        static let SESSION_TIMESTAMP = "SESSION_TIMESTAMP"
        static let SESSION_ID = "SESSION_ID"
        static let SESSION_TIMEOUT = "SESSION_TIMEOUT"
        static let TNT_ID = "TNT_ID"
        static let EDGE_HOST = "EDGE_HOST"
    }

    enum TargetRequestValue {
        static let CHANNEL_MOBILE = "mobile"
        static let COLOR_DEPTH_32 = 32
    }

    enum EventName {
        static let LOAD_REQUEST = "TargetLoadRequest"
        static let PREFETCH_REQUESTS = "prefetch"
        static let PREFETCH_RESPOND = "prefetchRespond"
        static let REQUEST_IDENTITY = "TargetRequestIdentity"
        static let REQUEST_RESET = "TargetRequestReset"
        static let CLEAR_PREFETCH_CACHE = "TargetClearPrefetchCache"
        static let SET_PREVIEW_DEEPLINK = "TargetSetPreviewRestartDeeplink"
        static let LOCATIONS_DISPLAYED = "TargetLocationsDisplayed"
        static let LOCATION_CLICKED = "TargetLocationClicked"
    }

    enum EventDataKeys {
        static let TARGET_PARAMETERS = "targetparams"
        static let PREFETCH_REQUESTS = "prefetch"
        static let PREFETCH_ERROR = "prefetcherror"
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
        // shared sate
        static let TNT_ID = "tntid"
    }

    enum Identity {
        static let EXTENSION_NAME = "com.adobe.module.identity"
        enum SharedState {
            enum Keys {
                static let VISITOR_ID_MID = "mid"
                static let VISITOR_ID_BLOB = "blob"
                static let VISITOR_ID_LOCATION_HINT = "locationhint"
                static let VISITOR_IDS_LIST = "visitoridslist"
                static let ADVERTISING_IDENTIFIER = "advertisingidentifier"
            }
        }
    }

    enum Configuration {
        static let EXTENSION_NAME = "com.adobe.module.configuration"
        enum SharedState {
            enum Keys {
                // Core Extension
                static let GLOBAL_CONFIG_PRIVACY = "global.privacy"
                // Target Extension
                static let TARGET_CLIENT_CODE = "target.clientCode"
                static let TARGET_PREVIEW_ENABLED = "target.previewEnabled"
                static let TARGET_NETWORK_TIMEOUT = "target.timeout"
                static let TARGET_ENVIRONMENT_ID = "target.environmentId"
                static let TARGET_PROPERTY_TOKEN = "target.propertyToken"
                static let TARGET_SESSION_TIMEOUT = "target.sessionTimeout"
                static let TARGET_SERVER = "target.server"
            }

            enum Values {
                static let GLOBAL_CONFIG_PRIVACY_OPT_IN = "optedin"
                static let GLOBAL_CONFIG_PRIVACY_OPT_OUT = "optedout"
                static let GLOBAL_CONFIG_PRIVACY_OPT_UNKNOWN = "optunknown"
            }
        }
    }

    enum Lifecycle {
        static let EXTENSION_NAME = "com.adobe.module.lifecycle"
    }
}
