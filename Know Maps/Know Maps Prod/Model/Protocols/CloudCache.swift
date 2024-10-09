//
//  CloudCache.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/8/24.
//

import Foundation
import CloudKit

public protocol CloudCache: AnyObject {
    // Properties
    var hasFsqAccess: Bool { get }
    
    // Fetching and Caching Methods
    func fetch(url: URL, from cloudService: CloudCacheServiceKey) async throws -> Any
    func fetchGroupedUserCachedRecords(for group: String) async throws -> [UserCachedRecord]
    func userCachedCKRecord(for cachedRecord: UserCachedRecord)->CKRecord
    func storeUserCachedRecord(for group: String, identity: String, title: String, icons: String, list: String, section: String, rating:Double) async throws -> String
    func updateUserCachedRecordRating(recordId: String, newRating: Double) async throws
    func deleteUserCachedRecord(for cachedRecord: UserCachedRecord) async throws
    func deleteAllUserCachedRecords(for group: String) async throws -> (saveResults: [CKRecord.ID: Result<CKRecord, Error>], deleteResults: [CKRecord.ID: Result<Void, Error>])
    func deleteAllUserCachedGroups() async throws
    
    func storeRecommendationData(for identity:String, attributes:[String], reviews:[String], userCachedCKRecord:CKRecord) async throws -> String
    func fetchRecommendationData() async throws -> [RecommendationData]
    func deleteRecommendationData(for recordId: String) async throws -> (
        saveResults: [CKRecord.ID: Result<CKRecord, Error>],
        deleteResults: [CKRecord.ID: Result<Void, Error>]
    )
    
    // CloudKit Identity and OAuth Management
    func fetchFsqIdentity() async throws -> String
    func fetchToken(for fsqUserId: String) async throws -> String
    func storeFoursquareIdentityAndToken(for fsqUserId: String, oauthToken: String)

    // API Key and Session Management
    func apiKey(for service: CloudCacheServiceKey) async throws -> String
    func session(service: String) async throws -> URLSession
    func fetchCloudKitUserRecordID() async throws -> CKRecord.ID?

    // Background Operations
    func clearCache()
}
