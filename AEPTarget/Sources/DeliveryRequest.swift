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
import AEPIdentity
import AEPServices
import Foundation

// MARK: - Delivery Request

/// Struct to represent Target Delivery API call's JSON request.
/// For more details refer to https://developers.adobetarget.com/api/delivery-api/#tag/Delivery-API
struct DeliveryRequest: Codable {
    static let LOG_TAG = "Target"

    var id: TargetIDs?
    var context: TargetContext
    var experienceCloud: ExperienceCloudInfo?
    var prefetch: Prefetch?

    func toJSON() -> String? {
        let jsonEncoder = JSONEncoder()
        guard let jsonData = try? jsonEncoder.encode(self) else {
            Log.error(label: DeliveryRequest.LOG_TAG, "Failed to encode the request object (as JSON): \(self) ")
            return nil
        }
        return String(data: jsonData, encoding: .utf8)
    }
}

// MARK: - Delivery Request - id

struct TargetIDs: Codable {
    var tntId: String?
    var thirdPartyId: String?
    var marketingCloudVisitorId: String?
    var customerIds: [CustomerID]?
}

struct CustomerID: Codable {
    var id: String
    var integrationCode: String
    var authenticatedState: AuthenticatedState

    /// Converts a `CustomIdentity` array to a `CustomerID` array
    /// - Parameter customIdentities: an array of `CustomIdentity` objects
    /// - Returns: an array of `CustomerID` objects
    static func from(customIdentities: [CustomIdentity]?) -> [CustomerID]? {
        guard let customIdentities = customIdentities else {
            return nil
        }

        var customerIDs = [CustomerID]()
        for customIdentity in customIdentities {
            guard let id = customIdentity.identifier, let code = customIdentity.type else {
                continue
            }
            customerIDs.append(CustomerID(id: id, integrationCode: code, authenticatedState: AuthenticatedState.from(authenticationState: customIdentity.authenticationState)))
        }
        return customerIDs
    }
}

// MARK: - Delivery Request - experienceCloud

struct ExperienceCloudInfo: Codable {
    var audienceManager: AudienceManagerInfo?
    var analytics: AnalyticsInfo?
}

struct AudienceManagerInfo: Codable {
    var blob: String?
    var locationHint: Int?

    init?(blob: String?, locationHint: Int?) {
        if blob == nil, locationHint == nil {
            return nil
        }
        self.blob = blob
        self.locationHint = locationHint
    }
}

struct AnalyticsInfo: Codable {
    var logging: AnalyticsLogging?
}

enum AnalyticsLogging: String, Codable {
    case client_side
}

enum AuthenticatedState: String, Codable {
    case unknown
    case authenticated
    case logged_out

    /// Converts a `MobileVisitorAuthenticationState` object to an `AuthenticatedState` object
    /// - Parameter authenticationState: a `MobileVisitorAuthenticationState` object
    /// - Returns: an `AuthenticatedState` object
    static func from(authenticationState: MobileVisitorAuthenticationState) -> AuthenticatedState {
        switch authenticationState {
        case .authenticated:
            return AuthenticatedState.authenticated
        case .loggedOut:
            return AuthenticatedState.logged_out
        default:
            return AuthenticatedState.unknown
        }
    }
}

// MARK: - Delivery Request - context

struct TargetContext: Codable {
    var channel: String
    var userAgent: String?
    var mobilePlatform: MobilePlatform?
    var application: AppInfo?
    var screen: Screen?
    var timeOffsetInMinutes: Int64?
}

struct Screen: Codable {
    var colorDepth: Int?
    var width: Int?
    var height: Int?
    var orientation: DeviceOrientation?
}

enum DeviceOrientation: String, Codable {
    case portrait
    case landscape
}

struct MobilePlatform: Codable {
    var deviceName: String?
    var deviceType: DeviceType
    var platformType: PlatformType
}

struct AppInfo: Codable {
    var id: String?
    var name: String?
    var version: String?
}

enum DeviceType: String, Codable {
    case phone
    case tablet
}

enum PlatformType: String, Codable {
    case android
    case ios
}

// MARK: - Delivery Request - prefetch

struct Prefetch: Codable {
    var mboxes: [Mbox]?
}

struct Mbox: Codable {
    var name: String?
    var index: Int
    var parameters: [String: String]?
    var profileParameters: [String: String]?
    var order: Order?
    var product: Product?
}

struct Notification: Codable {
    var id: String
    var timestamp: String
    var type: String
    var mbox: String?
}

struct Product: Codable {
    var id: String
    var categoryId: String?
}

struct Order: Codable {
    var id: String
    var total: Double?
    var purchasedProductIds: [String]?
}

// MARK: - DeliveryRequestBuilder

enum DeliveryRequestBuilder {
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
    /// - Returns: a `DeliveryRequest` object
    static func build(tntId: String?, thirdPartyId: String?, identitySharedState: [String: Any]?, lifecycleSharedState: [String: Any]?, targetPrefetchArray: [TargetPrefetch], targetParameters: TargetParameters?) -> DeliveryRequest? {
        let targetIDs = generateTargetIDsBy(tntid: tntId, thirdPartyId: thirdPartyId, identitySharedState: identitySharedState)
        let prefetch = generatePrefetchBy(targetPrefetchArray: targetPrefetchArray, lifecycleSharedState: lifecycleSharedState, globalParameters: targetParameters)
        let experienceCloud = generateExperienceCloudInfoBy(identitySharedState: identitySharedState)
        guard let context = generateTargetContextBy() else {
            return nil
        }
        return DeliveryRequest(id: targetIDs, context: context, experienceCloud: experienceCloud, prefetch: prefetch)
    }

    private static func generateTargetIDsBy(tntid: String?, thirdPartyId: String?, identitySharedState: [String: Any]?) -> TargetIDs? {
        let customerIds = identitySharedState?[TargetConstants.IDENTITY.SharedState.Keys.VISITOR_ID_MID] as? [CustomIdentity]
        return TargetIDs(tntId: tntid, thirdPartyId: thirdPartyId, marketingCloudVisitorId: identitySharedState?[TargetConstants.IDENTITY.SharedState.Keys.VISITOR_ID_MID] as? String, customerIds: CustomerID.from(customIdentities: customerIds))
    }

    private static func generateExperienceCloudInfoBy(identitySharedState: [String: Any]?) -> ExperienceCloudInfo? {
        guard let identitySharedState = identitySharedState else {
            return nil
        }
        let audienceManager = AudienceManagerInfo(blob: identitySharedState[TargetConstants.IDENTITY.SharedState.Keys.VISITOR_ID_BLOB] as? String, locationHint: identitySharedState[TargetConstants.IDENTITY.SharedState.Keys.VISITOR_ID_LOCATION_HINT] as? Int)
        let analytics = AnalyticsInfo(logging: .client_side)
        return ExperienceCloudInfo(audienceManager: audienceManager, analytics: analytics)
    }

    private static func generateTargetContextBy() -> TargetContext? {
        let deviceType: DeviceType = systemInfoService.getDeviceType() == AEPServices.DeviceType.PHONE ? .phone : .tablet
        let mobilePlatform = MobilePlatform(deviceName: systemInfoService.getDeviceName(), deviceType: deviceType, platformType: .ios)
        let application = AppInfo(id: systemInfoService.getApplicationBundleId(), name: systemInfoService.getApplicationName(), version: systemInfoService.getApplicationVersion())
        let orientation: DeviceOrientation = systemInfoService.getCurrentOrientation() == AEPServices.DeviceOrientation.LANDSCAPE ? .landscape : .portrait
        let screen = Screen(colorDepth: TargetConstants.TargetRequestValue.COLOR_DEPTH_32, width: systemInfoService.getDisplayInformation().width, height: systemInfoService.getDisplayInformation().height, orientation: orientation)
        return TargetContext(channel: TargetConstants.TargetRequestValue.CHANNEL_MOBILE, userAgent: systemInfoService.getDefaultUserAgent(), mobilePlatform: mobilePlatform, application: application, screen: screen, timeOffsetInMinutes: Date().getUnixTimeInSeconds())
    }

    private static func generatePrefetchBy(targetPrefetchArray: [TargetPrefetch], lifecycleSharedState: [String: Any]?, globalParameters: TargetParameters?) -> Prefetch? {
        let lifecycleDataDict = lifecycleSharedState as? [String: String]

        var mboxes = [Mbox]()

        for (index, prefetch) in targetPrefetchArray.enumerated() {
            let parameterWithLifecycleData = merge(newDictionary: lifecycleDataDict, to: prefetch.targetParameters?.parameters)
            let parameters = merge(newDictionary: globalParameters?.parameters, to: parameterWithLifecycleData)
            let profileParameters = merge(newDictionary: globalParameters?.profileParameters, to: prefetch.targetParameters?.profileParameters)
            let order = findFirstAvailableOrder(order: prefetch.targetParameters?.order, globalOrder: globalParameters?.order)
            let product = findFirstAvailableProduct(product: prefetch.targetParameters?.product, globalProduct: globalParameters?.product)
            let mbox = Mbox(name: prefetch.name, index: index, parameters: parameters, profileParameters: profileParameters, order: order, product: product)
            mboxes.append(mbox)
        }
        return Prefetch(mboxes: mboxes)
    }

    /// Merges the given dictionaries, and only keeps values from the new dictionary for duplicated keys.
    /// - Parameters:
    ///   - newDictionary: the new dictionary
    ///   - dictionary: the original dictionary
    /// - Returns: a new dictionary with combined key-value pairs
    private static func merge(newDictionary: [String: String]?, to dictionary: [String: String]?) -> [String: String]? {
        if let newDictionary = newDictionary, let dictionary = dictionary {
            return dictionary.merging(newDictionary) { _, new in new }
        }

        if let newDictionary = newDictionary {
            return newDictionary
        }

        if let dictionary = dictionary {
            return dictionary
        }

        return nil
    }

    private static func findFirstAvailableOrder(order: TargetOrder?, globalOrder: TargetOrder?) -> Order? {
        if let order = order {
            return order.toInternalOrder()
        }
        if let globalOrder = globalOrder {
            return globalOrder.toInternalOrder()
        }
        return nil
    }

    private static func findFirstAvailableProduct(product: TargetProduct?, globalProduct: TargetProduct?) -> Product? {
        if let product = product {
            return product.toInternalProduct()
        }
        if let globalProduct = globalProduct {
            return globalProduct.toInternalProduct()
        }
        return nil
    }
}
