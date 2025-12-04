import SwiftUI
import AVKit

struct VoDPlayerView: View {
    let initialChannel: Channel
    let channelCollection: [Channel]?

    init(initialChannel: Channel, channelCollection: [Channel]? = nil) {
        self.initialChannel = initialChannel
        self.channelCollection = channelCollection
    }
    @AppStorage("primaryVideoPlayer") private var primaryVideoPlayerRaw: String = VideoPlayerType.ksPlayer.rawValue
    private var selectedPlayerType: VideoPlayerType {
        VideoPlayerType(rawValue: primaryVideoPlayerRaw) ?? .ksPlayer
    }
    
    var body: some View {
        #if os(iOS)
        iOSVoDPlayerView(
            initialChannel: initialChannel,
            channelCollection: channelCollection,
            playerType: selectedPlayerType
        )
        #elseif os(tvOS)
        TVOSVoDPlayerView(
            initialChannel: initialChannel,
            channelCollection: channelCollection,
            playerType: selectedPlayerType
        )
        #else
        Text("Unsupported Platform")
        #endif
    }
}

// MARK: - Shared Helpers

private struct VoDMediaOption: Identifiable, Equatable {
    let id: String
    let title: String
    let option: AVMediaSelectionOption?
    
    static func optionID(for option: AVMediaSelectionOption) -> String {
        let langComponent = option.extendedLanguageTag
            ?? option.locale?.identifier
            ?? "und"
        let mediaType = option.mediaType.rawValue
        return "\(langComponent)_\(mediaType)_\(option.displayName)"
    }
    
    static func from(_ option: AVMediaSelectionOption) -> VoDMediaOption {
        VoDMediaOption(
            id: optionID(for: option),
            title: option.displayName,
            option: option
        )
    }
}

private struct VoDPlaybackState {
    var currentTime: Double = 0
    var totalDuration: Double = 1
}

#if os(iOS)
// MARK: - iOS Player
private struct iOSVoDPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var playerViewModel: PlayerViewModel
    private let playerType: VideoPlayerType
    
    @State private var overlayVisible: Bool = true
    @State private var playbackRate: Double = 1.0
    @State private var timeObserver: Any?
    @State private var isScrubbing: Bool = false
    @State private var playbackState = VoDPlaybackState()
    @State private var audioOptions: [VoDMediaOption] = []
    @State private var subtitleOptions: [VoDMediaOption] = []
    @State private var selectedAudioID: String?
    @State private var selectedSubtitleID: String?
    @State private var audioGroup: AVMediaSelectionGroup?
    @State private var subtitleGroup: AVMediaSelectionGroup?
    
    init(initialChannel: Channel, channelCollection: [Channel]?, playerType: VideoPlayerType) {
        _playerViewModel = StateObject(wrappedValue: PlayerViewModel(channel: initialChannel, preferredPlayer: playerType))
        _ = channelCollection
        self.playerType = playerType
    }
    
    var body: some View {
        ZStack {
            iOSVideoPlayerRepresentable(
                player: playerViewModel.player,
                videoGravity: .resizeAspect,
                allowsExternalPlayback: playerType == .avKit
            )
            .ignoresSafeArea()
            .onTapGesture { withAnimation { overlayVisible.toggle() } }
            
            if overlayVisible {
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(playerViewModel.currentChannel.name)
                                .font(.headline)
                                .foregroundColor(.white)
                            if let plot = playerViewModel.currentChannel.plot, !plot.isEmpty {
                                Text(plot)
                                    .font(.footnote)
                                    .lineLimit(2)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        Spacer()
                        Button(action: dismissPlayer) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 40)
                    
                    Spacer()
                    controlCluster
                }
                .transition(.opacity)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.65), Color.black.opacity(0.1)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .ignoresSafeArea()
                )
            }
            
            if playerViewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.4)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .onAppear {
            configureTimeObserver()
            refreshMediaOptions()
        }
        .onDisappear {
            removeTimeObserver()
            playerViewModel.cleanup()
        }
        .onReceive(playerViewModel.$currentChannel) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                refreshMediaOptions()
            }
        }
    }
    
    private var controlCluster: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading) {
                Slider(
                    value: Binding(
                        get: { playbackState.currentTime },
                        set: { newValue in
                            playbackState.currentTime = newValue
                        }
                    ),
                    in: 0...max(playbackState.totalDuration, 1),
                    onEditingChanged: { editing in
                        isScrubbing = editing
                        if !editing {
                            seek(to: playbackState.currentTime)
                        }
                    }
                )
                .accentColor(Color(hex: "e94560"))
                
                HStack {
                    Text(formatTime(playbackState.currentTime))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text(formatTime(playbackState.totalDuration))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            HStack(spacing: 24) {
                Button(action: { skip(by: -15) }) {
                    controlIcon("gobackward.15")
                }
                
                Button(action: playerViewModel.togglePlayPause) {
                    controlIcon(playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                }
                
                Button(action: { skip(by: 30) }) {
                    controlIcon("goforward.30")
                }
            }
            
            HStack(spacing: 16) {
                Menu {
                    ForEach(audioOptions) { option in
                        Button(option.title) {
                            selectAudio(option)
                        }
                    }
                } label: {
                    labeledControl(text: audioMenuLabel, systemName: "waveform")
                }
                
                Menu {
                    Button("Off") { selectSubtitle(nil) }
                    ForEach(subtitleOptions) { option in
                        Button(option.title) {
                            selectSubtitle(option)
                        }
                    }
                } label: {
                    labeledControl(text: subtitleMenuLabel, systemName: "captions.bubble")
                }
                
                Menu {
                    ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                        Button("\(rate, specifier: "%.2g")x") {
                            setPlaybackRate(rate)
                        }
                    }
                } label: {
                    labeledControl(text: "Speed", systemName: "speedometer")
                }
            }
            .padding(.bottom, 30)
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    private func controlIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 30, weight: .medium))
            .foregroundColor(.white)
            .frame(width: 54, height: 54)
            .background(Color.white.opacity(0.2))
            .clipShape(Circle())
    }
    
    private func labeledControl(text: String, systemName: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemName)
            Text(text)
        }
        .font(.footnote.bold())
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.2))
        .clipShape(Capsule())
    }
    
    // MARK: - Actions
    
    private func configureTimeObserver() {
        guard timeObserver == nil else { return }
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = playerViewModel.player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { _ in
            guard !isScrubbing else { return }
            let current = playerViewModel.player.currentTime().seconds
            if current.isFinite {
                playbackState.currentTime = current
            }
            if let duration = playerViewModel.player.currentItem?.duration.seconds, duration.isFinite {
                playbackState.totalDuration = max(duration, 1)
            }
        }
    }
    
    private func removeTimeObserver() {
        if let token = timeObserver {
            playerViewModel.player.removeTimeObserver(token)
            timeObserver = nil
        }
    }
    
    private func seek(to seconds: Double) {
        let cmTime = CMTime(seconds: seconds, preferredTimescale: 600)
        playerViewModel.player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    private func skip(by offset: Double) {
        let current = playerViewModel.player.currentTime().seconds
        let upperBound = playbackState.totalDuration
        let newTime = min(max(0, current + offset), upperBound)
        playbackState.currentTime = newTime
        seek(to: newTime)
    }
    
    private func setPlaybackRate(_ rate: Double) {
        playbackRate = rate
        if playerViewModel.isPlaying {
            playerViewModel.player.playImmediately(atRate: Float(rate))
        } else if rate != 1.0 {
            playerViewModel.play()
            playerViewModel.player.playImmediately(atRate: Float(rate))
        } else {
            playerViewModel.play()
        }
    }
    
    private func selectAudio(_ option: VoDMediaOption) {
        guard let group = audioGroup, let avOption = option.option else { return }
        playerViewModel.player.currentItem?.select(avOption, in: group)
        selectedAudioID = option.id
    }
    
    private func selectSubtitle(_ option: VoDMediaOption?) {
        guard let group = subtitleGroup else { return }
        if let avOption = option?.option {
            playerViewModel.player.currentItem?.select(avOption, in: group)
            selectedSubtitleID = option?.id
        } else {
            playerViewModel.player.currentItem?.select(nil, in: group)
            selectedSubtitleID = nil
        }
    }
    
    private func refreshMediaOptions() {
        guard let item = playerViewModel.player.currentItem else { return }
        if let audioGroup = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) {
            self.audioGroup = audioGroup
            let selected = item.currentMediaSelection.selectedMediaOption(in: audioGroup)
            audioOptions = audioGroup.options.map { option in
                VoDMediaOption.from(option)
            }
            selectedAudioID = selected.map { VoDMediaOption.optionID(for: $0) }
        } else {
            audioOptions = []
            audioGroup = nil
            selectedAudioID = nil
        }
        
        if let subtitleGroup = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
            self.subtitleGroup = subtitleGroup
            let selected = item.currentMediaSelection.selectedMediaOption(in: subtitleGroup)
            subtitleOptions = subtitleGroup.options.map { option in
                VoDMediaOption.from(option)
            }
            selectedSubtitleID = selected.map { VoDMediaOption.optionID(for: $0) }
        } else {
            subtitleOptions = []
            subtitleGroup = nil
            selectedSubtitleID = nil
        }
    }
    
    private var audioMenuLabel: String {
        if let id = selectedAudioID, let option = audioOptions.first(where: { $0.id == id }) {
            return option.title
        }
        return "Audio"
    }
    
    private var subtitleMenuLabel: String {
        if let id = selectedSubtitleID, let option = subtitleOptions.first(where: { $0.id == id }) {
            return option.title
        }
        return "Subtitles (Off)"
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "--:--" }
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
    
    private func dismissPlayer() {
        playerViewModel.cleanup()
        dismiss()
    }
}
#endif

#if os(tvOS)
// MARK: - tvOS Player

private struct TVScrubberView: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var onEditingChanged: (Bool) -> Void
    var step: Double = 5
    @State private var isDragging = false
    @State private var isFocused = false
    @State private var interactionEndWorkItem: DispatchWorkItem?
    
    init(value: Binding<Double>, in range: ClosedRange<Double>, onEditingChanged: @escaping (Bool) -> Void) {
        _value = value
        self.range = range
        self.onEditingChanged = onEditingChanged
    }
    
    var body: some View {
        GeometryReader { geometry in
            let totalWidth = max(geometry.size.width, 1)
            let progress = normalizedRatio()
            let handlePosition = CGFloat(progress) * totalWidth
            
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.25))
                Capsule()
                    .fill(Color.orange)
                    .frame(width: handlePosition)
                Circle()
                    .fill(Color.white)
                    .frame(width: 32, height: 32)
                    .offset(x: min(max(handlePosition - 16, 0), max(totalWidth - 32, 0)))
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            }
            .frame(height: 30)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(isFocused ? Color.white : Color.clear, lineWidth: 2)
            )
            .focusable(true) { focused in
                isFocused = focused
                if !focused {
                    endInteraction()
                }
            }
            .onMoveCommand { direction in
                guard isFocused else { return }
                switch direction {
                case .left:
                    beginInteraction()
                    adjustValue(by: -step)
                case .right:
                    beginInteraction()
                    adjustValue(by: step)
                default:
                    break
                }
            }
        }
        .frame(height: 50)
    }
    
    private func normalizedRatio() -> Double {
        let lower = range.lowerBound
        let upper = range.upperBound
        guard upper > lower else { return 0 }
        let clampedValue = min(max(value, lower), upper)
        let ratio = (clampedValue - lower) / (upper - lower)
        return ratio
    }
    
    private func adjustValue(by delta: Double) {
        let lower = range.lowerBound
        let upper = range.upperBound
        guard upper > lower else {
            value = lower
            return
        }
        let newValue = min(max(value + delta, lower), upper)
        value = newValue
        scheduleInteractionEnd()
    }
    
    private func beginInteraction() {
        guard !isDragging else { return }
        isDragging = true
        onEditingChanged(true)
    }
    
    private func endInteraction() {
        interactionEndWorkItem?.cancel()
        interactionEndWorkItem = nil
        if isDragging {
            isDragging = false
            onEditingChanged(false)
        }
    }
    
    private func scheduleInteractionEnd() {
        interactionEndWorkItem?.cancel()
        let workItem = DispatchWorkItem { endInteraction() }
        interactionEndWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: workItem)
    }
}

private struct TVOSVoDPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var playerViewModel: PlayerViewModel
    private let playerType: VideoPlayerType
    
    @State private var overlayVisible: Bool = true
    @State private var playbackRate: Double = 1.0
    @State private var timeObserver: Any?
    @State private var isScrubbing: Bool = false
    @State private var playbackState = VoDPlaybackState()
    @State private var audioOptions: [VoDMediaOption] = []
    @State private var subtitleOptions: [VoDMediaOption] = []
    @State private var selectedAudioID: String?
    @State private var selectedSubtitleID: String?
    @State private var audioGroup: AVMediaSelectionGroup?
    @State private var subtitleGroup: AVMediaSelectionGroup?
    @FocusState private var focusedControl: TVOSVoDControl?
    
    enum TVOSVoDControl: Hashable {
        case playPause, rewind, forward, timeline, audio, subtitles, speed, dismiss
    }
    
    init(initialChannel: Channel, channelCollection: [Channel]?, playerType: VideoPlayerType) {
        _playerViewModel = StateObject(wrappedValue: PlayerViewModel(channel: initialChannel, preferredPlayer: playerType))
        _ = channelCollection
        self.playerType = playerType
    }
    
    var body: some View {
        ZStack {
            TVAdaptiveVideoContainer(player: playerViewModel.player, aspectMode: .fit)
                .onTapGesture { toggleOverlay() }
                
            if overlayVisible {
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(playerViewModel.currentChannel.name)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                if let plot = playerViewModel.currentChannel.plot {
                                    Text(plot)
                                        .font(.footnote)
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Button(action: dismissPlayer) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 30))
                            }
                            .buttonStyle(.card)
                            .focused($focusedControl, equals: .dismiss)
                        }
                        
                        HStack(alignment: .center, spacing: 14) {
                            Button(action: { skip(by: -15) }) {
                                transportIcon("gobackward.15")
                            }
                            .buttonStyle(.card)
                            .focused($focusedControl, equals: .rewind)
                            
                            Button(action: playerViewModel.togglePlayPause) {
                                transportIcon(playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                            }
                            .buttonStyle(.card)
                            .focused($focusedControl, equals: .playPause)
                            
                            Button(action: { skip(by: 30) }) {
                                transportIcon("goforward.30")
                            }
                            .buttonStyle(.card)
                            .focused($focusedControl, equals: .forward)
                            
                            TVScrubberView(
                                value: Binding(
                                    get: { playbackState.currentTime },
                                    set: { playbackState.currentTime = $0 }
                                ),
                                in: 0...max(playbackState.totalDuration, 1),
                                onEditingChanged: { editing in
                                    isScrubbing = editing
                                    if !editing { seek(to: playbackState.currentTime) }
                                }
                            )
                            .frame(minWidth: 200, maxWidth: 400)
                            .focused($focusedControl, equals: .timeline)
                            
                            Menu {
                                ForEach(audioOptions) { option in
                                    Button(option.title) { selectAudio(option) }
                                }
                            } label: {
                                Label("Audio (\(audioOptions.count))", systemImage: "waveform")
                                    .font(.footnote.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.card)
                            .focused($focusedControl, equals: .audio)
                            
                            Menu {
                                Button("Off") { selectSubtitle(nil) }
                                ForEach(subtitleOptions) { option in
                                    Button(option.title) { selectSubtitle(option) }
                                }
                            } label: {
                                Label("Subs (\(subtitleOptions.count))", systemImage: "captions.bubble")
                                    .font(.footnote.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.card)
                            .focused($focusedControl, equals: .subtitles)
                            
                            Menu {
                                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                                    Button("\(rate, specifier: "%.2g")x") { setPlaybackRate(rate) }
                                }
                            } label: {
                                Label("Speed", systemImage: "speedometer")
                                    .font(.footnote.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.card)
                            .focused($focusedControl, equals: .speed)
                        }
                        .focusSection()
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color.black.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .padding(.horizontal, 32)
                    .padding(.bottom, 36)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            if playerViewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.8)
                    .tint(.white)
            }
        }
        .onAppear {
            print("[tvOS VoD] onAppear called")
            configureTimeObserver()
            refreshMediaOptions()
            focusedControl = .playPause
        }
        .onDisappear {
            removeTimeObserver()
            playerViewModel.cleanup()
        }
        .onReceive(playerViewModel.$currentChannel) { channel in
            print("[tvOS VoD] currentChannel changed: \(channel.name)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                refreshMediaOptions()
            }
        }
        .onPlayPauseCommand { playerViewModel.togglePlayPause() }
        .onExitCommand { dismissPlayer() }
    }
    
    private func transportIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 22, weight: .semibold))
            .frame(width: 56, height: 56)
            .background(Color.white.opacity(0.2))
            .clipShape(Circle())
            .foregroundColor(.white)
    }
    
    private func tvOSMenu<T: View>(title: String, systemImage: String, control: TVOSVoDControl, @ViewBuilder content: @escaping () -> T) -> some View {
        Menu {
            content()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.callout.bold())
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.2))
                .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .focused($focusedControl, equals: control)
    }
    
    // Shared logic with iOS version
    private func configureTimeObserver() {
        guard timeObserver == nil else { return }
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = playerViewModel.player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { _ in
            guard !isScrubbing else { return }
            let current = playerViewModel.player.currentTime().seconds
            if current.isFinite {
                playbackState.currentTime = current
            }
            if let duration = playerViewModel.player.currentItem?.duration.seconds, duration.isFinite {
                playbackState.totalDuration = max(duration, 1)
            }
        }
    }
    
    private func removeTimeObserver() {
        if let token = timeObserver {
            playerViewModel.player.removeTimeObserver(token)
            timeObserver = nil
        }
    }
    
    private func seek(to seconds: Double) {
        let cmTime = CMTime(seconds: seconds, preferredTimescale: 600)
        playerViewModel.player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    private func skip(by offset: Double) {
        let current = playerViewModel.player.currentTime().seconds
        let upperBound = playbackState.totalDuration
        let newTime = min(max(0, current + offset), upperBound)
        playbackState.currentTime = newTime
        seek(to: newTime)
    }
    
    private func setPlaybackRate(_ rate: Double) {
        playbackRate = rate
        playerViewModel.player.playImmediately(atRate: Float(rate))
        playerViewModel.isPlaying = true
    }
    
    private func selectAudio(_ option: VoDMediaOption) {
        guard let group = audioGroup, let avOption = option.option else { return }
        playerViewModel.player.currentItem?.select(avOption, in: group)
        selectedAudioID = option.id
    }
    
    private func selectSubtitle(_ option: VoDMediaOption?) {
        guard let group = subtitleGroup else { return }
        if let avOption = option?.option {
            playerViewModel.player.currentItem?.select(avOption, in: group)
            selectedSubtitleID = option?.id
        } else {
            playerViewModel.player.currentItem?.select(nil, in: group)
            selectedSubtitleID = nil
        }
    }
    
    private func refreshMediaOptions() {
        print("[tvOS VoD] refreshMediaOptions called")
        guard let item = playerViewModel.player.currentItem else {
            print("[tvOS VoD] No currentItem")
            return
        }
        print("[tvOS VoD] currentItem exists: \(item)")
        
        if let audioGroup = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) {
            self.audioGroup = audioGroup
            let selected = item.currentMediaSelection.selectedMediaOption(in: audioGroup)
            audioOptions = audioGroup.options.map { VoDMediaOption.from($0) }
            selectedAudioID = selected.map { VoDMediaOption.optionID(for: $0) }
            print("[tvOS VoD] Audio options loaded: \(audioOptions.count) options")
        } else {
            audioOptions = []
            audioGroup = nil
            selectedAudioID = nil
            print("[tvOS VoD] No audio group found")
        }
        
        if let subtitleGroup = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
            self.subtitleGroup = subtitleGroup
            let selected = item.currentMediaSelection.selectedMediaOption(in: subtitleGroup)
            subtitleOptions = subtitleGroup.options.map { VoDMediaOption.from($0) }
            selectedSubtitleID = selected.map { VoDMediaOption.optionID(for: $0) }
            print("[tvOS VoD] Subtitle options loaded: \(subtitleOptions.count) options")
        } else {
            subtitleOptions = []
            subtitleGroup = nil
            selectedSubtitleID = nil
            print("[tvOS VoD] No subtitle group found")
        }
    }
    
    private func toggleOverlay() {
        withAnimation { overlayVisible.toggle() }
    }
    
    private func dismissPlayer() {
        playerViewModel.cleanup()
        dismiss()
    }
}
#endif
