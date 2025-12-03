import SwiftUI

struct SettingsView: View {
    
    @EnvironmentObject var playlistManager: PlaylistManager
    @EnvironmentObject var viewModel: MainViewModel
    @State private var showingAddSheet = false
    @State private var playlistToEdit: Playlist?
    @State private var playlistToDelete: Playlist?
    @State private var showDeleteConfirmation = false
    @State private var hasAutoRefreshed = false // Track if auto-refresh already happened
    @State private var isLoadingPlaylist = false // Local flag to prevent duplicate loads
    
    private var refreshAccent: Color {
        Color(red: 0.08, green: 0.28, blue: 0.62)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Modern gradient background - açık tonlar
                LinearGradient(
                    colors: [Color(red: 0.95, green: 0.95, blue: 0.97), Color(red: 0.98, green: 0.98, blue: 1.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                playlistList
                
                // Floating Add button - sağ alt köşede
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingAddSheet = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Add Playlist")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.91, green: 0.27, blue: 0.38), Color(red: 1.0, green: 0.42, blue: 0.42)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(25)
                            .shadow(color: Color(red: 0.91, green: 0.27, blue: 0.38).opacity(0.4), radius: 12, y: 6)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Playlists")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                    }
                    
                    // Top-left "Refresh" button
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: refreshAllPlaylists) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(refreshAccent)
                                .clipShape(Circle())
                        }
                        .disabled(viewModel.isLoading)
                        .opacity(viewModel.isLoading ? 0.6 : 1.0)
                    }
                }
                .sheet(isPresented: $showingAddSheet) { addSheetContent }
                .sheet(item: $playlistToEdit) { playlist in
                    editSheetContent(playlist: playlist)
                }
                .alert("Delete Playlist", isPresented: $showDeleteConfirmation, presenting: playlistToDelete) { playlist in
                    deleteConfirmationButtons(playlist: playlist)
                } message: { playlist in
                    Text("Are you sure you want to delete '\(playlist.name)'? This action cannot be undone.")
                }
                .overlay(emptyStateOverlay) // Overlay is separated
                .onAppear {
                    // Auto-refresh on first appearance (when playlist is first loaded)
                    autoRefreshOnFirstLoad()
                }
        }
    }
    
    // MARK: - Helper Subviews (Compiler Error Solution)

    /// Main list displaying saved playlists
    private var playlistList: some View {
        List {
            ForEach(playlistManager.playlists) { playlist in
                HStack(spacing: 10) {
                    // Playlist icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.91, green: 0.27, blue: 0.38), Color(red: 1.0, green: 0.42, blue: 0.42)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            #if os(tvOS)
                            .frame(width: 28, height: 28)
                            #else
                            .frame(width: 36, height: 36)
                            #endif
                        
                        Image(systemName: playlist.iconName ?? "rectangle.stack.fill")
                            #if os(tvOS)
                            .font(.system(size: 14))
                            #else
                            .font(.system(size: 16))
                            #endif
                            .foregroundColor(.white)
                    }
                    
                    // Playlist name with neon green on dark background
                    Button(action: {
                        loadThisPlaylist(playlist)
                    }) {
                        Text(playlist.name)
                            #if os(tvOS)
                            .font(.system(size: 16, weight: .semibold))
                            #else
                            .font(.system(size: 14, weight: .semibold))
                            #endif
                            .foregroundColor(Color(red: 0.2, green: 1.0, blue: 0.3)) // Neon green
                            .lineLimit(1)
                            #if os(tvOS)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            #else
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            #endif
                            .background(Color(red: 0.12, green: 0.12, blue: 0.18))
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        refreshPlaylist(playlist)
                    }) {
                        Image(systemName: "arrow.clockwise")
                            #if os(tvOS)
                            .font(.system(size: 20))
                            .frame(width: 36, height: 36)
                            #else
                            .font(.system(size: 16))
                            .frame(width: 30, height: 30)
                            #endif
                            .foregroundColor(.white)
                            .background(refreshAccent)
                            .clipShape(Circle())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    Spacer(minLength: 8)
                    
                    // Edit button
                    Button(action: {
                        playlistToEdit = playlist
                    }) {
                        Image(systemName: "pencil")
                            #if os(tvOS)
                            .font(.system(size: 12))
                            #else
                            .font(.system(size: 14))
                            #endif
                            .foregroundColor(Color(red: 0.31, green: 0.66, blue: 0.87))
                            #if os(tvOS)
                            .frame(width: 24, height: 24)
                            #else
                            .frame(width: 28, height: 28)
                            #endif
                            .background(Color(red: 0.31, green: 0.66, blue: 0.87).opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    // Delete button
                    Button(action: {
                        playlistToDelete = playlist
                        showDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            #if os(tvOS)
                            .font(.system(size: 12))
                            #else
                            .font(.system(size: 14))
                            #endif
                            .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42))
                            #if os(tvOS)
                            .frame(width: 24, height: 24)
                            #else
                            .frame(width: 28, height: 28)
                            #endif
                            .background(Color(red: 1.0, green: 0.42, blue: 0.42).opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(Color.white)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
            }
        }
        #if os(iOS)
        .scrollContentBackground(.hidden)
        #endif
        .background(Color.clear)
    }

    /// Warning shown if there are no playlists
    @ViewBuilder
    private var emptyStateOverlay: some View {
        // @ViewBuilder allows using 'if' inside an 'overlay'
        if playlistManager.playlists.isEmpty {
            // Solution for Error 2: Now we use our new, single EmptyStateView
            EmptyStateView(
                title: "No Playlists",
                message: "To get started, tap the (+) button at the top right to add an M3U playlist."
            )
        }
    }
    
    /// Sheet content shown when "+" button is tapped
    private var addSheetContent: some View {
        AddPlaylistView()
            .environmentObject(playlistManager)
    }
    
    /// Sheet content for editing a playlist
    private func editSheetContent(playlist: Playlist) -> some View {
        EditPlaylistView(playlist: playlist)
            .environmentObject(playlistManager)
    }
    
    /// Alert buttons for delete confirmation
    private func deleteConfirmationButtons(playlist: Playlist) -> some View {
        Group {
            Button("Cancel", role: .cancel) {
                playlistToDelete = nil
            }
            Button("Delete", role: .destructive) {
                deletePlaylist(playlist)
            }
        }
    }
    
    // MARK: - Actions

    private func loadThisPlaylist(_ playlist: Playlist) {
        // CRITICAL: Check local flag first (synchronous check)
        guard !isLoadingPlaylist else {
            print("⚠️ Already loading a playlist, ignoring duplicate request")
            return
        }
        
        // Also check viewModel state
        guard !viewModel.isLoading else {
            print("⚠️ ViewModel is loading, ignoring duplicate request")
            return
        }
        
        // Set local flag immediately
        isLoadingPlaylist = true
        
        print("🎯 SettingsView: loadThisPlaylist called for '\(playlist.name)'")
        
        Task {
            print("⏳ SettingsView: Starting Task to load playlist...")
            await viewModel.loadPlaylist(playlist, append: false)
            print("✅ SettingsView: Task completed")
            
            // Reset flag after completion
            await MainActor.run {
                isLoadingPlaylist = false
            }
        }
    }
    
    private func refreshPlaylist(_ playlist: Playlist) {
        loadThisPlaylist(playlist)
    }
    
    private func refreshAllPlaylists() {
        guard !isLoadingPlaylist else {
            print("⚠️ Already loading playlists, ignoring refresh request")
            return
        }
        guard !viewModel.isLoading else {
            print("⚠️ ViewModel is busy, ignoring refresh request")
            return
        }
        
        let playlists = playlistManager.playlists
        guard !playlists.isEmpty else {
            print("ℹ️ No playlists to refresh")
            return
        }
        
        isLoadingPlaylist = true
        
        Task {
            for playlist in playlists {
                await viewModel.loadPlaylist(playlist)
            }
            
            await MainActor.run {
                isLoadingPlaylist = false
            }
        }
    }
    
    private func autoRefreshOnFirstLoad() {
        // Only refresh once per app session
        guard !hasAutoRefreshed else { return }
        
        // Don't auto-refresh if already loading (local check first)
        guard !isLoadingPlaylist else { return }
        guard !viewModel.isLoading else { return }
        
        // Only if there's a last loaded playlist and channels are already loaded
        guard let lastLoadedURL = viewModel.lastLoadedM3U,
              let lastPlaylist = playlistManager.playlists.first(where: { $0.displayURL == lastLoadedURL }),
              !viewModel.channels.isEmpty else {
            return
        }
        
        // Mark as refreshed to prevent multiple calls
        hasAutoRefreshed = true
        isLoadingPlaylist = true
        
        print("🔄 Auto-refreshing playlist on first load: \(lastPlaylist.name)")
        
        Task {
            await viewModel.loadPlaylist(lastPlaylist)
            
            await MainActor.run {
                isLoadingPlaylist = false
            }
        }
    }
    
    private func deletePlaylist(_ playlist: Playlist) {
        if let index = playlistManager.playlists.firstIndex(where: { $0.id == playlist.id }) {
            // CRITICAL: Remove channels belonging to this playlist from viewModel
            viewModel.channels.removeAll { $0.playlistID == playlist.id }
            
            // Save updated channels to persistence
            playlistManager.saveChannels(viewModel.channels)
            
            // Delete playlist from manager
            playlistManager.deletePlaylist(at: IndexSet(integer: index))
            
            print("🗑️ Deleted playlist '\(playlist.name)' and its channels")
        }
        playlistToDelete = nil
    }
}
