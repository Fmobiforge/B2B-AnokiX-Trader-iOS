import SwiftUI
import Combine

/// A single POS / order cart line.
struct CartLine: Identifiable, Hashable {
    let id: String          // product id
    let name: String
    let unitPrice: Double
    var qty: Int
    var imageUrl: String? = nil
    var sku: String? = nil
    var stock: Int = Int.max

    var lineTotal: Double { unitPrice * Double(qty) }
}

/// Mirrors the Android `Cart` singleton — one instance drives the POS sale and a
/// separate instance drives the marketplace order. 15% VAT, same as the portal.
final class Cart: ObservableObject {
    @Published private(set) var lines: [CartLine] = []

    static let vatRate = 0.15

    func add(id: String, name: String, unitPrice: Double) {
        if let idx = lines.firstIndex(where: { $0.id == id }) {
            lines[idx].qty += 1
        } else {
            lines.append(CartLine(id: id, name: name, unitPrice: unitPrice, qty: 1))
        }
    }

    /// Add one unit of a live POS product (clamped to on-hand stock).
    func add(product: PosProductDTO) {
        let key = String(product.id)
        if let idx = lines.firstIndex(where: { $0.id == key }) {
            if lines[idx].qty < lines[idx].stock { lines[idx].qty += 1 }
        } else {
            lines.append(CartLine(id: key, name: product.name ?? "", unitPrice: product.price,
                                  qty: 1, imageUrl: MediaUrls.resolve(product.image_url),
                                  sku: product.sku, stock: product.units))
        }
    }

    func setQty(_ id: String, _ qty: Int) {
        guard let idx = lines.firstIndex(where: { $0.id == id }) else { return }
        if qty <= 0 {
            lines.remove(at: idx)
        } else {
            lines[idx].qty = min(qty, lines[idx].stock)
        }
    }

    func remove(_ id: String) {
        lines.removeAll { $0.id == id }
    }

    func clear() { lines.removeAll() }

    var isEmpty: Bool { lines.isEmpty }
    var itemCount: Int { lines.reduce(0) { $0 + $1.qty } }
    var subtotal: Double { lines.reduce(0) { $0 + $1.lineTotal } }
    var vat: Double { subtotal * Cart.vatRate }
    var total: Double { subtotal + vat }
}

/// Auth gate. Mock-first: any non-empty credentials sign in. The only real backend
/// account (changd@gmail.com) is actually a distributor, so we don't pretend otherwise.
final class Session: ObservableObject {
    enum Stage { case splash, welcome, login, register, main }

    @Published var stage: Stage = .splash
    @Published var storeName: String = "Sipho's Spaza"
    @Published var accountName: String = "Trader Account"
    @Published var loginError: String?
    @Published var isSigningIn = false

    init() {
        restoreSavedSession()
    }

    private func restoreSavedSession() {
        guard let saved = LoginSessionStore.load() else { return }
        applySavedSession(saved, updateStage: false)
    }

    private func applySavedSession(_ saved: StoredLoginSession, updateStage: Bool) {
        if let token = saved.token, !token.isEmpty {
            APIClient.shared.token = token
        }
        if let store = saved.portal_info?.displayStoreName, !store.isEmpty {
            storeName = store
        }
        if let user = saved.user {
            accountName = user.displayName
        }
        if updateStage, APIClient.shared.token != nil {
            stage = .main
        }
    }

    private func persistLogin(_ data: LoginData) {
        let stored = StoredLoginSession(
            token: data.token,
            user: data.user,
            portal_type: data.portal_type,
            portal_info: data.portal_info
        )
        LoginSessionStore.save(stored)
        applySavedSession(stored, updateStage: false)
    }

    func bootFinished() {
        // After the splash animation, go to the welcome screen.
        stage = .welcome
    }

    /// Real login against the AX backend. On success the Bearer token is stored on
    /// APIClient so the marketplace/cart calls are authenticated. If the call fails
    /// we fall back to mock entry (the app stays usable offline, mirroring the
    /// distributor-only backend reality) and surface the error.
    func signIn(email: String, password: String) {
        let typed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let pass = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isSigningIn else { return }
        isSigningIn = true
        Task {
            defer { Task { @MainActor in isSigningIn = false } }
            do {
                let data = try await APIClient.shared.login(email: typed, password: pass)
                await MainActor.run {
                    persistLogin(data)
                    stage = .main
                }
            } catch {
                await MainActor.run {
                    loginError = (error as? LocalizedError)?.errorDescription
                    deriveName(from: typed)
                    stage = .main
                }
            }
        }
    }

    private func deriveName(from email: String) {
        if let handle = email.split(separator: "@").first, !handle.isEmpty {
            accountName = handle.prefix(1).uppercased() + handle.dropFirst()
        }
    }

    func signOut() {
        PushManager.shared.unregister()   // drop this device's token (needs the auth token, so first)
        APIClient.shared.token = nil
        LoginSessionStore.clear()
        storeName = "Sipho's Spaza"
        accountName = "Trader Account"
        stage = .welcome
    }
}

/// Money formatting helper used across the app (R 1,234.56).
enum Money {
    static func rand(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = ","
        return "R " + (f.string(from: NSNumber(value: value)) ?? "0.00")
    }
}
