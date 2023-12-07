//
//  Item.swift
//  Know Maps MacOS
//
//  Created by Michael A Edgcumbe on 12/6/23.
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
