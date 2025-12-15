import Foundation
import AVKit
import Combine

@MainActor
class PlayerViewModel: NSObject, ObservableObject, AVPictureInPictureControllerDelegate {
    
    @Published var player: AVPlayer
    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = true
    @Published var isMuted: Bool = false
    @Published var volume: Float
    
    // Tracks the current channel (used to load new URLs during swipe)
    @Published var currentChannel: Channel
    
    // VoD specific properties
    @Published var currentSeason: Season?
    @Published var currentEpisode: Episode?
    @Published var allSeasons: [Season] = []
    @Published var autoplayNextEpisode: Bool = UserDefaults.standard.bool(forKey: "autoplayNextEpisode")
    
    // Player settings
    @Published var primaryVideoPlayer: VideoPlayerType
    @Published var bufferDuration: Int = UserDefaults.standard.integer(forKey: "bufferDuration")
    @Published var subtitlesFontSize: Int = UserDefaults.standard.integer(forKey: "subtitlesFontSize")
    
    private var timeControlStatusObserver: NSKeyValueObservation?
    private var playerItemStatusObserver: NSKeyValueObservation?
    private var timeObserver: Any?
    private var videoEndObserver: NSObjectProtocol?
    
    private let networkManager = NetworkManager.shared
    private let volumeDefaultsKey = "playerVolume"
    private let defaultVolume: Float = 0.7
    private var lastNonZeroVolume: Float = 0.7
    
    init(channel: Channel, preferredPlayer: VideoPlayerType = .ksPlayer) {
        self.primaryVideoPlayer = preferredPlayer
        self.currentChannel = channel
        let defaults = UserDefaults.standard
        let storedVolume: Float = defaults.object(forKey: volumeDefaultsKey) != nil
            ? defaults.float(forKey: volumeDefaultsKey)
            : defaultVolume
        let clampedVolume = Self.clamp(storedVolume)
        self.volume = clampedVolume
        self.lastNonZeroVolume = clampedVolume == 0 ? defaultVolume : clampedVolume
        self.isMuted = clampedVolume == 0
        
        // Create player item with metadata
        let playerItem = AVPlayerItem(url: channel.url)
        
        // Add external metadata for Now Playing info
        let titleMetadata = AVMutableMetadataItem()
        titleMetadata.identifier = .commonIdentifierTitle
        titleMetadata.value = channel.name as NSString
        titleMetadata.extendedLanguageTag = "und"
        
        playerItem.externalMetadata = [titleMetadata]
        
        self.player = AVPlayer(playerItem: playerItem)
        
        super.init()
        
        // Load default buffer duration if not set
        if bufferDuration == 0 {
            bufferDuration = 3
        }
        
        // Load default subtitle font size if not set
        if subtitlesFontSize == 0 {
            subtitlesFontSize = 22
        }
        
        // Set player properties after super.init
        self.player.volume = clampedVolume
        self.player.isMuted = isMuted
        
        // Save to recent channels
        saveToRecentChannels(channel)
        
        setupAudioSession()
        setupPlayerSettings()
        addPlayerObservers()
        
        // If this is a series, load seasons/episodes
        if channel.contentType == .series, let seriesId = channel.seriesId {
            // Will be loaded when user opens series detail
        }
        
        play()
    }

    /// Initialize with an existing AVPlayer instance (used when transferring playback between
    /// mini player and fullscreen player to preserve the same playback session).
    init(player: AVPlayer, channel: Channel, preferredPlayer: VideoPlayerType = .ksPlayer) {
        self.primaryVideoPlayer = preferredPlayer
        self.currentChannel = channel

        let defaults = UserDefaults.standard
        let storedVolume: Float = defaults.object(forKey: volumeDefaultsKey) != nil
            ? defaults.float(forKey: volumeDefaultsKey)
            : defaultVolume
        let clampedVolume = Self.clamp(storedVolume)
        self.volume = clampedVolume
        self.lastNonZeroVolume = clampedVolume == 0 ? defaultVolume : clampedVolume
        self.isMuted = clampedVolume == 0

        // Reuse provided player instead of creating a new AVPlayerItem.
        self.player = player

        super.init()

        // Ensure volume/ mute state is applied to the reused player
        self.player.volume = clampedVolume
        self.player.isMuted = isMuted

        // Save to recent channels
        saveToRecentChannels(channel)

        setupAudioSession()
        setupPlayerSettings()
        addPlayerObservers()

        play()
    }
    
    deinit {
        // Clean-up kept empty to avoid Main Actor issues
    }
    
    // MARK: - Player Controls
    
    /// Called by central PlayerView when a new channel is loaded
    func load(channel: Channel) {
        // Skip if the same channel is already playing
        if self.currentChannel.url == channel.url { return }
        
        self.currentChannel = channel
        self.isLoading = true
        
        // Save to recent channels
        saveToRecentChannels(channel)
        
        // Remove previous observers and item
        removePlayerObservers()
        
        let playerItem = AVPlayerItem(url: channel.url)
        
        // Add external metadata for Now Playing info (fixes MediaRemote warnings)
        let titleMetadata = AVMutableMetadataItem()
        titleMetadata.identifier = .commonIdentifierTitle
        titleMetadata.value = channel.name as NSString
        titleMetadata.extendedLanguageTag = "und"
        
        let artworkMetadata = AVMutableMetadataItem()
        artworkMetadata.identifier = .commonIdentifierArtwork
        
        // Load artwork asynchronously to avoid blocking main thread
        if let logoURL = channel.logo {
            let itemReference = playerItem
            Task(priority: .utility) { [weak self] in
                guard let self else { return }
                do {
                    let imageData = try await self.networkManager.fetchData(from: logoURL)
                    await MainActor.run {
                        guard self.player.currentItem === itemReference else { return }
                        artworkMetadata.value = imageData as NSData
                        artworkMetadata.dataType = kCMMetadataBaseDataType_JPEG as String
                        itemReference.externalMetadata = [titleMetadata, artworkMetadata]
                    }
                } catch {
                    print("PlayerViewModel: Artwork fetch failed: \(error.localizedDescription)")
                }
            }
        }
        
        // Set metadata without artwork initially, will be updated if artwork loads
        playerItem.externalMetadata = [titleMetadata]
        
        // Pause player and replace current item
        player.pause()
        player.replaceCurrentItem(with: playerItem)
        player.volume = volume
        player.isMuted = isMuted
        
        // Add new observers
        addPlayerObservers()
        
        // Start playback
        play()
    }
    
    /// Compatibility helper for legacy callers expecting `loadChannel(_:debounce:)`.
    func loadChannel(_ channel: Channel, debounce: Bool = false) {
        if debounce {
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard !Task.isCancelled, let self else { return }
                self.load(channel: channel)
            }
        } else {
            load(channel: channel)
        }
    }
    
    // MARK: - Recent Channels
    
    private func saveToRecentChannels(_ channel: Channel) {
        let key = "recentChannelIDs"
        var recentIDs = UserDefaults.standard.stringArray(forKey: key) ?? []
        
        let stableID = channel.recentIdentifier
        let legacyID = channel.id.uuidString
        
        // Remove duplicates (both legacy UUID entries and new stable IDs)
        recentIDs.removeAll { $0 == stableID || $0 == legacyID }
        
        // Add to beginning
        recentIDs.insert(stableID, at: 0)
        
        // Keep only last 10
        if recentIDs.count > 10 {
            recentIDs = Array(recentIDs.prefix(10))
        }
        
        UserDefaults.standard.set(recentIDs, forKey: key)
        print("📺 Recent channel saved: \(channel.name)")
    }
    
    func play() {
        player.play()
    }
    
    func pause() {
        player.pause()
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func toggleMute() {
        if isMuted {
            let restored = lastNonZeroVolume == 0 ? defaultVolume : lastNonZeroVolume
            setVolume(restored)
        } else {
            if volume > 0 { lastNonZeroVolume = volume }
            setVolume(0)
        }
    }
    
    func setVolume(_ newValue: Float) {
        let clamped = Self.clamp(newValue)
        volume = clamped
        player.volume = clamped
        UserDefaults.standard.set(clamped, forKey: volumeDefaultsKey)
        if clamped == 0 {
            isMuted = true
            player.isMuted = true
        } else {
            lastNonZeroVolume = clamped
            isMuted = false
            player.isMuted = false
        }
    }
    
    /// Called from .onDisappear when the view is closed
    func cleanup() {
        player.pause()
        player.replaceCurrentItem(with: nil) // Release the media item
        
        // Release audio session resources
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Error deactivating audio session: \(error.localizedDescription)")
        }
        
        removePlayerObservers()
    }
    
    // MARK: - Setup
    
    private func setupAudioSession() {
        do {
            // Configure audio session for PiP support
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Log audio session errors (e.g., -50)
            print("Error setting up audio session: \(error.localizedDescription)")
        }
    }
    
    private func setupPlayerSettings() {
        // Apply buffer duration setting
        if let currentItem = player.currentItem {
            currentItem.preferredForwardBufferDuration = TimeInterval(bufferDuration)
        }
    }
    
    // MARK: - VoD Episode Playback
    
    func loadEpisode(_ episode: Episode, from season: Season) {
        guard let episodeURL = episode.streamURL else {
            print("Episode URL not available")
            return
        }
        
        self.currentEpisode = episode
        self.currentSeason = season
        self.isLoading = true
        
        removePlayerObservers()
        
        let playerItem = AVPlayerItem(url: episodeURL)
        playerItem.preferredForwardBufferDuration = TimeInterval(bufferDuration)
        
        player.pause()
        player.replaceCurrentItem(with: playerItem)
        player.volume = volume
        player.isMuted = isMuted
        
        addPlayerObservers()
        setupAutoplayNextEpisode()
        
        play()
    }
    
    private func setupAutoplayNextEpisode() {
        guard autoplayNextEpisode else { return }
        
        // Remove previous observer if exists
        if let observer = videoEndObserver {
            NotificationCenter.default.removeObserver(observer)
            videoEndObserver = nil
        }
        
        // Add observer for when video ends
        videoEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.playNextEpisode()
        }
    }
    
    private func playNextEpisode() {
        guard let currentEpisode = currentEpisode,
              let currentSeason = currentSeason else {
            return
        }
        
        // Find next episode in current season
        if let currentIndex = currentSeason.episodes.firstIndex(where: { $0.id == currentEpisode.id }),
           currentIndex + 1 < currentSeason.episodes.count {
            let nextEpisode = currentSeason.episodes[currentIndex + 1]
            loadEpisode(nextEpisode, from: currentSeason)
        } else {
            // Try to find next season
            if let seasonIndex = allSeasons.firstIndex(where: { $0.id == currentSeason.id }),
               seasonIndex + 1 < allSeasons.count {
                let nextSeason = allSeasons[seasonIndex + 1]
                if let firstEpisode = nextSeason.episodes.first {
                    loadEpisode(firstEpisode, from: nextSeason)
                }
            } else {
                print("No more episodes to play")
            }
        }
    }
    
    // MARK: - Player Status Observers
    
    private func addPlayerObservers() {
        
        timeControlStatusObserver = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            
            DispatchQueue.main.async {
                switch player.timeControlStatus {
                case .playing:
                    self?.isPlaying = true
                    self?.isLoading = false
                case .paused:
                    self?.isPlaying = false
                    self?.isLoading = false
                case .waitingToPlayAtSpecifiedRate:
                    self?.isLoading = true
                @unknown default:
                    break
                }
            }
        }
        
        playerItemStatusObserver = player.currentItem?.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self?.isLoading = false
                case .failed:
                    self?.isLoading = false
                    print("Media failed to load: \(item.error?.localizedDescription ?? "Unknown error")")
                default:
                    self?.isLoading = true
                }
            }
        }
    }
    
    private func removePlayerObservers() {
        timeControlStatusObserver?.invalidate()
        playerItemStatusObserver?.invalidate()
        timeControlStatusObserver = nil
        playerItemStatusObserver = nil
        
        if let observer = videoEndObserver {
            NotificationCenter.default.removeObserver(observer)
            videoEndObserver = nil
        }
    }
    
    // MARK: - AVPictureInPictureControllerDelegate
    
    nonisolated func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("PiP will start")
    }
    
    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("✅ PiP DID START (delegate callback)")
        Task { @MainActor in
            // Ensure playback continues
            if self.player.timeControlStatus != .playing {
                print("▶️ Starting playback in PiP...")
                self.player.play()
            }
        }
    }
    
    nonisolated func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("⏹ PiP WILL STOP (delegate callback)")
    }
    
    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("⏹ PiP stopped")
    }
    
    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        // User tapped restore in native PiP - accept and bring app to foreground
        print("🔄 PiP restore requested")
        Task { @MainActor in
            // Accept the restore - system will bring app to foreground and fullscreen player should appear
            completionHandler(true)
            print("✅ Restore accepted")
        }
    }
    
    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        print("❌ PiP failed to start: \(error.localizedDescription)")
    }
}

private extension PlayerViewModel {
    static func clamp(_ value: Float) -> Float { min(max(value, 0), 1) }
}
