//
//  VoDContentView.swift
//  Easy IPTV
//
//  Created by Haluk CELEBI on 19.11.2025.
//

import SwiftUI

// MARK: - VoD Content View (Movies & Series)
struct VoDContentView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @Environment(\.tabSearchResetToken) private var tabSearchResetToken
    @State private var selectedTab: VoDTab = .movies
    @State private var searchText: String = ""
    @State private var hasPerformedInitialServerRefresh = false
    @State private var isViewVisible = false
    @AppStorage("embyServerURL") private var embyServerURL: String = ""
    @AppStorage("embyServerToken") private var embyServerToken: String = ""
    @AppStorage("plexServerURL") private var plexServerURL: String = ""
    @AppStorage("plexServerToken") private var plexServerToken: String = ""
    
    enum VoDTab: String, CaseIterable {
        case movies = "Movies"
        case series = "Series"
        case myServer = "My Server"
        
        var icon: String {
            switch self {
            case .movies: return "film.fill"
            case .series: return "tv.fill"
            case .myServer: return "server.rack"
            }
        }
    }
    
    var movies: [Channel] {
        viewModel.channels.filter { $0.contentType == .movie }
    }
    
    var series: [Channel] {
        viewModel.channels.filter { $0.contentType == .series }
    }
    
    var filteredMovies: [Channel] {
        guard !searchText.isEmpty else { return movies }
        return movies.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var filteredSeries: [Channel] {
        guard !searchText.isEmpty else { return series }
        return series.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var myServerItems: [Channel] {
        guard !searchText.isEmpty else { return viewModel.serverChannels }
        return viewModel.serverChannels.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var hasServerConnection: Bool {
        let embyReady = !embyServerURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !embyServerToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let plexReady = !plexServerURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !plexServerToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return embyReady || plexReady
    }

    private var posterGridColumns: [GridItem] {
        #if os(tvOS)
        return Array(repeating: GridItem(.flexible(minimum: 220, maximum: 360), spacing: 24), count: 4)
        #else
        return [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
        #endif
    }

    private var serverGridColumns: [GridItem] {
        #if os(tvOS)
        return [GridItem(.adaptive(minimum: 360), spacing: 24)]
        #else
        return [GridItem(.adaptive(minimum: 220), spacing: 18)]
        #endif
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.95, blue: 0.97), Color(red: 0.98, green: 0.98, blue: 1.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Tab selector
                HStack(spacing: 16) {
                        ForEach(VoDTab.allCases, id: \.self) { tab in
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedTab = tab
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 16))
                                    
                                    Text(tab.rawValue)
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(selectedTab == tab ? .white : Color(red: 0.3, green: 0.3, blue: 0.4))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    selectedTab == tab ?
                                    LinearGradient(
                                        colors: [Color(hex: "e94560"), Color(hex: "ff6b82")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ) : LinearGradient(
                                        colors: [Color.white, Color.white],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(20)
                                .shadow(color: selectedTab == tab ? Color(hex: "e94560").opacity(0.3) : Color.clear, radius: 8, y: 4)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    // Search bar
                    HStack(spacing: 10) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                            
                            TextField("Search \(selectedTab.rawValue.lowercased())...", text: $searchText)
                                .font(.system(size: 15))
                        }
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)
                        
                        if selectedTab == .myServer {
                            Button(action: { refreshServerLibraries(force: true) }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color(hex: "e94560"))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .disabled(viewModel.isLoadingServerLibraries)
                            .opacity(viewModel.isLoadingServerLibraries ? 0.6 : 1.0)
                            .accessibilityLabel("Refresh server library")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    
                // Content grid
                switch selectedTab {
                case .movies:
                    moviesGrid
                case .series:
                    seriesGrid
                case .myServer:
                    myServerGrid
                }
            }
        }
        .onAppear {
            isViewVisible = true
            triggerInitialServerRefreshIfNeeded()
        }
        .onDisappear {
            isViewVisible = false
        }
        .onChange(of: selectedTab) { newValue in
            if newValue == .myServer {
                triggerInitialServerRefreshIfNeeded()
            }
        }
        .onChange(of: embyServerURL) { _ in
            resetServerRefreshStateAndReload()
        }
        .onChange(of: embyServerToken) { _ in
            resetServerRefreshStateAndReload()
        }
        .onChange(of: plexServerURL) { _ in
            resetServerRefreshStateAndReload()
        }
        .onChange(of: plexServerToken) { _ in
            resetServerRefreshStateAndReload()
        }
        .onChange(of: tabSearchResetToken) { _ in
            searchText = ""
        }
    }
    
    // MARK: - Movies Grid
    private var moviesGrid: some View {
        #if os(tvOS)
        let rowSpacing: CGFloat = 24
        #else
        let rowSpacing: CGFloat = 16
        #endif
        return ScrollView {
            LazyVGrid(columns: posterGridColumns, spacing: rowSpacing) {
                ForEach(filteredMovies) { movie in
                    MoviePosterCard(movie: movie)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        #if os(tvOS)
        .focusSection()
        #endif
    }
    
    // MARK: - Series Grid
    private var seriesGrid: some View {
        #if os(tvOS)
        let rowSpacing: CGFloat = 24
        #else
        let rowSpacing: CGFloat = 16
        #endif
        return ScrollView {
            LazyVGrid(columns: posterGridColumns, spacing: rowSpacing) {
                ForEach(filteredSeries) { show in
                    SeriesPosterCard(series: show)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        #if os(tvOS)
        .focusSection()
        #endif
    }

    // MARK: - My Server Grid
    private var myServerGrid: some View {
        Group {
            if !hasServerConnection {
                MyServerEmptyStateView(
                    title: "No server connected",
                    message: "Enter your Emby or Plex server details from Settings → External Servers."
                )
            } else if viewModel.isLoadingServerLibraries {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.3)
                    Text("Fetching your server library...")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if myServerItems.isEmpty {
                MyServerEmptyStateView(
                    title: "No media returned",
                    message: "We could not find playable movies or series from the connected servers yet."
                )
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: serverGridColumns,
                        spacing: 20
                    ) {
                        ForEach(myServerItems) { item in
                            ServerMediaCard(item: item)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                #if os(tvOS)
                .focusSection()
                #endif
            }
        }
        .padding(.top, 8)
    }

    private func triggerInitialServerRefreshIfNeeded() {
        guard isViewVisible, selectedTab == .myServer, hasServerConnection else { return }
        guard !hasPerformedInitialServerRefresh else { return }
        refreshServerLibraries(force: true)
    }

    private func resetServerRefreshStateAndReload() {
        hasPerformedInitialServerRefresh = false
        refreshServerLibraries()
    }

    private func refreshServerLibraries(force: Bool = false) {
        if force {
            hasPerformedInitialServerRefresh = true
        } else {
            guard isViewVisible, selectedTab == .myServer else { return }
            hasPerformedInitialServerRefresh = true
        }
        viewModel.refreshServerLibraries(
            embyURL: embyServerURL,
            embyToken: embyServerToken,
            plexURL: plexServerURL,
            plexToken: plexServerToken
        )
    }
}

// MARK: - Movie Poster Card
struct MoviePosterCard: View {
    let movie: Channel
    @EnvironmentObject var viewModel: MainViewModel
    @State private var selectedChannel: Channel?
    #if os(tvOS)
    @Environment(\.isFocused) private var isFocused
    #endif
    
    var body: some View {
        Button {
            selectedChannel = movie
        } label: {
            movieCardContent
        }
        .buttonStyle(.plain)
        #if os(tvOS)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .shadow(color: isFocused ? Color.black.opacity(0.25) : Color.black.opacity(0.08), radius: isFocused ? 18 : 6, y: isFocused ? 8 : 3)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        #else
        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
        #endif
        .fullScreenCover(item: $selectedChannel) { channel in
            VoDPlayerView(initialChannel: channel)
                .environmentObject(viewModel)
        }
    }

    private var movieCardContent: some View {
        VStack(spacing: 0) {
            posterBody
            Text(movie.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
                .padding(.top, 6)
        }
        .background(Color.white)
        .cornerRadius(10)
    }
    
    private var posterBody: some View {
        ZStack {
            if let logoURL = movie.cover ?? movie.logo {
                SecureAsyncImage(url: logoURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholderPoster(icon: "film.fill")
                }
            } else {
                placeholderPoster(icon: "film.fill")
            }
            
            if let rating = movie.rating, !rating.isNaN, !rating.isInfinite {
                ratingBadge(for: rating)
            }
            
            playBadge
        }
        .aspectRatio(2/3, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func placeholderPoster(icon: String) -> some View {
        Rectangle()
            .fill(Color(red: 0.9, green: 0.9, blue: 0.92))
            .aspectRatio(2/3, contentMode: .fit)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.75))
            )
    }
    
    private func ratingBadge(for rating: Double) -> some View {
        VStack {
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                    Text(String(format: "%.1f", rating))
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
                .padding(8)
            }
            Spacer()
        }
    }
    
    private var playBadge: some View {
        Circle()
            .fill(Color.black.opacity(0.7))
            .frame(width: 50, height: 50)
            .overlay(
                Image(systemName: "play.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .offset(x: 2)
            )
    }
}

// MARK: - Series Poster Card
struct SeriesPosterCard: View {
    let series: Channel
    @State private var showSeriesDetail = false
    #if os(tvOS)
    @Environment(\.isFocused) private var isFocused
    #endif
    
    var body: some View {
        Button {
            showSeriesDetail = true
        } label: {
            seriesCardContent
        }
        .buttonStyle(.plain)
        #if os(tvOS)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .shadow(color: isFocused ? Color.black.opacity(0.25) : Color.black.opacity(0.08), radius: isFocused ? 18 : 6, y: isFocused ? 8 : 3)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        #else
        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
        #endif
        .sheet(isPresented: $showSeriesDetail) {
            SeriesDetailView(series: series)
        }
    }

    private var seriesCardContent: some View {
        VStack(spacing: 0) {
            posterBody
            Text(series.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
                .padding(.top, 6)
        }
        .background(Color.white)
        .cornerRadius(10)
    }
    
    private var posterBody: some View {
        ZStack {
            if let logoURL = series.cover ?? series.logo {
                SecureAsyncImage(url: logoURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholderPoster
                }
            } else {
                placeholderPoster
            }
            
            if let rating = series.rating, !rating.isNaN, !rating.isInfinite {
                ratingBadge(for: rating)
            }
            
            playBadge
        }
        .aspectRatio(2/3, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var placeholderPoster: some View {
        Rectangle()
            .fill(Color(red: 0.9, green: 0.9, blue: 0.92))
            .aspectRatio(2/3, contentMode: .fit)
            .overlay(
                Image(systemName: "tv.fill")
                    .font(.system(size: 30))
                    .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.75))
            )
    }
    
    private func ratingBadge(for rating: Double) -> some View {
        VStack {
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                    Text(String(format: "%.1f", rating))
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
                .padding(8)
            }
            Spacer()
        }
    }
    
    private var playBadge: some View {
        Circle()
            .fill(Color.black.opacity(0.7))
            .frame(width: 50, height: 50)
            .overlay(
                Image(systemName: "play.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .offset(x: 2)
            )
    }
}

// MARK: - Server Media Card
struct ServerMediaCard: View {
    let item: Channel
    @EnvironmentObject var viewModel: MainViewModel
    @State private var selectedChannel: Channel?
    #if os(tvOS)
    @Environment(\.isFocused) private var isFocused
    #endif
    
    private var providerLabel: String {
        if item.group.lowercased().contains("plex") { return "Plex" }
        if item.group.lowercased().contains("emby") { return "Emby" }
        return "Server"
    }
    
    var body: some View {
        Button {
            selectedChannel = item
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        #if os(tvOS)
        .scaleEffect(isFocused ? 1.03 : 1.0)
        .shadow(color: isFocused ? Color.black.opacity(0.25) : Color.black.opacity(0.06), radius: isFocused ? 18 : 10, y: isFocused ? 8 : 4)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        #else
        .shadow(color: Color.black.opacity(0.06), radius: 10, y: 4)
        #endif
        .fullScreenCover(item: $selectedChannel) { channel in
            VoDPlayerView(initialChannel: channel, channelCollection: viewModel.serverChannels)
                .environmentObject(viewModel)
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            posterView
                .overlay(providerBadge, alignment: .topLeading)
                .overlay(playBadge, alignment: .bottomTrailing)
                .aspectRatio(16/9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.2))
                    .lineLimit(2)
                
                if let detail = item.plot, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.52))
                        .lineLimit(2)
                }
                
                metadataStack
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
    }

    private var posterView: some View {
        Group {
            if let poster = item.cover ?? item.logo {
                SecureAsyncImage(url: poster) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholderView
                }
            } else {
                placeholderView
            }
        }
    }
    
    private var placeholderView: some View {
        Rectangle()
            .fill(Color(red: 0.9, green: 0.9, blue: 0.92))
            .aspectRatio(16/9, contentMode: .fit)
            .overlay(
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 30))
                    .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.75))
            )
    }
    
    private var providerBadge: some View {
        Text(providerLabel)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.65))
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(12)
    }
    
    private var playBadge: some View {
        Circle()
            .fill(Color.black.opacity(0.7))
            .frame(width: 46, height: 46)
            .overlay(
                Image(systemName: "play.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .offset(x: 2)
            )
            .padding(12)
    }
    
    private var metadataStack: some View {
        HStack(spacing: 12) {
            if let duration = item.duration, !duration.isEmpty {
                Label(duration, systemImage: "clock")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
            }
            if let release = item.releaseDate, !release.isEmpty {
                Label(release, systemImage: "calendar")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Empty State View
struct MyServerEmptyStateView: View {
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "externaldrive.badge.questionmark")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.75))
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.3))
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 40)
    }
}

#Preview {
    let playlistManager = PlaylistManager()
    VoDContentView()
        .environmentObject(MainViewModel(playlistManager: playlistManager))
        .environmentObject(playlistManager)
}
