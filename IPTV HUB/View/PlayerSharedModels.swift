import Foundation
import AVKit
import CoreGraphics

// MARK: - SHARED ENUMS
// Bu dosya hem iOS hem tvOS tarafından görülür.

enum AspectRatioMode: String, CaseIterable, Identifiable {
    case original = "Original (Broadcast)"
    case fit = "Fit"
    case fill = "Fill"
    case ratio_16_9 = "16:9"
    case ratio_4_3 = "4:3"
    case ratio_21_9 = "21:9"
    case ratio_19_5_9 = "19.5:9"
    case ratio_16_10 = "16:10"
    case ratio_5_4 = "5:4"
    case ratio_1_1 = "1:1"
    
    var id: String { self.rawValue }
    
    var videoGravity: AVLayerVideoGravity {
        switch self {
        case .fill,
             .ratio_16_9,
             .ratio_4_3,
             .ratio_21_9,
             .ratio_19_5_9,
             .ratio_16_10,
             .ratio_5_4,
             .ratio_1_1:
            return .resizeAspectFill
        default:
            return .resizeAspect
        }
    }
    
    var targetAspectRatio: CGFloat? {
        switch self {
        case .ratio_16_9: return 16.0 / 9.0
        case .ratio_4_3: return 4.0 / 3.0
        case .ratio_21_9: return 21.0 / 9.0
        case .ratio_19_5_9: return 19.5 / 9.0
        case .ratio_16_10: return 16.0 / 10.0
        case .ratio_5_4: return 5.0 / 4.0
        case .ratio_1_1: return 1.0
        default: return nil
        }
    }
    
    var prefersLetterboxedFit: Bool {
        switch self {
        case .fill,
             .ratio_16_9,
             .ratio_4_3,
             .ratio_21_9,
             .ratio_19_5_9,
             .ratio_16_10,
             .ratio_5_4,
             .ratio_1_1:
            return false
        default:
            return true
        }
    }
    
    var hint: String {
        switch self {
        case .original: return "Source defined"
        case .fit: return "Show full frame"
        case .fill: return "Edge to edge"
        case .ratio_16_9: return "Standard HD"
        case .ratio_4_3: return "Classic TV"
        case .ratio_21_9: return "Cinema scope"
        case .ratio_19_5_9: return "Modern phone"
        case .ratio_16_10: return "Laptop"
        case .ratio_5_4: return "Retro"
        case .ratio_1_1: return "Square"
        }
    }
}

enum PlayerControlFocus: Hashable {
    case mute, aspect, category, epg, home, info
}

enum PlayerFocusArea: Hashable {
    case zapping, controls, modals
}

extension Array where Element == Channel {
    func ensuringContains(_ channel: Channel) -> [Channel] {
        if contains(where: { $0.id == channel.id }) {
            return self
        }
        var updated = self
        updated.insert(channel, at: 0)
        return updated
    }
}
