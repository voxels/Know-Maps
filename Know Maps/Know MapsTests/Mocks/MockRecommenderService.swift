//
//  MockRecommenderService.swift
//  Know MapsTests
//
//  Created for testing purposes
//

import Foundation
@testable import Know_Maps_Prod

@MainActor
final class MockRecommenderService: RecommenderService, @unchecked Sendable {
    
    // Configurable responses
    var mockRecommendations: [String] = []
    
    // Track method calls if needed
    var recommendCalled: Bool = false
    
    // Add any required methods from RecommenderService protocol here
    // (Based on the actual protocol definition)
}
