//
//  MockInputValidationServiceV2.swift
//  knowmapsTests
//

import Foundation
@testable import Know_Maps

public final class MockInputValidationServiceV2: InputValidationServiceV2 {
    public var mockResult: String = ""
    public var lastValidatedInput: String?
    
    public func validate(input: String) -> String {
        lastValidatedInput = input
        return mockResult.isEmpty ? input : mockResult
    }
    
    public func sanitize(query: String) -> String {
        lastValidatedInput = query
        return mockResult.isEmpty ? query : mockResult
    }
    
    public func join(searchTerms: [String]) -> String {
        return searchTerms.joined(separator: " ")
    }
    
    public func validate(intent: AssistiveChatHostIntent) -> Bool {
        return true
    }
}
