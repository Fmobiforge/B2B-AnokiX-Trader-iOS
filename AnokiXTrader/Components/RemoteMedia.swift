import SwiftUI
import UIKit
import AVFoundation
import Kingfisher

// MARK: - Media URL normalisation (Android `MediaUrls`)

enum MediaUrls {
    private static let baseURL = "http://155.117.20.51/ax/"

    static func resolve(_ raw: String?) -> String? {
        guard var url = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty else { return nil }
        if (url.hasPrefix("\"") && url.hasSuffix("\"")) || (url.hasPrefix("'") && url.hasSuffix("'")) {
            url = String(url.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !url.isEmpty else { return nil }
        if url.hasPrefix("http://") || url.hasPrefix("https://") { return url }
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        if url.hasPrefix("/") { return base + url }
        return baseURL + url
    }

    static func url(_ raw: String?) -> URL? {
        resolve(raw).flatMap { URL(string: $0) }
    }
}

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

/// First-frame poster shown while a video banner is off-screen (keeps scroll compositing stable).
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
        let resolved = MediaUrls.url(url.absoluteString) ?? url
        let asset = AVURLAsset(url: resolved)
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

/// Muted, auto-looping inline video for marketplace banners.
struct LoopingVideoView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerContainerView {
        let resolved = MediaUrls.url(url.absoluteString) ?? url
        let view = PlayerContainerView(url: resolved)
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        let resolved = MediaUrls.url(url.absoluteString) ?? url
        uiView.loadIfNeeded(resolved)
    }

    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: ()) {
        uiView.stop()
    }

    final class PlayerContainerView: UIView {
        private let playerLayer = AVPlayerLayer()
        private var queuePlayer: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private var statusObserver: NSKeyValueObservation?
        private var loadedURL: URL?

        init(url: URL) {
            super.init(frame: .zero)
            clipsToBounds = true
            layer.masksToBounds = true
            backgroundColor = UIColor(red: 91 / 255, green: 33 / 255, blue: 182 / 255, alpha: 1)
            playerLayer.videoGravity = .resizeAspectFill
            playerLayer.backgroundColor = backgroundColor?.cgColor
            layer.addSublayer(playerLayer)
            Self.prepareAudioSession()
            loadIfNeeded(url)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        func loadIfNeeded(_ url: URL) {
            guard loadedURL != url else {
                queuePlayer?.play()
                return
            }
            teardown(keepLayer: true)
            loadedURL = url

            let asset = AVURLAsset(url: url, options: [
                AVURLAssetAllowsCellularAccessKey: true
            ])
            let template = AVPlayerItem(asset: asset)

            let player = AVQueuePlayer()
            player.isMuted = true
            player.actionAtItemEnd = .none
            player.automaticallyWaitsToMinimizeStalling = false
            player.preventsDisplaySleepDuringVideoPlayback = false

            looper = AVPlayerLooper(player: player, templateItem: template)
            queuePlayer = player
            playerLayer.player = player

            statusObserver = template.observe(\.status, options: [.new]) { [weak player] item, _ in
                guard item.status == .readyToPlay else { return }
                DispatchQueue.main.async { player?.play() }
            }
            player.play()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            if bounds.width > 0, bounds.height > 0 {
                playerLayer.frame = bounds
            }
        }

        /// Full teardown when the SwiftUI view is removed (e.g. carousel page change).
        func stop() {
            teardown(keepLayer: false)
        }

        private func teardown(keepLayer: Bool) {
            statusObserver?.invalidate()
            statusObserver = nil
            queuePlayer?.pause()
            looper?.disableLooping()
            looper = nil
            queuePlayer = nil
            playerLayer.player = nil
            loadedURL = nil
            if !keepLayer {
                playerLayer.removeFromSuperlayer()
            }
        }

        private static var audioPrepared = false
        private static func prepareAudioSession() {
            guard !audioPrepared else { return }
            audioPrepared = true
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try? session.setActive(true)
        }
    }
}
