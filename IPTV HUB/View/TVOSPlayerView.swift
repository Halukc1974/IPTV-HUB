import SwiftUI
import AVKit

// DİKKAT: Channel, MainViewModel, PlaylistManager, PlayerViewModel ve ChannelCategory
// yapıları projenizin DİĞER dosyalarından gelmelidir.
// AspectRatioMode, PlayerControlFocus ve PlayerFocusArea artık PlayerSharedModels'dan gelmektedir.

#if os(tvOS)

// MARK: - 1. TV PLAYER VIEW (MAIN CONTAINER)
struct TVOSPlayerView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @EnvironmentObject var playlistManager: PlaylistManager
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var playerViewModel: PlayerViewModel
    private let channelCollection: [Channel]?
    private let playerType: VideoPlayerType
    
    @State private var selectedIndex: Int = 0
    @State private var selectedAspectRatio: AspectRatioMode = .original
    
    @State private var overlayVisible: Bool = false
    @State private var showChannelList: Bool = false
    @State private var showCategorySelector: Bool = false
    @State private var showAspectRatioPicker: Bool = false
    @State private var showDetailsPanel: Bool = false
    
    @FocusState private var focusArea: PlayerFocusArea?
    
    init(initialChannel: Channel, channelCollection: [Channel]? = nil, playerType: VideoPlayerType) {
        _playerViewModel = StateObject(wrappedValue: PlayerViewModel(channel: initialChannel, preferredPlayer: playerType))
        self.channelCollection = channelCollection
        self.playerType = playerType
    }
    
    private var playbackChannels: [Channel] {
        let source: [Channel]
        if let override = channelCollection?.ensuringContains(playerViewModel.currentChannel), !override.isEmpty {
            source = override
        } else {
            let base = viewModel.channels.ensuringContains(playerViewModel.currentChannel)
            source = base.isEmpty ? [playerViewModel.currentChannel] : base
        }
        return deduplicatedChannels(source)
    }

    /// Deduplicate channels per playlist so a channel appears only once within the same playlist.
    /// Uses tvgId when available, otherwise a normalized name.
    private func deduplicatedChannels(_ channels: [Channel]) -> [Channel] {
        var seen: Set<String> = []
        var result: [Channel] = []
        for ch in channels {
            let playlistKey = ch.playlistID?.uuidString ?? "no-playlist"
            let nameKey = ch.tvgId.isEmpty ? ch.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) : ch.tvgId.lowercased()
            let key = playlistKey + "|" + nameKey
            if !seen.contains(key) {
                seen.insert(key)
                result.append(ch)
            }
        }
        return result
    }
    
    private var isModalPresented: Bool { showChannelList || showCategorySelector || showAspectRatioPicker }
    
    var body: some View {
        ZStack {
            // LAYER 1: VIDEO PLAYER
            TVAdaptiveVideoContainer(
                player: playerViewModel.player,
                aspectMode: selectedAspectRatio
            )
            .focusable(!overlayVisible && !isModalPresented)
            
            // LAYER 2: ZAPPING (SWIPE) LAYER
            let channels = playbackChannels
            TabView(selection: $selectedIndex) {
                ForEach(channels.indices, id: \.self) { index in
                    Button(action: { toggleOverlay() }) {
                        Color.clear
                    }
                    .buttonStyle(.card)
                    .opacity(0.02)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .disabled(overlayVisible || isModalPresented)
            .focused($focusArea, equals: .zapping)
            
            // LAYER 3: CONTROLS OVERLAY
            if overlayVisible {
                TVControlsOverlay(
                    channel: getCurrentChannel(),
                    playerStyle: playerType,
                    playerViewModel: playerViewModel,
                    overlayVisible: $overlayVisible,
                    showChannelList: $showChannelList,
                    showCategorySelector: $showCategorySelector,
                    showAspectRatioPicker: $showAspectRatioPicker,
                    showDetailsPanel: $showDetailsPanel,
                    onDismiss: {
                        playerViewModel.cleanup()
                        dismiss()
                    }
                )
                .transition(.opacity)
                .zIndex(2)
                .focused($focusArea, equals: .controls)
            }
            
            // LAYER 4: MODALS & SIDEBARS
            
            // A. CHANNEL LIST (SOL TARAFTAN AÇILIŞ)
            if showChannelList {
                HStack(spacing: 0) {
                    TVChannelListOverlay(
                        channels: playbackChannels,
                        currentChannel: playerViewModel.currentChannel,
                        isPresented: $showChannelList,
                        onSelect: { channel in
                            changeChannel(to: channel)
                        },
                        onPlayPauseTrigger: {
                            if overlayVisible {
                                toggleOverlay()
                            }
                        }
                    )
                    .frame(width: 550)
                    .transition(.move(edge: .leading))
                    .zIndex(3)
                    
                    Spacer()
                }
                .focused($focusArea, equals: .modals)
            }
            
            // B. ASPECT RATIO PICKER
            if showAspectRatioPicker {
                TVAspectRatioPicker(selected: $selectedAspectRatio, isPresented: $showAspectRatioPicker).zIndex(4)
                    .focused($focusArea, equals: .modals)
            }
            
            // C. CATEGORY SELECTOR
            if showCategorySelector {
                TVCategorySelector(
                    categories: playlistManager.categories,
                    channel: playerViewModel.currentChannel,
                    isPresented: $showCategorySelector,
                    viewModel: viewModel
                ) { updatedChannel in
                    playerViewModel.currentChannel = updatedChannel
                }
                .zIndex(4)
                .focused($focusArea, equals: .modals)
            }
            
            // LOADING INDICATOR
            if playerViewModel.isLoading {
                ProgressView()
                    .scaleEffect(2.0)
                    .allowsHitTesting(false)
            }
        }
        // --- LOGIC & EVENTS ---
        .task(id: selectedIndex) {
            let channels = playbackChannels
            guard channels.indices.contains(selectedIndex) else { return }
            if selectedIndex != channels.firstIndex(where: { $0.id == playerViewModel.currentChannel.id }) {
                 try? await Task.sleep(nanoseconds: 300_000_000)
                 if !Task.isCancelled {
                     let channel = channels[selectedIndex]
                     await MainActor.run {
                         playerViewModel.loadChannel(channel, debounce: false)
                     }
                 }
            }
        }
        .onAppear {
            let channels = playbackChannels
            if let index = channels.firstIndex(where: { $0.id == playerViewModel.currentChannel.id }) {
                selectedIndex = index
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { focusArea = .zapping }
        }
        .onDisappear {
            // Ensure playback stops when the player view is dismissed via system gestures
            playerViewModel.cleanup()
        }
        // FOCUS YÖNETİMİ
        .onChange(of: overlayVisible) { isVisible in
            if isVisible {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focusArea = .controls }
            } else if !isModalPresented {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focusArea = .zapping }
            }
        }
        .onChange(of: isModalPresented) { isPresented in
            if isPresented { focusArea = .modals }
            else if overlayVisible { focusArea = .controls }
            else { focusArea = .zapping }
        }
        // KUMANDA KOMUTLARI
        .onPlayPauseCommand { toggleOverlay() }
        .onExitCommand {
            if isModalPresented { closeModals() }
            else if overlayVisible { toggleOverlay() }
            else { dismiss() }
        }
        .onMoveCommand { _ in
            if !overlayVisible && !isModalPresented { toggleOverlay() }
        }
    }
    
    // MARK: - Helpers
    private func getCurrentChannel() -> Channel { playerViewModel.currentChannel }
    
    private func closeModals() {
        withAnimation {
            showChannelList = false; showCategorySelector = false; showAspectRatioPicker = false
        }
        overlayVisible = true
    }
    
    private func toggleOverlay() {
        withAnimation { overlayVisible.toggle() }
    }
    
    private func changeChannel(to channel: Channel) {
        let channels = playbackChannels
        if let index = channels.firstIndex(where: { $0.id == channel.id }) {
            selectedIndex = index
            playerViewModel.loadChannel(channel, debounce: false)
        }
        showChannelList = false
    }
}

// MARK: - 3. CONTROLS OVERLAY (tvOS) - DİL DÜZELTİLDİ
struct TVControlsOverlay: View {
    let channel: Channel
    let playerStyle: VideoPlayerType
    @ObservedObject var playerViewModel: PlayerViewModel
    @Binding var overlayVisible: Bool
    
    @Binding var showChannelList: Bool
    @Binding var showCategorySelector: Bool
    @Binding var showAspectRatioPicker: Bool
    @Binding var showDetailsPanel: Bool
    let onDismiss: () -> Void
    
    @FocusState private var focusedControl: PlayerControlFocus? // ControlFocus -> PlayerControlFocus
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            
            VStack {
                // ÜST BAR
                HStack(alignment: .top) {
                    if !showChannelList { // hide top-left info when channel list/search is open
                        VStack(alignment: .leading, spacing: 6) {
                            Text(playerStyle.rawValue)
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(10)
                        }
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(channel.name).font(.subheadline).foregroundColor(.white)
                            Text("Live Broadcast").font(.caption2).foregroundColor(.green)
                        }
                        .padding(.trailing, 20)
                    } else {
                        Spacer()
                    }
                    
                    // BUTONLAR (SAĞ ÜST)
                    HStack(spacing: 12) {
                        TVBarButton(iconName: playerViewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", isFocused: focusedControl == .mute) { playerViewModel.toggleMute() }
                            .focused($focusedControl, equals: .mute)
                        
                        TVBarButton(iconName: "aspectratio", isFocused: focusedControl == .aspect) { withAnimation { showAspectRatioPicker.toggle() } }
                            .focused($focusedControl, equals: .aspect)
                        
                        TVBarButton(iconName: "heart", isFocused: focusedControl == .category) { withAnimation { showCategorySelector.toggle() } } // fav -> category
                            .focused($focusedControl, equals: .category) // fav -> category
                        
                        TVBarButton(iconName: "list.bullet", isFocused: focusedControl == .epg) { withAnimation { showChannelList.toggle() } }
                            .focused($focusedControl, equals: .epg)
                        
                        TVBarButton(iconName: "house.fill", isFocused: focusedControl == .home) { onDismiss() }
                            .focused($focusedControl, equals: .home)
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .focusSection() // Kilitlenme Çözümü
                }
                .padding(.top, 50)
                .padding(.trailing, 60)
                .padding(.leading, 60)
                
                Spacer()
                
                // ALT BAR
                HStack(alignment: .bottom) {
                    if showDetailsPanel {
                        HStack(alignment: .top, spacing: 20) {
                            VStack(alignment: .leading) {
                                Text("Program Info").font(.subheadline).bold()
                                Text("Channel Group: \(channel.group)").font(.caption)
                                Text("Current Program: Live Broadcast").font(.caption)
                            }
                            .padding(12)
                            .background(Color.black.opacity(0.85))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            
                            VStack(alignment: .leading) {
                                Text("Video Details").font(.subheadline).bold()
                                Text("Resolution: 1920x1080").font(.caption)
                                Text("Codec: H.264").font(.caption)
                            }
                            .padding(12)
                            .background(Color.black.opacity(0.85))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding(.leading, 30)
                        .padding(.bottom, 20)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 18) {
                        TVCircleButton(iconName: "info.circle", isFocused: focusedControl == .info) {
                            withAnimation { showDetailsPanel.toggle() }
                        }
                        .focused($focusedControl, equals: .info)
                        
                    }
                    .padding(.bottom, 50)
                    .padding(.trailing, 60)
                }
            }
        }
        .onAppear { focusedControl = .mute }
    }
}

// MARK: - 4. CHANNEL LIST OVERLAY (SOL TARAFTAN AÇILIŞ VE TASARIM DÜZELTMELERİ)
struct TVChannelListOverlay: View {
    let channels: [Channel]
    let currentChannel: Channel
    @Binding var isPresented: Bool
    let onSelect: (Channel) -> Void
    let onPlayPauseTrigger: () -> Void
    
    @State private var searchText: String = ""
    @AppStorage("channelOverlayOpacity") private var channelOverlayOpacity: Double = 0.9
    @FocusState private var focusedChannelID: String?
    @Environment(\.tabSearchResetToken) private var tabSearchResetToken
    
    var filteredChannels: [Channel] {
        if searchText.isEmpty { return channels }
        return channels.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // A. SABİT SEARCH BAR (ENGLISH)
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search Channels...", text: $searchText) // DİL: ENG
                        .textFieldStyle(.plain)
                        .foregroundColor(.black)
                        .onSubmit {
                            onPlayPauseTrigger()
                        }
                }

                
                
                .padding(20)
                .background(Color(red: 0.9, green: 0.9, blue: 0.93))
                .cornerRadius(12)
                
                // B. TURUNCU AYIRICI ÇİZGİ (iOS ile aynı)
                Rectangle()
                    .fill(Color.orange)
                    .frame(height: 1)
            }
            
            // C. KANAL LİSTESİ
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredChannels, id: \.id) { channel in
                            Button(action: {
                                onSelect(channel)
                            }) {
                                HStack {
                                    Text(channel.name)
                                        .font(.body)
                                        .foregroundColor(focusedChannelID == channel.id.uuidString ? .black : .white)
                                    
                                    Spacer()
                                    
                                    if channel.id == currentChannel.id {
                                        Image(systemName: "waveform")
                                            .foregroundColor(focusedChannelID == channel.id.uuidString ? .black : .orange)
                                    }
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 20)
                                .background(
                                    ZStack {
                                        if focusedChannelID == channel.id.uuidString {
                                            Color.white // Odaklanınca Beyaz
                                        } else {
                                            Color.clear // Normalde Şeffaf
                                        }
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                            .focused($focusedChannelID, equals: channel.id.uuidString)
                            
                            // D. KANALLAR ARASI TURUNCU ÇİZGİ (İnce)
                            Rectangle()
                                .fill(Color.orange.opacity(0.6))
                                .frame(height: 1)
                        }
                    }
                }
                .onAppear {
                    // List açılınca o anki kanala scroll et ve odaklan
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        let targetID = currentChannel.id.uuidString
                        proxy.scrollTo(targetID, anchor: .center)
                        focusedChannelID = targetID
                    }
                }
            }
        }
        .background(Color.black.opacity(channelOverlayOpacity)) // E. TRANSPARENT SİYAH ARKA PLAN
        .edgesIgnoringSafeArea(.vertical)
        .onChange(of: tabSearchResetToken) { _ in
            searchText = ""
        }
    }
}

// MARK: - 5. CUSTOM BUTTON STYLES (NAVİGASYON KİLİTLENMESİNİ ÇÖZEN YAPI)

struct TVBarButton: View {
    let iconName: String
    let isFocused: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundColor(isFocused ? .black : .white)
        }
        .buttonStyle(TVFixedFrameButtonStyle(isFocused: isFocused))
    }
}

struct TVFixedFrameButtonStyle: ButtonStyle {
    let isFocused: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(12)
            .background(
                ZStack {
                    if isFocused {
                        Circle()
                            .fill(Color.white)
                            .shadow(radius: 5)
                            .transition(.opacity)
                    }
                }
            )
            // GÖRSEL BÜYÜME (Layout'u etkilemez)
            .scaleEffect(isFocused ? 1.2 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFocused)
            // FİZİKSEL ÇERÇEVE (Sabit Kalmalı)
            .frame(width: 60, height: 60)
    }
}

struct TVCircleButton: View {
    let iconName: String
    let isFocused: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 30))
                .foregroundColor(isFocused ? .black : .white)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 70, height: 70)
        .background(Circle().fill(isFocused ? Color.white : Color.black.opacity(0.5)))
        .scaleEffect(isFocused ? 1.1 : 1.0)
        .animation(.spring(), value: isFocused)
    }
}

// MARK: - Adaptive Video Handling

struct TVAdaptiveVideoContainer: View {
    let player: AVPlayer
    let aspectMode: AspectRatioMode
    
    var body: some View {
        if let targetRatio = aspectMode.targetAspectRatio {
            GeometryReader { proxy in
                let containerSize = proxy.size
                let videoSize = AspectRatioGeometry.calculate(
                    container: containerSize,
                    targetRatio: targetRatio,
                    letterboxed: aspectMode.prefersLetterboxedFit
                )
                ZStack {
                    Color.black.ignoresSafeArea()
                    TVVideoPlayerRepresentable(
                        player: player,
                        videoGravity: aspectMode.videoGravity
                    )
                    .frame(width: videoSize.width, height: videoSize.height)
                    .clipped()
                }
                .frame(width: containerSize.width, height: containerSize.height)
            }
            .ignoresSafeArea()
        } else {
            ZStack {
                Color.black.ignoresSafeArea()
                TVVideoPlayerRepresentable(
                    player: player,
                    videoGravity: aspectMode.videoGravity
                )
            }
            .ignoresSafeArea()
        }
    }
}

private enum AspectRatioGeometry {
    static func calculate(container: CGSize, targetRatio: CGFloat, letterboxed: Bool) -> CGSize {
        guard container.width > 0, container.height > 0 else { return container }
        let containerRatio = container.width / container.height
        if letterboxed {
            if containerRatio > targetRatio {
                let height = container.height
                return CGSize(width: height * targetRatio, height: height)
            } else {
                let width = container.width
                return CGSize(width: width, height: width / targetRatio)
            }
        } else {
            if containerRatio > targetRatio {
                let width = container.width
                return CGSize(width: width, height: width / targetRatio)
            } else {
                let height = container.height
                return CGSize(width: height * targetRatio, height: height)
            }
        }
    }
}

// MARK: - 6. HELPER COMPONENTS

struct TVVideoPlayerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    let videoGravity: AVLayerVideoGravity
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.videoGravity = videoGravity
        controller.showsPlaybackControls = false // Native kontrolleri kapat
        controller.view.backgroundColor = .black
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player != player { uiViewController.player = player }
        if uiViewController.videoGravity != videoGravity { uiViewController.videoGravity = videoGravity }
    }
}

struct TVAspectRatioPicker: View {
    @Binding var selected: AspectRatioMode
    @Binding var isPresented: Bool
    
    var body: some View {
        HStack {
            Spacer()
            VStack {
                Text("Aspect Ratio").font(.headline).padding()
                ForEach(AspectRatioMode.allCases) { mode in
                    Button(action: { selected = mode; isPresented = false }) {
                        HStack { Text(mode.rawValue); Spacer(); if selected == mode { Image(systemName: "checkmark") } }
                    }.buttonStyle(.card)
                }
            }.frame(width: 450).background(Color.black.opacity(0.95))
        }
    }
}

struct TVCategorySelector: View {
    let categories: [ChannelCategory]
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: MainViewModel
    @State private var workingChannel: Channel
    let onChannelUpdate: (Channel) -> Void
    @FocusState private var focusedCategoryID: String?

    init(categories: [ChannelCategory], channel: Channel, isPresented: Binding<Bool>, viewModel: MainViewModel, onChannelUpdate: @escaping (Channel) -> Void) {
        self.categories = categories
        self._isPresented = isPresented
        self.viewModel = viewModel
        self._workingChannel = State(initialValue: channel)
        self.onChannelUpdate = onChannelUpdate
    }

    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .leading, spacing: 0) {
                Text("Categories")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.top, 30)
                    .padding(.bottom, 16)
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(categories) { cat in
                            let isSelected = workingChannel.categoryIDs.contains(cat.id)
                            let isFocused = focusedCategoryID == cat.id
                            Button {
                                if let updatedChannel = viewModel.toggleChannel(workingChannel, inCategory: cat) {
                                    workingChannel = updatedChannel
                                    onChannelUpdate(updatedChannel)
                                }
                            } label: {
                                HStack {
                                    Text(cat.name)
                                        .font(.body)
                                        .foregroundColor(isFocused ? .green : .white)
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.green)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(isSelected ? 0.9 : (isFocused ? 0.25 : 0.08)))
                                )
                            }
                            .buttonStyle(.card)
                            .focused($focusedCategoryID, equals: cat.id)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .frame(width: 540)
            .padding(.leading, 60)
            .padding(.vertical, 40)
            .background(Color.black.opacity(0.95))
            .cornerRadius(28)
            .shadow(radius: 22)
        }
    }
}
#endif
