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

import ACPCore
import AEPAssurance
import AEPCore
import AEPIdentity
import AEPLifecycle
import AEPSignal
import AEPTarget
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        MobileCore.setLogLevel(.trace)
        MobileCore.registerExtensions([Lifecycle.self, Identity.self, Target.self, Signal.self])
        // https://experience.adobe.com/#/@obumobile5/launch/companies/COe866eac9a46b406fb25e1576ddb40375/properties/PRa0cdd30c31c1444ab6287bdbb5e28a65/overview
        MobileCore.configureWith(appId: "launch-ENc28aaf2fb6934cff830c8d3ddc5465b1-development")

        // register AEPAssurance
        AEPAssurance.registerExtension()
        // need to call `ACPCore.start` in order to get ACP* extensions registered to AEPCore
        ACPCore.start {}

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options _: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_: UIApplication, didDiscardSceneSessions _: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}
