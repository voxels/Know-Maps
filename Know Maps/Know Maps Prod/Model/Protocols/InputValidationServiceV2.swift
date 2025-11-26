//
//  InputValidationServiceV2.swift
//  Know Maps
//
//  Protocol for validating and sanitizing user input queries
//

import Foundation

/// Service responsible for validating, sanitizing, and normalizing user input
@MainActor
public protocol InputValidationServiceV2 {
    /// Sanitizes a user-provided query string
    /// - Parameter query: Raw user input query
    /// - Returns: Sanitized query with normalized whitespace, removed control characters, and cleaned delimiters
    func sanitize(query: String) -> String

    /// Joins multiple search terms into a comma-separated string
    /// - Parameter searchTerms: Array of search term strings
    /// - Returns: Comma-separated string with trimmed terms and no whitespace
    func join(searchTerms: [String]) -> String

    /// Validates an AssistiveChatHostIntent for completeness and correctness
    /// - Parameter intent: The intent to validate
    /// - Returns: True if the intent is valid and can be processed, false otherwise
    func validate(intent: AssistiveChatHostIntent) -> Bool
}
