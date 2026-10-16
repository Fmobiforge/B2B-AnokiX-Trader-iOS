import SwiftUI
import UIKit
import AVFoundation

// MARK: - Code matching

/// Resolves a scanned or typed code to a POS product.
///
/// `api/trader/pos/products` carries no QR field, so both scanners match on the same two
/// identifiers: `barcode` and `sku`. A 1D barcode is that value verbatim; a QR label often
/// wraps it (a stock-take URL, a JSON blob, a `KEY:value` line), so when the raw payload
/// misses we retry against the tokens pulled out of it rather than declaring "not found"
/// on a code the shop can plainly read. Mirrors the Android `ProductCodeMatcher`.
enum ProductCodeMatcher {

    /// Longest token worth trying as an identifier — beyond this it is prose, not a code.
    private static let maxToken = 64

    /// The product whose barcode or SKU matches `raw`, or nil. Barcode is checked before
    /// SKU across the whole list, so a code that is one product's barcode never loses to
    /// another product's SKU.
    static func find(in products: [PosProductDTO], code raw: String) -> PosProductDTO? {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty, !products.isEmpty else { return nil }
        if let hit = matchExact(products, code) { return hit }
        // Structured QR payload — try each identifier-shaped token inside it.
        for token in tokenize(code) {
            if let hit = matchExact(products, token) { return hit }
        }
        return nil
    }

    private static func matchExact(_ products: [PosProductDTO], _ code: String) -> PosProductDTO? {
        if let hit = products.first(where: { equalsCode($0.barcode, code) }) { return hit }
        return products.first(where: { equalsCode($0.sku, code) })
    }

    private static func equalsCode(_ value: String?, _ code: String) -> Bool {
        guard let value else { return false }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.caseInsensitiveCompare(code) == .orderedSame
    }

    /// Splits a QR payload into candidate identifiers on the punctuation that separates
    /// fields in URLs, JSON and key/value labels. Ordering is preserved so the earliest
    /// plausible token wins.
    private static func tokenize(_ payload: String) -> [String] {
        let separators = CharacterSet(charactersIn: " \t\n\r/?&=,;:|\"'{}[]\\<>")
        var tokens: [String] = []
        for part in payload.components(separatedBy: separators) {
            let token = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty, token.count <= maxToken,
                  token.rangeOfCharacter(from: .alphanumerics) != nil else { continue }
            let lower = token.lowercased()
            // Drop URL scaffolding — "https", "http", "www.acme.co.za" and the like.
            if lower == "http" || lower == "https" || lower.hasPrefix("www.") { continue }
            if !tokens.contains(token) { tokens.append(token) }
        }
        return tokens
    }
}

// MARK: - Scan mode

/// Which sheet to show. Both match on barcode + SKU; they differ in symbologies + copy.
/// `Identifiable` so it can drive a `sheet(item:)` straight from the POS screen.
enum PosScanMode: Identifiable {
    case barcode, qr

    var id: String { self == .qr ? "qr" : "barcode" }
    var title: String { self == .qr ? "Scan a QR code" : "Scan a barcode" }
    var fieldHint: String { self == .qr ? "QR contents" : "Barcode or SKU" }
    var aimHint: String {
        self == .qr ? "Line the QR code up inside the frame" : "Line the barcode up inside the frame"
    }

    var symbologies: [AVMetadataObject.ObjectType] {
        self == .qr
            ? [.qr, .aztec, .dataMatrix, .pdf417]
            : [.ean13, .ean8, .upce, .code128, .code39, .code93, .itf14, .interleaved2of5]
    }
}

// MARK: - Camera controller

/// Owns the capture session for the POS scanner: permission, wiring, torch, and a
/// debounce so one label held in front of the lens is not read on every frame.
final class PosScannerController: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {

    enum Status {
        case idle, running, denied, unavailable, failed

        /// Copy for the placeholder shown in place of the preview.
        var message: String? {
            switch self {
            case .denied:      return "Camera access is off. Turn it on in Settings, or type the code below."
            case .unavailable: return "No camera on this device — type the code below."
            case .failed:      return "The camera could not be started. Type the code below."
            case .idle, .running: return nil
            }
        }
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var hasTorch = false
    @Published private(set) var torchOn = false
    /// True while a rung-up code is still in front of the lens — drives the "move the
    /// item away" prompt so the cashier can see why the next read is not landing.
    @Published private(set) var isHolding = false

    let session = AVCaptureSession()
    /// Called on the main thread with each accepted code.
    var onCode: ((String) -> Void)?

    /// A rung-up code counts again only once it has been out of frame for this long.
    private static let separation: TimeInterval = 0.9
    /// Nothing at all is accepted for this long after an accept — one item per gesture.
    private static let deadTime: TimeInterval = 0.6

    private let sessionQueue = DispatchQueue(label: "com.anokix.pos.scanner")
    private var configured = false
    /// The device actually opened — the torch belongs to this camera, not "the default one".
    private var device: AVCaptureDevice?
    private var mode: PosScanMode = .barcode
    /// Codes already rung up and still in front of the lens: code → when last seen.
    private var heldCodes: [String: Date] = [:]
    private var lastAcceptedAt: Date = .distantPast
    /// The metadata delegate only fires on change, so a held code that simply stops being
    /// reported would never be released. This sweeps them on a timer instead.
    private var releaseTimer: Timer?

    /// Ask for camera access if needed, then wire and start the session.
    func start(mode: PosScanMode) {
        self.mode = mode
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.configureAndRun() } else { self?.status = .denied }
                }
            }
        default:
            status = .denied
        }
    }

    func stop() {
        setTorch(on: false)
        releaseTimer?.invalidate()
        releaseTimer = nil
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configureAndRun() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.configured {
                guard self.configure() else {
                    DispatchQueue.main.async { self.status = .unavailable }
                    return
                }
                self.configured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
            let torch = self.device?.hasTorch ?? false
            DispatchQueue.main.async {
                self.hasTorch = torch
                self.status = .running
                self.startReleaseTimer()
            }
        }
    }

    /// Wires camera → metadata output. Must run on `sessionQueue`.
    private func configure() -> Bool {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else { return false }
        device = camera

        session.beginConfiguration()
        // 720p is plenty to decode a shelf label and keeps the pipeline light.
        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return false
        }
        session.addOutput(output)
        // Delivered on the main queue: metadata objects are light, and every listener
        // below touches @Published state.
        output.setMetadataObjectsDelegate(self, queue: .main)
        // Only after the output is attached does it publish the types it supports.
        output.metadataObjectTypes = mode.symbologies.filter {
            output.availableMetadataObjectTypes.contains($0)
        }
        session.commitConfiguration()
        return true
    }

    // MARK: Torch

    func toggleTorch() {
        setTorch(on: !torchOn)
    }

    private func setTorch(on: Bool) {
        guard let device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
            torchOn = on
        } catch {
            // Torch is a convenience — a locked device shouldn't break scanning.
        }
    }

    // MARK: Scan separation

    /// A label sits in front of the lens continuously, so a code is rung up once and then
    /// *held*: it cannot be rung up again until it has been out of frame for `separation`.
    /// That is the physical gesture a cashier already makes — scan, move the item aside,
    /// scan the next — and presenting the same item again still deliberately adds a second
    /// unit. A short dead time after every accept stops a second label in the same shot
    /// being swept up with the first.
    ///
    /// Codes are held whatever the outcome, so an unknown or out-of-stock label reports
    /// once instead of hammering the banner for as long as it is in view.
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        let now = Date()
        var visible: [String] = []
        for object in metadataObjects {
            guard let readable = object as? AVMetadataMachineReadableCodeObject,
                  let value = readable.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty, !visible.contains(value) else { continue }
            visible.append(value)
        }

        // Refresh the hold on anything still in view, then release what has cleared.
        for code in visible where heldCodes[code] != nil { heldCodes[code] = now }
        releaseClearedHolds(now: now)

        guard now.timeIntervalSince(lastAcceptedAt) >= Self.deadTime,
              let next = visible.first(where: { heldCodes[$0] == nil }) else { return }

        heldCodes[next] = now
        lastAcceptedAt = now
        isHolding = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onCode?(next)
    }

    private func startReleaseTimer() {
        releaseTimer?.invalidate()
        releaseTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.releaseClearedHolds(now: Date())
        }
    }

    /// Drops holds whose code has been absent long enough to count as a fresh presentation.
    private func releaseClearedHolds(now: Date) {
        guard !heldCodes.isEmpty else { return }
        heldCodes = heldCodes.filter { now.timeIntervalSince($0.value) < Self.separation }
        let holding = !heldCodes.isEmpty
        if holding != isHolding { isHolding = holding }
    }

    /// A typed code is an explicit request, so it skips the hold entirely. The dead time
    /// still applies, so the camera cannot pile a scan on top of what was just typed.
    func noteManualEntry() {
        lastAcceptedAt = Date()
    }
}

// MARK: - Camera preview

/// Hosts the capture session's preview layer. `layerClass` makes the layer the view's
/// own backing layer, so it resizes with the view for free.
private final class PreviewContainerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = PreviewContainerView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Scan sheet

/// POS "Scan a barcode" / "Scan a QR code" sheet.
///
/// The portal shows this as a type-it-in modal because a browser cannot reach the camera;
/// a phone can, so the camera is the primary input here and manual entry is the fallback
/// (damaged labels, and Bluetooth handheld scanners, which type the code and press Enter).
/// Either way the code is resolved against the loaded POS product list and the outcome is
/// reported in place — added, out of stock, or no match — leaving the sheet open so the
/// cashier can keep scanning the basket.
struct PosScanView: View {
    let mode: PosScanMode
    let products: [PosProductDTO]
    @ObservedObject var cart: Cart

    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = PosScannerController()
    @State private var typed = ""
    @State private var feedback: Feedback?

    private struct Feedback: Equatable {
        enum Tone: Equatable { case success, warning, error }
        let tone: Tone
        let message: String

        var icon: String {
            switch tone {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.circle.fill"
            case .error:   return "xmark.circle.fill"
            }
        }
        var tint: Color {
            switch tone {
            case .success: return Brand.success
            case .warning: return Color(hex: "#B45309")
            case .error:   return Brand.danger
            }
        }
        var background: Color {
            switch tone {
            case .success: return Color(hex: "#F0FDF4")
            case .warning: return Color(hex: "#FFFBEB")
            case .error:   return Color(hex: "#FEF2F2")
            }
        }
        var border: Color {
            switch tone {
            case .success: return Color(hex: "#BBF7D0")
            case .warning: return Color(hex: "#FDE68A")
            case .error:   return Color(hex: "#FECACA")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    cameraCard
                    manualEntry
                    if let feedback {
                        feedbackBanner(feedback)
                            .padding(.top, 14)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }

            footerBar
        }
        .background(Brand.surface)
        .onAppear { controller.onCode = { code in resolve(code) }; controller.start(mode: mode) }
        .onDisappear { controller.stop() }
    }

    // MARK: Sections

    private var headerBar: some View {
        HStack {
            Text(mode.title)
                .font(.app(18, .bold)).foregroundColor(Brand.textPrimary)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(Brand.textSecondary)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.leading, 20).padding(.trailing, 12)
        .padding(.top, 18).padding(.bottom, 14)
    }

    private var cameraCard: some View {
        ZStack {
            if controller.status == .running {
                CameraPreview(session: controller.session)
                // Green frame while a scan is held: it reads at a glance that the code
                // landed and the item has to move away before the next one counts.
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(controller.isHolding ? Color(hex: "#4ADE80") : Color.white.opacity(0.7),
                            lineWidth: 2)
                    .padding(26)
                VStack {
                    HStack {
                        Spacer()
                        if controller.hasTorch {
                            Button { controller.toggleTorch() } label: {
                                Image(systemName: controller.torchOn ? "bolt.fill" : "bolt.slash.fill")
                                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.black.opacity(0.4)).clipShape(Circle())
                            }
                        }
                    }
                    Spacer()
                    Text(controller.isHolding
                         ? "Scanned — move the item away for the next one"
                         : mode.aimHint)
                        .font(.app(11)).foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Color.black.opacity(0.4)).clipShape(Capsule())
                }
                .padding(10)
            } else {
                VStack(spacing: 12) {
                    Text(controller.status.message ?? "Allow camera access to scan straight off the label.")
                        .font(.app(13)).foregroundColor(Color(hex: "#E2E8F0"))
                        .multilineTextAlignment(.center)
                    if controller.status == .denied {
                        Button("Open settings") { openSettings() }
                            .font(.app(13, .semibold)).foregroundColor(.white)
                            .padding(.horizontal, 18).frame(height: 42)
                            .background(Brand.purple).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .frame(height: 190)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#0F172A"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var manualEntry: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Handheld scanner or type it in")
                .font(.app(14, .bold)).foregroundColor(Brand.textPrimary)
                .padding(.top, 18)

            HStack(spacing: 8) {
                TextField(mode.fieldHint, text: $typed)
                    .font(.app(14)).foregroundColor(Brand.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    // A handheld scanner types the code then sends Enter — same path as Add.
                    .onSubmit { submitTyped() }
                    .padding(.horizontal, 14).frame(height: 48)
                    .background(Brand.surfaceVariant)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button("Add") { submitTyped() }
                    .font(.app(14, .semibold)).foregroundColor(.white)
                    .padding(.horizontal, 20).frame(height: 48)
                    .background(Brand.purple).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top, 8)

            Text("Point the camera at the label, or type the code and tap Add. A Bluetooth scanner types it in and presses Enter — that works here too.")
                .font(.app(12)).foregroundColor(Brand.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        }
    }

    private func feedbackBanner(_ f: Feedback) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: f.icon).font(.system(size: 16)).foregroundColor(f.tint)
            Text(f.message)
                .font(.app(13)).foregroundColor(Brand.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(f.background)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(f.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var footerBar: some View {
        HStack {
            Text(cart.itemCount == 0
                 ? "Nothing on this sale yet"
                 : "\(cart.itemCount) \(cart.itemCount == 1 ? "item" : "items") · \(Money.rand(cart.subtotal))")
                .font(.app(12)).foregroundColor(Brand.textSecondary)
            Spacer()
            Button("Done") { dismiss() }
                .font(.app(14, .semibold)).foregroundColor(.white)
                .padding(.horizontal, 28).frame(height: 46)
                .background(Brand.purple).clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 20)
        .padding(.top, 8).padding(.bottom, 18)
    }

    // MARK: Actions

    private func submitTyped() {
        let code = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            feedback = Feedback(tone: .warning, message: "Enter or scan a code first.")
            return
        }
        controller.noteManualEntry()
        resolve(code)
    }

    /// Match the code against the POS list, then add / explain.
    private func resolve(_ code: String) {
        guard !products.isEmpty else {
            feedback = Feedback(tone: .warning, message: "Products are still loading. Try again in a moment.")
            return
        }
        guard let product = ProductCodeMatcher.find(in: products, code: code) else {
            feedback = Feedback(tone: .error,
                                message: "No product matches \"\(code)\". Check it's stocked under Inventory.")
            return
        }
        let name = product.name ?? ""
        guard product.sellable else {
            feedback = Feedback(tone: .warning, message: "\(name) is out of stock.")
            return
        }
        if cart.qty(of: String(product.id)) >= product.units {
            // Cart.add clamps at on-hand stock; say so rather than no-op silently.
            feedback = Feedback(tone: .warning,
                                message: "All \(product.units) in stock of \(name) are already on this sale.")
            return
        }
        cart.add(product: product)
        typed = ""
        feedback = Feedback(tone: .success, message: "Added \(name) — \(Money.rand(product.price))")
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
