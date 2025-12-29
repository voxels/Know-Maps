import Foundation
import SwiftData

@Model
public class ProactiveCacheEntry {
    @Attribute(.unique) public var identity: String // fsqID or search term
    public var data: Data // JSON blob
    public var timestamp: Date
    
    public init(identity: String, data: Data, timestamp: Date = Date()) {
        self.identity = identity
        self.data = data
        self.timestamp = timestamp
    }
}
