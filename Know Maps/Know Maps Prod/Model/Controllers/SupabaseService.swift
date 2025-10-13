// SupabaseService.swift

import Foundation
@preconcurrency import Supabase

// MARK: - Models

// Define a struct to represent a Point of Interest, matching your 'pois' table
public struct POI: Decodable, Identifiable, Equatable, Sendable {
    public let id: Int
    public let tour_id: Int
    public let title: String
    public let description: String?
    public let latitude: Double
    public let longitude: Double
    public let script: String?
    public let audio_path: String?
    public let image_path: String?
    public let order: Int

    // Convenience method to download POI image
    public func downloadImage() async throws -> URL? {
        guard let image_path = image_path else { return nil }
        return try await SupabaseService.shared.downloadPOIImage(at: image_path)
    }
}

public struct Tour: Decodable, Identifiable, Equatable, Sendable {
    public let id: Int
    public let creator_id: Int
    public let title: String
    public let short_description: String?
    public let is_public: Bool
    public let created_at: Date
    public let updated_at: Date
    public let persona_id: Int?
    public let image_path: String?

    // Convenience method to download Tour image
    public func downloadImage() async throws -> URL? {
        guard let image_path = image_path else { return nil }
        return try await SupabaseService.shared.downloadTourImage(at: image_path)
    }
}

// MARK: - Errors
public enum SupabaseServiceError: Error, Sendable, LocalizedError {
    case invalidURL
    case decodingStrategyNotConfigured
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .decodingStrategyNotConfigured: return "Decoding strategy not configured"
        case .cancelled: return "Operation was cancelled"
        }
    }
}

// MARK: - Service
// Use an actor for thread safety and isolation.
public actor SupabaseService {
    public nonisolated static let shared = SupabaseService()

    // The client is not Sendable; keep it isolated to the actor. We mark it as let to avoid mutation.
    private let supabase: SupabaseClient

    // Simple in-memory cache for signed URLs to avoid re-signing within a short window.
    // Keys are bucket+path; values store URL and expiry.
    private struct CachedURL: Sendable { let url: URL; let expiry: Date }
    private var signedURLCache: [String: CachedURL] = [:]

    // ISO8601 date decoding support if needed by Supabase JSON payloads
    private static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        // Adjust if your schema uses a different format
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private init() {
        supabase = SupabaseClient(
            supabaseURL: URL(string: "https://bmwglbhezxbbxudthfqf.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJtd2dsYmhlenhiYnh1ZHRoZnFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU3OTI2OTMsImV4cCI6MjA3MTM2ODY5M30.fHzLXDkE3BP5b63is4GbRnpzZaOWGHqroq0WXKFh6OY"
        )
    }

    // MARK: - Public API

    // Fetch all POIs from the 'public_pois' view/table
    public func fetchPOIs() async throws -> [POI] {
        try Task.checkCancellation()
        // Network I/O off the main actor; actor isolation ensures thread-safety.
        let response: [POI] = try await supabase
            .from("public_pois")
            .select()
            .execute()
            .value
        return response
    }

    public func fetchTours() async throws -> [Tour] {
        try Task.checkCancellation()
        // Some Supabase libs return optional; coalesce to [] for safety.
        let response: [Tour] = try await supabase
            .from("tours")
            .select()
            .execute()
            .value ?? []
        return response
    }

    /// Fetch POIs and Tours concurrently for faster startup.
    /// - Returns: A tuple of (pois, tours).
    public func fetchPOIsAndTours() async throws -> ([POI], [Tour]) {
        try Task.checkCancellation()
        async let pois: [POI] = fetchPOIs()
        async let tours: [Tour] = fetchTours()
        return try await (pois, tours)
    }

    /// UI-friendly helper that hops results back to the main actor.
    @MainActor
    public func fetchPOIsAndToursForUI() async throws -> ([POI], [Tour]) {
        // Run the concurrent fetch on the service actor, then return to MainActor implicitly.
        return try await self.fetchPOIsAndTours()
    }

    // MARK: - Storage Helpers

    // Normalize path by removing the first path component if the path is of the form "bucket/path".
    nonisolated private static func normalizedPath(_ path: String) -> String {
        let comps = path.split(separator: "/", omittingEmptySubsequences: true)
        guard comps.count > 1 else { return String(path) }
        // Drop the first component which is often the bucket name when persisted
        return comps.dropFirst().joined(separator: "/")
    }

    private func cachedSignedURL(for key: String, now: Date = Date()) -> URL? {
        if let entry = signedURLCache[key], entry.expiry > now {
            return entry.url
        }
        signedURLCache.removeValue(forKey: key)
        return nil
    }

    private func setCachedSignedURL(_ url: URL, for key: String, ttl: TimeInterval) {
        signedURLCache[key] = CachedURL(url: url, expiry: Date().addingTimeInterval(ttl * 0.9)) // refresh a bit earlier
    }

    @inline(__always)
    private func makeCacheKey(bucket: String, path: String) -> String {
        "\(bucket)::\(path)"
    }

    // Download audio data from Supabase Storage from the 'poi-audio' bucket
    public func downloadAudio(at path: String) async throws -> URL {
        try Task.checkCancellation()
        let bucket = "poi-audio"
        let normalized = Self.normalizedPath(path)
        let cacheKey = makeCacheKey(bucket: bucket, path: normalized)
        if let cached = cachedSignedURL(for: cacheKey) { return cached }

        let ttl: TimeInterval = 3600
        let url = try await supabase.storage
            .from(bucket)
            .createSignedURL(path: normalized, expiresIn: Int(ttl))
        setCachedSignedURL(url, for: cacheKey, ttl: ttl)
        return url
    }

    // Download POI image from Supabase Storage
    public func downloadPOIImage(at path: String) async throws -> URL {
        try Task.checkCancellation()
        return try await downloadImage(from: "poi-images", at: path)
    }

    // Download Tour image from Supabase Storage
    public func downloadTourImage(at path: String) async throws -> URL {
        try Task.checkCancellation()
        return try await downloadImage(from: "tour-images", at: path)
    }

    // Generic image download method (if you want to specify the bucket)
    public func downloadImage(from bucket: String, at path: String) async throws -> URL {
        try Task.checkCancellation()
        let normalized = Self.normalizedPath(path)
        let cacheKey = makeCacheKey(bucket: bucket, path: normalized)
        if let cached = cachedSignedURL(for: cacheKey) { return cached }

        let ttl: TimeInterval = 3600
        let url = try await supabase.storage
            .from(bucket)
            .createSignedURL(path: normalized, expiresIn: Int(ttl))
        setCachedSignedURL(url, for: cacheKey, ttl: ttl)
        return url
    }
}

