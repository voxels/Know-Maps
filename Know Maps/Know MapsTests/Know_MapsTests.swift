//
//  ChatResultViewModelTests.swift
//  No Maps Tests
//
//  Created by Michael A Edgcumbe on 9/25/23.
//


import XCTest
import Segment
import CoreLocation
import MapKit
import CloudKit
import RevenueCat

@testable import Know_Maps

// Mock for the LanguageGenerator
final class MockLanguageGenerator: LanguageGenerator {
    
    // Variables to simulate different conditions
    var mockSearchQueryDescription: String?
    var mockPlaceDescription: String?
    var mockPlaceDescriptionError: Error?
    var mockLocationPlacemarks: [CLPlacemark]?
    var mockLocationNamePlacemarks: [CLPlacemark]?
    
    override public func searchQueryDescription(nearLocation: CLLocation) async throws -> String {
        if let description = mockSearchQueryDescription {
            return description
        }
        return "Default Search Query Description"
    }
    
    override public func placeDescription(with description: String, chatResult: ChatResult, delegate: AssistiveChatHostStreamResponseDelegate) async {
        // Simulate calling the delegate with the description
        await delegate.willReceiveStreamingResult(for: chatResult.id)
        await delegate.didReceiveStreamingResult(with: description, for: chatResult, promptTokens: 0, completionTokens: 0)
        await delegate.didFinishStreamingResult()
    }
    
    override public func placeDescription(chatResult: ChatResult, delegate: AssistiveChatHostStreamResponseDelegate) async throws {
        if let error = mockPlaceDescriptionError {
            throw error
        }
        if let description = mockPlaceDescription {
            await delegate.willReceiveStreamingResult(for: chatResult.id)
            await delegate.didReceiveStreamingResult(with: description, for: chatResult, promptTokens: 0, completionTokens: 0)
            await delegate.didFinishStreamingResult()
        } else {
            // Call the default method if no mock description
            try await super.placeDescription(chatResult: chatResult, delegate: delegate)
        }
    }
    
    override public func lookUpLocation(location: CLLocation) async throws -> [CLPlacemark]? {
        return mockLocationPlacemarks
    }
    
    override public func lookUpLocationName(name: String) async throws -> [CLPlacemark]? {
        return mockLocationNamePlacemarks
    }
}

// MARK: - Mock Delegate for AssistiveChatHostStreamResponseDelegate

final class MockAssistiveChatHostStreamResponseDelegate: AssistiveChatHostStreamResponseDelegate {
    
    var didReceiveStreamingResultCalled = false
    var receivedDescription: String?
    
    func willReceiveStreamingResult(for chatResultID: UUID) {
        // Mocked delegate call
    }
    
    func didReceiveStreamingResult(with string: String, for result: ChatResult, promptTokens: Int, completionTokens: Int) {
        didReceiveStreamingResultCalled = true
        receivedDescription = string
    }
    
    func didFinishStreamingResult() {
        // Mocked delegate call
    }
}

final class MockLocationProvider: LocationProvider {
    // Variables to simulate different conditions
    var mockAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    var mockLocation: CLLocation?
    var shouldFailWithError: Bool = false
    var mockError: Error?

    // Override methods to use the mock data instead of the actual CLLocationManager
    override public func isAuthorized() -> Bool {
        return mockAuthorizationStatus == .authorizedWhenInUse || mockAuthorizationStatus == .authorizedAlways
    }
    
    override public func authorize() {
        // Simulate authorization by setting the mock authorization status
        switch mockAuthorizationStatus {
        case .notDetermined:
            mockAuthorizationStatus = .authorizedWhenInUse
            NotificationCenter.default.post(name: Notification.Name("LocationProviderAuthorized"), object: nil)
        case .restricted, .denied:
            NotificationCenter.default.post(name: Notification.Name("LocationProviderDenied"), object: nil)
        default:
            break
        }
    }
    
    override public func currentLocation() -> CLLocation? {
        // Simulate fetching location based on authorization status
        if isAuthorized() {
            return mockLocation
        } else {
            authorize()
            return nil
        }
    }
}

final class LocationProviderTests: XCTestCase {
    
    var locationProvider: MockLocationProvider!

    override func setUp() {
        super.setUp()
        // Initialize the mock location provider
        locationProvider = MockLocationProvider()
    }

    override func tearDown() {
        locationProvider = nil
        super.tearDown()
    }

    // MARK: - Test Authorization

    func testAuthorizationWhenNotDetermined() {
        // Given: The authorization status is not determined
        locationProvider.mockAuthorizationStatus = .notDetermined
        
        // When: We check if it's authorized
        let isAuthorized = locationProvider.isAuthorized()
        
        // Then: It should return false
        XCTAssertFalse(isAuthorized)
    }

    func testAuthorizationWhenAuthorized() {
        // Given: The authorization status is authorized
        locationProvider.mockAuthorizationStatus = .authorizedWhenInUse
        
        // When: We check if it's authorized
        let isAuthorized = locationProvider.isAuthorized()
        
        // Then: It should return true
        XCTAssertTrue(isAuthorized)
    }

    func testAuthorizationRequest() {
        // Given: The authorization status is not determined
        locationProvider.mockAuthorizationStatus = .notDetermined
        
        // When: We call authorize
        locationProvider.authorize()
        
        // Then: The authorization status should be changed to authorized
        XCTAssertTrue(locationProvider.isAuthorized())
    }

    // MARK: - Test Location Fetching

    func testCurrentLocationWhenAuthorized() {
        // Given: The authorization status is authorized and a mock location
        locationProvider.mockAuthorizationStatus = .authorizedWhenInUse
        let mockLocation = CLLocation(latitude: 40.7128, longitude: -74.0060) // New York
        locationProvider.mockLocation = mockLocation
        
        // When: We call currentLocation
        let currentLocation = locationProvider.currentLocation()
        
        // Then: It should return the mock location
        XCTAssertEqual(currentLocation?.coordinate.latitude, mockLocation.coordinate.latitude)
        XCTAssertEqual(currentLocation?.coordinate.longitude, mockLocation.coordinate.longitude)
    }

    func testCurrentLocationWhenNotAuthorized() {
        // Given: The authorization status is not authorized
        locationProvider.mockAuthorizationStatus = .notDetermined
        
        // When: We call currentLocation
        let currentLocation = locationProvider.currentLocation()
        
        // Then: It should return nil
        XCTAssertNil(currentLocation)
    }

    // MARK: - Test Location Update Simulation

//    func testLocationUpdate() {
//        // Given: We have a mock location
//        let mockLocation = CLLocation(latitude: 34.0522, longitude: -118.2437) // Los Angeles
//
//        // When: We simulate a location update
//        locationProvider.simulateDidUpdateLocations([mockLocation])
//
//        // Then: The location should be the updated one
//        XCTAssertEqual(locationProvider.currentLocation()?.coordinate.latitude, mockLocation.coordinate.latitude)
//        XCTAssertEqual(locationProvider.currentLocation()?.coordinate.longitude, mockLocation.coordinate.longitude)
//    }

    // MARK: - Test Location Failure Simulation

//    func testLocationFailure() {
//        // Given: We simulate a failure with a mock error
//        let mockError = LocationProviderError.LocationManagerFailed
//
//        // When: We simulate the error
//        locationProvider.simulateDidFailWithError(mockError)
//
//        // Then: Check if the error is handled properly
//        XCTAssertTrue(locationProvider.shouldFailWithError)
//    }
}


final class LanguageGeneratorTests: XCTestCase {

    var languageGenerator: MockLanguageGenerator!
    var mockDelegate: MockAssistiveChatHostStreamResponseDelegate!

    override func setUp() {
        super.setUp()
        // Initialize the mock language generator and mock delegate
        languageGenerator = MockLanguageGenerator()
        mockDelegate = MockAssistiveChatHostStreamResponseDelegate()
    }

    override func tearDown() {
        languageGenerator = nil
        mockDelegate = nil
        super.tearDown()
    }

    // MARK: - Test Search Query Description

    func testSearchQueryDescription() async throws {
        // Given: A mock description for the search query
        let mockLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        languageGenerator.mockSearchQueryDescription = "Mock Search Query Description"
        
        // When: We call searchQueryDescription
        let description = try await languageGenerator.searchQueryDescription(nearLocation: mockLocation)
        
        // Then: The returned description should match the mock description
        XCTAssertEqual(description, "Mock Search Query Description")
    }

    // MARK: - Test Place Description with String

    func testPlaceDescriptionWithString() async {
        // Given: A mock description and a chat result
        let mockDescription = "This is a mock place description."
        let mockChatResult = ChatResult(title: "Test Place", placeResponse: nil, recommendedPlaceResponse: nil)
        
        // When: We call placeDescription(with:)
        await languageGenerator.placeDescription(with: mockDescription, chatResult: mockChatResult, delegate: mockDelegate)
        
        // Then: The mock delegate should have received the description
        XCTAssertTrue(mockDelegate.didReceiveStreamingResultCalled)
        XCTAssertEqual(mockDelegate.receivedDescription, mockDescription)
    }

    // MARK: - Test Place Description with Error

    func testPlaceDescriptionWithError() async throws {
        // Given: A mock error for place description
        let mockError = NSError(domain: "TestErrorDomain", code: 500, userInfo: nil)
        languageGenerator.mockPlaceDescriptionError = mockError
        
        // When: We call placeDescription and expect an error
        do {
            let mockChatResult = ChatResult(title: "Test Place", placeResponse: nil, recommendedPlaceResponse: nil)
            try await languageGenerator.placeDescription(chatResult: mockChatResult, delegate: mockDelegate)
            XCTFail("Expected error to be thrown, but it succeeded.")
        } catch {
            // Then: The thrown error should match the mock error
            XCTAssertEqual(error as NSError, mockError)
        }
    }

    // MARK: - Test Look Up Location

    func testLookUpLocation() async throws {
        // Given: A mock location and a mock placemark
        let mockLocation = CLLocation(latitude: 34.0522, longitude: -118.2437) // Los Angeles
        let mockPlacemark = CLPlacemark(placemark: MKPlacemark(coordinate: mockLocation.coordinate))
        languageGenerator.mockLocationPlacemarks = [mockPlacemark]
        
        // When: We call lookUpLocation
        let placemarks = try await languageGenerator.lookUpLocation(location: mockLocation)
        
        // Then: The returned placemarks should match the mock placemarks
        XCTAssertEqual(placemarks?.first?.location?.coordinate.latitude, mockLocation.coordinate.latitude)
        XCTAssertEqual(placemarks?.first?.location?.coordinate.longitude, mockLocation.coordinate.longitude)
    }
    
    // MARK: - Test Look Up Location by Name

    func testLookUpLocationName() async throws {
        // Given: A mock location name and a mock placemark
        let mockName = "Los Angeles"
        let mockLocation = CLLocation(latitude: 34.0522, longitude: -118.2437)
        let mockPlacemark = CLPlacemark(placemark: MKPlacemark(coordinate: mockLocation.coordinate))
        languageGenerator.mockLocationNamePlacemarks = [mockPlacemark]
        
        // When: We call lookUpLocationName
        let placemarks = try await languageGenerator.lookUpLocationName(name: mockName)
        
        // Then: The returned placemarks should match the mock placemarks
        XCTAssertEqual(placemarks?.first?.location?.coordinate.latitude, mockLocation.coordinate.latitude)
        XCTAssertEqual(placemarks?.first?.location?.coordinate.longitude, mockLocation.coordinate.longitude)
    }
}

final class MockCloudCache: CloudCache {

    // Variables to simulate different conditions
    var mockAPIKey: String?
    var mockResponse: Any?
    var mockError: Error?
    var mockFetchedRecords: [UserCachedRecord] = []
    var shouldThrowError: Bool = false
    var simulateSuccess: Bool = true
    
    override public func clearCache() {
        // Simulate clearing the cache
    }
    
    override public func fetch(url: URL, from cloudService: CloudCacheService) async throws -> Any {
        if let error = mockError {
            throw error
        }
        return mockResponse ?? ["mockKey": "mockValue"]
    }
    
    override public func fetchCloudKitUserRecordID() async throws -> CKRecord.ID? {
        if shouldThrowError {
            throw CloudCacheError.ServiceNotFound
        }
        return CKRecord.ID(recordName: "mockRecordID")
    }
    
    override public func fetchGroupedUserCachedRecords(for group: String) async throws -> [UserCachedRecord] {
        if shouldThrowError {
            throw CloudCacheError.ServerErrorMessage
        }
        return mockFetchedRecords
    }
    
    override public func apiKey(for service: CloudCacheService) async throws -> String {
        if shouldThrowError {
            throw CloudCacheError.ServiceNotFound
        }
        return mockAPIKey ?? "mockAPIKey"
    }
    
    override public func fetchGeneratedDescription(for fsqid: String) async throws -> String {
        if shouldThrowError {
            throw CloudCacheError.ServerErrorMessage
        }
        return "Mock description for \(fsqid)"
    }
    
    override public func storeGeneratedDescription(for fsqid: String, description: String) {
        // Simulate storing the description
    }
    
    override public func fetchFsqIdentity() async throws -> String {
        if shouldThrowError {
            throw CloudCacheError.ServiceNotFound
        }
        return "mockFsqIdentity"
    }
    
    override public func fetchToken(for fsqUserId: String) async throws -> String {
        if shouldThrowError {
            throw CloudCacheError.ServerErrorMessage
        }
        return "mockOAuthToken"
    }
    
    override public func storeFoursquareIdentityAndToken(for fsqUserId: String, oauthToken: String) {
        // Simulate storing Foursquare identity and token
    }
    
    override public func storeUserCachedRecord(for group: String, identity: String, title: String, icons: String? = nil, list: String? = nil) async throws -> String {
        if shouldThrowError {
            throw CloudCacheError.ServerErrorMessage
        }
        return "mockRecordID"
    }
    
    override public func deleteUserCachedRecord(for cachedRecord: UserCachedRecord) async throws {
        if shouldThrowError {
            throw CloudCacheError.ServerErrorMessage
        }
    }
    
    override public func deleteAllUserCachedRecords(for group: String) async throws -> (saveResults: [CKRecord.ID: Result<CKRecord, Error>], deleteResults: [CKRecord.ID: Result<Void, Error>]) {
        if shouldThrowError {
            throw CloudCacheError.ServerErrorMessage
        }
        return ([:], [:])
    }
    
    override public func deleteAllUserCachedGroups() async throws {
        if shouldThrowError {
            throw CloudCacheError.ServerErrorMessage
        }
    }
}

final class CloudCacheTests: XCTestCase {

    var cloudCache: MockCloudCache!

    override func setUp() {
        super.setUp()
        cloudCache = MockCloudCache()
    }

    override func tearDown() {
        cloudCache = nil
        super.tearDown()
    }

    // MARK: - Test Storing User Cached Record

    func testStoreUserCachedRecord() async throws {
        do {
            // When: We store a user cached record
            let recordId = try await cloudCache.storeUserCachedRecord(for: "Group1", identity: "Identity1", title: "Title1", icons: "mockIcons", list: "mockList")
            
            // Then: The returned record ID should match the mock record ID
            XCTAssertEqual(recordId, "mockRecordID")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testStoreUserCachedRecordFails() async throws {
        // Given: Simulate an error
        cloudCache.shouldThrowError = true

        // When/Then: We expect an error to be thrown
        do {
            _ = try await cloudCache.storeUserCachedRecord(for: "Group1", identity: "Identity1", title: "Title1", icons: "mockIcons", list: "mockList")
            XCTFail("Expected error, but got success.")
        } catch let error as CloudCacheError {
            XCTAssertEqual(error, .ServerErrorMessage)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Test Deleting User Cached Record

    func testDeleteUserCachedRecord() async throws {
        do {
            // Given: A mock user cached record
            let mockRecord = UserCachedRecord(recordId: "mockID", group: "Group1", identity: "Identity1", title: "Title1", icons: "mockIcons", list: nil)

            // When: We delete the user cached record
            try await cloudCache.deleteUserCachedRecord(for: mockRecord)

            // Then: Ensure no errors were thrown
            XCTAssertTrue(true) // If no error is thrown, the test passes
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDeleteUserCachedRecordFails() async throws {
        // Given: Simulate an error
        cloudCache.shouldThrowError = true
        let mockRecord = UserCachedRecord(recordId: "mockID", group: "Group1", identity: "Identity1", title: "Title1", icons: "mockIcons", list: nil)

        // When/Then: We expect an error to be thrown
        do {
            try await cloudCache.deleteUserCachedRecord(for: mockRecord)
            XCTFail("Expected error, but got success.")
        } catch let error as CloudCacheError {
            XCTAssertEqual(error, .ServerErrorMessage)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Test Deleting All User Cached Records for Group

    func testDeleteAllUserCachedRecords() async throws {
        do {
            // When: We delete all cached records for a group
            let result = try await cloudCache.deleteAllUserCachedRecords(for: "Group1")

            // Then: Ensure the save and delete results are empty
            XCTAssertTrue(result.saveResults.isEmpty)
            XCTAssertTrue(result.deleteResults.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDeleteAllUserCachedRecordsFails() async throws {
        // Given: Simulate an error
        cloudCache.shouldThrowError = true

        // When/Then: We expect an error to be thrown
        do {
            _ = try await cloudCache.deleteAllUserCachedRecords(for: "Group1")
            XCTFail("Expected error, but got success.")
        } catch let error as CloudCacheError {
            XCTAssertEqual(error, .ServerErrorMessage)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Test Fetching Token for FSQ User ID

    func testFetchTokenForFsqUserId() async throws {
        do {
            // Given: Mock token
            cloudCache.mockResponse = "mockOAuthToken"

            // When: We fetch the token for the FSQ user ID
            let token = try await cloudCache.fetchToken(for: "mockFsqUserId")

            // Then: The returned token should match the mock token
            XCTAssertEqual(token, "mockOAuthToken")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchTokenForFsqUserIdFails() async throws {
        // Given: Simulate an error
        cloudCache.shouldThrowError = true

        // When/Then: We expect an error to be thrown
        do {
            _ = try await cloudCache.fetchToken(for: "mockFsqUserId")
            XCTFail("Expected error, but got success.")
        } catch let error as CloudCacheError {
            XCTAssertEqual(error, .ServerErrorMessage)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Test Storing Foursquare Identity and Token

//    func testStoreFoursquareIdentityAndToken() async {
//        // When: We store the Foursquare identity and token
//        cloudCache.storeFoursquareIdentityAndToken(for: "mockFsqUserId", oauthToken: "mockOAuthToken")
//
//        // Then: Ensure the values are stored correctly
//        XCTAssertEqual(cloudCache.fsqUserId, "mockFsqUserId")
//        XCTAssertEqual(cloudCache.oauthToken, "mockOAuthToken")
//    }

    // MARK: - Test Deleting All User Cached Groups

    func testDeleteAllUserCachedGroups() async throws {
        do {
            // When: We delete all user cached groups
            try await cloudCache.deleteAllUserCachedGroups()

            // Then: Ensure no errors were thrown
            XCTAssertTrue(true) // If no error is thrown, the test passes
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDeleteAllUserCachedGroupsFails() async throws {
        // Given: Simulate an error
        cloudCache.shouldThrowError = true

        // When/Then: We expect an error to be thrown
        do {
            try await cloudCache.deleteAllUserCachedGroups()
            XCTFail("Expected error, but got success.")
        } catch let error as CloudCacheError {
            XCTAssertEqual(error, .ServerErrorMessage)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

final class MockFeatureFlags: FeatureFlags {
    
    var mockFeatures: [Flag: Bool] = [:]
    var mockCustomerInfo: CustomerInfo?
    
    override public func owns(flag: FeatureFlags.Flag) -> Bool {
        return mockFeatures[flag] == true
    }
    
    override public func update(flag: FeatureFlags.Flag, allowed: Bool) {
        mockFeatures[flag] = allowed
    }
    
    override public func updateFlags(with customerInfo: CustomerInfo) {
        self.mockCustomerInfo = customerInfo
        if customerInfo.entitlements["limited"]?.isActive == true {
            update(flag: .hasLimitedSubscription, allowed: true)
        }
        if customerInfo.entitlements["monthly"]?.isActive == true {
            update(flag: .hasMonthlySubscription, allowed: true)
        }
        if !owns(flag: .hasLimitedSubscription) && !owns(flag: .hasMonthlySubscription) {
            update(flag: .hasFreeSubscription, allowed: true)
        }
    }
    
    override public func updateFlags(with selectedSubscription: SubscriptionPlan) {
        switch selectedSubscription.plan {
        case .limited:
            update(flag: .hasLimitedSubscription, allowed: true)
        case .monthly:
            update(flag: .hasMonthlySubscription, allowed: true)
        default:
            break
        }
    }
}

final class FeatureFlagsTests: XCTestCase {

    var featureFlags: MockFeatureFlags!

    override func setUp() {
        super.setUp()
        featureFlags = MockFeatureFlags()
    }

    override func tearDown() {
        featureFlags = nil
        super.tearDown()
    }

    // MARK: - Test Owning Feature Flags

    func testOwningFeatureFlag() {
        // Given: A feature flag is set to true
        featureFlags.mockFeatures[.hasMonthlySubscription] = true
        
        // When: We check if the feature flag is owned
        let ownsFlag = featureFlags.owns(flag: .hasMonthlySubscription)
        
        // Then: It should return true
        XCTAssertTrue(ownsFlag)
    }

    func testNotOwningFeatureFlag() {
        // Given: A feature flag is not set or set to false
        featureFlags.mockFeatures[.hasMonthlySubscription] = false
        
        // When: We check if the feature flag is owned
        let ownsFlag = featureFlags.owns(flag: .hasMonthlySubscription)
        
        // Then: It should return false
        XCTAssertFalse(ownsFlag)
    }

    // MARK: - Test Updating Feature Flags

    func testUpdatingFeatureFlag() {
        // When: We update a feature flag
        featureFlags.update(flag: .hasMonthlySubscription, allowed: true)
        
        // Then: The feature flag should be updated to true
        XCTAssertTrue(featureFlags.mockFeatures[.hasMonthlySubscription] == true)
    }
//
//    // MARK: - Test Updating Flags with CustomerInfo
//
//    func testUpdateFlagsWithCustomerInfo() {
//        // Given: A mock CustomerInfo with entitlements for a limited subscription
//        let entitlements = EntitlementInfos(
//            entitlements: ["limited": EntitlementInfo(identifier: "limited", isActive: true, willRenew: true)]
//        )
//        let customerInfo = CustomerInfo(entitlements: entitlements)
//
//        // When: We update the flags with the customer info
//        featureFlags.updateFlags(with: customerInfo)
//
//        // Then: The limited subscription flag should be true
//        XCTAssertTrue(featureFlags.mockFeatures[.hasLimitedSubscription] == true)
//        XCTAssertFalse(featureFlags.owns(flag: .hasFreeSubscription)) // Should not be a free subscription
//    }
//
//    func testUpdateFlagsWithMonthlyCustomerInfo() {
//        // Given: A mock CustomerInfo with entitlements for a monthly subscription
//        let entitlements = EntitlementInfos(
//            entitlements: ["monthly": EntitlementInfo(identifier: "monthly", isActive: true, willRenew: true)]
//        )
//        let customerInfo = CustomerInfo(entitlements: entitlements)
//
//        // When: We update the flags with the customer info
//        featureFlags.updateFlags(with: customerInfo)
//
//        // Then: The monthly subscription flag should be true
//        XCTAssertTrue(featureFlags.mockFeatures[.hasMonthlySubscription] == true)
//    }
//
//    func testUpdateFlagsWithFreeSubscription() {
//        // Given: A mock CustomerInfo with no active entitlements
//        let entitlements = EntitlementInfos(entitlements: [:])
//        let customerInfo = CustomerInfo(entitlements: entitlements)
//
//        // When: We update the flags with the customer info
//        featureFlags.updateFlags(with: customerInfo)
//
//        // Then: The free subscription flag should be true
//        XCTAssertTrue(featureFlags.mockFeatures[.hasFreeSubscription] == true)
//    }

    // MARK: - Test Updating Flags with SubscriptionPlan

    func testUpdateFlagsWithLimitedSubscriptionPlan() {
        // Given: A limited subscription plan
        let limitedPlan = SubscriptionPlan(plan: .limited)
        
        // When: We update the flags with the subscription plan
        featureFlags.updateFlags(with: limitedPlan)
        
        // Then: The limited subscription flag should be true
        XCTAssertTrue(featureFlags.mockFeatures[.hasLimitedSubscription] == true)
    }

    func testUpdateFlagsWithMonthlySubscriptionPlan() {
        // Given: A monthly subscription plan
        let monthlyPlan = SubscriptionPlan(plan: .monthly)
        
        // When: We update the flags with the subscription plan
        featureFlags.updateFlags(with: monthlyPlan)
        
        // Then: The monthly subscription flag should be true
        XCTAssertTrue(featureFlags.mockFeatures[.hasMonthlySubscription] == true)
    }
}

// Mock PlaceSearchSession for testing
class MockPlaceSearchSession: PlaceSearchSession {
    
    var queryCalled = false
    var queryRequest: PlaceSearchRequest?
    var queryLocation: CLLocation?
    var mockQueryResult: [String: Any] = [:]
    
    override func query(request: PlaceSearchRequest, location: CLLocation?) async throws -> [String: Any] {
        queryCalled = true
        queryRequest = request
        queryLocation = location
        return mockQueryResult
    }
    
    var detailsCalled = false
    var detailsRequest: PlaceDetailsRequest?
    var mockDetailsResult: Any?
    
    override func details(for request: PlaceDetailsRequest) async throws -> Any {
        detailsCalled = true
        detailsRequest = request
        if let result = mockDetailsResult {
            return result
        }
        throw PlaceSearchSessionError.NoPlaceLocationsFound
    }
    
    var photosCalled = false
    var photosFsqID: String?
    var mockPhotosResult: Any?
    
    override func photos(for fsqID: String) async throws -> Any {
        photosCalled = true
        photosFsqID = fsqID
        if let result = mockPhotosResult {
            return result
        }
        throw PlaceSearchSessionError.NoPlaceLocationsFound
    }
    
    var tipsCalled = false
    var tipsFsqID: String?
    var mockTipsResult: Any?
    
    override func tips(for fsqID: String) async throws -> Any {
        tipsCalled = true
        tipsFsqID = fsqID
        if let result = mockTipsResult {
            return result
        }
        throw PlaceSearchSessionError.NoPlaceLocationsFound
    }
    
    var autocompleteCalled = false
    var autocompleteCaption: String?
    var autocompleteParameters: [String: Any]?
    var autocompleteLocation: CLLocation?
    var mockAutocompleteResult: [String: Any] = [:]
    
    override func autocomplete(caption: String, parameters: [String: Any]?, location: CLLocation) async throws -> [String: Any] {
        autocompleteCalled = true
        autocompleteCaption = caption
        autocompleteParameters = parameters
        autocompleteLocation = location
        return mockAutocompleteResult
    }
    
    var sessionCalled = false
    var mockSession: URLSession = URLSession(configuration: .default)
    
    override func session(service: String) async throws -> URLSession {
        sessionCalled = true
        return mockSession
    }
}

final class PlaceSearchSessionTests: XCTestCase {

    var mockSession: MockPlaceSearchSession!

    override func setUp() {
        super.setUp()
        mockSession = MockPlaceSearchSession()
    }

    func testQuery() async throws {
        // Arrange
        let request = PlaceSearchRequest(query: "Pizza", ll: nil, categories: nil, fields: nil, minPrice: 1, maxPrice: 4, openAt: nil, openNow: nil, nearLocation: nil, sort: nil, limit: 50)
        let location = CLLocation(latitude: 40.7128, longitude: -74.0060)
        mockSession.mockQueryResult = ["result": "test"]

        // Act
        let result = try await mockSession.query(request: request, location: location)

        // Assert
        XCTAssertTrue(mockSession.queryCalled)
        XCTAssertEqual(mockSession.queryRequest?.query, "Pizza")
        XCTAssertEqual(mockSession.queryLocation?.coordinate.latitude, location.coordinate.latitude)
        XCTAssertEqual(result["result"] as? String, "test")
    }

    func testDetails() async throws {
        // Arrange
        let request = PlaceDetailsRequest(fsqID: "test-fsqID", core: true, description: true, tel: false, fax: false, email: false, website: false, socialMedia: false, verified: false, hours: false, hoursPopular: false, rating: false, stats: false, popularity: false, price: false, menu: false, tastes: false, features: false)
        mockSession.mockDetailsResult = ["detail": "test"]

        // Act
        let result = try await mockSession.details(for: request)

        // Assert
        XCTAssertTrue(mockSession.detailsCalled)
        XCTAssertEqual(mockSession.detailsRequest?.fsqID, "test-fsqID")
        XCTAssertEqual((result as! [String: String])["detail"], "test")
    }

    func testPhotos() async throws {
        // Arrange
        mockSession.mockPhotosResult = ["photos": "test"]

        // Act
        let result = try await mockSession.photos(for: "test-fsqID")

        // Assert
        XCTAssertTrue(mockSession.photosCalled)
        XCTAssertEqual(mockSession.photosFsqID, "test-fsqID")
        XCTAssertEqual((result as! [String: String])["photos"], "test")
    }

    func testTips() async throws {
        // Arrange
        mockSession.mockTipsResult = ["tips": "test"]

        // Act
        let result = try await mockSession.tips(for: "test-fsqID")

        // Assert
        XCTAssertTrue(mockSession.tipsCalled)
        XCTAssertEqual(mockSession.tipsFsqID, "test-fsqID")
        XCTAssertEqual((result as! [String: String])["tips"], "test")
    }

    func testAutocomplete() async throws {
        // Arrange
        let location = CLLocation(latitude: 40.7128, longitude: -74.0060)
        mockSession.mockAutocompleteResult = ["autocomplete": "test"]

        // Act
        let result = try await mockSession.autocomplete(caption: "Pizza", parameters: nil, location: location)

        // Assert
        XCTAssertTrue(mockSession.autocompleteCalled)
        XCTAssertEqual(mockSession.autocompleteCaption, "Pizza")
        XCTAssertEqual(mockSession.autocompleteLocation?.coordinate.latitude, location.coordinate.latitude)
        XCTAssertEqual(result["autocomplete"] as? String, "test")
    }

    func testSession() async throws {
        // Act
        let session = try await mockSession.session(service: "foursquare")

        // Assert
        XCTAssertTrue(mockSession.sessionCalled)
        XCTAssertEqual(session.configuration, mockSession.mockSession.configuration)
    }
}

class MockPersonalizedSearchSession: PersonalizedSearchSession {
    
    var fetchManagedUserIdentityCalled = false
    var mockManagedUserIdentityResult: String?
    
    override func fetchManagedUserIdentity() async throws -> String? {
        fetchManagedUserIdentityCalled = true
        return mockManagedUserIdentityResult
    }
    
    var fetchManagedUserAccessTokenCalled = false
    var mockAccessTokenResult: String?
    
    override func fetchManagedUserAccessToken() async throws -> String {
        fetchManagedUserAccessTokenCalled = true
        if let token = mockAccessTokenResult {
            return token
        }
        throw PersonalizedSearchSessionError.NoTokenFound
    }
    
    var addFoursquareManagedUserIdentityCalled = false
    var mockAddIdentityResult = false
    
    override func addFoursquareManagedUserIdentity() async throws -> Bool {
        addFoursquareManagedUserIdentityCalled = true
        return mockAddIdentityResult
    }
    
    var autocompleteCalled = false
    var autocompleteCaption: String?
    var autocompleteParameters: [String: Any]?
    var autocompleteLocation: CLLocation?
    var mockAutocompleteResult: [String: Any] = [:]
    
    override func autocomplete(caption: String, parameters: [String: Any]?, location: CLLocation) async throws -> [String: Any] {
        autocompleteCalled = true
        autocompleteCaption = caption
        autocompleteParameters = parameters
        autocompleteLocation = location
        return mockAutocompleteResult
    }
    
    var autocompleteTastesCalled = false
    var autocompleteTastesCaption: String?
    var mockAutocompleteTastesResult: [String: Any] = [:]
    
    override func autocompleteTastes(caption: String, parameters: [String: Any]?) async throws -> [String: Any] {
        autocompleteTastesCalled = true
        autocompleteTastesCaption = caption
        return mockAutocompleteTastesResult
    }
    
    var fetchRecommendedVenuesCalled = false
    var mockRecommendedVenuesResult: [String: Any] = [:]
    
    override func fetchRecommendedVenues(with request: RecommendedPlaceSearchRequest, location: CLLocation?) async throws -> [String: Any] {
        fetchRecommendedVenuesCalled = true
        return mockRecommendedVenuesResult
    }
    
    var fetchTastesCalled = false
    var mockTastesResult: [String] = []
    
    override func fetchTastes(page: Int) async throws -> [String] {
        fetchTastesCalled = true
        return mockTastesResult
    }
    
    var fetchRelatedVenuesCalled = false
    var mockRelatedVenuesResult: [String: Any] = [:]
    
    override func fetchRelatedVenues(for fsqID: String) async throws -> [String: Any] {
        fetchRelatedVenuesCalled = true
        return mockRelatedVenuesResult
    }
}

final class PersonalizedSearchSessionTests: XCTestCase {

    var mockSession: MockPersonalizedSearchSession!

    override func setUp() {
        super.setUp()
        let mockCloudCache = CloudCache() // You may mock CloudCache as needed
        mockSession = MockPersonalizedSearchSession(cloudCache: mockCloudCache)
    }

    func testFetchManagedUserIdentity() async throws {
        // Arrange
        mockSession.mockManagedUserIdentityResult = "mock-user-id"

        // Act
        let result = try await mockSession.fetchManagedUserIdentity()

        // Assert
        XCTAssertTrue(mockSession.fetchManagedUserIdentityCalled)
        XCTAssertEqual(result, "mock-user-id")
    }

    func testFetchManagedUserAccessToken() async throws {
        // Arrange
        mockSession.mockAccessTokenResult = "mock-access-token"

        // Act
        let result = try await mockSession.fetchManagedUserAccessToken()

        // Assert
        XCTAssertTrue(mockSession.fetchManagedUserAccessTokenCalled)
        XCTAssertEqual(result, "mock-access-token")
    }

    func testFetchManagedUserAccessTokenNoTokenFound() async {
        // Arrange
        mockSession.mockAccessTokenResult = nil

        // Act & Assert
        do {
            _ = try await mockSession.fetchManagedUserAccessToken()
            XCTFail("Expected to throw NoTokenFound error")
        } catch {
            XCTAssertTrue(mockSession.fetchManagedUserAccessTokenCalled)
            XCTAssertEqual(error as? PersonalizedSearchSessionError, .NoTokenFound)
        }
    }

    func testAddFoursquareManagedUserIdentity() async throws {
        // Arrange
        mockSession.mockAddIdentityResult = true

        // Act
        let result = try await mockSession.addFoursquareManagedUserIdentity()

        // Assert
        XCTAssertTrue(mockSession.addFoursquareManagedUserIdentityCalled)
        XCTAssertTrue(result)
    }

    func testAutocomplete() async throws {
        // Arrange
        let location = CLLocation(latitude: 40.7128, longitude: -74.0060)
        mockSession.mockAutocompleteResult = ["autocomplete": "test"]

        // Act
        let result = try await mockSession.autocomplete(caption: "Pizza", parameters: nil, location: location)

        // Assert
        XCTAssertTrue(mockSession.autocompleteCalled)
        XCTAssertEqual(mockSession.autocompleteCaption, "Pizza")
        XCTAssertEqual(mockSession.autocompleteLocation?.coordinate.latitude, location.coordinate.latitude)
        XCTAssertEqual(result["autocomplete"] as? String, "test")
    }

    func testAutocompleteTastes() async throws {
        // Arrange
        mockSession.mockAutocompleteTastesResult = ["tastes": ["Spicy", "Cheesy"]]

        // Act
        let result = try await mockSession.autocompleteTastes(caption: "Chee", parameters: nil)

        // Assert
        XCTAssertTrue(mockSession.autocompleteTastesCalled)
        XCTAssertEqual(mockSession.autocompleteTastesCaption, "Chee")
        XCTAssertEqual(result["tastes"] as? [String], ["Spicy", "Cheesy"])
    }

    func testFetchRecommendedVenues() async throws {
        // Arrange
        let request = RecommendedPlaceSearchRequest(query: "test", ll: nil, radius: 1000, categories: "", minPrice: 1, maxPrice: 4, openNow: nil, nearLocation: nil, limit: 50, tags: [:])
        mockSession.mockRecommendedVenuesResult = ["venue": "test"]

        // Act
        let result = try await mockSession.fetchRecommendedVenues(with: request, location: nil)

        // Assert
        XCTAssertTrue(mockSession.fetchRecommendedVenuesCalled)
        XCTAssertEqual(result["venue"] as? String, "test")
    }

    func testFetchTastes() async throws {
        // Arrange
        mockSession.mockTastesResult = ["Taste1", "Taste2"]

        // Act
        let result = try await mockSession.fetchTastes(page: 1)

        // Assert
        XCTAssertTrue(mockSession.fetchTastesCalled)
        XCTAssertEqual(result, ["Taste1", "Taste2"])
    }

    func testFetchRelatedVenues() async throws {
        // Arrange
        mockSession.mockRelatedVenuesResult = ["relatedVenue": "test"]

        // Act
        let result = try await mockSession.fetchRelatedVenues(for: "test-fsqID")

        // Assert
        XCTAssertTrue(mockSession.fetchRelatedVenuesCalled)
        XCTAssertEqual(result["relatedVenue"] as? String, "test")
    }
}

final class AssistiveChatHostTests: XCTestCase {

    // MARK: - Properties

    var assistiveChatHost: AssistiveChatHost!
    var mockMessagesDelegate: MockChatResultViewModel!
    var mockLanguageDelegate: MockLanguageGenerator!
    var mockPlaceSearchSession: MockPlaceSearchSession!
    var mockCloudCache: MockCloudCache!

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()
        mockMessagesDelegate = MockAssistiveChatHostMessagesDelegate()
        mockLanguageDelegate = MockLanguageGenerator()
        mockPlaceSearchSession = MockPlaceSearchSession()
        mockCloudCache = MockCloudCache()

        assistiveChatHost = AssistiveChatHost(
            messagesDelegate: mockMessagesDelegate,
            analytics: mockAnalytics
        )
        assistiveChatHost.languageDelegate = mockLanguageDelegate
        assistiveChatHost.placeSearchSession = mockPlaceSearchSession
        assistiveChatHost.cloudCache = mockCloudCache
    }

    override func tearDown() {
        assistiveChatHost = nil
        mockMessagesDelegate = nil
        mockLanguageDelegate = nil
        mockPlaceSearchSession = nil
        mockCloudCache = nil
        super.tearDown()
    }

    // MARK: - Test Cases

    // MARK: organizeCategoryCodeList Tests

    func testOrganizeCategoryCodeList_Success() async {
        // Arrange
        var bundle = Bundle(for: type(of: self))
        guard let path = bundle.path(forResource: "integrated_category_taxonomy", ofType: "json") else {
            XCTFail("integrated_category_taxonomy.json not found")
            return
        }
        // Simulate the file in the main bundle
        Bundle.main = bundle

        // Act
        do {
            try await assistiveChatHost.organizeCategoryCodeList()
        } catch {
            XCTFail("organizeCategoryCodeList threw an error: \(error)")
        }

        // Assert
        XCTAssertFalse(assistiveChatHost.categoryCodes.isEmpty)
    }

    // MARK: determineIntent Tests

    func testDetermineIntent_ReturnsSearch_ForKnownCategory() {
        // Arrange
        assistiveChatHost.categoryCodes = [
            ["Food": [["category": "Pizza", "code": "123"]]]
        ]
        let caption = "Pizza near me"

        // Act
        let intent = assistiveChatHost.determineIntent(for: caption)

        // Assert
        XCTAssertEqual(intent, .Search)
    }

    func testDetermineIntent_ReturnsAutocompleteSearch_ForUnknownCategory() {
        // Arrange
        assistiveChatHost.categoryCodes = []
        let caption = "RandomQuery"

        // Act
        let intent = assistiveChatHost.determineIntent(for: caption)

        // Assert
        XCTAssertEqual(intent, .AutocompleteSearch)
    }

    // MARK: defaultParameters Tests

    func testDefaultParameters_ReturnsParameters() async {
        // Arrange
        let query = "Pizza near New York"
        mockCloudCache.hasPrivateCloudAccess = true
        mockLanguageDelegate.tagsStub = ["Pizza": ["CATEGORY"], "New York": ["PLACE"]]

        // Act
        var parameters: [String: Any]?
        do {
            parameters = try await assistiveChatHost.defaultParameters(for: query)
        } catch {
            XCTFail("defaultParameters threw an error: \(error)")
        }

        // Assert
        XCTAssertNotNil(parameters)
        XCTAssertEqual(parameters?["query"] as? String, "Pizza")
    }

    // MARK: updateLastIntent Tests

    func testUpdateLastIntent_UpdatesIntentParameters() async {
        // Arrange
        let caption = "Coffee shops near me"
        let locationID = UUID()
        assistiveChatHost.queryIntentParameters = AssistiveChatHostQueryParameters()
        let initialIntent = AssistiveChatHostIntent(caption: "Initial", intent: .Search)
        assistiveChatHost.queryIntentParameters?.queryIntents = [initialIntent]

        // Act
        do {
            try await assistiveChatHost.updateLastIntent(caption: caption, selectedDestinationLocationID: locationID)
        } catch {
            XCTFail("updateLastIntent threw an error: \(error)")
        }

        // Assert
        XCTAssertEqual(assistiveChatHost.queryIntentParameters?.queryIntents.last?.caption, caption)
        XCTAssertEqual(assistiveChatHost.queryIntentParameters?.queryIntents.last?.selectedDestinationLocationID, locationID)
    }

    // MARK: appendIntentParameters Tests

    func testAppendIntentParameters_AppendsNewIntent() {
        // Arrange
        assistiveChatHost.queryIntentParameters = AssistiveChatHostQueryParameters()
        let newIntent = AssistiveChatHostIntent(caption: "New Intent", intent: .Search)

        // Act
        assistiveChatHost.appendIntentParameters(intent: newIntent)

        // Assert
        XCTAssertEqual(assistiveChatHost.queryIntentParameters?.queryIntents.count, 1)
        XCTAssertEqual(assistiveChatHost.queryIntentParameters?.queryIntents.last?.caption, "New Intent")
    }

    // MARK: resetIntentParameters Tests

    func testResetIntentParameters_ClearsIntents() {
        // Arrange
        assistiveChatHost.queryIntentParameters = AssistiveChatHostQueryParameters()
        assistiveChatHost.queryIntentParameters?.queryIntents = [
            AssistiveChatHostIntent(caption: "Intent 1", intent: .Search),
            AssistiveChatHostIntent(caption: "Intent 2", intent: .Place)
        ]

        // Act
        assistiveChatHost.resetIntentParameters()

        // Assert
        XCTAssertTrue(assistiveChatHost.queryIntentParameters?.queryIntents.isEmpty ?? false)
    }

    // MARK: receiveMessage Tests

    func testReceiveMessage_CallsAddReceivedMessage() async {
        // Arrange
        let caption = "Hello"
        assistiveChatHost.queryIntentParameters = AssistiveChatHostQueryParameters()
        mockMessagesDelegate.addReceivedMessageExpectation = expectation(description: "addReceivedMessage called")

        // Act
        do {
            try await assistiveChatHost.receiveMessage(caption: caption, isLocalParticipant: true)
        } catch {
            XCTFail("receiveMessage threw an error: \(error)")
        }

        // Assert
        waitForExpectations(timeout: 1)
        XCTAssertEqual(mockMessagesDelegate.addReceivedMessageCaption, caption)
    }

    // MARK: nearLocation Tests

    func testNearLocation_ReturnsLocationString() {
        // Arrange
        let query = "Pizza near New York"

        // Act
        let location = assistiveChatHost.nearLocation(for: query)

        // Assert
        XCTAssertEqual(location, "New York")
    }

    func testNearLocation_ReturnsNil_WhenNoNearKeyword() {
        // Arrange
        let query = "Pizza in town"

        // Act
        let location = assistiveChatHost.nearLocation(for: query)

        // Assert
        XCTAssertNil(location)
    }

    // MARK: tags Tests

    func testTags_ReturnsTaggedWords() {
        // Arrange
        let query = "Pizza in New York"

        // Act
        var tags: AssistiveChatHostTaggedWord?
        do {
            tags = try assistiveChatHost.tags(for: query)
        } catch {
            XCTFail("tags threw an error: \(error)")
        }

        // Assert
        XCTAssertNotNil(tags)
        XCTAssertTrue(tags?.keys.contains("Pizza") ?? false)
        XCTAssertTrue(tags?.keys.contains("New York") ?? false)
    }

    // MARK: lastLocationIntent Tests

    func testLastLocationIntent_ReturnsLastLocationIntent() {
        // Arrange
        let locationIntent = AssistiveChatHostIntent(caption: "Location", intent: .Location)
        let searchIntent = AssistiveChatHostIntent(caption: "Search", intent: .Search)
        assistiveChatHost.queryIntentParameters = AssistiveChatHostQueryParameters()
        assistiveChatHost.queryIntentParameters?.queryIntents = [searchIntent, locationIntent]

        // Act
        let lastIntent = assistiveChatHost.lastLocationIntent()

        // Assert
        XCTAssertEqual(lastIntent?.intent, .Location)
    }

    // MARK: parsedQuery Tests

    func testParsedQuery_ReturnsParsedQuery() {
        // Arrange
        let query = "Find a cheap pizza place near me"
        let tags: AssistiveChatHostTaggedWord = [
            "cheap": ["Adjective"],
            "pizza": ["CATEGORY"],
            "place": ["Noun"]
        ]

        // Act
        let parsedQuery = assistiveChatHost.parsedQuery(for: query, tags: tags)

        // Assert
        XCTAssertEqual(parsedQuery, "cheap pizza place")
    }

    // MARK: radius Tests

    func testRadius_Returns1000_WhenQueryContainsNearby() {
        // Arrange
        let query = "Restaurants nearby"

        // Act
        let radius = assistiveChatHost.radius(for: query)

        // Assert
        XCTAssertEqual(radius, 1000)
    }

    func testRadius_ReturnsNil_WhenNoRadiusKeyword() {
        // Arrange
        let query = "Restaurants in town"

        // Act
        let radius = assistiveChatHost.radius(for: query)

        // Assert
        XCTAssertNil(radius)
    }

    // MARK: minPrice Tests

    func testMinPrice_Returns3_WhenQueryContainsExpensive() {
        // Arrange
        let query = "Looking for an expensive restaurant"

        // Act
        let minPrice = assistiveChatHost.minPrice(for: query)

        // Assert
        XCTAssertEqual(minPrice, 3)
    }

    func testMinPrice_ReturnsNil_WhenNoPriceKeyword() {
        // Arrange
        let query = "Looking for a restaurant"

        // Act
        let minPrice = assistiveChatHost.minPrice(for: query)

        // Assert
        XCTAssertNil(minPrice)
    }

    // MARK: maxPrice Tests

    func testMaxPrice_Returns2_WhenQueryContainsCheap() {
        // Arrange
        let query = "Looking for a cheap place to eat"

        // Act
        let maxPrice = assistiveChatHost.maxPrice(for: query)

        // Assert
        XCTAssertEqual(maxPrice, 2)
    }

    // MARK: openNow Tests

    func testOpenNow_ReturnsTrue_WhenQueryContainsOpenNow() {
        // Arrange
        let query = "Find a bar open now"

        // Act
        let openNow = assistiveChatHost.openNow(for: query)

        // Assert
        XCTAssertTrue(openNow ?? false)
    }

    // MARK: categoryCodes Tests

    func testCategoryCodes_ReturnsCodes() {
        // Arrange
        assistiveChatHost.categoryCodes = [
            ["Food": [["category": "Pizza", "code": "123"]]]
        ]
        let query = "Pizza"

        // Act
        let codes = assistiveChatHost.categoryCodes(for: query)

        // Assert
        XCTAssertEqual(codes, ["123"])
    }

    // MARK: placeDescription Tests

    func testPlaceDescription_UsesCachedDescription() async {
        // Arrange
        let placeResponse = PlaceSearchResponse(fsqID: "1", name: "Test Place")
        let chatResult = ChatResult(title: "Test Place", placeResponse: placeResponse)
        mockCloudCache.generatedDescriptionStub = "Cached Description"
        mockAnalytics.trackCalled = false

        // Act
        do {
            try await assistiveChatHost.placeDescription(chatResult: chatResult, delegate: mockMessagesDelegate)
        } catch {
            XCTFail("placeDescription threw an error: \(error)")
        }

        // Assert
        XCTAssertTrue(mockAnalytics.trackCalled)
        XCTAssertEqual(mockAnalytics.trackName, "usingCachedGPTDescription")
    }

    func testPlaceDescription_GeneratesDescription_WhenNoCache() async {
        // Arrange
        let placeResponse = PlaceSearchResponse(fsqID: "1", name: "Test Place")
        let chatResult = ChatResult(title: "Test Place", placeResponse: placeResponse)
        mockCloudCache.generatedDescriptionStub = ""
        mockAnalytics.trackCalled = false

        // Act
        do {
            try await assistiveChatHost.placeDescription(chatResult: chatResult, delegate: mockMessagesDelegate)
        } catch {
            XCTFail("placeDescription threw an error: \(error)")
        }

        // Assert
        XCTAssertFalse(mockAnalytics.trackCalled)
        XCTAssertTrue(mockLanguageDelegate.placeDescriptionCalled)
    }

    // MARK: searchQueryDescription Tests

    func testSearchQueryDescription_ReturnsDescription() async {
        // Arrange
        let location = CLLocation(latitude: 0, longitude: 0)
        mockLanguageDelegate.searchQueryDescriptionStub = "Search Description"

        // Act
        var description: String?
        do {
            description = try await assistiveChatHost.searchQueryDescription(nearLocation: location)
        } catch {
            XCTFail("searchQueryDescription threw an error: \(error)")
        }

        // Assert
        XCTAssertEqual(description, "Search Description")
    }

    // MARK: fireTimer Tests

    func testFireTimer_DoesNotCrash() {
        // Arrange

        // Act
        assistiveChatHost.fireTimer()

        // Assert
        // No crash
    }

    // MARK: nearLocationCoordinate Tests

    func testNearLocationCoordinate_ReturnsPlacemarks() async {
        // Arrange
        let query = "Pizza near New York"
        let expectedPlacemark = CLPlacemark()
        mockLanguageDelegate.geocodeAddressStringStub = [expectedPlacemark]

   

final class ChatResultViewModelTests: XCTestCase {

    // MARK: - Properties

    var viewModel: ChatResultViewModel!
    var mockAssistiveHostDelegate: MockAssistiveChatHostDelegate!
    var mockLocationProvider: MockLocationProvider!
    var mockCloudCache: MockCloudCache!
    var mockFeatureFlags: FeatureFlags!
    var mockAnalytics: MockAnalytics!
    var mockPlaceSearchSession: MockPlaceSearchSession!
    var mockPersonalizedSearchSession: MockPersonalizedSearchSession!

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()
        mockAssistiveHostDelegate = MockAssistiveChatHostDelegate()
        mockLocationProvider = MockLocationProvider()
        mockCloudCache = MockCloudCache()
        mockFeatureFlags = FeatureFlags()
        mockAnalytics = MockAnalytics()
        mockPlaceSearchSession = MockPlaceSearchSession()
        mockPersonalizedSearchSession = MockPersonalizedSearchSession()

        viewModel = ChatResultViewModel(
            assistiveHostDelegate: mockAssistiveHostDelegate,
            locationProvider: mockLocationProvider,
            cloudCache: mockCloudCache,
            featureFlags: mockFeatureFlags,
            analytics: mockAnalytics
        )

        // Inject mock sessions
        viewModel.placeSearchSession = mockPlaceSearchSession
        viewModel.personalizedSearchSession = mockPersonalizedSearchSession
    }

    override func tearDown() {
        viewModel = nil
        mockAssistiveHostDelegate = nil
        mockLocationProvider = nil
        mockCloudCache = nil
        mockFeatureFlags = nil
        mockAnalytics = nil
        mockPlaceSearchSession = nil
        mockPersonalizedSearchSession = nil
        super.tearDown()
    }

    // MARK: - Test Cases

    // MARK: Session Management Tests

    func testRefreshSessions_Success() async {
        // Arrange
        mockPlaceSearchSession.shouldInvalidateSessionSucceed = true

        // Act
        do {
            try await viewModel.refreshSessions()
        } catch {
            XCTFail("Expected refreshSessions to succeed, but it failed with error: \(error)")
        }

        // Assert
        XCTAssertEqual(viewModel.sessionRetryCount, 0)
        XCTAssertTrue(mockPlaceSearchSession.invalidateSessionCalled)
    }

    func testRefreshSessions_RetryTimeout() async {
        // Arrange
        viewModel.sessionRetryCount = 1 // Simulate retry count already at 1

        // Act & Assert
        do {
            try await viewModel.refreshSessions()
            XCTFail("Expected refreshSessions to throw retryTimeout error")
        } catch ChatResultViewModelError.retryTimeout {
            // Success
        } catch {
            XCTFail("Expected retryTimeout error, but got: \(error)")
        }
    }

    // MARK: Location Handling Tests

    func testCurrentLocationName_ReturnsLocationName() async {
        // Arrange
        let expectedLocationName = "Test City"
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        mockLocationProvider.currentLocationStub = location
        mockAssistiveHostDelegate.locationNameStub = expectedLocationName

        // Act
        var locationName: String?
        do {
            locationName = try await viewModel.currentLocationName()
        } catch {
            XCTFail("currentLocationName threw an error: \(error)")
        }

        // Assert
        XCTAssertEqual(locationName, expectedLocationName)
    }

    func testLocationChatResultForID_ReturnsCorrectResult() {
        // Arrange
        let locationResult = LocationResult(locationName: "Test Location", location: CLLocation(latitude: 0, longitude: 0))
        viewModel.locationResults = [locationResult]

        // Act
        let result = viewModel.locationChatResult(for: locationResult.id)

        // Assert
        XCTAssertEqual(result?.locationName, "Test Location")
    }

    func testLocationChatResultWithTitle_ReturnsCorrectResult() async {
        // Arrange
        let locationResult = LocationResult(locationName: "Test Location", location: CLLocation(latitude: 0, longitude: 0))
        viewModel.locationResults = [locationResult]

        // Act
        let result = await viewModel.locationChatResult(with: "Test Location")

        // Assert
        XCTAssertEqual(result.locationName, "Test Location")
    }

    func testCheckSearchTextForLocations_ReturnsPlacemarks() async {
        // Arrange
        let searchText = "Test City"
        mockAssistiveHostDelegate.tagsStub = nil
        let expectedPlacemarks = [CLPlacemark()]
        mockAssistiveHostDelegate.placemarksStub = expectedPlacemarks

        // Act
        var placemarks: [CLPlacemark]?
        do {
            placemarks = try await viewModel.checkSearchTextForLocations(with: searchText)
        } catch {
            XCTFail("checkSearchTextForLocations threw an error: \(error)")
        }

        // Assert
        XCTAssertEqual(placemarks?.count, expectedPlacemarks.count)
    }

    // MARK: Filtered Results Tests

    func testFilteredRecommendedPlaceResults_ReturnsFilteredResults() {
        // Arrange
        let tasteCategoryID = UUID()
        let tasteCategory = ChatResult(title: "Coffee", placeResponse: nil)
        let tasteResult = CategoryResult(id: tasteCategoryID, parentCategory: "Coffee", categoricalChatResults: [tasteCategory])
        viewModel.selectedTasteCategoryResult = tasteCategoryID
        viewModel.tasteResults = [tasteResult]

        let matchingPlace = ChatResult(title: "Coffee Shop", recommendedPlaceResponse: RecommendedPlaceSearchResponse(fsqID: "1", tastes: ["coffee"]))
        let nonMatchingPlace = ChatResult(title: "Tea House", recommendedPlaceResponse: RecommendedPlaceSearchResponse(fsqID: "2", tastes: ["tea"]))
        viewModel.recommendedPlaceResults = [matchingPlace, nonMatchingPlace]

        // Act
        let results = viewModel.filteredRecommendedPlaceResults

        // Assert
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Coffee Shop")
    }

    func testFilteredLocationResults_ReturnsCombinedResults() {
        // Arrange
        let cachedLocation = LocationResult(locationName: "Cached Location", location: nil)
        viewModel.cachedLocationResults = [cachedLocation]
        let locationResult = LocationResult(locationName: "New Location", location: nil)
        viewModel.locationResults = [locationResult]

        // Act
        let results = viewModel.filteredLocationResults

        // Assert
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].locationName, "Cached Location")
        XCTAssertEqual(results[1].locationName, "New Location")
    }

    // MARK: Cache Management Tests

    func testRefreshCache_UpdatesCachedResults() async {
        // Arrange
        mockCloudCache.groupedUserCachedRecordsStub = [
            UserCachedRecord(group: "Category", identity: "1", title: "Food"),
            UserCachedRecord(group: "Taste", identity: "2", title: "Spicy"),
            UserCachedRecord(group: "List", identity: "3", title: "Favorites")
        ]

        // Act
        do {
            try await viewModel.refreshCache(cloudCache: mockCloudCache)
        } catch {
            XCTFail("refreshCache threw an error: \(error)")
        }

        // Assert
        XCTAssertFalse(viewModel.cachedCategoryResults.isEmpty)
        XCTAssertFalse(viewModel.cachedTasteResults.isEmpty)
        XCTAssertFalse(viewModel.cachedListResults.isEmpty)
        XCTAssertFalse(viewModel.allCachedResults.isEmpty)
    }

    func testAppendCachedLocation_AddsLocation() {
        // Arrange
        let record = UserCachedRecord(group: "Location", identity: "0,0", title: "Test Location")

        // Act
        viewModel.appendCachedLocation(with: record)

        // Assert
        XCTAssertEqual(viewModel.cachedLocationResults.count, 1)
        XCTAssertEqual(viewModel.cachedLocationResults.first?.locationName, "Test Location")
    }

    func testCachedCategories_ContainsCategory() {
        // Arrange
        let record = UserCachedRecord(group: "Category", identity: "1", title: "Food")
        viewModel.cachedCategoryRecords = [record]

        // Act
        let contains = viewModel.cachedCategories(contains: "1")

        // Assert
        XCTAssertTrue(contains)
    }

    // MARK: Place Handling Tests

    func testPlaceChatResultForID_ReturnsCorrectChatResult() {
        // Arrange
        let placeResponse = PlaceSearchResponse(fsqID: "1", name: "Test Place")
        let chatResult = ChatResult(id: UUID(), title: "Test Place", placeResponse: placeResponse)
        viewModel.placeResults = [chatResult]

        // Act
        let result = viewModel.placeChatResult(for: chatResult.id)

        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "Test Place")
    }

    func testPlaceChatResultForFSQID_ReturnsCorrectChatResult() {
        // Arrange
        let fsqID = "1"
        let placeResponse = PlaceSearchResponse(fsqID: fsqID, name: "Test Place")
        let chatResult = ChatResult(title: "Test Place", placeResponse: placeResponse)
        viewModel.placeResults = [chatResult]

        // Act
        let result = viewModel.placeChatResult(for: fsqID)

        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.placeResponse?.fsqID, fsqID)
    }

    // MARK: Model Building and Query Handling Tests

    func testResetPlaceModel_ClearsPlaceData() {
        // Arrange
        viewModel.selectedPlaceChatResult = UUID()
        viewModel.placeResults = [ChatResult(title: "Place 1")]
        viewModel.recommendedPlaceResults = [ChatResult(title: "Place 2")]
        viewModel.relatedPlaceResults = [ChatResult(title: "Place 3")]

        // Act
        viewModel.resetPlaceModel()

        // Assert
        XCTAssertNil(viewModel.selectedPlaceChatResult)
        XCTAssertTrue(viewModel.placeResults.isEmpty)
        XCTAssertTrue(viewModel.recommendedPlaceResults.isEmpty)
        XCTAssertTrue(viewModel.relatedPlaceResults.isEmpty)
    }

    func testReceiveMessage_AddsNewLocations() async {
        // Arrange
        let caption = "New York"
        let parameters = AssistiveChatHostQueryParameters(queryIntents: [
            AssistiveChatHostIntent(caption: caption, intent: .Location)
        ])
        let placemark = CLPlacemark()
        mockAssistiveHostDelegate.placemarksStub = [placemark]

        // Act
        do {
            try await viewModel.receiveMessage(caption: caption, parameters: parameters, isLocalParticipant: true)
        } catch {
            XCTFail("receiveMessage threw an error: \(error)")
        }

        // Assert
        XCTAssertEqual(viewModel.locationResults.count, 1)
    }

    func testSearchIntent_PlaceIntent_FetchesPlaceDetails() async {
        // Arrange
        let placeResponse = PlaceSearchResponse(fsqID: "1", name: "Test Place")
        mockPlaceSearchSession.placeSearchResponsesStub = [placeResponse]
        mockPlaceSearchSession.placeDetailsResponseStub = Data()
        let intent = AssistiveChatHostIntent(caption: "Test Place", intent: .Place)

        // Act
        do {
            try await viewModel.searchIntent(intent: intent, location: nil)
        } catch {
            XCTFail("searchIntent threw an error: \(error)")
        }

        // Assert
        XCTAssertNotNil(intent.placeSearchResponses)
        XCTAssertNotNil(intent.selectedPlaceSearchDetails)
    }

    func testFetchDetails_ReturnsPlaceDetailsResponses() async {
        // Arrange
        let placeResponse = PlaceSearchResponse(fsqID: "1", name: "Test Place")
        mockPlaceSearchSession.placeDetailsResponseStub = Data()
        mockPlaceSearchSession.placeTipsResponseStub = Data()
        mockPlaceSearchSession.placePhotosResponseStub = Data()
        mockCloudCache.hasPrivateCloudAccess = true

        // Act
        var detailsResponses: [PlaceDetailsResponse] = []
        do {
            detailsResponses = try await viewModel.fetchDetails(for: [placeResponse])
        } catch {
            XCTFail("fetchDetails threw an error: \(error)")
        }

        // Assert
        XCTAssertEqual(detailsResponses.count, 1)
    }

    func testRetrieveFSQUser_ReturnsUser() async {
        // Arrange
        mockPersonalizedSearchSession.fetchFSQUserResponseStub = Data()
        mockCloudCache.hasPrivateCloudAccess = true

        // Act
        var user: FSQUser?
        do {
            user = try await viewModel.retrieveFsqUser()
        } catch {
            XCTFail("retrieveFsqUser threw an error: \(error)")
        }

        // Assert
        XCTAssertNotNil(user)
    }

    func testCategoricalSearchModel_UpdatesCategoryResults() async {
        // Arrange
        mockAssistiveHostDelegate.categoryCodesStub = [
            ["Food": [["category": "Pizza"], ["category": "Burger"]]]
        ]

        // Act
        await viewModel.categoricalSearchModel()

        // Assert
        XCTAssertEqual(viewModel.categoryResults.count, 1)
        XCTAssertEqual(viewModel.categoryResults.first?.parentCategory, "Food")
    }

    func testAutocompleteTastes_FetchesTasteResults() async {
        // Arrange
        let intent = AssistiveChatHostIntent(caption: "Spicy", intent: .AutocompleteTastes)
        mockPersonalizedSearchSession.autocompleteTastesResponseStub = Data()

        // Act
        do {
            try await viewModel.autocompleteTastes(lastIntent: intent)
        } catch {
            XCTFail("autocompleteTastes threw an error: \(error)")
        }

        // Assert
        XCTAssertFalse(viewModel.tasteResults.isEmpty)
    }

    func testPlaceQueryModel_UpdatesPlaceResults() async {
        // Arrange
        let placeResponse = PlaceSearchResponse(fsqID: "1", name: "Test Place")
        let intent = AssistiveChatHostIntent(caption: "Test Place", intent: .Place, placeSearchResponses: [placeResponse])

        // Act
        await viewModel.placeQueryModel(intent: intent)

        // Assert
        XCTAssertEqual(viewModel.placeResults.count, 1)
    }

    func testDetailIntent_FetchesPlaceDetails() async {
        // Arrange
        let placeResponse = PlaceSearchResponse(fsqID: "1", name: "Test Place")
        let intent = AssistiveChatHostIntent(caption: "Test Place", intent: .Place, selectedPlaceSearchResponse: placeResponse)
        mockPlaceSearchSession.placeDetailsResponseStub = Data()

        // Act
        do {
            try await viewModel.detailIntent(intent: intent)
        } catch {
            XCTFail("detailIntent threw an error: \(error)")
        }

        // Assert
        XCTAssertNotNil(intent.selectedPlaceSearchDetails)
    }

    func testAutocompletePlaceModel_UpdatesPlaceResults() async {
        // Arrange
        let caption = "Coffee"
        let location = CLLocation(latitude: 0, longitude: 0)
        let intent = AssistiveChatHostIntent(caption: caption, intent: .AutocompleteSearch)
        mockPlaceSearchSession.autocompletePlaceSearchResponsesStub = [
            PlaceSearchResponse(fsqID: "1", name: "Coffee Shop")
        ]

        // Act
        do {
            try await viewModel.autocompletePlaceModel(caption: caption, intent: intent, location: location)
        } catch {
            XCTFail("autocompletePlaceModel threw an error: \(error)")
        }

        // Assert
        XCTAssertEqual(viewModel.placeResults.count, 1)
    }

    // MARK: - Delegate Methods Tests

    func testDidSearch_UpdatesModel() async {
        // Arrange
        let caption = "Pizza"
        mockAssistiveHostDelegate.intentStub = .Search
        mockAssistiveHostDelegate.queryParametersStub = NSDictionary()
        mockAssistiveHostDelegate.queryIntentParameters = AssistiveChatHostQueryParameters(queryIntents: [])

        // Act
        do {
            try await viewModel.didSearch(caption: caption, selectedDestinationChatResultID: nil)
        } catch {
            XCTFail("didSearch threw an error: \(error)")
        }

        // Assert
        XCTAssertNotNil(viewModel.assistiveHostDelegate?.queryIntentParameters?.queryIntents.last)
    }

    func testDidTapPlaceChatResult_UpdatesIntent() async {
        // Arrange
        let placeResponse = PlaceSearchResponse(fsqID: "1", name: "Test Place")
        let chatResult = ChatResult(title: "Test Place", placeResponse: placeResponse)
        viewModel.placeResults = [chatResult]
        mockAssistiveHostDelegate.queryIntentParameters = AssistiveChatHostQueryParameters(queryIntents: [AssistiveChatHostIntent(caption: "Test Place", intent: .Place, placeSearchResponses: [placeResponse])])

        // Act
        do {
            try await viewModel.didTap(placeChatResult: chatResult)
        } catch {
            XCTFail("didTap threw an error: \(error)")
        }

        // Assert
        XCTAssertNotNil(viewModel.selectedPlaceChatResult)
    }

    func testDidReceiveStreamingResult_UpdatesPlaceDescription() async {
        // Arrange
        let placeResponse = PlaceSearchResponse(fsqID: "1", name: "Test Place")
        let detailsResponse = PlaceDetailsResponse(searchResponse: placeResponse, description: "Old Description")
        let chatResult = ChatResult(id: UUID(), title: "Test Place", placeResponse: placeResponse, placeDetailsResponse: detailsResponse)
        viewModel.placeResults = [chatResult]
        let streamingString = " New Description"

        // Act
        await viewModel.didReceiveStreamingResult(with: streamingString, for: chatResult)

        // Assert
        let updatedChatResult = viewModel.placeResults.first
        XCTAssertEqual(updatedChatResult?.placeDetailsResponse?.description, "Old Description New Description")
    }
}
