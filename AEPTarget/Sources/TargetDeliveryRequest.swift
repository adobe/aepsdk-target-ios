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

// MARK: - Delivery Request

/// Struct to represent Target Delivery API call's JSON request.
/// For more details refer to https://developers.adobetarget.com/api/delivery-api/#tag/Delivery-API
struct TargetDeliveryRequest: Codable {
    static let LOG_TAG = "TargetDeliveryRequest"

    var id: TargetIDs?
    var context: TargetContext
    var experienceCloud: ExperienceCloudInfo?
    var prefetch: Prefetch?
    var notifications: [Notification]?
    var environmentId: Int64
    var property: Property?

    init(id: TargetIDs? = nil, context: TargetContext, experienceCloud: ExperienceCloudInfo? = nil, prefetch: Prefetch? = nil, notifications: [Notification]? = nil, environmentId: Int64 = 0, property: Property? = nil) {
        self.id = id
        self.context = context
        self.experienceCloud = experienceCloud
        self.prefetch = prefetch
        self.notifications = notifications
        self.environmentId = environmentId
        self.property = property
    }

    func toJSON() -> String? {
        let jsonEncoder = JSONEncoder()
        guard let jsonData = try? jsonEncoder.encode(self) else {
            Log.warning(label: TargetDeliveryRequest.LOG_TAG, "Failed to encode the request object (as JSON): \(self) ")
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
}

// MARK: - Delivery Request - experienceCloud

struct ExperienceCloudInfo: Codable {
    var audienceManager: AudienceManagerInfo?
    var analytics: AnalyticsInfo?
}

struct AudienceManagerInfo: Codable {
    var blob: String?
    var locationHint: String?

    init?(blob: String?, locationHint: String?) {
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

    /// Constructs an `AuthenticatedState` enum using "VisitorAuthenticationState" from the Identity's shared states
    /// - Parameter state: the value of the "VisitorAuthenticationState" from the Identity's shared states
    /// - Returns: `AuthenticatedState` enum
    static func from(state: Int) -> AuthenticatedState {
        switch state {
        case 1:
            return .authenticated
        case 2:
            return .logged_out
        default:
            return .unknown
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
    var mboxes: [Mbox]
}

struct Mbox: Codable {
    var name: String
    var index: Int?
    var state: String?
    var parameters: [String: String]?
    var profileParameters: [String: String]?
    var order: Order?
    var product: Product?

    init(name: String, index: Int? = nil, state: String? = nil, parameters: [String: String]? = nil, profileParameters: [String: String]? = nil, order: Order? = nil, product: Product? = nil) {
        self.name = name
        self.index = index
        self.state = state
        self.profileParameters = profileParameters
        self.order = order
        self.product = product
        self.parameters = parameters
    }
}

struct Notification: Codable {
    var id: String
    var timestamp: Int64
    var type: String
    var mbox: Mbox
    var tokens: [String]?
    var parameters: [String: String]?
    var profileParameters: [String: String]?
    var order: Order?
    var product: Product?

    init(id: String, timestamp: Int64, type: String, mbox: Mbox, tokens: [String]? = nil, parameters: [String: String]? = nil, profileParameters: [String: String]? = nil, order: Order? = nil, product: Product? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.mbox = mbox
        self.tokens = tokens
        self.parameters = parameters
        self.profileParameters = profileParameters
        self.order = order
        self.product = product
    }
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

struct Property: Codable {
    var token: String?
}
