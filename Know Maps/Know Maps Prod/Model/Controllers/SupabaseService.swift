// SupabaseService.swift

import Foundation
import Supabase

// Define a struct to represent a Point of Interest, matching your 'pois' table
public struct POI: Decodable, Identifiable {
    public let id: Int
    let tour_id: Int
    let title: String
    let description: String?
    let latitude: Double
    let longitude: Double
    let script: String?
    let audio_path: String?
}

public struct Tour: Decodable, Identifiable {
    public let id: Int
    let creator_id:Int
    let title: String
    let short_description: String?
    let is_public:Bool
    let created_at:Date
    let updated_at:Date
    let persona_id:Int?
    let image_path:String?
}

public final class SupabaseService {
    static let shared = SupabaseService()

    private let supabase: SupabaseClient

    private init() {
        supabase = SupabaseClient(
          supabaseURL: URL(string: "https://bmwglbhezxbbxudthfqf.supabase.co")!,
          supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJtd2dsYmhlenhiYnh1ZHRoZnFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU3OTI2OTMsImV4cCI6MjA3MTM2ODY5M30.fHzLXDkE3BP5b63is4GbRnpzZaOWGHqroq0WXKFh6OY"
        )

    }

    // Fetch all POIs from the 'pois' table
    func fetchPOIs() async throws -> [POI] {
        let response: [POI] = try await supabase
            .from("public_pois")
            .select()
            .execute()
            .value
        return response
    }
    
    func fetchTours() async throws -> [Tour] {
        let response: [Tour] = try await supabase
            .from("tours")
            .select()
            .execute()
            .value ?? []
        return response
    }

    // Download audio data from Supabase Storage from the 'media' bucket
    func downloadAudio(at path: String) async throws -> URL {
        let filePath = "\(path.components(separatedBy: "/").dropFirst().joined(separator: "/"))"
        let data = try await supabase.storage
            .from("poi-audio")
            .createSignedURL(path: filePath, expiresIn: 3600)
        return data
    }
}
