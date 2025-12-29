//
//  MockAssistiveChatHost.swift
//  knowmapsTests
//

import Foundation
@testable import Know_Maps

public final class MockAssistiveChatHost: AssistiveChatHost {
    public var categoryCodes: [[String : [[String : String]]]] = []
    public var queryIntentParameters: AssistiveChatHostQueryParameters = AssistiveChatHostQueryParameters()
    public var mockSection: PersonalizedSearchSection = .topPicks
    public var lastTaggedQuery: String?

    public init() {}
    
    public init(analyticsManager: AnalyticsService, messagesDelegate: AssistiveChatHostMessagesDelegate) {
        self.messagesDelegate = messagesDelegate
    }

    public func section(for title: String) async -> PersonalizedSearchSection { mockSection }
    
    public func tags(for rawQuery: String) async throws -> AssistiveChatHostTaggedWord? {
        lastTaggedQuery = rawQuery
        return nil
    }
    
    public func determineIntentEnhanced(for caption: String, override: AssistiveChatHostService.Intent?) async throws -> (AssistiveChatHostService.Intent, UnifiedSearchIntent?) {
        return (.Search, nil)
    }
    
    public func updateLastIntentParameters(intent: AssistiveChatHostIntent, modelController: ModelController) async {}
    
    public func appendIntentParameters(intent: AssistiveChatHostIntent, modelController: ModelController) async {}
    
    public func resetIntentParameters() async {}
    
    public func receiveMessage(caption: String, isLocalParticipant: Bool, filters: [String : String], modelController: ModelController, overrideIntent: AssistiveChatHostService.Intent?, selectedDestinationLocation: LocationResult?) async throws {}
    
    public func defaultParameters(for query: String, filters: [String : String], enrichedIntent: UnifiedSearchIntent?) async throws -> [String : Any]? {
        return nil
    }
    
    public func createIntent(for result: ChatResult, filters: [String : String], selectedDestination: LocationResult) async throws -> AssistiveChatHostIntent {
        // Return a dummy intent
        let request = IntentRequest(caption: result.title, intentType: .Place, enrichedIntent: nil, rawParameters: nil)
        let context = IntentContext(destination: selectedDestination)
        return await AssistiveChatHostIntent(request: request, context: context, fulfillment: IntentFulfillment())
    }
    
    public func updateLastIntent(caption: String, selectedDestinationLocation: LocationResult, filters: [String : String], modelController: ModelController) async throws {}
    
    public var messagesDelegate: any AssistiveChatHostMessagesDelegate = MockMessagesDelegate()
    public var placeSearchSession: PlaceSearchSession = PlaceSearchSession()
}

public final class MockMessagesDelegate: AssistiveChatHostMessagesDelegate {
    public init() {}
    public func addReceivedMessage(caption: String, parameters: AssistiveChatHostQueryParameters, isLocalParticipant: Bool, filters: [String : String], modelController: ModelController, overrideIntent: AssistiveChatHostService.Intent?, selectedDestinationLocation: LocationResult?) async throws {}
    public func updateQueryParametersHistory(with parameters: AssistiveChatHostQueryParameters, modelController: ModelController) async {}
}
