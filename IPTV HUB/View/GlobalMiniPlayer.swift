import SwiftUI
import AVKit

final class MiniPlayerManager: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var videoGravity: AVLayerVideoGravity = .resizeAspect
    @Published var position: CGPoint = CGPoint(x: UIScreen.main.bounds.width - 180, y: UIScreen.main.bounds.height - 280)
    @Published var isNativePiPActive: Bool = false
    @Published var pipController: AVPictureInPictureController?
    var currentPlayer: AVPlayer?
    var currentChannel: Channel?
    private var homeHandler: (() -> Void)?
    private var expandHandler: (() -> Void)?
    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?
    private var restoreObserver: NSObjectProtocol?
    private var pipStopObserver: NSObjectProtocol?
    private var shouldRestorePlayer: Bool = false
    private var isRestoringFromPiP: Bool = false

    func setHomeHandler(_ handler: @escaping () -> Void) {
        homeHandler = handler
    }

    func show(player: AVPlayer, channel: Channel, videoGravity: AVLayerVideoGravity, pipController: AVPictureInPictureController?, onExpand: @escaping () -> Void) {
        print("📱 MiniPlayerManager.show called for channel: \(channel.name)")
        currentPlayer = player
        currentChannel = channel
        self.videoGravity = videoGravity
        self.pipController = pipController
        expandHandler = onExpand
        print("🏠 Calling homeHandler to switch tab...")
        homeHandler?() // switch to home immediately when mini is shown
        
        // Setup background observers for native PiP
        setupBackgroundObservers()
        
        // Setup PiP restore observer
        setupPiPObservers()
        
        print("✨ Setting isVisible = true with animation...")
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible = true
        }
        print("✅ Mini player should now be visible: \(isVisible)")
    }
    
    private func setupPiPObservers() {
        // Remove old observers
        if let observer = restoreObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = pipStopObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        print("🔔 Setting up PiP observers...")
        
        // Listen for restore request (right icon tapped in native PiP)
        restoreObserver = NotificationCenter.default.addObserver(
            forName: .init("restoreCustomMiniPlayer"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 Restore custom mini player notification received (right icon)")
            guard let self = self else { return }
            
            // Mark we're actively restoring so any PiP stop notifications are ignored
            self.isRestoringFromPiP = true

            // Manually stop PiP to restore custom player
            if let pipController = self.pipController, pipController.isPictureInPictureActive {
                print("⏹ Manually stopping PiP for restore...")
                pipController.stopPictureInPicture()
                
                // Wait for PiP to fully stop, then show custom player
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    self?.switchToCustomMiniPlayer()
                }
            } else {
                // PiP not active, restore immediately
                self.switchToCustomMiniPlayer()
            }
        }
        
        // Listen for PiP stop (left gear icon - close PiP completely)
        pipStopObserver = NotificationCenter.default.addObserver(
            forName: .pipDidStop,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            print("🛑 PiP stop notification received")
            
            // If we're explicitly restoring custom mini player, ignore this stop event
            if self.isRestoringFromPiP {
                print("ℹ️ PiP stopping as part of custom restore flow; skipping hide")
                self.isNativePiPActive = false
                self.shouldRestorePlayer = false
                self.isRestoringFromPiP = false
                return
            }

            print("❌ PiP stopped outside restore flow - hiding player")
            self.hide(stopPlayback: true)
        }
        
        print("✅ PiP observers set up")
    }
    
    private func setupBackgroundObservers() {
        // Remove old observers first
        removeBackgroundObservers()
        
        print("🔔 Setting up background observers...")
        
        // When app goes to background, switch to native PiP (only if not already in PiP)
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            print("📱 App entered background")
            if !self.isNativePiPActive && self.isVisible {
                print("🔄 Auto-switching to native PiP...")
                self.switchToNativePiP()
            }
        }
        
        // When app comes to foreground, check if we should restore custom player
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            print("📱 App will enter foreground")
            
            // Only restore if native PiP is active and we should restore
            if self.isNativePiPActive && self.shouldRestorePlayer {
                print("🔄 Restoring custom mini player...")
                self.switchToCustomMiniPlayer()
                self.shouldRestorePlayer = false
            }
        }
        
        print("✅ Background observers set up successfully")
    }
    
    private func removeBackgroundObservers() {
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
            backgroundObserver = nil
            print("🗑️ Removed background observer")
        }
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
            foregroundObserver = nil
            print("🗑️ Removed foreground observer")
        }
        if let observer = restoreObserver {
            NotificationCenter.default.removeObserver(observer)
            restoreObserver = nil
            print("🗑️ Removed restore observer")
        }
        if let observer = pipStopObserver {
            NotificationCenter.default.removeObserver(observer)
            pipStopObserver = nil
            print("🗑️ Removed PiP stop observer")
        }
    }
    
    func switchToNativePiP(sendToBackground: Bool = true, attempt: Int = 0) {
        print("🔄 switchToNativePiP called (sendToBackground: \(sendToBackground), attempt: \(attempt))")
        print("   Current state: isNativePiPActive=\(isNativePiPActive), isVisible=\(isVisible)")
        isRestoringFromPiP = false
        
        // Ensure we have a valid PiP controller. If not, drop it and let views rebuild, then retry.
        if pipController == nil || (pipController != nil && pipController?.isPictureInPicturePossible == false) {
            print("⚠️ PiP controller missing or not possible, requesting host recreate and forcing rebuild...")
            pipController = nil
            NotificationCenter.default.post(name: .init("PiPHostRecreateController"), object: nil)
            if attempt < 2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    self?.switchToNativePiP(sendToBackground: sendToBackground, attempt: attempt + 1)
                }
            } else {
                print("❌ PiP controller unavailable after retries")
            }
            return
        }
        guard let pipController = pipController else { return }
        
        // Check if already active
        if pipController.isPictureInPictureActive {
            print("⚠️ Native PiP already active, skipping start")
            if sendToBackground {
                print("📱 Sending to background anyway...")
                #if os(iOS)
                UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
                #endif
            }
            return
        }
        
        // Check if PiP is currently stopping (isNativePiPActive but not isPictureInPictureActive)
        if isNativePiPActive {
            print("⚠️ PiP is in transition state, waiting...")
            // Wait a bit and retry
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.switchToNativePiP(sendToBackground: sendToBackground)
            }
            return
        }
        
        guard pipController.isPictureInPicturePossible else {
            print("⚠️ Native PiP not possible (isPictureInPicturePossible = false)")
            print("   Reason: PiP might be suspended or AVPlayerLayer not ready")
            return
        }
        
        print("🎬 Starting native PiP transition...")
        
        // Mark that we're in native PiP mode
        isNativePiPActive = true
        shouldRestorePlayer = true
        
        // Ensure player is playing
        if let player = currentPlayer {
            print("▶️ Ensuring player is playing...")
            player.play()
        }
        
        // Hide custom mini player first
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        
        // Start PiP with delay — but wait/poll for isPictureInPicturePossible to become true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self = self else { return }

            func attemptStart(attemptsLeft: Int) {
                guard let ctrl = self.pipController else { print("⚠️ No pipController during start attempts"); return }
                if ctrl.isPictureInPicturePossible {
                    print("🚀 Calling startPictureInPicture() (attemptsLeft: \(attemptsLeft))...")
                    ctrl.startPictureInPicture()
                    print("✅ Native PiP start requested, waiting for delegate callback...")
                    return
                }
                if attemptsLeft <= 0 {
                    print("❌ startPictureInPicture failed: controller never became possible")
                    return
                }
                // controller not yet possible — retry shortly
                print("⚠️ startPictureInPicture: controller not yet possible, retrying in 0.25s (\(attemptsLeft) attempts left)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    attemptStart(attemptsLeft: attemptsLeft - 1)
                }
            }

            attemptStart(attemptsLeft: 6)
            
            // Send app to background if requested
            if sendToBackground {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    #if os(iOS)
                    UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
                    print("📱 App sent to background")
                    #endif
                }
            }
        }
    }
    
    func switchToCustomMiniPlayer() {
        print("🔄 switchToCustomMiniPlayer called")
        print("   Current state: isNativePiPActive=\(isNativePiPActive), isVisible=\(isVisible)")
        
        // Reset native PiP state immediately
        isNativePiPActive = false
        shouldRestorePlayer = false
        isRestoringFromPiP = true
        
        // Ensure player is still playing
        if let player = currentPlayer {
            if player.timeControlStatus != .playing {
                print("▶️ Resuming playback...")
                player.play()
            }
        }
        
        guard let pipController = pipController else {
            print("⚠️ PiP controller is nil, showing custom player anyway")
            showCustomMiniPlayer()
            return
        }
        
        // Stop native PiP if active
        if pipController.isPictureInPictureActive {
            print("⏹ Stopping active native PiP...")
            pipController.stopPictureInPicture()
            
            // Wait for PiP to stop, then show custom player
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showCustomMiniPlayer()
            }
        } else {
            print("ℹ️ PiP not active, showing custom player immediately")
            // PiP not active, show custom player immediately
            showCustomMiniPlayer()
        }
    }
    
    private func showCustomMiniPlayer() {
        print("📺 showCustomMiniPlayer called")
        // Ensure state is clean
        isNativePiPActive = false
        shouldRestorePlayer = false
        isRestoringFromPiP = false
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible = true
        }
        print("✅ Custom mini player visible, state: isNativePiPActive=\(isNativePiPActive)")
    }

    func hide(stopPlayback: Bool = true) {
        print("🛑 MiniPlayerManager.hide() called (stopPlayback: \(stopPlayback))")
        
        // Only remove observers when we're stopping playback entirely.
        // For expand (stopPlayback: false) we want observers kept so PiP/restore still works.
        if stopPlayback {
            removeBackgroundObservers()
        }
        
        // Stop native PiP if active
        if let pipController = pipController, pipController.isPictureInPictureActive {
            print("⏹ Stopping active PiP before hiding...")
            pipController.stopPictureInPicture()
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible = false
        }
        
        // Stop playback if requested
        if stopPlayback {
            currentPlayer?.pause()
            currentPlayer?.replaceCurrentItem(with: nil)
            print("⏸ Playback stopped")
            currentPlayer = nil
            currentChannel = nil
        }
        
        // Do NOT nil out pipController; keep it reusable across sessions
        expandHandler = nil
        isNativePiPActive = false
        shouldRestorePlayer = false
        isRestoringFromPiP = false
        
        print("✅ Mini player hidden and cleaned up")
    }

    func expand() {
        expandHandler?()
        // Keep playback alive when expanding to fullscreen
        hide(stopPlayback: false)
    }
    
    func updatePosition(_ newPosition: CGPoint) {
        position = newPosition
    }
}

#if os(iOS)
struct GlobalMiniPlayerOverlay: View {
    let player: AVPlayer
    let channel: Channel
    let videoGravity: AVLayerVideoGravity
    let onClose: () -> Void
    let onExpand: () -> Void
    let onBackground: () -> Void
    @Binding var pipController: AVPictureInPictureController?
    
    @State private var currentPosition: CGPoint
    @State private var isDragging: Bool = false
    
    private let playerWidth: CGFloat = 280
    private let playerHeight: CGFloat = 160
    private let edgeMargin: CGFloat = 16
    
    init(player: AVPlayer, channel: Channel, videoGravity: AVLayerVideoGravity, position: CGPoint, pipController: Binding<AVPictureInPictureController?>, onClose: @escaping () -> Void, onExpand: @escaping () -> Void, onBackground: @escaping () -> Void) {
        self.player = player
        self.channel = channel
        self.videoGravity = videoGravity
        self.onClose = onClose
        self.onExpand = onExpand
        self.onBackground = onBackground
        self._pipController = pipController
        _currentPosition = State(initialValue: position)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle + Channel name
            HStack {
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Text(channel.name)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                // Background PiP button
                Button(action: onBackground) {
                    Image(systemName: "pip.enter")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
                // Expand button
                Button(action: onExpand) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.85))
            
            // Video player
            iOSVideoPlayerRepresentable(
                player: player,
                videoGravity: videoGravity,
                allowsExternalPlayback: false,
                pipController: $pipController,
                viewModel: nil
            )
            .frame(height: playerHeight)
        }
        .frame(width: playerWidth)
        .background(Color.black)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(isDragging ? 0.4 : 0.2), lineWidth: 1)
        )
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .position(currentPosition)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    let newX = value.location.x
                    let newY = value.location.y
                    
                    // Clamp to screen bounds
                    let screenWidth = UIScreen.main.bounds.width
                    let screenHeight = UIScreen.main.bounds.height
                    let minX = playerWidth / 2 + edgeMargin
                    let maxX = screenWidth - playerWidth / 2 - edgeMargin
                    let minY = playerHeight / 2 + edgeMargin + 50 // extra space for status bar
                    let maxY = screenHeight - playerHeight / 2 - edgeMargin - 50 // extra space for tab bar
                    
                    currentPosition = CGPoint(
                        x: min(max(newX, minX), maxX),
                        y: min(max(newY, minY), maxY)
                    )
                }
                .onEnded { value in
                    isDragging = false
                    // Snap to nearest edge
                    snapToEdge()
                }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPosition)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isDragging)
    }
    
    private func snapToEdge() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        // Determine nearest edge
        let distanceToLeft = currentPosition.x
        let distanceToRight = screenWidth - currentPosition.x
        let distanceToTop = currentPosition.y
        let distanceToBottom = screenHeight - currentPosition.y
        
        let minDistance = min(distanceToLeft, distanceToRight, distanceToTop, distanceToBottom)
        
        var snappedPosition = currentPosition
        
        if minDistance == distanceToLeft {
            snappedPosition.x = playerWidth / 2 + edgeMargin
        } else if minDistance == distanceToRight {
            snappedPosition.x = screenWidth - playerWidth / 2 - edgeMargin
        } else if minDistance == distanceToTop {
            snappedPosition.y = playerHeight / 2 + edgeMargin + 50
        } else {
            snappedPosition.y = screenHeight - playerHeight / 2 - edgeMargin - 80
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentPosition = snappedPosition
        }
    }
}
#endif
