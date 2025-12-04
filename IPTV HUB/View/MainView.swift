import SwiftUI

private enum MainTab: Hashable, CaseIterable {
    case home, channels, vod, guide, categories, playlists, settings
}

struct MainView: View {
    
    // CRITICAL: Create ONE shared PlaylistManager instance
    @StateObject private var playlistManager = PlaylistManager()
    // ViewModel uses playlistManager from @EnvironmentObject injection
    @StateObject private var viewModel: MainViewModel
    
    @State private var hasLoadedInitialPlaylist = false
    @AppStorage("themeMode") private var themeModeString: String = "System"
    @AppStorage("showTVGuide") private var showTVGuide: Bool = true

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
        #else
        // iOS: Standard TabView
        TabView(selection: $selectedTab) {
            HomeView()
                .id(tabResetTokens[.home]!)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(MainTab.home)
            
            ChannelListView()
                .id(tabResetTokens[.channels]!)
                .tabItem { Label("TV", systemImage: "tv.fill") }
                .tag(MainTab.channels)
            
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

            CategoryManagerView()
                .id(tabResetTokens[.categories]!)
                .tabItem { Label("Categories", systemImage: "folder.fill") }
                .tag(MainTab.categories)
            
            SettingsView()
                .id(tabResetTokens[.playlists]!)
                .tabItem { Label("Playlists", systemImage: "rectangle.stack.fill") }
                .tag(MainTab.playlists)
            
            AppSettingsView()
                .id(tabResetTokens[.settings]!)
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(MainTab.settings)
        }
        .tint(Color(hex: "e94560"))
        .preferredColorScheme(colorScheme)
        .environmentObject(viewModel)
        .environmentObject(playlistManager)
        .environment(\.tabSearchResetToken, searchResetToken)
        .onAppear {
            loadInitialPlaylist()
            resetTab(selectedTab)
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
