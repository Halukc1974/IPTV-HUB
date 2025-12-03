//
//  MovieDetailView.swift
//  Easy IPTV
//
//  Created by Haluk CELEBI on 19.11.2025.
//

import SwiftUI

struct MovieDetailView: View {
    let movie: Channel
    @State private var showPlayer = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Backdrop image
                if let backdropURL = movie.backdrop {
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
                
                // Movie info
                VStack(alignment: .leading, spacing: 12) {
                    // Title
                    Text(movie.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                    
                    // Metadata
                    HStack(spacing: 16) {
                        if let rating = movie.rating {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", rating))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.4))
                            }
                        }
                        
                        if let releaseDate = movie.releaseDate {
                            Text(releaseDate)
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                        }
                        
                        if let duration = movie.duration {
                            Text(duration)
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                        }
                    }
                    
                    // Genre
                    if let genre = movie.genre {
                        Text(genre)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "e94560"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(hex: "e94560").opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Play button
                    Button(action: {
                        showPlayer = true
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                                .font(.system(size: 18))
                            Text("Play Movie")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "e94560"), Color(hex: "ff6b82")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: Color(hex: "e94560").opacity(0.4), radius: 12, y: 6)
                    }
                    .padding(.top, 8)
                    
                    // Plot
                    if let plot = movie.plot, !plot.isEmpty {
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
                    
                    // Cast
                    if let cast = movie.cast, !cast.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cast")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                            
                            Text(cast)
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                        }
                    }
                    
                    // Director
                    if let director = movie.director, !director.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Director")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                            
                            Text(director)
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                        }
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
        .navigationTitle("Movie Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .fullScreenCover(isPresented: $showPlayer) {
            PlayerView(initialChannel: movie)
        }
    }
}
