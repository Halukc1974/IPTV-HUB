//
//  XtreamCategoryResponse.swift
//  Easy IPTV
//
//  Created by Haluk CELEBI on 16.11.2025.
//


//
//  XtreamParser.swift
//  Easy IPTV
//
//  Created by Haluk CELEBI on 16.11.2025.
//

import Foundation

// MARK: - Xtream API Response Models
struct XtreamCategoryResponse: Codable {
    let categoryId: String
    let categoryName: String
    let parentId: Int
    
    enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case categoryName = "category_name"
        case parentId = "parent_id"
    }
}

struct XtreamChannelResponse: Codable {
    let num: Int
    let name: String
    let streamType: String
    let streamId: Int
    let streamIcon: String?
    let epgChannelId: String?
    let categoryId: String?
    let tvArchive: Int?
    let directSource: String?
    let tvArchiveDuration: String?
    
    enum CodingKeys: String, CodingKey {
        case num
        case name
        case streamType = "stream_type"
        case streamId = "stream_id"
        case streamIcon = "stream_icon"
        case epgChannelId = "epg_channel_id"
        case categoryId = "category_id"
        case tvArchive = "tv_archive"
        case directSource = "direct_source"
        case tvArchiveDuration = "tv_archive_duration"
    }
}

// MARK: - VoD Response Models
struct XtreamVoDResponse: Codable {
    let num: Int?
    let name: String
    let streamType: String?
    let streamId: Int?
    let streamIcon: String?
    let rating: String?
    let rating5based: Double?
    let added: String?
    let categoryId: String?
    let containerExtension: String?
    let plot: String?
    let cast: String?
    let director: String?
    let genre: String?
    let releaseDate: String?
    let duration: String?
    let cover: String?
    let backdrop: String?
    
    enum CodingKeys: String, CodingKey {
        case num
        case name
        case streamType = "stream_type"
        case streamId = "stream_id"
        case streamIcon = "stream_icon"
        case rating
        case rating5based = "rating_5based"
        case added
        case categoryId = "category_id"
        case containerExtension = "container_extension"
        case plot
        case cast
        case director
        case genre
        case releaseDate = "releasedate"
        case duration
        case cover
        case backdrop = "backdrop_path"
    }
}

// MARK: - Series Response Models
struct XtreamSeriesResponse: Codable {
    let num: Int?
    let name: String
    let seriesId: Int
    let cover: String?
    let plot: String?
    let cast: String?
    let director: String?
    let genre: String?
    let releaseDate: String?
    let rating: String?
    let rating5based: Double?
    let categoryId: String?
    let backdrop: String?
    
    enum CodingKeys: String, CodingKey {
        case num
        case name
        case seriesId = "series_id"
        case cover
        case plot
        case cast
        case director
        case genre
        case releaseDate = "releaseDate"
        case rating
        case rating5based = "rating_5based"
        case categoryId = "category_id"
        case backdrop = "backdrop_path"
    }
}

struct XtreamSeriesInfoResponse: Codable {
    let seasons: [XtreamSeasonResponse]
    let info: SeriesInfo
    
    struct SeriesInfo: Codable {
        let name: String
        let cover: String?
        let plot: String?
        let cast: String?
        let director: String?
        let genre: String?
        let releaseDate: String?
        let rating: String?
        let rating5based: Double?
        let backdrop: String?
        
        enum CodingKeys: String, CodingKey {
            case name
            case cover
            case plot
            case cast
            case director
            case genre
            case releaseDate = "releaseDate"
            case rating
            case rating5based = "rating_5based"
            case backdrop = "backdrop_path"
        }
    }
}

struct XtreamSeasonResponse: Codable {
    let seasonNumber: Int
    let name: String?
    let episodeCount: Int
    let cover: String?
    
    enum CodingKeys: String, CodingKey {
        case seasonNumber = "season_number"
        case name
        case episodeCount = "episode_count"
        case cover = "cover_big"
    }
}

struct XtreamEpisodeResponse: Codable {
    let id: String
    let episodeNum: Int
    let title: String
    let containerExtension: String
    let info: EpisodeInfoResponse?
    
    enum CodingKeys: String, CodingKey {
        case id
        case episodeNum = "episode_num"
        case title
        case containerExtension = "container_extension"
        case info
    }
    
    struct EpisodeInfoResponse: Codable {
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

// MARK: - Xtream Parser Error
enum XtreamParserError: Error {
    case invalidURL
    case invalidCredentials
    case networkError(Error)
    case decodingError(Error)
    case serverError(String)
}

// MARK: - Xtream Parser
class XtreamParser {
    
    private let networkManager = NetworkManager.shared
    
    /// Parses Xtream Codes API to get ALL content (Live TV, Movies, Series)
    func parse(serverURL: String, username: String, password: String) async throws -> [Channel] {
        async let liveChannels = parseLiveTV(serverURL: serverURL, username: username, password: password)
        async let movies = parseMovies(serverURL: serverURL, username: username, password: password)
        async let series = parseSeries(serverURL: serverURL, username: username, password: password)
        
        let allContent = try await [liveChannels, movies, series].flatMap { $0 }
        return allContent
    }
    
    /// Parses Xtream Codes API to get live TV channels only
    private func parseLiveTV(serverURL: String, username: String, password: String) async throws -> [Channel] {
        
        // 1. Build API URL for live channels
        guard var components = URLComponents(string: serverURL) else {
            throw XtreamParserError.invalidURL
        }
        
        // Remove trailing slash if exists
        var path = components.path
        if path.hasSuffix("/") {
            path.removeLast()
        }
        
        // Xtream API endpoint for live channels
        components.path = "\(path)/player_api.php"
        components.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "action", value: "get_live_streams")
        ]
        
        guard let apiURL = components.url else {
            throw XtreamParserError.invalidURL
        }
        
        print("XtreamParser: Fetching channels from \(apiURL.absoluteString)")
        
        // 2. Fetch data from API
        let data: Data
        do {
            data = try await networkManager.fetchData(from: apiURL)
        } catch {
            print("XtreamParser NETWORK ERROR: \(error.localizedDescription)")
            throw XtreamParserError.networkError(error)
        }
        
        // 3. Parse JSON response
        return try await Task.detached(priority: .userInitiated) {
            let decoder = JSONDecoder()
            
            let xtreamChannels: [XtreamChannelResponse]
            do {
                xtreamChannels = try decoder.decode([XtreamChannelResponse].self, from: data)
            } catch {
                print("XtreamParser DECODING ERROR: \(error.localizedDescription)")
                throw XtreamParserError.decodingError(error)
            }
            
            // 4. Convert Xtream channels to our Channel model
            var channels = [Channel]()
            
            for xtreamChannel in xtreamChannels {
                // Build stream URL: http://server:port/live/username/password/streamId.ext
                let streamURL = "\(serverURL)/live/\(username)/\(password)/\(xtreamChannel.streamId).ts"
                
                guard let url = URL(string: streamURL) else {
                    print("XtreamParser: Invalid URL for channel \(xtreamChannel.name)")
                    continue
                }
                
                // Create Channel instance
                let channel = Channel(
                    id: UUID(),
                    name: xtreamChannel.name,
                    url: url,
                    logo: URL(string: xtreamChannel.streamIcon ?? ""),
                    group: "Xtream Live TV", // Can be enhanced with category names
                    tvgId: xtreamChannel.epgChannelId ?? "",
                    isFavorite: false,
                    categoryIDs: []
                )
                
                channels.append(channel)
            }
            
            print("XtreamParser: Successfully parsed \(channels.count) live channels.")
            return channels
            
        }.value
    }
    
    /// Parses Xtream Codes API to get VoD (Movies)
    private func parseMovies(serverURL: String, username: String, password: String) async throws -> [Channel] {
        
        guard var components = URLComponents(string: serverURL) else {
            throw XtreamParserError.invalidURL
        }
        
        var path = components.path
        if path.hasSuffix("/") {
            path.removeLast()
        }
        
        components.path = "\(path)/player_api.php"
        components.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "action", value: "get_vod_streams")
        ]
        
        guard let apiURL = components.url else {
            throw XtreamParserError.invalidURL
        }
        
        print("XtreamParser: Fetching movies from \(apiURL.absoluteString)")
        
        let data: Data
        do {
            data = try await networkManager.fetchData(from: apiURL)
        } catch {
            print("XtreamParser MOVIE ERROR: \(error.localizedDescription)")
            return [] // Don't fail if movies not available
        }
        
        return try await Task.detached(priority: .userInitiated) {
            let decoder = JSONDecoder()
            
            let vodStreams: [XtreamVoDResponse]
            do {
                vodStreams = try decoder.decode([XtreamVoDResponse].self, from: data)
            } catch {
                print("XtreamParser MOVIE DECODING ERROR: \(error.localizedDescription)")
                return []
            }
            
            var movies = [Channel]()
            
            for vod in vodStreams {
                guard let streamId = vod.streamId else { continue }
                
                // Build stream URL: http://server:port/movie/username/password/streamId.ext
                let ext = vod.containerExtension ?? "mp4"
                let streamURL = "\(serverURL)/movie/\(username)/\(password)/\(streamId).\(ext)"
                
                guard let url = URL(string: streamURL) else { continue }
                
                let movie = Channel(
                    id: UUID(),
                    name: vod.name,
                    url: url,
                    logo: URL(string: vod.streamIcon ?? ""),
                    group: "Movies",
                    tvgId: "",
                    contentType: .movie,
                    streamId: streamId,
                    containerExtension: vod.containerExtension,
                    duration: vod.duration,
                    rating: vod.rating5based,
                    releaseDate: vod.releaseDate,
                    plot: vod.plot,
                    director: vod.director,
                    cast: vod.cast,
                    genre: vod.genre,
                    cover: URL(string: vod.cover ?? ""),
                    backdrop: URL(string: vod.backdrop ?? "")
                )
                
                movies.append(movie)
            }
            
            print("XtreamParser: Successfully parsed \(movies.count) movies.")
            return movies
            
        }.value
    }
    
    /// Parses Xtream Codes API to get Series
    private func parseSeries(serverURL: String, username: String, password: String) async throws -> [Channel] {
        
        guard var components = URLComponents(string: serverURL) else {
            throw XtreamParserError.invalidURL
        }
        
        var path = components.path
        if path.hasSuffix("/") {
            path.removeLast()
        }
        
        components.path = "\(path)/player_api.php"
        components.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "action", value: "get_series")
        ]
        
        guard let apiURL = components.url else {
            throw XtreamParserError.invalidURL
        }
        
        print("XtreamParser: Fetching series from \(apiURL.absoluteString)")
        
        let data: Data
        do {
            data = try await networkManager.fetchData(from: apiURL)
        } catch {
            print("XtreamParser SERIES ERROR: \(error.localizedDescription)")
            return [] // Don't fail if series not available
        }
        
        return try await Task.detached(priority: .userInitiated) {
            let decoder = JSONDecoder()
            
            let seriesList: [XtreamSeriesResponse]
            do {
                seriesList = try decoder.decode([XtreamSeriesResponse].self, from: data)
            } catch {
                print("XtreamParser SERIES DECODING ERROR: \(error.localizedDescription)")
                return []
            }
            
            var series = [Channel]()
            
            for show in seriesList {
                // For series, we need to fetch detailed info including episodes
                // This will be done when user selects the series
                
                // Create a placeholder URL (will be replaced with episode URLs)
                guard let dummyURL = URL(string: "\(serverURL)/series/\(username)/\(password)/\(show.seriesId)") else {
                    continue
                }
                
                let seriesChannel = Channel(
                    id: UUID(),
                    name: show.name,
                    url: dummyURL,
                    logo: URL(string: show.cover ?? ""),
                    group: "Series",
                    tvgId: "",
                    contentType: .series,
                    rating: show.rating5based,
                    releaseDate: show.releaseDate,
                    plot: show.plot,
                    director: show.director,
                    cast: show.cast,
                    genre: show.genre,
                    seriesId: show.seriesId,
                    cover: URL(string: show.cover ?? ""),
                    backdrop: URL(string: show.backdrop ?? "")
                )
                
                series.append(seriesChannel)
            }
            
            print("XtreamParser: Successfully parsed \(series.count) series.")
            return series
            
        }.value
    }
    
    /// Fetches detailed info for a specific series including all seasons and episodes
    func fetchSeriesInfo(serverURL: String, username: String, password: String, seriesId: Int) async throws -> [Season] {
        
        guard var components = URLComponents(string: serverURL) else {
            throw XtreamParserError.invalidURL
        }
        
        var path = components.path
        if path.hasSuffix("/") {
            path.removeLast()
        }
        
        components.path = "\(path)/player_api.php"
        components.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "action", value: "get_series_info"),
            URLQueryItem(name: "series_id", value: String(seriesId))
        ]
        
        guard let apiURL = components.url else {
            throw XtreamParserError.invalidURL
        }
        
        let data = try await networkManager.fetchData(from: apiURL)
        
        return try await Task.detached(priority: .userInitiated) {
            let decoder = JSONDecoder()
            let seriesInfo = try decoder.decode(XtreamSeriesInfoResponse.self, from: data)
            
            var seasons = [Season]()
            
            for seasonData in seriesInfo.seasons {
                // Fetch episodes for this season
                let episodesData = seasonData // Episodes are in season data
                
                var episodes = [Episode]()
                // In real implementation, episodes would be fetched from season data
                // For now, create placeholder
                
                let season = Season(
                    id: "\(seriesId)-\(seasonData.seasonNumber)",
                    seasonNumber: seasonData.seasonNumber,
                    name: seasonData.name ?? "Season \(seasonData.seasonNumber)",
                    episodes: episodes,
                    coverURL: URL(string: seasonData.cover ?? "")
                )
                
                seasons.append(season)
            }
            
            return seasons
        }.value
    }
}
