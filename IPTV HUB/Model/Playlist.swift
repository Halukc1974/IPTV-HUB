//
//  Playlist.swift
//  Easy IPTV
//
//  Created by Haluk CELEBI on 15.11.2025.
//


import Foundation

// MARK: - Playlist Type Enum
enum PlaylistType: String, Codable, CaseIterable, Identifiable {
    case m3u8 = "M3U8 playlist"
    case xtream = "Xtream playlist"
    case stremio = "Stremio playlist"
    
    var id: String { self.rawValue }
}

// MARK: - Playlist Model
// Represents a saved playlist (M3U8, Xtream, or Stremio)
// Codable: To save as JSON
// Identifiable: To display in SwiftUI List
struct Playlist: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var type: PlaylistType
    var iconName: String? // SF Symbol name for identification
    
    // M3U8 specific fields
    var m3uURL: String?
    var epgURL: String?
    
    // Xtream specific fields
    var xtreamServerURL: String?
    var xtreamUsername: String?
    var xtreamPassword: String?
    
    // Stremio specific fields
    var stremioAddonURL: String?
    
    // All fields in JSON encoding
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case iconName
        case m3uURL
        case epgURL
        case xtreamServerURL
        case xtreamUsername
        case xtreamPassword
        case stremioAddonURL
    }
    
    // Initializer for creating new playlists
    init(id: UUID = UUID(), name: String, type: PlaylistType, iconName: String?, m3uURL: String?, epgURL: String?, xtreamServerURL: String?, xtreamUsername: String?, xtreamPassword: String?, stremioAddonURL: String?) {
        self.id = id
        self.name = name
        self.type = type
        self.iconName = iconName
        self.m3uURL = m3uURL
        self.epgURL = epgURL
        self.xtreamServerURL = xtreamServerURL
        self.xtreamUsername = xtreamUsername
        self.xtreamPassword = xtreamPassword
        self.stremioAddonURL = stremioAddonURL
    }
    
    // Helper computed property to get display URL
    var displayURL: String {
        switch type {
        case .m3u8:
            return m3uURL ?? ""
        case .xtream:
            return xtreamServerURL ?? ""
        case .stremio:
            return stremioAddonURL ?? ""
        }
    }
}
