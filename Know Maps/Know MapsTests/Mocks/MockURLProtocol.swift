//
//  MockURLProtocol.swift
//  Know MapsTests
//
//  Created for mocking URLSession network requests in tests
//

import Foundation

/// A mock URLProtocol that allows deterministic network request testing
/// without making actual HTTP calls.
///
/// Usage:
/// ```swift
/// // Configure mock responses
/// MockURLProtocol.responseHandler = { request in
///     let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
///     let data = """
///     {"results": []}
///     """.data(using: .utf8)!
///     return (response, data)
/// }
///
/// // Create URLSession with mock protocol
/// let config = URLSessionConfiguration.ephemeral
/// config.protocolClasses = [MockURLProtocol.self]
/// let mockSession = URLSession(configuration: config)
/// ```
final class MockURLProtocol: URLProtocol {

    // MARK: - Static Properties

    /// Handler for generating mock responses based on the request
    static var responseHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?

    /// Queue of pre-configured responses for sequential requests
    static var queuedResponses: [(HTTPURLResponse, Data?)] = []

    /// Queue of pre-configured errors for sequential requests
    static var queuedErrors: [Error] = []

    /// Tracks all requests made during testing
    static var requestHistory: [URLRequest] = []

    /// Count of requests made
    static var requestCount: Int {
        return requestHistory.count
    }

    /// Delay to simulate network latency (in seconds)
    static var networkDelay: TimeInterval = 0.0

    // MARK: - URLProtocol Overrides

    override class func canInit(with request: URLRequest) -> Bool {
        // Intercept all requests
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        // Return request as-is
        return request
    }

    override func startLoading() {
        // Track the request
        MockURLProtocol.requestHistory.append(request)

        // Simulate network delay if configured
        if MockURLProtocol.networkDelay > 0 {
            Thread.sleep(forTimeInterval: MockURLProtocol.networkDelay)
        }

        // Check for queued errors first
        if !MockURLProtocol.queuedErrors.isEmpty {
            let error = MockURLProtocol.queuedErrors.removeFirst()
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        // Check for queued responses
        if !MockURLProtocol.queuedResponses.isEmpty {
            let (response, data) = MockURLProtocol.queuedResponses.removeFirst()
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data = data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        // Use response handler if available
        guard let handler = MockURLProtocol.responseHandler else {
            fatalError("MockURLProtocol: No responseHandler or queued responses configured")
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data = data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        // No cleanup needed
    }

    // MARK: - Test Helpers

    /// Resets all mock state between tests
    static func reset() {
        responseHandler = nil
        queuedResponses = []
        queuedErrors = []
        requestHistory = []
        networkDelay = 0.0
    }

    /// Queues a successful response
    static func queueSuccess(statusCode: Int = 200, data: Data? = nil, headers: [String: String]? = nil) {
        let url = URL(string: "https://api.example.com")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headers
        )!
        queuedResponses.append((response, data))
    }

    /// Queues an error response
    static func queueError(_ error: Error) {
        queuedErrors.append(error)
    }

    /// Queues a network error (connection lost, timeout, etc.)
    static func queueNetworkError(code: URLError.Code = .networkConnectionLost) {
        queuedErrors.append(URLError(code))
    }

    /// Creates a URLSession configured to use MockURLProtocol
    static func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}

// MARK: - Convenience Extensions

extension MockURLProtocol {

    /// Helper to create JSON response data
    static func jsonData(_ dictionary: [String: Any]) -> Data? {
        try? JSONSerialization.data(withJSONObject: dictionary, options: [])
    }

    /// Helper to create JSON array response data
    static func jsonArrayData(_ array: [[String: Any]]) -> Data? {
        try? JSONSerialization.data(withJSONObject: array, options: [])
    }

    /// Verifies that a request was made to the expected URL
    static func verifyRequest(to urlString: String, method: String = "GET") -> Bool {
        return requestHistory.contains { request in
            request.url?.absoluteString.contains(urlString) == true &&
            request.httpMethod == method
        }
    }

    /// Returns the last request made (for verification)
    static var lastRequest: URLRequest? {
        return requestHistory.last
    }
}
