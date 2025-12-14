//
//  MockInputValidationServiceV2.swift
//  Know MapsTests
//
//  Mock implementation of InputValidationServiceV2 for testing
//

import Foundation
@testable import Know_Maps

@MainActor
public final class MockInputValidationServiceV2: InputValidationServiceV2 {

    // MARK: - Call Tracking

    public var sanitizeCalled = false
    public var joinCalled = false
    public var validateCalled = false

    public var lastSanitizedQuery: String?
    public var lastJoinedTerms: [String]?
    public var lastValidatedIntent: AssistiveChatHostIntent?

    public var sanitizeCallCount = 0
    public var joinCallCount = 0
    public var validateCallCount = 0

    // MARK: - Configurable Responses

    public var mockSanitizedResult: String = ""
    public var mockJoinedResult: String = ""
    public var mockValidationResult: Bool = true

    // MARK: - InputValidationServiceV2

    public func sanitize(query: String) -> String {
        sanitizeCalled = true
        sanitizeCallCount += 1
        lastSanitizedQuery = query
        return mockSanitizedResult.isEmpty ? query : mockSanitizedResult
    }

    public func join(searchTerms: [String]) -> String {
        joinCalled = true
        joinCallCount += 1
        lastJoinedTerms = searchTerms
        return mockJoinedResult.isEmpty ? searchTerms.joined(separator: ",") : mockJoinedResult
    }

    public func validate(intent: AssistiveChatHostIntent) -> Bool {
        validateCalled = true
        validateCallCount += 1
        lastValidatedIntent = intent
        return mockValidationResult
    }

    // MARK: - Test Helpers

    public func reset() {
        sanitizeCalled = false
        joinCalled = false
        validateCalled = false

        lastSanitizedQuery = nil
        lastJoinedTerms = nil
        lastValidatedIntent = nil

        sanitizeCallCount = 0
        joinCallCount = 0
        validateCallCount = 0

        mockSanitizedResult = ""
        mockJoinedResult = ""
        mockValidationResult = true
    }
}
