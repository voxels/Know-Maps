//
//  CloudCache.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/28/23.
//

import Foundation
import CloudKit
import Segment

public enum CloudCacheError : Error {
    case ThrottleRequests
    case ServerErrorMessage
    case ServiceNotFound
}

open class CloudCache : NSObject, ObservableObject {
    public var analytics:Analytics?
    @Published var hasPrivateCloudAccess:Bool = false
    @Published var isFetchingCachedRecords:Bool = false
    @Published public var queuedGroups = Set<String>()
    let cacheContainer = CKContainer(identifier:"iCloud.com.secretatomics.knowmaps.Cache")
    let keysContainer = CKContainer(identifier:"iCloud.com.secretatomics.knowmaps.Keys")
    private var fsqid:String = ""
    private var desc:String = ""
    private var fsqUserId:String = ""
    private var oauthToken:String = ""
    private var serviceAPIKey:String = ""
    
    public enum CloudCacheService : String {
        case revenuecat
    }
    
    public func clearCache() {
        
        
    }
    
    
    
    public func fetch(url:URL, from cloudService:CloudCacheService) async throws -> Any {
        let configuredSession = try await session(service: cloudService.rawValue)
        return try await fetch(url: url, apiKey: serviceAPIKey, session: configuredSession)
    }

    internal func fetch(url:URL, apiKey:String, session:URLSession) async throws -> Any {
        print("Requesting URL: \(url)")
        var request = URLRequest(url:url)
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        let responseAny:Any = try await withCheckedThrowingContinuation({checkedContinuation in
            let dataTask = session.dataTask(with: request, completionHandler: { data, response, error in
                if let e = error {
                    print(e)
                    checkedContinuation.resume(throwing:e)
                } else {
                    if let d = data {
                        do {
                            let json = try JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed])
                            checkedContinuation.resume(returning:json)
                        } catch {
                            print(error)
                            let returnedString = String(data: d, encoding: String.Encoding.utf8) ?? ""
                            print(returnedString)
                            checkedContinuation.resume(throwing: CloudCacheError.ServerErrorMessage)
                        }
                    }
                }
            })
            
            dataTask.resume()
        })
        
        return responseAny
    }
    
    
    internal func session(service:String) async throws -> URLSession {
            let predicate = NSPredicate(format: "service == %@", service)
            let query = CKQuery(recordType: "KeyString", predicate: predicate)
            let operation = CKQueryOperation(query: query)
            operation.desiredKeys = ["value", "service"]
            operation.resultsLimit = 1
            operation.recordMatchedBlock = { [weak self] recordId, result in
                guard let strongSelf = self else { return }

                do {
                    let record = try result.get()
                    if let apiKey = record["value"] as? String {
                        print("\(String(describing: record["service"]))")
                        strongSelf.serviceAPIKey = apiKey
                    } else {
                        print("Did not find API Key")
                    }
                } catch {
                    print(error)
                }
            }
            
            operation.queuePriority = .veryHigh
            operation.qualityOfService = .userInitiated
        
        
        let success = try await withCheckedThrowingContinuation { checkedContinuation in
            operation.queryResultBlock = { result in
                
                switch result {
                case .success(_):
                    checkedContinuation.resume(with: .success(true))
                case .failure(let error):
                    print(error)
                    checkedContinuation.resume(with: .success(false))
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
    
    
    public func apiKey(for service:CloudCacheService) async throws -> String {
        let predicate = NSPredicate(format: "service == %@", service.rawValue)
            let query = CKQuery(recordType: "KeyString", predicate: predicate)
            let operation = CKQueryOperation(query: query)
            operation.desiredKeys = ["value", "service"]
            operation.resultsLimit = 1
            operation.recordMatchedBlock = { [weak self] recordId, result in
                guard let strongSelf = self else { return }

                do {
                    let record = try result.get()
                    if let apiKey = record["value"] as? String {
                        print("\(String(describing: record["service"]))")
                        strongSelf.serviceAPIKey = apiKey
                    } else {
                        print("Did not find API Key")
                    }
                } catch {
                    print(error)
                }
            }
            
            operation.queuePriority = .veryHigh
            operation.qualityOfService = .userInitiated
        
        
        let success = try await withCheckedThrowingContinuation { checkedContinuation in
            operation.queryResultBlock = { result in
                
                switch result {
                case .success(_):
                    checkedContinuation.resume(with: .success(true))
                case .failure(let error):
                    print(error)
                    checkedContinuation.resume(with: .success(false))
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
    
    
    public func fetchCloudKitUserRecordID() async throws -> CKRecord.ID?{
        
        let userRecord:CKRecord.ID? = try await withCheckedThrowingContinuation { checkedContinuation in
            cacheContainer.fetchUserRecordID { recordId, error in
                if let e = error {
                    checkedContinuation.resume(throwing: e)
                } else if let record = recordId {
                    checkedContinuation.resume(returning: record)
                } else {
                    checkedContinuation.resume(returning: nil)
                }
            }
        }
        return userRecord
    }
    
    public func fetchGeneratedDescription(for fsqid:String) async throws -> String {
        desc = ""
        let predicate = NSPredicate(format: "fsqid == %@", fsqid)
        let query = CKQuery(recordType: "GeneratedDescription", predicate: predicate)
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["description"]
        operation.resultsLimit = 1
        operation.qualityOfService = .userInteractive
        operation.recordMatchedBlock = { recordId, result in
            Task { @MainActor in
                
                do {
                    let record = try result.get()
                    if let description = record["description"] as? String {
                        print("Found Generated Description \(description)")
                        self.fsqid = fsqid
                        self.desc = description
                    } else {
                        self.desc = ""
                        print("Did not find description")
                    }
                } catch {
                    print(error)
                    self.analytics?.track(name: "error \(error)")
                }
                
            }
        }
        
        let success = try await withCheckedThrowingContinuation { checkedContinuation in
            operation.queryResultBlock = { result in
                
                switch result {
                case .success(_):
                    checkedContinuation.resume(with: .success(true))
                case .failure(let error):
                    print(error)
                    checkedContinuation.resume(with: .success(false))
                }
            }
            
            cacheContainer.privateCloudDatabase.add(operation)
        }
        
        if success {
            return desc
        } else {
            return ""
        }
    }
    
    public func storeGeneratedDescription(for fsqid:String, description:String) {
        let record = CKRecord(recordType:"GeneratedDescription")
        record.setObject(fsqid as NSString, forKey: "fsqid")
        record.setObject(description as NSString, forKey: "description")
        cacheContainer.privateCloudDatabase.save(record) { [weak self] record, error in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                strongSelf.fsqid = fsqid
                strongSelf.desc = description
            }
        }
    }
    
    public func fetchFsqIdentity() async throws -> String {
        let predicate = NSPredicate(format: "TRUEPREDICATE")
        let query = CKQuery(recordType: "PersonalizedUser", predicate:predicate)
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["userId"]
        operation.resultsLimit = 1
        operation.qualityOfService = .userInitiated
        operation.recordMatchedBlock = { recordId, result in
                do {
                    let record = try result.get()
                    if let userId = record["userId"] as? String {
                        self.fsqUserId = userId
                    } else {
                        self.fsqUserId = ""
                        print("Did not find description")
                    }
                } catch {
                    print(error)
                    self.analytics?.track(name: "error \(error)")
                }
        }
        
        let success = try await withCheckedThrowingContinuation { checkedContinuation in
            operation.queryResultBlock = { result in
                
                switch result {
                case .success(_):
                    checkedContinuation.resume(with: .success(true))
                case .failure(let error):
                    print(error)
                    checkedContinuation.resume(with: .success(false))
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
    
    
    public func fetchToken(for fsqUserId:String) async throws -> String {
        
        let predicate = NSPredicate(format: "userId == %@", fsqUserId)
        let query = CKQuery(recordType: "PersonalizedUser", predicate: predicate)
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["token"]
        operation.resultsLimit = 1
        operation.qualityOfService = .userInteractive
        operation.recordMatchedBlock = { recordId, result in
                
                do {
                    let record = try result.get()
                    if let token = record["token"] as? String {
                        self.fsqUserId = fsqUserId
                        self.oauthToken = token
                    } else {
                        self.oauthToken = ""
                        print("Did not find description")
                    }
                } catch {
                    print(error)
                    self.analytics?.track(name: "error \(error)")
                }

        }
        
        let success = try await withCheckedThrowingContinuation { checkedContinuation in
            operation.queryResultBlock = { result in
                
                switch result {
                case .success(_):
                    checkedContinuation.resume(with: .success(true))
                case .failure(let error):
                    print(error)
                    checkedContinuation.resume(with: .success(false))
                }
            }
            
            cacheContainer.privateCloudDatabase.add(operation)
        }
        
        if success {
            return oauthToken
        } else {
            return ""
        }
    }
    
    public func storeFoursquareIdentityAndToken(for fsqUserId:String, oauthToken:String) {
        let record = CKRecord(recordType:"PersonalizedUser")
        record.setObject(fsqUserId as NSString, forKey: "userId")
        record.setObject(oauthToken as NSString, forKey: "token")
        cacheContainer.privateCloudDatabase.save(record) { [weak self] record, error in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                strongSelf.fsqUserId = fsqUserId
                strongSelf.oauthToken = oauthToken
            }
        }
        
        self.fsqUserId = fsqUserId
        self.oauthToken = oauthToken
    }

    
    public func fetchGroupedUserCachedRecords(for group:String) async throws -> [UserCachedRecord] {
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
                var rawGroup = ""
                var rawIdentity = ""
                var rawTitle = ""
                var rawIcons = ""
                var rawList = ""
                var rawSection = ""
                
                if let group = record["Group"] as? String {
                    rawGroup = group
                }
                if let identity = record["Identity"] as? String {
                    rawIdentity = identity
                }
                if let title = record["Title"] as? String {
                    rawTitle = title
                }
                if let icons = record["Icons"] as? String {
                    rawIcons = icons
                }
                
                if let list = record["List"] as? String {
                    rawList = list
                }
                
                if let section = record["Section"] as? String {
                    rawSection = section
                }
                
                if !rawGroup.isEmpty && !rawIdentity.isEmpty && !rawTitle.isEmpty {
                    let cachedRecord = UserCachedRecord(recordId: recordId.recordName, group: rawGroup, identity: rawIdentity, title: rawTitle, icons: rawIcons, list: rawList, section:PersonalizedSearchSection(rawValue: rawSection)?.rawValue ?? PersonalizedSearchSection.none.rawValue)
                    retval.append(cachedRecord)
                }
                
            } catch {
                print(error)
                self.analytics?.track(name: "error \(error)")
            }
        }
        
        let _ = try await withCheckedThrowingContinuation { checkedContinuation in
            operation.queryResultBlock = { result in
                
                switch result {
                case .success(_):
                    checkedContinuation.resume(with: .success(true))
                case .failure(let error):
                    print(error)
                    checkedContinuation.resume(with: .success(false))
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
    public func storeUserCachedRecord(for group:String, identity:String, title:String, icons:String? = nil, list:String, section:String) async throws -> String {
        
        let record = CKRecord(recordType:"UserCachedRecord")
        record.setObject(group as NSString, forKey: "Group")
        record.setObject(identity as NSString, forKey: "Identity")
        record.setObject(title as NSString, forKey: "Title")
        record.setObject(list as NSString, forKey:"List")
        record.setObject(section as NSString, forKey:"Section")
        
        if let icons = icons {
            record.setObject(icons as NSString, forKey: "Icons")
        } else {
            record.setObject("" as NSString, forKey: "Icons")
        }
        let result = try await cacheContainer.privateCloudDatabase.modifyRecords(saving: [record], deleting:[], atomically: false)
        if let resultName = result.saveResults.keys.first?.recordName {
            return resultName
        }

        return record.recordID.recordName
    }
    
    public func deleteUserCachedRecord(for cachedRecord:UserCachedRecord) async throws {
        if cachedRecord.recordId.isEmpty {
            return
        }
        try await cacheContainer.privateCloudDatabase.deleteRecord(withID: CKRecord.ID(recordName: cachedRecord.recordId))
    }
    
    @discardableResult
    public func deleteAllUserCachedRecords(for group:String) async throws -> (saveResults: [CKRecord.ID : Result<CKRecord, Error>], deleteResults: [CKRecord.ID : Result<Void, Error>]) {
        let existingGroups = try await fetchGroupedUserCachedRecords(for: group)
        var existingRecordsToDelete = [CKRecord.ID]()
        for group in existingGroups {
            existingRecordsToDelete.append(CKRecord.ID(recordName: group.recordId))
        }
        return try await cacheContainer.privateCloudDatabase.modifyRecords(saving:[], deleting: existingRecordsToDelete, atomically: true)
    }
    
    
    public func deleteAllUserCachedGroups() async throws {
        try await deleteAllUserCachedRecords(for: "Location")
        try await deleteAllUserCachedRecords(for: "Category")
        try await deleteAllUserCachedRecords(for: "Taste")
        try await deleteAllUserCachedRecords(for: "Place")
        try await deleteAllUserCachedRecords(for: "List")
    }
    
}


private extension CloudCache {
    func defaultSession()->URLSession {
        let sessionConfiguration = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfiguration)
        return session
    }
}
