//
//  CloudCache.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/28/23.
//

import Foundation
import CloudKit
import SwiftData
import Segment
#if os(macOS)
import AppKit
#else
import UIKit
#endif

public enum CloudCacheError: Error {
    case ThrottleRequests
    case ServerErrorMessage
    case ServiceNotFound
}

public enum CloudCacheServiceKey: String {
    case revenuecat
}

public final class CloudCacheService: NSObject, CloudCache {
    @MainActor
    static let shared = CloudCacheService(analyticsManager: SegmentAnalyticsService.shared, modelContext: Know_MapsApp.sharedModelContainer.mainContext)
    
    var analyticsManager: AnalyticsService
    var foursquareAuthenticationRecord: FoursquareAuthenticationRecord!
    
    @MainActor public var hasFsqAccess: Bool {
        return !foursquareAuthenticationRecord.fsqUserId.isEmpty
    }
    let cacheContainer = CKContainer(identifier: "iCloud.com.secretatomics.knowmaps.Cache")
    let keysContainer = CKContainer(identifier: "iCloud.com.secretatomics.knowmaps.Keys")
    private let modelContext: ModelContext
    
    private var cacheOperations = Set<CKDatabaseOperation>()
    private var keysOperations = Set<CKDatabaseOperation>()
    
    // Thread-safe queues for synchronizing access
    private let operationQueue = DispatchQueue(label: "com.secretatomics.knowmaps.operationQueue", attributes: .concurrent)
    
#if !os(macOS)
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
#endif
    
    public init(analyticsManager: AnalyticsService, modelContext: ModelContext) {
        self.analyticsManager = analyticsManager
        self.modelContext = modelContext
        self.foursquareAuthenticationRecord = FoursquareAuthenticationRecord(fsqid: "", fsqUserId: "", oauthToken: "", serviceAPIKey: "")
        
        super.init()
#if os(macOS)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: NSApplication.didResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: NSApplication.didBecomeActiveNotification, object: nil)
#else
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
#endif
    }
    
    @objc func appDidEnterBackground() {
        // Register background task
#if !os(macOS)
        backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            // Cancel operations if background time expires
            self.cancelAllOperations()
            UIApplication.shared.endBackgroundTask(self.backgroundTask)
            self.backgroundTask = .invalid
        })
#endif
        
        // Do not immediately cancel operations; allow them to finish in the background
        DispatchQueue.global().async {
            self.waitForOperationsToFinish()
        }
    }
    
    @objc func appWillEnterForeground() {
        // End background task if necessary
#if !os(macOS)
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
#endif
        // Resume or restart any necessary operations
    }
    
    private func waitForOperationsToFinish() {
        // Wait for ongoing operations to finish before canceling
        cacheOperations.forEach { operation in
            if operation.isExecuting {
                operation.queuePriority = .veryLow
            }
        }
        keysOperations.forEach { operation in
            if operation.isExecuting {
                operation.queuePriority = .veryLow
            }
        }
        
        // Optionally wait for a specific amount of time before cancelling if necessary
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
            self.cancelAllOperations()
        }
    }
    
    private func cancelAllOperations() {
        // Safely cancel all operations
        cacheOperations.forEach { $0.cancel() }
        keysOperations.forEach { $0.cancel() }
    }
    
    private func insertCacheOperation(_ operation: CKDatabaseOperation) {
        operationQueue.async(flags: .barrier) {
            self.cacheOperations.insert(operation)
        }
    }
    
    private func insertKeysOperation(_ operation: CKDatabaseOperation) {
        operationQueue.async(flags: .barrier) {
            self.keysOperations.insert(operation)
        }
    }
    
    private func removeCacheOperation(_ operation: CKDatabaseOperation) {
        operationQueue.async(flags: .barrier) {
            self.cacheOperations.remove(operation)
        }
    }
    
    private func removeKeysOperation(_ operation: CKDatabaseOperation) {
        operationQueue.async(flags: .barrier) {
            self.keysOperations.remove(operation)
        }
    }
    
    public func clearCache() {
        // Implement cache clearing logic here
    }
    
    public func fetch(url: URL, from cloudService: CloudCacheServiceKey) async throws -> Any {
        let configuredSession = try await session(service: cloudService.rawValue)
        let serviceAPIKey = foursquareAuthenticationRecord.serviceAPIKey
        return try await fetch(url: url, apiKey: serviceAPIKey, session: configuredSession)
    }
    
    internal func fetch(url: URL, apiKey: String, session: URLSession) async throws -> Any {
        print("Requesting URL: \(url)")
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        
        return try await withCheckedThrowingContinuation { continuation in
            let dataTask = session.dataTask(with: request) { [weak self] data, response, error in
                
                guard let strongSelf = self else { return }
                if let e = error {
                    print(e)
                    continuation.resume(throwing: e)
                } else if let d = data {
                    do {
                        let json = try JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed])
                        continuation.resume(returning: json)
                    } catch {
                        let returnedString = String(data: d, encoding: .utf8) ?? ""
                        print(returnedString)
                        strongSelf.analyticsManager.trackError(error: error, additionalInfo: nil)
                        continuation.resume(throwing: CloudCacheError.ServerErrorMessage)
                    }
                }
            }
            dataTask.resume()
        }
    }
    
    public func session(service: String) async throws -> URLSession {
        let predicate = NSPredicate(format: "service == %@", service)
        let query = CKQuery(recordType: "KeyString", predicate: predicate)
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["value", "service"]
        operation.resultsLimit = 1
        operation.recordMatchedBlock = { [weak self] _, result in
            guard let strongSelf = self else { return }
            
            do {
                let record = try result.get()
                if let apiKey = record["value"] as? String {
                    print("\(String(describing: record["service"]))")
                    Task { @MainActor in
                        strongSelf.foursquareAuthenticationRecord.serviceAPIKey = apiKey
                    }
                } else {
                    print("Did not find API Key")
                }
            } catch {
                strongSelf.analyticsManager.trackError(error: error, additionalInfo: nil)
            }
        }
        operation.queuePriority = .veryHigh
        operation.qualityOfService = .userInitiated
        
        let success = try await withCheckedThrowingContinuation { continuation in
            operation.queryResultBlock = { [weak self] result in
                guard let strongSelf = self else { return }
                switch result {
                case .success:
                    continuation.resume(returning: true)
                case .failure(let error):
                    strongSelf.analyticsManager.trackError(error: error, additionalInfo: nil)
                    continuation.resume(returning: false)
                }
            }
            self.insertKeysOperation(operation)
            keysContainer.publicCloudDatabase.add(operation)
        }
        
        self.removeKeysOperation(operation)
        
        if success {
            return defaultSession()
        } else {
            throw CloudCacheError.ServiceNotFound
        }
    }
    
    public func apiKey(for service: CloudCacheServiceKey) async throws -> String {
        let predicate = NSPredicate(format: "service == %@", service.rawValue)
        let query = CKQuery(recordType: "KeyString", predicate: predicate)
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["value", "service"]
        operation.resultsLimit = 1
        operation.recordMatchedBlock = { [weak self] _, result in
            guard let strongSelf = self else { return }
            
            do {
                let record = try result.get()
                if let apiKey = record["value"] as? String {
                    print("\(String(describing: record["service"]))")
                    Task { @MainActor in
                        strongSelf.foursquareAuthenticationRecord.serviceAPIKey = apiKey
                    }
                } else {
                    print("Did not find API Key")
                }
            } catch {
                strongSelf.analyticsManager.trackError(error: error, additionalInfo: nil)
            }
        }
        operation.queuePriority = .veryHigh
        operation.qualityOfService = .userInitiated
        
        let success = try await withCheckedThrowingContinuation { continuation in
            operation.queryResultBlock = { [weak self] result in
                guard let strongSelf = self else { return }
                switch result {
                case .success:
                    continuation.resume(returning: true)
                case .failure(let error):
                    strongSelf.analyticsManager.trackError(error: error, additionalInfo: nil)
                    continuation.resume(returning: false)
                }
            }
            self.insertKeysOperation(operation)
            keysContainer.publicCloudDatabase.add(operation)
        }
        
        self.removeKeysOperation(operation)
        
        if success {
            return await MainActor.run {
                foursquareAuthenticationRecord.serviceAPIKey
            }
        } else {
            throw CloudCacheError.ServiceNotFound
        }
    }
    
    public func fetchCloudKitUserRecordID() async throws -> CKRecord.ID? {
        return try await withCheckedThrowingContinuation { continuation in
            cacheContainer.fetchUserRecordID { [weak self] recordId, error in
                guard let strongSelf = self else { return }
                if let e = error {
                    strongSelf.analyticsManager.trackError(error: e, additionalInfo: nil)
                    continuation.resume(throwing: e)
                } else if let record = recordId {
                    continuation.resume(returning: record)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    public func fetchFsqIdentity() async throws -> String {
        let predicate = NSPredicate(format: "TRUEPREDICATE")
        let query = CKQuery(recordType: "PersonalizedUser", predicate: predicate)
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["userId"]
        operation.resultsLimit = 1
        operation.qualityOfService = .userInitiated
        operation.recordMatchedBlock = { [weak self] _, result in
            guard let strongSelf = self else { return }
            do {
                let record = try result.get()
                if let userId = record["userId"] as? String {
                    Task { @MainActor in
                        strongSelf.foursquareAuthenticationRecord.fsqUserId = userId
                    }
                } else {
                    Task { @MainActor in
                        strongSelf.foursquareAuthenticationRecord.fsqUserId = ""
                    }
                    print("Did not find userId")
                }
            } catch {
                strongSelf.analyticsManager.trackError(error: error, additionalInfo: ["operation": "fetchFsqIdentity"])
            }
        }
        
        let success = try await withCheckedThrowingContinuation { continuation in
            operation.queryResultBlock = { [weak self] result in
                guard let strongSelf = self else { return }
                switch result {
                case .success:
                    continuation.resume(returning: true)
                case .failure(let error):
                    strongSelf.analyticsManager.trackError(error: error, additionalInfo: nil)
                    continuation.resume(returning: false)
                }
            }
            self.insertCacheOperation(operation)
            cacheContainer.privateCloudDatabase.add(operation)
        }
        
        self.removeCacheOperation(operation)
        
        if success {
            return await MainActor.run { foursquareAuthenticationRecord.fsqUserId }
        } else {
            return ""
        }
    }
    
    public func fetchToken(for fsqUserId: String) async throws -> String {
        let predicate = NSPredicate(format: "userId == %@", fsqUserId)
        let query = CKQuery(recordType: "PersonalizedUser", predicate: predicate)
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["token"]
        operation.resultsLimit = 1
        operation.qualityOfService = .userInteractive
        operation.recordMatchedBlock = { [weak self] _, result in
            guard let strongSelf = self else { return }
            do {
                let record = try result.get()
                if let token = record["token"] as? String {
                    Task { @MainActor in
                        strongSelf.foursquareAuthenticationRecord.fsqUserId = fsqUserId
                        strongSelf.foursquareAuthenticationRecord.oauthToken = token
                    }
                } else {
                    Task { @MainActor in
                        strongSelf.foursquareAuthenticationRecord.oauthToken = ""
                    }
                    print("Did not find token")
                }
            } catch {
                strongSelf.analyticsManager.trackError(error: error, additionalInfo: nil)
            }
        }
        
        let success = try await withCheckedThrowingContinuation { continuation in
            operation.queryResultBlock = { [weak self] result in
                guard let strongSelf = self else { return }
                switch result {
                case .success:
                    continuation.resume(returning: true)
                case .failure(let error):
                    strongSelf.analyticsManager.trackError(error: error, additionalInfo: nil)
                    continuation.resume(returning: false)
                }
            }
            self.insertCacheOperation(operation)
            cacheContainer.privateCloudDatabase.add(operation)
        }
        
        self.removeCacheOperation(operation)
        if success {
            // Access oauthToken on the main actor
            return await MainActor.run { self.foursquareAuthenticationRecord.oauthToken }
        } else {
            return ""
        }
    }
    
    public func storeFoursquareIdentityAndToken(for fsqUserId: String, oauthToken: String) {
        let record = CKRecord(recordType: "PersonalizedUser")
        record.setObject(fsqUserId as NSString, forKey: "userId")
        record.setObject(oauthToken as NSString, forKey: "token")
        cacheContainer.privateCloudDatabase.save(record) { [weak self] _, _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.foursquareAuthenticationRecord.fsqUserId = fsqUserId
                self.foursquareAuthenticationRecord.oauthToken = oauthToken
            }
        }
    }
    public func fetchGroupedUserCachedRecords(for group: String) async throws -> [UserCachedRecord] {
            // Fetch from local store
            return try await MainActor.run {
                let fetchDescriptor = FetchDescriptor<UserCachedRecord>(
                    predicate: #Predicate { $0.group == group }
                )
                return try modelContext.fetch(fetchDescriptor)
            }
        }
        
        @discardableResult
        public func storeUserCachedRecord(
            recordId: String,
            group: String,
            identity: String,
            title: String,
            icons: String,
            list: String,
            section: String,
            rating: Double
        ) async throws -> Bool {
            await MainActor.run {
                let userCachedRecord = UserCachedRecord(
                    recordId: recordId,
                    group: group,
                    identity: identity,
                    title: title,
                    icons: icons,
                    list: list,
                    section: section,
                    rating: rating
                )
                modelContext.insert(userCachedRecord)
                do {
                    try modelContext.save()
                } catch {
                    analyticsManager.trackError(error: error, additionalInfo: nil)
                }
            }
            return true
        }
        
        public func updateUserCachedRecordRating(identity: String, newRating: Double) async throws {
            await MainActor.run {
                do {
                    let fetchDescriptor = FetchDescriptor<UserCachedRecord>(
                        predicate: #Predicate { $0.identity == identity }
                    )
                    if let localRecord = try modelContext.fetch(fetchDescriptor).first {
                        localRecord.rating = newRating
                        try modelContext.save()
                    } else {
                        print("Local record not found for identity: \(identity)")
                    }
                } catch {
                    analyticsManager.trackError(error: error, additionalInfo: nil)
                }
            }
        }
        
        public func deleteUserCachedRecord(for cachedRecord: UserCachedRecord) async throws {
            await MainActor.run {
                modelContext.delete(cachedRecord)
                do {
                    try modelContext.save()
                } catch {
                    analyticsManager.trackError(error: error, additionalInfo: nil)
                }
            }
        }
        
    
        public func deleteAllUserCachedRecords(for group: String) async throws {
            await MainActor.run {
                do {
                    let fetchDescriptor = FetchDescriptor<UserCachedRecord>(
                        predicate: #Predicate { $0.group == group }
                    )
                    let localRecords = try modelContext.fetch(fetchDescriptor)
                    localRecords.forEach { modelContext.delete($0) }
                    try modelContext.save()
                } catch {
                    analyticsManager.trackError(error: error, additionalInfo: nil)
                }
            }
        }
        
        // MARK: RecommendationData Methods
        
        public func fetchRecommendationData() async throws -> [RecommendationData] {
            // Fetch from local store
            return try await MainActor.run {
                let fetchDescriptor = FetchDescriptor<RecommendationData>()
                return try modelContext.fetch(fetchDescriptor)
            }
        }
        
        public func storeRecommendationData(
            for identity: String,
            attributes: [String],
            reviews: [String]
        ) async throws -> Bool {
            // Generate a local record ID
            let recordID = UUID().uuidString
            
            await MainActor.run {
                let recommendationData = RecommendationData(
                    recordId: recordID,
                    identity: identity,
                    attributes: attributes,
                    reviews: reviews,
                    attributeRatings: [:] // Initialize as needed
                )
                modelContext.insert(recommendationData)
                do {
                    try modelContext.save()
                } catch {
                    analyticsManager.trackError(error: error, additionalInfo: nil)
                }
            }
            return true
        }
        
    
        public func deleteRecommendationData(for identity: String) async throws {
            await MainActor.run {
                do {
                    let fetchDescriptor = FetchDescriptor<RecommendationData>(
                        predicate: #Predicate { $0.identity == identity }
                    )
                    if let localRecord = try modelContext.fetch(fetchDescriptor).first {
                        modelContext.delete(localRecord)
                        try modelContext.save()
                    }
                } catch {
                    analyticsManager.trackError(error: error, additionalInfo: nil)
                }
            }
        }
        
        // MARK: - Other Methods
        
        public func deleteAllUserCachedGroups() async throws {
            let types = ["Location", "Category", "Taste", "Place"]
            for type in types {
                try await deleteAllUserCachedRecords(for: type)
            }
        }
        
}

private extension CloudCacheService {
    func defaultSession() -> URLSession {
        let sessionConfiguration = URLSessionConfiguration.default
        return URLSession(configuration: sessionConfiguration)
    }
}
