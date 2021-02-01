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

enum TargetTestConstants {
    // preview parameters
    static let PREVIEW_MESSAGE_ID = "target-preview-message-id"
    static let PREVIEW_PARAMETERS = "at_preview_params"
    static let PREVIEW_TOKEN = "at_preview_token"
    static let PREVIEW_ENDPOINT = "at_preview_endpoint"
    static let PREVIEW_QA_MODE = "qaMode"
    static let DEFAULT_TARGET_PREVIEW_ENDPOINT = "hal.testandtarget.omniture.com"
    static let DEEPLINK = "deeplink"
    static let DEEPLINK_SCHEME = "adbinapp"
    static let DEEPLINK_SCHEME_CANCEL = "cancel"
    static let DEEPLINK_SCHEME_PATH_CONFIRM = "confirm"
    static let TEST_CLIENT_CODE = "test_client_code"

    static let ENCODED_PREVIEW_PARAMS = "%7B%22qaMode%22%3A%7B%0D%0A%22token%22%3A%22abcd%22%2C%0D%0A%22bypassEntryAudience%22%3Atrue%2C%0D%0A%22listedActivitiesOnly%22%3Atrue%2C%0D%0A%22evaluateAsTrueAudienceIds%22%3A%5B%22audienceId1%22%2C%22audienceId2%22%5D%2C%0D%0A%22evaluateAsFalseAudienceIds%22%3A%5B%22audienceId3%22%2C%22audienceId4%22%5D%2C%0D%0A%22previewIndexes%22%3A%5B%0D%0A%7B%0D%0A%22activityIndex%22%3A1%2C%0D%0A%22experienceIndex%22%3A1%0D%0A%7D%5D%7D%7D"
    static let JSON_PREVIEW_PARAMS = "{\"" + PREVIEW_QA_MODE + "\" : {\n"
        + "  \"token\" : \"abcd\",\n"
        + "  \"bypassEntryAudience\" : true,\n"
        + "  \"listedActivitiesOnly\" : true,\n"
        + "  \"evaluateAsTrueAudienceIds\" : [\"audienceId1\", \"audienceId2\"],\n"
        + "  \"evaluateAsFalseAudienceIds\" : [\"audienceId3\", \"audienceId4\"],\n"
        + "  \"previewIndexes\" : [\n"
        + "     {\n"
        + "       \"activityIndex\" : 1,\n"
        + "       \"experienceIndex\" : 1\n"
        + "     }\n"
        + "   ]\n"
        + "}\n"
        + "}"
    static let TEST_QUERY_PARAMS = PREVIEW_PARAMETERS + "=" + ENCODED_PREVIEW_PARAMS + "&extraKey=extraValue"
    static let TEST_CONFIRM_DEEPLINK = "adbinapp://confirm?" + TEST_QUERY_PARAMS
    static let TEST_CANCEL_DEEPLINK = "adbinapp://cancel"
    static let TEST_RESTART_URL = "adbinapp://somepage"
}
