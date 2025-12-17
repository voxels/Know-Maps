//
//  DefaultInputValidationServiceV2.swift
//  Know Maps
//
//  Default implementation of InputValidationServiceV2
//

import Foundation

@MainActor
@Observable
public final class DefaultInputValidationServiceV2: InputValidationServiceV2 {

    // MARK: - Constants

    private let maxQueryLength: Int

    // MARK: - Initialization

    public init(maxQueryLength: Int = 200) {
        self.maxQueryLength = maxQueryLength
    }

    // MARK: - InputValidationServiceV2

    /// Sanitizes a user-provided query string through 8 steps:
    /// 1. Normalize newlines/tabs to spaces
    /// 2. Remove ASCII control characters
    /// 3. Collapse multiple spaces
    /// 4. Clean up delimiter artifacts (=, or , ,)
    /// 5. Remove spaces around commas and equal signs
    /// 6. Remove dangling comma after equals
    /// 7. Final trim
    /// 8. Limit length to maxQueryLength
    public func sanitize(query: String) -> String {
        // 1) Normalize newlines/tabs to spaces
        var sanitized = query.replacingOccurrences(of: "\n", with: " ")
        sanitized = sanitized.replacingOccurrences(of: "\r", with: " ")
        sanitized = sanitized.replacingOccurrences(of: "\t", with: " ")

        // 2) Remove ASCII control characters (except standard whitespace)
        sanitized = sanitized.replacingOccurrences(of: "[\\u0000-\\u001F\\u007F]", with: "", options: .regularExpression)

        // 3) Collapse multiple spaces
        sanitized = sanitized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        // 4) Clean up awkward delimiter artifacts like '=,' or ', ,'
        //    - Replace '=,' with '=' (user likely meant `key=value` but typed a comma)
        //    - Replace ', ,' with ',' and then trim spaces around commas
        sanitized = sanitized.replacingOccurrences(of: "=\\s*,\\s*", with: "=", options: .regularExpression)
        sanitized = sanitized.replacingOccurrences(of: ",\\s*,\\s*", with: ",", options: .regularExpression)

        // 5) Remove spaces around commas and equal signs to avoid parsing ambiguity
        //    e.g. "query = , Arcade" -> "query=,Arcade" (we'll handle the comma next)
        sanitized = sanitized.replacingOccurrences(of: "\\s*,\\s*", with: ",", options: .regularExpression)
        sanitized = sanitized.replacingOccurrences(of: "\\s*=\\s*", with: "=", options: .regularExpression)

        // 6) If we end up with a dangling comma immediately after '=', remove that comma
        //    e.g. "query=,Arcade" -> "query=Arcade"
        sanitized = sanitized.replacingOccurrences(of: "=,", with: "=", options: .regularExpression)

        // 7) Final trim
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)

        // 8) Limit length to avoid excessively long inputs
        if sanitized.count > maxQueryLength {
            sanitized = String(sanitized.prefix(maxQueryLength))
        }

        return sanitized
    }

    /// Joins multiple search terms into a comma-separated string with no whitespace
    public func join(searchTerms: [String]) -> String {
        return searchTerms
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ",")
    }

    /// Validates an AssistiveChatHostIntent for basic completeness
    /// - Checks that caption is not empty
    /// - Checks that selectedDestinationLocation is valid
    /// - Checks that intent type is set
    public func validate(intent: AssistiveChatHostIntent) -> Bool {
        // Caption should not be empty after sanitization
        let sanitizedCaption = sanitize(query: intent.caption)
        guard !sanitizedCaption.isEmpty else {
            return false
        }

        // Selected destination location should have a valid name
        guard !intent.selectedDestinationLocation.locationName.isEmpty else {
            return false
        }

        // Intent type should be set (assuming .Search is valid default)
        // All intent types are valid as long as they're set
        return true
    }
}
