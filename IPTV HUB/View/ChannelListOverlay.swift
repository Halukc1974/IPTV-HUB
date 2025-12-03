//
//  ChannelListOverlay.swift
//  Easy IPTV
//
//  Created by Haluk CELEBI on 20.11.2025.
//

import SwiftUI

// MARK: - Overlay View

struct ChannelListOverlay: View {
    let channels: [Channel]
    let currentChannel: Channel
    @Binding var isPresented: Bool
    let onChannelSelected: (Channel) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Channel List
            ScrollView {
                ScrollViewReader { proxy in
                    LazyVStack(spacing: 0) {
                        ForEach(channels) { channel in
                            ChannelRowView(
                                channel: channel,
                                isCurrentlyPlaying: channel.id == currentChannel.id
                            )
                            .onTapGesture {
                                onChannelSelected(channel)
                            }
                            .id(channel.id)
                        }
                    }
                    .onAppear {
                        proxy.scrollTo(currentChannel.id, anchor: .center)
                    }
                }
            }
            .frame(maxWidth: 500)
            .background(Color.black.opacity(0.95))
            .edgesIgnoringSafeArea(.all)
            
            Spacer()
            
            // Close area
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                }
        }
    }
}

// MARK: - Channel Row View

struct ChannelRowView: View {
    let channel: Channel
    let isCurrentlyPlaying: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Channel Logo
            SecureAsyncImage(url: channel.logo) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "tv")
                            .foregroundColor(.white.opacity(0.5))
                    )
            }
            .frame(width: 48, height: 48)
            .cornerRadius(8)
            
            // Channel Info
            VStack(alignment: .leading, spacing: 4) {
                Text(channel.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // EPG Time (dummy)
                Text("09:00-11:00")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Live indicator
            if isCurrentlyPlaying {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            isCurrentlyPlaying ? Color.white.opacity(0.1) : Color.clear
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

struct ChannelListOverlay_Previews: PreviewProvider {
    private struct PreviewWrapper: View {
        @State private var showOverlay = true
        private let sampleChannels: [Channel] = {
            let streamURL = URL(string: "https://example.com/stream.m3u8")!
            return [
                Channel(id: UUID(), name: "Sample News", url: streamURL, logo: nil, group: "News", tvgId: "news"),
                Channel(id: UUID(), name: "Sample Sports", url: streamURL, logo: nil, group: "Sports", tvgId: "sports"),
                Channel(id: UUID(), name: "Sample Movies", url: streamURL, logo: nil, group: "Movies", tvgId: "movies")
            ]
        }()
        
        var body: some View {
            ChannelListOverlay(
                channels: sampleChannels,
                currentChannel: sampleChannels[0],
                isPresented: $showOverlay,
                onChannelSelected: { _ in }
            )
            .preferredColorScheme(.dark)
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
    }
}
