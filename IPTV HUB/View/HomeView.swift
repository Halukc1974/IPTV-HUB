//
//  HomeView.swift
//  Easy IPTV
//
//  Created by Haluk CELEBI on 16.11.2025.
//

import SwiftUI

struct HomeView: View {
    
    @EnvironmentObject var viewModel: MainViewModel
    @EnvironmentObject var playlistManager: PlaylistManager
    @Environment(\.tabSearchResetToken) private var tabSearchResetToken
    
    @State private var selectedChannel: Channel?
    @State private var searchText = ""
    @State private var selectedPlaylistID: UUID? = nil // nil means "All"
    @State private var cachedFilteredChannels: [Channel] = []
    
    @AppStorage("showRecentWatches") private var showRecentWatches: Bool = true
    @AppStorage("showPopularChannels") private var showPopularChannels: Bool = true
    @AppStorage("showOnlyMyCategories") private var showOnlyMyCategories: Bool = false
    
#if os(tvOS)
    private let horizontalCardSpacing: CGFloat = 48
#else
    private let horizontalCardSpacing: CGFloat = 15
#endif
    
    // Filtered channels based on selected playlist (memoized for performance)
    private var filteredChannelsByPlaylist: [Channel] {
        if let playlistID = selectedPlaylistID {
            // Filter channels by selected playlist
            return viewModel.channels.filter { channel in
                channel.playlistID == playlistID
            }
        } else {
            // Show all channels
            return viewModel.channels
        }
    }
    
    // Recent channels (last 10 watched) - optimized
    private var recentChannels: [Channel] {
        let recentIDs = UserDefaults.standard.stringArray(forKey: "recentChannelIDs") ?? []
        
        // Create lookup dictionaries for UUIDs and stable identifiers (survive playlist reloads)
        var channelLookup: [String: Channel] = [:]
        filteredChannelsByPlaylist.forEach { channel in
            channelLookup[channel.id.uuidString] = channel
            channelLookup[channel.recentIdentifier] = channel
        }
        
        let allRecent = recentIDs.compactMap { channelLookup[$0] }
        
        // Filter by search text
        if searchText.isEmpty {
            return allRecent
        } else {
            return allRecent.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // Grouped channels by category
    private var channelsByGroup: [String: [Channel]] {
        let allChannels = filteredChannelsByPlaylist
        
        // Filter by search text
        let filteredChannels = searchText.isEmpty ? allChannels : allChannels.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        
        return Dictionary(grouping: filteredChannels) { $0.group }
    }
    
    // Featured/Popular channels (first 10) - with action support
    private var featuredChannels: [Channel] {
        let allChannels = filteredChannelsByPlaylist
        
        // Filter by search text
        if searchText.isEmpty {
            return Array(allChannels.prefix(10))
        } else {
            // CRITICAL: Search sonuçları da tıklanabilir olmalı
            let filtered = allChannels.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            return Array(filtered.prefix(20)) // Search'te daha fazla sonuç göster
        }
    }
    
    // User categories
    private var userCategories: [ChannelCategory] {
        playlistManager.categories.sorted(by: { $0.order < $1.order })
    }
    
    var body: some View {
        ZStack {
            // Background - Daha açık, okunabilir tonlar
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.95, blue: 0.97), Color(red: 0.98, green: 0.98, blue: 1.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Sticky Header with Search (always visible)
                stickyHeaderSection
                
                // Scrollable content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 30) {
                        
                        // Recently Watched Channels (AT THE TOP - FIRST)
                        if showRecentWatches && !recentChannels.isEmpty {
                            continueWatchingSection
                                .padding(.horizontal, 20)
                        }
                        
                        // Featured/Popular Channels (AFTER RECENT)
                        if showPopularChannels && !featuredChannels.isEmpty {
                            featuredSection
                                .padding(.horizontal, 20)
                        }
                        
                        // User Categories
                        ForEach(userCategories) { category in
                            let allCategoryChannels = viewModel.getChannels(forCategory: category.id)
                            let categoryChannels = searchText.isEmpty ? allCategoryChannels : allCategoryChannels.filter {
                                $0.name.localizedCaseInsensitiveContains(searchText)
                            }
                            if !categoryChannels.isEmpty {
                                CategorySection(
                                    title: category.name,
                                    channels: categoryChannels,
                                    accentColor: Color(red: 1.0, green: 0.4, blue: 0.0),
                                    horizontalSpacing: horizontalCardSpacing,
                                    selectedChannel: $selectedChannel
                                )
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        // Channel Groups (only if NOT "Only My Categories" mode)
                        if !showOnlyMyCategories {
                            ForEach(channelsByGroup.keys.sorted(), id: \.self) { groupName in
                                if let channels = channelsByGroup[groupName], !channels.isEmpty {
                                    CategorySection(
                                        title: groupName,
                                        channels: channels,
                                        accentColor: Color(red: 0.2, green: 0.6, blue: 0.9),
                                        horizontalSpacing: horizontalCardSpacing,
                                        selectedChannel: $selectedChannel
                                    )
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.top, 20)
                }
            }
            
            // Loading overlay
            if viewModel.isLoading {
                loadingOverlay
            }
            
            // Empty state
            if viewModel.channels.isEmpty && !viewModel.isLoading {
                emptyStateView
            }
        }
        .fullScreenCover(item: $selectedChannel) { channel in
            PlayerView(initialChannel: channel)
                .environmentObject(viewModel)
                .environmentObject(playlistManager)
        }
        .onChange(of: viewModel.channels) { _ in
            // Update cached filtered channels when source changes
            updateFilteredChannels()
        }
        .onChange(of: selectedPlaylistID) { _ in
            // Update when playlist filter changes
            updateFilteredChannels()
        }
        .onChange(of: tabSearchResetToken) { _ in
            searchText = ""
        }
        .onAppear {
            // Initial cache
            updateFilteredChannels()
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateFilteredChannels() {
        if let playlistID = selectedPlaylistID {
            cachedFilteredChannels = viewModel.channels.filter { $0.playlistID == playlistID }
        } else {
            cachedFilteredChannels = viewModel.channels
        }
    }
    
    // MARK: - Sticky Header Section (Compact Single Line with Search)
    
    private var stickyHeaderSection: some View {
        HStack(spacing: 12) {
            // App title
            Text("Easy IPTV")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.2, green: 0.2, blue: 0.3), Color(red: 0.91, green: 0.27, blue: 0.38)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            // Search bar in the center
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                
                TextField("Search channels...", text: $searchText)
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.3))
                    .tint(Color(red: 0.91, green: 0.27, blue: 0.38))
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .keyboardType(.default)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
            .frame(maxWidth: .infinity)
            
            // Playlist Dropdown Menu
            Menu {
                // All playlists option
                Button(action: {
                    selectedPlaylistID = nil
                }) {
                    Label(selectedPlaylistID == nil ? "✓ All Playlists" : "All Playlists", systemImage: "rectangle.stack.fill")
                }
                
                Divider()
                
                // Individual playlists
                ForEach(playlistManager.playlists) { playlist in
                    Button(action: {
                        selectedPlaylistID = playlist.id
                    }) {
                        Label(
                            selectedPlaylistID == playlist.id ? "✓ \(playlist.name)" : playlist.name,
                            systemImage: playlist.iconName ?? "rectangle.stack"
                        )
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    if let selectedID = selectedPlaylistID,
                       let selectedPlaylist = playlistManager.playlists.first(where: { $0.id == selectedID }) {
                        Image(systemName: selectedPlaylist.iconName ?? "rectangle.stack.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(red: 0.91, green: 0.27, blue: 0.38))
                        Text(selectedPlaylist.name)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.4))
                    } else {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(red: 0.91, green: 0.27, blue: 0.38))
                        Text("All")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.4))
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white)
                .cornerRadius(15)
                .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.98, green: 0.98, blue: 1.0))
    }
    

    
    // MARK: - Continue Watching Section
    
    private var continueWatchingSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title3)
                    .foregroundColor(Color(red: 0.91, green: 0.27, blue: 0.38))
                
                Text("Recently Watched")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: horizontalCardSpacing) {
                    ForEach(recentChannels.prefix(10)) { channel in
                        RecentChannelCard(channel: channel) {
                            selectedChannel = channel
                        }
                    }
                }
            }
#if os(tvOS)
            .focusSection()
#endif
        }
    }
    
    // MARK: - Featured Section
    
    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Popular channels")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                
                Spacer()
#if !os(tvOS)
                Button(action: {}) {
                    Text("View all")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color(red: 0.91, green: 0.27, blue: 0.38))
                }
#endif
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: horizontalCardSpacing) {
                    ForEach(Array(featuredChannels.enumerated()), id: \.element.id) { index, channel in
                        FeaturedChannelCard(
                            channel: channel,
                            index: index + 1,
                            accentColor: Color(red: 0.91, green: 0.27, blue: 0.38)
                        ) {
                            selectedChannel = channel
                        }
                    }
                }
            }
#if os(tvOS)
            .focusSection()
#endif
        }
    }
    
    // MARK: - Loading & Empty States
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(Color(red: 0.91, green: 0.27, blue: 0.38))
                
                Text("Loading channels...")
                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.3))
                    .font(.headline)
            }
            .padding(40)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.15), radius: 20)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tv.and.mediabox")
                .font(.system(size: 60))
                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.7))
            
            Text("No playlists loaded")
                .font(.title2.bold())
                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.3))
            
            Text("Go to Playlists tab to add a playlist")
                .font(.subheadline)
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
        }
    }
}

// MARK: - Recent Channel Card (Logo Focus)

struct RecentChannelCard: View {
    let channel: Channel
    let action: () -> Void
    
    #if os(tvOS)
    @Environment(\.isFocused) var isFocused
    #endif
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Channel logo as main thumbnail
                ZStack {
                    SecureAsyncImage(url: channel.logo) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(10)
                    } placeholder: {
                        ZStack {
                            LinearGradient(
                                colors: [Color(red: 0.91, green: 0.27, blue: 0.38).opacity(0.8), Color(red: 1.0, green: 0.42, blue: 0.42).opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            Image(systemName: "tv.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    #if os(tvOS)
                    .frame(width: 250, height: 250)
                    #else
                    .frame(width: 120, height: 120)
                    #endif
                    .background(Color.white)
                    .cornerRadius(12)
                    .clipped()
                    
                    // Small play overlay
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Color(red: 0.91, green: 0.27, blue: 0.38))
                                #if os(tvOS)
                                .frame(width: 50, height: 50)
                                #else
                                .frame(width: 32, height: 32)
                                #endif
                                .overlay(
                                    Image(systemName: "play.fill")
                                        .foregroundColor(.white)
                                        #if os(tvOS)
                                        .font(.system(size: 20))
                                        #else
                                        .font(.system(size: 12))
                                        #endif
                                )
                                .shadow(color: Color.black.opacity(0.2), radius: 6)
                                .padding(8)
                        }
                    }
                }
                
                // Channel name
                Text(channel.name)
                    #if os(tvOS)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 250, height: 60, alignment: .top)
                    #else
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 120, height: 36, alignment: .top)
                    #endif
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
        .buttonStyle(PlainButtonStyle())
        #if os(tvOS)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .shadow(color: Color.black.opacity(isFocused ? 0.35 : 0.15), radius: isFocused ? 20 : 10, y: isFocused ? 14 : 6)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.18), value: isFocused)
        #endif
    }
}

// MARK: - Featured Channel Card (Compact Logo Style)

struct FeaturedChannelCard: View {
    let channel: Channel
    let index: Int
    let accentColor: Color
    let action: () -> Void
    
    #if os(tvOS)
    @Environment(\.isFocused) var isFocused
    #endif
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Channel logo as main thumbnail
                ZStack {
                    SecureAsyncImage(url: channel.logo) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(10)
                    } placeholder: {
                        ZStack {
                            LinearGradient(
                                colors: [accentColor.opacity(0.8), accentColor.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            Image(systemName: "tv.fill")
                                #if os(tvOS)
                                .font(.system(size: 60))
                                #else
                                .font(.system(size: 36))
                                #endif
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    #if os(tvOS)
                    .frame(width: 250, height: 250)
                    #else
                    .frame(width: 120, height: 120)
                    #endif
                    .background(Color.white)
                    .cornerRadius(12)
                    .clipped()
                    
                    // Ranking badge at top-left
                    VStack {
                        HStack {
                            Text("#\(index)")
                                #if os(tvOS)
                                .font(.system(size: 20, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                #else
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                #endif
                                .foregroundColor(.white)
                                .background(accentColor)
                                .cornerRadius(6)
                                .shadow(color: .black.opacity(0.2), radius: 4)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(8)
                }
                
                // Channel name
                Text(channel.name)
                    #if os(tvOS)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 250, height: 60, alignment: .top)
                    #else
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 120, height: 36, alignment: .top)
                    #endif
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
        .buttonStyle(PlainButtonStyle())
        #if os(tvOS)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .shadow(color: Color.black.opacity(isFocused ? 0.35 : 0.15), radius: isFocused ? 20 : 10, y: isFocused ? 14 : 6)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.18), value: isFocused)
        #endif
    }
}

// MARK: - Category Section

struct CategorySection: View {
    let title: String
    let channels: [Channel]
    let accentColor: Color
    let horizontalSpacing: CGFloat
    @Binding var selectedChannel: Channel?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                
                Spacer()
#if !os(tvOS)
                Button(action: {}) {
                    Text("View all")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(accentColor)
                }
#endif
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: horizontalSpacing) {
                    ForEach(channels.prefix(10)) { channel in
                        ChannelCard(channel: channel, accentColor: accentColor) {
                            selectedChannel = channel
                        }
                    }
                }
            }
#if os(tvOS)
            .focusSection()
#endif
        }
    }
}

// MARK: - Channel Card (Compact Logo Style)

struct ChannelCard: View {
    let channel: Channel
    let accentColor: Color
    let action: () -> Void
    
    #if os(tvOS)
    @Environment(\.isFocused) var isFocused
    #endif
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Channel logo as main thumbnail
                ZStack {
                    SecureAsyncImage(url: channel.logo) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(10)
                    } placeholder: {
                        ZStack {
                            LinearGradient(
                                colors: [accentColor.opacity(0.7), accentColor.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            Image(systemName: "tv.fill")
                                #if os(tvOS)
                                .font(.system(size: 60))
                                #else
                                .font(.system(size: 36))
                                #endif
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    #if os(tvOS)
                    .frame(width: 250, height: 250)
                    #else
                    .frame(width: 120, height: 120)
                    #endif
                    .background(Color.white)
                    .cornerRadius(12)
                    .clipped()
                }
                
                // Channel name
                Text(channel.name)
                    #if os(tvOS)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 250, height: 60, alignment: .top)
                    #else
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 120, height: 36, alignment: .top)
                    #endif
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
        .buttonStyle(PlainButtonStyle())
        #if os(tvOS)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .shadow(color: Color.black.opacity(isFocused ? 0.35 : 0.15), radius: isFocused ? 20 : 10, y: isFocused ? 14 : 6)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.18), value: isFocused)
        #endif
    }
}


