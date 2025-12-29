//
//  PersonalizedSearchSession.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 1/10/24.
//

import Foundation
import CloudKit
import NaturalLanguage
import ConcurrencyExtras

public enum PersonalizedSearchSessionError : Error {
    case UnsupportedRequest
    case ServerErrorMessage
    case NoUserFound
    case NoTokenFound
    case NoTasteFound
    case NoVenuesFound
    case MaxRetriesReached
    case TransientNetworkError
    case Debounce
}

public actor PersonalizedSearchSession : PersonalizedSearchSessionProtocol {
    // Retry/backoff configuration
    private static let maxRetryAttempts = 3
    private static let baseBackoff: TimeInterval = 0.5 // seconds
    private var isFetchingRecommendations:Bool = false

    private let cloudCacheService: CloudCacheService
    private let analyticsManager: AnalyticsService

    public init(cloudCacheService: CloudCacheService) {
        self.cloudCacheService = cloudCacheService
        self.analyticsManager = cloudCacheService.analyticsManager
    }

    private func exponentialBackoffDelay(attempt: Int) -> TimeInterval {
        // Exponential backoff with jitter
        // attempt starts at 1
        let exp = pow(2.0, Double(attempt - 1))
        let jitter = Double.random(in: 0...0.25) // add up to 250ms jitter
        return PersonalizedSearchSession.baseBackoff * exp + jitter
    }

    // Memoization for in-flight token fetches
    private var tokenTask: Task<String, Error>? = nil
    private var cachedAccessToken: String = ""

    // Centralized token gating helper with observability and optional refresh
    @discardableResult
    private func requireAccessToken(
        cacheManager: CacheManager,
        refresh: (() async throws -> Void)? = nil
    ) async throws -> String {
        // Fast path: return cached token if available
        if !cachedAccessToken.isEmpty {
            return cachedAccessToken
        }
        if let token = fsqAccessToken, !token.isEmpty {
            cachedAccessToken = token
            return token
        }
        // Share any in-flight token fetch across concurrent callers
        if let task = tokenTask {
            return try await task.value
        }

        let task = Task { () throws -> String in
            do {
                let token = try await fetchManagedUserAccessToken(cacheManager: cacheManager)
                if token.isEmpty {
                    if let refresh = refresh {
                        try await refresh()
                        let refreshed = try await fetchManagedUserAccessToken(cacheManager: cacheManager)
                        guard !refreshed.isEmpty else { throw PersonalizedSearchSessionError.NoTokenFound }
                        return refreshed
                    }
                    throw PersonalizedSearchSessionError.NoTokenFound
                }
                return token
            } catch {
                if let refresh = refresh {
                    try await refresh()
                    let refreshed = try await fetchManagedUserAccessToken(cacheManager: cacheManager)
                    guard !refreshed.isEmpty else { throw PersonalizedSearchSessionError.NoTokenFound }
                    return refreshed
                }
                throw error
            }
        }
        tokenTask = task
        defer { tokenTask = nil }
        let acquired = try await task.value
        // Cache the acquired token for fast-path next time
        cachedAccessToken = acquired
        fsqAccessToken = acquired
        return acquired
    }
    
    public var fsqIdentity:String?
    public var fsqAccessToken:String?
    private var fsqServiceAPIKey:String?
    let keysContainer = CKContainer(identifier:"iCloud.com.secretatomics.knowmaps.Keys")
    static let serverUrl = "https://api.foursquare.com/"
    static let userManagementAPIUrl = "v2/usermanagement"
    static let userManagementCreationPath = "/createuser"
    static let tasteSuggestionsAPIUrl = "v2/tastes/suggestions"
    static let venueRecommendationsAPIUrl = "v3/places/search"
    static let autocompleteAPIUrl = "v3/autocomplete"
    static let autocompleteTastesAPIUrl = "v2/tastes/autocomplete"
    static let relatedVenueAPIUrl = "v3/places/"
    static let relatedVenuePath = "/related"
    static let foursquareVersionDate = "20241227"
    
    @discardableResult
    public func fetchManagedUserIdentity(cacheManager:CacheManager) async throws ->String? {
        let cloudFsqIdentity = try await cacheManager.cloudCacheService.fetchFsqIdentity()
        
        if cloudFsqIdentity.isEmpty {
            try await addFoursquareManagedUserIdentity(cacheManager: cacheManager)
            return try await fetchManagedUserIdentity(cacheManager: cacheManager)
        }
        
        fsqIdentity = cloudFsqIdentity
        
        return fsqIdentity
    }
    
    @discardableResult
    public func fetchManagedUserAccessToken(cacheManager:CacheManager) async throws ->String {
        if fsqIdentity == nil {
            try await fetchManagedUserIdentity(cacheManager: cacheManager)
        }
        
        guard let fsqIdentity = fsqIdentity, !fsqIdentity.isEmpty else {
            throw PersonalizedSearchSessionError.NoUserFound
        }
        
        let cloudToken = try await cacheManager.cloudCacheService.fetchToken(for: fsqIdentity)
        fsqAccessToken = cloudToken
        
        guard let token = fsqAccessToken, !token.isEmpty else {
            throw PersonalizedSearchSessionError.NoTokenFound
        }
        
        return token
    }
    
    @discardableResult
    public func addFoursquareManagedUserIdentity(cacheManager:CacheManager) async throws -> Bool {
        let apiKey = try await fetchFoursquareServiceAPIKey()
        
        guard let apiKey = apiKey else {
            return false
        }
        
        let components = URLComponents(string:"\(PersonalizedSearchSession.serverUrl)\(PersonalizedSearchSession.userManagementAPIUrl)\(PersonalizedSearchSession.userManagementCreationPath)")
        guard let url = components?.url else {
            throw PersonalizedSearchSessionError.UnsupportedRequest
        }
        
        let data = try await fetch(url: url, apiKey: apiKey, urlQueryItems: [], httpMethod: "POST")
        
        guard let root = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return false
        }
        
        var identity:String? = nil
        var token:String? = nil
        
        if let responseDict = root["response"] as? NSDictionary {
            if let userId = responseDict["userId"] as? Int {
                identity = "\(userId)"
            }
            if let accessToken = responseDict["access_token"] as? String {
                token = accessToken
            }
        }
        
        guard let identity = identity, let token = token else {
            throw PersonalizedSearchSessionError.NoUserFound
        }
                
        await cacheManager.cloudCacheService.storeFoursquareIdentityAndToken(for: identity, oauthToken: token)
        
        return true
    }

    public func autocompleteTastes(caption:String, parameters:[String:String]?, cacheManager:CacheManager) async throws -> FSQTastesResponse {
        
        let apiKey = try await requireAccessToken(cacheManager: cacheManager) {
            _ = await self.cloudCacheService.refreshFsqToken()
        }

        var limit = 50
        var nameString:String = ""
        
        if let parameters = parameters, let rawQuery = parameters["query"] {
            nameString = rawQuery
        }
        
        if let parameters = parameters, let rawLimit = Int(parameters["limit"] ?? "") {
            limit = rawLimit
        }
        
        guard let queryComponents = URLComponents(string:"\(PersonalizedSearchSession.serverUrl)\(PersonalizedSearchSession.autocompleteTastesAPIUrl)") else {
            throw PersonalizedSearchSessionError.UnsupportedRequest
        }
        
        var queryItems = [URLQueryItem]()

        if nameString.count > 0 {
            let queryUrlItem = URLQueryItem(name: "query", value: nameString.trimmingCharacters(in: .whitespacesAndNewlines))
            queryItems.append(queryUrlItem)
        } else {
            let queryUrlItem = URLQueryItem(name: "query", value: caption)
            queryItems.append(queryUrlItem)
        }
        
        let limitQueryItem = URLQueryItem(name: "limit", value: "\(limit)")
        queryItems.append(limitQueryItem)

        guard let url = queryComponents.url else {
            throw PersonalizedSearchSessionError.UnsupportedRequest
        }
        
        let data = try await fetch(url: url, apiKey: apiKey, urlQueryItems: queryItems)
        let decoder = JSONDecoder()
        let root = try decoder.decode(FSQTastesRoot.self, from: data)
        return root.response ?? FSQTastesResponse(tastes: [])
    }
    
    public func fetchRecommendedVenues(with request:RecommendedPlaceSearchRequest, cacheManager:CacheManager) async throws -> [PlaceSearchResponse] {
        guard !isFetchingRecommendations else { throw PersonalizedSearchSessionError.Debounce }
        isFetchingRecommendations = true
        let apiKey = try await requireAccessToken(cacheManager: cacheManager) {
            _ = await self.cloudCacheService.refreshFsqToken()
        }
                
        guard !apiKey.isEmpty else {
            throw PersonalizedSearchSessionError.UnsupportedRequest
        }
        
        guard let components = URLComponents(string:"\(PersonalizedSearchSession.serverUrl)\(PersonalizedSearchSession.venueRecommendationsAPIUrl)") else {
            throw PersonalizedSearchSessionError.UnsupportedRequest
        }
        
        // Progressive radius candidates
        let progressiveRadii = [20000, 30000, 50000]

        // Helper to build query items for a given radius
        func buildQueryItems(radius: Int?) -> [URLQueryItem] {
            var items = [URLQueryItem]()

            if let rawLocation = request.ll {
                items.append(URLQueryItem(name: "ll", value: rawLocation))
                if let radius = radius { items.append(URLQueryItem(name: "radius", value: "\(radius)")) }
            }

            if !request.categories.isEmpty {
                items.append(URLQueryItem(name: "categories", value: request.categories))
            }
            
            if request.minPrice > 1 || request.maxPrice < 4 {
                var priceStr = ""
                for p in request.minPrice...request.maxPrice {
                    priceStr += "\(p),"
                }
                if !priceStr.isEmpty {
                    priceStr.removeLast()
                    items.append(URLQueryItem(name: "min_price", value: "\(request.minPrice)"))
                    items.append(URLQueryItem(name: "max_price", value: "\(request.maxPrice)"))
                }
            }

            if request.openNow == true { items.append(URLQueryItem(name: "open_now", value: "true")) }

            items.append(URLQueryItem(name: "limit", value: "\(request.limit)"))
            items.append(URLQueryItem(name: "sort", value: "RELEVANCE"))

            if !request.query.isEmpty {
                items.append(URLQueryItem(name: "query", value: request.query))
            }
            return items
        }

        // Try with the provided radius first (if any), then progressively expand
        let radiiToTry: [Int?]
        if request.radius > 0 {
            radiiToTry = [request.radius] + progressiveRadii.filter { $0 > request.radius }
        } else {
            radiiToTry = [nil] + progressiveRadii
        }

        var lastError: Error?
        for (index, radius) in radiiToTry.enumerated() {
            do {
                let queryItems = buildQueryItems(radius: radius)
                let data = try await fetch(url: components.url!, apiKey: apiKey, urlQueryItems: queryItems)
                
                isFetchingRecommendations = false
                
                let decoder = JSONDecoder()
                let response = try decoder.decode(FSQSearchResponse.self, from: data)
                let results = try PlaceResponseFormatter.placeSearchResponses(with: response)
                
                if results.isEmpty && index < radiiToTry.count - 1 {
                    continue
                }
                
                self.analyticsManager.track(
                    event: "recommendedSearch.parsed",
                    properties: [
                        "count": results.count
                    ]
                )
                
                return results
            } catch {
                isFetchingRecommendations = false
                lastError = error
                // On transient/server errors, try next radius if available
                if index < radiiToTry.count - 1 { continue }
                throw error
            }
        }

        if let lastError = lastError { throw lastError }
        throw PersonalizedSearchSessionError.NoVenuesFound
    }
    
    public func fetchTastes(page:Int, cacheManager:CacheManager) async throws -> FSQTastesResponse {
        let apiKey = try await requireAccessToken(cacheManager: cacheManager) {
            _ = await self.cloudCacheService.refreshFsqToken()
        }
        
        guard !apiKey.isEmpty else {
            throw PersonalizedSearchSessionError.UnsupportedRequest
        }
        
        guard let components = URLComponents(string:"\(PersonalizedSearchSession.serverUrl)\(PersonalizedSearchSession.tasteSuggestionsAPIUrl)") else {
            throw PersonalizedSearchSessionError.UnsupportedRequest
        }
        
        let intentQueryItem = URLQueryItem(name: "intent", value: "onboarding")
        let limitQueryItem = URLQueryItem(name: "limit", value: "50")
        let offsetQueryItem = URLQueryItem(name: "offset", value:"\(page)")
        
        let data = try await fetch(url: components.url!, apiKey: apiKey, urlQueryItems: [intentQueryItem, limitQueryItem, offsetQueryItem])
        
        let decoder = JSONDecoder()
        let root = try decoder.decode(FSQTastesRoot.self, from: data)
        return root.response ?? FSQTastesResponse(tastes: [])
    }

    
    public func fetchRelatedVenues(for fsqID:String, cacheManager:CacheManager) async throws -> [PlaceSearchResponse] {
        let apiKey = try await requireAccessToken(cacheManager: cacheManager) {
            _ = await self.cloudCacheService.refreshFsqToken()
        }
        
        guard !apiKey.isEmpty else {
            throw PersonalizedSearchSessionError.UnsupportedRequest
        }
        
        guard let components = URLComponents(string:"\(PersonalizedSearchSession.serverUrl)\(PersonalizedSearchSession.relatedVenueAPIUrl)\(fsqID)\(PersonalizedSearchSession.relatedVenuePath)") else {
            throw PersonalizedSearchSessionError.UnsupportedRequest
        }
        
        guard let url = components.url else {
            throw PersonalizedSearchSessionError.UnsupportedRequest
        }
        
        let data = try await fetch(url: url, apiKey: apiKey, urlQueryItems: [])
        let decoder = JSONDecoder()
        let response = try decoder.decode(FSQSearchResponse.self, from: data)
        return try PlaceResponseFormatter.placeSearchResponses(with: response)
    }
    
    private func fetchFoursquareServiceAPIKey() async throws -> String? {
        let predicate = NSPredicate(format: "service == %@", "foursquareService")
        let query = CKQuery(recordType: "KeyString", predicate: predicate)
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["value", "service"]
        operation.resultsLimit = 1

        // Use a continuation to wait for the async operation to complete
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.recordMatchedBlock = { [weak self] recordId, result in
                
                Task { [weak self] in
                    guard let self = self else { return }
                    await self.handleRecordMatched(result: result)
                }
            }

            operation.queryResultBlock = { [weak self] result in
                
                Task { [weak self] in
                    guard let self = self else { return }
                    await self.handleQueryResult(result: result, continuation: continuation)
                }
            }

            keysContainer.publicCloudDatabase.add(operation)
        }

        return fsqServiceAPIKey
    }

    private func handleRecordMatched(result: Result<CKRecord, Error>) async {
        do {
            let record = try result.get()
            if let apiKey = record["value"] as? String {
                print("\(String(describing: record["service"]))")
                // Safely update the actor-isolated property
                self.fsqServiceAPIKey = apiKey
            } else {
                print("Did not find API Key")
            }
        } catch {
            print(error)
        }
    }

    private func handleQueryResult(result: Result<CKQueryOperation.Cursor?, Error>, continuation: CheckedContinuation<Void, Error>) async {
        switch result {
        case .success:
            continuation.resume()
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
    
    internal func fetch(
        url: URL,
        apiKey: String,
        urlQueryItems: [URLQueryItem],
        httpMethod: String = "GET"
    ) async throws -> Data {
        // Construct URL with query items
        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw PersonalizedSearchSessionError.UnsupportedRequest
        }
        let versionQueryItem = URLQueryItem(name: "v", value: PersonalizedSearchSession.foursquareVersionDate)
        var allQueryItems = [versionQueryItem]
        allQueryItems.append(contentsOf: urlQueryItems)
        urlComponents.queryItems = allQueryItems
        guard let queryUrl = urlComponents.url else { throw PersonalizedSearchSessionError.UnsupportedRequest }

        var attempt = 0
        var lastError: Error?
        while attempt < PersonalizedSearchSession.maxRetryAttempts {
            attempt += 1
            do {
                print("Requesting URL: \(queryUrl) [attempt: \(attempt)]")
                var request = URLRequest(url: queryUrl)
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.timeoutInterval = 5.0
                request.httpMethod = httpMethod

                let (data, response) = try await URLSession.shared.data(for: request)

                // Retry on HTTP 5xx
                if let http = response as? HTTPURLResponse, (500...599).contains(http.statusCode) {
                    throw PersonalizedSearchSessionError.ServerErrorMessage
                }

                // On success return raw data
                return data
            } catch {
                lastError = error
                if attempt >= PersonalizedSearchSession.maxRetryAttempts {
                    break
                }
                // Backoff with jitter on likely-transient failures
                let delay = exponentialBackoffDelay(attempt: attempt)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        throw lastError ?? PersonalizedSearchSessionError.MaxRetriesReached
    }
}



