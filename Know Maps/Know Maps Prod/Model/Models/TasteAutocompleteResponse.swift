//
//  TasteAutocompleteResponse.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 9/18/24.
//

import Foundation

public struct TasteAutocompleteResponse: Equatable, Hashable, Sendable {
    public let uuid = UUID().uuidString
    public var id: String
    public var text: String
}
