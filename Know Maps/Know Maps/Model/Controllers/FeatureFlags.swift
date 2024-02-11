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
        case hasPremiumSubscription
        case hasLimitedSubscription
        case hasAdSupportedSubscription
    }
    
    @Published public var features:[Flag:Bool] = [Flag:Bool]()
    
    public func owns(flag:FeatureFlags.Flag)->Bool{
        return features[flag] == true
    }
    
    public func update(flag:FeatureFlags.Flag, allowed:Bool){
        features[flag] = allowed
    }
    
    public func updateFlags(with customerInfo:CustomerInfo) {
        if customerInfo.entitlements["limited"]?.isActive == true {
            update(flag: .hasLimitedSubscription, allowed: true)
        }
        if customerInfo.entitlements["premium"]?.isActive == true {
            update(flag: .hasPremiumSubscription, allowed: true)
        }
        
        if !owns(flag: .hasLimitedSubscription) && !owns(flag: .hasLimitedSubscription) {
            update(flag: .hasAdSupportedSubscription, allowed: true)
        }
        
        update(flag: .hasPremiumSubscription, allowed: true)
    }
}

extension FeatureFlags : PurchasesDelegate {
    public func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        updateFlags(with: customerInfo)
    }
}
