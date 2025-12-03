//
//  AppSettingsView.swift
//  Easy IPTV
//
//  Created by Haluk CELEBI on 18.11.2025.
//

import SwiftUI

// MARK: - Color Extension (Color(hex: "...") hatasını gidermek için eklendi)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Playlist Update Mode Enum
enum PlaylistUpdateMode: String, CaseIterable, Identifiable {
    case manually = "Manually"
    case daily = "Daily"
    case every3days = "Every 3 days"
    case weekly = "Weekly"
    case monthly = "Monthly"
    
    var id: String { self.rawValue }
    
    var subtitle: String {
        switch self {
        case .manually: return "Update playlists when you tap refresh"
        case .daily: return "Refresh playlists once every day"
        case .every3days: return "Refresh playlists every 3 days"
        case .weekly: return "Refresh playlists once a week"
        case .monthly: return "Refresh playlists once a month"
        }
    }
}

// MARK: - Video Player Type Enum
enum VideoPlayerType: String, CaseIterable, Identifiable {
    case ksPlayer = "KSPlayer (Metal)"
    case vlcKit = "VLCKit (OpenGL)"
    case avKit = "AVKit (Native)"
    case mpv = "MPV (Experimental)"
    
    var id: String { self.rawValue }
    
    var subtitle: String {
        switch self {
        case .ksPlayer: return "Recommended for best performance"
        case .vlcKit: return "Good compatibility with formats"
        case .avKit: return "Native iOS/tvOS player"
        case .mpv: return "Advanced features, may be unstable"
        }
    }
}

// MARK: - Audio Language Enum
enum AudioLanguage: String, CaseIterable, Identifiable {
    case english = "English"
    case turkish = "Turkish"
    case spanish = "Spanish"
    case french = "French"
    case german = "German"
    case auto = "Auto"
    
    var id: String { self.rawValue }
}

// MARK: - Theme Mode Enum
enum ThemeMode: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
}

// MARK: - Support Topics
enum SupportTopic: String, Identifiable, CaseIterable {
    case help = "Quick Help"
    case legal = "Terms & Privacy"
    
    var id: String { rawValue }
    
    var subtitle: String {
        switch self {
        case .help:
            return "Read the detailed FAQ for using Easy IPTV"
        case .legal:
            return "Review the Terms & Conditions and Privacy Policy"
        }
    }
    
    var icon: String {
        switch self {
        case .help:
            return "questionmark.circle.fill"
        case .legal:
            return "doc.text.fill"
        }
    }
}

// MARK: - App Settings View
struct AppSettingsView: View {
    
    // Theme & Display
    @AppStorage("themeMode") private var themeModeString: String = ThemeMode.system.rawValue
    @AppStorage("showRecentWatches") private var showRecentWatches: Bool = true
    @AppStorage("showPopularChannels") private var showPopularChannels: Bool = true
    @AppStorage("showOnlyMyCategories") private var showOnlyMyCategories: Bool = false
    @AppStorage("showTVGuide") private var showTVGuide: Bool = true
    @AppStorage("showPlayerOverlay") private var showPlayerOverlay: Bool = true
    @AppStorage("playlistUpdateMode") private var playlistUpdateModeString: String = PlaylistUpdateMode.manually.rawValue
    @AppStorage("channelOverlayOpacity") private var channelOverlayOpacity: Double = 0.9
    
    // Player Settings
    @AppStorage("autoplayNextEpisode") private var autoplayNextEpisode: Bool = true
    @AppStorage("primaryVideoPlayer") private var primaryVideoPlayerString: String = VideoPlayerType.ksPlayer.rawValue
    @AppStorage("allowPausingLiveStreams") private var allowPausingLiveStreams: Bool = false
    @AppStorage("cacheDataLocally") private var cacheDataLocally: Bool = true
    @AppStorage("adaptiveFrameRate") private var adaptiveFrameRate: Bool = false
    @AppStorage("hardwareDecode") private var hardwareDecode: Bool = true
    @AppStorage("asynchronousDecompression") private var asynchronousDecompression: Bool = false
    @AppStorage("bufferDuration") private var bufferDuration: Int = 3
    @AppStorage("preferredAudioLanguage") private var preferredAudioLanguageString: String = AudioLanguage.english.rawValue
    @AppStorage("preferredSubtitleLanguage") private var preferredSubtitleLanguageString: String = AudioLanguage.english.rawValue
    @AppStorage("subtitlesFontSize") private var subtitlesFontSize: Int = 22
    @AppStorage("openSubtitlesUsername") private var openSubtitlesUsername: String = ""
    @AppStorage("openSubtitlesPassword") private var openSubtitlesPassword: String = ""
    
    // MARK: - YENİ SUNUCU AYARLARI
    @AppStorage("embyServerURL") private var embyServerURL: String = ""
    @AppStorage("embyServerToken") private var embyServerToken: String = ""
    @AppStorage("plexServerURL") private var plexServerURL: String = ""
    @AppStorage("plexServerToken") private var plexServerToken: String = ""
    // MARK: -
    
#if os(tvOS)
    private let overlayOpacityOptions = Array(stride(from: 0.3, through: 1.0, by: 0.1))
#endif
    
    private var playlistUpdateMode: PlaylistUpdateMode {
        PlaylistUpdateMode(rawValue: playlistUpdateModeString) ?? .manually
    }
    
    private var themeMode: ThemeMode {
        ThemeMode(rawValue: themeModeString) ?? .system
    }
    
    private var primaryVideoPlayer: VideoPlayerType {
        VideoPlayerType(rawValue: primaryVideoPlayerString) ?? .ksPlayer
    }
    
    private var preferredAudioLanguage: AudioLanguage {
        AudioLanguage(rawValue: preferredAudioLanguageString) ?? .english
    }
    
    private var preferredSubtitleLanguage: AudioLanguage {
        AudioLanguage(rawValue: preferredSubtitleLanguageString) ?? .english
    }
    
    private var supportTopics: [SupportTopic] {
        SupportTopic.allCases
    }
    
    private var overlayTransparencyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Channel Overlay Transparency")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                Spacer()
                Text(String(format: "%d%%", Int(channelOverlayOpacity * 100)))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
            }
            Text("Adjust how opaque the channel list overlay appears while watching.")
                .font(.system(size: 13))
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
            
#if os(tvOS)
            Menu {
                ForEach(overlayOpacityOptions, id: \.self) { value in
                    Button {
                        channelOverlayOpacity = value
                    } label: {
                        Label(String(format: "%d%%", Int(value * 100)), systemImage: value == channelOverlayOpacity ? "checkmark" : "circle")
                    }
                }
            } label: {
                HStack {
                    Text(String(format: "%d%%", Int(channelOverlayOpacity * 100)))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.primary.opacity(0.7))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.primary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                )
            }
#else
            Slider(value: $channelOverlayOpacity, in: 0.3...1.0, step: 0.05)
#endif
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(red: 0.95, green: 0.95, blue: 0.97), Color(red: 0.98, green: 0.98, blue: 1.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Themes Section
                        VStack(alignment: .leading, spacing: 16) {
                            // Section header
                            HStack {
                                Image(systemName: "paintbrush.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: "e94560"))
                                
                                Text("Themes")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            
                            // Theme mode radio buttons
                            VStack(spacing: 0) {
                                ForEach(Array(ThemeMode.allCases.enumerated()), id: \.element) { index, mode in
                                    ThemeRadioButton(
                                        mode: mode,
                                        isSelected: themeMode == mode,
                                        action: {
                                            withAnimation(.spring(response: 0.3)) {
                                                themeModeString = mode.rawValue
                                            }
                                        }
                                    )
                                    
                                    if index < ThemeMode.allCases.count - 1 {
                                        Divider().padding(.leading, 60)
                                    }
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
                            .padding(.horizontal, 20)
                            
                            overlayTransparencyCard
                                .padding(.horizontal, 20)
                        }
                        
                        // --- HARİCİ SUNUCULAR (EMBY/PLEX) BÖLÜMÜ ---
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "server.rack")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: "e94560"))
                                
                                Text("External Servers")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                            }
                            .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                // Yeni NavigationLink, detaylı sunucu ayarları ekranına gidecek
                                NavigationLink(destination: ServerSettingsDetailView(
                                    embyServerURL: $embyServerURL,
                                    embyServerToken: $embyServerToken,
                                    plexServerURL: $plexServerURL,
                                    plexServerToken: $plexServerToken
                                )) {
                                    HStack(spacing: 16) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(red: 0.95, green: 0.95, blue: 0.97))
                                                .frame(width: 44, height: 44)
                                            
                                            Image(systemName: "network")
                                                .font(.system(size: 18))
                                                .foregroundColor(Color(hex: "e94560"))
                                        }
                                        
                                        VStack(alignment: .leading) {
                                            Text("Emby & Plex Connection")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                                            Text("Manage your VOD server connections.")
                                                .font(.system(size: 13))
                                                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.75))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }
                                .buttonStyle(PlainButtonStyle()) // NavLink'i düz buton stiliyle sarmalayın
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
                            .padding(.horizontal, 20)
                        }
                        // --- HARİCİ SUNUCULAR BÖLÜMÜ SONU ---
                                               // Update Playlists Section
                        VStack(alignment: .leading, spacing: 16) {
                            // Section header
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: "e94560"))
                                
                                Text("Update Playlists")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                            }
                            .padding(.horizontal, 20)
                            
                            // Update mode radio buttons
                            VStack(spacing: 0) {
                                ForEach(Array(PlaylistUpdateMode.allCases.enumerated()), id: \.element) { index, mode in
                                    UpdateModeRadioButton(
                                        mode: mode,
                                        isSelected: playlistUpdateMode == mode,
                                        action: {
                                            withAnimation(.spring(response: 0.3)) {
                                                playlistUpdateModeString = mode.rawValue
                                            }
                                        }
                                    )
                                    
                                    if index < PlaylistUpdateMode.allCases.count - 1 {
                                        Divider().padding(.leading, 60)
                                    }
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
                            .padding(.horizontal, 20)
                        }
                        
                        // Player Settings Section (Devamı önceki kod ile aynı)
                        // ...
                        
                        // Player Settings Section
                        VStack(alignment: .leading, spacing: 16) {
                            // Section header
                            HStack {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: "e94560"))
                                
                                Text("Player settings")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                            }
                            .padding(.horizontal, 20)
                            
                            // GENERAL SETTINGS
                            VStack(spacing: 0) {
                                Text("GENERAL SETTINGS")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color(red: 0.97, green: 0.97, blue: 0.98))
                                
                                ToggleRow(
                                    title: "Autoplay next episode",
                                    subtitle: "Automatically play next episode when current ends",
                                    icon: "play.circle.fill",
                                    isOn: $autoplayNextEpisode
                                )
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
                            .padding(.horizontal, 20)
                            
                            // PRIMARY VIDEO PLAYER
                            VStack(spacing: 0) {
                                Text("PRIMARY VIDEO PLAYER")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color(red: 0.97, green: 0.97, blue: 0.98))
                                
                                ForEach(Array(VideoPlayerType.allCases.enumerated()), id: \.element) { index, playerType in
                                    PlayerTypeRadioButton(
                                        playerType: playerType,
                                        isSelected: primaryVideoPlayer == playerType,
                                        action: {
                                            withAnimation(.spring(response: 0.3)) {
                                                primaryVideoPlayerString = playerType.rawValue
                                            }
                                        }
                                    )
                                    
                                    if index < VideoPlayerType.allCases.count - 1 {
                                        Divider().padding(.leading, 20)
                                    }
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
                            .padding(.horizontal, 20)
                            
                            // KSPLAYER (METAL) SETTINGS
                            VStack(spacing: 0) {
                                Text("KSPLAYER (METAL)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color(red: 0.97, green: 0.97, blue: 0.98))
                                
                                ToggleRow(
                                    title: "Allow pausing live streams",
                                    subtitle: "Enable pause/resume for live TV",
                                    icon: "pause.circle.fill",
                                    isOn: $allowPausingLiveStreams
                                )
                                
                                Divider().padding(.leading, 60)
                                
                                ToggleRow(
                                    title: "Cache data locally",
                                    subtitle: "Store video data for smoother playback",
                                    icon: "externaldrive.fill",
                                    isOn: $cacheDataLocally
                                )
                                
                                Divider().padding(.leading, 60)
                                
                                ToggleRow(
                                    title: "Adaptive frame rate",
                                    subtitle: "Match video frame rate automatically",
                                    icon: "waveform.circle.fill",
                                    isOn: $adaptiveFrameRate
                                )
                                
                                Divider().padding(.leading, 60)
                                
                                ToggleRow(
                                    title: "Hardware decode",
                                    subtitle: "Use GPU for video decoding",
                                    icon: "cpu.fill",
                                    isOn: $hardwareDecode
                                )
                                
                                Divider().padding(.leading, 60)
                                
                                ToggleRow(
                                    title: "Asynchronous decompression",
                                    subtitle: "Decode video frames in background",
                                    icon: "arrow.triangle.branch",
                                    isOn: $asynchronousDecompression
                                )
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
                            .padding(.horizontal, 20)
                            
                            // BUFFER DURATION
                            VStack(spacing: 0) {
                                Text("BUFFER DURATION")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color(red: 0.97, green: 0.97, blue: 0.98))
                                
                                HStack {
                                    Button(action: {
                                        if bufferDuration > 1 {
                                            bufferDuration -= 1
                                        }
                                    }) {
                                        Image(systemName: "minus")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(Color(hex: "e94560"))
                                            .frame(width: 44, height: 44)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(bufferDuration) seconds")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        if bufferDuration < 10 {
                                            bufferDuration += 1
                                        }
                                    }) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(Color(hex: "e94560"))
                                            .frame(width: 44, height: 44)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
                            .padding(.horizontal, 20)
                            
                            // PREFERRED AUDIO LANGUAGE
                            VStack(spacing: 0) {
                                Text("PREFERRED AUDIO LANGUAGE")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color(red: 0.97, green: 0.97, blue: 0.98))
                                
                                NavigationLink(destination: LanguageSelectionView(
                                    title: "Audio Language",
                                    selectedLanguage: $preferredAudioLanguageString
                                )) {
                                    HStack(spacing: 16) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(red: 0.95, green: 0.95, blue: 0.97))
                                                .frame(width: 44, height: 44)
                                            
                                            Image(systemName: "waveform")
                                                .font(.system(size: 18))
                                                .foregroundColor(Color(hex: "e94560"))
                                        }
                                        
                                        Text(preferredAudioLanguage.rawValue)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.75))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
                            .padding(.horizontal, 20)
                            
                            // PREFERRED SUBTITLES LANGUAGE
                            VStack(spacing: 0) {
                                Text("PREFERRED SUBTITLES LANGUAGE")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color(red: 0.97, green: 0.97, blue: 0.98))
                                
                                NavigationLink(destination: LanguageSelectionView(
                                    title: "Subtitle Language",
                                    selectedLanguage: $preferredSubtitleLanguageString
                                )) {
                                    HStack(spacing: 16) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(red: 0.95, green: 0.95, blue: 0.97))
                                                .frame(width: 44, height: 44)
                                            
                                            Image(systemName: "captions.bubble.fill")
                                                .font(.system(size: 18))
                                                .foregroundColor(Color(hex: "e94560"))
                                        }
                                        
                                        Text(preferredSubtitleLanguage.rawValue)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.75))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
                            .padding(.horizontal, 20)
                            
                            // SUBTITLES FONT SIZE
                            VStack(spacing: 0) {
                                Text("SUBTITLES FONT SIZE")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color(red: 0.97, green: 0.97, blue: 0.98))
                                
                                HStack {
                                    Button(action: {
                                        if subtitlesFontSize > 12 {
                                            subtitlesFontSize -= 2
                                        }
                                    }) {
                                        Image(systemName: "minus")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(Color(hex: "e94560"))
                                            .frame(width: 44, height: 44)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(subtitlesFontSize)px")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        if subtitlesFontSize < 40 {
                                            subtitlesFontSize += 2
                                        }
                                    }) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(Color(hex: "e94560"))
                                            .frame(width: 44, height: 44)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                
                                Text("The custom subtitles font size is only compatible with KSPlayer.")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 16)
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
                            .padding(.horizontal, 20)
                            
                            // OPENSUBTITLES.COM
                            VStack(spacing: 0) {
                                Text("OPENSUBTITLES.COM")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color(red: 0.97, green: 0.97, blue: 0.98))
                                
                                VStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        TextField("Username (not email)", text: $openSubtitlesUsername)
                                            #if os(iOS)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            #else
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .padding(12)
                                            .background(Color(red: 0.95, green: 0.95, blue: 0.97))
                                            .cornerRadius(8)
                                            #endif
                                            .font(.system(size: 15))
                                            .autocapitalization(.none)
                                            .disableAutocorrection(true)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        SecureField("Password", text: $openSubtitlesPassword)
                                            #if os(iOS)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            #else
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .padding(12)
                                            .background(Color(red: 0.95, green: 0.95, blue: 0.97))
                                            .cornerRadius(8)
                                            #endif
                                            .font(.system(size: 15))
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
                            .padding(.horizontal, 20)
                        }
                        
                        // Display Options Section (Devamı önceki kod ile aynı)
                        // ...
                        
                        // Display Options Section
                        VStack(alignment: .leading, spacing: 16) {
                            // Section header
                            HStack {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: "e94560"))
                                
                                Text("Display Options")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                            }
                            .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                ToggleRow(
                                    title: "Recent Watches",
                                    subtitle: "Show recently watched channels on Home",
                                    icon: "clock.arrow.circlepath",
                                    isOn: $showRecentWatches
                                )
                                
                                Divider().padding(.leading, 60)
                                
                                ToggleRow(
                                    title: "Popular Channels",
                                    subtitle: "Show featured channels section on Home",
                                    icon: "star.fill",
                                    isOn: $showPopularChannels
                                )
                                
                                Divider().padding(.leading, 60)
                                
                                ToggleRow(
                                    title: "Only My Categories",
                                    subtitle: "Hide auto-grouped channels, show only your custom categories",
                                    icon: "folder.badge.person.crop",
                                    isOn: $showOnlyMyCategories
                                )
                                
                                Divider().padding(.leading, 60)
                                
                                ToggleRow(
                                    title: "TV Guide Tab",
                                    subtitle: "Show TV Guide in tab bar",
                                    icon: "list.bullet.rectangle",
                                    isOn: $showTVGuide
                                )
                                
                                Divider().padding(.leading, 60)
                                
                                ToggleRow(
                                    title: "Player Overlay Info",
                                    subtitle: "Show channel info, codec details and controls while playing",
                                    icon: "info.circle",
                                    isOn: $showPlayerOverlay
                                )
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
                            .padding(.horizontal, 20)
                        }
                        
                        // Support Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "lifepreserver")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: "e94560"))
                                
                                Text("Support")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                            }
                            .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                ForEach(Array(supportTopics.enumerated()), id: \.element.id) { index, topic in
                                    NavigationLink {
                                        SupportDetailView(topic: topic)
                                    } label: {
                                        SupportRow(
                                            title: topic.rawValue,
                                            subtitle: topic.subtitle,
                                            icon: topic.icon
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    if index < supportTopics.count - 1 {
                                        Divider().padding(.leading, 60)
                                    }
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
                            .padding(.horizontal, 20)
                        }
                        
                        // About Section
                        VStack(alignment: .leading, spacing: 16) {
                            // Section header
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: "e94560"))
                                
                                Text("About")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                            }
                            .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                InfoRow(title: "Version", value: "1.0.0")
                                Divider().padding(.leading, 20)
                                InfoRow(title: "Build", value: "2025.11.18")
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Settings")
#if os(iOS)
            .navigationBarTitleDisplayMode(.large)
#endif
        }
    }
}

// MARK: - Update Mode Radio Button (Diğer component'ler aynı kalır)
struct UpdateModeRadioButton: View {
    // ... (kod aynı kalır)
    let mode: PlaylistUpdateMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(red: 0.95, green: 0.95, blue: 0.97))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "e94560"))
                }
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.rawValue)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                    
                    Text(mode.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                }
                
                Spacer()
                
                // Radio button
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color(hex: "e94560") : Color(red: 0.85, green: 0.85, blue: 0.87), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color(hex: "e94560"))
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Theme Radio Button (Diğer component'ler aynı kalır)
struct ThemeRadioButton: View {
    // ... (kod aynı kalır)
    let mode: ThemeMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(red: 0.95, green: 0.95, blue: 0.97))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: mode.icon)
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "e94560"))
                }
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.rawValue)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                    
                    Text(mode == .system ? "Match device theme" : "Always \(mode.rawValue.lowercased())")
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                }
                
                Spacer()
                
                // Radio button
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color(hex: "e94560") : Color(red: 0.85, green: 0.85, blue: 0.87), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color(hex: "e94560"))
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Toggle Row (Diğer component'ler aynı kalır)
struct ToggleRow: View {
    // ... (kod aynı kalır)
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(red: 0.95, green: 0.95, blue: 0.97))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "e94560"))
            }
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
            }
            
            Spacer()
            
            // Toggle switch
            Toggle("", isOn: $isOn)
                .tint(Color(hex: "e94560"))
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Info Row (Diğer component'ler aynı kalır)
struct InfoRow: View {
    // ... (kod aynı kalır)
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.4))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// MARK: - Support Row
struct SupportRow: View {
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.95, green: 0.95, blue: 0.97))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "e94560"))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.75))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Support Detail View
struct SupportDetailView: View {
    let topic: SupportTopic
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
#if os(tvOS)
            TVBackButtonBar(title: topic.rawValue) {
                dismiss()
            }
#endif
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch topic {
                    case .help:
                        SupportFAQContentView(content: HelpContent.easyIPTV)
                    case .legal:
                        SupportLegalContentView(content: TermsContent.easyIPTV)
                    }
                }
                .padding(20)
            }
        }
#if os(tvOS)
        .focusSection()
#endif
        .background(Color(red: 0.97, green: 0.97, blue: 0.98))
        .navigationTitle(topic.rawValue)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

private struct SupportLegalContentView: View {
    let content: TermsContent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(content.headerTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.15))
                .padding(.bottom, 4)
            Text(content.updatedText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            
            ForEach(content.sections) { section in
                SupportSectionView(section: section)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(content.contactDescription)
                    .font(.system(size: 15))
                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.3))
                Text(content.contactEmailLine)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                Text(content.footerLine)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 6, y: 2)
            .tvFocusableCard()
        }
    }
}

private struct SupportFAQContentView: View {
    let content: HelpContent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(content.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.15))
            Text(content.intro)
                .font(.system(size: 15))
                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.3))
            
            ForEach(content.faqs) { item in
                FAQItemView(item: item)
            }
            
            Text(content.outro)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
}

private struct SupportSectionView: View {
    let section: TermsContent.Section
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
            if !section.paragraphs.isEmpty {
                ForEach(section.paragraphs, id: \.self) { paragraph in
                    Text(paragraph)
                        .font(.system(size: 15))
                        .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.3))
                }
            }
            if !section.bullets.isEmpty {
                BulletListView(items: section.bullets)
            }
            if let title = section.linkTitle, let url = section.linkURL {
                Link(title, destination: url)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "007aff"))
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 6, y: 2)
        .tvFocusableCard()
    }
}

private struct BulletListView: View {
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                    Text(item)
                        .font(.system(size: 15))
                        .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.3))
                }
            }
        }
    }
}

private struct FAQItemView: View {
    let item: HelpContent.FAQItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.question)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
            BulletListView(items: item.answers)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 6, y: 2)
        .tvFocusableCard()
    }
}

#if os(tvOS)
private struct TVFocusableCard: ViewModifier {
    @State private var isFocused = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isFocused ? 1.02 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isFocused ? Color.white.opacity(0.6) : Color.clear, lineWidth: 3)
            )
            .animation(.easeOut(duration: 0.2), value: isFocused)
            .focusable(true) { focused in
                isFocused = focused
            }
    }
}

private extension View {
    func tvFocusableCard() -> some View { modifier(TVFocusableCard()) }
}

private struct TVBackButtonBar: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Color(hex: "e94560"))
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.top, 30)
        .padding(.bottom, 10)
    }
}
#else
private extension View {
    func tvFocusableCard() -> some View { self }
}
#endif

// MARK: - Player Type Radio Button (Diğer component'ler aynı kalır)
struct PlayerTypeRadioButton: View {
    // ... (kod aynı kalır)
    let playerType: VideoPlayerType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(playerType.rawValue)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                    .padding(.leading, 20)
                
                Spacer()
                
                // Radio button
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color(hex: "e94560") : Color(red: 0.85, green: 0.85, blue: 0.87), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color(hex: "e94560"))
                            .frame(width: 14, height: 14)
                    }
                }
                .padding(.trailing, 20)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Language Selection View (Diğer component'ler aynı kalır)
struct LanguageSelectionView: View {
    // ... (kod aynı kalır)
    let title: String
    @Binding var selectedLanguage: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
#if os(tvOS)
            TVBackButtonBar(title: title) {
                dismiss()
            }
#endif
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(red: 0.95, green: 0.95, blue: 0.97), Color(red: 0.98, green: 0.98, blue: 1.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                List {
                    ForEach(AudioLanguage.allCases) { language in
                        Button(action: {
                            selectedLanguage = language.rawValue
                            dismiss()
                        }) {
                            HStack {
                                Text(language.rawValue)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                                
                                Spacer()
                                
                                if selectedLanguage == language.rawValue {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color(hex: "e94560"))
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(Color.white)
                    }
                }
                #if os(iOS)
                .scrollContentBackground(.hidden)
                #endif
                .background(Color.clear)
            }
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Server Settings Detail View (YENİ EKRAN)
struct ServerSettingsDetailView: View {
    @Binding var embyServerURL: String
    @Binding var embyServerToken: String
    @Binding var plexServerURL: String
    @Binding var plexServerToken: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
#if os(tvOS)
            TVBackButtonBar(title: "Server Connections") {
                dismiss()
            }
#endif
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Emby Section
                    ServerConnectionSection(
                        title: "Emby Server",
                        subtitle: "Connect to your Emby server for VOD content.",
                        icon: "externaldrive.fill.badge.person.crop",
                        serverURL: $embyServerURL,
                        serverToken: $embyServerToken,
                        hint: "e.g., http://192.168.1.10:8096"
                    )
                    
                    // Plex Section
                    ServerConnectionSection(
                        title: "Plex Server",
                        subtitle: "Connect to your Plex server for VOD content.",
                        icon: "play.tv.fill",
                        serverURL: $plexServerURL,
                        serverToken: $plexServerToken,
                        hint: "e.g., https://[domain].plex.direct:32400"
                    )
                }
                .padding(.top, 20)
                .padding(.horizontal, 0)
            }
        }
        .navigationTitle("Server Connections")
        .background(LinearGradient(
            colors: [Color(red: 0.95, green: 0.95, blue: 0.97), Color(red: 0.98, green: 0.98, blue: 1.0)],
            startPoint: .top,
            endPoint: .bottom
        ).ignoresSafeArea())
    }
}

// MARK: - Server Connection Section Component
struct ServerConnectionSection: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var serverURL: String
    @Binding var serverToken: String
    let hint: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "e94560"))
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                // Section Title/Subtitle
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connection Details")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(red: 0.97, green: 0.97, blue: 0.98))
                
                // Server URL Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Server Address (URL)")
                        .font(.system(size: 15, weight: .medium))
                    TextField(hint, text: $serverURL)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(12)
                        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
                        .cornerRadius(8)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Access Token Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Access Token / API Key")
                        .font(.system(size: 15, weight: .medium))
                    SecureField("Token", text: $serverToken)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(12)
                        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
                        .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)

                // Save/Test Button (Dummy)
                Button("Test Connection & Save") {
                    // Bağlantı test logic buraya eklenecek.
                    print("\(title) URL: \(serverURL)")
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "e94560"))
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Preview
#Preview {
    AppSettingsView()
}
