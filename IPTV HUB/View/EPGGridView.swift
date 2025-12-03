//
//  EPGGridView.swift
//  Easy IPTV
//
//  Created by Haluk CELEBI on 16.11.2025.
//

import SwiftUI

struct EPGGridView: View {
    
    // Shared ViewModel for all tabs
    @EnvironmentObject var viewModel: MainViewModel
    
    // EPG width scaling: 1 minute = 3 points (more compact)
    private let pointsPerMinute: CGFloat = 3.0
    
    // Left column width for channel logo/name
    private let channelHeaderWidth: CGFloat = 100.0
    
    // Current time
    @State private var currentTime = Date()
    
    // EPG start time (current time minus 1 hour)
    private var timelineStartDate: Date {
        Date().addingTimeInterval(-1 * 3600)
    }
    
    // Timer to update current time indicator
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.95, blue: 0.97), Color(red: 0.98, green: 0.98, blue: 1.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if viewModel.channels.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "tv.and.mediabox")
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: "e94560").opacity(0.6))
                        
                        Text("No TV Guide Available")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                        
                        Text("Load a playlist to view the TV guide")
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            
                            // MARK: - Time Ruler Header
                            Section {
                                // Channel rows
                                ForEach(viewModel.channels) { channel in
                                    if !(viewModel.epgData[channel.tvgId] ?? []).isEmpty {
                                        ModernChannelRow(
                                            channel: channel,
                                            programs: viewModel.epgData[channel.tvgId] ?? [],
                                            startDate: timelineStartDate,
                                            currentTime: currentTime,
                                            pointsPerMinute: pointsPerMinute,
                                            channelHeaderWidth: channelHeaderWidth
                                        )
                                    }
                                }
                            } header: {
                                TimeRulerView(
                                    startDate: timelineStartDate,
                                    currentTime: currentTime,
                                    pointsPerMinute: pointsPerMinute,
                                    headerWidth: channelHeaderWidth
                                )
                            }
                        }
                }
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
}


// MARK: - Modern Channel Row
struct ModernChannelRow: View {
    let channel: Channel
    let programs: [EPGProgram]
    let startDate: Date
    let currentTime: Date
    let pointsPerMinute: CGFloat
    let channelHeaderWidth: CGFloat
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left: Channel info
            VStack(spacing: 6) {
                AsyncImage(url: channel.logo) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.91, green: 0.27, blue: 0.38).opacity(0.1))
                        Image(systemName: "tv")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "e94560"))
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text(channel.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: channelHeaderWidth)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(Color.white)
            
            // Right: Programs timeline
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(programs.sorted(by: { $0.startDate < $1.startDate })) { program in
                        ModernProgramCard(
                            program: program,
                            startDate: startDate,
                            currentTime: currentTime,
                            pointsPerMinute: pointsPerMinute
                        )
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
            }
            .background(Color.white.opacity(0.5))
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

// MARK: - Modern Program Card
struct ModernProgramCard: View {
    let program: EPGProgram
    let startDate: Date
    let currentTime: Date
    let pointsPerMinute: CGFloat
    
    private var duration: TimeInterval {
        program.stopDate.timeIntervalSince(program.startDate)
    }
    
    private var width: CGFloat {
        (duration / 60) * pointsPerMinute
    }
    
    private var isLive: Bool {
        currentTime >= program.startDate && currentTime <= program.stopDate
    }
    
    private var isPast: Bool {
        currentTime > program.stopDate
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Time range
            HStack(spacing: 4) {
                if isLive {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                    
                    Text("LIVE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.red)
                } else {
                    Text(timeString(program.startDate))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(isPast ? Color(red: 0.6, green: 0.6, blue: 0.65) : Color(hex: "e94560"))
                }
                
                Text("•")
                    .font(.system(size: 8))
                    .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.75))
                
                Text(timeString(program.stopDate))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.65))
            }
            
            // Program title
            Text(program.title)
                .font(.system(size: 13, weight: isLive ? .bold : .semibold))
                .foregroundColor(isPast ? Color(red: 0.5, green: 0.5, blue: 0.55) : Color(red: 0.15, green: 0.15, blue: 0.25))
                .lineLimit(2)
            
            // Description
            if !program.desc.isEmpty {
                Text(program.desc)
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.6))
                    .lineLimit(2)
            }
            
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: max(140, width), height: 90)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isLive ?
                      LinearGradient(colors: [Color(hex: "e94560").opacity(0.15), Color(hex: "e94560").opacity(0.05)],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing) :
                      LinearGradient(colors: [Color.white, Color(red: 0.98, green: 0.98, blue: 0.99)],
                                   startPoint: .top,
                                   endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isLive ? Color(hex: "e94560") : Color.clear, lineWidth: 2)
        )
        .opacity(isPast ? 0.6 : 1.0)
    }
    
    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Time Ruler (Sticky Header)
struct TimeRulerView: View {
    let startDate: Date
    let currentTime: Date
    let pointsPerMinute: CGFloat
    let headerWidth: CGFloat
    
    var totalHours = 12
    var hourWidth: CGFloat { pointsPerMinute * 60 }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left spacer matching channel column
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "e94560").opacity(0.9), Color(hex: "e94560").opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14))
                    Text("NOW")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
            }
            .frame(width: headerWidth, height: 44)
            
            // Time slots
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(0..<totalHours, id: \.self) { hour in
                        VStack(spacing: 2) {
                            Text(timeString(for: hour))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                            
                            Rectangle()
                                .fill(Color(hex: "e94560").opacity(0.3))
                                .frame(height: 2)
                        }
                        .frame(width: hourWidth)
                    }
                }
                .padding(.horizontal, 8)
                .background(
                    LinearGradient(
                        colors: [Color.white, Color(red: 0.98, green: 0.98, blue: 0.99)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .frame(height: 44)
        }
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
    }
    
    private func timeString(for hourOffset: Int) -> String {
        let calendar = Calendar.current
        let time = calendar.date(byAdding: .hour, value: hourOffset, to: startDate)!
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: time)
    }
}


// MARK: - Preview
#Preview {
    MainView()
}
