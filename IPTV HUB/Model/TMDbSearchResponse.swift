//
//  TMDbSearchResponse.swift
//  Easy IPTV
//
//  Created by Haluk CELEBI on 15.11.2025.
//


import Foundation

// Main search response returned by the API
struct TMDbSearchResponse: Codable {
    let results: [TMDbResult]
}

// A single content item in the search results (Movie or TV Show)
struct TMDbResult: Codable, Identifiable {
    let id: Int
    let overview: String?
    let posterPath: String?
    let voteAverage: Double?
    
    // API uses different keys for movies (title) and series (name)
    let title: String? // For movies
    let name: String?  // For TV shows
    
    var displayName: String {
        return title ?? name ?? "Unknown"
    }
    
    // Helper variable that constructs the full poster URL
    var posterURL: URL? {
        guard let posterPath = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }
}
