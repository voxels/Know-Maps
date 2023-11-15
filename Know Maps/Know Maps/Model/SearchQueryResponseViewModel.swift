//
//  SearchQueryResponseViewModel.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 5/29/23.
//

import Foundation
import CoreLocation

public struct SearchQueryResponseViewModel {
    public let responseString:String
    public let placeDetailsResponses:[PlaceDetailsResponse]
    public let targetLocation:CLLocation
}
