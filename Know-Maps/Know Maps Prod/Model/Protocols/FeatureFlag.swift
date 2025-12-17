//
//  FeatureFlag.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/8/24.
//

import Foundation
//import RevenueCat

// Define the protocol for feature flag management
public protocol FeatureFlag {
    associatedtype FlagType: Hashable

    var features: [FlagType: Bool] { get set }

    // Check if a flag is owned (enabled)
    func owns(flag: FlagType) -> Bool

    // Update a specific flag with a new state (allowed or not)
    func update(flag: FlagType, allowed: Bool)

    /*
    // Update flags based on CustomerInfo from RevenueCat
    func updateFlags(with customerInfo: CustomerInfo)

    // Update flags based on selected subscription plan
    func updateFlags(with selectedSubscription: SubscriptionPlan)
     */
}

/*
 // Extend the protocol to include PurchasesDelegate methods
 public protocol FeatureFlagsPurchasesDelegate: FeatureFlag, PurchasesDelegate {
 func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo)
 }
 */
