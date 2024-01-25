//
//  FeatureFlags.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 1/24/24.
//

import Foundation

open class FeatureFlags : ObservableObject {
    
    public let cloudCache:CloudCache
    
    public enum Flag : String {
        case hasPremiumSubscription
    }
    
    @Published public var features:[Flag:Bool] = [Flag.hasPremiumSubscription:true]
    
    public init(cloudCache: CloudCache) {
        self.cloudCache = cloudCache
    }
    
    public func owns(flag:FeatureFlags.Flag)->Bool{
        return features[flag] == true
    }
}
