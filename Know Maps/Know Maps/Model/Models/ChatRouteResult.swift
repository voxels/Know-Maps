//
//  ChatRouteResult.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/23/23.
//

import Foundation
import MapKit

public struct ChatRouteResult : Identifiable, Equatable, Hashable {
    public let id = UUID()
    
    public static func == (lhs: ChatRouteResult, rhs: ChatRouteResult) -> Bool {
        lhs.id == rhs.id
    }
    
    let route:MKRoute?
    let instructions:String
}
