import SwiftUI

struct PlayerView: View {
    let initialChannel: Channel
    let channelCollection: [Channel]?
    @AppStorage("primaryVideoPlayer") private var primaryVideoPlayerRaw: String = VideoPlayerType.ksPlayer.rawValue
    private var selectedPlayerType: VideoPlayerType {
        VideoPlayerType(rawValue: primaryVideoPlayerRaw) ?? .ksPlayer
    }
    
    init(initialChannel: Channel, channelCollection: [Channel]? = nil) {
        self.initialChannel = initialChannel
        self.channelCollection = channelCollection
    }
    
    var body: some View {
        #if os(iOS)
        iOSPlayerView(
            initialChannel: initialChannel,
            channelCollection: channelCollection,
            playerType: selectedPlayerType
        )
        #elseif os(tvOS)
        TVOSPlayerView(
            initialChannel: initialChannel,
            channelCollection: channelCollection,
            playerType: selectedPlayerType
        )
        #else
        Text("Unsupported Platform")
        #endif
    }
}
