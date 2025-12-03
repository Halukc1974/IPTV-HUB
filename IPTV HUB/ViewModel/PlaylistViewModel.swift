//
//  PlaylistViewModel.swift
//  Easy IPTV
//
//  Created by Haluk CELEBI on 15.11.2025.
//

import Foundation
import Combine // For SwiftUI reactive data binding

@MainActor // Ensures UI updates occur on the main thread
class PlaylistViewModel: ObservableObject {
    
    // @Published: Any view observing this variable will automatically update when it changes
    @Published var channels = [Channel]()
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let parser = M3UParser()
    
    func loadPlaylist(from urlString: String) async {
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid URL format"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let parsedChannels = try await parser.parse(url: url)
            self.channels = parsedChannels
        } catch {
            self.errorMessage = "Failed to load playlist: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}
