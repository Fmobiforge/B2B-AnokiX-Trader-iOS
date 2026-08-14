import SwiftUI

// MARK: - Reports DTOs (GET api/trader/reports, /generate, /delete)

/// Envelope `data` for the Reports screen: the catalogue of report types the trader may
/// build, the reports already generated, and the KPI summary.
struct ReportsData: Decodable {
    let available: [ReportAvailableDTO]?
    let reports: [ReportDTO]?
    let summary: ReportSummaryDTO?
}

/// Envelope `data` for generate and delete. Both return the refreshed summary;
/// generate additionally returns the newly created report.
struct ReportMutationData: Decodable {
    let report: ReportDTO?
    let summary: ReportSummaryDTO?
}

/// One entry in the "Choose a report" picker of the Generate sheet.
struct ReportAvailableDTO: Decodable, Identifiable, Hashable {
    /// Value sent as `report_key` when generating, e.g. "till_sales".
    let key: String
    let name: String
    let category: String?
    /// One-line explanation shown under the picker.
    let about: String?

    var id: String { key }
}

/// One generated report file.
struct ReportDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let category: String?
    /// "yyyy-MM-dd".
    let period_from: String?
    let period_to: String?
    let format: String?
    let size_bytes: Int?
    let row_count: Int?
    /// "ready" | "generating" | "failed".
    let status: String?
    /// Failure reason when `status` is "failed".
    let error: String?
    let downloads: Int?
    /// "yyyy-MM-dd HH:mm:ss".
    let created_at: String?

    var isReady: Bool { (status ?? "").lowercased() == "ready" }

    var statusLabel: String {
        switch (status ?? "").lowercased() {
        case "ready":                            return "Ready"
        case "generating", "pending", "queued":  return "Generating"
        case "failed":                           return "Failed"
        default:                                 return (status ?? "").isEmpty ? "—" : status!
        }
    }

    var statusTone: (fg: Color, bg: Color) {
        switch (status ?? "").lowercased() {
        case "ready":                            return (Brand.success, Brand.successBg)
        case "generating", "pending", "queued":  return (Brand.warning, Brand.warningBg)
        case "failed":                           return (Brand.danger, Brand.dangerBg)
        default:                                 return (Brand.purple, Brand.purpleLight)
        }
    }

    /// "190 B" / "1.2 KB" / "3.4 MB".
    var sizeLabel: String {
        let bytes = size_bytes ?? 0
        if bytes <= 0 { return "—" }
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        return String(format: "%.1f MB", kb / 1024)
    }

    /// "CSV · 2 rows · 190 B".
    var metaLine: String {
        let fmt = (format ?? "csv").uppercased()
        let rows = row_count ?? 0
        return "\(fmt) · \(rows) \(rows == 1 ? "row" : "rows") · \(sizeLabel)"
    }

    /// "15 Jul – 14 Aug 2026".
    var periodLabel: String { ReportFmt.range(period_from, period_to) }

    /// File name suggested for the download, e.g. "till-sales-22.csv".
    var suggestedFileName: String {
        let base = (name?.isEmpty == false ? name! : "report")
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "\(base)-\(id).\((format ?? "csv").lowercased())"
    }
}

struct ReportSummaryDTO: Decodable, Hashable {
    let generated: Int?
    let downloads: Int?
    let this_month: Int?
    let failed: Int?
}

/// A downloaded report file held in memory until it is written to disk.
struct ReportDownload {
    let bytes: Data
    let contentType: String?
    /// Name from the server's Content-Disposition, nil when it sent none.
    let fileName: String?
}

// MARK: - Category tabs

/// The category tabs the trader portal shows, each mapped to the server `category`
/// values it covers. The API groups Best Sellers under "products" (a till/POS report)
/// and Purchases under "orders" (bought on the marketplace).
enum ReportTab: String, CaseIterable, Identifiable {
    case all = "All Reports"
    case sales = "Sales"
    case pos = "POS"
    case inventory = "Inventory"
    case marketplace = "MarketPlace"
    case wallet = "Wallet"
    case rewards = "Rewards"

    var id: String { rawValue }

    /// Empty means "match everything".
    var categories: Set<String> {
        switch self {
        case .all:         return []
        case .sales:       return ["sales"]
        case .pos:         return ["products", "pos"]
        case .inventory:   return ["inventory"]
        case .marketplace: return ["orders", "marketplace"]
        case .wallet:      return ["wallet"]
        case .rewards:     return ["rewards"]
        }
    }
}

// MARK: - Store

/// Loads GET api/trader/reports and holds the on-device filter state — the endpoint
/// takes no query params, so the tab, the search text and the period all filter locally.
@MainActor
final class ReportsStore: ObservableObject {
    @Published private(set) var reports: [ReportDTO] = []
    @Published private(set) var available: [ReportAvailableDTO] = []
    @Published private(set) var summary: ReportSummaryDTO?
    @Published private(set) var loading = false
    @Published var error: String?

    // Filters
    @Published var tab: ReportTab = .all
    @Published var search = ""
    @Published var periodFrom: Date?
    @Published var periodTo: Date?

    var hasPeriodFilter: Bool { periodFrom != nil || periodTo != nil }

    var filtered: [ReportDTO] {
        let needle = search.trimmingCharacters(in: .whitespaces).lowercased()
        let categories = tab.categories
        let from = periodFrom.map(ReportFmt.api)
        let to = periodTo.map(ReportFmt.api)

        return reports.filter { r in
            if !categories.isEmpty, !categories.contains((r.category ?? "").lowercased()) {
                return false
            }
            if !needle.isEmpty {
                let haystack = [r.name, r.category, r.period_from, r.period_to]
                    .compactMap { $0?.lowercased() }
                if !haystack.contains(where: { $0.contains(needle) }) { return false }
            }
            // A report matches when its own period overlaps the filter window.
            if from != nil || to != nil {
                let start = r.period_from ?? r.period_to
                let end = r.period_to ?? r.period_from
                guard let start, let end else { return false }
                if let from, end < from { return false }
                if let to, start > to { return false }
            }
            return true
        }
    }

    func load() async {
        loading = true
        do {
            let data = try await APIClient.shared.getReports()
            reports = data.reports ?? []
            available = data.available ?? []
            summary = data.summary
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Failed to load reports."
        }
        loading = false
    }

    func clearPeriod() {
        periodFrom = nil
        periodTo = nil
    }

    /// Which catalogue entry a generated report came from, for "Generate again".
    /// Falls back to the category when the display name has since been reworded.
    func availableIndex(for report: ReportDTO) -> Int? {
        if let i = available.firstIndex(where: {
            $0.name.caseInsensitiveCompare(report.name ?? "") == .orderedSame
        }) { return i }
        return available.firstIndex {
            ($0.category ?? "").caseInsensitiveCompare(report.category ?? "") == .orderedSame
        }
    }
}

// MARK: - Dates

/// Date parsing/formatting for the Reports API: periods are "yyyy-MM-dd" and
/// `created_at` is "yyyy-MM-dd HH:mm:ss", both in UTC.
enum ReportFmt {
    private static func formatter(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = pattern
        return f
    }

    /// Date → "yyyy-MM-dd" for the API.
    static func api(_ date: Date) -> String { formatter("yyyy-MM-dd").string(from: date) }

    /// "yyyy-MM-dd" → Date.
    static func parse(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        return formatter("yyyy-MM-dd").date(from: raw)
    }

    /// "2026-07-15" + "2026-08-14" → "15 Jul – 14 Aug 2026".
    static func range(_ from: String?, _ to: String?) -> String {
        let a = parse(from)
        let b = parse(to)
        switch (a, b) {
        case (nil, nil):            return "—"
        case (let a?, nil):         return formatter("dd MMM yyyy").string(from: a)
        case (nil, let b?):         return formatter("dd MMM yyyy").string(from: b)
        case (let a?, let b?):
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC")!
            // Drop the repeated year on the left when both ends share it.
            let sameYear = cal.component(.year, from: a) == cal.component(.year, from: b)
            let left = formatter(sameYear ? "dd MMM" : "dd MMM yyyy").string(from: a)
            return "\(left) – \(formatter("dd MMM yyyy").string(from: b))"
        }
    }

    /// Date range straight from two `Date`s (the period filter pill).
    static func range(_ from: Date?, _ to: Date?) -> String {
        range(from.map(api), to.map(api))
    }

    /// "2026-08-13 22:46:59" → "13 Aug 2026, 22:46".
    static func dateTime(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "—" }
        guard let d = formatter("yyyy-MM-dd HH:mm:ss").date(from: raw) else { return raw }
        return formatter("dd MMM yyyy, HH:mm").string(from: d)
    }

    /// The last 30 days, inclusive — the period the portal opens with.
    static var defaultPeriod: (from: Date, to: Date) {
        let to = Date()
        let from = Calendar.current.date(byAdding: .day, value: -30, to: to) ?? to
        return (from, to)
    }
}
