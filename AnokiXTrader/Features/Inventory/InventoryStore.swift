import SwiftUI

// MARK: - Inventory DTOs (GET api/trader/inventory + history + analytics)

struct InventoryData: Decodable {
    let summary: InventorySummaryDTO?
    let chart: [InvChartSlice]?
    let fast_moving: [InvFastMover]?
    let rows: [InvRow]?
    let movements: [InvMovement]?
}

struct InventorySummaryDTO: Decodable {
    let total_stock_value: Double?
    let total_units: Int?
    let low_stock: Int?
    let out_of_stock: Int?
    let stock_movement: Int?
    let total_products: Int?
}

struct InvChartSlice: Decodable, Hashable {
    let type: String?
    let value: Double?
    let color: String?
}

struct InvFastMover: Decodable, Hashable, Identifiable {
    let rank: Int?
    let name: String?
    let units: Int?
    var id: Int { rank ?? 0 }
}

/// One product line on the inventory table.
struct InvRow: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let sku: String?
    let barcode: String?
    let category: String?
    let brand: String?
    let warehouse: String?
    let units: Int?
    let capacity: Int?
    let stockValue: Double?
    let stockStatus: String?
    let movement: String?
    let soldLast30: Int?
    let updatedAt: String?
    let imageColor: String?

    var onHand: Int { units ?? 0 }
    var value: Double { stockValue ?? 0 }
    var statusLabel: String { InvFmt.statusLabel(stockStatus) }
    var statusTone: (fg: Color, bg: Color) { InvFmt.statusTone(stockStatus) }
    var stockPercent: Double {
        let cap = max(1, capacity ?? 0)
        return min(100, max(0, Double(onHand) * 100.0 / Double(cap)))
    }
}

/// One stock-ledger entry.
struct InvMovement: Decodable, Identifiable, Hashable {
    let id: Int
    let product_id: Int?
    let product_name: String?
    let movement_type: String?
    let reference_number: String?
    let quantity_in: Int?
    let quantity_out: Int?
    let balance_after: Int?
    let note: String?
    let created_at: String?

    var net: Int { (quantity_in ?? 0) - (quantity_out ?? 0) }
}

struct InventoryHistoryData: Decodable {
    let product: InvHistProduct?
    let on_hand: Int?
    let average_cost: Double?
    let stock_value: Double?
    let low_stock_threshold: Int?
    let status: String?
    let updated_at: String?
    let movements: [InvMovement]?
}

struct InvHistProduct: Decodable {
    let id: Int?
    let name: String?
    let sku: String?
    let barcode: String?
    let category: String?
    let brand: String?
}

struct InventoryAnalyticsData: Decodable {
    let window_days: Int?
    let ageing: [InvAgeing]?
    let gross_profit: InvGrossProfit?
    let reorder: [InvReorder]?
}

struct InvAgeing: Decodable, Hashable {
    let label: String?
    let products: Int?
    let units: Int?
    let value: Double?
    let color: String?
}

struct InvGrossProfit: Decodable {
    let net_revenue: Double?
    let cogs: Double?
    let gross_profit: Double?
    let margin_pct: Double?
    let units_sold: Int?
}

struct InvReorder: Decodable, Identifiable, Hashable {
    let product_id: Int
    let name: String?
    let sku: String?
    let on_hand: Int?
    let threshold: Int?
    let sold_last_30: Int?
    let suggested: Int?
    let urgency: String?
    var id: Int { product_id }
}

// MARK: - Store

@MainActor
final class InventoryStore: ObservableObject {
    @Published var summary: InventorySummaryDTO?
    @Published var chart: [InvChartSlice] = []
    @Published var fastMoving: [InvFastMover] = []
    @Published var rows: [InvRow] = []
    @Published var movements: [InvMovement] = []
    @Published var loading = false
    @Published var error: String?
    @Published var filter = "all"
    @Published var search = ""
    /// nil = "All Categories" / "All Brands".
    @Published var category: String?
    @Published var brand: String?
    /// True once a load has completed, so the view can tell "empty" from "not loaded yet".
    @Published var loaded = false

    func load() async {
        loading = true
        error = nil
        do {
            let data = try await APIClient.shared.getInventory()
            summary = data.summary
            chart = data.chart ?? []
            fastMoving = data.fast_moving ?? []
            rows = data.rows ?? []
            movements = data.movements ?? []
            pruneStaleSelections()
            loaded = true
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Failed to load inventory."
        }
        loading = false
    }

    /// Category/brand options come from the rows the server returned (the endpoint takes
    /// no filter params), so the pickers only ever offer values that can actually match.
    var categories: [String] {
        distinct(rows.compactMap { $0.category })
    }

    var brands: [String] {
        distinct(rows.compactMap { $0.brand })
    }

    private func distinct(_ values: [String]) -> [String] {
        Array(Set(values.filter { !$0.isEmpty })).sorted { $0.lowercased() < $1.lowercased() }
    }

    /// Drops a category/brand selection the freshly loaded rows can no longer satisfy,
    /// so a stale pick can't leave the list permanently empty.
    private func pruneStaleSelections() {
        if let c = category, !categories.contains(c) { category = nil }
        if let b = brand, !brands.contains(b) { brand = nil }
    }

    /// Adjust stock (signed quantity), then refresh.
    func adjust(productId: Int, quantity: Int, reason: String) async throws {
        try await APIClient.shared.adjustInventory(productId: productId, quantity: quantity, reason: reason)
        await load()
    }

    var filteredRows: [InvRow] {
        rows.filter { matchesTab($0) && matchesSearch($0) && matchesCategory($0) && matchesBrand($0) }
    }

    private func matchesTab(_ row: InvRow) -> Bool {
        switch filter {
        case "all":  return true
        case "fast": return row.movement == "fast"
        case "slow": return row.movement == "slow"
        default:     return row.stockStatus == filter
        }
    }

    /// Product name, SKU or barcode — matching the portal's search placeholder.
    private func matchesSearch(_ row: InvRow) -> Bool {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return true }
        return [row.name, row.sku, row.barcode]
            .compactMap { $0?.lowercased() }
            .contains { $0.contains(q) }
    }

    private func matchesCategory(_ row: InvRow) -> Bool {
        guard let category else { return true }
        return row.category == category
    }

    private func matchesBrand(_ row: InvRow) -> Bool {
        guard let brand else { return true }
        return row.brand == brand
    }
}

// MARK: - Formatting + reasons

enum InvFmt {
    static func money(_ value: Double) -> String { Money.rand(value) }

    static func statusLabel(_ key: String?) -> String {
        switch key ?? "" {
        case "out_of_stock": return "Out of Stock"
        case "low_stock":    return "Low Stock"
        case "damaged":      return "Damaged"
        case "expired":      return "Expired"
        default:             return "In Stock"
        }
    }

    static func statusTone(_ key: String?) -> (fg: Color, bg: Color) {
        switch key ?? "" {
        case "low_stock":    return (Brand.warning, Brand.warningBg)
        case "out_of_stock": return (Brand.danger, Brand.dangerBg)
        case "damaged":      return (Color(hex: "#DB2777"), Color(hex: "#FCE7F3"))
        case "expired":      return (Color(hex: "#78716C"), Color(hex: "#F5F5F4"))
        default:             return (Brand.success, Brand.successBg)
        }
    }

    static func movementTypeLabel(_ type: String?) -> String {
        switch type ?? "" {
        case "grv":        return "Goods received"
        case "grn":        return "Return"
        case "sale":       return "Sale"
        case "adjustment": return "Adjustment"
        case "order":      return "Order"
        case "":           return ""
        default:           return (type ?? "").prefix(1).uppercased() + (type ?? "").dropFirst()
        }
    }

    /// "dd/MM/yyyy HH:mm:ss" → "25 Jun 2026, 21:31".
    static func dateTime(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd/MM/yyyy HH:mm:ss"
        guard let d = f.date(from: raw) else { return raw }
        f.dateFormat = "dd MMM yyyy, HH:mm"
        return f.string(from: d)
    }
}

enum InvAdjustReason {
    static let keys = ["stock_count", "damaged", "expired", "theft", "found", "correction", "other"]
    static let labels = ["Stock count", "Damaged", "Expired", "Theft / loss", "Found", "Correction", "Other"]
    static func label(_ key: String) -> String {
        if let i = keys.firstIndex(of: key) { return labels[i] }
        return key
    }
}
