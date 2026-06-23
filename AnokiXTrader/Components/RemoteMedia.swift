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

/// First-frame poster for video banners inside scroll views.
///
/// Inline `AVPlayerLayer` playback corrupts compositing when nested in a vertical
/// `ScrollView` (common on VMware / nested iOS simulators). A static thumbnail
/// avoids hardware-layer ghosting while still showing the video's opening frame.
struct VideoThumbnailView: View {
    let url: URL
    @State private var thumbnail: UIImage?

    var body: some View {
        Group {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [Brand.purple, Brand.purpleDark],
                               startPoint: .leading, endPoint: .trailing)
            }
        }
        .task(id: url) {
            thumbnail = await Self.generateThumbnail(from: url)
        }
    }

    private static func generateThumbnail(from url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 960, height: 540)
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)

        return await withCheckedContinuation { continuation in
            generator.generateCGImageAsynchronously(for: time) { cgImage, _, _ in
                if let cgImage {
                    continuation.resume(returning: UIImage(cgImage: cgImage))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

/// Muted, auto-looping inline video — not used inside scroll views; kept for
/// potential full-screen playback. See `VideoThumbnailView` for banner posters.
struct LoopingVideoView: UIViewRepresentable {
    let url: URL
    var isActive: Bool = true

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView(url: url)
        view.setActive(isActive)
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.setActive(isActive)
    }

    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: ()) {
        uiView.stop()
    }

    final class PlayerContainerView: UIView {
        private let playerLayer = AVPlayerLayer()
        private var queuePlayer: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private var isActive = true

        init(url: URL) {
            super.init(frame: .zero)
            clipsToBounds = true
            layer.masksToBounds = true
            backgroundColor = UIColor(red: 91 / 255, green: 33 / 255, blue: 182 / 255, alpha: 1)

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
            guard !playerLayer.isHidden else { return }
            playerLayer.frame = bounds
        }

        func setActive(_ active: Bool) {
            guard isActive != active else { return }
            isActive = active
            if active {
                playerLayer.player = queuePlayer
                playerLayer.isHidden = false
                playerLayer.frame = bounds
                queuePlayer?.play()
            } else {
                queuePlayer?.pause()
                playerLayer.player = nil
                playerLayer.isHidden = true
            }
        }

        func stop() {
            queuePlayer?.pause()
            playerLayer.player = nil
            playerLayer.removeFromSuperlayer()
            queuePlayer = nil
            looper = nil
        }
    }
}
