//
//  Item.swift
//  Know Maps iOS
//
//  Created by Michael A Edgcumbe on 12/15/23.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
