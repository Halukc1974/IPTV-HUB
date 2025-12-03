//
//  PlaylistManager.swift
//  Easy IPTV
//
//  Created by Haluk CELEBI on 15.11.2025.
//

import Foundation
import Combine

// FIX: ChannelCategory definition removed from here.
// It must only be defined inside Model/Channel.swift.

@MainActor
class PlaylistManager: ObservableObject {
    
    @Published var playlists: [Playlist] = []
    
    // Created Category List
    @Published var categories: [ChannelCategory] = []
    @Published private(set) var categoryMemberships: [String: Set<String>] = [:]
    
    // Persistence keys as nonisolated constants (no main thread needed)
    private nonisolated static let playlistsKey = "SavedPlaylists"
    private nonisolated static let categoriesKey = "UserCategories"
    private nonisolated static let categoryMembershipsKey = "CategoryChannelMemberships"
    private nonisolated static let lastPlaylistKey = "LastLoadedPlaylist"
    
    // CRITICAL: File-based storage for large channel lists
    private nonisolated static func channelsFileURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("channels.json")
    }
    
    init() {
        // Migrate old UserDefaults channel data to file (one-time migration)
        migrateChannelsToFile()
        
        // Load saved playlists and categories when the app starts
        loadData()
    }
    
    // MARK: - Migration
    
    private func migrateChannelsToFile() {
        // Check if old UserDefaults data exists
        let oldKey = "SavedChannels"
        guard let oldData = UserDefaults.standard.data(forKey: oldKey) else {
            return // No migration needed
        }
        
        print("🔄 Migrating channels from UserDefaults to file...")
        
        // Write to file
        do {
            let fileURL = Self.channelsFileURL()
            try oldData.write(to: fileURL, options: .atomic)
            
            // Clear old UserDefaults data to free up space
            UserDefaults.standard.removeObject(forKey: oldKey)
            
            print("✅ Migration complete: \(oldData.count) bytes moved to file")
        } catch {
            print("❌ Migration failed: \(error)")
        }
    }
    
    // MARK: - Saving and Loading (Unified)
    
    func loadData() {
        loadPlaylists()
        loadCategories() // Load the new categories as well
        loadCategoryMemberships()
    }
    
    func saveData() {
        savePlaylists()
        saveCategories() // Save the new categories as well
        saveCategoryMemberships()
    }
    
    // MARK: - Channel Persistence
    
    nonisolated func saveChannels(_ channels: [Channel]) {
        ChannelSaveCoordinator.pendingChannelSave?.cancel()
        let workItem = DispatchWorkItem {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(channels)
                let fileURL = Self.channelsFileURL()
                try data.write(to: fileURL, options: .atomic)
                print("PlaylistManager: \(channels.count) channels saved to file (\(data.count) bytes)")
            } catch {
                print("PlaylistManager: Failed to save channels: \(error)")
            }
        }
        ChannelSaveCoordinator.pendingChannelSave = workItem
        workItem.notify(queue: ChannelSaveCoordinator.queue) {
            if ChannelSaveCoordinator.pendingChannelSave === workItem {
                ChannelSaveCoordinator.pendingChannelSave = nil
            }
        }
        ChannelSaveCoordinator.queue.asyncAfter(deadline: .now() + 0.4, execute: workItem)
    }
    
    nonisolated func loadChannels() async -> [Channel] {
        await Task.detached(priority: .utility) {
            let fileURL = Self.channelsFileURL()
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("PlaylistManager: No saved channels file found.")
                return [] as [Channel]
            }
            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                let channels = try decoder.decode([Channel].self, from: data)
                print("PlaylistManager: \(channels.count) channels loaded from file (\(data.count) bytes)")
                return channels
            } catch {
                print("PlaylistManager: Failed to load channels: \(error)")
                return [] as [Channel]
            }
        }.value
    }
    
    nonisolated func saveLastPlaylist(_ playlistId: UUID) {
        UserDefaults.standard.set(playlistId.uuidString, forKey: Self.lastPlaylistKey)
        print("PlaylistManager: Last playlist ID saved: \(playlistId)")
    }
    
    func getLastPlaylist() -> Playlist? {
        guard let idString = UserDefaults.standard.string(forKey: Self.lastPlaylistKey),
              let uuid = UUID(uuidString: idString) else {
            return nil
        }
        return playlists.first(where: { $0.id == uuid })
    }
    
    private func loadPlaylists() {
        guard let data = UserDefaults.standard.data(forKey: Self.playlistsKey) else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            self.playlists = try decoder.decode([Playlist].self, from: data)
            print("PlaylistManager: \(playlists.count) playlists successfully loaded.")
        } catch {
            print("PlaylistManager: Failed to load playlists (decode error): \(error)")
        }
    }
    
    private func savePlaylists() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(playlists)
            UserDefaults.standard.set(data, forKey: Self.playlistsKey)
            print("PlaylistManager: Playlists successfully saved.")
        } catch {
            print("PlaylistManager: Failed to save playlists (encode error): \(error)")
        }
    }
    
    // MARK: - Category Persistence Methods
    
    private func loadCategories() {
        if let savedCategories = UserDefaults.standard.data(forKey: Self.categoriesKey) {
            if let decodedCategories = try? JSONDecoder().decode([ChannelCategory].self, from: savedCategories) {
                // Sort categories by their order value
                self.categories = decodedCategories.sorted(by: { $0.order < $1.order })
                print("PlaylistManager: \(categories.count) categories successfully loaded.")
                return
            }
        }
        self.categories = [] // Default empty list
    }
    
    func saveCategories() {
        // Update order before saving
        
        // WARNING FIX: 'category' variable was unused; using only index
        for index in categories.indices {
            categories[index].order = index // Update ordering based on index
        }
        
        if let encoded = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(encoded, forKey: Self.categoriesKey)
            print("PlaylistManager: Categories successfully saved.")
        }
    }

    private func loadCategoryMemberships() {
        guard let data = UserDefaults.standard.data(forKey: Self.categoryMembershipsKey) else {
            categoryMemberships = [:]
            return
        }
        do {
            let decoded = try JSONDecoder().decode([String: [String]].self, from: data)
            categoryMemberships = decoded.mapValues { Set($0) }
            print("PlaylistManager: Category memberships loaded (\(categoryMemberships.count) categories)")
        } catch {
            print("PlaylistManager: Failed to load category memberships: \(error)")
            categoryMemberships = [:]
        }
    }
    
    func saveCategoryMemberships() {
        let encodable = categoryMemberships.mapValues { Array($0) }
        if let data = try? JSONEncoder().encode(encodable) {
            UserDefaults.standard.set(data, forKey: Self.categoryMembershipsKey)
            print("PlaylistManager: Category memberships saved.")
        }
    }
    
    func updateCategoryMembership(categoryId: String, stableID: String, isMember: Bool) {
        var set = categoryMemberships[categoryId] ?? Set<String>()
        if isMember {
            set.insert(stableID)
        } else {
            set.remove(stableID)
        }
        categoryMemberships[categoryId] = set
        saveCategoryMemberships()
    }
    
    func removeMemberships(for categoryId: String) {
        categoryMemberships[categoryId] = nil
        saveCategoryMemberships()
    }
    
    // MARK: - Category Operations (CRUD)
    
    func addCategory(name: String) -> ChannelCategory {
        // Uses ChannelCategory initializer from Model file
        let newCategory = ChannelCategory(name: name, order: categories.count)
        categories.append(newCategory)
        saveCategories()
        return newCategory
    }
    
    func deleteCategory(id: String) {
        // Remove category from list
        categories.removeAll { $0.id == id }
        categoryMemberships[id] = nil
        saveCategoryMemberships()
        // NOTE: MainViewModel must clear CategoryIDs from channels impacted by deletion.
        
        saveCategories()
    }
    
    func updateCategory(category: ChannelCategory, newName: String) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index].name = newName
            saveCategories()
        }
    }

    // MARK: - Playlist Operations (CRUD)
    
    func addPlaylist(_ playlist: Playlist) {
        playlists.append(playlist)
        saveData() // Save everything (including categories)
    }
    
    func deletePlaylist(at offsets: IndexSet) {
        playlists.remove(atOffsets: offsets)
        saveData()
    }
    
    func updatePlaylist(_ updatedPlaylist: Playlist) {
        if let index = playlists.firstIndex(where: { $0.id == updatedPlaylist.id }) {
            playlists[index] = updatedPlaylist
            saveData()
        }
    }
    
    // Legacy method for backwards compatibility
    func addPlaylist(name: String, m3uURL: String, epgURL: String) {
        let newPlaylist = Playlist(
            id: UUID(),
            name: name,
            type: .m3u8,
            iconName: "rectangle.stack.fill",
            m3uURL: m3uURL,
            epgURL: epgURL,
            xtreamServerURL: nil,
            xtreamUsername: nil,
            xtreamPassword: nil,
            stremioAddonURL: nil
        )
        addPlaylist(newPlaylist)
    }
}

private enum ChannelSaveCoordinator {
    static let queue = DispatchQueue(label: "com.easyiptv.channels.save", qos: .utility)
    static var pendingChannelSave: DispatchWorkItem?
}
