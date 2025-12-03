//
//  EmptyStateView.swift
//  Easy IPTV
//
//  Created by Haluk CELEBI on 15.11.2025.
//

import SwiftUI

/// A general-purpose helper view shown when the list is empty or no error occurs.
struct EmptyStateView: View {
    var title: String
    var message: String
    var iconName: String = "tv.and.mediabox"
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: iconName)
                .font(.system(size: 60))
                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.7))
            
            Text(title)
                .font(.title2.bold())
                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding()
    }
}

#Preview {
    EmptyStateView(
        title: "No Playlists",
        message: "Please add a playlist."
    )
}
