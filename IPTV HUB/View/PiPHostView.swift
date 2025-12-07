import SwiftUI
import AVKit

/// Invisible host that keeps a persistent AVPlayerLayer alive for PiP.
/// This prevents PiP controller from being tied to transient fullscreen/floating views.
struct PiPHostView: UIViewRepresentable {
    let player: AVPlayer
    let videoGravity: AVLayerVideoGravity
    @Binding var pipController: AVPictureInPictureController?
    let delegate: AVPictureInPictureControllerDelegate?

    func makeUIView(context: Context) -> UIView {
        // Keep a tiny, nearly-transparent host view so the AVPlayerLayer stays attached
        // — hidden views can make PiP impossible on some OS versions.
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 2, height: 2))
        view.alpha = 0.001
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = videoGravity
        // Give the layer a tiny frame so PiP can bind to a valid surface
        layer.frame = CGRect(x: 0, y: 0, width: 2, height: 2)
        view.layer.addSublayer(layer)
        context.coordinator.playerLayer = layer

        setupPiP(for: layer, coordinator: context.coordinator)

        // Listen for explicit host recreate requests (e.g., when controller was dropped)
        context.coordinator.recreateObserver = NotificationCenter.default.addObserver(forName: .init("PiPHostRecreateController"), object: nil, queue: .main) { _ in
            if let layer = context.coordinator.playerLayer {
                print("🔔 PiPHostView received recreate request — attempting setupPiP")
                setupPiP(for: layer, coordinator: context.coordinator)
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = context.coordinator.playerLayer {
            if layer.player !== player { layer.player = player; context.coordinator.createAttempts = 0; print("🔁 PiP host layer player swapped (createAttempts reset)") }
            if layer.videoGravity != videoGravity { layer.videoGravity = videoGravity; print("🔁 PiP host layer gravity updated") }
            // Ensure layer has a tiny non-zero size
            if layer.frame.size.width <= 0 || layer.frame.size.height <= 0 {
                layer.frame = CGRect(x: 0, y: 0, width: 2, height: 2)
            }
            setupPiP(for: layer, coordinator: context.coordinator)

            // If controller exists, keep delegate in sync
            if let controller = pipController, controller.delegate !== delegate {
                controller.delegate = delegate
                print("🔁 PiP host controller delegate refreshed on update")
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var playerLayer: AVPlayerLayer?
        var createAttempts: Int = 0
        var recreateObserver: NSObjectProtocol?
        deinit {
            if let obj = recreateObserver {
                NotificationCenter.default.removeObserver(obj)
                print("🧹 PiPHostView.Coordinator deinit — removed recreate observer")
            }
        }
    }

    private func setupPiP(for layer: AVPlayerLayer, coordinator: Coordinator) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        // If there is no playable item on the layer yet or the current item is not ready,
        // wait and retry a few times. PiP requires a visible layer + a ready item.
        if let player = layer.player {
            if player.currentItem == nil || player.currentItem?.status != .readyToPlay {
            coordinator.createAttempts += 1
            if coordinator.createAttempts > 6 {
                print("❌ PiPHost: no playerItem after repeated attempts — stopping retries")
                return
            }
            let delay = 0.25 * Double(coordinator.createAttempts)
            print("⚠️ PiPHost: player layer missing currentItem — will retry in \(String(format: "%.2fs", delay)) (attempt: \(coordinator.createAttempts))")
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak layer] in
                guard let l = layer else { return }
                self.setupPiP(for: l, coordinator: coordinator)
            }
                return
            }
        } else {
            // No player attached yet — retry later
            coordinator.createAttempts += 1
            if coordinator.createAttempts > 6 {
                print("❌ PiPHost: no player attached after repeated attempts — stopping retries")
                return
            }
            let delay = 0.25 * Double(coordinator.createAttempts)
            print("⚠️ PiPHost: no player attached — will retry in \(String(format: "%.2fs", delay)) (attempt: \(coordinator.createAttempts))")
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak layer] in
                guard let l = layer else { return }
                self.setupPiP(for: l, coordinator: coordinator)
            }
            return
        }

        // If a controller already exists, check whether it is usable; if not, drop and retry.
        if let controller = pipController {
            if controller.isPictureInPicturePossible {
                controller.delegate = delegate
                coordinator.createAttempts = 0
                print("ℹ️ PiP controller already present and usable — delegate refreshed: \(delegate != nil)")
                return
            }

            // controller exists but isn't possible — try clearing and recreating
            if let p = layer.player {
                print("🔍 PiPHost diagnostic: player.status=\(p.currentItem?.status.rawValue ?? -999) timeControl=\(p.timeControlStatus) rate=\(p.rate) layerSize=\(layer.frame.size)")
            }
            coordinator.createAttempts = 0
            print("⚠️ PiPHost: controller present but not possible — clearing and scheduling recreate")
            DispatchQueue.main.async {
                self.pipController = nil
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.setupPiP(for: layer, coordinator: coordinator)
            }
            return
        }
        let controller: AVPictureInPictureController?
        if #available(iOS 15.0, *) {
            let source = AVPictureInPictureController.ContentSource(playerLayer: layer)
            controller = AVPictureInPictureController(contentSource: source)
        } else {
            controller = AVPictureInPictureController(playerLayer: layer)
        }
        if let controller {
            controller.delegate = delegate
            DispatchQueue.main.async {
                self.pipController = controller
                print("✅ Persistent PiP controller created (host). isPossible=\(controller.isPictureInPicturePossible)")

                // If controller exists but isn't possible yet, try a few times before giving up.
                if !controller.isPictureInPicturePossible {
                    coordinator.createAttempts += 1
                    if coordinator.createAttempts <= 6 {
                        let delay = 0.3 * Double(coordinator.createAttempts)
                        print("⚠️ PiPHost: controller created but not possible yet — retrying in \(String(format: "%.2fs", delay)) (attempt: \(coordinator.createAttempts))")
                        if let p = layer.player {
                            print("🔍 PiPHost diagnostic: post-create player.status=\(p.currentItem?.status.rawValue ?? -999) timeControl=\(p.timeControlStatus) rate=\(p.rate) layerSize=\(layer.frame.size)")
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            // Clear and retry
                            self.pipController = nil
                            self.setupPiP(for: layer, coordinator: coordinator)
                        }
                    } else {
                        print("❌ PiPHost: created controller never becomes possible after retries — giving up until player changes")
                    }
                    return
                }

                // Success — reset attempts
                coordinator.createAttempts = 0
            }
        } else {
            print("❌ PiPHost: failed to instantiate AVPictureInPictureController")
        }
    }
}
