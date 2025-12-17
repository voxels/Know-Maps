import Foundation
import SwiftData

@Model
public final class UserCachedRecord: Identifiable, Hashable, Equatable, Codable {
    public var id: UUID = UUID()
    var recordId: String = UUID().uuidString
    var group: String = ""
    var identity: String = ""
    var title: String = ""
    var icons: String = ""
    var list: String = ""
    var section: String = ""
    var rating: Double = 0

    public init(id: UUID = UUID(), recordId: String, group: String, identity: String, title: String, icons: String, list: String, section: String, rating: Double) {
        self.id = id
        self.recordId = recordId
        self.group = group
        self.identity = identity
        self.title = title
        self.icons = icons
        self.list = list
        self.section = section
        self.rating = rating
    }

    public func setRecordId(to string: String) {
        recordId = string
    }

    // MARK: - Codable Conformance

    enum CodingKeys: String, CodingKey {
        case id
        case recordId
        case group
        case identity
        case title
        case icons
        case list
        case section
        case rating
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(recordId, forKey: .recordId)
        try container.encode(group, forKey: .group)
        try container.encode(identity, forKey: .identity)
        try container.encode(title, forKey: .title)
        try container.encode(icons, forKey: .icons)
        try container.encode(list, forKey: .list)
        try container.encode(section, forKey: .section)
        try container.encode(rating, forKey: .rating)
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let recordId = try container.decode(String.self, forKey: .recordId)
        let group = try container.decode(String.self, forKey: .group)
        let identity = try container.decode(String.self, forKey: .identity)
        let title = try container.decode(String.self, forKey: .title)
        let icons = try container.decode(String.self, forKey: .icons)
        let list = try container.decode(String.self, forKey: .list)
        let section = try container.decode(String.self, forKey: .section)
        let rating = try container.decode(Double.self, forKey: .rating)
        self.init(id: id, recordId: recordId, group: group, identity: identity, title: title, icons: icons, list: list, section: section, rating: rating)
    }
}
