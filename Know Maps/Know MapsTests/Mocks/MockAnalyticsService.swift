//
//  MockAnalyticsService.swift
//  Know MapsTests
//
//  Created for testing purposes
//

import Foundation
@testable import Know_Maps_Prod

@MainActor
final class MockAnalyticsService: AnalyticsService, @unchecked Sendable {
    
    // Track all events and errors for verification
    var trackedEvents: [(event: String, properties: [String: Any]?)] = []
    var trackedErrors: [(error: Error, additionalInfo: [String: Any]?)] = []
    
    func track(event: String, properties: [String : Any]?) {
        trackedEvents.append((event: event, properties: properties))
    }
    
    func trackError(error: Error, additionalInfo: [String : Any]?) {
        trackedErrors.append((error: error, additionalInfo: additionalInfo))
    }
    
    // Helper methods for testing
    func reset() {
        trackedEvents.removeAll()
        trackedErrors.removeAll()
    }
    
    func hasTrackedEvent(_ eventName: String) -> Bool {
        return trackedEvents.contains { $0.event == eventName }
    }
    
    func eventCount(for eventName: String) -> Int {
        return trackedEvents.filter { $0.event == eventName }.count
    }
    
    func properties(for eventName: String) -> [String: Any]? {
        return trackedEvents.first { $0.event == eventName }?.properties
    }
}
