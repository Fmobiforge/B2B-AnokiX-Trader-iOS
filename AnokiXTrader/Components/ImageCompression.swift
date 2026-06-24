import UIKit

extension UIImage {
    /// Downscale so the longest side is at most `maxDimension`, then JPEG-encode at
    /// `quality`. Keeps multipart uploads small enough to finish before the upload
    /// times out (parity with the Distributor app's `downscaledJpeg`). The backend
    /// uploads ~40s per MB, so document images are trimmed to ~1440px @ 0.6.
    func downscaledJPEG(maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let longest = max(size.width, size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
