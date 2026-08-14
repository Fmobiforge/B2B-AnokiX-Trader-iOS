import SwiftUI

// MARK: - Support DTOs (GET api/common/support/*)

/// Envelope `data` for the Support Centre landing screen.
struct SupportOverviewData: Decodable {
    let channels: SupportChannels?
    /// Help-article topics. Empty while the knowledge base is still being written.
    let categories: [SupportCategoryDTO]?
    let popular: [SupportArticleDTO]?
    let tickets: [SupportTicketDTO]?
    let inbox_awaiting: Int?
}

/// Envelope `data` shared by create / detail / reply / close — all return the ticket.
struct SupportTicketData: Decodable {
    let ticket: SupportTicketDTO?
}

/// Envelope `data` for GET .../articles/search.
struct SupportArticlesData: Decodable {
    let query: String?
    let articles: [SupportArticleDTO]?
    let total: Int?
}

/// Which ways of reaching support are switched on for this merchant.
struct SupportChannels: Decodable {
    let tickets: SupportToggle?
    let callback: SupportToggle?
    let whatsapp: SupportWhatsApp?
    let live_chat: SupportToggle?
    let atlas: SupportToggle?
    let email: SupportEmail?
    let phone: SupportPhone?
    /// Free-text opening hours. May be blank.
    let hours: String?

    var ticketsEnabled: Bool { tickets?.enabled == true }
    var callbackEnabled: Bool { callback?.enabled == true }
    var whatsappEnabled: Bool { whatsapp?.enabled == true }
    var emailEnabled: Bool { email?.enabled == true && !(email?.address ?? "").isEmpty }
    var phoneEnabled: Bool { phone?.enabled == true && !(phone?.number ?? "").isEmpty }
}

struct SupportToggle: Decodable {
    let enabled: Bool?
}

struct SupportWhatsApp: Decodable {
    let enabled: Bool?
    /// Ready-made wa.me link with the greeting pre-filled.
    let link: String?
    /// Human-readable number, e.g. "+1 5674987536".
    let display: String?

    /// Digits only, for the `whatsapp://` deep link.
    var msisdn: String? {
        let source = (display?.isEmpty == false ? display : link) ?? ""
        let digits = source.filter(\.isNumber)
        return digits.isEmpty ? nil : digits
    }
}

struct SupportEmail: Decodable {
    let enabled: Bool?
    let address: String?
}

struct SupportPhone: Decodable {
    let enabled: Bool?
    let number: String?
}

struct SupportCategoryDTO: Decodable, Identifiable, Hashable {
    let key: String
    let name: String

    var id: String { key }
}

struct SupportArticleDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String?
    let excerpt: String?
}

/// One support ticket. `messages` is only populated by the detail endpoint.
struct SupportTicketDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let ticket_number: String?
    let subject: String?
    /// Who the ticket was addressed to. Nil means anokiX Support; a value means the
    /// trader raised it with that distributor instead.
    let distributor_id: Int?
    let distributor_name: String?
    let category: String?
    /// "web" | "callback".
    let channel: String?
    /// "open" | "closed".
    let status: String?
    /// "low" | "normal" | "high" | "urgent".
    let priority: String?
    let callback_phone: String?
    /// "dd/MM/yyyy HH:mm:ss".
    let created_at: String?
    let last_reply_at: String?
    /// "merchant" | "agent" | "system".
    let last_reply_by: String?
    let resolved_at: String?
    let is_open: Bool?
    let messages: [SupportMessageDTO]?

    var open: Bool { is_open ?? ((status ?? "").lowercased() == "open") }

    var statusLabel: String { open ? "Open" : "Closed" }

    var statusTone: (fg: Color, bg: Color) {
        open ? (Brand.danger, Brand.dangerBg) : (Brand.success, Brand.successBg)
    }

    /// Sub-line on the list row: who we are waiting on.
    var waitingLabel: String {
        guard open else { return "Closed" }
        return (last_reply_by ?? "").lowercased() == "merchant"
            ? "Waiting for support" : "Support replied"
    }

    /// "normal" carries no information, so it is not badged.
    var priorityBadge: (label: String, fg: Color, bg: Color)? {
        let p = (priority ?? "").lowercased()
        guard !p.isEmpty, p != "normal" else { return nil }
        let label = p.prefix(1).uppercased() + p.dropFirst()
        switch p {
        case "urgent": return (label, Brand.danger, Brand.dangerBg)
        case "high":   return (label, Brand.warning, Brand.warningBg)
        default:       return (label, Brand.textSecondary, Brand.surfaceVariant)
        }
    }
}

/// One entry in a ticket conversation.
struct SupportMessageDTO: Decodable, Identifiable, Hashable {
    let id: Int
    /// "merchant" | "agent" | "system".
    let author_type: String?
    let author_name: String?
    let body: String?
    let is_internal: Bool?
    /// "dd/MM/yyyy HH:mm:ss".
    let created_at: String?

    var isMine: Bool { (author_type ?? "").lowercased() == "merchant" }
    var isSystem: Bool { (author_type ?? "").lowercased() == "system" }
}

// MARK: - Ticket priority

/// The priority options on the Create Ticket form. The codes go to the API; the
/// labels are worded for a trader running a shop.
enum TicketPriority: String, CaseIterable, Identifiable {
    case low, normal, high, urgent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low:    return "Low — whenever you can"
        case .normal: return "Normal"
        case .high:   return "High — it's affecting my store"
        case .urgent: return "Urgent — I can't trade"
        }
    }
}

// MARK: - Store

/// Loads GET api/common/support/overview and drives the help-article search.
@MainActor
final class SupportStore: ObservableObject {
    @Published private(set) var channels: SupportChannels?
    @Published private(set) var categories: [SupportCategoryDTO] = []
    @Published private(set) var tickets: [SupportTicketDTO] = []
    @Published private(set) var articles: [SupportArticleDTO] = []
    @Published private(set) var loading = false
    @Published var error: String?

    @Published var search = ""
    /// Non-nil while showing search results rather than the popular topics.
    @Published private(set) var activeQuery: String?

    /// The trader's distributors, for the "Who should answer this?" picker.
    @Published private(set) var distributors: [TraderDistributorDTO] = []

    private var popular: [SupportArticleDTO] = []

    var hasAnyChannel: Bool {
        guard let channels else { return false }
        return channels.whatsappEnabled || channels.callbackEnabled
            || channels.ticketsEnabled || channels.phoneEnabled || channels.emailEnabled
    }

    func load() async {
        loading = true
        do {
            let data = try await APIClient.shared.getSupportOverview()
            channels = data.channels
            categories = data.categories ?? []
            tickets = data.tickets ?? []
            popular = data.popular ?? []
            if activeQuery == nil { articles = popular }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription
                ?? "Could not load the Support Centre."
        }
        loading = false
    }

    /// Loaded alongside the overview so the Create Ticket sheet opens with the picker
    /// ready. A failure is silent — the picker then offers anokiX Support only, which
    /// is the default anyway.
    func loadDistributors() async {
        guard distributors.isEmpty else { return }
        if let data = try? await APIClient.shared.getDistributors() {
            distributors = data.distributors
        }
    }

    func runSearch() async {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            activeQuery = nil
            articles = popular
            return
        }
        do {
            let data = try await APIClient.shared.searchSupportArticles(query: q)
            activeQuery = q
            articles = data.articles ?? []
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription
                ?? "Could not search help articles."
        }
    }
}

// MARK: - Dates

/// Ticket timestamps arrive as "dd/MM/yyyy HH:mm:ss" on the list and
/// "yyyy-MM-dd HH:mm:ss" on reply fields, so both shapes are tried.
enum SupportFmt {
    private static func formatter(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = pattern
        return f
    }

    static func parse(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        for pattern in ["dd/MM/yyyy HH:mm:ss", "yyyy-MM-dd HH:mm:ss"] {
            if let d = formatter(pattern).date(from: raw) { return d }
        }
        return nil
    }

    /// "13/08/2026 20:33:41" → "13 Aug, 20:33".
    static func shortDateTime(_ raw: String?) -> String {
        guard let d = parse(raw) else { return raw ?? "" }
        return formatter("dd MMM, HH:mm").string(from: d)
    }

    /// "13/08/2026 20:33:41" → "20:33".
    static func time(_ raw: String?) -> String {
        guard let d = parse(raw) else { return "" }
        return formatter("HH:mm").string(from: d)
    }
}
