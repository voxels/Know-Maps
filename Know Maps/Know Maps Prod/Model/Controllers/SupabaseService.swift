// SupabaseService.swift

import Foundation
import Supabase

// Define a struct to represent a Point of Interest, matching your 'pois' table
struct POI: Decodable {
    let id: Int
    let tour_id: Int
    let title: String
    let description: String?
    let latitude: Double
    let longitude: Double
    let script: String?
    let audio_path: String?
}

public class SupabaseService {
    static let shared = SupabaseService()

    private let supabase: SupabaseClient

    private init() {
        // Replace with your Supabase project URL and anon key
        let supabaseURL = URL(string: "https://bmwglbhezxbbxudthfqf.supabase.co")!
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJtd2dsYmhlenhiYnh1ZHRoZnFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU3OTI2OTMsImV4cCI6MjA3MTM2ODY5M30.fHzLXDkE3BP5b63is4GbRnpzZaOWGHqroq0WXKFh6OY"

        supabase = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
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

    // Download audio data from Supabase Storage from the 'media' bucket
    func downloadAudio(at path: String) async throws -> URL {
        let filePath = "\(path.components(separatedBy: "/").dropFirst().joined(separator: "/"))"
        let data = try await supabase.storage
            .from("poi-audio")
            .createSignedURL(path: filePath, expiresIn: 3600)
        return data
    }
}
