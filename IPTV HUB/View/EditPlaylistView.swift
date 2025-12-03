//
//  EditPlaylistView.swift
//  Easy IPTV
//
//  Created by Haluk CELEBI on 16.11.2025.
//


//
//  EditPlaylistView.swift
//  Easy IPTV
//
//  Created by Haluk CELEBI on 16.11.2025.
//

import SwiftUI

struct EditPlaylistView: View {
    // To dismiss this view
    @Environment(\.dismiss) var dismiss
    
    // Access to the service managing playlists
    @EnvironmentObject var playlistManager: PlaylistManager
    
    // The playlist to edit
    let playlist: Playlist
    
    // Playlist type (cannot be changed)
    @State private var selectedType: PlaylistType
    
    // Common fields
    @State private var name: String
    @State private var selectedIcon: String
    
    // M3U8 fields
    @State private var m3uURL: String
    @State private var epgURL: String
    
    // Xtream fields
    @State private var xtreamServerURL: String
    @State private var xtreamUsername: String
    @State private var xtreamPassword: String
    
    // Stremio fields
    @State private var stremioAddonURL: String
    
    // Icon options for each type
    private let m3u8Icons = ["rectangle.stack.fill", "antenna.radiowaves.left.and.right", "tv.fill", "clock.fill", "link", "camera.fill", "cloud.fill", "desktopcomputer", "server.rack"]
    private let xtreamIcons = ["film.fill", "person.2.fill", "crown.fill", "tag.fill", "circle.fill", "moon.fill", "globe", "gamecontroller.fill", "house.fill"]
    private let stremioIcons = ["play.rectangle.fill", "triangle.fill", "soccerball", "cube.fill", "gift.fill", "circle.fill", "gift.fill", "circle.fill", "star.fill"]
    
    private var currentIcons: [String] {
        switch selectedType {
        case .m3u8: return m3u8Icons
        case .xtream: return xtreamIcons
        case .stremio: return stremioIcons
        }
    }
    
    init(playlist: Playlist) {
        self.playlist = playlist
        _selectedType = State(initialValue: playlist.type)
        _name = State(initialValue: playlist.name)
        _selectedIcon = State(initialValue: playlist.iconName ?? "rectangle.stack.fill")
        
        // M3U8 fields
        _m3uURL = State(initialValue: playlist.m3uURL ?? "")
        _epgURL = State(initialValue: playlist.epgURL ?? "")
        
        // Xtream fields
        _xtreamServerURL = State(initialValue: playlist.xtreamServerURL ?? "")
        _xtreamUsername = State(initialValue: playlist.xtreamUsername ?? "")
        _xtreamPassword = State(initialValue: playlist.xtreamPassword ?? "")
        
        // Stremio fields
        _stremioAddonURL = State(initialValue: playlist.stremioAddonURL ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Type Display (Read-only)
                Section(header: Text("PLAYLIST TYPE")) {
                    HStack {
                        Text(selectedType.rawValue)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "lock.fill")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                }
                
                // Name Section
                Section(header: Text("NAME THIS PLAYLIST")) {
                    TextField("i.e. My playlist", text: $name)
                }
                
                // Icon Selection
                Section(header: Text("IDENTIFY WITH AN ICON")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(currentIcons, id: \.self) { icon in
                                Button(action: {
                                    selectedIcon = icon
                                }) {
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .frame(width: 50, height: 50)
                                        .background(selectedIcon == icon ? Color.orange : Color.gray.opacity(0.2))
                                        .foregroundColor(selectedIcon == icon ? .white : .primary)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Type-specific fields
                switch selectedType {
                case .m3u8:
                    m3u8Section
                case .xtream:
                    xtreamSection
                case .stremio:
                    stremioSection
                }
            }
            .navigationTitle("Edit Playlist")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                // Cancel Button
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                // Save Button
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAndDismiss()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }
    
    // MARK: - Type-Specific Sections
    
    private var m3u8Section: some View {
        Group {
            Section(header: Text("URL TO YOUR M3U8 FILE")) {
                TextField("i.e. http://your-domain:port/path/file", text: $m3uURL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            Section(header: Text("URL TO YOUR EPG FILE")) {
                TextField("i.e. http://your-domain/epg.xml (optional)", text: $epgURL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
        }
    }
    
    private var xtreamSection: some View {
        Group {
            Section(header: Text("URL TO XTREAM SERVER")) {
                TextField("i.e. http://your-domain:port/path/file", text: $xtreamServerURL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            Section(header: Text("YOUR USERNAME")) {
                TextField("i.e. my-username", text: $xtreamUsername)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            Section(header: Text("YOUR PASSWORD")) {
                SecureField("i.e. my-passw0rd", text: $xtreamPassword)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
        }
    }
    
    private var stremioSection: some View {
        Section(header: Text("STREMIO ADD-ON URL")) {
            TextField("i.e. http://add-on.stremio.com", text: $stremioAddonURL)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
    }
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        guard !name.isEmpty else { return false }
        
        switch selectedType {
        case .m3u8:
            return !m3uURL.isEmpty
        case .xtream:
            return !xtreamServerURL.isEmpty && !xtreamUsername.isEmpty && !xtreamPassword.isEmpty
        case .stremio:
            return !stremioAddonURL.isEmpty
        }
    }
    
    // MARK: - Save
    
    private func saveAndDismiss() {
        var updatedPlaylist = Playlist(
            id: playlist.id, // Keep the same ID
            name: name,
            type: selectedType,
            iconName: selectedIcon,
            m3uURL: nil,
            epgURL: nil,
            xtreamServerURL: nil,
            xtreamUsername: nil,
            xtreamPassword: nil,
            stremioAddonURL: nil
        )
        
        switch selectedType {
        case .m3u8:
            updatedPlaylist.m3uURL = m3uURL
            updatedPlaylist.epgURL = epgURL.isEmpty ? nil : epgURL
        case .xtream:
            updatedPlaylist.xtreamServerURL = xtreamServerURL
            updatedPlaylist.xtreamUsername = xtreamUsername
            updatedPlaylist.xtreamPassword = xtreamPassword
        case .stremio:
            updatedPlaylist.stremioAddonURL = stremioAddonURL
        }
        
        playlistManager.updatePlaylist(updatedPlaylist)
        dismiss()
    }
}
