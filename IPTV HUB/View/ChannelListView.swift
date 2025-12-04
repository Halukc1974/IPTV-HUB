import SwiftUI

// MARK: - ChannelListView
struct ChannelListView: View {
    
    // Access the shared ViewModel
    @EnvironmentObject var viewModel: MainViewModel
    @EnvironmentObject var playlistManager: PlaylistManager // Direct access to category data
    @Environment(\.tabSearchResetToken) private var tabSearchResetToken
    
    // Selected channel to open the player
    @State private var selectedChannel: Channel?
    
    // NEW: Selected channel for opening Category/Folder management modal
    @State private var channelToCategorize: Channel?
    
    // Search text
    @State private var searchText = ""
    
    // ONLY Live TV channels (exclude Movies and Series)
    private var liveTVChannels: [Channel] {
        viewModel.liveTVChannelsCache
    }
    
    // Group channels
    private var groupedChannels: [String: [Channel]] {
        viewModel.groupedLiveChannelsCache
    }
    
    // Sort groups alphabetically
    private var sortedGroups: [String] {
        groupedChannels.keys.sorted()
    }
    
    // Filtered channels based on search
    private var filteredChannels: [Channel] {
        guard !searchText.isEmpty else { return liveTVChannels }
        return liveTVChannels.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.group.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredGroupedChannels: [String: [Channel]] {
        Dictionary(grouping: filteredChannels) { $0.group }
    }
    
    private var visibleGroups: [String] {
        if searchText.isEmpty {
            return sortedGroups
        } else {
            return filteredGroupedChannels.keys.sorted()
        }
    }
    
    // Search bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                #if os(tvOS)
                .font(.system(size: 28))
                #endif
            
            TextField("Search channels...", text: $searchText)
                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.3))
                .tint(Color(red: 0.91, green: 0.27, blue: 0.38))
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .keyboardType(.default)
                #endif
                #if os(tvOS)
                .font(.system(size: 24))
                #endif
        }
        #if os(tvOS)
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        #else
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        #endif
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 10, y: 3)
        #if os(tvOS)
        .padding(.horizontal, 40)
        .padding(.top, 20)
        .padding(.bottom, 10)
        #else
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 5)
        #endif
    }
    
    var body: some View {
        let topColor = Color(red: 0.95, green: 0.95, blue: 0.97)
        let bottomColor = Color(red: 0.98, green: 0.98, blue: 1.0)
        
        ZStack {
            // Modern gradient background - açık tonlar
            LinearGradient(
                colors: [topColor, bottomColor],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                if let errorMessage = viewModel.errorMessage {
                    // ----- CASE 1: ERROR OCCURRED -----
                    ErrorStateView(errorMessage: errorMessage)
                    
                } else if liveTVChannels.isEmpty && !viewModel.isLoading {
                    // ----- CASE 2: EMPTY LIST (NO LIVE TV CHANNELS) -----
                    EmptyStateView(
                        title: "No Live TV Channels",
                        message: "Please select a playlist from the 'Settings' tab or add a new one.\n\nNote: Movies and Series are shown in the VoD tab."
                    )
                    
                } else {
                    // ----- CASE 3: SUCCESS (CHANNELS LOADED) -----
                    List {
                        // NEW SECTION: CATEGORIES AS FOLDABLE MENUS (iOS only - tvOS doesn't support DisclosureGroup)
                        #if os(iOS)
                        ForEach(playlistManager.categories.sorted(by: { $0.order < $1.order }), id: \.id) { category in
                            
                            // Get channels for this category from MainViewModel
                            let categoryChannels = viewModel.getChannels(forCategory: category.id)
                            
                            if !categoryChannels.isEmpty {
                                DisclosureGroup(category.name) {
                                    ForEach(categoryChannels) { channel in
                                        MainChannelRowView(channel: channel, selectedChannel: $selectedChannel, channelToCategorize: $channelToCategorize)
                                    }
                                }
                                .tint(Color(red: 0.91, green: 0.27, blue: 0.38))
                            }
                        }
                        #endif
                        
                        // LIST CHANNELS BY GROUP (filtered by search)
                        ForEach(visibleGroups, id: \.self) { groupName in
                            let channels = searchText.isEmpty
                            ? (groupedChannels[groupName] ?? [])
                            : (filteredGroupedChannels[groupName] ?? [])
                            
                            if !channels.isEmpty {
                                Section(header: Text(groupName)
                                    .foregroundColor(Color(red: 0.91, green: 0.27, blue: 0.38))
                                    .font(.headline)) {
                                    ForEach(channels) { channel in
                                        MainChannelRowView(channel: channel, selectedChannel: $selectedChannel, channelToCategorize: $channelToCategorize)
                                    }
                                }
                            }
                        }
                    }
                    #if os(iOS)
                    .scrollContentBackground(.hidden)
                    #endif
                    .background(Color.clear)
                    #if os(iOS)
                    .listStyle(.insetGrouped)
                    #else
                    .listStyle(.plain)
                    #endif
                }
            }
        }
        .fullScreenCover(item: $selectedChannel) { channel in
            PlayerView(initialChannel: channel)
                .environmentObject(viewModel)
                .environmentObject(playlistManager)
        }
        .sheet(item: $channelToCategorize) { channel in
            CategoryChannelSelector(channel: channel)
                .environmentObject(viewModel)
                .environmentObject(playlistManager)
        }
        .onChange(of: tabSearchResetToken) { _ in
            searchText = ""
        }
    }
}

// MARK: - Helper Views

/// Contains all the channel row logic and buttons
struct MainChannelRowView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @State var channel: Channel
    @Binding var selectedChannel: Channel?
    @Binding var channelToCategorize: Channel? // For adding categories
    
    #if os(tvOS)
    @Environment(\.isFocused) var isFocused
    #endif
    
    // Checks if the channel belongs to any category
    private var isCategorized: Bool {
        !channel.categoryIDs.isEmpty
    }

    var body: some View {
        HStack(spacing: 12) {
            // Logo
            SecureAsyncImage(url: channel.logo) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.95, green: 0.95, blue: 0.98), Color(red: 0.9, green: 0.9, blue: 0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "tv.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.8))
                }
            }
            #if os(tvOS)
            .frame(width: 100, height: 100)
            #else
            .frame(width: 50, height: 50)
            #endif
            .cornerRadius(8)
            .clipped()
            
            // Channel Name
            VStack(alignment: .leading, spacing: 4) {
                Text(channel.name)
                    #if os(tvOS)
                    .font(.system(size: 28, weight: .semibold))
                    #else
                    .font(.system(size: 15, weight: .semibold))
                    #endif
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                    .lineLimit(1)
                Text(channel.group)
                    #if os(tvOS)
                    .font(.system(size: 20))
                    #else
                    .font(.caption)
                    #endif
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                    .lineLimit(1)
            }
            
            Spacer()
            
            #if os(iOS)
            // CATEGORY BUTTON - iOS only
            Button(action: {
                channelToCategorize = channel
            }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: isCategorized ? "folder.fill" : "folder")
                        .font(.system(size: 20))
                        .foregroundColor(isCategorized ? Color(red: 1.0, green: 0.6, blue: 0.0) : Color(red: 0.7, green: 0.7, blue: 0.8))
                    
                    // Badge showing number of categories (if > 0)
                    if channel.categoryIDs.count > 0 {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.6, blue: 0.0))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text("\(channel.categoryIDs.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 6, y: -6)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            #endif
            
            // Play button (opens PlayerView)
            Button(action: {
                selectedChannel = channel
            }) {
                Circle()
                    .fill(Color(red: 0.91, green: 0.27, blue: 0.38))
                    #if os(tvOS)
                    .frame(width: 60, height: 60)
                    #else
                    .frame(width: 36, height: 36)
                    #endif
                    .overlay(
                        Image(systemName: "play.fill")
                            #if os(tvOS)
                            .font(.system(size: 24))
                            #else
                            .font(.system(size: 14))
                            #endif
                            .foregroundColor(.white)
                            .offset(x: 1)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
        }
        #if os(tvOS)
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        #else
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        #endif
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
        .listRowBackground(Color.clear)
        #if os(tvOS)
        .listRowInsets(EdgeInsets(top: 8, leading: 40, bottom: 8, trailing: 40))
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        #else
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        #endif
    }
}

/// CASE 1: View shown when an error occurs
struct ErrorStateView: View {
    let errorMessage: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(red: 0.91, green: 0.27, blue: 0.38))
            
            Text("Failed to Load Channels")
                .font(.title2.bold())
                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
            
            Text("Please check your playlist URL or try a different playlist.")
                .font(.subheadline)
                .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Show technical error details
            Text(errorMessage)
                .font(.caption)
                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .padding()
    }
}

// EmptyStateView (shown when list is empty) is assumed to exist

// MARK: - Preview
#Preview {
    // Fix: Provide PlaylistManager expected by MainViewModel
    let playlistManager = PlaylistManager()
    let mainViewModel = MainViewModel(playlistManager: playlistManager)
    
    return MainView()
        .environmentObject(mainViewModel)
        .environmentObject(playlistManager)
}
