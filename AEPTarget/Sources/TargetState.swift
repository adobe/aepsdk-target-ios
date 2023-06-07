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
    private(set) var prefetchedMboxJsonDicts = [String: [String: Any]]()
    private(set) var loadedMboxJsonDicts = [String: [String: Any]]()
    private(set) var notifications = [Notification]()

    private(set) var storedConfigurationSharedState: [String: Any]?

    private(set) var thirdPartyId: String?
    private(set) var tntId: String?
    private(set) var sessionTimestampInSeconds: Int64? {
        didSet {
            if sessionTimestampInSeconds == 0 {
                dataStore.remove(key: TargetConstants.DataStoreKeys.SESSION_TIMESTAMP)
            } else {
                dataStore.set(key: TargetConstants.DataStoreKeys.SESSION_TIMESTAMP, value: sessionTimestampInSeconds)
            }
        }
    }

    private(set) var storedSessionId: String {
        didSet {
            if storedSessionId.isEmpty {
                dataStore.remove(key: TargetConstants.DataStoreKeys.SESSION_ID)
            } else {
                dataStore.set(key: TargetConstants.DataStoreKeys.SESSION_ID, value: storedSessionId)
            }
        }
    }

    private let LOADED_MBOX_ACCEPTED_KEYS = [TargetConstants.TargetJson.Mbox.NAME, TargetConstants.TargetJson.METRICS]

    private var privacyStatus: String {
        return storedConfigurationSharedState?[TargetConstants.Configuration.SharedState.Keys.GLOBAL_CONFIG_PRIVACY] as? String
            ?? TargetConstants.Configuration.SharedState.Values.GLOBAL_CONFIG_PRIVACY_OPT_UNKNOWN
    }

    var sessionTimeoutInSeconds: Int {
        return storedConfigurationSharedState?[TargetConstants.Configuration.SharedState.Keys.TARGET_SESSION_TIMEOUT] as? Int ?? TargetConstants.DEFAULT_SESSION_TIMEOUT
    }

    var privacyStatusIsOptOut: Bool {
        return privacyStatus == TargetConstants.Configuration.SharedState.Values.GLOBAL_CONFIG_PRIVACY_OPT_OUT
    }

    var privacyStatusIsOptIn: Bool {
        return privacyStatus == TargetConstants.Configuration.SharedState.Values.GLOBAL_CONFIG_PRIVACY_OPT_IN
    }

    var clientCode: String? {
        return storedConfigurationSharedState?[TargetConstants.Configuration.SharedState.Keys.TARGET_CLIENT_CODE] as? String
    }

    var environmentId: Int {
        return storedConfigurationSharedState?[TargetConstants.Configuration.SharedState.Keys.TARGET_ENVIRONMENT_ID] as? Int ?? 0
    }

    var propertyToken: String {
        return storedConfigurationSharedState?[TargetConstants.Configuration.SharedState.Keys.TARGET_PROPERTY_TOKEN] as? String ?? ""
    }

    var targetServer: String? {
        return storedConfigurationSharedState?[TargetConstants.Configuration.SharedState.Keys.TARGET_SERVER] as? String
    }

    var networkTimeout: Double {
        guard let timeout = storedConfigurationSharedState?[TargetConstants.Configuration.SharedState.Keys.TARGET_NETWORK_TIMEOUT] as? Int else {
            return TargetConstants.NetworkConnection.DEFAULT_CONNECTION_TIMEOUT_SEC
        }

        return Double(timeout)
    }

    var sessionId: String {
        if storedSessionId.isEmpty || isSessionExpired() {
            storedSessionId = UUID().uuidString
            updateSessionTimestamp()
        }
        return storedSessionId
    }

    private(set) var storedEdgeHost: String?
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
        thirdPartyId = dataStore.getString(key: TargetConstants.DataStoreKeys.THIRD_PARTY_ID)
        storedEdgeHost = dataStore.getString(key: TargetConstants.DataStoreKeys.EDGE_HOST)
        sessionTimestampInSeconds = dataStore.getLong(key: TargetConstants.DataStoreKeys.SESSION_TIMESTAMP)
        storedSessionId = dataStore.getString(key: TargetConstants.DataStoreKeys.SESSION_ID) ?? ""
    }

    ///  Updates the stored configuration shared state if the given on is not nil.
    ///  If the given configuration shared state contains a new client code, the stored `edge host` will be set with an empty String.
    /// - Parameter configuration: the shared state of the `Configuration`
    func updateConfigurationSharedState(_ configuration: [String: Any]?) {
        guard let configuration = configuration else {
            return
        }
        if
            let newClientCode = configuration[TargetConstants.Configuration.SharedState.Keys.TARGET_CLIENT_CODE] as? String,
            storedConfigurationSharedState != nil, newClientCode != clientCode
        {
            updateEdgeHost(nil)
        }

        storedConfigurationSharedState = configuration
    }

    /// Updates the session timestamp of the latest target API call in memory and in the data store
    /// - Parameters:
    ///     - reset: `Bool` value to reset the timestamp to 0 and remove it from datastore
    func updateSessionTimestamp(reset: Bool = false) {
        if reset {
            sessionTimestampInSeconds = 0
            return
        }
        sessionTimestampInSeconds = Date().getUnixTimeInSeconds()
    }

    /// Updates stored sessionId with the provided value.
    ///
    /// - Parameter sessionId: string containing the new sessionId to be set
    func updateSessionId(_ sessionId: String) {
        storedSessionId = sessionId
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
                // Save click metrics, it will be used when sending notifications later.
                for key in mboxNode.keys where !LOADED_MBOX_ACCEPTED_KEYS.contains(key) {
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
