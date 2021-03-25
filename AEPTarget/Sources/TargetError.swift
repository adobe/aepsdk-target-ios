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

import Foundation

class TargetError: Error, CustomStringConvertible {
    private let message: String
    static let ERROR_EMPTY_PREFETCH_LIST = "Empty or nil prefetch requests list"
    static let ERROR_INVALID_REQUEST = "Invalid request error"
    static let ERROR_TIMEOUT = "API call timeout"
    static let ERROR_MBOX_NAMES_NULL_OR_EMPTY = "MboxNames list is either nil or empty"
    static let ERROR_MBOX_NAME_NULL_OR_EMPTY = "MboxName is either nil or empty"
    static let ERROR_NO_CLIENT_CODE = "Missing client code"
    static let ERROR_OPTED_OUT = "Privacy status is opted out"
    static let ERROR_NOT_OPTED_IN = "Privacy status is not opted in"
    static let ERROR_DISPLAY_NOTIFICATION_SEND_FAILED = "Unable to send display notification: "
    static let ERROR_DISPLAY_NOTIFICATION_NOT_SENT = "No display notifications are available to send"
    static let ERROR_CLICK_NOTIFICATION_NOT_SENT = "No click notifications are available to send"
    static let ERROR_NO_CACHED_MBOX_FOUND = "No cached mbox found for"
    static let ERROR_DISPLAY_NOTIFICATION_TOKEN_EMPTY = "Unable to create display notification as token is nil or empty"
    static let ERROR_DISPLAY_NOTIFICATION_NULL_FOR_MBOX = "No display notifications are available to send for mbox"
    static let ERROR_CLICK_NOTIFICATION_SEND_FAILED = "Unable to send click notification:"
    static let ERROR_NO_CLICK_METRICS = "No click metrics set on mbox:"
    static let ERROR_NO_CLICK_METRIC_FOUND = "No click metric found on mbox:"
    static let ERROR_CLICK_NOTIFICATION_CREATE_FAILED = "Failed to create click notification Json"
    static let ERROR_NULL_EMPTY_REQUEST_MESSAGE = "The provided request list for mboxes is empty or null"
    static let ERROR_TARGET_EVENT_DISPATCH_MESSAGE = "Dispatching - Target response content event"
    static let ERROR_BATCH_REQUEST_SEND_FAILED = "Unable to send batch requests: "

    init(message: String) {
        self.message = message
    }

    var description: String {
        message
    }
}
