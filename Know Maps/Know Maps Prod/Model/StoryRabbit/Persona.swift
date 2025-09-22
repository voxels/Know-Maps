import Foundation

class Persona: Codable {
    let id: Int
    let name: String
    let description: String
    let genreTags: [String]
    let poiTypes: [String]
    let pictureUrl: String
    let stage: String?
    //let createdAt: Date?
    //let updatedAt: Date?
    let subscriptionType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case genreTags
        case poiTypes
        case pictureUrl
        case stage
        //case createdAt
        //case updatedAt
        case subscriptionType
    }

    init(id: Int,
         name: String,
         description: String,
         genreTags: [String],
         poiTypes: [String],
         pictureUrl: String,
         stage: String? = nil,
         //createdAt: Date? = nil,
         //updatedAt: Date? = nil,
         subscriptionType: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.genreTags = genreTags
        self.poiTypes = poiTypes
        self.pictureUrl = pictureUrl
        self.stage = stage
        //self.createdAt = createdAt
        //self.updatedAt = updatedAt
        self.subscriptionType = subscriptionType
    }

    // From JSON
    static func fromJson(_ json: [String: Any]) -> Persona? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json, options: []),
              let persona = try? JSONDecoder().decode(Persona.self, from: jsonData) else {
            return nil
        }
        return persona
    }

    // To JSON
    func toJson() -> [String: Any]? {
        guard let jsonData = try? JSONEncoder().encode(self),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
              let jsonDict = jsonObject as? [String: Any] else {
            return nil
        }
        return jsonDict
    }

    func isPremium() -> Bool {
        return subscriptionType == "premium"
    }
}

