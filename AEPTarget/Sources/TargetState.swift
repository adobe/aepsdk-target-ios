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

import AEPServices
import Foundation

/// Represents the state of the `Target` extension
class TargetState {
    private(set) var thirdPartyId: String?
    private(set) var tntId: String?
    private(set) var sessionTimestampInSeconds: Int64?
    private(set) var clientCode: String?
    private(set) var prefetchedMboxJsonDicts = [String: [String: Any]]()
    private(set) var loadedMboxJsonDicts = [String: [String: Any]]()
    private(set) var notifications = [Notification]()
    var sessionTimeoutInSeconds: Int

    private var storedSessionId: String

    private let LOADED_MBOX_ACCEPTED_KEYS = [TargetConstants.TargetJson.Mbox.NAME, TargetConstants.TargetJson.METRICS]

    var sessionId: String {
        if storedSessionId.isEmpty || isSessionExpired() {
            storedSessionId = UUID().uuidString
            dataStore.set(key: TargetConstants.DataStoreKeys.SESSION_ID, value: storedSessionId)
            updateSessionTimestamp()
        }
        return storedSessionId
    }

    private var storedEdgeHost: String?
    var edgeHost: String? {
        if isSessionExpired() {
            updateEdgeHost(nil)
        }
        return storedEdgeHost
    }

    private let dataStore: NamedCollectionDataStore

    /// Loads the TNT ID and the edge host string from the data store when initializing the `TargetState` object
    init() {
        dataStore = NamedCollectionDataStore(name: TargetConstants.DATASTORE_NAME)
        tntId = dataStore.getString(key: TargetConstants.DataStoreKeys.TNT_ID)
        storedEdgeHost = dataStore.getString(key: TargetConstants.DataStoreKeys.EDGE_HOST)
        sessionTimestampInSeconds = dataStore.getLong(key: TargetConstants.DataStoreKeys.SESSION_TIMESTAMP)
        storedSessionId = dataStore.getString(key: TargetConstants.DataStoreKeys.SESSION_ID) ?? UUID().uuidString
        sessionTimeoutInSeconds = TargetConstants.DEFAULT_SESSION_TIMEOUT
    }

    func updateSessionTimeoutInSeconds(timeout: Int) {
        sessionTimeoutInSeconds = timeout
    }

    /// Updates the session timestamp of the latest target API call in memory and in the data store
    /// - Parameters:
    ///     - reset: `Bool` value to reset the timestamp to 0 and remove it from datastore
    func updateSessionTimestamp(reset: Bool = false) {
        if reset {
            sessionTimestampInSeconds = 0
            dataStore.remove(key: TargetConstants.DataStoreKeys.SESSION_TIMESTAMP)
            return
        }
        sessionTimestampInSeconds = Date().getUnixTimeInSeconds()
        dataStore.set(key: TargetConstants.DataStoreKeys.SESSION_TIMESTAMP, value: sessionTimestampInSeconds)
    }

    /// Remove storedSessionId and remove the key from datastore
    func resetSessionId() {
        dataStore.remove(key: TargetConstants.DataStoreKeys.SESSION_ID)
        storedSessionId = ""
    }

    /// Updates the TNT ID in memory and in the data store
    func updateTntId(_ tntId: String?) {
        self.tntId = tntId

        if let tntId = tntId, !tntId.isEmpty {
            dataStore.set(key: TargetConstants.DataStoreKeys.TNT_ID, value: tntId)
        } else {
            dataStore.remove(key: TargetConstants.DataStoreKeys.TNT_ID)
        }
    }

    /// Updates the Third party Id in memory and in the data store
    func updateThirdPartyId(_ thirdPartyId: String?) {
        self.thirdPartyId = thirdPartyId

        if let thirdPartyId = thirdPartyId, !thirdPartyId.isEmpty {
            dataStore.set(key: TargetConstants.DataStoreKeys.THIRD_PARTY_ID, value: thirdPartyId)
        } else {
            dataStore.remove(key: TargetConstants.DataStoreKeys.THIRD_PARTY_ID)
        }
    }

    /// Updates the edge host in memory and in the data store
    func updateEdgeHost(_ edgeHost: String?) {
        if edgeHost == storedEdgeHost {
            Log.debug(label: Target.LOG_TAG, "setEdgeHost - New edgeHost value is same as the existing edgeHost \(String(describing: edgeHost))")
            return
        }
        storedEdgeHost = edgeHost
        if let edgeHost = edgeHost, !edgeHost.isEmpty {
            dataStore.set(key: TargetConstants.DataStoreKeys.EDGE_HOST, value: edgeHost)
        } else {
            dataStore.remove(key: TargetConstants.DataStoreKeys.EDGE_HOST)
        }
    }

    /// Updates the client code in memory and in the data store
    func updateClientCode(_ clientCode: String) {
        self.clientCode = clientCode
    }

    /// Generates a `Target` shared state with the stored TNT ID and third party id.
    func generateSharedState() -> [String: Any] {
        var eventData = [String: Any]()
        if let tntId = tntId { eventData[TargetConstants.EventDataKeys.TNT_ID] = tntId }
        if let thirdPartyId = thirdPartyId { eventData[TargetConstants.EventDataKeys.THIRD_PARTY_ID] = thirdPartyId }
        return eventData
    }

    /// Combines the prefetched mboxes with the cached mboxes
    func mergePrefetchedMboxJson(mboxesDictionary: [String: [String: Any]]) {
        prefetchedMboxJsonDicts = prefetchedMboxJsonDicts.merging(mboxesDictionary) { _, new in new }
    }

    /// Combines the prefetched mboxes with the cached mboxes
    func saveLoadedMbox(mboxesDictionary: [String: [String: Any]]) {
        for mbox in mboxesDictionary {
            let name = mbox.key
            var mboxNode = mbox.value
            if !name.isEmpty, prefetchedMboxJsonDicts[name] == nil {
                // remove not accepted keys
                for key in LOADED_MBOX_ACCEPTED_KEYS {
                    mboxNode.removeValue(forKey: key)
                }
                loadedMboxJsonDicts[name] = mboxNode
            }
        }
    }

    func removeLoadedMbox(mboxName: String) {
        loadedMboxJsonDicts.removeValue(forKey: mboxName)
    }

    func addNotification(_ notification: Notification) {
        notifications.append(notification)
    }

    func clearNotifications() {
        notifications.removeAll()
    }

    func clearprefetchedMboxes() {
        prefetchedMboxJsonDicts.removeAll()
    }

    /// Verifies if current target session is expired.
    /// - Returns: whether Target session has expired
    private func isSessionExpired() -> Bool {
        guard let sessionTimestamp = sessionTimestampInSeconds else {
            return false
        }
        let currentTimestamp = Date().getUnixTimeInSeconds()
        return (currentTimestamp - sessionTimestamp) > sessionTimeoutInSeconds
    }
}
