
//
//  CloudCache.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/28/23.
//

import Foundation
import CloudKit
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
    var analyticsManager:AnalyticsService
    @MainActor public var hasFsqAccess: Bool {
        fsqUserId.isEmpty ? false : true
    }
    let cacheContainer = CKContainer(identifier: "iCloud.com.secretatomics.knowmaps.Cache")
    let keysContainer = CKContainer(identifier: "iCloud.com.secretatomics.knowmaps.Keys")
    @MainActor private var fsqid: String = ""
    @MainActor private var desc: String = ""
    @MainActor private var fsqUserId: String = ""
    @MainActor private var oauthToken: String = ""
    @MainActor private var serviceAPIKey: String = ""
    
    private var cacheOperations = Set<CKDatabaseOperation>()
    private var keysOperations = Set<CKDatabaseOperation>()
    
    // Thread-safe queues for synchronizing access
    private let operationQueue = DispatchQueue(label: "com.secretatomics.knowmaps.operationQueue", attributes: .concurrent)
    
#if !os(macOS)
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
#endif
    
    public init(analyticsManager:AnalyticsService) {
        self.analyticsManager = analyticsManager
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
                    Task{ @MainActor in
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
                strongSelf.analyticsManager.trackError(error:error, additionalInfo: nil)
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
            return await MainActor.run { self.oauthToken }
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
                self.fsqUserId = fsqUserId
                self.oauthToken = oauthToken
            }
        }
    }
    
    public func fetchGroupedUserCachedRecords(for group: String) async throws -> [UserCachedRecord] {
        var retval = [UserCachedRecord]()
        let predicate = NSPredicate(format: "Group == %@", group)
        let query = CKQuery(recordType: "UserCachedRecord", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["Group", "Icons", "Identity", "Title", "List", "Section", "Rating"]
        operation.qualityOfService = .default
        operation.recordMatchedBlock = { [weak self] recordId, result in
            guard let strongSelf = self else { return }
            do {
                let record = try result.get()
                guard
                    let rawGroup = record["Group"] as? String,
                    let rawIdentity = record["Identity"] as? String,
                    let rawTitle = record["Title"] as? String
                        
                else {
                    return
                }
                let rawIcons = record["Icons"] as? String ?? ""
                let rawList = record["List"] as? String ?? ""
                let rawSection = record["Section"] as? String ?? PersonalizedSearchSection.none.rawValue
                let rawRating = record["Rating"] as? Int ?? 1
                let cachedRecord = UserCachedRecord(
                    recordId: recordId.recordName,
                    group: rawGroup,
                    identity: rawIdentity,
                    title: rawTitle,
                    icons: rawIcons,
                    list: rawList,
                    section: PersonalizedSearchSection(rawValue: rawSection)?.rawValue ?? PersonalizedSearchSection.none.rawValue,
                    rating: rawRating
                )
                retval.append(cachedRecord)
            } catch {
                strongSelf.analyticsManager.trackError(error: error, additionalInfo: nil)
            }
        }
        
        let _ = try await withCheckedThrowingContinuation { continuation in
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
        
        return retval
    }
    
    @discardableResult
    public func storeUserCachedRecord(
        for group: String,
        identity: String,
        title: String,
        icons: String,
        list: String,
        section: String,
        rating:Double
    ) async throws -> String {
        let record = CKRecord(recordType: "UserCachedRecord")
        record.setObject(group as NSString, forKey: "Group")
        record.setObject(identity as NSString, forKey: "Identity")
        record.setObject(title as NSString, forKey: "Title")
        record.setObject(list as NSString, forKey: "List")
        record.setObject(section as NSString, forKey: "Section")
        record.setObject((icons) as NSString, forKey: "Icons")
        record.setObject(rating as NSNumber, forKey: "Rating")
        
        let result = try await cacheContainer.privateCloudDatabase.modifyRecords(
            saving: [record],
            deleting: [],
            atomically: false
        )
        if let resultName = result.saveResults.keys.first?.recordName {
            return resultName
        }
        
        return record.recordID.recordName
    }
    
    public func updateUserCachedRecordRating(recordId: String, newRating: Double) async throws {
        let recordID = CKRecord.ID(recordName: recordId)
        do {
            // Fetch the existing record
            let record = try await cacheContainer.privateCloudDatabase.record(for: recordID)
            // Update the rating field
            record["Rating"] = newRating as NSNumber
            // Save the updated record
            _ = try await cacheContainer.privateCloudDatabase.modifyRecords(
                saving: [record],
                deleting: []
            )
        } catch {
            // Log the error using your analytics manager
            analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }
    
    public func deleteUserCachedRecord(for cachedRecord: UserCachedRecord) async throws {
        guard !cachedRecord.recordId.isEmpty else { return }
        try await cacheContainer.privateCloudDatabase.deleteRecord(withID: CKRecord.ID(recordName: cachedRecord.recordId))
    }
    
    @discardableResult
    public func deleteAllUserCachedRecords(for group: String) async throws -> (
        saveResults: [CKRecord.ID: Result<CKRecord, Error>],
        deleteResults: [CKRecord.ID: Result<Void, Error>]
    ) {
        let existingGroups = try await fetchGroupedUserCachedRecords(for: group)
        let recordsToDelete = existingGroups.map { CKRecord.ID(recordName: $0.recordId) }
        return try await cacheContainer.privateCloudDatabase.modifyRecords(
            saving: [],
            deleting: recordsToDelete
        )
    }
    
    public func deleteAllUserCachedGroups() async throws {
        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            let types = ["Location", "Category", "Taste", "Place"]
            for type in types {
                taskGroup.addTask {
                    try await self.deleteAllUserCachedRecords(for: type)
                }
            }
            try await taskGroup.waitForAll()
        }
    }
}

private extension CloudCacheService {
    func defaultSession() -> URLSession {
        let sessionConfiguration = URLSessionConfiguration.default
        return URLSession(configuration: sessionConfiguration)
    }
}
