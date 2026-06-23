import SwiftUI
import Combine

/// A single POS / order cart line.
struct CartLine: Identifiable, Hashable {
    let id: String          // product id
    let name: String
    let unitPrice: Double
    var qty: Int

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

    func setQty(_ id: String, _ qty: Int) {
        guard let idx = lines.firstIndex(where: { $0.id == id }) else { return }
        if qty <= 0 { lines.remove(at: idx) } else { lines[idx].qty = qty }
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

    func bootFinished() {
        // After the splash animation, go to the welcome screen.
        stage = .welcome
    }

    /// Real login against the AX backend. On success the Bearer token is stored on
    /// APIClient so the marketplace/cart calls are authenticated. If the call fails
    /// we fall back to mock entry (the app stays usable offline, mirroring the
    /// distributor-only backend reality) and surface the error.
    func signIn(email: String, password: String) {
        let typed = email.isEmpty ? "trader@anokix.co.za" : email
        Task {
            do {
                let data = try await APIClient.shared.login(email: typed, password: password)
                await MainActor.run {
                    APIClient.shared.token = data.token
                    if let name = data.user?.first_name, !name.isEmpty {
                        accountName = name
                    } else { deriveName(from: typed) }
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
        APIClient.shared.token = nil
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
