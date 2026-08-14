import SwiftUI

// MARK: - Staff DTOs (GET/POST api/trader/staff, /password, /update)

/// Envelope `data` for the staff list.
struct StaffData: Decodable {
    let staff: [StaffMemberDTO]?
    let total: Int?
    /// What a staff login is allowed to reach, e.g. ["sell"].
    let staff_capabilities: [String]?
}

/// Envelope `data` for add / set-password / update — all three return the member
/// in its new state.
struct StaffMemberData: Decodable {
    let staff: StaffMemberDTO?
}

/// One staff member. They sign in to the app with their own email and password.
struct StaffMemberDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let user_id: Int?
    /// Full name as the server composes it.
    let name: String?
    let first_name: String?
    let last_name: String?
    let email: String?
    let phone: String?
    let job_title: String?
    /// "active" | "disabled".
    let status: String?
    /// Server-side role wording, e.g. "Trader Stuff".
    let role_label: String?
    /// "yyyy-MM-dd HH:mm:ss".
    let created_at: String?
    let can_sign_in: Bool?

    var isActive: Bool { (status ?? "").lowercased() == "active" }
    var canSignIn: Bool { can_sign_in ?? isActive }

    /// Name to show, falling back to the two parts and then the email.
    var displayName: String {
        if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty {
            return name.trimmingCharacters(in: .whitespaces)
        }
        let composed = [first_name, last_name]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return composed.isEmpty ? (email ?? "") : composed
    }

    /// Uppercase initials for the avatar tile, e.g. "TN".
    var initials: String {
        let parts = displayName.split(separator: " ")
        guard let first = parts.first?.prefix(1) else { return "?" }
        let second = parts.count > 1 ? parts[parts.count - 1].prefix(1) : ""
        return (first + second).uppercased()
    }

    var accessLabel: String { canSignIn ? "Can sign in" : "Disabled" }

    var accessTone: (fg: Color, bg: Color) {
        canSignIn ? (Brand.success, Brand.successBg) : (Brand.textSecondary, Brand.surfaceVariant)
    }

    /// "Cashier · Added 12 Aug 2026".
    var metaLine: String {
        let trimmed = job_title?.trimmingCharacters(in: .whitespaces) ?? ""
        let title = trimmed.isEmpty ? "No job title" : trimmed
        return "\(title) · Added \(StaffFmt.date(created_at))"
    }
}

// MARK: - Store

/// Loads GET api/trader/staff and keeps the list in step with the single-member
/// responses that add / set-password / update send back.
@MainActor
final class StaffStore: ObservableObject {
    @Published private(set) var staff: [StaffMemberDTO] = []
    @Published private(set) var loading = false
    @Published var error: String?

    /// Never rendered from the server copy — the explainer wording is fixed — but
    /// kept so a future capability list can drive it.
    @Published private(set) var capabilities: [String] = []

    func load() async {
        loading = true
        do {
            let data = try await APIClient.shared.getStaff()
            staff = data.staff ?? []
            capabilities = data.staff_capabilities ?? []
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Could not load your staff."
        }
        loading = false
    }

    /// Swap an updated member into the list in place; reload if it is new to us.
    func merge(_ member: StaffMemberDTO?) async {
        guard let member else {
            await load()
            return
        }
        if let index = staff.firstIndex(where: { $0.id == member.id }) {
            staff[index] = member
        } else {
            await load()
        }
    }
}

// MARK: - Dates

/// `created_at` arrives as "yyyy-MM-dd HH:mm:ss".
enum StaffFmt {
    /// "2026-08-12 05:16:38" → "12 Aug 2026" (falls back to the raw value).
    static func date(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "—" }
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let d = parser.date(from: raw) else { return raw }

        let out = DateFormatter()
        out.locale = Locale(identifier: "en_US_POSIX")
        out.dateFormat = "dd MMM yyyy"
        return out.string(from: d)
    }
}
