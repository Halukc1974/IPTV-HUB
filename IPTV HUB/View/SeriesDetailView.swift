//
//  SeriesDetailView.swift
//  Easy IPTV
//
//  Created by Haluk CELEBI on 19.11.2025.
//


//
//  SeriesDetailView.swift
//  Easy IPTV
//
//  Created by Haluk CELEBI on 19.11.2025.
//

import SwiftUI

struct SeriesDetailView: View {
    let series: Channel
    @State private var seasons: [Season] = []
    @State private var selectedSeason: Season?
    @State private var isLoading = true
    @State private var showPlayer = false
    @State private var selectedEpisode: Episode?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Backdrop image
                if let backdropURL = series.backdrop {
                    AsyncImage(url: backdropURL) { image in
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(red: 0.9, green: 0.9, blue: 0.92))
                            .aspectRatio(16/9, contentMode: .fill)
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                }
                
                // Series info
                VStack(alignment: .leading, spacing: 12) {
                    // Title
                    Text(series.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                    
                    // Metadata
                    HStack(spacing: 16) {
                        if let rating = series.rating {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", rating))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.4))
                            }
                        }
                        
                        if let releaseDate = series.releaseDate {
                            Text(releaseDate)
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                        }
                    }
                    
                    // Genre
                    if let genre = series.genre {
                        Text(genre)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "e94560"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(hex: "e94560").opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Plot
                    if let plot = series.plot, !plot.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Overview")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                            
                            Text(plot)
                                .font(.system(size: 15))
                                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.4))
                                .lineSpacing(4)
                        }
                        .padding(.top, 8)
                    }
                    
                    // Seasons selector
                    if !seasons.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Seasons")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(seasons) { season in
                                        Button(action: {
                                            selectedSeason = season
                                        }) {
                                            Text(season.name)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(selectedSeason?.id == season.id ? .white : Color(red: 0.3, green: 0.3, blue: 0.4))
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .background(
                                                    selectedSeason?.id == season.id ?
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
                                                .shadow(color: selectedSeason?.id == season.id ? Color(hex: "e94560").opacity(0.3) : Color.clear, radius: 8, y: 4)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    
                    // Episodes list
                    if let selectedSeason = selectedSeason {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Episodes")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                            
                            ForEach(selectedSeason.episodes) { episode in
                                EpisodeRow(episode: episode) {
                                    self.selectedEpisode = episode
                                    self.showPlayer = true
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 20)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.95, blue: 0.97), Color(red: 0.98, green: 0.98, blue: 1.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Series Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            // Load seasons if not already loaded
            if !series.seasons.isEmpty {
                seasons = series.seasons
                selectedSeason = seasons.first
                isLoading = false
            } else {
                // Fetch from API (implement later)
                // For now, show placeholder
                isLoading = false
            }
        }
        .fullScreenCover(isPresented: $showPlayer) {
            if let episode = selectedEpisode {
                // In future, use PlayerView with episode support
                // For now, show placeholder
                Text("Episode player coming soon")
            }
        }
    }
}

// MARK: - Episode Row
struct EpisodeRow: View {
    let episode: Episode
    let onPlay: () -> Void
    
    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 16) {
                // Episode number circle
                ZStack {
                    Circle()
                        .fill(Color(hex: "e94560").opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Text("\(episode.episodeNum)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "e94560"))
                }
                
                // Episode info
                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                        .lineLimit(2)
                    
                    if let plot = episode.info?.plot {
                        Text(plot)
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                            .lineLimit(2)
                    }
                    
                    if let duration = episode.info?.duration {
                        Text(duration)
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.65))
                    }
                }
                
                Spacer()
                
                // Play button
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color(hex: "e94560"))
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationView {
        SeriesDetailView(series: Channel(
            name: "Sample Series",
            url: URL(string: "https://example.com")!,
            logo: nil,
            group: "Series",
            tvgId: "",
            contentType: .series
        ))
    }
}
