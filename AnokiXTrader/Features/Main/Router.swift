import SwiftUI

enum Tab: Hashable { case home, sell, orders, wallet, more }

/// Secondary modules reached from the drawer / More tab / quick actions.
/// Presented as a full-screen cover over the tab bar (matches the Android Activities).
enum Module: String, Identifiable, Hashable {
    case inventory, marketplace, payments, airtime, rewards
    case promotions, customers, analytics, reports, notifications, settings, support
    var id: String { rawValue }

    var title: String {
        switch self {
        case .inventory: return "Inventory"
        case .marketplace: return "Marketplace"
        case .payments: return "Payments"
        case .airtime: return "Airtime & VAS"
        case .rewards: return "anokiX Rewards"
        case .promotions: return "Promotions"
        case .customers: return "Customers"
        case .analytics: return "Analytics"
        case .reports: return "Reports"
        case .notifications: return "Notifications"
        case .settings: return "Settings"
        case .support: return "Support Centre"
        }
    }
}

/// Central navigation state shared by the whole main app.
final class Router: ObservableObject {
    @Published var tab: Tab = .home
    @Published var drawerOpen = false
    @Published var presented: Module? = nil

    /// Route by the string keys used across MockData menus / quick actions.
    func route(_ key: String) {
        drawerOpen = false
        switch key {
        case "home":   tab = .home
        case "sell":   tab = .sell
        case "orders": tab = .orders
        case "wallet": tab = .wallet
        default:
            if let m = Module(rawValue: key) { presented = m }
        }
    }
}
