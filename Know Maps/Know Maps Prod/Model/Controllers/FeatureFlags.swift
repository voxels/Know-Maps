//
//  FeatureFlags.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 1/24/24.
//

import Foundation
import RevenueCat

open class FeatureFlags : NSObject, ObservableObject {
    
    public enum Flag : String {
        case hasMonthlySubscription
        case hasLimitedSubscription
        case hasFreeSubscription
    }
    
    @Published public var features:[Flag:Bool] = [Flag:Bool]()
    
    public func owns(flag:FeatureFlags.Flag)->Bool{
        return features[flag] == true
    }
    
    @MainActor
    public func update(flag:FeatureFlags.Flag, allowed:Bool){
        features[flag] = allowed
    }
    
    @MainActor
    public func updateFlags(with customerInfo:CustomerInfo) {
        if customerInfo.entitlements["limited"]?.isActive == true {
            update(flag: .hasLimitedSubscription, allowed: true)
        }
        if customerInfo.entitlements["monthly"]?.isActive == true {
            update(flag: .hasMonthlySubscription, allowed: true)
        }
        
        if !owns(flag: .hasLimitedSubscription) && !owns(flag: .hasLimitedSubscription) {
            update(flag: .hasFreeSubscription, allowed: true)
        }
    }
    
    @MainActor
    public func updateFlags(with selectedSubscription:SubscriptionPlan) {

        switch selectedSubscription.plan {
        case .limited:
            update(flag: .hasLimitedSubscription, allowed: true)
        case .monthly:
            update(flag: .hasMonthlySubscription, allowed: true)
        default:
            break
        }
    }
}

extension FeatureFlags : @preconcurrency PurchasesDelegate {
    @MainActor public func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        updateFlags(with: customerInfo)
    }
}
