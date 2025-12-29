//
//  PlaceSearchRequestService.swift
//  Know Maps
//
//  Created on 11/26/24.
//

import Foundation
import CoreLocation

// MARK: - Place Search Request Service Protocol
public protocol PlaceSearchRequestService: Sendable, AnyObject {
    func fetchPlaceSearchResponse(for query: String, location: CLLocation?) async throws -> [PlaceSearchResponse]
    func fetchPlaceDetailsResponse(for fsqID: String) async throws -> PlaceDetailsResponse
}
