import SwiftUI

// MARK: - Rewards DTOs (GET api/common/rewards/overview)

/// Envelope `data` for the whole anokiX rewards (Limes) screen in one round trip: points
/// balance, benefits, tier progress, the points ledger, the voucher catalog, running
/// promotions and the trader's invite code.
///
/// Everything is optional and every list decodes leniently — this screen is read-only
/// apart from redemption, and one unfamiliar row must never blank the page.
struct RewardsOverviewData: Decodable {
    let balance: RewardsBalanceDTO?
    let benefits: RewardsBenefitsDTO?
    let tier: RewardsTierDTO?
    let activity: [RewardsActivityDTO]
    let pagination: RewardsPaginationDTO?
    let vouchers: [RewardVoucherDTO]
    let promotions: [RewardPromotionDTO]
    let referral: RewardsReferralDTO?

    private enum CodingKeys: String, CodingKey {
        case balance, benefits, tier, activity, pagination, vouchers, promotions, referral
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        balance = try? c.decode(RewardsBalanceDTO.self, forKey: .balance)
        benefits = try? c.decode(RewardsBenefitsDTO.self, forKey: .benefits)
        tier = try? c.decode(RewardsTierDTO.self, forKey: .tier)
        activity = c.decodeLenientList(RewardsActivityDTO.self, forKey: .activity)
        pagination = try? c.decode(RewardsPaginationDTO.self, forKey: .pagination)
        vouchers = c.decodeLenientList(RewardVoucherDTO.self, forKey: .vouchers)
        promotions = c.decodeLenientList(RewardPromotionDTO.self, forKey: .promotions)
        referral = try? c.decode(RewardsReferralDTO.self, forKey: .referral)
    }
}

/// The green hero card: what the trader has, what it is worth, what is about to lapse.
struct RewardsBalanceDTO: Decodable {
    let points: Int?
    /// Rand value of `points`.
    let value: Double?
    let earned_this_month: Int?
    /// Points that lapse on `expiring_date`. Zero when nothing is due to lapse.
    let expiring: Int?
    /// Already formatted for display, e.g. "18 Sep 2026".
    let expiring_date: String?
}

/// The "Your Benefits" card.
struct RewardsBenefitsDTO: Decodable {
    /// Cashback available, in Rand.
    let cashback: Double?
    /// Same value as `RewardsTierDTO.level`; shown as the monthly bonus level.
    let tier: String?
    /// Points earned from referrals so far.
    let referral: Int?
}

/// Progress towards the next tier.
struct RewardsTierDTO: Decodable {
    let level: String?
    /// Nil once the trader is on the top tier.
    let next_level: String?
    let points_away: Int?
    let current: Int?
    let target: Int?

    /// 0…1 for the progress bar, guarded so an absent target cannot divide by zero.
    var fraction: Double {
        guard let target, target > 0 else { return 0 }
        return min(1, max(0, Double(current ?? 0) / Double(target)))
    }

    var hasNextLevel: Bool { !(next_level ?? "").isEmpty }
}

/// One entry in the points ledger.
struct RewardsActivityDTO: Decodable, Identifiable, Hashable {
    let id: Int
    /// "earned" | "cashback" | "redeemed" | "expired" — new kinds may appear.
    let type: String?
    let title: String?
    let description: String?
    let points: Int
    /// False for a debit (a redemption or an expiry).
    let positive: Bool?
    /// "dd/MM/yyyy HH:mm:ss".
    let date: String?

    private enum CodingKeys: String, CodingKey {
        case id, type, title, description, points, positive, date
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        type = try? c.decode(String.self, forKey: .type)
        title = try? c.decode(String.self, forKey: .title)
        description = try? c.decode(String.self, forKey: .description)
        points = (try? c.decode(Int.self, forKey: .points)) ?? 0
        positive = try? c.decode(Bool.self, forKey: .positive)
        date = try? c.decode(String.self, forKey: .date)
    }

    var isCredit: Bool { positive ?? true }

    /// "+20 pts" / "−1,000 pts".
    var signedPoints: String {
        (isCredit ? "+" : "−") + RewardsFmt.points(points) + " pts"
    }

    var tone: Color { isCredit ? Brand.success : Brand.danger }

    /// SF Symbol for the ledger row, by entry type.
    var icon: String {
        switch (type ?? "").lowercased() {
        case "cashback": return "dollarsign.circle.fill"
        case "redeemed": return "gift"
        case "expired":  return "clock"
        default:         return "star.fill"
        }
    }
}

struct RewardsPaginationDTO: Decodable {
    let page: Int?
    let per_page: Int?
    let total: Int?
    let total_pages: Int?

    var hasMore: Bool { (page ?? 1) < (total_pages ?? 1) }
}

/// One item in the redemption catalog.
struct RewardVoucherDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let brand: String?
    let title: String?
    /// "airtime" | "data" | "grocery" — drives the icon only.
    let kind: String?
    let points: Int
    /// Rand value of the voucher.
    let cash_value: Double?
    /// "limes" fulfils live; "manual" is recorded pending.
    let provider: String?
    /// Brand colour, e.g. "#ffcc00".
    let color: String?
    /// True when the API needs a recipient phone number to fulfil (Limes airtime/data).
    let needs_msisdn: Bool?

    private enum CodingKeys: String, CodingKey {
        case id, brand, title, kind, points, cash_value, provider, color, needs_msisdn
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        brand = try? c.decode(String.self, forKey: .brand)
        title = try? c.decode(String.self, forKey: .title)
        kind = try? c.decode(String.self, forKey: .kind)
        points = (try? c.decode(Int.self, forKey: .points)) ?? 0
        cash_value = try? c.decode(Double.self, forKey: .cash_value)
        provider = try? c.decode(String.self, forKey: .provider)
        color = try? c.decode(String.self, forKey: .color)
        needs_msisdn = try? c.decode(Bool.self, forKey: .needs_msisdn)
    }

    /// First letter of the brand, for the coloured tile.
    var initial: String {
        guard let first = brand?.first else { return "?" }
        return String(first).uppercased()
    }

    var brandColor: Color {
        let hex = color ?? ""
        return hex.isEmpty ? Brand.purple : Color(hex: hex)
    }

    var pointsLabel: String { RewardsFmt.points(points) + " pts" }

    var needsNumber: Bool { needs_msisdn == true }

    /// Limes fulfils live; anything else is recorded and issued afterwards.
    var fulfilsLive: Bool { (provider ?? "").lowercased() == "limes" }
}

/// One running promotion. Copy comes from the server; `tone` picks the colour.
struct RewardPromotionDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String?
    let description: String?
    /// "green" | "lime" | "purple" — anything else falls back to the brand purple.
    let tone: String?
    let link_label: String?

    private enum CodingKeys: String, CodingKey {
        case id, title, description, tone, link_label
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        title = try? c.decode(String.self, forKey: .title)
        description = try? c.decode(String.self, forKey: .description)
        tone = try? c.decode(String.self, forKey: .tone)
        link_label = try? c.decode(String.self, forKey: .link_label)
    }

    var toneColor: Color {
        switch (tone ?? "").lowercased() {
        case "green":  return Brand.success
        case "lime":   return Color(hex: "#65A30D")
        case "blue":   return Brand.info
        case "orange": return Brand.warning
        default:       return Brand.purple
        }
    }
}

/// Invite & Earn.
struct RewardsReferralDTO: Decodable {
    let code: String?
    /// Points earned from referrals so far.
    let earnings: Int?
    /// Points paid per successful referral.
    let reward: Int?
}

// MARK: - Redeem (POST api/common/rewards/redeem)

/// The recorded redemption plus the balance left afterwards, so the screen can settle
/// without re-reading the overview.
struct RewardRedeemData: Decodable {
    let redemption: RewardRedemptionDTO?
    let balance: RewardsBalanceDTO?
}

struct RewardRedemptionDTO: Decodable {
    let id: Int?
    let voucher_id: Int?
    let brand: String?
    let title: String?
    let points: Int?
    /// "pending" | "fulfilled" | "failed".
    let status: String?
    let msisdn: String?
    let created_at: String?
}

// MARK: - Store

/// Backs the anokiX rewards screen. One endpoint carries the whole page, so a load is a
/// single call; only the points ledger is paged, and it accumulates across pages while
/// everything else is replaced.
@MainActor
final class RewardsStore: ObservableObject {
    @Published private(set) var overview: RewardsOverviewData?
    @Published private(set) var activity: [RewardsActivityDTO] = []
    @Published private(set) var loading = false
    @Published private(set) var loadingMore = false
    @Published private(set) var loaded = false
    @Published var error: String?

    private var page = 1
    private let perPage = 20

    var balance: RewardsBalanceDTO? { overview?.balance }
    var benefits: RewardsBenefitsDTO? { overview?.benefits }
    var tier: RewardsTierDTO? { overview?.tier }
    var vouchers: [RewardVoucherDTO] { overview?.vouchers ?? [] }
    var promotions: [RewardPromotionDTO] { overview?.promotions ?? [] }
    var referral: RewardsReferralDTO? { overview?.referral }

    var points: Int { balance?.points ?? 0 }
    var hasMoreActivity: Bool { overview?.pagination?.hasMore == true }

    /// The portal labels the earned figure "Points Earned (Aug)" — the month is the
    /// current one, so it is read off the clock rather than parsed out of anything.
    var currentMonth: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM"
        return f.string(from: Date())
    }

    func load() async {
        loading = true
        await fetch(page: 1)
        loading = false
        loaded = true
    }

    func loadMore() async {
        guard !loadingMore, hasMoreActivity else { return }
        loadingMore = true
        await fetch(page: page + 1)
        loadingMore = false
    }

    /// Page 1 replaces the ledger; later pages append to it. Everything outside the ledger
    /// is re-read on every page — it costs nothing extra, the endpoint returns the whole
    /// screen, and it keeps the balance honest after a redemption.
    private func fetch(page target: Int) async {
        do {
            let data = try await APIClient.shared.getRewardsOverview(page: target, perPage: perPage)
            overview = data
            page = data.pagination?.page ?? target
            if target <= 1 {
                activity = data.activity
            } else {
                activity.append(contentsOf: data.activity)
            }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Failed to load rewards."
        }
    }

    /// Spends points on a voucher. Returns the server's own wording on success.
    ///
    /// The response carries the balance left over, so the hero and the affordability of
    /// every other voucher settle immediately; the reload behind it then picks up the new
    /// ledger entry.
    func redeem(voucher: RewardVoucherDTO, msisdn: String?) async throws -> String? {
        let (result, message) = try await APIClient.shared.redeemReward(
            voucherId: voucher.id, msisdn: msisdn)
        if let settled = result.balance {
            overview = overview?.replacingBalance(settled)
        }
        await fetch(page: 1)
        return message
    }
}

extension RewardsOverviewData {
    /// Swaps in a freshly-settled balance without re-reading the rest of the page.
    func replacingBalance(_ newBalance: RewardsBalanceDTO) -> RewardsOverviewData {
        RewardsOverviewData(balance: newBalance, benefits: benefits, tier: tier,
                            activity: activity, pagination: pagination, vouchers: vouchers,
                            promotions: promotions, referral: referral)
    }

    /// Memberwise init, which the custom `init(from:)` above would otherwise suppress.
    init(balance: RewardsBalanceDTO?, benefits: RewardsBenefitsDTO?, tier: RewardsTierDTO?,
         activity: [RewardsActivityDTO], pagination: RewardsPaginationDTO?,
         vouchers: [RewardVoucherDTO], promotions: [RewardPromotionDTO],
         referral: RewardsReferralDTO?) {
        self.balance = balance
        self.benefits = benefits
        self.tier = tier
        self.activity = activity
        self.pagination = pagination
        self.vouchers = vouchers
        self.promotions = promotions
        self.referral = referral
    }
}

// MARK: - Formatting

enum RewardsFmt {
    /// "1000" → "1,000".
    static func points(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// "R1.05" for the Rand value of a points balance.
    static func rand(_ value: Double?) -> String {
        "R" + WalletFmt.decimal(value ?? 0)
    }

    /// "18/08/2026 12:43:22" → "18 Aug 2026, 12:43".
    static func dateTime(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for pattern in ["dd/MM/yyyy HH:mm:ss", "yyyy-MM-dd HH:mm:ss"] {
            f.dateFormat = pattern
            if let d = f.date(from: raw) {
                f.dateFormat = "dd MMM yyyy, HH:mm"
                return f.string(from: d)
            }
        }
        return raw
    }
}
