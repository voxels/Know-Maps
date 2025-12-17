import Foundation
import SwiftData

@Model
public class UserCachedRecord: Identifiable, Hashable, Equatable, Codable {
    public var id:UUID
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

    public required convenience init(from decoder: Decoder) throws {
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

public class SendableCachedRecord : UserCachedRecord, Sendable {
    public let _id:UUID
    let _recordId: String
    let _group: String
    let _identity: String
    let _title: String
    let _icons: String
    let _list: String
    let _section: String
    let _rating: Double
    
    static func sendableRecords(_ userCachedRecords:[UserCachedRecord])->[SendableCachedRecord] {
        return userCachedRecords.compactMap({ record in
            return SendableCachedRecord(record)
        })
    }
    
    public convenience init(_ userCachedRecord:UserCachedRecord) {
        self.init(id:userCachedRecord.id, recordId: userCachedRecord.recordId, group: userCachedRecord.group, identity: userCachedRecord.identity, title: userCachedRecord.title, icons: userCachedRecord.icons, list: userCachedRecord.list, section: userCachedRecord.section, rating:userCachedRecord.rating)
    }
    
    public required override init(id: UUID, recordId: String, group: String, identity: String, title: String, icons: String, list: String, section: String, rating: Double) {
        let userCachedRecord = UserCachedRecord(recordId: recordId, group: group, identity: identity, title: title, icons: icons, list: list, section: section, rating: rating)
        self._id = userCachedRecord.id
        self._recordId = userCachedRecord.recordId
        self._group = userCachedRecord.group
        self._identity = userCachedRecord.identity
        self._title = userCachedRecord.title
        self._icons = userCachedRecord.icons
        self._list = userCachedRecord.list
        self._section = userCachedRecord.section
        self._rating = userCachedRecord.rating
        super.init(recordId: recordId, group: group, identity: identity, title: title, icons: icons, list: list, section: section, rating: rating)
    }
    
    public required convenience init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
    
    required public init(backingData: any SwiftData.BackingData<UserCachedRecord>) {
        fatalError("init(backingData:) has not been implemented")
    }
}
