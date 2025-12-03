import Foundation
import Combine
import SwiftUI // Required for EnvironmentObject usage

@MainActor
class MainViewModel: ObservableObject {
    // MARK: - Published Variables
    @Published var channels: [Channel] = []
    @Published var epgData: [String: [EPGProgram]] = [:]
    @Published private(set) var liveTVChannelsCache: [Channel] = []
    @Published private(set) var groupedLiveChannelsCache: [String: [Channel]] = [:]
    @Published var serverChannels: [Channel] = []
    @Published var isLoadingServerLibraries = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastLoadedM3U: String?
    @Published var lastLoadedEPG: String?

    // MARK: - Services
    @Published var playlistManager: PlaylistManager
    private var savedChannelsCache: [Channel] = []
    private let m3uParser = M3UParser()
    private let xtreamParser = XtreamParser()
    private let stremioParser = StremioParser()
    private let serverLibraryService = ServerLibraryService()
    private let epgParser = EPGParser()
    private let tmdbService = TMDbService()
    private let networkManager = NetworkManager.shared
    private var serverLibraryTask: Task<Void, Never>?

    deinit {
        serverLibraryTask?.cancel()
    }

    init(playlistManager: PlaylistManager) {
        self.playlistManager = playlistManager

        let playlistSnapshot = playlistManager.playlists
        let lastPlaylist = playlistManager.getLastPlaylist()

        Task(priority: .utility) { [weak self, playlistManager, playlistSnapshot, lastPlaylist] in
            guard let self else { return }
            var savedChannels = await playlistManager.loadChannels()
            guard !savedChannels.isEmpty else { return }

            let validPlaylistIDs = Set(playlistSnapshot.map { $0.id })

            if let lastPlaylist {
                let missingPlaylist = savedChannels.filter { $0.playlistID == nil }
                if !missingPlaylist.isEmpty {
                    print("🔧 Fixing \(missingPlaylist.count) channels without playlistID")
                    savedChannels = savedChannels.map { channel in
                        var updatedChannel = channel
                        if updatedChannel.playlistID == nil {
                            updatedChannel.playlistID = lastPlaylist.id
                        }
                        return updatedChannel
                    }
                }
            }

            let orphaned = savedChannels.filter { channel in
                if let pid = channel.playlistID {
                    return !validPlaylistIDs.contains(pid)
                }
                return false
            }
            if !orphaned.isEmpty {
                savedChannels = savedChannels.filter { channel in
                    guard let pid = channel.playlistID else { return true }
                    return validPlaylistIDs.contains(pid)
                }
                print("🧹 Removed \(orphaned.count) orphaned channels")
                playlistManager.saveChannels(savedChannels)
            }

            let stats = savedChannels.reduce(into: (withCategories: 0, withPlaylistID: 0, playlistIDs: Set<UUID>())) { result, channel in
                if !channel.categoryIDs.isEmpty { result.withCategories += 1 }
                if let pid = channel.playlistID {
                    result.withPlaylistID += 1
                    result.playlistIDs.insert(pid)
                }
            }

            await MainActor.run {
                self.channels = savedChannels
                self.savedChannelsCache = savedChannels
                self.rebuildLiveChannelCaches()
                self.lastLoadedM3U = lastPlaylist?.displayURL
                self.lastLoadedEPG = lastPlaylist?.epgURL
                print("✅ Loaded \(savedChannels.count) channels from storage")
                print("📂 Stats: \(stats.withCategories) with categories, \(stats.withPlaylistID) with playlistID, \(stats.playlistIDs.count) unique playlists")
                if let lastPlaylist {
                    print("✅ Restored last playlist: \(lastPlaylist.name) (ID: \(lastPlaylist.id))")
                }
            }
        }
    }
    
    // MARK: - Category / Bouquet Functions
    
    /// Adds or removes channel membership to a category after channels are loaded
    @discardableResult
    func toggleChannel(_ channel: Channel, inCategory category: ChannelCategory) -> Channel? {
        // Find the current index of the channel
        guard let index = channels.firstIndex(where: { $0.id == channel.id }) else { return nil }
        
        var updatedChannel = channels[index]
        let categoryId = category.id
        
        // Toggle membership
        if updatedChannel.categoryIDs.contains(categoryId) {
            updatedChannel.categoryIDs.remove(categoryId) // Remove
        } else {
            updatedChannel.categoryIDs.insert(categoryId) // Add
        }
        
        // Update the channel in the list (ensures ChannelListView updates DisclosureGroups)
        channels[index] = updatedChannel
        rebuildLiveChannelCaches()
        
        // Save changes to disk
        playlistManager.updateCategoryMembership(
            categoryId: categoryId,
            stableID: updatedChannel.recentIdentifier,
            isMember: updatedChannel.categoryIDs.contains(categoryId)
        )
        playlistManager.saveChannels(channels)
        savedChannelsCache = channels
        print("✅ Channel category membership saved for: \(channel.name)")

        return updatedChannel
    }
    
    /// Returns channels for a specific category (used in Sidebar)
    func getChannels(forCategory categoryId: String) -> [Channel] {
        return channels.filter { $0.categoryIDs.contains(categoryId) }
    }

    // MARK: - Main Data Loading
    
    /// Load playlist based on its type
    func loadPlaylist(_ playlist: Playlist, append: Bool = false) async {
        print("🔄 Loading playlist: \(playlist.name)")
        isLoading = true
        errorMessage = nil
        let existingChannelsSnapshot = channels
        
        if !append {
            channels.removeAll { $0.playlistID == playlist.id }
            rebuildLiveChannelCaches()
        }
        
        do {
            let parsedChannels: [Channel]
            switch playlist.type {
            case .m3u8:
                parsedChannels = try await loadM3U8Playlist(playlist)
            case .xtream:
                parsedChannels = try await loadXtreamPlaylist(playlist)
            case .stremio:
                parsedChannels = try await loadStremioPlaylist(playlist)
            }
            
            let channelsWithPlaylistID = parsedChannels.map { channel in
                var updated = channel
                updated.playlistID = playlist.id
                return updated
            }
            
            let newChannelsWithCategories = await applyCategoryMembership(
                to: channelsWithPlaylistID,
                savedSnapshot: existingChannelsSnapshot
            )
            
            channels.append(contentsOf: newChannelsWithCategories)
            savedChannelsCache = channels
            rebuildLiveChannelCaches()
            
            print("✅ Loaded \(newChannelsWithCategories.count) channels (Total: \(channels.count))")
            lastLoadedM3U = playlist.displayURL
            lastLoadedEPG = playlist.epgURL
            
            Task.detached(priority: .utility) { [channels = self.channels, playlistID = playlist.id, playlistManager = self.playlistManager] in
                await Task.yield()
                playlistManager.saveChannels(channels)
                playlistManager.saveLastPlaylist(playlistID)
            }
        } catch {
            errorMessage = "Failed to load playlist: \(error.localizedDescription)"
            print("❌ Error loading playlist: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Legacy method for backwards compatibility
    func loadAllData(m3uURLString: String, epgURLString: String) async {
        let playlist = Playlist(
            id: UUID(),
            name: "Legacy Playlist",
            type: .m3u8,
            iconName: nil,
            m3uURL: m3uURLString,
            epgURL: epgURLString,
            xtreamServerURL: nil,
            xtreamUsername: nil,
            xtreamPassword: nil,
            stremioAddonURL: nil
        )
        await loadPlaylist(playlist)
    }

    // MARK: - Type-Specific Loaders
    private func loadM3U8Playlist(_ playlist: Playlist) async throws -> [Channel] {
        guard let m3uURLString = playlist.m3uURL,
              let m3uURL = URL(string: m3uURLString) else {
            throw NSError(domain: "MainViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid M3U URL"])
        }

        let channels = try await m3uParser.parse(url: m3uURL)

        if let epgURLString = playlist.epgURL,
           !epgURLString.isEmpty,
           let epgURL = URL(string: epgURLString) {
            Task {
                do {
                    let epgData = try await networkManager.fetchData(from: epgURL)
                    let programs = await epgParser.parseAsync(data: epgData)
                    await MainActor.run {
                        self.epgData = Dictionary(grouping: programs, by: { $0.channelID })
                    }
                } catch {
                    print("EPG loading failed: \(error.localizedDescription)")
                }
            }
        }

        return channels
    }

    private func loadXtreamPlaylist(_ playlist: Playlist) async throws -> [Channel] {
        guard let serverURL = playlist.xtreamServerURL,
              let username = playlist.xtreamUsername,
              let password = playlist.xtreamPassword else {
            throw NSError(domain: "MainViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid Xtream credentials"])
        }

        return try await xtreamParser.parse(
            serverURL: serverURL,
            username: username,
            password: password
        )
    }

    private func loadStremioPlaylist(_ playlist: Playlist) async throws -> [Channel] {
        guard let addonURL = playlist.stremioAddonURL else {
            throw NSError(domain: "MainViewModel", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid Stremio add-on URL"])
        }

        return try await stremioParser.parse(addonURL: addonURL)
    }
    
    /// Applies persistent category memberships to newly loaded channels
    private func applyCategoryMembership(to channels: [Channel], savedSnapshot: [Channel]) async -> [Channel] {
        // Reuse in-memory snapshot when available; fall back to cached copy or disk.
        let savedChannels: [Channel]
        if !savedSnapshot.isEmpty {
            savedChannels = savedSnapshot
            savedChannelsCache = savedSnapshot
        } else if !savedChannelsCache.isEmpty {
            savedChannels = savedChannelsCache
        } else {
            let manager = playlistManager
            let diskChannels = await Task.detached(priority: .utility) { () async -> [Channel] in
                await manager.loadChannels()
            }.value
            savedChannels = diskChannels
            savedChannelsCache = diskChannels
        }
        var savedChannelDict: [UUID: Channel] = [:]
        var savedByStableID: [String: Channel] = [:]
        for channel in savedChannels {
            // Preserve the first occurrence to keep the most recently saved metadata
            if savedChannelDict[channel.id] == nil {
                savedChannelDict[channel.id] = channel
            }
            let stableKey = channel.recentIdentifier
            if savedByStableID[stableKey] == nil {
                savedByStableID[stableKey] = channel
            }
        }
        
        return channels.map { channel in
            var updatedChannel = channel
            // CRITICAL: Save the newly assigned playlistID first!
            let newPlaylistID = channel.playlistID
            
            // If this channel was saved before, restore ONLY its category memberships
            if let savedChannel = savedByStableID[channel.recentIdentifier] ?? savedChannelDict[channel.id] {
                updatedChannel.categoryIDs = savedChannel.categoryIDs
                // CRITICAL: Restore the new playlistID (don't let it be overwritten)
                updatedChannel.playlistID = newPlaylistID
                updatedChannel.isFavorite = savedChannel.isFavorite
            }
            
            return updatedChannel
        }
        .applyingCategoryMemberships(from: playlistManager.categoryMemberships)
    }
    
    /// Fetches metadata from TMDb
    func getMetadata(for programTitle: String) async -> TMDbResult? {
        do {
            return try await tmdbService.fetchMetadata(for: programTitle)
        } catch {
            print("TMDb Error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Server Library Loading (Emby / Plex)
    func refreshServerLibraries(embyURL: String, embyToken: String, plexURL: String, plexToken: String) {
        let trimmedEmbyURL = embyURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmbyToken = embyToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlexURL = plexURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlexToken = plexToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let embyConfig = ServerConnectionConfig.make(urlString: trimmedEmbyURL, token: trimmedEmbyToken)
        let plexConfig = ServerConnectionConfig.make(urlString: trimmedPlexURL, token: trimmedPlexToken)
        if embyConfig == nil && plexConfig == nil {
            serverLibraryTask?.cancel()
            serverChannels = []
            isLoadingServerLibraries = false
            return
        }
        isLoadingServerLibraries = true
        serverLibraryTask?.cancel()
        serverLibraryTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let channels = await self.serverLibraryService.fetchLibraries(emby: embyConfig, plex: plexConfig)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.serverChannels = channels
                self.isLoadingServerLibraries = false
            }
        }
    }

    private func rebuildLiveChannelCaches() {
        let liveChannels = channels.filter { $0.contentType == .liveTV }
        liveTVChannelsCache = liveChannels
        groupedLiveChannelsCache = Dictionary(grouping: liveChannels) { $0.group }
    }
}

private extension Array where Element == Channel {
    func applyingCategoryMemberships(from memberships: [String: Set<String>]) -> [Channel] {
        guard !memberships.isEmpty else { return self }
        var updated = self
        var stableLookup: [String: Int] = [:]
        for (index, channel) in updated.enumerated() {
            stableLookup[channel.recentIdentifier] = index
        }
        for (categoryId, stableIDs) in memberships {
            for stableID in stableIDs {
                if let index = stableLookup[stableID] {
                    updated[index].categoryIDs.insert(categoryId)
                }
            }
        }
        return updated
    }
}
