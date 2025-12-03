//
//  CategoryChannelSelector.swift
//  Easy IPTV
//
//  Created by Haluk CELEBI on 16.11.2025.
//

import SwiftUI

// MARK: - CategoryChannelSelector View
/// This view is used to select which categories a channel belongs to.
struct CategoryChannelSelector: View {
    @EnvironmentObject var viewModel: MainViewModel
    @EnvironmentObject var playlistManager: PlaylistManager // Access to category list
    @Environment(\.dismiss) var dismiss
    
    let channel: Channel // The channel to edit
    
    var body: some View {
        NavigationView {
            List {
                ForEach(playlistManager.categories) { category in
                    CategoryToggleRow(
                        category: category,
                        channel: channel,
                        viewModel: viewModel
                    )
                }
            }
            .navigationTitle("\(channel.name) Categories")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Category Toggle Row (with State)
struct CategoryToggleRow: View {
    let category: ChannelCategory
    let channel: Channel
    @ObservedObject var viewModel: MainViewModel
    
    // Local state that updates immediately
    @State private var isSelected: Bool
    
    init(category: ChannelCategory, channel: Channel, viewModel: MainViewModel) {
        self.category = category
        self.channel = channel
        self.viewModel = viewModel
        
        // Initialize state from current channel data
        _isSelected = State(initialValue: channel.categoryIDs.contains(category.id))
    }
    
    var body: some View {
        Button(action: {
            // Toggle state immediately for instant UI feedback
            isSelected.toggle()
            
            // Update the actual data in ViewModel
            viewModel.toggleChannel(channel, inCategory: category)
        }) {
            HStack(spacing: 16) {
                // Checkbox icon
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? Color(red: 0.2, green: 0.78, blue: 0.35) : Color(red: 0.6, green: 0.6, blue: 0.7))
                
                // Category name
                Text(category.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                
                Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
