import Foundation

// Swift ports of com.anokix.trader.model.* — same fields, same meaning.

struct ProductItem: Identifiable, Hashable {
    let id: String
    let name: String
    let sku: String
    let category: String
    let price: String
    let stockStatus: String
    /// Marketplace extras: pack size, optional badge, accent colour.
    let pack: String
    let badge: String?
    let colorHex: String

    /// POS / generic catalogue product (carries an SKU).
    init(id: String, name: String, sku: String, category: String,
         price: String, stockStatus: String, badge: String? = nil, colorHex: String = "#7C3AED") {
        self.id = id; self.name = name; self.sku = sku; self.category = category
        self.price = price; self.stockStatus = stockStatus; self.pack = ""
        self.badge = badge; self.colorHex = colorHex
    }

    /// Marketplace product (carries a pack label instead of an SKU).
    init(marketId id: String, name: String, pack: String, category: String,
         price: String, stockStatus: String, badge: String?, colorHex: String) {
        self.id = id; self.name = name; self.sku = ""; self.category = category
        self.price = price; self.stockStatus = stockStatus; self.pack = pack
        self.badge = badge; self.colorHex = colorHex
    }

    var isOutOfStock: Bool { stockStatus.caseInsensitiveCompare("Out of Stock") == .orderedSame }
    var priceValue: Double { Double(price.filter { "0123456789.".contains($0) }) ?? 0 }
}

struct InventoryItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let sku: String
    let barcode: String
    let category: String
    let brand: String
    let warehouse: String
    var units: Int
    let capacity: Int
    let stockValue: Double
    let statusKey: String    // in_stock | low_stock | out_of_stock | damaged | expired
    let movement: String     // fast | slow
    let updatedAt: String
    let imageColor: String

    var status: String {
        switch statusKey {
        case "out_of_stock": return "Out of Stock"
        case "low_stock":    return "Low Stock"
        case "damaged":      return "Damaged"
        case "expired":      return "Expired"
        default:             return "In Stock"
        }
    }

    var stockPercent: Int {
        let ceiling = max(1, capacity)
        return max(0, min(100, Int((Double(units) * 100.0 / Double(ceiling)).rounded())))
    }
}

struct Transaction: Identifiable, Hashable {
    let id = UUID()
    let type: String         // received | sent | settlement | airtime
    let title: String
    let subtitle: String
    let amount: Double
    let positive: Bool
    let date: String
    let status: String
}

struct Distributor: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let region: String
    let type: String
    let rating: String
    let products: String
    let colorHex: String
}

struct MarketPromo: Identifiable, Hashable {
    let id = UUID()
    let brand: String
    let offer: String
    let detail: String
    let expires: String
    let tone: String         // green | purple | orange
}

struct RewardVoucher: Identifiable, Hashable {
    let id = UUID()
    let brand: String
    let title: String
    let points: Int
    let colorHex: String
}

struct PointsEntry: Identifiable, Hashable {
    let id = UUID()
    let type: String
    let title: String
    let description: String
    let points: Int
    let positive: Bool
    let date: String
}

struct SupportTicket: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let status: String       // open | in_progress | resolved
    let updated: String
}

struct TraderNotification: Identifiable, Hashable {
    let id = UUID()
    let type: String
    let title: String
    let message: String
    let time: String
    var read: Bool
    let important: Bool
    let route: String
}

struct TraderReport: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let categoryLabel: String
    let period: String
    let format: String
    let status: String       // ready | generating | failed
    let fileSize: String
    let colorHex: String
}

/// Generic two-line + badge list row (Payments, Customers, Offers, Top Products, Low Stock).
struct ListItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let badge: String
}

struct MenuItem: Identifiable, Hashable {
    var id: String { key }
    let key: String
    let title: String
    let subtitle: String?
    let systemIcon: String

    init(_ key: String, _ title: String, subtitle: String? = nil, icon: String) {
        self.key = key; self.title = title; self.subtitle = subtitle; self.systemIcon = icon
    }
}

/// Dashboard recent-order row (verbatim from the portal dashboard).
struct RecentOrder: Identifiable, Hashable {
    let id = UUID()
    let orderId: String
    let amount: String
    let statusLabel: String
    let statusColor: String
    let date: String
}

/// Dashboard top-category slice.
struct CategorySlice: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let formatted: String
    let percentage: Double
    let colorHex: String
}

/// A single KPI tile on the dashboard.
struct Kpi: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
    let tintHex: String
}
