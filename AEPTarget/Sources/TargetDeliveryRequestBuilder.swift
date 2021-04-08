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

enum TargetDeliveryRequestBuilder {
    private static var systemInfoService: SystemInfoService {
        ServiceProvider.shared.systemInfoService
    }

    /// Builds the `DeliveryRequest` object
    /// - Parameters:
    ///   - tntId: an UUID generated by the TNT server
    ///   - thirdPartyId: a string pointer containing the value of the third party id (custom visitor id)
    ///   - identitySharedState: the shared state of `Identity` extension
    ///   - lifecycleSharedState: the shared state of `Lifecycle` extension
    ///   - targetPrefetchArray: an array of ACPTargetPrefetch objects representing the desired mboxes to prefetch
    ///   - targetParameters: a TargetParameters object containing parameters for all the mboxes in the request array
    ///   - notifications: viewed mboxes that we cached
    ///   - environmentId: target environmentId
    ///   - propertyToken: String to be passed for all requests
    /// - Returns: a `DeliveryRequest` object
    static func build(tntId: String?, thirdPartyId: String?, identitySharedState: [String: Any]?, lifecycleSharedState: [String: Any]?, targetPrefetchArray: [TargetPrefetch]? = nil, targetRequestArray: [TargetRequest]? = nil, targetParameters: TargetParameters? = nil, notifications: [Notification]? = nil, environmentId: Int64 = 0, propertyToken: String? = nil) -> TargetDeliveryRequest? {
        let targetIDs = getTargetIDs(tntid: tntId, thirdPartyId: thirdPartyId, identitySharedState: identitySharedState)
        let experienceCloud = getExperienceCloudInfo(identitySharedState: identitySharedState)
        guard let context = getTargetContext() else {
            return nil
        }

        // prefetch
        var prefetch: Mboxes?
        if let tpArray: [TargetPrefetch] = targetPrefetchArray {
            prefetch = getPrefetch(targetPrefetchArray: tpArray, lifecycleSharedState: lifecycleSharedState, globalParameters: targetParameters) ?? nil
        }

        // prefetch
        var execute: Mboxes?
        if let trArray: [TargetRequest] = targetRequestArray {
            execute = getBatch(targetRequestArray: trArray, lifecycleSharedState: lifecycleSharedState, globalParameters: targetParameters) ?? nil
        }

        var property: Property?
        if let propertyToken = propertyToken, !propertyToken.isEmpty {
            property = Property(token: propertyToken)
        }

        return TargetDeliveryRequest(id: targetIDs, context: context, experienceCloud: experienceCloud, prefetch: prefetch, execute: execute, notifications: notifications, environmentId: environmentId, property: property)
    }

    /// Creates the display notification object
    /// - Parameters:
    ///  - mboxName: name of the mbox
    ///  - cachedMboxJson: the cached mbox
    ///  - parameters: TargetParameters object associated with the notification
    ///  - timestamp: timestamp associated with the event
    ///  - lifecycleContextData: payload for notification
    /// - Returns: Notification object
    static func getDisplayNotification(mboxName: String, cachedMboxJson: [String: Any]?, targetParameters: TargetParameters?, timestamp: Int64, lifecycleContextData: [String: String]?) -> Notification? {
        let id = UUID().uuidString

        // Set parameters: getMboxParameters
        let mboxParameters = getMboxParameters(mboxParameters: targetParameters?.parameters, lifecycleContextData: lifecycleContextData)

        // Set mbox
        guard let mboxState = cachedMboxJson?[TargetConstants.TargetJson.Mbox.STATE] as? String, !mboxState.isEmpty else {
            Log.debug(label: TargetDeliveryRequest.LOG_TAG, "Unable to get display notification, mbox state is invalid")
            return nil
        }
        let mbox = Mbox(name: mboxName, state: mboxState)

        // set token
        var tokens: [String] = []
        if let optionsArray = cachedMboxJson?[TargetConstants.TargetJson.OPTIONS] as? [[String: Any?]?] {
            for option in optionsArray {
                guard let optionEventToken = option?[TargetConstants.TargetJson.Metric.EVENT_TOKEN] as? String else {
                    continue
                }
                tokens.append(optionEventToken)
            }
        }

        if tokens.isEmpty {
            Log.debug(label: TargetDeliveryRequest.LOG_TAG, TargetError.ERROR_DISPLAY_NOTIFICATION_TOKEN_EMPTY)
            return nil
        }

        let notification = Notification(id: id, timestamp: timestamp, type: TargetConstants.TargetJson.MetricType.DISPLAY, mbox: mbox, tokens: tokens, parameters: mboxParameters, profileParameters: targetParameters?.profileParameters, order: targetParameters?.order?.toInternalOrder(), product: targetParameters?.product?.toInternalProduct())

        return notification
    }

    static func getClickedNotification(cachedMboxJson: [String: Any?], targetParameters: TargetParameters?, timestamp: Int64, lifecycleContextData: [String: String]?) -> Notification? {
        let id = UUID().uuidString

        // Set parameters: getMboxParameters
        let mboxparameters = getMboxParameters(mboxParameters: targetParameters?.parameters, lifecycleContextData: lifecycleContextData)

        let mboxName = cachedMboxJson[TargetConstants.TargetJson.Mbox.NAME] as? String ?? ""

        let mbox = Mbox(name: mboxName)

        guard let metrics = cachedMboxJson[TargetConstants.TargetJson.METRICS] as? [Any?] else {
            return Notification(id: id, timestamp: timestamp, type: TargetConstants.TargetJson.MetricType.CLICK, mbox: mbox, parameters: mboxparameters, profileParameters: targetParameters?.profileParameters, order: targetParameters?.order?.toInternalOrder(), product: targetParameters?.product?.toInternalProduct())
        }

        // set token
        var tokens: [String] = []
        for metricItem in metrics {
            guard let metric = metricItem as? [String: Any?], TargetConstants.TargetJson.MetricType.CLICK == metric[TargetConstants.TargetJson.Metric.TYPE] as? String, let token = metric[TargetConstants.TargetJson.Metric.EVENT_TOKEN] as? String, !token.isEmpty else {
                continue
            }

            tokens.append(token)
        }

        if tokens.isEmpty {
            Log.warning(label: Target.LOG_TAG, "\(TargetError.ERROR_CLICK_NOTIFICATION_CREATE_FAILED) \(cachedMboxJson.description)")
            return nil
        }

        return Notification(id: id, timestamp: timestamp, type: TargetConstants.TargetJson.MetricType.CLICK, mbox: mbox, tokens: tokens, parameters: mboxparameters, profileParameters: targetParameters?.profileParameters, order: targetParameters?.order?.toInternalOrder(), product: targetParameters?.product?.toInternalProduct())
    }

    /// Creates the mbox parameters with the provided lifecycle data.
    /// - Parameters:
    ///     - mboxParameters: the mbox parameters provided by the user
    ///     - lifecycleContextData: Lifecycle context  data
    /// - Returns: a dictionary [String: String]
    private static func getMboxParameters(mboxParameters: [String: String]?, lifecycleContextData: [String: Any]?) -> [String: String] {
        var mboxParametersCopy = mboxParameters ?? [:]

        let l = lifecycleContextData as? [String: String]
        mboxParametersCopy = merge(newDictionary: l, to: mboxParametersCopy) ?? [:]

        return mboxParametersCopy
    }

    /// Creates `TargetIDs` with the given tntId, thirdPartyId and the Identity's shared states
    /// - Parameters:
    ///   - tntid: `String` tnt id
    ///   - thirdPartyId: `String` third party id
    ///   - identitySharedState: `Identity` context  data
    /// - Returns: `TargetIDs` object
    static func getTargetIDs(tntid: String?, thirdPartyId: String?, identitySharedState: [String: Any]?) -> TargetIDs {
        var customerIds = [CustomerID]()
        if let visitorIds = identitySharedState?[TargetConstants.Identity.SharedState.Keys.VISITOR_IDS_LIST] as? [[String: Any]] {
            for visitorId in visitorIds {
                if let id = visitorId[TargetConstants.Identity.SharedState.Keys.VISITORID_ID] as? String,
                   let code = visitorId[TargetConstants.Identity.SharedState.Keys.VISITORID_TYPE] as? String,
                   let authenticatedState = visitorId[TargetConstants.Identity.SharedState.Keys.VISITORID_AUTHENTICATION_STATE] as? Int
                {
                    customerIds.append(CustomerID(id: id, integrationCode: code, authenticatedState: AuthenticatedState.from(state: authenticatedState)))
                }
            }
        }
        return TargetIDs(tntId: tntid, thirdPartyId: thirdPartyId,
                         marketingCloudVisitorId: identitySharedState?[TargetConstants.Identity.SharedState.Keys.VISITOR_ID_MID] as? String,
                         customerIds: customerIds.isEmpty ? nil : customerIds)
    }

    private static func getExperienceCloudInfo(identitySharedState: [String: Any]?) -> ExperienceCloudInfo {
        let analytics = AnalyticsInfo(logging: .client_side)
        if let identitySharedState = identitySharedState {
            let audienceManager = AudienceManagerInfo(blob: identitySharedState[TargetConstants.Identity.SharedState.Keys.VISITOR_ID_BLOB] as? String, locationHint: identitySharedState[TargetConstants.Identity.SharedState.Keys.VISITOR_ID_LOCATION_HINT] as? String)
            return ExperienceCloudInfo(audienceManager: audienceManager, analytics: analytics)
        }

        return ExperienceCloudInfo(audienceManager: nil, analytics: analytics)
    }

    private static func getTargetContext() -> TargetContext? {
        let deviceType: DeviceType = systemInfoService.getDeviceType() == AEPServices.DeviceType.PHONE ? .phone : .tablet
        let mobilePlatform = MobilePlatform(deviceName: systemInfoService.getDeviceName(), deviceType: deviceType, platformType: .ios)
        let application = AppInfo(id: systemInfoService.getApplicationBundleId(), name: systemInfoService.getApplicationName(), version: systemInfoService.getApplicationVersion())
        let orientation: DeviceOrientation = systemInfoService.getCurrentOrientation() == AEPServices.DeviceOrientation.LANDSCAPE ? .landscape : .portrait
        let screen = Screen(colorDepth: TargetConstants.TargetRequestValue.COLOR_DEPTH_32, width: systemInfoService.getDisplayInformation().width, height: systemInfoService.getDisplayInformation().height, orientation: orientation)
        return TargetContext(channel: TargetConstants.TargetRequestValue.CHANNEL_MOBILE, userAgent: systemInfoService.getDefaultUserAgent(), mobilePlatform: mobilePlatform, application: application, screen: screen, timeOffsetInMinutes: Date().getUnixTimeInSeconds())
    }

    private static func getPrefetch(targetPrefetchArray: [TargetPrefetch], lifecycleSharedState: [String: Any]?, globalParameters: TargetParameters?) -> Mboxes? {
        let lifecycleDataDict = lifecycleSharedState as? [String: String]

        var mboxes = [Mbox]()

        for (index, prefetch) in targetPrefetchArray.enumerated() {
            let parameterWithLifecycleData = merge(newDictionary: lifecycleDataDict, to: prefetch.targetParameters?.parameters)
            let parameters = merge(newDictionary: globalParameters?.parameters, to: parameterWithLifecycleData)
            let profileParameters = merge(newDictionary: globalParameters?.profileParameters, to: prefetch.targetParameters?.profileParameters)
            let order = getOrder(globalOrder: globalParameters?.order, order: prefetch.targetParameters?.order)
            let product = getProduct(product: prefetch.targetParameters?.product, globalProduct: globalParameters?.product)
            let mbox = Mbox(name: prefetch.name, index: index, parameters: parameters, profileParameters: profileParameters, order: order, product: product)
            mboxes.append(mbox)
        }
        return Mboxes(mboxes: mboxes)
    }

    private static func getBatch(targetRequestArray: [TargetRequest], lifecycleSharedState: [String: Any]?, globalParameters: TargetParameters?) -> Mboxes? {
        let lifecycleDataDict = lifecycleSharedState as? [String: String]

        var mboxes = [Mbox]()

        for (index, request) in targetRequestArray.enumerated() {
            let parameterWithLifecycleData = merge(newDictionary: lifecycleDataDict, to: request.targetParameters?.parameters)
            let parameters = merge(newDictionary: globalParameters?.parameters, to: parameterWithLifecycleData)
            let profileParameters = merge(newDictionary: globalParameters?.profileParameters, to: request.targetParameters?.profileParameters)
            let order = getOrder(globalOrder: globalParameters?.order, order: request.targetParameters?.order)
            let product = getProduct(product: request.targetParameters?.product, globalProduct: globalParameters?.product)
            let mbox = Mbox(name: request.name, index: index, parameters: parameters, profileParameters: profileParameters, order: order, product: product)
            mboxes.append(mbox)
        }
        return Mboxes(mboxes: mboxes)
    }

    /// Merges the given dictionaries, and only keeps values from the new dictionary for duplicated keys.
    /// - Parameters:
    ///   - newDictionary: the new dictionary
    ///   - dictionary: the original dictionary
    /// - Returns: a new dictionary with combined key-value pairs
    private static func merge(newDictionary: [String: String]?, to dictionary: [String: String]?) -> [String: String]? {
        guard let newDictionary = newDictionary else {
            return dictionary
        }
        guard let dictionary = dictionary else {
            return newDictionary
        }
        return dictionary.merging(newDictionary) { _, new in new }
    }

    private static func getOrder(globalOrder: TargetOrder?, order: TargetOrder?) -> Order? {
        if let globalOrder = globalOrder {
            return globalOrder.toInternalOrder()
        }
        if let order = order {
            return order.toInternalOrder()
        }
        return nil
    }

    private static func getProduct(product: TargetProduct?, globalProduct: TargetProduct?) -> Product? {
        if let globalProduct = globalProduct {
            return globalProduct.toInternalProduct()
        }
        if let product = product {
            return product.toInternalProduct()
        }
        return nil
    }
}
