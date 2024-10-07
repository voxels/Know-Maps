//
//  AnalyticsManager.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/7/24.
//

import Foundation
import Segment

public protocol AnalyticsService {
    // Track a generic event with optional properties
    func track(event: String, properties: [String: Any]?)
    
    // Track errors with detailed error description
    func trackError(error: Error, additionalInfo: [String: Any]?)
    
    // Track cache refreshes or updates
    func trackCacheRefresh(cacheType: String, success: Bool, additionalInfo: [String: Any]?)
    
    func identify(userID:String)
}

public final class SegmentAnalyticsManager: AnalyticsService {
    
    private var analytics: Analytics
    
    public init(analytics: Analytics) {
        self.analytics = analytics
    }
    
    public func identify(userID: String) {
        analytics.identify(userId: userID)
    }
    
    // MARK: - Track Event
    
    public func track(event: String, properties: [String: Any]? = nil) {
        analytics.track(name: event, properties: properties)
    }
    
    // MARK: - Track Error
    
    public func trackError(error: Error, additionalInfo: [String: Any]? = nil) {
        print(error)

        var properties: [String: Any] = ["errorDescription": error.localizedDescription]
        if let additionalInfo = additionalInfo {
            properties.merge(additionalInfo) { (_, new) in new }
        }
        track(event: "Error", properties: properties)
    }
    
    // MARK: - Track Cache Refresh
    
    public func trackCacheRefresh(cacheType: String, success: Bool, additionalInfo: [String: Any]?) {
        var properties: [String: Any] = [
            "cacheType": cacheType,
            "success": success
        ]
        if let additionalInfo = additionalInfo {
            properties.merge(additionalInfo) { (_, new) in new }
        }
        track(event: "CacheRefresh", properties: properties)
    }
}
