import SwiftUI
import UIKit
import UserNotifications

// MARK: - DTOs (GET api/common/notifications, /unread-count)

struct NotificationsListData: Decodable {
    let notifications: [NotificationDTO]
    let unread_count: Int
    let pagination: NotifPagination?
}

struct NotifPagination: Decodable {
    let page: Int
    let per_page: Int
    let total: Int
    let total_pages: Int
}

struct UnreadCountData: Decodable {
    let unread_count: Int
}

/// One notification. `type` (e.g. "order.status", "return.decision", "stock.low")
/// drives the icon and which screen a tap opens.
struct NotificationDTO: Decodable, Identifiable, Hashable {
    let id: String
    let type: String
    let title: String
    let body: String?
    let data: NotifPayload?
    let read_at: String?
    let created_at: String?
    let is_read: Bool

    /// Resolved through the shared `PushRoute.resolve`, so a row tap and a push tap for
    /// the same payload always land on the same screen.
    var route: PushRoute {
        PushRoute.resolve(type: type, route: data?.route, ids: data?.ids ?? PushIds())
    }

    /// Important = any return decision, or an order whose status is Failed/Cancelled.
    /// Mirrors the Trader web portal exactly:
    ///   important = type=="return.decision"
    ///            || (type=="order.status" && status in {"Failed","Cancelled"})
    ///
    /// The comparison is case-insensitive and also reads `status_key`: the push contract
    /// uses machine values ("cancelled", "out_for_delivery") while the portal uses display
    /// case, and a row built from either source has to raise the same flag.
    var isImportant: Bool {
        if type == "return.decision" { return true }
        if type == "order.status" {
            return Self.isFailedOrCancelled(data?.status)
                || Self.isFailedOrCancelled(data?.status_key)
        }
        return false
    }

    private static func isFailedOrCancelled(_ status: String?) -> Bool {
        guard let s = status?.trimmingCharacters(in: .whitespaces).lowercased() else { return false }
        return s == "failed" || s == "cancelled" || s == "canceled"
    }

    var icon: String {
        switch route {
        case .order:         return "bag.fill"
        case .delivery:      return "shippingbox.fill"
        case .grv:           return "shippingbox.and.arrow.backward.fill"
        case .returns:       return "arrowshape.turn.up.left.fill"
        case .inventory:     return "archivebox.fill"
        case .invoice:       return "doc.text.fill"
        case .finance, .wallet: return "creditcard.fill"
        case .vas:           return "antenna.radiowaves.left.and.right"
        case .promotion, .product, .marketplace, .cart: return "tag.fill"
        case .report:        return "chart.bar.fill"
        case .rewards:       return "gift.fill"
        case .settings:      return "lock.fill"
        case .notifications: return "bell.fill"
        }
    }

    var tint: Color {
        switch route {
        case .order, .promotion, .product, .marketplace, .cart, .notifications, .settings:
            return Brand.purple
        case .returns, .rewards:
            return Brand.warning
        case .delivery, .grv, .inventory, .vas, .report:
            return Brand.info
        case .invoice, .finance, .wallet:
            return Brand.success
        }
    }
}

/// The `data` object — only the fields used for navigation and the "important" flag are
/// modelled. See `FCM-settings/3-Event-Catalogue.md` §3.1 for the full dictionary;
/// unmodelled keys are ignored.
struct NotifPayload: Decodable, Hashable {
    /// "order" | "delivery" | "grv" | "return" | "invoice" | "finance" | "wallet"
    /// | "inventory" | "vas" | "promotion" | "product" | "marketplace" | "cart"
    /// | "report" | "rewards" | "settings" | "notifications".
    let route: String?
    let order_id: Int?
    let order_number: String?
    let grn_id: Int?
    let grn_number: String?
    let grv_id: Int?
    let grv_number: String?
    let invoice_id: Int?
    let invoice_number: String?
    let product_id: Int?
    let promotion_id: Int?
    let transaction_id: Int?
    /// Order status — "Cancelled" or the machine form "cancelled"; drives `isImportant`.
    let status: String?
    /// Machine form of `status` when the server sends both, e.g. "out_for_delivery".
    let status_key: String?
    let decision: String?

    /// The feed's numeric ids in the shape the shared resolver expects.
    var ids: PushIds {
        PushIds(orderId: positive(order_id),
                grnId: positive(grn_id),
                grvId: positive(grv_id),
                invoiceId: positive(invoice_id),
                productId: positive(product_id).map { String($0) },
                promotionId: positive(promotion_id).map { String($0) },
                transactionId: positive(transaction_id).map { String($0) },
                notificationId: nil)
    }

    private func positive(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }
}

// MARK: - Screen store

/// Loads the notification feed (filter all/unread, paged) and marks notifications read.
@MainActor
final class NotificationsStore: ObservableObject {
    @Published var items: [NotificationDTO] = []
    @Published var filter = "all"          // "all" | "unread"
    @Published var loading = false
    @Published var unreadCount = 0
    @Published var total = 0
    @Published var page = 1
    @Published var totalPages = 1

    let perPage = 8

    func load(page requestedPage: Int = 1) async {
        loading = true
        do {
            let data = try await APIClient.shared.getNotifications(
                filter: filter, page: requestedPage, perPage: perPage)
            items = data.notifications
            unreadCount = data.unread_count
            NotificationBadge.shared.count = data.unread_count
            if let p = data.pagination {
                page = p.page
                total = p.total
                totalPages = max(1, p.total_pages)
            }
        } catch {
            items = []
        }
        loading = false
    }

    func setFilter(_ f: String) async {
        guard f != filter else { return }
        filter = f
        await load(page: 1)
    }

    /// Mark one notification read (optimistic; refreshes the shared badge).
    func markRead(_ n: NotificationDTO) async {
        guard !n.is_read else { return }
        if filter == "unread" {
            items.removeAll { $0.id == n.id }
        } else if let idx = items.firstIndex(where: { $0.id == n.id }) {
            items[idx] = n.readCopy()
        }
        if unreadCount > 0 { unreadCount -= 1 }
        try? await APIClient.shared.markNotificationRead(id: n.id)
        await NotificationBadge.shared.refresh()
    }

    func markAll() async {
        try? await APIClient.shared.markAllNotificationsRead()
        await load(page: 1)
        await NotificationBadge.shared.refresh()
    }

    var readCount: Int { max(0, total - unreadCount) }
    var importantOnPage: Int { items.filter { $0.isImportant }.count }
}

private extension NotificationDTO {
    /// A copy flagged read (DTO is immutable / decoded). Uses the compiler-synthesized
    /// memberwise initializer.
    func readCopy() -> NotificationDTO {
        NotificationDTO(id: id, type: type, title: title, body: body, data: data,
                        read_at: read_at, created_at: created_at, is_read: true)
    }	
}

// MARK: - Shared unread badge (header bell)

/// App-wide unread count for the header bell badge. Refresh on header appear and
/// after marking notifications read.
@MainActor
final class NotificationBadge: ObservableObject {
    static let shared = NotificationBadge()
    @Published var count = 0

    private init() {}

    func refresh() async {
        if let d = try? await APIClient.shared.getUnreadCount() {
            count = d.unread_count
            applyToAppIcon(d.unread_count)
        }
    }

    /// Keeps the springboard badge in step with the bell.
    ///
    /// The server sends `aps.badge` as the unread total at send time, so iOS is only
    /// correct until the user reads something in-app — without this the icon keeps
    /// showing the old count until the next push arrives.
    private func applyToAppIcon(_ count: Int) {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }
}

// MARK: - Date formatting

enum NotifFmt {
    private static func parse(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return f.date(from: raw)
    }

    /// Recent (< 24h) → "x hours/minutes ago"; older → "dd MMM yyyy, HH:mm".
    static func relative(_ raw: String?) -> String {
        guard let d = parse(raw) else { return raw ?? "" }
        let diff = Date().timeIntervalSince(d)
        if diff >= 0 && diff < 24 * 3600 {
            let hours = Int(diff / 3600)
            if hours >= 1 { return "\(hours) hour\(hours == 1 ? "" : "s") ago" }
            let mins = Int(diff / 60)
            if mins >= 1 { return "\(mins) minute\(mins == 1 ? "" : "s") ago" }
            return "Just now"
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd MMM yyyy, HH:mm"
        return f.string(from: d)
    }
}
