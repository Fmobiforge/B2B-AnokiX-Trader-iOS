import SwiftUI

enum Tab: Hashable { case home, sell, orders, wallet, more }

/// Secondary modules reached from the drawer / More tab / quick actions.
/// Presented as a full-screen cover over the tab bar (matches the Android Activities).
enum Module: String, Identifiable, Hashable {
    case inventory, marketplace, cart, payments, airtime, rewards, sales, invoices, finances, distributors
    case promotions, customers, analytics, reports, notifications, settings, support
    /// Raw values match the drawer keys so Router.route can resolve them.
    case goodsReceived = "goods_received"
    case goodsReturns = "goods_returns"
    var id: String { rawValue }

    var title: String {
        switch self {
        case .goodsReceived: return "Goods Received (GRV)"
        case .goodsReturns:  return "Goods Returns (GRN)"
        case .inventory: return "Inventory"
        case .marketplace: return "Marketplace"
        case .cart: return "My Cart"
        case .payments: return "Payments"
        case .airtime: return "Airtime & VAS"
        case .rewards: return "anokiX Rewards"
        case .sales: return "Sales"
        case .invoices: return "Invoices"
        case .finances: return "Finances"
        case .distributors: return "Distributors"
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

/// A deep link to one order's detail screen (e.g. from an order push notification).
/// Wraps the id in an `Identifiable` so it can drive a `fullScreenCover(item:)`.
struct OrderDetailRoute: Identifiable, Hashable {
    let id: Int
}

/// Central navigation state shared by the whole main app.
final class Router: ObservableObject {
    @Published var tab: Tab = .home
    @Published var drawerOpen = false
    @Published var presented: Module? = nil
    /// Set to open a specific order's detail full-screen (push deep link).
    @Published var orderDetail: OrderDetailRoute? = nil

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
