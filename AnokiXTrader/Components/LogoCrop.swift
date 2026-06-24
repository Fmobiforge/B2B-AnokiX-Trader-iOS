import SwiftUI
import UIKit

/// Square logo cropper — a direct port of the Distributor app's `LogoCropView`.
/// Supports scale, rotation, and drag-to-pan; `croppedImage()` renders the centred
/// square viewport to a new bitmap for upload.
final class LogoCropView: UIView {

    private var sourceImage: UIImage?
    private var baseScale: CGFloat = 1
    private var userScale: CGFloat = 1
    private var rotationDegrees: CGFloat = 0
    private var offsetX: CGFloat = 0
    private var offsetY: CGFloat = 0

    private var lastPanLocation: CGPoint = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        backgroundColor = UIColor(red: 0.58, green: 0.64, blue: 0.72, alpha: 1) // Brand.textTertiary
        contentMode = .redraw
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setImage(_ image: UIImage) {
        sourceImage = image.normalizedForEditing()
        userScale = 1
        rotationDegrees = 0
        offsetX = 0
        offsetY = 0
        recomputeBaseScale()
        setNeedsDisplay()
    }

    func setUserScale(_ scale: CGFloat) {
        userScale = scale
        clampOffsets()
        setNeedsDisplay()
    }

    func setRotationDegrees(_ degrees: CGFloat) {
        rotationDegrees = degrees
        clampOffsets()
        setNeedsDisplay()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        recomputeBaseScale()
        clampOffsets()
    }

    private var viewportSide: CGFloat { min(bounds.width, bounds.height) }

    private var sourcePixelSize: CGSize {
        guard let image = sourceImage, let cg = image.cgImage else { return .zero }
        return CGSize(width: cg.width, height: cg.height)
    }

    private func recomputeBaseScale() {
        let size = sourcePixelSize
        let side = viewportSide
        guard size.width > 0, size.height > 0, side > 0 else { return }
        baseScale = max(side / size.width, side / size.height)
        clampOffsets()
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard sourceImage != nil else { return }
        switch gesture.state {
        case .began:
            lastPanLocation = gesture.location(in: self)
            gesture.cancelsTouchesInView = true
        case .changed:
            let location = gesture.location(in: self)
            offsetX += location.x - lastPanLocation.x
            offsetY += location.y - lastPanLocation.y
            clampOffsets()
            lastPanLocation = location
            setNeedsDisplay()
        default:
            break
        }
    }

    private func clampOffsets() {
        let size = sourcePixelSize
        let side = viewportSide
        guard size.width > 0, size.height > 0, side > 0 else {
            offsetX = 0
            offsetY = 0
            return
        }
        let scale = baseScale * userScale
        let halfSide = side / 2
        let hw = size.width * scale / 2
        let hh = size.height * scale / 2

        let rad = rotationDegrees * .pi / 180
        let cos = abs(cos(rad))
        let sin = abs(sin(rad))
        let boundW = hw * cos + hh * sin
        let boundH = hw * sin + hh * cos

        let maxOffsetX = max(0, boundW - halfSide)
        let maxOffsetY = max(0, boundH - halfSide)
        offsetX = min(maxOffsetX, max(-maxOffsetX, offsetX))
        offsetY = min(maxOffsetY, max(-maxOffsetY, offsetY))
    }

    override func draw(_ rect: CGRect) {
        guard let image = sourceImage, let ctx = UIGraphicsGetCurrentContext() else { return }

        let side = viewportSide
        let cropOrigin = CGPoint(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2)
        let cropRect = CGRect(origin: cropOrigin, size: CGSize(width: side, height: side))

        ctx.saveGState()
        ctx.clip(to: cropRect)
        applyTransform(to: ctx, centerX: bounds.midX, centerY: bounds.midY, outputRatio: 1)
        image.draw(in: CGRect(x: -sourcePixelSize.width / 2,
                              y: -sourcePixelSize.height / 2,
                              width: sourcePixelSize.width,
                              height: sourcePixelSize.height))
        ctx.restoreGState()

        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.35).cgColor)
        ctx.setLineWidth(1)
        ctx.stroke(cropRect)
    }

    private func applyTransform(to ctx: CGContext, centerX: CGFloat, centerY: CGFloat, outputRatio: CGFloat) {
        let scale = baseScale * userScale * outputRatio
        ctx.translateBy(x: centerX + offsetX * outputRatio, y: centerY + offsetY * outputRatio)
        ctx.rotate(by: rotationDegrees * .pi / 180)
        ctx.scaleBy(x: scale, y: scale)
    }

    func croppedImage() -> UIImage? {
        let side = viewportSide
        guard side > 0, sourceImage != nil else { return nil }

        let out = min(side, 1024)
        let ratio = out / side
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: out, height: out), format: format)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.saveGState()
            cg.clip(to: CGRect(x: 0, y: 0, width: out, height: out))
            applyTransform(to: cg, centerX: out / 2, centerY: out / 2, outputRatio: ratio)
            sourceImage?.draw(in: CGRect(x: -sourcePixelSize.width / 2,
                                         y: -sourcePixelSize.height / 2,
                                         width: sourcePixelSize.width,
                                         height: sourcePixelSize.height))
            cg.restoreGState()
        }
    }
}

private extension UIImage {
    /// Upright pixel image so crop math matches Android's raw bitmap dimensions.
    func normalizedForEditing() -> UIImage {
        guard let cgImage = cgImage else { return self }
        if imageOrientation == .up, scale == 1 { return self }
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIImage(cgImage: cgImage, scale: 1, orientation: .up)
                .draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - SwiftUI host

/// Holds the cropper UIView so the SwiftUI sheet can drive scale/rotation and read
/// the cropped result.
final class LogoCropController: ObservableObject {
    let cropView = LogoCropView()
    func setImage(_ image: UIImage) { cropView.setImage(image) }
    func setScale(_ value: CGFloat) { cropView.setUserScale(value) }
    func setRotation(_ degrees: CGFloat) { cropView.setRotationDegrees(degrees) }
    func cropped() -> UIImage? { cropView.croppedImage() }
}

private struct LogoCropCanvas: UIViewRepresentable {
    let controller: LogoCropController
    func makeUIView(context: Context) -> LogoCropView { controller.cropView }
    func updateUIView(_ uiView: LogoCropView, context: Context) {}
}

/// Modal crop editor for the company logo — mirrors the Distributor app's
/// `LogoCropViewController` (scale + rotation sliders, drag to reposition).
struct LogoCropSheet: View {
    let image: UIImage
    let onConfirm: (UIImage) -> Void
    let onUploadNew: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = LogoCropController()
    @State private var scale: Double = 50      // 0…200  → userScale 0.5…2.5
    @State private var rotation: Double = 0     // 0…360 degrees

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Crop Company Logo")
                    .font(.system(size: 16, weight: .bold)).foregroundColor(Brand.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").foregroundColor(Brand.textSecondary)
                }
            }

            LogoCropCanvas(controller: controller)
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("Drag to reposition")
                .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)

            Text("Scale").font(.system(size: 14)).foregroundColor(Brand.textPrimary)
            Slider(value: $scale, in: 0...200) { _ in }
                .tint(Brand.purple)
                .onChange(of: scale) { v in controller.setScale(0.5 + CGFloat(v) / 100) }

            Text("Rotation").font(.system(size: 14)).foregroundColor(Brand.textPrimary)
            Slider(value: $rotation, in: 0...360) { _ in }
                .tint(Brand.purple)
                .onChange(of: rotation) { v in controller.setRotation(CGFloat(v)) }

            Button {
                dismiss()
                DispatchQueue.main.async { onUploadNew() }
            } label: {
                Text("Upload new image")
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.purple)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
            }

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.textPrimary)
                    .padding(.horizontal, 20).frame(height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                Button {
                    if let cropped = controller.cropped() {
                        dismiss()
                        DispatchQueue.main.async { onConfirm(cropped) }
                    }
                } label: {
                    Text("OK").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                        .padding(.horizontal, 28).frame(height: 44)
                        .background(Brand.purple).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Brand.surface.ignoresSafeArea())
        .preferredColorScheme(.light)   // always render clear/light, even in Dark Mode
        .onAppear { controller.setImage(image) }
    }
}
