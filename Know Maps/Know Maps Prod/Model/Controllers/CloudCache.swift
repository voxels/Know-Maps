
//
//  CloudCache.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/28/23.
//

import Foundation
import CloudKit
import Segment

public enum CloudCacheError: Error {
    case ThrottleRequests
    case ServerErrorMessage
    case ServiceNotFound
}

open class CloudCache: NSObject, ObservableObject {
    public var analytics:Analytics?
    var hasFsqAccess: Bool {
        fsqUserId.isEmpty ? false : true
    }
    @Published var isFetchingCachedRecords: Bool = false
    @Published public var queuedGroups = Set<String>()
    let cacheContainer = CKContainer(identifier: "iCloud.com.secretatomics.knowmaps.Cache")
    let keysContainer = CKContainer(identifier: "iCloud.com.secretatomics.knowmaps.Keys")
    private var fsqid: String = ""
    private var desc: String = ""
    private var fsqUserId: String = ""
    @MainActor private var oauthToken: String = ""
    private var serviceAPIKey: String = ""

    public enum CloudCacheService: String {
        case revenuecat
    }

    public func clearCache() {
        // Implement cache clearing logic here
    }

    public func fetch(url: URL, from cloudService: CloudCacheService) async throws -> Any {
        let configuredSession = try await session(service: cloudService.rawValue)
        return try await fetch(url: url, apiKey: serviceAPIKey, session: configuredSession)
    }

    internal func fetch(url: URL, apiKey: String, session: URLSession) async throws -> Any {
        print("Requesting URL: \(url)")
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")

        return try await withCheckedThrowingContinuation { continuation in
            let dataTask = session.dataTask(with: request) { data, response, error in
                if let e = error {
                    print(e)
                    continuation.resume(throwing: e)
                } else if let d = data {
                    do {
                        let json = try JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed])
                        continuation.resume(returning: json)
                    } catch {
                        print(error)
                        let returnedString = String(data: d, encoding: .utf8) ?? ""
                        print(returnedString)
                        continuation.resume(throwing: CloudCacheError.ServerErrorMessage)
                    }
                }
            }
            dataTask.resume()
        }
    }

    internal func session(service: String) async throws -> URLSession {
        let predicate = NSPredicate(format: "service == %@", service)
        let query = CKQuery(recordType: "KeyString", predicate: predicate)
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["value", "service"]
        operation.resultsLimit = 1
        operation.recordMatchedBlock = { [weak self] _, result in
            guard let self = self else { return }

            do {
                let record = try result.get()
                if let apiKey = record["value"] as? String {
                    print("\(String(describing: record["service"]))")
                    self.serviceAPIKey = apiKey
                } else {
                    print("Did not find API Key")
                }
            } catch {
                print(error)
            }
        }
        operation.queuePriority = .veryHigh
        operation.qualityOfService = .userInitiated

        let success = try await withCheckedThrowingContinuation { continuation in
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: true)
                case .failure(let error):
                    print(error)
                    continuation.resume(returning: false)
                }
            }
            keysContainer.publicCloudDatabase.add(operation)
        }

        if success {
            return defaultSession()
        } else {
            throw CloudCacheError.ServiceNotFound
        }
    }

    public func apiKey(for service: CloudCacheService) async throws -> String {
        let predicate = NSPredicate(format: "service == %@", service.rawValue)
        let query = CKQuery(recordType: "KeyString", predicate: predicate)
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["value", "service"]
        operation.resultsLimit = 1
        operation.recordMatchedBlock = { [weak self] _, result in
            guard let self = self else { return }

            do {
                let record = try result.get()
                if let apiKey = record["value"] as? String {
                    print("\(String(describing: record["service"]))")
                    self.serviceAPIKey = apiKey
                } else {
                    print("Did not find API Key")
                }
            } catch {
                print(error)
            }
        }
        operation.queuePriority = .veryHigh
        operation.qualityOfService = .userInitiated

        let success = try await withCheckedThrowingContinuation { continuation in
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: true)
                case .failure(let error):
                    print(error)
                    continuation.resume(returning: false)
                }
            }
            keysContainer.publicCloudDatabase.add(operation)
        }

        if success {
            return serviceAPIKey
        } else {
            throw CloudCacheError.ServiceNotFound
        }
    }

    public func fetchCloudKitUserRecordID() async throws -> CKRecord.ID? {
        return try await withCheckedThrowingContinuation { continuation in
            cacheContainer.fetchUserRecordID { recordId, error in
                if let e = error {
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
        operation.recordMatchedBlock = { _, result in
            do {
                let record = try result.get()
                if let userId = record["userId"] as? String {
                    self.fsqUserId = userId
                } else {
                    self.fsqUserId = ""
                    print("Did not find userId")
                }
            } catch {
                print(error)
                self.analytics?.track(name: "error \(error)")
            }
        }

        let success = try await withCheckedThrowingContinuation { continuation in
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: true)
                case .failure(let error):
                    print(error)
                    continuation.resume(returning: false)
                }
            }
            cacheContainer.privateCloudDatabase.add(operation)
        }

        if success {
            return fsqUserId
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
        operation.recordMatchedBlock = { _, result in
            do {
                let record = try result.get()
                if let token = record["token"] as? String {
                    Task { @MainActor in
                        self.fsqUserId = fsqUserId
                        self.oauthToken = token
                    }
                } else {
                    Task { @MainActor in
                        self.oauthToken = ""
                    }
                    print("Did not find token")
                }
            } catch {
                print(error)
                self.analytics?.track(name: "error \(error)")
            }
        }

        let success = try await withCheckedThrowingContinuation { continuation in
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: true)
                case .failure(let error):
                    print(error)
                    continuation.resume(returning: false)
                }
            }
            cacheContainer.privateCloudDatabase.add(operation)
        }

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
        await MainActor.run {
            isFetchingCachedRecords = true
        }
        var retval = [UserCachedRecord]()
        let predicate = NSPredicate(format: "Group == %@", group)
        let query = CKQuery(recordType: "UserCachedRecord", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["Group", "Icons", "Identity", "Title", "List", "Section"]
        operation.qualityOfService = .default
        operation.recordMatchedBlock = { recordId, result in
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

                let cachedRecord = UserCachedRecord(
                    recordId: recordId.recordName,
                    group: rawGroup,
                    identity: rawIdentity,
                    title: rawTitle,
                    icons: rawIcons,
                    list: rawList,
                    section: PersonalizedSearchSection(rawValue: rawSection)?.rawValue ?? PersonalizedSearchSection.none.rawValue
                )
                retval.append(cachedRecord)
            } catch {
                print(error)
                self.analytics?.track(name: "error \(error)")
            }
        }

        let _ = try await withCheckedThrowingContinuation { continuation in
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: true)
                case .failure(let error):
                    print(error)
                    continuation.resume(returning: false)
                }
            }
            cacheContainer.privateCloudDatabase.add(operation)
        }

        await MainActor.run {
            isFetchingCachedRecords = false
        }

        return retval
    }

    @discardableResult
    public func storeUserCachedRecord(
        for group: String,
        identity: String,
        title: String,
        icons: String? = nil,
        list: String,
        section: String
    ) async throws -> String {
        let record = CKRecord(recordType: "UserCachedRecord")
        record.setObject(group as NSString, forKey: "Group")
        record.setObject(identity as NSString, forKey: "Identity")
        record.setObject(title as NSString, forKey: "Title")
        record.setObject(list as NSString, forKey: "List")
        record.setObject(section as NSString, forKey: "Section")
        record.setObject((icons ?? "") as NSString, forKey: "Icons")

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
            deleting: recordsToDelete,
            atomically: true
        )
    }

    public func deleteAllUserCachedGroups() async throws {
        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            let types = ["Location", "Category", "Taste", "Place", "List"]
            for type in types {
                taskGroup.addTask {
                    try await self.deleteAllUserCachedRecords(for: type)
                }
            }
            try await taskGroup.waitForAll()
        }
    }
}

private extension CloudCache {
    func defaultSession() -> URLSession {
        let sessionConfiguration = URLSessionConfiguration.default
        return URLSession(configuration: sessionConfiguration)
    }
}
