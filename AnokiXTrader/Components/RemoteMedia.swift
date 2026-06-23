import SwiftUI
import UIKit
import AVFoundation
import Kingfisher

/// Cached remote image — drop-in replacement for SwiftUI's `AsyncImage`, backed by
/// **Kingfisher** (in-memory + on-disk cache, so images load instantly on repeat
/// views and survive relaunches). Always resizable with a surface placeholder; the
/// caller controls the size via `.frame(...)` and clipping as before.
struct RemoteImage: View {
    let url: String?
    /// `true` → fill the frame (aspect-fill, clipped by the caller); `false` → fit.
    var fill: Bool = true

    var body: some View {
        KFImage(url.flatMap { URL(string: $0) })
            .placeholder { Brand.surfaceVariant }
            .fade(duration: 0.2)
            .cancelOnDisappear(true)
            .resizable()
            .aspectRatio(contentMode: fill ? .fill : .fit)
    }
}

/// Muted, auto-looping inline video for banners. Uses a UIKit `AVPlayerLayer`
/// (via `AVQueuePlayer` + `AVPlayerLooper`) which is far more reliable for inline
/// autoplay than SwiftUI's `VideoPlayer` (no controls, no garbage first frame,
/// seamless loop). Mirrors the Android `LoopingBannerVideoView`.
struct LoopingVideoView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerContainerView {
        PlayerContainerView(url: url)
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {}

    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: ()) {
        uiView.stop()
    }

    final class PlayerContainerView: UIView {
        private let playerLayer = AVPlayerLayer()
        private var queuePlayer: AVQueuePlayer?
        private var looper: AVPlayerLooper?

        init(url: URL) {
            super.init(frame: .zero)
            backgroundColor = .clear
            let item = AVPlayerItem(url: url)
            let player = AVQueuePlayer(playerItem: item)
            player.isMuted = true
            player.actionAtItemEnd = .none
            looper = AVPlayerLooper(player: player, templateItem: item)
            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspectFill
            layer.addSublayer(playerLayer)
            queuePlayer = player
            player.play()
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }

        func stop() {
            queuePlayer?.pause()
            queuePlayer = nil
            looper = nil
        }
    }
}
