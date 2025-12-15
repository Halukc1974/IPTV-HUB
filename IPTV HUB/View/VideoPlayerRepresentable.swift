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

        // Only create if we have a viewModel (not for mini overlays)
        guard viewModel != nil else {
            return
        }
        
        // Don't recreate if we already have a working controller
        if let controller = pipController, controller.isPictureInPicturePossible {
            if controller.delegate !== viewModel {
                controller.delegate = viewModel
                print("🔁 Updated PiP delegate")
            }
            return
        }
        
        // Create new controller
        let controller: AVPictureInPictureController?
        if #available(iOS 15.0, *) {
            let source = AVPictureInPictureController.ContentSource(playerLayer: playerLayer)
            controller = AVPictureInPictureController(contentSource: source)
        } else {
            controller = AVPictureInPictureController(playerLayer: playerLayer)
        }
        
        if let controller = controller {
            controller.delegate = viewModel
            DispatchQueue.main.async {
                self.pipController = controller
                print("✅ PiP controller created, possible: \(controller.isPictureInPicturePossible)")
            }
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
