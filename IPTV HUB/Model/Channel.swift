//
//  ContentType.swift
//  IPTV HUB
//
//  Created by Haluk CELEBI on 3.12.2025.
//


import Foundation

// MARK: - Content Type Enum
enum ContentType: String, Codable {
    case liveTV = "live"
    case movie = "movie"
    case series = "series"
}

// MARK: - Episode Model
struct Episode: Identifiable, Codable, Hashable {
    let id: String
    let episodeNum: Int
    let title: String
    let containerExtension: String?
    let info: EpisodeInfo?
    let streamURL: URL?
    
    struct EpisodeInfo: Codable, Hashable {
        let duration: String?
        let plot: String?
        let releaseDate: String?
        let rating: Double?
        
        enum CodingKeys: String, CodingKey {
            case duration
            case plot
            case releaseDate = "release_date"
            case rating
        }
    }
}

// MARK: - Season Model
struct Season: Identifiable, Codable, Hashable {
    let id: String
    let seasonNumber: Int
    let name: String
    let episodes: [Episode]
    let coverURL: URL?
    
    enum CodingKeys: String, CodingKey {
        case id
        case seasonNumber = "season_number"
        case name
        case episodes
        case coverURL = "cover"
    }
}

// MARK: - Category Model
/// Represents a user-created bouquet/category.
struct ChannelCategory: Identifiable, Codable {
    
    // Default value removed to allow Codable loading.
    let id: String
    var name: String
    var order: Int = 0
    
    // NEW INITIALIZER: Assigns ID when a category is created.
    init(name: String, order: Int) {
        self.id = UUID().uuidString
        self.name = name
        self.order = order
    }
}

// MARK: - Channel Model
/// Represents a single channel in an M3U file.
struct Channel: Identifiable, Codable, Hashable {
    
    // Default value removed to allow Codable loading.
    let id: UUID
    
    let name: String
    let url: URL
    let logo: URL?
    let group: String
    let tvgId: String
    
    var isFavorite: Bool = false
    
    // Set of category IDs that this channel belongs to.
    var categoryIDs: Set<String> = []
    
    // Playlist ID that this channel belongs to
    var playlistID: UUID?
    
    // VoD (Video on Demand) properties
    var contentType: ContentType = .liveTV
    var streamId: Int?
    var containerExtension: String?
    
    // Movie-specific properties
    var duration: String?
    var rating: Double?
    var releaseDate: String?
    var plot: String?
    var director: String?
    var cast: String?
    var genre: String?
    
    // Series-specific properties
    var seasons: [Season] = []
    var seriesId: Int?
    var cover: URL?
    var backdrop: URL?
    
    // MARK: - Initializers
    
    // Custom initializer (used by M3UParser)
    init?(extinfLine: String, urlLine: String, playlistID: UUID? = nil) {
        
        // ID is assigned only when creating a new channel from M3U.
        self.id = UUID()
        
        // 1. Validate URL
        guard let url = URL(string: urlLine.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        self.url = url
        
        // 2. Extract Channel Name
        self.name = extinfLine
            .components(separatedBy: ",")
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown Channel"
        
        // 3. Extract Other Attributes
        let attributes = Self.extractAttributes(from: extinfLine)
        
        self.logo = URL(string: attributes["tvg-logo"] ?? "")
        self.group = attributes["group-title"] ?? "General"
        self.tvgId = attributes["tvg-id"] ?? ""
        self.playlistID = playlistID
        
        // 4. Detect Content Type (Movie/Series/Live TV)
        let groupTitle = self.group.lowercased()
        let fileName = url.lastPathComponent.lowercased()
        
        // Check if it's a movie or series
        if fileName.hasSuffix(".mp4") || fileName.hasSuffix(".mkv") || fileName.hasSuffix(".avi") {
            // File extension indicates VoD content
            if groupTitle.contains("series") || groupTitle.contains("episode") || groupTitle.contains("season") {
                self.contentType = .series
            } else {
                self.contentType = .movie
            }
            
            // Parse genre from group-title (e.g., "Action;Comedy;Thriller")
            let genres = self.group.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }
            if !genres.isEmpty {
                self.genre = genres.joined(separator: ", ")
            }
        } else {
            self.contentType = .liveTV
        }
    }
    
    // Direct initializer (used by XtreamParser and StremioParser)
    init(id: UUID = UUID(), name: String, url: URL, logo: URL?, group: String, tvgId: String, isFavorite: Bool = false, categoryIDs: Set<String> = [], playlistID: UUID? = nil, contentType: ContentType = .liveTV, streamId: Int? = nil, containerExtension: String? = nil, duration: String? = nil, rating: Double? = nil, releaseDate: String? = nil, plot: String? = nil, director: String? = nil, cast: String? = nil, genre: String? = nil, seasons: [Season] = [], seriesId: Int? = nil, cover: URL? = nil, backdrop: URL? = nil) {
        self.id = id
        self.name = name
        self.url = url
        self.logo = logo
        self.group = group
        self.tvgId = tvgId
        self.isFavorite = isFavorite
        self.categoryIDs = categoryIDs
        self.playlistID = playlistID
        self.contentType = contentType
        self.streamId = streamId
        self.containerExtension = containerExtension
        self.duration = duration
        self.rating = rating
        self.releaseDate = releaseDate
        self.plot = plot
        self.director = director
        self.cast = cast
        self.genre = genre
        self.seasons = seasons
        self.seriesId = seriesId
        self.cover = cover
        self.backdrop = backdrop
    }
    
    // MARK: - Helper Methods
    private static let attributeRegex: NSRegularExpression = {
        // Precompile attribute regex once to avoid repeated work per channel
        return try! NSRegularExpression(pattern: #"(\w+-?\w+)="([^"]*)""#, options: [])
    }()
    
    private static func extractAttributes(from text: String) -> [String: String] {
        var attributes = [String: String]()
        let matches = attributeRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            if match.numberOfRanges == 3,
               let keyRange = Range(match.range(at: 1), in: text),
               let valueRange = Range(match.range(at: 2), in: text) {
                let key = String(text[keyRange])
                let value = String(text[valueRange])
                attributes[key] = value
            }
        }
        return attributes
    }
}

// MARK: - Stable Identifiers
extension Channel {
    /// Returns a stable identifier that survives playlist reloads for features like Recently Watched.
    var recentIdentifier: String {
        if !tvgId.isEmpty {
            return "tvg:\(tvgId.lowercased())"
        }
        if let normalizedURL = normalizedStreamURLString {
            return "url:\(normalizedURL)"
        }
        let nameKey = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let groupKey = group.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !nameKey.isEmpty || !groupKey.isEmpty {
            return "name:\(nameKey)|group:\(groupKey)"
        }
        return "id:\(id.uuidString.lowercased())"
    }
    
    /// Normalizes the stream URL by stripping query parameters and fragments so tokens don't break persistence.
    private var normalizedStreamURLString: String? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.query = nil
        components.fragment = nil
        return components.string?.lowercased()
    }
}
