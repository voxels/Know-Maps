//
//  PlaceSearchSessionProtocol.swift
//  Know Maps
//

import Foundation

public protocol PlaceSearchSessionProtocol: Sendable {
    func query(request: PlaceSearchRequest) async throws -> FSQSearchResponse
    func details(for request: PlaceDetailsRequest) async throws -> FSQPlace
    func photos(for fsqID: String) async throws -> FSQPhotosResponse
    func tips(for fsqID: String) async throws -> [FSQTip]
    func autocomplete(caption: String, limit: Int?, locationResult: LocationResult) async throws -> FSQAutocompleteResponse
    func searchLocations(caption: String, locationResult: LocationResult?) async throws -> [LocationResult]
}
