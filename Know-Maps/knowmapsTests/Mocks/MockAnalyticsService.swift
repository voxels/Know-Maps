//
//  MockAnalyticsService.swift
//  knowmapsTests
//

import Foundation
@testable import Know_Maps

public final class MockAnalyticsService: AnalyticsService {
    public var trackedEvents: [String] = []
    public var trackedErrors: [Error] = []
    public var identifiedUserID: String?
    
    public init() {}

    public func track(event: String, properties: [String : Any]?) {
        trackedEvents.append(event)
    }

    public func trackError(error: Error, additionalInfo: [String : Any]?) {
        trackedErrors.append(error)
    }

    public func trackCacheRefresh(cacheType: String, success: Bool, additionalInfo: [String : Any]?) {
        trackedEvents.append("cacheRefresh.\(cacheType).\(success)")
    }

    public func identify(userID: String) {
        identifiedUserID = userID
    }
}
