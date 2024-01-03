//
//  CloudCache.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/28/23.
//

import Foundation
import CloudKit

open class CloudCache : NSObject, ObservableObject {
    @Published var hasPrivateCloudAccess:Bool = false
    let cacheContainer = CKContainer(identifier:"iCloud.com.noisederived.No-Maps.Cache")
    private var fsqid:String = ""
    private var desc:String = ""
    private var fsqUserId:String = ""
    private var oauthToken:String = ""
    
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
        
        let predicate = NSPredicate(format: "fsqid == %@", fsqid)
        let query = CKQuery(recordType: "GeneratedDescription", predicate: predicate)
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["description"]
        operation.resultsLimit = 1
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
    
    
    public func fetchToken(for fsqUserId:String) async throws -> String {
        
        let predicate = NSPredicate(format: "userId == %@", fsqUserId)
        let query = CKQuery(recordType: "PersonalizedUser", predicate: predicate)
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["token"]
        operation.resultsLimit = 1
        operation.recordMatchedBlock = { recordId, result in
            Task { @MainActor in
                
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
            return oauthToken
        } else {
            return ""
        }
    }
    
    public func storeToken(for fsqUserId:String, oauthToken:String) {
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
    }

    public func fetchGroupedUserCachedRecords(for group:String) async throws -> [UserCachedRecord] {
        var retval = [UserCachedRecord]()
        let predicate = NSPredicate(format: "Group == %@", group)
        let query = CKQuery(recordType: "UserCachedRecord", predicate: predicate)
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["Group", "Icons", "Identity", "Title"]
        operation.recordMatchedBlock = { recordId, result in
            do {
                let record = try result.get()
                var rawGroup = ""
                var rawIdentity = ""
                var rawTitle = ""
                var rawIcons = ""
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
                
                if !rawGroup.isEmpty && !rawIdentity.isEmpty && !rawTitle.isEmpty {
                    let cachedRecord = UserCachedRecord(recordId: recordId.recordName, group: rawGroup, identity: rawIdentity, title: rawTitle, icons: rawIcons)
                    retval.append(cachedRecord)
                }
                
            } catch {
                print(error)
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
        
        return retval
    }

    
    
    public func storeUserCachedRecord(for group:String, identity:String, title:String, icons:String? = nil) async throws -> CKRecord {
        let record = CKRecord(recordType:"UserCachedRecord")
        record.setObject(group as NSString, forKey: "Group")
        record.setObject(identity as NSString, forKey: "Identity")
        record.setObject(title as NSString, forKey: "Title")
        if let icons = icons {
            record.setObject(icons as NSString, forKey: "Icons")
        } else {
            record.setObject("" as NSString, forKey: "Icons")
        }
        return try await cacheContainer.privateCloudDatabase.save(record)
    }
    
    public func deleteUserCachedRecord(for cachedRecord:UserCachedRecord) async throws {
        try await cacheContainer.privateCloudDatabase.deleteRecord(withID: CKRecord.ID(recordName: cachedRecord.recordId))
    }
}


