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
    
    let analyticsManager: AnalyticsService
    
    @MainActor public var hasFsqAccess: Bool {
        return !fsqUserId.isEmpty
    }
    
    private var fsqid: String = ""
    private var fsqUserId: String = ""
    private var oauthToken: String = ""
    private var serviceAPIKey: String = ""
    
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
        let serviceAPIKey = serviceAPIKey
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
                        strongSelf.serviceAPIKey = apiKey
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
                        strongSelf.serviceAPIKey = apiKey
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
                serviceAPIKey
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
                        strongSelf.fsqUserId = userId
                    }
                } else {
                    Task { @MainActor in
                        strongSelf.fsqUserId = ""
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
            return await MainActor.run { fsqUserId }
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
                        strongSelf.fsqUserId = fsqUserId
                        strongSelf.oauthToken = token
                    }
                } else {
                    Task { @MainActor in
                        strongSelf.oauthToken = ""
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
            return await MainActor.run { oauthToken }
        } else {
            return ""
        }
    }
    
    public func storeFoursquareIdentityAndToken(for fsqUserId: String, oauthToken: String) {
        let record = CKRecord(recordType: "PersonalizedUser")
        record.setObject(fsqUserId as NSString, forKey: "userId")
        record.setObject(oauthToken as NSString, forKey: "token")
        cacheContainer.privateCloudDatabase.save(record) { [weak self] _, _ in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                strongSelf.fsqUserId = fsqUserId
                strongSelf.oauthToken = oauthToken
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

        // ... [Existing code] ...

        /// Fetches all records from the specified record types in the private CloudKit database.
        /// - Parameter recordTypes: An array of record type names to fetch.
        /// - Throws: `CloudCacheError` if any errors occur during fetching.
        @MainActor
        public func fetchAllRecords(recordTypes: [String]) async throws {
            for recordType in recordTypes {
                try await fetchRecords(ofType: recordType)
            }
        }

        /// Fetches all records for a specific record type.
        /// - Parameter recordType: The CloudKit record type to fetch.
        /// - Throws: `CloudCacheError` if any errors occur during fetching.
        private func fetchRecords(ofType recordType: String) async throws {
            let predicate = NSPredicate(value: true) // Fetch all records
            let query = CKQuery(recordType: recordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

            var continuation: CKQueryOperation.Cursor? = nil

            repeat {
                let operation = CKQueryOperation(query: query)
                operation.cursor = continuation
                operation.resultsLimit = 100 // Adjust as needed

                // Temporary storage for this batch
                var batchRecords: [CKRecord] = []

                // Handle each fetched record
                operation.recordMatchedBlock = { recordID, result in
                    do {
                        let record = try result.get()
                        batchRecords.append(record)
                    } catch {
                        self.analyticsManager.trackError(error: error, additionalInfo: nil)
                    }
                }
                // Handle completion of the query operation
                let operationCompletion: (Result<CKQueryOperation.Cursor?, Error>) -> Void = { result in
                    switch result {
                    case .success(let cursor):
                        continuation = cursor
                    case .failure(let error):
                        self.analyticsManager.trackError(error: error, additionalInfo: ["operation": "fetchRecords", "recordType": recordType])
                        // You can choose to throw or handle specific errors here
                    }
                }

                // Execute the operation
                try await withCheckedThrowingContinuation { continuationFetch in
                    operation.queryResultBlock = { result in
                        switch result {
                        case .success(let cursor):
                            continuation = cursor
                            continuationFetch.resume()
                        case .failure(let error):
                            continuationFetch.resume(throwing: error)
                        }
                    }

                    // Add operation to tracking
                    self.insertCacheOperation(operation)
                    self.cacheContainer.privateCloudDatabase.add(operation)
                }

                // Remove operation from tracking
                self.removeCacheOperation(operation)

                // Process the fetched batch
                if !batchRecords.isEmpty {
                    await processFetchedRecords(batchRecords, for: recordType)
                }

            } while continuation != nil
        }

        /// Processes fetched records by updating the local cache.
        /// - Parameters:
        ///   - records: The array of fetched `CKRecord` objects.
        ///   - recordType: The type of the records fetched.
        @MainActor
        private func processFetchedRecords(_ records: [CKRecord], for recordType: String) async {
            switch recordType {
            case "UserCachedRecord":
                for record in records {
                    if let recordId = record["recordId"] as? String,
                       let group = record["group"] as? String,
                       let identity = record["identity"] as? String,
                       let title = record["title"] as? String,
                       let icons = record["icons"] as? String,
                       let list = record["list"] as? String,
                       let section = record["section"] as? String,
                       let rating = record["rating"] as? Double {
                        
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
                    }
                }
                await saveContext()

            case "RecommendationData":
                for record in records {
                    if let recordId = record["recordId"] as? String,
                       let identity = record["identity"] as? String,
                       let attributes = record["attributes"] as? [String],
                       let reviews = record["reviews"] as? [String] {
                        
                        let recommendationData = RecommendationData(
                            recordId: recordId,
                            identity: identity,
                            attributes: attributes,
                            reviews: reviews,
                            attributeRatings: [:] // Adjust as needed
                        )
                        modelContext.insert(recommendationData)
                    }
                }
                await saveContext()

            case "PersonalizedUser":
                for record in records {
                    if let userId = record["userId"] as? String,
                       let token = record["token"] as? String {
                        fsqUserId = userId
                        oauthToken = token
                    }
                }

            case "KeyString":
                for record in records {
                    if let service = record["service"] as? String,
                       let value = record["value"] as? String {
                        // Handle KeyString records as needed
                        serviceAPIKey = value // Example assignment
                    }
                }

            default:
                print("Unhandled record type: \(recordType)")
            }

            // Save the context after processing each batch
            await saveContext()
        }

        /// Saves the `ModelContext` and handles any errors.
        @MainActor
        private func saveContext() async {
            do {
                try modelContext.save()
            } catch {
                analyticsManager.trackError(error: error, additionalInfo: ["operation": "saveContext"])
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
