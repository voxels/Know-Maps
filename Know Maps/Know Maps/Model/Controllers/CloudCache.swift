//
//  CloudCache.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/28/23.
//

import Foundation
import CloudKit

open class CloudCache : NSObject, ObservableObject {
    let cacheContainer = CKContainer(identifier:"iCloud.com.noisederived.No-Maps.Cache")
    @Published var fsqid:String = ""
    @Published var desc:String = ""
    public func fetchGeneratedDescription(for fsqid:String) async throws -> String {
        self.fsqid = fsqid
        let predicate = NSPredicate(format: "fsqid == %@", fsqid)
        let query = CKQuery(recordType: "GeneratedDescription", predicate: predicate)
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["description"]
        operation.resultsLimit = 1
        operation.recordMatchedBlock = { recordId, result in
            do {
                let record = try result.get()
                if let description = record["description"] as? String {
                    print("Found Generated Description \(description)")
                    self.desc = description
                } else {
                    self.desc = ""
                    print("Did not find description")
                }
            } catch {
                print(error)
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
            self?.fsqid = fsqid
            self?.desc = description
        }
    }
}


