//
//  PersonalizedSearchSessionProtocol.swift
//  Know Maps
//

import Foundation

public protocol PersonalizedSearchSessionProtocol: Sendable {
    var fsqIdentity: String? { get async }
    var fsqAccessToken: String? { get async }
    func fetchManagedUserIdentity(cacheManager: CacheManager) async throws -> String?
    func fetchManagedUserAccessToken(cacheManager: CacheManager) async throws -> String
    func addFoursquareManagedUserIdentity(cacheManager: CacheManager) async throws -> Bool
    func autocompleteTastes(caption: String, parameters: [String: String]?, cacheManager: CacheManager) async throws -> FSQTastesResponse
    func fetchRecommendedVenues(with request: RecommendedPlaceSearchRequest, cacheManager: CacheManager) async throws -> [PlaceSearchResponse]
    func fetchTastes(page: Int, cacheManager: CacheManager) async throws -> FSQTastesResponse
    func fetchRelatedVenues(for fsqID: String, cacheManager: CacheManager) async throws -> [PlaceSearchResponse]
}
