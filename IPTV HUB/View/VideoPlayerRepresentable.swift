import SwiftUI
import AVKit

#if os(iOS)
struct iOSVideoPlayerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    let videoGravity: AVLayerVideoGravity
    let allowsExternalPlayback: Bool
    @Binding var pipController: AVPictureInPictureController?
    let viewModel: PlayerViewModel?

    func makeUIViewController(context: Context) -> PlayerContainerViewController {
        let controller = PlayerContainerViewController()
        controller.view.backgroundColor = .black

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = videoGravity
        controller.playerLayer = playerLayer
        controller.view.layer.addSublayer(playerLayer)

        player.allowsExternalPlayback = allowsExternalPlayback
        
        // Setup PiP controller
        setupPiPController(for: playerLayer)

        return controller
    }

    func updateUIViewController(_ uiViewController: PlayerContainerViewController, context: Context) {
        if uiViewController.playerLayer?.player !== player {
            uiViewController.playerLayer?.player = player
        }

        if uiViewController.playerLayer?.videoGravity != videoGravity {
            uiViewController.playerLayer?.videoGravity = videoGravity
        }

        player.allowsExternalPlayback = allowsExternalPlayback
        
        // Ensure PiP controller exists
        if let layer = uiViewController.playerLayer {
            setupPiPController(for: layer)
        }
    }
    
    private func setupPiPController(for playerLayer: AVPlayerLayer) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("❌ PiP not supported on this device")
            return
        }

        // When viewModel is nil (e.g., mini overlay), avoid creating/rebinding PiP here;
        // the persistent host owns the controller to keep it stable across transitions.
        guard viewModel != nil else {
            return
        }
        
        // Do not create a new PiP controller here - the `PiPHostView` owns and manages
        // the persistent controller. If a controller exists, make sure the delegate
        // is forwarded to the current view model so delegate callbacks reach it.
        if let controller = pipController {
            if controller.delegate !== viewModel {
                controller.delegate = viewModel
                print("🔁 Forwarded existing PiP delegate to current PlayerViewModel: \(viewModel != nil)")
            }
        } else {
            // No controller yet — host should create one. We don't instantiate one here to
            // avoid binding it to a temporary fullscreen layer that will be destroyed.
            print("ℹ️ No shared PiP controller present in representable; relying on host")
        }
    }
}

/// Keeps the `AVPlayerLayer` sized to the container view so PiP can bind to a valid layer.
final class PlayerContainerViewController: UIViewController {
    var playerLayer: AVPlayerLayer?

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
    }
}
#endif
