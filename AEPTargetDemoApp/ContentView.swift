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

import AEPAssurance
import AEPCore
import AEPServices
import AEPTarget
import SwiftUI

struct ContentView: View {
    @State var thirdPartyId: String = ""
    @State var updatedThirdPartyId: String = ""
    @State var sessionId: String = ""
    @State var updatedSessionId: String = ""
    @State var tntId: String = ""
    @State var updatedTntId: String = ""
    @State var notificationTokens: [(String, String)] = []
    @State var griffonUrl: String = TestConstants.GRIFFON_URL
    @State var fullscreenMessage: FullscreenPresentable?
    let targetParameters = TargetParameters(parameters: ["mbox_parameter_key": "mbox_parameter_value"], profileParameters: ["profile_parameter_key": "profile_parameter_value"], order: TargetOrder(id: "223d24411", total: 445.12, purchasedProductIds: ["ppId1"]), product: TargetProduct(productId: "764334", categoryId: "Footwear"))
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .center, spacing: nil, content: {
                Section(header: CustomSectionHeader(title: "Assurance", bgColor: Color(UIColor.lightGray))) {
                    TextField("Griffon URL", text: $griffonUrl).multilineTextAlignment(.center)
                    Button("Connect to griffon") {
                        startGriffon()
                    }.padding(10)

                }
                Section(header: CustomSectionHeader(title: "Target APIs", bgColor: Color(UIColor.lightGray))) {
                    Group {
                        Button("Prefetch") {
                            prefetch()
                        }.padding(10)

                        Button("GetLocations (using contentCallback)") {
                            getLocations1()
                        }.padding(10)

                        Button("GetLocations (using contentWithDataCallback)") {
                            getLocations2()
                        }.padding(10)

                        Button("Locations displayed") {
                            locationDisplayed()
                        }.padding(10)

                        Button("Location clicked") {
                            locationClicked()
                        }.padding(10)

                        Button("Reset Experience") {
                            resetExperience()
                        }.padding(10)
                    }

                    Group {
                        Text("Session Id - \(sessionId)")
                        Button("Get Session Id") {
                            getSessionId()
                        }.padding(10)

                        TextField("Please enter Session Id", text: $updatedSessionId).multilineTextAlignment(.center)
                        Button("Set Session Id") {
                            setSessionId()
                        }.padding(10)
                        
                        Text("Third Party ID - \(thirdPartyId)")
                        Button("Get Third Party Id") {
                            getThirdPartyId()
                        }.padding(10)
                        
                        TextField("Please enter thirdPartyId", text: $updatedThirdPartyId).multilineTextAlignment(.center)
                        Button("Set Third Party Id") {
                            setThirdPartyId()
                        }.padding(10)
                    }
                    Group {
                        Text("Tnt id - \(tntId)")
                        Button("Get Tnt Id") {
                            getTntId()
                        }.padding(10)
                        
                        TextField("Please enter tntId", text: $updatedTntId).multilineTextAlignment(.center)
                        Button("Set Tnt Id") {
                            setTntId()
                        }.padding(10)

                        Button("Clear prefetch cache") {
                            clearPrefetchCache()
                        }.padding(10)

                        Button("Enter Preview") {
                            enterPreview()
                        }.padding(10)
                    }
                }
                Section(header: CustomSectionHeader(title: "Target Raw APIs", bgColor: Color(UIColor.lightGray))) {
                    Button("Execute Raw Request") {
                        executeRawRequest()
                    }.padding(10)

                    Button("Send Raw Notifications") {
                        sendRawNotifications()
                    }.padding(10)

                }
            })
        }
    }

    func startGriffon() {
        if let url = URL(string: griffonUrl) {
            Assurance.startSession(url: url)
        }
    }

    func prefetch() {
        Target.prefetchContent(
            [
                TargetPrefetch(name: "sdk_smoke_tests_target", targetParameters: nil),
                TargetPrefetch(name: "aep-loc-2", targetParameters: self.targetParameters),
            ],
            with: self.targetParameters,
            nil
        )
    }

    func getLocations1() {
        Target.retrieveLocationContent([TargetRequest(mboxName: "sdk_smoke_tests_target", defaultContent: "DefaultValue1", targetParameters: nil, contentCallback: { content in
            print("------")
            print("Content: \(content ?? "")")
        }),
                                        TargetRequest(mboxName: "aep-loc-2", defaultContent: "DefaultValue2", targetParameters: nil, contentCallback: { content in
            print("------")
            print("Content: \(content ?? "")")
        }),
                                        TargetRequest(mboxName: "sdk_smoke_tests_target_a4t", defaultContent: "DefaultValuex", targetParameters: self.targetParameters, contentCallback: { content in
            print("------")
            print("Content: \(content ?? "")")
        })],
                                       with: self.targetParameters
        )
    }

    func getLocations2() {
        Target.retrieveLocationContent([
            TargetRequest(mboxName: "sdk_smoke_tests_target", defaultContent: "DefaultValue1", targetParameters: nil, contentWithDataCallback: { content, data in
                print("------")
                print("Content: \(content ?? "")")

                let responseTokens = data?["responseTokens"] as? [String: Any] ?? [:]
                print("Response tokens: \(responseTokens as AnyObject)")

                let analyticsPayload = data?["analytics.payload"] as? [String: String] ?? [:]
                print("Analytics payload: \(analyticsPayload as AnyObject)")

                let clickAnalyticsPayload = data?["clickmetric.analytics.payload"] as? [String: String] ?? [:]
                print("Metrics Analytics payload (click): \(clickAnalyticsPayload as AnyObject)")
            }),
            TargetRequest(mboxName: "aep-loc-2", defaultContent: "DefaultValue2", targetParameters: nil, contentWithDataCallback: { content, data in
                print("------")
                print("Content: \(content ?? "")")

                let responseTokens = data?["responseTokens"] as? [String: Any] ?? [:]
                print("Response tokens: \(responseTokens as AnyObject)")

                let analyticsPayload = data?["analytics.payload"] as? [String: String] ?? [:]
                print("Analytics payload: \(analyticsPayload as AnyObject)")

                let clickAnalyticsPayload = data?["clickmetric.analytics.payload"] as? [String: String] ?? [:]
                print("Metrics Analytics payload (click): \(clickAnalyticsPayload as AnyObject)")
            }),
        ],
                                       with: TargetParameters(parameters: ["mbox_parameter_key": "mbox_parameter_value"], profileParameters: ["name": "Smith"], order: TargetOrder(id: "id1", total: 1.0, purchasedProductIds: ["ppId1"]), product: TargetProduct(productId: "pId1", categoryId: "cId1")))
    }

    func locationDisplayed() {
        Target.displayedLocations(["sdk_smoke_tests_target", "aep-loc-2", "sdk_smoke_tests_target_a4t"], targetParameters: self.targetParameters)
    }

    func locationClicked() {
        Target.clickedLocation("sdk_smoke_tests_target_a4t", targetParameters: self.targetParameters)
    }

    func resetExperience() {
        Target.resetExperience()
    }

    func clearPrefetchCache() {
        Target.clearPrefetchCache()
    }

    func getSessionId() {
        Target.getSessionId { id, err in
            if let id = id {
                self.sessionId = id
            }
            if let err = err {
                Log.error(label: "AEPTargetDemoApp", "Error: \(err)")
            }
        }
    }
    
    func setSessionId() {
        Target.setSessionId(updatedSessionId)
    }
    
    func getThirdPartyId() {
        Target.getThirdPartyId { id, err in
            if let id = id {
                self.thirdPartyId = id
            }
            if let err = err {
                Log.error(label: "AEPTargetDemoApp", "Error: \(err)")
            }
        }
    }

    func setThirdPartyId() {
        Target.setThirdPartyId(updatedThirdPartyId)
    }
    
    func getTntId() {
        Target.getTntId { id, err in
            if let id = id {
                self.tntId = id
            }
            if let err = err {
                Log.error(label: "AEPTargetDemoApp", "Error: \(err)")
            }
        }
    }

    func setTntId() {
        Target.setTntId(updatedTntId)
    }
    
    func enterPreview() {
        MobileCore.collectLaunchInfo(["adb_deeplink": TestConstants.DEEP_LINK])
    }
    
    func executeRawRequest() {
        Target.executeRawRequest([
            "property": [
                "token": ""
            ],
            "execute": [
                "mboxes": [
                    [
                        "index": 0,
                        "name": "sdk_smoke_tests_target",
                        "parameters": [
                            "mbox_parameter_key1": "mbox_parameter_value1"
                        ]
                    ],
                    [
                        "index": 1,
                        "name": "aep-loc-2",
                        "parameters": [
                            "mbox_parameter_key2": "mbox_parameter_value2"
                        ]
                    ]
                ]
            ]
        ]) { responseDict, err in
            if let err = err {
                print("Error: \(err.localizedDescription)")
                return
            }
            guard let responseDict = responseDict,
                  !responseDict.isEmpty else {
                return
            }
            print("Execute Raw Response:")
            print(PrettyDictionary.prettify(responseDict))
            guard let execute = responseDict["execute"] as? [String: Any], let executeMboxes = execute["mboxes"] as? [[String: Any]] else {
                return
            }
            
            for mbox in executeMboxes {
                if let mboxName = mbox["name"] as? String, let metrics = mbox["metrics"] as? [[String: Any]],
                    !metrics.isEmpty, let token = metrics[0]["eventToken"] as? String {
                    notificationTokens.append((mboxName, token))
                }
            }
        }
    }
    
    func sendRawNotifications() {
        var notifications: [[String: Any]] = []
        var i: Int = 0
        for token in notificationTokens {
            let notification: [String: Any] = [
                "id": String(i),
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000.0),
                "type": "click",
                "mbox": [
                    "name": token.0
                ],
                "tokens": [
                    token.1
                ],
                "parameters": [
                    "mbox_parameter_key3": "mbox_parameter_value3"
                ]
            ]
            notifications.append(notification)
            i += 1
        }
        guard !notifications.isEmpty else {
            return
        }
        Target.sendRawNotifications([
            "notifications": notifications
        ])
        notificationTokens.removeAll()
    }
}

struct CustomSectionHeader: View {
    let title: String
    let bgColor: Color

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text(title)
                Spacer()
            }
            Spacer()
        }
        .background(bgColor)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
