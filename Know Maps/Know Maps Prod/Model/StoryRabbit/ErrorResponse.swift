import Foundation

struct ErrorResponse: Codable {
    let errorType: String
    let data: EntitlementData
    let message: String?
}

struct EntitlementData: Codable {
    let entitlementType: String
    let personaId: Int?
}
