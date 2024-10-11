//
//  AnalyticsService.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/8/24.
//

import Foundation
import Segment

public protocol AnalyticsService : Sendable {
    // Track a generic event with optional properties
    func track(event: String, properties: [String: Any]?)
    
    // Track errors with detailed error description
    func trackError(error: Error, additionalInfo: [String: Any]?)
    
    // Track cache refreshes or updates
    func trackCacheRefresh(cacheType: String, success: Bool, additionalInfo: [String: Any]?)
    
    func identify(userID:String)
}
