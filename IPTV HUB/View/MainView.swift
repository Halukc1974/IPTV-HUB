import SwiftUI
import AVKit

private enum MainTab: Hashable, CaseIterable {
    case home, channels, vod, guide, categories, playlists, settings
}

struct MainView: View {
    
    // CRITICAL: Create ONE shared PlaylistManager instance
    @StateObject private var playlistManager = PlaylistManager()
    // ViewModel uses playlistManager from @EnvironmentObject injection
    @StateObject private var viewModel: MainViewModel
    @StateObject private var miniPlayerManager = MiniPlayerManager()
    
    @State private var hasLoadedInitialPlaylist = false
    @State private var showExpandedPlayer: Bool = false
    @AppStorage("themeMode") private var themeModeString: String = "System"
    @AppStorage("showTVGuide") private var showTVGuide: Bool = true
    @AppStorage("showHomeTab") private var showHomeTab: Bool = true
    @AppStorage("showTVTab") private var showTVTab: Bool = true
    @AppStorage("showCategoriesTab") private var showCategoriesTab: Bool = true
    @AppStorage("primaryVideoPlayer") private var primaryVideoPlayerRaw: String = VideoPlayerType.ksPlayer.rawValue

    @State private var selectedTab: MainTab = .home
#if os(iOS)
    @State private var tabResetTokens: [MainTab: UUID] = Dictionary(
        uniqueKeysWithValues: MainTab.allCases.map { ($0, UUID()) }
    )
#endif
    @State private var searchResetToken = UUID()
    
    private var colorScheme: ColorScheme? {
        switch themeModeString {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil // System
        }
    }
    
    private var primaryVideoPlayer: VideoPlayerType {
        VideoPlayerType(rawValue: primaryVideoPlayerRaw) ?? .ksPlayer
    }

    private var playerViewModelDelegate: AVPictureInPictureControllerDelegate? {
        viewModel.playerViewModelDelegate
    }
    
    // Custom initializer for proper StateObject setup
    init() {
        // CRITICAL FIX: Use a single PlaylistManager instance
        let sharedManager = PlaylistManager()
        _playlistManager = StateObject(wrappedValue: sharedManager)
        _viewModel = StateObject(wrappedValue: MainViewModel(playlistManager: sharedManager))
        
        #if os(tvOS)
        // Configure tvOS tab bar using UITabBarItem appearance for proper font sizing
        UITabBarItem.appearance().setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 18, weight: .medium)
        ], for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 20, weight: .semibold)
        ], for: .focused)
        UITabBarItem.appearance().setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 20, weight: .semibold)
        ], for: .selected)
        let tabBarAppearance = UITabBar.appearance()
        tabBarAppearance.itemWidth = 230
        tabBarAppearance.itemSpacing = 24
        #endif
    }
    
    var body: some View {
        #if os(tvOS)
        // tvOS: TabView with custom font sizes set via UIKit appearance
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(MainTab.home)
            
            ChannelListView()
                .tabItem {
                    Label("TV", systemImage: "tv.fill")
                }
                .tag(MainTab.channels)
            
            VoDContentView()
                .tabItem {
                    Label("VoD", systemImage: "film.fill")
                }
                .tag(MainTab.vod)
            
            if showTVGuide {
                EPGGridView()
                    .tabItem {
                        Label("Guide", systemImage: "list.bullet.rectangle")
                    }
                    .tag(MainTab.guide)
            }

            CategoryManagerView()
                .tabItem {
                    Label("Categories", systemImage: "folder.fill")
                }
                .tag(MainTab.categories)
            
            SettingsView()
                .tabItem {
                    Label("lists", systemImage: "rectangle.stack.fill")
                }
                .tag(MainTab.playlists)
            
            AppSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(MainTab.settings)
        }
        .preferredColorScheme(colorScheme)
        .environmentObject(viewModel)
        .environmentObject(playlistManager)
        .environment(\.tabSearchResetToken, searchResetToken)
        .onAppear {
            loadInitialPlaylist()
        }
        .onChange(of: selectedTab) { _ in
            bumpSearchResetToken()
        }
        .onChange(of: showTVGuide) { isVisible in
            if !isVisible && selectedTab == .guide {
                selectedTab = .home
            }
        }
        .onChange(of: showHomeTab) { isVisible in
            if !isVisible && selectedTab == .home {
                selectedTab = firstAvailableTab()
            }
        }
        .onChange(of: showTVTab) { isVisible in
            if !isVisible && selectedTab == .channels {
                selectedTab = firstAvailableTab()
            }
        }
        .onChange(of: showCategoriesTab) { isVisible in
            if !isVisible && selectedTab == .categories {
                selectedTab = firstAvailableTab()
            }
        }
        .onChange(of: showHomeTab) { isVisible in
            if !isVisible && selectedTab == .home {
                selectedTab = firstAvailableTab()
            }
        }
        .onChange(of: showTVTab) { isVisible in
            if !isVisible && selectedTab == .channels {
                selectedTab = firstAvailableTab()
            }
        }
        .onChange(of: showCategoriesTab) { isVisible in
            if !isVisible && selectedTab == .categories {
                selectedTab = firstAvailableTab()
            }
        }
        #else
        // iOS: Standard TabView with global mini player overlay
        ZStack {
            // Persistent PiP host keeps a playerLayer alive for native PiP.
            // We always instantiate the host with either the active player or a placeholder
            // to ensure the controller is available across the app lifecycle.
            PiPHostView(
                player: miniPlayerManager.currentPlayer ?? AVPlayer(),
                videoGravity: miniPlayerManager.videoGravity,
                pipController: $miniPlayerManager.pipController,
                delegate: viewModel.playerViewModelDelegate
            )
            .frame(width: 2, height: 2)

            TabView(selection: $selectedTab) {
                if showHomeTab {
                    HomeView()
                        .id(tabResetTokens[.home]!)
                        .tabItem { Label("Home", systemImage: "house.fill") }
                        .tag(MainTab.home)
                }
            
                if showTVTab {
                    ChannelListView()
                        .id(tabResetTokens[.channels]!)
                        .tabItem { Label("TV", systemImage: "tv.fill") }
                        .tag(MainTab.channels)
                }
            
            VoDContentView()
                .id(tabResetTokens[.vod]!)
                .tabItem { Label("VoD", systemImage: "film.fill") }
                .tag(MainTab.vod)
            
            if showTVGuide {
                EPGGridView()
                    .id(tabResetTokens[.guide]!)
                    .tabItem { Label("Guide", systemImage: "list.bullet.rectangle") }
                    .tag(MainTab.guide)
            }

                if showCategoriesTab {
                    CategoryManagerView()
                        .id(tabResetTokens[.categories]!)
                        .tabItem { Label("Categories", systemImage: "folder.fill") }
                        .tag(MainTab.categories)
                }
            
            SettingsView()
                .id(tabResetTokens[.playlists]!)
                .tabItem { Label("Playlists", systemImage: "rectangle.stack.fill") }
                .tag(MainTab.playlists)
            
            AppSettingsView()
                .id(tabResetTokens[.settings]!)
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(MainTab.settings)
            }
            if miniPlayerManager.isVisible {
                if let miniPlayer = miniPlayerManager.currentPlayer,
                   let channel = miniPlayerManager.currentChannel {
                    GlobalMiniPlayerOverlay(
                        player: miniPlayer,
                        channel: channel,
                        videoGravity: miniPlayerManager.videoGravity,
                        position: miniPlayerManager.position,
                        pipController: $miniPlayerManager.pipController,
                        onClose: { 
                            print("❌ Close button tapped")
                            miniPlayerManager.hide(stopPlayback: true)
                        },
                        onExpand: { 
                            print("📺 Expand button tapped")
                            // When expanding from the mini player, hide the mini (but keep playback)
                            miniPlayerManager.hide(stopPlayback: false)
                            // Then present the fullscreen player
                            showExpandedPlayer = true
                        },
                        onBackground: {
                            print("🌐 Background PiP button tapped")
                            // Manuel olarak native PiP'ye geç ve uygulamayı arka plana gönder
                            miniPlayerManager.switchToNativePiP(sendToBackground: true)
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(999)
                    .onAppear {
                        print("🎉 GlobalMiniPlayerOverlay appeared!")
                    }
                } else {
                    Color.clear
                        .onAppear {
                            print("⚠️ Mini player state invalid (visible with nil player/channel). Forcing hide.")
                            miniPlayerManager.hide(stopPlayback: true)
                        }
                }
            }
        }
        .fullScreenCover(isPresented: $showExpandedPlayer) {
            // Fullscreen player expanded from mini player
            if let channel = miniPlayerManager.currentChannel {
                iOSPlayerView(
                    initialChannel: channel,
                    channelCollection: nil,
                    playerType: primaryVideoPlayer,
                    existingPlayer: miniPlayerManager.currentPlayer
                )
                .environmentObject(viewModel)
                .environmentObject(playlistManager)
                .environmentObject(miniPlayerManager)
                // Do not auto-hide the mini on disappear — the fullscreen player can choose to show the mini itself.
            }
        }
        .tint(Color(hex: "e94560"))
        .preferredColorScheme(colorScheme)
        .environmentObject(viewModel)
        .environmentObject(playlistManager)
        .environmentObject(miniPlayerManager)
        .environment(\.tabSearchResetToken, searchResetToken)
        .onAppear {
            loadInitialPlaylist()
            resetTab(selectedTab)
            miniPlayerManager.setHomeHandler { selectedTab = .home }
        }
        .onChange(of: selectedTab) { newValue in
            resetTab(newValue)
            bumpSearchResetToken()
        }
        .onChange(of: showTVGuide) { isVisible in
            if !isVisible && selectedTab == .guide {
                selectedTab = .home
            }
        }
        #endif
    }
    
    private func loadInitialPlaylist() {
        // Prevent multiple loads
        guard !hasLoadedInitialPlaylist else { return }
        hasLoadedInitialPlaylist = true
        
        // Auto-load last playlist on app startup if channels are empty
        Task { @MainActor in
            // Check if channels are empty and get last playlist
            guard viewModel.channels.isEmpty else { return }
            
            // Get last playlist ID from UserDefaults
            guard let idString = UserDefaults.standard.string(forKey: "LastLoadedPlaylist"),
                  let uuid = UUID(uuidString: idString),
                  let lastPlaylist = playlistManager.playlists.first(where: { $0.id == uuid }) else {
                return
            }
            
            print("🚀 Auto-loading last playlist: \(lastPlaylist.name)")
            await viewModel.loadPlaylist(lastPlaylist)
        }
    }
}

#if os(iOS)
private extension MainView {
    func resetTab(_ tab: MainTab) {
        tabResetTokens[tab] = UUID()
    }
}
#endif

private extension MainView {
    func bumpSearchResetToken() {
        searchResetToken = UUID()
    }

    // Determine a sensible fallback tab when the current tab is hidden.
    func firstAvailableTab() -> MainTab {
        if showHomeTab { return .home }
        if showTVTab { return .channels }
        if showCategoriesTab { return .categories }
        // VoD is usually always present
        return .vod
    }
}

// MARK: - Environment Keys

private struct TabSearchResetTokenKey: EnvironmentKey {
    static var defaultValue = UUID()
}

extension EnvironmentValues {
    var tabSearchResetToken: UUID {
        get { self[TabSearchResetTokenKey.self] }
        set { self[TabSearchResetTokenKey.self] = newValue }
    }
}
