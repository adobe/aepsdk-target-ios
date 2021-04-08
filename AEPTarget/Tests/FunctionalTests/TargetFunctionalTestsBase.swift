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

@testable import AEPCore
@testable import AEPServices
@testable import AEPTarget
import XCTest

class TargetFunctionalTestsBase: XCTestCase {
    var target: Target!
    var mockRuntime: TestableExtensionRuntime!
    var mockPreviewManager = MockTargetPreviewManager()

    var mockMBox = ["mbox1", "mbox2"]
    var mockMBoxJson = ["mbox1": ["name": "mbox1", "state": "state1", "options": [["eventToken": "sometoken"]], "metrics": [["type": "click", "eventToken": "eventToken"]]],
                        "mbox2": ["name": "mbox2", "state": "state2", "options": [["eventToken": "sometoken2"]]]]
    var mockProfileParam = ["name": "Smith"]
    var mockConfigSharedState: [String: Any] = [:]
    var mockLifecycleData: [String: Any] = [:]
    var mockIdentityData: [String: Any] = [:]

    override func setUp() {
        // Mock data
        mockConfigSharedState = ["target.clientCode": "code_123", "global.privacy": "optedin"]
        mockLifecycleData = [
            "lifecyclecontextdata":
                [
                    "appid": "appid_1",
                    "devicename": "devicename_1",
                    "locale": "en-US",
                    "osversion": "iOS 14.4",
                    "resolution": "1125x2436",
                    "runmode": "Application",
                ] as Any,
        ]
        mockIdentityData = [
            "mid": "38209274908399841237725561727471528301",
            "visitoridslist":
                [
                    [
                        "authentication_state": 0,
                        "id": "vid_id_1",
                        "id_origin": "d_cid_ic",
                        "id_type": "vid_type_1",
                    ],
                ] as Any,
        ]

        cleanUserDefaults()
        mockRuntime = TestableExtensionRuntime()
        target = Target(runtime: mockRuntime)
        target.previewManager = mockPreviewManager
        target.onRegistered()
    }

    // MARK: - helper methods

    func cleanUserDefaults() {
        for _ in 0 ... 5 {
            for key in getUserDefaults().dictionaryRepresentation().keys {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        for _ in 0 ... 5 {
            for key in UserDefaults.standard.dictionaryRepresentation().keys {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        ServiceProvider.shared.namedKeyValueService.setAppGroup(nil)
    }

    func getTargetDataStore() -> NamedCollectionDataStore {
        return NamedCollectionDataStore(name: "com.adobe.module.target")
    }

    func getUserDefaults() -> UserDefaults {
        if let appGroup = ServiceProvider.shared.namedKeyValueService.getAppGroup(), !appGroup.isEmpty {
            return UserDefaults(suiteName: appGroup) ?? UserDefaults.standard
        }

        return UserDefaults.standard
    }

    func prettify(_ eventData: Any?) -> String {
        guard let eventData = eventData else {
            return ""
        }
        guard JSONSerialization.isValidJSONObject(eventData),
              let data = try? JSONSerialization.data(withJSONObject: eventData, options: .prettyPrinted),
              let prettyPrintedString = String(data: data, encoding: String.Encoding.utf8)
        else {
            return " \(eventData as AnyObject)"
        }
        return prettyPrintedString
    }

    func payloadAsDictionary(_ payload: String?) -> [String: Any]? {
        if let payload = payload, let data = payload.data(using: .utf8),
           let dictionary = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
        {
            return dictionary
        }
        return nil
    }

    func getQueryMap(url: String) -> [String: String] {
          let params: [String] = url.components(separatedBy: "&")
          var map = [String: String]()

          for string in params {
              let name = string.components(separatedBy: "=")[0]
              let value = string.components(separatedBy: "=")[1]
              map[name] = value
          }

          return map
      }
}
