//
//  NetworkIntegrationTests.swift
//  Know MapsTests
//
//  Created for testing network integration with MockURLProtocol
//

import XCTest
import CoreLocation
@testable import Know_Maps

// MARK: - Network Mocking Integration Tests

/// These tests demonstrate how to use MockURLProtocol to test network-dependent code
/// without making actual HTTP requests. This is Phase 2 of the unit test implementation.
@MainActor
final class NetworkIntegrationTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        // Reset MockURLProtocol before each test
        MockURLProtocol.reset()
    }

    override func tearDown() async throws {
        MockURLProtocol.reset()
        try await super.tearDown()
    }

    // MARK: - Example: Mocking Foursquare Place Search Response

    func testPlaceSearchWithMockedNetwork_returnsExpectedResults() async throws {
        // Given - Configure MockURLProtocol to return a mock Foursquare response
        let mockPlaceData = """
        {
            "results": [
                {
                    "fsq_id": "test-place-1",
                    "name": "Test Restaurant",
                    "geocodes": {
                        "main": {
                            "latitude": 37.7749,
                            "longitude": -122.4194
                        }
                    },
                    "categories": [
                        {
                            "id": 13065,
                            "name": "Restaurant"
                        }
                    ]
                }
            ]
        }
        """.data(using: .utf8)!

        MockURLProtocol.responseHandler = { request in
            // Verify the request is for Foursquare API
            XCTAssertTrue(
                request.url?.absoluteString.contains("foursquare") ?? false,
                "Should be making request to Foursquare API"
            )

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, mockPlaceData)
        }

        // When - Make a network request using the mocked session
        let mockSession = MockURLProtocol.makeMockSession()
        let url = URL(string: "https://api.foursquare.com/v3/places/search")!
        let (data, _) = try await mockSession.data(from: url)

        // Then - Verify the response was received
        XCTAssertNotNil(data, "Should receive mock data")
        XCTAssertGreaterThan(data.count, 0, "Data should not be empty")
    }

    // MARK: - Example: Testing Network Error Handling

    func testNetworkError_handlesGracefully() async throws {
        // Given - Configure MockURLProtocol to return a network error
        MockURLProtocol.queueNetworkError(code: .networkConnectionLost)

        // When/Then - Verify error is thrown
        let mockSession = MockURLProtocol.makeMockSession()
        let url = URL(string: "https://api.foursquare.com/v3/places/search")!

        do {
            _ = try await mockSession.data(from: url)
            XCTFail("Should throw network error")
        } catch {
            XCTAssertTrue(error is URLError, "Should be a URLError")
        }
    }

    // MARK: - Example: Testing with Queued Responses

    func testQueuedResponses_processedInOrder() async throws {
        // Given - Queue multiple responses
        let firstResponse = """
        {"results": [{"fsq_id": "1", "name": "First Place"}]}
        """.data(using: .utf8)!

        let secondResponse = """
        {"results": [{"fsq_id": "2", "name": "Second Place"}]}
        """.data(using: .utf8)!

        MockURLProtocol.queueSuccess(statusCode: 200, data: firstResponse)
        MockURLProtocol.queueSuccess(statusCode: 200, data: secondResponse)

        // When - Make two requests
        let mockSession = MockURLProtocol.makeMockSession()
        let url = URL(string: "https://api.foursquare.com/v3/places/search")!

        let (firstData, _) = try await mockSession.data(from: url)
        let (secondData, _) = try await mockSession.data(from: url)

        // Then - Verify responses were returned in order
        let firstString = String(data: firstData, encoding: .utf8)
        let secondString = String(data: secondData, encoding: .utf8)

        XCTAssertTrue(firstString?.contains("First Place") ?? false, "First request should return first response")
        XCTAssertTrue(secondString?.contains("Second Place") ?? false, "Second request should return second response")
    }

    // MARK: - Example: Verifying Request Parameters

    func testPlaceSearch_sendsCorrectQueryParameters() async throws {
        // Given
        MockURLProtocol.responseHandler = { request in
            // Verify query parameters
            guard let url = request.url,
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                XCTFail("Invalid URL")
                throw URLError(.badURL)
            }

            // Check for expected query parameters
            let queryItems = components.queryItems ?? []
            XCTAssertTrue(
                queryItems.contains { $0.name == "ll" },
                "Should include lat/lng parameter"
            )

            let mockData = """
            {"results": []}
            """.data(using: .utf8)!

            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, mockData)
        }

        // When
        let mockSession = MockURLProtocol.makeMockSession()
        let url = URL(string: "https://api.foursquare.com/v3/places/search?ll=37.7749,-122.4194")!
        _ = try await mockSession.data(from: url)

        // Then - Verify request was made
        XCTAssertTrue(
            MockURLProtocol.verifyRequest(to: "foursquare", method: "GET"),
            "Should have made GET request to Foursquare"
        )
    }

    // MARK: - Example: Testing Network Latency Simulation

    func testNetworkLatency_doesNotCauseTimeout() async throws {
        // Given - Configure network delay
        MockURLProtocol.networkDelay = 0.1 // 100ms delay

        let mockData = """
        {"results": []}
        """.data(using: .utf8)!

        MockURLProtocol.queueSuccess(statusCode: 200, data: mockData)

        // When
        let startTime = Date()
        let mockSession = MockURLProtocol.makeMockSession()
        let url = URL(string: "https://api.foursquare.com/v3/places/search")!
        _ = try await mockSession.data(from: url)
        let elapsed = Date().timeIntervalSince(startTime)

        // Then - Verify delay was applied
        XCTAssertGreaterThanOrEqual(elapsed, 0.1, "Should respect network delay")
    }

    // MARK: - Example: Testing Request History

    func testRequestHistory_tracksAllRequests() async throws {
        // Given
        let mockData = """
        {"results": []}
        """.data(using: .utf8)!

        MockURLProtocol.queueSuccess(statusCode: 200, data: mockData)
        MockURLProtocol.queueSuccess(statusCode: 200, data: mockData)

        // When - Make multiple requests
        let mockSession = MockURLProtocol.makeMockSession()
        let url1 = URL(string: "https://api.foursquare.com/v3/places/search")!
        let url2 = URL(string: "https://api.foursquare.com/v3/places/details")!

        _ = try await mockSession.data(from: url1)
        _ = try await mockSession.data(from: url2)

        // Then - Verify request history
        XCTAssertEqual(MockURLProtocol.requestCount, 2, "Should track 2 requests")
        XCTAssertNotNil(MockURLProtocol.lastRequest, "Should have last request")
        XCTAssertTrue(
            MockURLProtocol.lastRequest?.url?.absoluteString.contains("details") ?? false,
            "Last request should be to details endpoint"
        )
    }
}

// MARK: - CloudCache Integration Tests

@MainActor
final class CloudCacheIntegrationTests: XCTestCase {

    var mockCloudCacheService: MockCloudCacheService!
    var mockAnalytics: MockAnalyticsService!

    override func setUp() async throws {
        try await super.setUp()
        mockAnalytics = MockAnalyticsService()
        mockCloudCacheService = MockCloudCacheService(analyticsManager: mockAnalytics)
        MockCloudCacheService.reset()
        MockURLProtocol.reset()
    }

    override func tearDown() async throws {
        mockCloudCacheService = nil
        mockAnalytics = nil
        MockCloudCacheService.reset()
        MockURLProtocol.reset()
        try await super.tearDown()
    }

    func testFetchGroupedRecords_withMockData_returnsFilteredResults() async throws {
        // Given
        let record1 = UserCachedRecord()
        record1.identity = "test-1"
        record1.list = "favorites"

        let record2 = UserCachedRecord()
        record2.identity = "test-2"
        record2.list = "history"

        mockCloudCacheService.mockCachedRecords = [record1, record2]

        // When
        let favorites = try await mockCloudCacheService.fetchGroupedUserCachedRecords(for: "favorites")

        // Then
        XCTAssertEqual(favorites.count, 1, "Should return only favorites")
        XCTAssertEqual(favorites.first?.identity, "test-1", "Should return correct record")
    }

    func testStoreUserCachedRecord_addsRecordToMock() async throws {
        // Given
        XCTAssertEqual(mockCloudCacheService.mockCachedRecords.count, 0, "Should start empty")

        // When
        let success = try await mockCloudCacheService.storeUserCachedRecord(
            recordId: "rec-1",
            group: "favorites",
            identity: "place-1",
            title: "Test Place",
            icons: "🍕",
            list: "favorites",
            section: "food",
            rating: 4.0
        )

        // Then
        XCTAssertTrue(success, "Should succeed")
        XCTAssertEqual(mockCloudCacheService.mockCachedRecords.count, 1, "Should have 1 record")
        XCTAssertEqual(mockCloudCacheService.mockCachedRecords.first?.identity, "place-1", "Should store correct record")
    }

    func testUpdateUserCachedRecordRating_modifiesExistingRecord() async throws {
        // Given
        let record = UserCachedRecord()
        record.identity = "test-1"
        record.rating = 3
        mockCloudCacheService.mockCachedRecords = [record]

        // When
        try await mockCloudCacheService.updateUserCachedRecordRating(identity: "test-1", newRating: 5.0)

        // Then
        XCTAssertEqual(mockCloudCacheService.mockCachedRecords.first?.rating, 5, "Should update rating")
    }

    func testDeleteUserCachedRecord_removesRecord() async throws {
        // Given
        let record = UserCachedRecord()
        record.identity = "test-1"
        mockCloudCacheService.mockCachedRecords = [record]

        // When
        try await mockCloudCacheService.deleteUserCachedRecord(for: record)

        // Then
        XCTAssertEqual(mockCloudCacheService.mockCachedRecords.count, 0, "Should remove record")
    }

    func testFetchAllRecords_tracksCalls() async throws {
        // Given
        XCTAssertFalse(mockCloudCacheService.fetchAllRecordsCalled, "Should not be called initially")

        // When
        try await mockCloudCacheService.fetchAllRecords(recordTypes: ["UserCachedRecord", "RecommendationData"])

        // Then
        XCTAssertTrue(mockCloudCacheService.fetchAllRecordsCalled, "Should track call")
        XCTAssertEqual(
            mockCloudCacheService.requestedRecordTypes?.count,
            2,
            "Should track requested types"
        )
    }

    func testSession_returnsMockURLSession() async throws {
        // Given/When
        let session = try await mockCloudCacheService.session(service: "foursquare")

        // Then
        XCTAssertNotNil(session, "Should return a session")
        // Verify it's configured with MockURLProtocol
        let config = session.configuration
        XCTAssertTrue(
            config.protocolClasses?.contains(where: { $0 == MockURLProtocol.self }) ?? false,
            "Should be configured with MockURLProtocol"
        )
    }
}
