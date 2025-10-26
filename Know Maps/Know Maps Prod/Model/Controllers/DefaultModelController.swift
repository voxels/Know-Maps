//
//  DefaultModelController.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/8/24.
//

import SwiftUI
import CoreLocation
import AVKit

// MARK: - Model Controller Errors
public enum ModelControllerError: Error, LocalizedError {
    case invalidRecommendedPlaceResponse
    case missingLocationData
    case invalidAsyncOperation
    
    public var errorDescription: String? {
        switch self {
        case .invalidRecommendedPlaceResponse:
            return "Invalid recommended place response"
        case .missingLocationData:
            return "Missing location data"
        case .invalidAsyncOperation:
            return "Invalid async operation"
        }
    }
}

@MainActor
@Observable
public final class DefaultModelController : ModelController {
    // MARK: - Dependencies
    public let assistiveHostDelegate: AssistiveChatHost
    public let locationService:LocationService
    public let placeSearchService: PlaceSearchService
    public let analyticsManager: AnalyticsService
    public let recommenderService:RecommenderService
    public let cacheManager:CacheManager
    
    // MARK: - Published Properties
    
    
    // Selection States
    public var selectedPersonalizedSearchSection:PersonalizedSearchSection?
    public var selectedPlaceChatResultFsqId:String?
    public var selectedCategoryChatResult:CategoryResult.ID?
    public var selectedDestinationLocationChatResult: LocationResult {
        didSet {
            print("🗺️ selectedDestinationLocationChatResult changed to \(selectedDestinationLocationChatResult.locationName)")
        }
    }
    
    // Fetching States
    public var isFetchingPlaceDescription: Bool = false
    public var isRefreshingPlaces:Bool = false
    public var fetchMessage:String = "Searching near Current Location..."
    
    // TabView
    public var section:Int = 0
    
    // Results
    public var industryResults = [CategoryResult]()
    public var tasteResults = [CategoryResult]()
    public var placeResults = [ChatResult]()
    public var previousPlaceResults = [ChatResult]()
    public var mapPlaceResults = [ChatResult]()
    public var recommendedPlaceResults = [ChatResult]()
    public var relatedPlaceResults = [ChatResult]()
    public var locationResults = [LocationResult]()
    
    
    // MARK: - Private Properties
    
    // MARK: - Coordinate Utilities
    private let coordinateEpsilon: CLLocationDistance = 1e-5
    private let coordinateDistanceThresholdMeters: CLLocationDistance = 50
    
    private func currentDistanceThresholdMeters() -> CLLocationDistance {
        // Try to read a distance-like value from the most recent saved query parameters history.
        // Accept common keys: "distance", "radius", "rangeMeters". Assume meters.
        if let last = queryParametersHistory.last {
            // Attempt to extract from a generic dictionary via reflection-safe access patterns
            // Since AssistiveChatHostQueryParameters isn't defined here, try common dynamic paths
            let mirror = Mirror(reflecting: last)
            for child in mirror.children {
                if let label = child.label?.lowercased() {
                    if label.contains("filters"), let dict = child.value as? [String: Any] {
                        if let d = dict["rangeMeters"] as? Double { return d }
                        if let d = dict["distance"] as? Double { return d }
                        if let d = dict["radius"] as? Double { return d }
                        if let s = dict["rangeMeters"] as? String, let d = Double(s) { return d }
                        if let s = dict["distance"] as? String, let d = Double(s) { return d }
                        if let s = dict["radius"] as? String, let d = Double(s) { return d }
                    }
                }
            }
        }
        return coordinateDistanceThresholdMeters
    }
    
    private func coordinatesEqual(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D, epsilon: CLLocationDistance? = nil) -> Bool {
        let e = epsilon ?? coordinateEpsilon
        return abs(a.latitude - b.latitude) < e && abs(a.longitude - b.longitude) < e
    }
    
    private func isOutsideThreshold(from a: CLLocationCoordinate2D?, to b: CLLocationCoordinate2D, threshold: CLLocationDistance? = nil) -> Bool {
        guard let a = a else { return true }
        let distance = CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
        return distance > (threshold ?? currentDistanceThresholdMeters())
    }
    
    public var queryParametersHistory = [AssistiveChatHostQueryParameters]()
    private var fetchingPlaceID: ChatResult.ID?
    private var sessionRetryCount: Int = 0
    
    // Added re-entrancy guard for selectedPlaceChatResult updates
    private var isUpdatingSelectedPlace: Bool = false
    
    // Debounce state for reselects
    private var lastPlaceReselectAt: Date? = nil
    private var lastReselectedPlaceID: ChatResult.ID? = nil
    
    // Added re-entrancy guard for selectedDestinationLocationChatResult updates
    private var isUpdatingSelectedLocation: Bool = false
    
    // New private property for in-flight duplicate search guarding
    private var inFlightSearchKey: String? = nil
    
    // Tracks in-flight component operations (e.g., placeQueryModel/recommendedPlaceQueryModel) per search key
    private var inFlightComponentKeys: Set<String> = []
    
    // MARK: - Lazy Detail Fetch Concurrency Gate
    private actor DetailFetchLimiter {
        private let limit: Int
        private var current: Int = 0
        private var waiters: [CheckedContinuation<Void, Never>] = []
        
        init(limit: Int) { self.limit = max(1, limit) }
        
        func acquire() async {
            if current < limit {
                current += 1
                return
            }
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                waiters.append(continuation)
            }
            current += 1
        }
        
        func release() async {
            if !waiters.isEmpty {
                let next = waiters.removeFirst()
                next.resume()
            } else {
                current = max(0, current - 1)
            }
        }
    }
    
    private static let detailLimiter = DetailFetchLimiter(limit: 4)
    
    /// Enqueue a lazy detail fetch with limited concurrency to avoid saturating the network/UI.
    public func enqueueLazyDetailFetch(for result: ChatResult) async {
        await DefaultModelController.detailLimiter.acquire()
        defer { Task { await DefaultModelController.detailLimiter.release() } }
        do {
            try await self.fetchPlaceDetailsIfNeeded(for: result)
        } catch {
            analyticsManager.trackError(error: error, additionalInfo: ["context": "enqueueLazyDetailFetch"])
        }
    }
    
    // MARK: - Initializer
    
    public init(
        cacheManager:CacheManager
    ) {
        self.cacheManager = cacheManager
        self.analyticsManager = cacheManager.cloudCacheService.analyticsManager
        self.assistiveHostDelegate = AssistiveChatHostService(analyticsManager: analyticsManager, messagesDelegate: ChatResultViewModel.shared)
        self.placeSearchService = DefaultPlaceSearchService(assistiveHostDelegate: assistiveHostDelegate, placeSearchSession: PlaceSearchSession(), personalizedSearchSession: PersonalizedSearchSession(cloudCacheService: cacheManager.cloudCacheService), analyticsManager: analyticsManager)
        self.locationService = DefaultLocationService(locationProvider: LocationProvider.shared)
        self.recommenderService = DefaultRecommenderService()
        self.selectedDestinationLocationChatResult = LocationResult(locationName: "Current Location", location: locationService.currentLocation())
    }
    
    // MARK: - Consolidated State Management
    
    public func coalesceOnNextFrame(_ updates: @escaping () -> Void) {
        DispatchQueue.main.async(execute: updates)
    }
    
    /// Centralized method for updating all results to ensure consistency
    private func updateAllResults(
        industry: [CategoryResult]? = nil,
        taste: [CategoryResult]? = nil,
        places: [ChatResult]? = nil,
        mapPlaces: [ChatResult]? = nil,
        recommended: [ChatResult]? = nil,
        related: [ChatResult]? = nil,
        locations: [LocationResult]? = nil,
        appendLocations: Bool = false,
        selectedPlaceFsqId: String? = nil,
        selectedLocation: LocationResult? = nil,
        clearSelection:Bool = true,
        clearAll: Bool = false
    ) {
        coalesceOnNextFrame {
            if clearSelection {
                self.setSelectedPlaceChatResult(nil)
            }
                if clearAll {
                    self.tasteResults.removeAll()
                    self.placeResults.removeAll()
                    self.mapPlaceResults.removeAll()
                    self.recommendedPlaceResults.removeAll()
                    self.relatedPlaceResults.removeAll()
                    self.locationResults.removeAll()
                    self.selectedPlaceChatResultFsqId = nil
                    self.selectedCategoryChatResult = nil
                    self.selectedPersonalizedSearchSection
                    = nil
                    self.industryResults = self.filteredResults
                }
                
                if let industry = industry { self.industryResults = industry }
            if let taste = taste {
                self.tasteResults = taste
            }
                if let places = places {
                    self.previousPlaceResults = self.placeResults
                    self.placeResults = places
                }
                if let mapPlaces = mapPlaces { self.mapPlaceResults = mapPlaces }
                if let recommended = recommended { self.recommendedPlaceResults = recommended }
                if let related = related { self.relatedPlaceResults = related }
                
                if let locations = locations {
                    if appendLocations {
                        let existingLocationNames = self.locationResults.map { $0.locationName }
                        let newLocations = locations.filter { !existingLocationNames.contains($0.locationName) }
                        self.locationResults.append(contentsOf: newLocations)
                    } else {
                        self.locationResults = locations
                    }
                }
                
                if let selectedPlaceFsqId {
                    self.selectedPlaceChatResultFsqId = selectedPlaceFsqId
                }
                
                if let selectedLocation = selectedLocation { self.setSelectedLocation(selectedLocation)
                }
                
                // Centrally manage message based on result presence (no timeout)
                let proposedPlaces = places ?? self.placeResults
                let proposedRecommended = recommended ?? self.recommendedPlaceResults
                let hasResults = !(proposedPlaces.isEmpty && proposedRecommended.isEmpty)
                if hasResults {
                    // Results are present: refresh the found message
                    self.updateFoundResultsMessage()
                }
            }
    }
    
    /// Safely update location state
    public func setSelectedLocation(_ result: LocationResult?) {
        guard let result else {
            Task {
                let currentLocation = locationService.currentLocation()
                let name = try await locationService.currentLocationName()
                // Set the selected destination to current location
                await MainActor.run {
                    selectedDestinationLocationChatResult = LocationResult(
                        locationName: name,
                        location: currentLocation)
                }
            }
            return
        }
        // Debug logging to trace selection changes
        print("🗺️ ModelController setSelectedLocation called with: \(result.id)")
        let previous = selectedDestinationLocationChatResult
        print("🗺️ Previous selectedDestinationLocationChatResult: \(previous)")
        
        // Re-entrancy guard
        if isUpdatingSelectedLocation {
            print("🗺️ setSelectedLocation re-entrancy guard active; ignoring call")
            return
        }
        
        // No-op if unchanged
        if previous == result {
            print("🗺️ setSelectedLocation no-op: same ID \(String(describing: previous))")
            return
        } else {
            isUpdatingSelectedLocation = true
            defer { isUpdatingSelectedLocation = false }
            if let cachedResult = self.locationChatResult(for: result.id, in: filteredLocationResults()) {
                selectedDestinationLocationChatResult = cachedResult
            } else {
                if result.locationName == "Current Location" {
                    Task {
                        do {
                            let candidatePlacemarks = try await locationService.lookUpLocation(result.location)
                            if let firstPlacemark = candidatePlacemarks.first {
                                let resolvedNameResult = LocationResult(locationName: firstPlacemark.name ?? "Current Location", location: result.location)
                                Task { @MainActor in
                                    locationResults.append(resolvedNameResult)
                                    selectedDestinationLocationChatResult = resolvedNameResult
                                }
                            } else {
                                Task { @MainActor in
                                    locationResults.append(result)
                                    selectedDestinationLocationChatResult = result
                                }
                            }
                        } catch {
                            analyticsManager.trackError(error: error, additionalInfo: nil)
                        }
                    }
                }
            }
            
            // keep currentlySelectedLocationResult as-is
            print("🗺️ New selectedDestinationLocationChatResult: \(result.id) (current location)")
        }
    }
    
    /// Safely update selected place chat result state (supports reselection)
    public func setSelectedPlaceChatResult(_ fsqId:String?) {
        print("📍 ModelController setSelectedPlaceChatResult called with: \(String(describing: fsqId))")
        print("📍 Previous selectedPlaceChatResult: \(String(describing: selectedPlaceChatResultFsqId))")
        
        // Re-entrancy guard
        if isUpdatingSelectedPlace {
            print("📍 setSelectedPlaceChatResult re-entrancy guard active; ignoring call")
            return
        }
        
        // Handle same-ID assignments
        if let id = fsqId, id == selectedPlaceChatResultFsqId {
            print("📍 setSelectedPlaceChatResult no-op: same ID \(id)")
            return
        }
        
        isUpdatingSelectedPlace = true
        
        self.selectedPlaceChatResultFsqId = fsqId
        
        isUpdatingSelectedPlace = false
        print("📍 New selectedPlaceChatResult: \(String(describing: selectedPlaceChatResultFsqId))")
    }
    
    /// Get the CLLocation for the currently selected destination
    public func getSelectedDestinationLocation() -> CLLocation {
        print("🗺️ getSelectedDestinationLocation called")
        print("🗺️ Current selectedDestinationLocationChatResult: \(selectedDestinationLocationChatResult.locationName)")
        return selectedDestinationLocationChatResult.location
    }
    
    /// Set the selected location and return the CLLocation synchronously to avoid race conditions
    public func setSelectedLocationAndGetLocation(_ locationResult: LocationResult) -> CLLocation {
        print("🗺️ setSelectedLocationAndGetLocation called with: \(locationResult.id)")
        setSelectedLocation(locationResult)
        
        // Immediately get the location to avoid race conditions
        return getSelectedDestinationLocation()
    }
    
    // MARK: - Input Sanitization
    /// Join a list of search terms into a single comma-separated string with no whitespace
    private func joinSearchTerms(_ terms: [String]) -> String {
        return terms
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ",")
    }
    
    /// Sanitize user-provided captions/queries to keep state consistent and safe
    private func sanitizeCaption(_ caption: String) -> String {
        // 1) Normalize newlines/tabs to spaces
        var sanitized = caption.replacingOccurrences(of: "\n", with: " ")
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
        if sanitized.count > 200 {
            sanitized = String(sanitized.prefix(200))
        }
        
        return sanitized
    }
    
    /// Resolve a friendly name for the currently selected destination location.
    /// Falls back to the current location name if unavailable.
    private func selectedDestinationLocationName() -> String {
        selectedDestinationLocationChatResult.locationName
    }
        
    /// Generate a stable in-flight search key for duplicate suppression
    private func makeSearchKey(for intent: AssistiveChatHostIntent) -> String {
        let caption = intent.caption
        let locationName = intent.selectedDestinationLocation.locationName
        let radius = currentDistanceThresholdMeters()
        return "\(caption)|\(locationName)|\(radius)"
    }
    
    // MARK: - Progress Instrumentation
    private func setProgressMessage(phase: String, caption: String?, locationName: String?) {
        let cleanCaption = (caption?.isEmpty == false) ? caption : nil
        let cleanLocation = (locationName?.isEmpty == false) ? locationName : selectedDestinationLocationName()
        let message: String
        if let cleanCaption, let cleanLocation {
            message = "\(phase) for \"\(cleanCaption)\" near \(cleanLocation)…"
        } else if let cleanCaption {
            message = "\(phase) for \"\(cleanCaption)\"…"
        } else if let cleanLocation {
            message = "\(phase) near \(cleanLocation)…"
        } else {
            message = phase
        }
        coalesceOnNextFrame { [weak self] in
            self?.fetchMessage = message
        }
    }
    
    private func trackProgress(phase: String, caption: String?, locationName: String?) {
        var props: [String: Any] = ["phase": phase]
        if let c = caption, !c.isEmpty { props["caption"] = c }
        if let l = locationName, !l.isEmpty { props["locationName"] = l }
        analyticsManager.track(event: "progressPhase", properties: props)
    }
    
    // MARK: - Recommendation Payload Normalization / Diagnostics
    /// Attempts to coerce the raw personalized recommendations payload into the
    /// `[String: Any]` dictionary shape expected by
    /// `PlaceResponseFormatter.recommendedPlaceSearchResponses(with:)`.
    ///
    /// Tries envelope style first (["response": ...], ["data": ...]), then falls back to top-level dict.
    private func normalizeRecommendedResponsePayload(_ raw: Any) -> [String: Any]? {
        // Try envelope style first
        if let outer = raw as? [String: Any] {
            if let inner = outer["response"] as? [String: Any] {
                return inner
            }
            if let inner = outer["data"] as? [String: Any] {
                return inner
            }
            // Fall back to top-level dict as-is
            return outer
        }
        // Not a dictionary or recognizable envelope
        return nil
    }

    // MARK: - Search Timeout & Messaging
    
    public func updateFoundResultsMessage() {
        let recCount = self.recommendedPlaceResults.count
        
        let placeCount = self.placeResults.count
        
        let name = self.selectedDestinationLocationName()
        coalesceOnNextFrame {
            self.fetchMessage = "Found \(recCount) recommended and \(placeCount) places near \(name)."
        }
    }
    
    public func resetPlaceModel() async throws {
        let preservedSelectedDestination = selectedDestinationLocationChatResult
        
        // Clear all state consistently
        updateAllResults(clearAll: true)
                
        analyticsManager.track(event:"resetPlaceModel", properties: nil)
    }
    
    
    public func categoricalSearchModel() async {
        let blendedResults = categoricalResults()
        updateAllResults(industry: blendedResults)
    }
    
    /// Ensures industry results are populated if they're empty
    public func ensureIndustryResultsPopulated() async {
        if industryResults.isEmpty {
            await categoricalSearchModel()
        }
    }
    
    public func categoricalResults()->[CategoryResult] {
        var retval = [CategoryResult]()
        var categoryMap = [String: Int]() // For efficient lookup
        
        for categoryCode in assistiveHostDelegate.categoryCodes {
            var newChatResults = [ChatResult]()
            for values in categoryCode.values {
                for index in 0..<values.count {
                    let value = values[index]
                    if let category = value["category"]{
                        let chatResult = ChatResult(  index:index, identity: category, title:category, list:category, icon: "", rating: 1, section:assistiveHostDelegate.section(for:category), placeResponse:nil, recommendedPlaceResponse: nil)
                        newChatResults.append(chatResult)
                    }
                }
            }
            
            let keys = Array(categoryCode.keys.sorted())
            for index in 0..<keys.count {
                let key = keys[index]
                newChatResults.append(ChatResult(index:index,identity: key, title: key, list:key, icon:"", rating: 1, section: assistiveHostDelegate.section(for:key), placeResponse:nil, recommendedPlaceResponse: nil))
                
                if let existingIndex = categoryMap[key] {
                    // Update existing result
                    let existingResult = retval[existingIndex]
                    if !existingResult.categoricalChatResults.isEmpty {
                        newChatResults.append(contentsOf: existingResult.categoricalChatResults)
                    }
                    
                    let newResult = CategoryResult(identity:key, parentCategory: key, list:key, icon:"", rating:1, section:assistiveHostDelegate.section(for:key), categoricalChatResults: newChatResults)
                    retval[existingIndex] = newResult
                } else {
                    // Add new result
                    let newResult = CategoryResult(identity: key, parentCategory: key, list:key, icon: "", rating: 1, section: assistiveHostDelegate.section(for:key), categoricalChatResults: newChatResults)
                    categoryMap[key] = retval.count
                    retval.append(newResult)
                }
            }
        }
        
        return retval
    }
    
    
    // MARK: - Filtered Results
    
    public var filteredRecommendedPlaceResults: [ChatResult] {
        return recommendedPlaceResults
    }
    
    public func filteredLocationResults() -> [LocationResult] {
        var results = [LocationResult]()
                
        // Add cached locations
        results.append(contentsOf: cacheManager.cachedLocationResults)
        
        // Add location results that aren't already in cache
        results.append(contentsOf: locationResults.filter({ result in
            !cacheManager.cachedLocationResults.contains(where: { $0.locationName.lowercased() == result.locationName.lowercased() })
        }))
        
        let sortedResults = results.sorted(by: { $0.locationName < $1.locationName })
        return sortedResults
    }
    
    public var filteredResults: [CategoryResult] {
        // Ensure industry results are populated before filtering
        if industryResults.isEmpty {
            Task {
                await ensureIndustryResultsPopulated()
            }
        }
        return industryResults.filter { !$0.categoricalChatResults.isEmpty }
    }
    
    public var filteredPlaceResults: [ChatResult] {
        return placeResults
    }
    
    // MARK: Place Result Methods
    
    public func placeChatResult(for id: ChatResult.ID) -> ChatResult? {
        if !recommendedPlaceResults.isEmpty {
            if let recommendedResult = recommendedPlaceResults.first(where: { $0.id == id }) {
                return recommendedResult
            }
        }
        
        if !placeResults.isEmpty {
            if let placeResult = placeResults.first(where: { $0.id == id }) {
                return placeResult
            }
        }
        
        if !relatedPlaceResults.isEmpty {
            if let recommendedResult = relatedPlaceResults.first(where: { $0.id == id }) {
                return recommendedResult
            }
        }
        
        return nil
    }
    
    public func placeChatResult(with fsqID: String) -> ChatResult? {
        return (
            placeResults.first { $0.placeResponse?.fsqID == fsqID }
            ?? recommendedPlaceResults.first { $0.recommendedPlaceResponse?.fsqID == fsqID || $0.placeResponse?.fsqID == fsqID }
        )
    }
    
    // MARK: Chat Result Methods
    
    public func chatResult(title: String) -> ChatResult? {
        return industryResults.compactMap { $0.result(title: title) }.first
    }
    
    public func industryChatResult(for id: ChatResult.ID) -> ChatResult? {
        let allResults = industryResults.compactMap { $0.categoricalChatResults }
        for results in allResults {
            if let result = results.first(where: { $0.id == id || $0.parentId == id }) {
                return result
            }
        }
        return nil
    }
    
    public func tasteChatResult(for id: CategoryResult.ID) -> ChatResult? {
        return tasteResults.first(where: { $0.id == id })?.categoricalChatResults.first
    }
    
    // MARK: Category Result Methods
    
    public func industryCategoryResult(for id: CategoryResult.ID) -> CategoryResult? {
        return industryResults.flatMap { [$0] + $0.children }.first { $0.id == id }
    }
    
    public func tasteCategoryResult(for id: CategoryResult.ID) -> CategoryResult? {
        return tasteResults.first { $0.id == id }
    }
    
    public func cachedIndustryResult(for id:CategoryResult.ID)->CategoryResult? {
        return cacheManager.cachedIndustryResults.first { $0.id == id }
    }
    
    public func cachedPlaceResult(for id: CategoryResult.ID) -> CategoryResult? {
        return cacheManager.cachedPlaceResults.first { $0.id == id }
    }
    
    public func cachedChatResult(for id: CategoryResult.ID) -> ChatResult? {
        if let parentCategory = cacheManager.allCachedResults.first(where: { $0.id == id }) {
            return parentCategory.categoricalChatResults.first
        }
        
        return nil
    }
    
    public func cachedTasteResult(for id: CategoryResult.ID) -> CategoryResult? {
        return cacheManager.cachedTasteResults.first { $0.id == id }
    }
    
    
    public func cachedTasteResultTitle(_ title: String) -> CategoryResult? {
        return cacheManager.cachedTasteResults.first { $0.parentCategory == title}
    }
    
    public func cachedRecommendationData(for identity: String) -> RecommendationData? {
        return cacheManager.cachedRecommendationData.first { $0.identity == identity }
    }
    
    // MARK: - Location Handling
    
    public func locationChatResult(for id: LocationResult.ID, in locationResults: [LocationResult]) -> LocationResult? {
        return locationResults.first { $0.id == id }
    }
    
    public func locationChatResult(with title: String, in locationResults: [LocationResult]) async -> LocationResult? {
        if let existingResult = locationResults.first(where: { $0.locationName == title }) {
            return existingResult
        }
        
        do {
            let placemarks = try await locationService.lookUpLocationName(name: title)
            if let firstPlacemark = placemarks.first, let location = firstPlacemark.location {
                let result = LocationResult(locationName: title, location:location)
                return result
            }
        } catch {
            Task { @MainActor in
                analyticsManager.trackError(error: error, additionalInfo: ["title": title])
            }
        }
        
        return nil
    }
    
    @discardableResult
    public func refreshModel(query: String, queryIntents: [AssistiveChatHostIntent]?, filters:[String:Any]) async throws -> [ChatResult] {
        
        if let lastIntent = queryIntents?.last {
            return try await model(intent: lastIntent)
        } else {
            let safeQuery = sanitizeCaption(query)
            // Normalize to a comma-separated token list with no whitespace
            let tokens = safeQuery
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let normalizedCaption = joinSearchTerms(tokens)
            let intent = assistiveHostDelegate.determineIntent(for: normalizedCaption, override: nil)
            let queryParameters = try await assistiveHostDelegate.defaultParameters(for: normalizedCaption, filters: filters)
            
            // Use selectedDestinationLocationChatResult as the search location
            let searchLocation = selectedDestinationLocationChatResult
            
            let newIntent = AssistiveChatHostIntent(
                caption: normalizedCaption,
                intent: intent,
                selectedPlaceSearchResponse: nil,
                selectedPlaceSearchDetails: nil,
                placeSearchResponses: [],
                selectedDestinationLocation: searchLocation,
                placeDetailsResponses: nil,
                queryParameters: queryParameters
            )
            await assistiveHostDelegate.appendIntentParameters(intent: newIntent, modelController: self)
            return try await model(intent: newIntent)
        }
    }
    
    
    
    
    /// Build autocomplete place results and update model state.
    public func autocompletePlaceModel(caption: String, intent: AssistiveChatHostIntent) async throws -> [ChatResult] {
        
        let autocompleteResponse = try await placeSearchService.placeSearchSession.autocomplete(
            caption: caption,
            parameters: intent.queryParameters,
            locationResult: intent.selectedDestinationLocation
        )
        let placeSearchResponses = try PlaceResponseFormatter.autocompletePlaceSearchResponses(with: autocompleteResponse)
        intent.placeSearchResponses = placeSearchResponses
        
        // Build lightweight chat results for display
        let section = assistiveHostDelegate.section(for: caption)
        var chatResults: [ChatResult] = []
        chatResults.reserveCapacity(placeSearchResponses.count)
        for (index, response) in placeSearchResponses.enumerated() {
            let results = PlaceResponseFormatter.placeChatResults(
                for: intent,
                place: response,
                section: section,
                list: caption,
                index: index,
                rating: 1,
                details: nil
            )
            chatResults.append(contentsOf: results)
        }
        
        // Update model results on main actor
        if placeSearchResponses.count == 1 {
            updateAllResults(places: chatResults, mapPlaces: chatResults, selectedPlaceFsqId: placeSearchResponses.first?.fsqID)
        } else {
            updateAllResults(places: chatResults, mapPlaces: chatResults)
        }
        return chatResults
    }
    
    /// Prefetch details for the first N places to speed up initial paint.
    private func prefetchInitialDetailsIfNeeded(intent: AssistiveChatHostIntent, initialCount: Int = 8) async throws {
        let responses = intent.placeSearchResponses
        guard !responses.isEmpty else { return }
        let count = max(0, min(initialCount, responses.count))
        guard count > 0 else { return }
        
        let initialResponses = Array(responses.prefix(count))
        // Build a lightweight intent with only the initial responses
        let tempIntent = AssistiveChatHostIntent(
            caption: intent.caption,
            intent: .Search,
            selectedPlaceSearchResponse: nil,
            selectedPlaceSearchDetails: nil,
            placeSearchResponses: initialResponses,
            selectedDestinationLocation: intent.selectedDestinationLocation,
            placeDetailsResponses: nil,
            recommendedPlaceSearchResponses: intent.recommendedPlaceSearchResponses,
            relatedPlaceSearchResponses: intent.relatedPlaceSearchResponses,
            queryParameters: intent.queryParameters
        )
        
        try await placeSearchService.detailIntent(intent: tempIntent, cacheManager:cacheManager)
        // Merge prefetched details back into the main intent
        if let details = tempIntent.placeDetailsResponses, !details.isEmpty {
            if intent.placeDetailsResponses == nil {
                intent.placeDetailsResponses = details
            } else {
                // Append only new details
                let existingIDs = Set(intent.placeDetailsResponses?.map { $0.fsqID } ?? [])
                let newOnes = details.filter { !existingIDs.contains($0.fsqID) }
                intent.placeDetailsResponses?.append(contentsOf: newOnes)
            }
        }
    }
    
    /// Orchestrates fetching recommendations and places, merges responses, prefetches details, and builds results.
    private func performSearch(for intent: AssistiveChatHostIntent) async throws {
        let destinationName = selectedDestinationLocationName()
        let caption = intent.caption
        setProgressMessage(phase: "Fetching recommendations", caption: caption, locationName: destinationName)
        trackProgress(phase: "search.fetchRecommendations.begin", caption: caption, locationName: destinationName)
        let recHandle = Task(priority: .userInitiated) { () -> ([RecommendedPlaceSearchResponse], Bool) in
            do {
                let rawPayload = try await placeSearchService.personalizedSearchSession.fetchRecommendedVenues(
                    with: await placeSearchService.recommendedPlaceSearchRequest(intent: intent),
                    cacheManager: cacheManager
                )
                
                // --- Diagnostics BEFORE normalization/parse ---
                var topLevelKeys: [String] = []
                if let dict = rawPayload as? [String: Any] {
                    topLevelKeys = Array(dict.keys)
                }
                
                self.analyticsManager.track(
                    event: "recommendedSearch.rawPayload",
                    properties: [
                        "type": String(describing: type(of: rawPayload)),
                        "topLevelKeys": topLevelKeys
                    ]
                )
                
                // Normalize common envelopes like { "response": {...} } into a flat dictionary.
                let normalized = self.normalizeRecommendedResponsePayload(rawPayload)
                
                var normalizedKeys: [String] = []
                if let nk = normalized {
                    normalizedKeys = Array(nk.keys)
                }
                
                self.analyticsManager.track(
                    event: "recommendedSearch.normalizedPayload",
                    properties: [
                        "didNormalize": normalized != nil,
                        "normalizedKeys": normalizedKeys
                    ]
                )
                
                // Gracefully handle bad / unexpected shapes.
                guard let normalizedDict = normalized else {
                    self.analyticsManager.track(
                        event: "recommendedSearch.missingNormalizedDict",
                        properties: [
                            "reason": "Payload not dictionary / unrecognized envelope"
                        ]
                    )
                    return ([], false)
                }
                
                // Attempt parse
                do {
                    let recs = try PlaceResponseFormatter.recommendedPlaceSearchResponses(with: normalizedDict)
                    
                    self.analyticsManager.track(
                        event: "recommendedSearch.parsed",
                        properties: [
                            "count": recs.count
                        ]
                    )
                    
                    return (recs, true)
                } catch {
                    // Parsing failed, but we don't want to throw upstream.
                    self.analyticsManager.trackError(
                        error: error,
                        additionalInfo: [
                            "phase": "recommendedSearch.parseError",
                            "normalizedKeys": normalizedKeys
                        ]
                    )
                    return ([], false)
                }
            } catch {
                // Network / request layer threw.
                self.analyticsManager.trackError(
                    error: error,
                    additionalInfo: ["phase": "recommendedSearch.fetchError"]
                )
                return ([], false)
            }
        }
        
        setProgressMessage(phase: "Fetching places", caption: caption, locationName: destinationName)
        trackProgress(phase: "search.fetchPlaces.begin", caption: caption, locationName: destinationName)
        let placeHandle = Task(priority: .userInitiated) { () -> ([PlaceSearchResponse], Bool) in
            do {
                let raw = try await placeSearchService.placeSearchSession.query(request: await placeSearchService.placeSearchRequest(intent: intent))
                let places = try PlaceResponseFormatter.placeSearchResponses(with: raw)
                return (places, true)
            } catch {
                analyticsManager.trackError(error: error, additionalInfo: ["phase": "placeSearch"])
                return ([], false)
            }
        }
        
        let (recs, recOK) = await recHandle.value
        let (places, placeOK) = await placeHandle.value

        trackProgress(phase: "search.fetchRecommendations.end", caption: caption, locationName: destinationName)
        trackProgress(phase: "search.fetchPlaces.end", caption: caption, locationName: destinationName)
        setProgressMessage(phase: "Merging results", caption: caption, locationName: destinationName)
        
        var finalPlaceResponses: [PlaceSearchResponse] = places

        if !recs.isEmpty {
            // keep the raw recommended objects for downstream display/details
            intent.recommendedPlaceSearchResponses = recs

            // convert recs -> PlaceSearchResponse rows for UI
            let recAsPlaces = PlaceResponseFormatter.placeSearchResponses(from: recs)

            if !recAsPlaces.isEmpty {
                finalPlaceResponses = recAsPlaces
                print("✅ Using \(recAsPlaces.count) recommended places as finalPlaceResponses")
            } else {
                print("⚠️ Parsed \(recs.count) recs but produced 0 PlaceSearchResponse rows. Falling back to \(places.count) /v3 places.")
            }
        }

        intent.placeSearchResponses = finalPlaceResponses
        
        setProgressMessage(phase: "Prefetching details", caption: caption, locationName: destinationName)
        trackProgress(phase: "search.prefetchDetails.begin", caption: caption, locationName: destinationName)
        try await prefetchInitialDetailsIfNeeded(intent: intent, initialCount: 8)
        trackProgress(phase: "search.prefetchDetails.end", caption: caption, locationName: destinationName)
        setProgressMessage(phase: "Building results", caption: caption, locationName: destinationName)
        
        try await searchQueryModel(intent: intent)
        trackProgress(phase: "search.buildResults.end", caption: caption, locationName: destinationName)
        updateFoundResultsMessage()
    }
    
    @discardableResult
    public func placeQueryModel(intent: AssistiveChatHostIntent) async throws -> [ChatResult] {
        // Component-level in-flight guard to prevent duplicate place queries for the same intent key
        let _placeComponentKey = makeSearchKey(for: intent) + "::place"
        if inFlightComponentKeys.contains(_placeComponentKey) {
            print("🔁 Suppressing duplicate placeQueryModel for key: \(_placeComponentKey)")
            analyticsManager.track(event: "placeQueryModel.duplicateSuppressed", properties: ["key": _placeComponentKey])
            return placeResults
        }
        inFlightComponentKeys.insert(_placeComponentKey)
        defer { inFlightComponentKeys.remove(_placeComponentKey) }
        
        // Prepare inputs
        let hasSelected = (intent.selectedPlaceSearchResponse != nil && intent.selectedPlaceSearchDetails != nil)
        let placeResponses = intent.placeSearchResponses
        let caption = intent.caption
        let section = assistiveHostDelegate.section(for: caption)
        
        try await relatedPlaceQueryModel(intent: intent)
        // Ensure details are present for unselected flows by fetching any missing ones
        if !hasSelected && !placeResponses.isEmpty {
            let existingIDs = Set((intent.placeDetailsResponses ?? []).map { $0.fsqID })
            let missingResponses = placeResponses.filter { !existingIDs.contains($0.fsqID) }
            if !missingResponses.isEmpty {
                let tempIntent = AssistiveChatHostIntent(
                    caption: intent.caption,
                    intent: .Place,
                    selectedPlaceSearchResponse: nil,
                    selectedPlaceSearchDetails: nil,
                    placeSearchResponses: missingResponses,
                    selectedDestinationLocation: intent.selectedDestinationLocation,
                    placeDetailsResponses: nil,
                    recommendedPlaceSearchResponses: intent.recommendedPlaceSearchResponses,
                    relatedPlaceSearchResponses: intent.relatedPlaceSearchResponses,
                    queryParameters: intent.queryParameters
                )
                do {
                    try await placeSearchService.detailIntent(intent: tempIntent, cacheManager: cacheManager)
                    if let fetched = tempIntent.placeDetailsResponses, !fetched.isEmpty {
                        let merged = intent.placeDetailsResponses ?? []
                        let mergedIDs = Set(merged.map { $0.fsqID })
                        let newOnes = fetched.filter { !mergedIDs.contains($0.fsqID) }
                        if !newOnes.isEmpty { intent.placeDetailsResponses = merged + newOnes }
                    }
                } catch {
                    analyticsManager.trackError(error: error, additionalInfo: ["phase": "placeQueryModel.ensureDetails"])
                }
            }
        }
        // Heavy compute off-main: build chatResults
        let chatResults: [ChatResult] = await Task.detached(priority: .userInitiated) { () -> [ChatResult] in
            var results: [ChatResult] = []
            if hasSelected, let response = intent.selectedPlaceSearchResponse, let details = intent.selectedPlaceSearchDetails {
                let r = PlaceResponseFormatter.placeChatResults(
                    for: intent,
                    place: response,
                    section: section,
                    list: caption,
                    index: 0,
                    rating: 1,
                    details: details,
                    recommendedPlaceResponse: nil
                )
                results.append(contentsOf: r)
            } else if !placeResponses.isEmpty {
                let detailsByID: [String: PlaceDetailsResponse] = {
                    var dict: [String: PlaceDetailsResponse] = [:]
                    if let all = intent.placeDetailsResponses {
                        for d in all { dict[d.fsqID] = d }
                    }
                    return dict
                }()
                for index in 0..<placeResponses.count {
                    let response = placeResponses[index]
                    guard !response.name.isEmpty else { continue }
                    let details = detailsByID[response.fsqID]
                    let r = PlaceResponseFormatter.placeChatResults(
                        for: intent,
                        place: response,
                        section: section,
                        list: caption,
                        index: index,
                        rating: 1,
                        details: details,
                        recommendedPlaceResponse: nil
                    )
                    results.append(contentsOf: r)
                }
            }

            return results
        }.value
        
        updateAllResults(
            places: chatResults,
            selectedPlaceFsqId: intent.selectedPlaceSearchResponse?.fsqID
        )
        
        return chatResults
    }
    
    public func recommendedPlaceQueryModel(intent: AssistiveChatHostIntent, cacheManager: CacheManager) async throws {
        // Component-level in-flight guard to prevent duplicate recommendations queries for the same intent key
        let _recsComponentKey = makeSearchKey(for: intent) + "::recs"
        if inFlightComponentKeys.contains(_recsComponentKey) {
            print("🔁 Suppressing duplicate recommendedPlaceQueryModel for key: \(_recsComponentKey)")
            analyticsManager.track(event: "recommendedPlaceQueryModel.duplicateSuppressed", properties: ["key": _recsComponentKey])
            return
        }
        inFlightComponentKeys.insert(_recsComponentKey)
        defer { inFlightComponentKeys.remove(_recsComponentKey) }
        
        // Capture dependencies and inputs for off-main work
        let recResponses = intent.recommendedPlaceSearchResponses ?? []
        let caption = intent.caption
        let section = assistiveHostDelegate.section(for: caption)
        let recommender = recommenderService
        
        // Early exit: nothing to do
        if recResponses.isEmpty {
            updateAllResults(recommended: [])
            return
        }
#if canImport(CreateML)
        let hasSufficientTrainingData = (cacheManager.cachedTasteResults.count > 2 || cacheManager.cachedIndustryResults.count > 2)
        let precomputedTrainingData: [RecommendationData] = hasSufficientTrainingData ? recommender.recommendationData(
            tasteCategoryResults: cacheManager.cachedTasteResults,
            industryCategoryResults: cacheManager.cachedIndustryResults,
            placeRecommendationData: cacheManager.cachedRecommendationData
        ) : []
        
#if canImport(CreateML)
        if hasSufficientTrainingData {
            let destinationName = selectedDestinationLocationName()
            let caption = intent.caption
            setProgressMessage(phase: "Personalizing recommendations", caption: caption, locationName: destinationName)
            trackProgress(phase: "recommendations.ml.begin", caption: caption, locationName: destinationName)
        }
#endif
        
#else
        let hasSufficientTrainingData = false
        let precomputedTrainingData: [RecommendationData] = []
#endif
        
        // Heavy compute off-main
        let sortedResults: [ChatResult] = try await Task.detached(priority: .userInitiated) { () -> [ChatResult] in
            var recommendedChatResults = [ChatResult]()
            
#if canImport(CreateML)
            if recResponses.count > 1 {
                if hasSufficientTrainingData {
                    let model = try recommender.model(with: precomputedTrainingData)
                    let testingData = recommender.testingData(with: recResponses)
                    let recommenderResults = try recommender.recommend(from: testingData, with: model)
                    for index in 0..<recResponses.count {
                        let response = recResponses[index]
                        guard !response.fsqID.isEmpty else { continue }
                        let rating = index < recommenderResults.count ? (recommenderResults[index].attributeRatings.first?.value ?? 1) : 1
                        let placeResponse = PlaceSearchResponse(
                            fsqID: response.fsqID,
                            name: response.name,
                            categories: response.categories,
                            latitude: response.latitude,
                            longitude: response.longitude,
                            address: response.address,
                            addressExtended: response.formattedAddress,
                            country: response.country,
                            dma: response.neighborhood,
                            formattedAddress: response.formattedAddress,
                            locality: response.city,
                            postCode: response.postCode,
                            region: response.state,
                            chains: [],
                            link: "",
                            childIDs: [],
                            parentIDs: []
                        )
                        let results = PlaceResponseFormatter.placeChatResults(
                            for: intent,
                            place: placeResponse,
                            section: section,
                            list: caption,
                            index: index,
                            rating: rating,
                            details: nil,
                            recommendedPlaceResponse: response
                        )
                        recommendedChatResults.append(contentsOf: results)
                    }
                } else {
                    for index in 0..<recResponses.count {
                        let response = recResponses[index]
                        guard !response.fsqID.isEmpty else { continue }
                        let placeResponse = PlaceSearchResponse(
                            fsqID: response.fsqID,
                            name: response.name,
                            categories: response.categories,
                            latitude: response.latitude,
                            longitude: response.longitude,
                            address: response.address,
                            addressExtended: response.formattedAddress,
                            country: response.country,
                            dma: response.neighborhood,
                            formattedAddress: response.formattedAddress,
                            locality: response.city,
                            postCode: response.postCode,
                            region: response.state,
                            chains: [],
                            link: "",
                            childIDs: [],
                            parentIDs: []
                        )
                        let results = PlaceResponseFormatter.placeChatResults(
                            for: intent,
                            place: placeResponse,
                            section: section,
                            list: caption,
                            index: index,
                            rating: 1,
                            details: nil,
                            recommendedPlaceResponse: response
                        )
                        recommendedChatResults.append(contentsOf: results)
                    }
                }
            } else {
                if let response = recResponses.first, !response.fsqID.isEmpty {
                    let placeResponse = PlaceSearchResponse(
                        fsqID: response.fsqID,
                        name: response.name,
                        categories: response.categories,
                        latitude: response.latitude,
                        longitude: response.longitude,
                        address: response.address,
                        addressExtended: response.formattedAddress,
                        country: response.country,
                        dma: response.neighborhood,
                        formattedAddress: response.formattedAddress,
                        locality: response.city,
                        postCode: response.postCode,
                        region: response.state,
                        chains: [],
                        link: "",
                        childIDs: [],
                        parentIDs: []
                    )
                    let results = PlaceResponseFormatter.placeChatResults(
                        for: intent,
                        place: placeResponse,
                        section: section,
                        list: caption,
                        index: 0,
                        rating: 1,
                        details: nil,
                        recommendedPlaceResponse: response
                    )
                    recommendedChatResults.append(contentsOf: results)
                }
            }
#else
            for index in 0..<recResponses.count {
                let response = recResponses[index]
                guard !response.fsqID.isEmpty else { continue }
                let placeResponse = PlaceSearchResponse(
                    fsqID: response.fsqID,
                    name: response.name,
                    categories: response.categories,
                    latitude: response.latitude,
                    longitude: response.longitude,
                    address: response.address,
                    addressExtended: response.formattedAddress,
                    country: response.country,
                    dma: response.neighborhood,
                    formattedAddress: response.formattedAddress,
                    locality: response.city,
                    postCode: response.postCode,
                    region: response.state,
                    chains: [],
                    link: "",
                    childIDs: [],
                    parentIDs: []
                )
                let results = PlaceResponseFormatter.placeChatResults(
                    for: intent,
                    place: placeResponse,
                    section: section,
                    list: caption,
                    index: index,
                    rating: 1,
                    details: nil,
                    recommendedPlaceResponse: response
                )
                recommendedChatResults.append(contentsOf: results)
            }
#endif
            
            // Sort deterministically off-main
            let sorted = recommendedChatResults.sorted { lhs, rhs in
                if lhs.rating == rhs.rating { return lhs.index < rhs.index }
                return lhs.rating > rhs.rating
            }
            return sorted
        }.value
        
#if canImport(CreateML)
        if hasSufficientTrainingData {
            trackProgress(phase: "recommendations.ml.end", caption: caption, locationName: selectedDestinationLocationName())
        }
#endif
        
        // Apply on main actor
        updateAllResults(recommended: sortedResults)
    }
    
    public func relatedPlaceQueryModel(intent: AssistiveChatHostIntent) async throws {
        // Capture inputs and dependencies
        let relatedResponses = intent.relatedPlaceSearchResponses ?? []
        let caption = intent.caption
        let section = assistiveHostDelegate.section(for: caption)
        
        // Early exit
        if relatedResponses.isEmpty {
            updateAllResults(related: [])
            return
        }
        
        // Heavy compute off-main
        let sortedResults: [ChatResult] = await Task.detached(priority: .userInitiated) { () -> [ChatResult] in
            var relatedChatResults: [ChatResult] = []
            
            for index in 0..<relatedResponses.count {
                let response = relatedResponses[index]
                guard !response.fsqID.isEmpty else { continue }
                let placeResponse = PlaceSearchResponse(
                    fsqID: response.fsqID,
                    name: response.name,
                    categories: response.categories,
                    latitude: response.latitude,
                    longitude: response.longitude,
                    address: response.address,
                    addressExtended: response.formattedAddress,
                    country: response.country,
                    dma: response.neighborhood,
                    formattedAddress: response.formattedAddress,
                    locality: response.city,
                    postCode: response.postCode,
                    region: response.state,
                    chains: [],
                    link: "",
                    childIDs: [],
                    parentIDs: []
                )
                let results = PlaceResponseFormatter.placeChatResults(
                    for: intent,
                    place: placeResponse,
                    section: section,
                    list: caption,
                    index: index,
                    rating: 1,
                    details: nil,
                    recommendedPlaceResponse: response
                )
                relatedChatResults.append(contentsOf: results)
            }
            
            let sorted = relatedChatResults.sorted { lhs, rhs in
                if lhs.rating == rhs.rating { return lhs.index < rhs.index }
                return lhs.rating > rhs.rating
            }
            return sorted
        }.value
        
        // Apply on main actor
        updateAllResults(related: sortedResults)
    }
    
    @discardableResult
    public func searchQueryModel(intent: AssistiveChatHostIntent) async throws -> [ChatResult] {
        var chatResults = [ChatResult]()
        
        let existingPlaceResults = placeResults.compactMap { $0.placeResponse }
        
        if existingPlaceResults == intent.placeSearchResponses,
           let selectedPlaceSearchDetails = intent.selectedPlaceSearchDetails,
           let selectedPlaceChatResultFsqId = selectedPlaceChatResultFsqId,
           let placeChatResult = placeChatResult(with: selectedPlaceChatResultFsqId) {
            var newResults = [ChatResult]()
            for placeResult in placeResults {
                if placeResult.placeResponse?.fsqID == placeChatResult.placeResponse?.fsqID, placeResult.placeDetailsResponse == nil {
                    var updatedPlaceResult = placeResult
                    updatedPlaceResult.replaceDetails(response: selectedPlaceSearchDetails)
                    newResults.append(updatedPlaceResult)
                } else {
                    newResults.append(placeResult)
                }
            }
            
            try await recommendedPlaceQueryModel(intent: intent, cacheManager: cacheManager)
            
            updateAllResults(places: newResults, mapPlaces: newResults)
            
            return chatResults
        }
        
        if let detailsResponses = intent.placeDetailsResponses {
            var allDetailsResponses = detailsResponses
            if let selectedPlaceSearchDetails = intent.selectedPlaceSearchDetails {
                allDetailsResponses.append(selectedPlaceSearchDetails)
            }
            for index in 0..<allDetailsResponses.count {
                let detailsResponse = allDetailsResponses[index]
                let results = PlaceResponseFormatter.placeChatResults(
                    for: intent,
                    place: detailsResponse.searchResponse,
                    section: assistiveHostDelegate.section(for: intent.caption), list: intent.caption, index: index, rating: 1,
                    details: detailsResponse
                )
                chatResults.append(contentsOf: results)
            }
        }
        
        for index in 0..<intent.placeSearchResponses.count {
            let response = intent.placeSearchResponses[index]
            var results = PlaceResponseFormatter.placeChatResults(for: intent, place: response, section: assistiveHostDelegate.section(for: intent.caption), list: intent.caption, index: index, rating: 1, details: nil)
            results = results.filter { result in
                !(intent.placeDetailsResponses?.contains { $0.fsqID == result.placeResponse?.fsqID } ?? false)
            }
            chatResults.append(contentsOf: results)
        }
        
        try await recommendedPlaceQueryModel(intent: intent, cacheManager: cacheManager)
        
        updateAllResults(places: chatResults, mapPlaces: chatResults)
        
        return chatResults
    }
    
    /// Lightweight details prefetch that avoids rebuilding search intent.
    @MainActor
    public func fetchPlaceDetailsIfNeeded(for result: ChatResult) async throws {
        // Fast exit if details already exist
        
        if result.placeDetailsResponse != nil { return }
        if result.placeResponse != nil, result.placeResponse?.latitude == 0 {
            
            let queryParameters = try await assistiveHostDelegate.defaultParameters(for: result.title, filters:[:])
            
            try await refreshModel(query: result.title, queryIntents: [.init(caption: result.title, intent: .Place, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, placeSearchResponses: [], selectedDestinationLocation: selectedDestinationLocationChatResult, placeDetailsResponses: nil, queryParameters: queryParameters)], filters: [:])
        }
        
        // Capture minimal inputs on main actor, then hop off
        let fsqID = result.placeResponse?.fsqID ?? result.recommendedPlaceResponse?.fsqID
        guard let fsqID else { return }
        let caption = result.title
        let selectedID = selectedDestinationLocationChatResult
        let delegate = assistiveHostDelegate
        let service = placeSearchService
        
        // Prepare a base response snapshot (pure data only)
        let basePlaceResponse: PlaceSearchResponse?
        if let pr = result.placeResponse {
            basePlaceResponse = pr
        } else if let rr = result.recommendedPlaceResponse {
            basePlaceResponse = PlaceSearchResponse(
                fsqID: rr.fsqID,
                name: rr.name,
                categories: rr.categories,
                latitude: rr.latitude,
                longitude: rr.longitude,
                address: rr.address,
                addressExtended: rr.formattedAddress,
                country: rr.country,
                dma: rr.neighborhood,
                formattedAddress: rr.formattedAddress,
                locality: rr.city,
                postCode: rr.postCode,
                region: rr.state,
                chains: [],
                link: "",
                childIDs: [],
                parentIDs: []
            )
        } else {
            basePlaceResponse = nil
        }
        guard let basePlaceResponse else { return }
        
        let params = try? await delegate.defaultParameters(for: caption, filters: [:])
        let intent = AssistiveChatHostIntent(
            caption: caption,
            intent: .Place,
            selectedPlaceSearchResponse: basePlaceResponse,
            selectedPlaceSearchDetails: nil,
            placeSearchResponses: [basePlaceResponse],
            selectedDestinationLocation: selectedID,
            placeDetailsResponses: nil,
            queryParameters: params
        )
        try await relatedPlaceQueryModel(intent: intent)
        // Perform detail fetch off-main to avoid holding the main actor while awaiting network
        try await Task.detached(priority: .userInitiated) {
            try await service.detailIntent(intent: intent, cacheManager: self.cacheManager)
        }.value
        let detailsResponse = intent.selectedPlaceSearchDetails
        intent.selectedPlaceSearchResponse = intent.selectedPlaceSearchDetails?.searchResponse
        
        guard let details = detailsResponse else { return }
        
        // Apply to model on the main actor
        func update(_ arr: inout [ChatResult]) {
            var newArr: [ChatResult] = []
            newArr.reserveCapacity(arr.count)
            for item in arr {
                if (item.placeResponse?.fsqID == fsqID || item.recommendedPlaceResponse?.fsqID == fsqID),
                   item.placeDetailsResponse == nil {
                    var updated = item
                    updated.replace(response: details.searchResponse)
                    updated.replaceDetails(response: details)
                    newArr.append(updated)
                } else {
                    newArr.append(item)
                }
            }
            arr = newArr
        }
        
        update(&self.placeResults)
        update(&self.recommendedPlaceResults)
        self.updateFoundResultsMessage()
    }
    
    public func updateLastIntentParameter(for placeChatResult: ChatResult, selectedDestinationChatResult: LocationResult, filters: [String : Any]) async throws {
        guard let lastIntent = assistiveHostDelegate.queryIntentParameters.queryIntents.last else {
            return
        }
        
        let queryParameters = try await assistiveHostDelegate.defaultParameters(for: placeChatResult.title, filters: filters)
        let newIntent = AssistiveChatHostIntent(caption: placeChatResult.title, intent: .Place, selectedPlaceSearchResponse: placeChatResult.placeResponse, selectedPlaceSearchDetails: placeChatResult.placeDetailsResponse, placeSearchResponses: lastIntent.placeSearchResponses, selectedDestinationLocation: selectedDestinationChatResult, placeDetailsResponses: nil, recommendedPlaceSearchResponses: lastIntent.recommendedPlaceSearchResponses, relatedPlaceSearchResponses: lastIntent.relatedPlaceSearchResponses, queryParameters: queryParameters)
        
        guard placeChatResult.placeResponse != nil, placeChatResult.placeResponse?.latitude != 0 else {
            await assistiveHostDelegate.updateLastIntentParameters(intent: newIntent, modelController: self)
            try await assistiveHostDelegate.receiveMessage(caption: newIntent.caption, isLocalParticipant: true, filters: filters, modelController: self, overrideIntent: nil, selectedDestinationLocation: selectedDestinationChatResult)
            return
        }
        
        await enqueueLazyDetailFetch(for: placeChatResult)
        
        await assistiveHostDelegate.updateLastIntentParameters(intent: newIntent, modelController: self)
        
        let queryIntentParameters = assistiveHostDelegate.queryIntentParameters
        try await didUpdateQuery(with: placeChatResult.title, parameters: queryIntentParameters, filters: filters)
        
    }
    
    public func addReceivedMessage(caption: String, parameters: AssistiveChatHostQueryParameters, isLocalParticipant: Bool, filters: [String : Any], overrideIntent: AssistiveChatHostService.Intent? = nil, selectedDestinationLocation: LocationResult? = nil) async throws {
        
        let safeCaption = sanitizeCaption(caption)
        
        if let lastIntent = queryParametersHistory.last?.queryIntents.last {
            try await searchIntent(intent: lastIntent)
            try await didUpdateQuery(with: safeCaption, parameters: parameters, filters: filters)
        } else {
            var intent:AssistiveChatHostService.Intent = assistiveHostDelegate.determineIntent(for: safeCaption, override: nil)
            if let overrideIntent {
                intent = overrideIntent
            }
            
            if selectedDestinationLocation != nil, overrideIntent == .Location {
                intent = .Location
            }
            
            let queryParameters = try await assistiveHostDelegate.defaultParameters(for: safeCaption ,filters: filters)
            let newIntent = AssistiveChatHostIntent(caption: safeCaption, intent: intent, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, placeSearchResponses: [PlaceSearchResponse](), selectedDestinationLocation: selectedDestinationLocation ??  selectedDestinationLocationChatResult, placeDetailsResponses:nil, queryParameters: queryParameters)
            
            await assistiveHostDelegate.appendIntentParameters(intent: newIntent, modelController: self)
            try await searchIntent(intent: newIntent)
            try await didUpdateQuery(with: safeCaption, parameters: parameters, filters: filters)
        }
    }
    
    @discardableResult
    public func didUpdateQuery(with query: String, parameters: AssistiveChatHostQueryParameters, filters: [String : Any]) async throws -> [ChatResult] {
        let safeQuery = sanitizeCaption(query)
        return try await refreshModel(query: safeQuery, queryIntents: parameters.queryIntents, filters: filters)
    }
    
    
    public func updateQueryParametersHistory(with parameters: AssistiveChatHostQueryParameters) async {
        queryParametersHistory.append(parameters)
    }
    
    
    public func model(intent: AssistiveChatHostIntent) async throws -> [ChatResult] {
        let destinationName = selectedDestinationLocationName()
        let caption = intent.caption
        setProgressMessage(phase: "Starting search", caption: caption, locationName: destinationName)
        trackProgress(phase: "start", caption: caption, locationName: destinationName)
        
        // Minimal in-flight guard for duplicate search flows
        // Only applies to .Search and .Location, leaving .Place and autocomplete flows untouched.
        let intentKind = intent.intent
        if intentKind == .Search || intentKind == .Location {
            let key = makeSearchKey(for: intent)
            if inFlightSearchKey == key {
                print("🔁 Suppressing duplicate model search for key: \(key)")
                analyticsManager.track(event: "model.duplicateSearchSuppressed", properties: ["key": key])
                return placeResults
            }
            inFlightSearchKey = key
            defer { if inFlightSearchKey == key { inFlightSearchKey = nil } }
        }
        
        switch intentKind {
        case .Place:
            setProgressMessage(phase: "Building place results", caption: caption, locationName: destinationName)
            trackProgress(phase: "place.buildResults", caption: caption, locationName: destinationName)
            try await placeQueryModel(intent: intent)
            analyticsManager.track(event:"modelPlaceQueryBuilt", properties: nil)
        case .Location:
            // Use PlaceSearchSession to search for locations and update NavigationLocationView via locationResults
            setProgressMessage(phase: "Searching locations", caption: caption, locationName: destinationName)
            trackProgress(phase: "location.autocomplete.begin", caption: caption, locationName: destinationName)
             do {
                 let locs = try await placeSearchService.placeSearchSession.autocompleteLocationResults(
                     caption: intent.caption,
                     parameters: intent.queryParameters,
                     locationResult: intent.selectedDestinationLocation
                 )
                 updateAllResults(locations: locs, appendLocations: true)
                 trackProgress(phase: "location.autocomplete.end", caption: caption, locationName: destinationName)
                 analyticsManager.track(event: "searchIntentLocationAutocompleteBuilt", properties: ["count": locs.count])
             } catch {
                 analyticsManager.trackError(error: error, additionalInfo: ["phase": "searchIntent.location.autocomplete"])
                 throw error
             }
        case .Search:
            try await performSearch(for: intent)
            analyticsManager.track(event:"modelSearchQueryBuilt", properties: nil)
            analyticsManager.track(event: "searchIntentWithSearch", properties: nil)
        case .AutocompleteTastes:
            do {
                // Use the service to fetch and format tastes using tasteCategoryResults
                let formattedTastes = try await placeSearchService.autocompleteTastes(
                    lastIntent: intent,
                    currentTasteResults: self.tasteResults,
                    cacheManager: cacheManager
                )
                
                updateAllResults(taste: formattedTastes)
                
                setProgressMessage(phase: "Showing autocomplete tastes", caption: caption, locationName: destinationName)
                trackProgress(phase: "autocomplete.tastes.end", caption: caption, locationName: destinationName)
                analyticsManager.track(event: "searchIntentWithPersonalizedAutocompleteTastes", properties: ["count": formattedTastes.count])
            } catch {
                analyticsManager.trackError(error: error, additionalInfo: ["phase": "searchIntent.autocompleteTastes"]) 
                throw error
            }
        }
        
        return placeResults
    }
    
    
    public func searchIntent(intent: AssistiveChatHostIntent) async throws {
        let destinationName = intent.selectedDestinationLocation.locationName
        
        let caption = intent.caption
        setProgressMessage(phase: "Starting search", caption: caption, locationName: destinationName)
        trackProgress(phase: "start", caption: caption, locationName: destinationName)
        
        // Minimal in-flight guard for duplicate search flows in searchIntent
        // Only applies to .Search and .Location, leaving .Place and autocomplete flows untouched.
        let intentKind = intent.intent
        if intentKind == .Search || intentKind == .Location {
            let key = makeSearchKey(for: intent)
            if inFlightSearchKey == key {
                print("🔁 Suppressing duplicate searchIntent for key: \(key)")
                analyticsManager.track(event: "searchIntent.duplicateSearchSuppressed", properties: ["key": key])
                return
            }
            inFlightSearchKey = key
            do { if inFlightSearchKey == key { inFlightSearchKey = nil } }
        }
        
        switch intentKind {
            
        case .Place:
            if intent.selectedPlaceSearchResponse != nil {
                setProgressMessage(phase: "Fetching place details", caption: caption, locationName: destinationName)
                trackProgress(phase: "place.details.begin", caption: caption, locationName: destinationName)
                try await placeSearchService.detailIntent(intent: intent, cacheManager: cacheManager)
                if let detailsResponse = intent.selectedPlaceSearchDetails, let searchResponse = intent.selectedPlaceSearchDetails?.searchResponse {
                    intent.placeSearchResponses = [searchResponse]
                    intent.placeDetailsResponses = [detailsResponse]
                    intent.selectedPlaceSearchResponse = searchResponse
                    intent.selectedPlaceSearchDetails = detailsResponse
                }
                // Publish initial (possibly detailed) results immediately for fast UI transition

                try await placeQueryModel(intent: intent)
                
                trackProgress(phase: "place.details.end", caption: caption, locationName: destinationName)
                updateFoundResultsMessage()
                
                analyticsManager.track(event: "searchIntentWithSelectedPlace", properties: nil)
            } else {
                setProgressMessage(phase: "Fetching places", caption: caption, locationName: destinationName)
                trackProgress(phase: "place.fetch.begin", caption: caption, locationName: destinationName)
                let request = await placeSearchService.placeSearchRequest(intent: intent)
                let rawQueryResponse = try await placeSearchService.placeSearchSession.query(request:request)
                let placeSearchResponses = try PlaceResponseFormatter.placeSearchResponses(with: rawQueryResponse)
                intent.placeSearchResponses = placeSearchResponses
                setProgressMessage(phase: "Prefetching details", caption: caption, locationName: destinationName)
                trackProgress(phase: "place.prefetchDetails.begin", caption: caption, locationName: destinationName)
                // Prefetch only the first few details initially
                try await prefetchInitialDetailsIfNeeded(intent: intent, initialCount: 8)
                trackProgress(phase: "place.prefetchDetails.end", caption: caption, locationName: destinationName)
                _ = try await placeQueryModel(intent: intent)
                setProgressMessage(phase: "Building results", caption: caption, locationName: destinationName)
                trackProgress(phase: "place.buildResults.end", caption: caption, locationName: destinationName)
                updateFoundResultsMessage()
                analyticsManager.track(event: "searchIntentWithPlace", properties: nil)
            }
        case .Location:
            // Use PlaceSearchSession to search for locations and update NavigationLocationView via locationResults
            setProgressMessage(phase: "Searching locations", caption: caption, locationName: destinationName)
            trackProgress(phase: "location.autocomplete.begin", caption: caption, locationName: destinationName)
             do {
                 let locs = try await placeSearchService.placeSearchSession.autocompleteLocationResults(
                     caption: intent.caption,
                     parameters: intent.queryParameters,
                     locationResult: intent.selectedDestinationLocation
                 )
                 updateAllResults(locations: locs, appendLocations: true)
                 trackProgress(phase: "location.autocomplete.end", caption: caption, locationName: destinationName)
                 analyticsManager.track(event: "searchIntentLocationAutocompleteBuilt", properties: ["count": locs.count])
             } catch {
                 analyticsManager.trackError(error: error, additionalInfo: ["phase": "searchIntent.location.autocomplete"])
                 throw error
             }
        case .Search:
            try await performSearch(for: intent)
        case .AutocompleteTastes:
            do {
                // Use the service to fetch and format tastes using tasteCategoryResults
                let formattedTastes = try await placeSearchService.autocompleteTastes(
                    lastIntent: intent,
                    currentTasteResults: self.tasteResults,
                    cacheManager: cacheManager
                )
                
                updateAllResults(taste: formattedTastes)
                
                setProgressMessage(phase: "Showing autocomplete tastes", caption: caption, locationName: destinationName)
                trackProgress(phase: "autocomplete.tastes.end", caption: caption, locationName: destinationName)
                analyticsManager.track(event: "searchIntentWithPersonalizedAutocompleteTastes", properties: ["count": formattedTastes.count])
            } catch {
                analyticsManager.trackError(error: error, additionalInfo: ["phase": "searchIntent.autocompleteTastes"]) 
                throw error
            }
        }
    }
}

