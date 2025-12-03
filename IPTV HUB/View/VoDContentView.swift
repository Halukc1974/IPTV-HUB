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
    @State private var selectedTab: VoDTab = .movies
    @State private var searchText: String = ""
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
        if searchText.isEmpty {
            return movies
        }
        return movies.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var filteredSeries: [Channel] {
        if searchText.isEmpty {
            return series
        }
        return series.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var myServerItems: [Channel] {
        if searchText.isEmpty {
            return viewModel.serverChannels
        }
        return viewModel.serverChannels.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var hasServerConnection: Bool {
        let embyReady = !embyServerURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !embyServerToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let plexReady = !plexServerURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !plexServerToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return embyReady || plexReady
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
            if selectedTab == .myServer {
                refreshServerLibraries(force: true)
            }
        }
        .onChange(of: selectedTab) { newValue in
            if newValue == .myServer {
                refreshServerLibraries(force: true)
            }
        }
        .onChange(of: embyServerURL) { _ in
            refreshServerLibraries()
        }
        .onChange(of: embyServerToken) { _ in
            refreshServerLibraries()
        }
        .onChange(of: plexServerURL) { _ in
            refreshServerLibraries()
        }
        .onChange(of: plexServerToken) { _ in
            refreshServerLibraries()
        }
    }
    
    // MARK: - Movies Grid
    private var moviesGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 16) {
                ForEach(filteredMovies) { movie in
                    MoviePosterCard(movie: movie)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Series Grid
    private var seriesGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 16) {
                ForEach(filteredSeries) { show in
                    SeriesPosterCard(series: show)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
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
                        columns: [GridItem(.adaptive(minimum: 220), spacing: 18)],
                        spacing: 20
                    ) {
                        ForEach(myServerItems) { item in
                            ServerMediaCard(item: item)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .padding(.top, 8)
    }

    private func refreshServerLibraries(force: Bool = false) {
        guard force || selectedTab == .myServer else { return }
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Poster image
            ZStack {
                if let logoURL = movie.cover ?? movie.logo {
                    SecureAsyncImage(url: logoURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(red: 0.9, green: 0.9, blue: 0.92))
                            .aspectRatio(2/3, contentMode: .fit)
                            .overlay(
                                Image(systemName: "film.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.75))
                            )
                    }
                } else {
                    Rectangle()
                        .fill(Color(red: 0.9, green: 0.9, blue: 0.92))
                        .aspectRatio(2/3, contentMode: .fit)
                        .overlay(
                            Image(systemName: "film.fill")
                                .font(.system(size: 30))
                                .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.75))
                        )
                }
                
                // Rating badge
                if let rating = movie.rating, !rating.isNaN, !rating.isInfinite {
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
                
                // Play button overlay
                Button(action: {
                    selectedChannel = movie
                }) {
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
                .buttonStyle(PlainButtonStyle())
            }
            .aspectRatio(2/3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Title
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
        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
        .fullScreenCover(item: $selectedChannel) { channel in
            PlayerView(initialChannel: channel)
                .environmentObject(viewModel)
        }
    }
}

// MARK: - Series Poster Card
struct SeriesPosterCard: View {
    let series: Channel
    @State private var showSeriesDetail = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Poster image
            ZStack {
                if let logoURL = series.cover ?? series.logo {
                    SecureAsyncImage(url: logoURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(red: 0.9, green: 0.9, blue: 0.92))
                            .aspectRatio(2/3, contentMode: .fit)
                            .overlay(
                                Image(systemName: "tv.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.75))
                            )
                    }
                } else {
                    Rectangle()
                        .fill(Color(red: 0.9, green: 0.9, blue: 0.92))
                        .aspectRatio(2/3, contentMode: .fit)
                        .overlay(
                            Image(systemName: "tv.fill")
                                .font(.system(size: 30))
                                .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.75))
                        )
                }
                
                // Rating badge
                if let rating = series.rating, !rating.isNaN, !rating.isInfinite {
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
                
                // Play button overlay
                Button(action: {
                    showSeriesDetail = true
                }) {
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
                .buttonStyle(PlainButtonStyle())
            }
            .aspectRatio(2/3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Title
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
        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
        .sheet(isPresented: $showSeriesDetail) {
            SeriesDetailView(series: series)
        }
    }
}

// MARK: - Server Media Card
struct ServerMediaCard: View {
    let item: Channel
    @EnvironmentObject var viewModel: MainViewModel
    @State private var selectedChannel: Channel?
    
    private var providerLabel: String {
        if item.group.lowercased().contains("plex") { return "Plex" }
        if item.group.lowercased().contains("emby") { return "Emby" }
        return "Server"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            posterView
                .overlay(providerBadge, alignment: .topLeading)
                .overlay(playButton, alignment: .bottomTrailing)
            .aspectRatio(16/9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
            
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
        .shadow(color: Color.black.opacity(0.06), radius: 10, y: 4)
        .fullScreenCover(item: $selectedChannel) { channel in
            PlayerView(initialChannel: channel, channelCollection: viewModel.serverChannels)
                .environmentObject(viewModel)
        }
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
            .aspectRatio(2/3, contentMode: .fit)
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
    
    private var playButton: some View {
        Button(action: { selectedChannel = item }) {
            Circle()
                .fill(Color.black.opacity(0.7))
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .offset(x: 2)
                )
        }
        .buttonStyle(PlainButtonStyle())
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
