import Foundation

struct ServerConnectionConfig {
    let baseURL: URL
    let token: String
}

extension ServerConnectionConfig {
    static func make(urlString: String, token: String) -> ServerConnectionConfig? {
        guard !urlString.isEmpty, !token.isEmpty else { return nil }
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalizedString: String
        if trimmed.lowercased().hasPrefix("http") {
            normalizedString = trimmed
        } else {
            normalizedString = "http://\(trimmed)"
        }
        guard let url = URL(string: normalizedString) else { return nil }
        return ServerConnectionConfig(baseURL: url, token: token)
    }
}

final class ServerLibraryService {
    private let networkManager = NetworkManager.shared
    
    func fetchLibraries(emby: ServerConnectionConfig?, plex: ServerConnectionConfig?) async -> [Channel] {
        var aggregated: [Channel] = []
        if let embyConfig = emby {
            if let embyChannels = try? await fetchEmbyItems(config: embyConfig) {
                aggregated.append(contentsOf: embyChannels)
            }
        }
        if let plexConfig = plex {
            if let plexChannels = try? await fetchPlexItems(config: plexConfig) {
                aggregated.append(contentsOf: plexChannels)
            }
        }
        return aggregated
    }
    
    private func fetchEmbyItems(config: ServerConnectionConfig) async throws -> [Channel] {
        var baseString = config.baseURL.absoluteString
        if baseString.hasSuffix("/") { baseString.removeLast() }
        if !baseString.lowercased().contains("/emby") {
            baseString += "/emby"
        }
        guard var components = URLComponents(string: baseString + "/Items") else { return [] }
        components.queryItems = [
            URLQueryItem(name: "IncludeItemTypes", value: "Movie,Series"),
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "Limit", value: "60"),
            URLQueryItem(name: "Fields", value: "Overview,CommunityRating,RunTimeTicks,PremiereDate"),
            URLQueryItem(name: "SortBy", value: "DateCreated"),
            URLQueryItem(name: "SortOrder", value: "Descending"),
            URLQueryItem(name: "api_key", value: config.token)
        ]
        guard let url = components.url else { return [] }
        let data = try await networkManager.fetchData(from: url, cachePolicy: .reloadIgnoringLocalCacheData)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(EmbyItemsResponse.self, from: data)
        return response.items.compactMap { item in
            // Use the download endpoint so we get a direct file URL suitable for AVPlayer
            guard let streamURL = URL(string: "\(baseString)/Items/\(item.id)/Download?api_key=\(config.token)") else { return nil }
            let posterURL = item.primaryImageTag.flatMap { URL(string: "\(baseString)/Items/\(item.id)/Images/Primary?tag=\($0)&api_key=\(config.token)") }
            let backdropURL = item.backdropImageTags?.first.flatMap { tag in
                URL(string: "\(baseString)/Items/\(item.id)/Images/Backdrop/0?tag=\(tag)&api_key=\(config.token)")
            }
            let contentType: ContentType = item.type.lowercased() == "series" || item.type.lowercased() == "episode" ? .series : .movie
            return Channel(
                name: item.name,
                url: streamURL,
                logo: posterURL,
                group: "My Server (Emby)",
                tvgId: item.id,
                contentType: contentType,
                duration: item.runTimeTicks.flatMap { formatTicks($0) },
                rating: item.communityRating,
                releaseDate: item.premiereDate,
                plot: item.overview,
                genre: item.genres?.joined(separator: ", "),
                cover: posterURL,
                backdrop: backdropURL
            )
        }
    }
    
    private func formatTicks(_ ticks: Int64) -> String {
        let seconds = Double(ticks) / 10_000_000
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
    
    private func fetchPlexItems(config: ServerConnectionConfig) async throws -> [Channel] {
        var baseString = config.baseURL.absoluteString
        if baseString.hasSuffix("/") { baseString.removeLast() }
        guard let url = URL(string: "\(baseString)/library/recentlyAdded?X-Plex-Token=\(config.token)&X-Plex-Container-Size=60") else { return [] }
        let data = try await networkManager.fetchData(from: url, cachePolicy: .reloadIgnoringLocalCacheData)
        let parser = PlexLibraryXMLParser(baseURL: baseString, token: config.token)
        return parser.parse(data: data)
    }
}

private struct EmbyItemsResponse: Codable {
    let items: [EmbyItem]
    enum CodingKeys: String, CodingKey { case items = "Items" }
}

private struct EmbyItem: Codable {
    let id: String
    let name: String
    let overview: String?
    let type: String
    let runTimeTicks: Int64?
    let communityRating: Double?
    let premiereDate: String?
    let genres: [String]?
    let imageTags: [String: String]?
    let backdropImageTags: [String]?
    
    var primaryImageTag: String? { imageTags?["Primary"] }
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case overview = "Overview"
        case type = "Type"
        case runTimeTicks = "RunTimeTicks"
        case communityRating = "CommunityRating"
        case premiereDate = "PremiereDate"
        case genres = "Genres"
        case imageTags = "ImageTags"
        case backdropImageTags = "BackdropImageTags"
    }
}

private final class PlexLibraryXMLParser: NSObject, XMLParserDelegate {
    private struct PlexVideo {
        var ratingKey: String
        var type: String
        var title: String
        var summary: String?
        var thumb: String?
        var art: String?
        var duration: String?
        var addedAt: String?
        var partKey: String?
        var grandparentTitle: String?
    }
    
    private let baseURL: String
    private let token: String
    private var currentVideo: PlexVideo?
    private var items: [Channel] = []
    
    init(baseURL: String, token: String) {
        self.baseURL = baseURL
        self.token = token
    }
    
    func parse(data: Data) -> [Channel] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        if elementName == "Video" {
            currentVideo = PlexVideo(
                ratingKey: attributeDict["ratingKey"] ?? UUID().uuidString,
                type: attributeDict["type"] ?? "movie",
                title: attributeDict["title"] ?? "Unknown",
                summary: attributeDict["summary"],
                thumb: attributeDict["thumb"],
                art: attributeDict["art"],
                duration: attributeDict["duration"],
                addedAt: attributeDict["addedAt"],
                partKey: nil,
                grandparentTitle: attributeDict["grandparentTitle"]
            )
        } else if elementName == "Part" {
            currentVideo?.partKey = attributeDict["key"]
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "Video", let video = currentVideo {
            guard let partKey = video.partKey else {
                currentVideo = nil
                return
            }
            let normalizedPartKey = partKey.hasPrefix("/") ? partKey : "/" + partKey
            let playbackURLString = baseURL + normalizedPartKey + (normalizedPartKey.contains("?") ? "&" : "?") + "X-Plex-Token=\(token)"
            guard let playbackURL = URL(string: playbackURLString) else {
                currentVideo = nil
                return
            }
            let posterURL = video.thumb.flatMap { thumb -> URL? in
                let normalizedThumb = thumb.hasPrefix("/") ? thumb : "/" + thumb
                return URL(string: baseURL + normalizedThumb + "?X-Plex-Token=\(token)")
            }
            let backdropURL = video.art.flatMap { art -> URL? in
                let normalizedArt = art.hasPrefix("/") ? art : "/" + art
                return URL(string: baseURL + normalizedArt + "?X-Plex-Token=\(token)")
            }
            let contentType: ContentType = video.type.lowercased() == "episode" ? .series : .movie
            let durationString: String?
            if let raw = video.duration, let millis = Double(raw) {
                let totalMinutes = Int(millis / 60000)
                let hours = totalMinutes / 60
                let minutes = totalMinutes % 60
                durationString = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
            } else {
                durationString = nil
            }
            let title = contentType == .series && video.grandparentTitle != nil ? "\(video.grandparentTitle!) • \(video.title)" : video.title
            let channel = Channel(
                name: title,
                url: playbackURL,
                logo: posterURL,
                group: "My Server (Plex)",
                tvgId: video.ratingKey,
                contentType: contentType,
                duration: durationString,
                releaseDate: video.addedAt,
                plot: video.summary,
                cover: posterURL,
                backdrop: backdropURL
            )
            items.append(channel)
            currentVideo = nil
        }
    }
}
