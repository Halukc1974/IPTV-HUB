import SwiftUI
import AVKit

#if os(iOS)
struct iOSPlayerView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @EnvironmentObject var playlistManager: PlaylistManager
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var playerViewModel: PlayerViewModel
    private let channelCollection: [Channel]?
    private let playerType: VideoPlayerType
    @State private var selectedIndex: Int = 0
    @State private var selectedAspectRatio: AspectRatioMode = .original
    
    // UI States
    @State private var overlayVisible: Bool = false
    @State private var showChannelList: Bool = false
    @State private var showCategorySheet: Bool = false
    @State private var showAspectRatioSheet: Bool = false
    @State private var showDetailsPanel: Bool = false
    @State private var showSupportHelp: Bool = false
    
    // Auto-Hide Task
    @State private var hideOverlayTask: Task<Void, Never>?
    
    init(initialChannel: Channel, channelCollection: [Channel]? = nil, playerType: VideoPlayerType) {
        _playerViewModel = StateObject(wrappedValue: PlayerViewModel(channel: initialChannel, preferredPlayer: playerType))
        self.channelCollection = channelCollection
        self.playerType = playerType
    }
    
    private var playbackChannels: [Channel] {
        let override = channelCollection?.ensuringContains(playerViewModel.currentChannel)
        if let override, !override.isEmpty {
            return override
        }
        let liveChannels = viewModel.channels.ensuringContains(playerViewModel.currentChannel)
        return liveChannels.isEmpty ? [playerViewModel.currentChannel] : liveChannels
    }
    
    var body: some View {
        ZStack {
            // 1. VIDEO LAYER (Sabit)
            iOSVideoPlayerRepresentable(
                player: playerViewModel.player,
                videoGravity: selectedAspectRatio.videoGravity,
                allowsExternalPlayback: playerType == .avKit
            )
            .ignoresSafeArea()
            .onTapGesture { toggleOverlay() }
            
            // 2. SWIPE LAYER (Kanal Geçişi)
            let channels = playbackChannels
            TabView(selection: $selectedIndex) {
                ForEach(channels.indices, id: \.self) { index in
                    Color.clear // Video görünür kalsın diye şeffaf
                        .tag(index)
                        .contentShape(Rectangle())
                        .onTapGesture { toggleOverlay() }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .disabled(overlayVisible || showChannelList) // Overlay açıkken swipe disable
            
            // 3. OVERLAY (Senin Tasarımın)
            if overlayVisible {
                iOSControlsOverlay(
                    channel: getCurrentChannel(),
                    playerType: playerType,
                    playerViewModel: playerViewModel,
                    showChannelList: $showChannelList,
                    showCategorySheet: $showCategorySheet,
                    showAspectRatioSheet: $showAspectRatioSheet,
                    showDetailsPanel: $showDetailsPanel,
                    showSupportHelp: $showSupportHelp,
                    onDismiss: {
                        playerViewModel.cleanup()
                        dismiss()
                    }
                )
                .transition(.opacity)
                .zIndex(2)
            }
            
            // 4. LOADING
            if playerViewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
                    .allowsHitTesting(false)
            }
            
            // 5. CHANNEL LIST (Overlay)
            if showChannelList {
                iOSChannelListOverlay(
                    channels: playbackChannels,
                    currentChannel: playerViewModel.currentChannel,
                    isPresented: $showChannelList,
                    onSelect: { channel in
                        if let index = playbackChannels.firstIndex(where: { $0.id == channel.id }) {
                            selectedIndex = index
                        }
                    }
                )
                .zIndex(3)
                .transition(.move(edge: .leading))
            }
        }
        // iOS SHEET MENÜLERİ
        .sheet(isPresented: $showAspectRatioSheet) {
            iOSAspectRatioSheet(selectedMode: $selectedAspectRatio)
        }
        .sheet(isPresented: $showCategorySheet) {
            iOSCategorySheet(
                categories: playlistManager.categories,
                channel: Binding(
                    get: { playerViewModel.currentChannel },
                    set: { playerViewModel.currentChannel = $0 }
                ),
                viewModel: viewModel
            )
        }
        .sheet(isPresented: $showSupportHelp) {
            NavigationView {
                SupportDetailView(topic: .help)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showSupportHelp = false }
                        }
                    }
            }
        }
        // DEBOUNCE LOGIC (Ağ Koruması)
        .task(id: selectedIndex) {
            let channels = playbackChannels
            guard channels.indices.contains(selectedIndex) else { return }
            if selectedIndex != channels.firstIndex(where: { $0.id == playerViewModel.currentChannel.id }) {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5sn bekle
                if !Task.isCancelled {
                    let channel = channels[selectedIndex]
                    await MainActor.run {
                        playerViewModel.loadChannel(channel, debounce: false)
                        overlayVisible = true
                        scheduleAutoHide()
                    }
                }
            }
        }
        .onAppear {
            let channels = playbackChannels
            if let index = channels.firstIndex(where: { $0.id == playerViewModel.currentChannel.id }) {
                selectedIndex = index
            } else {
                selectedIndex = 0
            }
            toggleOverlay()
        }
        .onDisappear { playerViewModel.cleanup() }
    }
    
    private func getCurrentChannel() -> Channel {
        let channels = playbackChannels
        if channels.indices.contains(selectedIndex) {
            return channels[selectedIndex]
        }
        return playerViewModel.currentChannel
    }
    
    private func toggleOverlay() {
        withAnimation { overlayVisible.toggle() }
        if overlayVisible { scheduleAutoHide() } else { hideOverlayTask?.cancel() }
    }
    
    private func scheduleAutoHide() {
        hideOverlayTask?.cancel()
        hideOverlayTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled { withAnimation { overlayVisible = false } }
        }
    }
}

// MARK: - iOS SPECIFIC UI COMPONENTS

struct iOSVideoPlayerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    let videoGravity: AVLayerVideoGravity
    let allowsExternalPlayback: Bool
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.videoGravity = videoGravity
        controller.showsPlaybackControls = false
        controller.view.backgroundColor = .black
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        player.allowsExternalPlayback = allowsExternalPlayback
        return controller
    }
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player != player { uiViewController.player = player }
        if uiViewController.videoGravity != videoGravity { uiViewController.videoGravity = videoGravity }
        player.allowsExternalPlayback = allowsExternalPlayback
    }
}

struct iOSControlsOverlay: View {
    let channel: Channel
    let playerType: VideoPlayerType
    @ObservedObject var playerViewModel: PlayerViewModel
    @Binding var showChannelList: Bool
    @Binding var showCategorySheet: Bool
    @Binding var showAspectRatioSheet: Bool
    @Binding var showDetailsPanel: Bool
    @Binding var showSupportHelp: Bool
    let onDismiss: () -> Void
    
    private var volumeBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(playerViewModel.volume) },
            set: { playerViewModel.setVolume(Float($0)) }
        )
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // iOS'ta overlay'e tap yapınca kapanmasın, sadece auto-hide
                }
            
            VStack {
                // ÜST KISIM
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(channel.name).font(.headline).foregroundColor(.white)
                        Text("Live TV").font(.caption).foregroundColor(.green)
                        Text(playerType.rawValue)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.45))
                            .cornerRadius(6)
                    }
                    .padding(.top, 30)
                    .padding(.leading, 30)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        iOSVolumeSlider(value: volumeBinding, isMuted: playerViewModel.isMuted)
                            .frame(width: 220)
                            .padding(.leading, 10)
                        
                        // Buton Grubu (Sağ Üst)
                        HStack(spacing: 8) {
                        Button(action: { playerViewModel.toggleMute() }) {
                            Image(systemName: playerViewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 55, height: 55)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                        
                        Button(action: { showAspectRatioSheet = true }) {
                            Image(systemName: "aspectratio")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 55, height: 55)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                        
                        Button(action: { showCategorySheet = true }) {
                            Image(systemName: "heart")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 55, height: 55)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                        
                        Button(action: { withAnimation { showChannelList = true } }) {
                            Image(systemName: "list.bullet")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 55, height: 55)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                        
                        Button(action: onDismiss) {
                            Image(systemName: "house.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 55, height: 55)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                    }
                    .padding(.top, 30)
                    .padding(.trailing, 30)
                }
                
                Spacer()
                
                // ALT KISIM
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
                    
                    HStack(spacing: 16) {
                        Button(action: { withAnimation { showDetailsPanel.toggle() } }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                        
                        Button(action: {
                            showSupportHelp = true
                        }) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .padding(.trailing, 30)
                    .padding(.bottom, 20)
                }
            }
            .ignoresSafeArea(.all, edges: .bottom)
        }
    }
}

// iOS Sheets
struct iOSAspectRatioSheet: View {
    @Binding var selectedMode: AspectRatioMode
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            List(AspectRatioMode.allCases) { mode in
                Button { selectedMode = mode; dismiss() } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(mode.rawValue)
                            Text(mode.hint).font(.caption).foregroundColor(.gray)
                        }
                        Spacer()
                        if selectedMode == mode { Image(systemName: "checkmark") }
                    }
                }
            }.navigationTitle("Aspect Ratio")
        }
    }
}

struct iOSVolumeSlider: View {
    @Binding var value: Double
    let isMuted: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Volume")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            HStack(spacing: 10) {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .foregroundColor(.white)
                Slider(value: $value, in: 0...1, step: 0.01)
                    .tint(.orange)
            }
        }
    }
}

struct iOSCategorySheet: View {
    let categories: [ChannelCategory]
    @Binding var channel: Channel
    @ObservedObject var viewModel: MainViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if categories.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("No categories yet")
                            .font(.headline)
                        Text("Create categories from the Playlists tab, then come back to add this channel.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
                } else {
                    ForEach(categories) { category in
                        Button {
                            if let updatedChannel = viewModel.toggleChannel(channel, inCategory: category) {
                                channel = updatedChannel
                            }
                        } label: {
                            HStack {
                                Text(category.name)
                                Spacer()
                                if channel.categoryIDs.contains(category.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct iOSChannelListOverlay: View {
    let channels: [Channel]
    let currentChannel: Channel
    @Binding var isPresented: Bool
    let onSelect: (Channel) -> Void
    @State private var searchText = ""
    @AppStorage("channelOverlayOpacity") private var channelOverlayOpacity: Double = 0.9
    
    private var filteredChannels: [Channel] {
        if searchText.isEmpty { return channels }
        return channels.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { withAnimation { isPresented = false } }
            
            VStack(spacing: 0) {
                // Sabit Search Bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search channels...", text: $searchText)
                        .foregroundColor(.black)
                        .tint(Color.orange)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
                .padding(16)
                .background(Color(red: 0.9, green: 0.9, blue: 0.93))
                .padding(.top, 50)
                
                Rectangle().fill(Color.orange).frame(height: 1)
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredChannels) { channel in
                            VStack(spacing: 0) {
                                Button {
                                    onSelect(channel)
                                    withAnimation { isPresented = false }
                                } label: {
                                    HStack {
                                        Text(channel.name)
                                            .foregroundColor(.white)
                                        Spacer()
                                        if channel.id == currentChannel.id {
                                            Image(systemName: "waveform")
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    .padding()
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Rectangle().fill(Color.orange).frame(height: 1)
                            }
                        }
                    }
                }
            }
            .frame(width: 500)
            .background(Color.black.opacity(channelOverlayOpacity))
            .edgesIgnoringSafeArea(.all)
        }
    }
}
#endif
