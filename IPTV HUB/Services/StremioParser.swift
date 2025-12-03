//
//  StremioManifest.swift
//  Easy IPTV
//
//  Created by Haluk CELEBI on 16.11.2025.
//


//
//  StremioParser.swift
//  Easy IPTV
//
//  Created by Haluk CELEBI on 16.11.2025.
//

import Foundation

// MARK: - Stremio Response Models
struct StremioManifest: Codable {
    let id: String
    let name: String
    let description: String?
    let version: String
    let resources: [String]?
    let types: [String]?
    let catalogs: [StremioCatalog]?
}

struct StremioCatalog: Codable {
    let id: String
    let type: String
    let name: String
}

struct StremioStream: Codable {
    let name: String?
    let title: String?
    let url: String
    let infoHash: String?
    let behaviorHints: StreomioBehaviorHints?
    
    enum CodingKeys: String, CodingKey {
        case name
        case title
        case url
        case infoHash
        case behaviorHints
    }
}

struct StreomioBehaviorHints: Codable {
    let notWebReady: Bool?
    let bingeGroup: String?
    
    enum CodingKeys: String, CodingKey {
        case notWebReady
        case bingeGroup
    }
}

struct StremioMeta: Codable {
    let id: String
    let type: String
    let name: String
    let poster: String?
    let background: String?
    let logo: String?
    let description: String?
    let genres: [String]?
}

// MARK: - Stremio Parser Error
enum StremioParserError: Error {
    case invalidURL
    case invalidAddon
    case networkError(Error)
    case decodingError(Error)
    case noStreamsAvailable
}

// MARK: - Stremio Parser
class StremioParser {
    
    private let networkManager = NetworkManager.shared
    
    /// Parses Stremio add-on to get available streams
    /// Note: Stremio add-ons are primarily for movies/series, not live TV
    /// This is a simplified implementation for demonstration
    func parse(addonURL: String) async throws -> [Channel] {
        
        // 1. Validate and build manifest URL
        guard var components = URLComponents(string: addonURL) else {
            throw StremioParserError.invalidURL
        }
        
        // Ensure the URL ends with /manifest.json
        if !components.path.hasSuffix("/manifest.json") {
            if components.path.hasSuffix("/") {
                components.path += "manifest.json"
            } else {
                components.path += "/manifest.json"
            }
        }
        
        guard let manifestURL = components.url else {
            throw StremioParserError.invalidURL
        }
        
        print("StremioParser: Fetching manifest from \(manifestURL.absoluteString)")
        
        // 2. Fetch manifest
        let manifestData: Data
        do {
            manifestData = try await networkManager.fetchData(from: manifestURL)
        } catch {
            print("StremioParser NETWORK ERROR: \(error.localizedDescription)")
            throw StremioParserError.networkError(error)
        }
        
        // 3. Parse manifest
        let manifest: StremioManifest
        do {
            let decoder = JSONDecoder()
            manifest = try decoder.decode(StremioManifest.self, from: manifestData)
            print("StremioParser: Loaded add-on '\(manifest.name)' v\(manifest.version)")
        } catch {
            print("StremioParser DECODING ERROR: \(error.localizedDescription)")
            throw StremioParserError.decodingError(error)
        }
        
        // 4. Check if add-on supports catalogs
        guard let catalogs = manifest.catalogs, !catalogs.isEmpty else {
            print("StremioParser: Add-on has no catalogs")
            throw StremioParserError.noStreamsAvailable
        }
        
        // 5. For demonstration, create dummy channels from catalogs
        // In a real implementation, you would:
        // - Fetch catalog items: GET /catalog/{type}/{id}.json
        // - For each item, fetch streams: GET /stream/{type}/{id}.json
        // - Parse stream URLs and create channels
        
        var channels = [Channel]()
        
        for catalog in catalogs {
            // Create a placeholder channel for each catalog
            // This is simplified - real implementation would fetch actual streams
            let channelName = "\(manifest.name) - \(catalog.name)"
            
            // Dummy URL (in real implementation, fetch actual stream URLs)
            let dummyURLString = "\(addonURL)/stream/\(catalog.type)/\(catalog.id)"
            guard let dummyURL = URL(string: dummyURLString) else { continue }
            
            let channel = Channel(
                id: UUID(),
                name: channelName,
                url: dummyURL,
                logo: nil,
                group: "Stremio - \(manifest.name)",
                tvgId: catalog.id,
                isFavorite: false,
                categoryIDs: []
            )
            
            channels.append(channel)
        }
        
        print("StremioParser: Created \(channels.count) placeholder channels from catalogs.")
        print("Note: Full Stremio implementation requires fetching individual streams.")
        
        return channels
    }
}
