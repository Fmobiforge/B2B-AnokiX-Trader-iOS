import SwiftUI

/// A distributor option for the Orders filter, discovered from the loaded orders.
struct DistributorOption: Identifiable, Hashable {
    let id: String
    let name: String
}

/// Loads + filters the trader's orders from GET /api/trader/orders.
/// Mirrors the Android `OrdersFragment`: keyword search, distributor filter
/// (populated from the returned orders), date range, status tabs with counts,
/// and pagination.
@MainActor
final class OrdersStore: ObservableObject {
    @Published var orders: [OrderDTO] = []
    @Published var statusCounts: StatusCountsDTO?
    @Published var pagination: PaginationDTO?
    @Published var loading = false
    @Published var error: String?
    @Published var knownDistributors: [DistributorOption] = []

    // Filter state
    @Published var status = "all"
    @Published var distributorId: String?
    @Published var distributorName: String?
    @Published var search = ""
    @Published var dateFrom = ""
    @Published var dateTo = ""

    private(set) var page = 1
    let perPage = 10

    init() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        dateTo = OrderFmt.apiDate(today)
        dateFrom = OrderFmt.apiDate(cal.date(byAdding: .day, value: -30, to: today) ?? today)
    }

    func load() async {
        loading = true
        error = nil
        do {
            let data = try await APIClient.shared.getOrders(
                distributorId: distributorId, search: search, dateFrom: dateFrom,
                dateTo: dateTo, status: status, page: page, perPage: perPage)
            orders = data.orders
            statusCounts = data.status_counts
            pagination = data.pagination
            mergeDistributors(data.orders)
            loading = false
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Failed to load orders."
            orders = []
            statusCounts = nil
            pagination = nil
            loading = false
        }
    }

    func reload() {
        page = 1
        Task { await load() }
    }

    func setStatus(_ key: String) {
        guard key != status else { return }
        status = key
        reload()
    }

    func setDistributor(_ option: DistributorOption?) {
        distributorId = option?.id
        distributorName = option?.name
        reload()
    }

    func setDateRange(from: Date, to: Date) {
        dateFrom = OrderFmt.apiDate(from)
        dateTo = OrderFmt.apiDate(to)
        reload()
    }

    func nextPage() {
        guard let p = pagination, page < p.total_pages else { return }
        page += 1
        Task { await load() }
    }

    func prevPage() {
        guard page > 1 else { return }
        page -= 1
        Task { await load() }
    }

    func count(for key: String) -> Int { statusCounts?.count(for: key) ?? 0 }

    private func mergeDistributors(_ list: [OrderDTO]) {
        var map = Dictionary(uniqueKeysWithValues: knownDistributors.map { ($0.id, $0.name) })
        for o in list {
            if let id = o.distributor?.id {
                map[String(id)] = o.distributorName
            }
        }
        knownDistributors = map.map { DistributorOption(id: $0.key, name: $0.value) }
            .sorted { $0.name < $1.name }
    }
}

/// Formatting helpers for the Orders screens (dates, currency, time windows).
enum OrderFmt {
    private static func formatter(_ pattern: String, utc: Bool = false) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        if utc { f.timeZone = TimeZone(identifier: "UTC") }
        f.dateFormat = pattern
        return f
    }

    static func apiDate(_ date: Date) -> String { formatter("yyyy-MM-dd").string(from: date) }

    /// "yyyy-MM-dd" → Date (for seeding the range picker).
    static func parseApiDate(_ raw: String) -> Date? { formatter("yyyy-MM-dd").date(from: raw) }

    /// "yyyy-MM-dd" → "28 May 2026".
    static func display(_ raw: String) -> String {
        guard let d = formatter("yyyy-MM-dd").date(from: raw) else { return raw }
        return formatter("dd MMM yyyy").string(from: d)
    }

    /// "24/06/2026 21:13:56" → "24 Jun 2026, 21:13".
    static func createdAt(_ raw: String?) -> String {
        guard let raw, let d = formatter("dd/MM/yyyy HH:mm:ss").date(from: raw) else { return raw ?? "" }
        return formatter("dd MMM yyyy, HH:mm").string(from: d)
    }

    /// "2026-06-26" → "26 Jun 2026".
    static func deliveryDate(_ raw: String?) -> String {
        guard let raw, let d = formatter("yyyy-MM-dd").date(from: raw) else { return raw ?? "" }
        return formatter("dd MMM yyyy").string(from: d)
    }

    static func money(_ value: Double) -> String { CurrencyFmt.format(value, symbol: "R") }

    /// "08:00:00" + "22:00:00" → "08:00–22:00".
    static func timeWindow(_ start: String?, _ end: String?) -> String {
        let s = trim(start), e = trim(end)
        if s.isEmpty && e.isEmpty { return "" }
        return "\(s)–\(e)"
    }

    private static func trim(_ t: String?) -> String {
        guard let t else { return "" }
        return t.count >= 5 ? String(t.prefix(5)) : t
    }
}

/// Deterministic logo palette keyed by distributor id (mirrors the portal tints).
enum OrderLogo {
    private static let colors = ["#EC4899", "#7C3AED", "#2563EB", "#0891B2", "#16A34A", "#EA580C", "#D97706"]

    static func color(_ distributorId: Int?) -> Color {
        let id = distributorId ?? 0
        return Color(hex: colors[abs(id) % colors.count])
    }

    static func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let s = parts.compactMap { $0.first }.map(String.init).joined().uppercased()
        return s.isEmpty ? "?" : s
    }
}
