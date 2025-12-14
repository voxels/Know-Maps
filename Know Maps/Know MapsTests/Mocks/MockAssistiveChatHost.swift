//
//  MockAssistiveChatHost.swift
//  Know MapsTests
//
//  Created for testing purposes
//

import Foundation
import CoreLocation
@testable import Know_Maps

@MainActor
final class MockAssistiveChatHost: AssistiveChatHost, @unchecked Sendable {
    weak var messagesDelegate: (any AssistiveChatHostMessagesDelegate)?
    var placeSearchSession: PlaceSearchSession
    var queryIntentParameters: AssistiveChatHostQueryParameters
    var categoryCodes: [[String : [[String : String]]]] = []
    
    // Configurable responses
    var mockIntent: AssistiveChatHostService.Intent = .Search
    var mockDefaultParameters: [String: Any]? = [:]
    var mockSection: PersonalizedSearchSection = .food
    var mockTags: AssistiveChatHostTaggedWord? = nil
    
    // Track method calls
    var determineIntentCalled: Bool = false
    var updateLastIntentParametersCalled: Bool = false
    var appendIntentParametersCalled: Bool = false
    var resetIntentParametersCalled: Bool = false
    var receiveMessageCalled: Bool = false
    var defaultParametersCalled: Bool = false
    
    required init(analyticsManager: AnalyticsService, messagesDelegate: (any AssistiveChatHostMessagesDelegate)?) {
        self.messagesDelegate = messagesDelegate
        self.placeSearchSession = PlaceSearchSession()
        self.queryIntentParameters = AssistiveChatHostQueryParameters()
    }
    
    func determineIntent(for caption: String, override: AssistiveChatHostService.Intent?) -> AssistiveChatHostService.Intent {
        determineIntentCalled = true
        return override ?? mockIntent
    }
        
    func defaultParameters(for query: String, filters: [String : Any]) async throws -> [String : Any]? {
        defaultParametersCalled = true
        return mockDefaultParameters
    }
    
    func tags(for rawQuery: String) throws -> AssistiveChatHostTaggedWord? {
        return mockTags
    }
    
    func section(for title: String) -> PersonalizedSearchSection {
        return mockSection
    }
}

