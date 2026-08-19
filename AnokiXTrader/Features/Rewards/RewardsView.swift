import SwiftUI
import UIKit

/// anokiX rewards (Limes) — the whole screen off GET api/common/rewards/overview, laid
/// out in the reading order of the portal's three columns: points balance, benefits,
/// quick redeem, VAS services, promotions, the voucher catalog, the points ledger, tier
/// progress and Invite & Earn.
///
/// Two things here can be acted on rather than only read:
/// - **Airtime and Data** hand off to the live VAS module. The other service tiles say
///   "coming soon" — there is no endpoint behind electricity, water or TV yet, and a tile
///   that pretends otherwise is worse than one that is honest.
/// - **Redeem** spends real points through POST api/common/rewards/redeem, behind a sheet
///   that restates the cost and the balance left over.
struct RewardsView: View {
    @EnvironmentObject var router: Router
    @StateObject private var store = RewardsStore()

    @State private var toastMsg: String?
    @State private var redeeming: RewardVoucherDTO?

    /// One tile in the Quick Redeem grid / VAS Services row.
    private struct Service: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let tint: Color
        let action: Act

        enum Act { case airtime, vouchers, soon }
    }

    private let quickRedeem: [Service] = [
        Service(title: "Airtime", subtitle: "", icon: "phone.fill", tint: Brand.success, action: .airtime),
        Service(title: "Data", subtitle: "", icon: "wifi", tint: Brand.info, action: .airtime),
        Service(title: "Electricity", subtitle: "", icon: "bolt.fill", tint: Brand.warning, action: .soon),
        Service(title: "Water", subtitle: "", icon: "drop.fill", tint: Color(hex: "#0891B2"), action: .soon),
        Service(title: "Loyalty Store", subtitle: "", icon: "bag.fill", tint: Brand.purple, action: .soon),
        Service(title: "Cashback", subtitle: "", icon: "dollarsign.circle.fill", tint: Brand.success, action: .soon),
        Service(title: "Vouchers", subtitle: "", icon: "gift", tint: Color(hex: "#D97706"), action: .vouchers),
        Service(title: "More", subtitle: "", icon: "ellipsis", tint: Brand.textSecondary, action: .soon),
    ]

    private let vasServices: [Service] = [
        Service(title: "Airtime", subtitle: "Top up instantly", icon: "phone.fill",
                tint: Brand.success, action: .airtime),
        Service(title: "Data", subtitle: "Buy data bundles", icon: "wifi",
                tint: Brand.info, action: .airtime),
        Service(title: "Electricity", subtitle: "Prepaid & Postpaid", icon: "bolt.fill",
                tint: Brand.warning, action: .soon),
        Service(title: "Water", subtitle: "Pay your bill", icon: "drop.fill",
                tint: Color(hex: "#0891B2"), action: .soon),
        Service(title: "TV", subtitle: "DStv, GOtv & more", icon: "tv.fill",
                tint: Brand.purple, action: .soon),
        Service(title: "More", subtitle: "View all services", icon: "ellipsis",
                tint: Brand.textSecondary, action: .airtime),
    ]

    private let grid = [GridItem(.flexible()), GridItem(.flexible()),
                        GridItem(.flexible()), GridItem(.flexible())]

    /// Anchor for the Quick Redeem "Vouchers" tile — everything redeemable is already on
    /// this screen, so it scrolls there rather than opening a second list of the same six.
    private let voucherAnchor = "rewards.vouchers"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Earn and redeem Limes points — Powered by Limes")
                        .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                    balanceCard
                    benefitsCard
                    quickRedeemCard(proxy)
                    vasSection
                    if !store.promotions.isEmpty { promotionsSection }
                    if !store.vouchers.isEmpty { vouchersSection }
                    activityCard
                    tierCard
                    inviteCard
                }
                .padding(16)
            }
        }
        .background(Brand.background)
        .refreshable { await store.load() }
        .task { if !store.loaded { await store.load() } }
        .toast($toastMsg)
        .sheet(item: $redeeming) { voucher in
            RedeemSheet(voucher: voucher, balance: store.points) { msisdn in
                try await store.redeem(voucher: voucher, msisdn: msisdn)
            } onDone: { message in
                toastMsg = message ?? "Redeemed — \(voucher.title ?? "")"
            }
        }
        .onChange(of: store.error) { message in
            if let message { toastMsg = message; store.error = nil }
        }
    }

    // MARK: - Points balance hero

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Limes Points Balance")
                .font(.system(size: 13)).foregroundColor(Color(hex: "#D9FBE7"))

            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text("\(RewardsFmt.points(store.points)) pts")
                    .font(.system(size: 30, weight: .bold)).foregroundColor(.white)
                Spacer()
            }

            Text("≈ \(RewardsFmt.rand(store.balance?.value)) value")
                .font(.system(size: 13)).foregroundColor(Color(hex: "#D9FBE7"))

            Divider().background(Color.white.opacity(0.3)).padding(.top, 4)

            HStack(spacing: 20) {
                heroFigure("Points Earned (\(store.currentMonth))",
                           "+\(RewardsFmt.points(store.balance?.earned_this_month ?? 0))")
                heroFigure("Points Expiring", expiringLabel)
            }

            HStack {
                Spacer()
                Text("LIMES")
                    .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color(hex: "#34D399"), Color(hex: "#16A34A")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var expiringLabel: String {
        guard let b = store.balance else { return "None expiring" }
        let count = b.expiring ?? 0
        guard let date = b.expiring_date, !date.isEmpty else {
            return count == 0 ? "None expiring" : "\(RewardsFmt.points(count)) pts"
        }
        return "\(RewardsFmt.points(count)) pts on \(date)"
    }

    private func heroFigure(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11)).foregroundColor(Color(hex: "#B7F0CD"))
            Text(value)
                .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Benefits

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your Benefits")
                .font(.system(size: 15, weight: .bold)).foregroundColor(Brand.textPrimary)
                .padding(.bottom, 2)
            benefitRow("Cashback Available", "dollarsign.circle.fill", Brand.success, Brand.successBg,
                       RewardsFmt.rand(store.benefits?.cashback))
            Divider()
            benefitRow("Monthly Bonus Level", "crown.fill", Brand.purple, Brand.purpleLight,
                       store.benefits?.tier ?? "—")
            Divider()
            benefitRow("Referral Earnings", "person.badge.plus", Brand.info, Brand.infoBg,
                       "\(RewardsFmt.points(store.benefits?.referral ?? 0)) pts")
        }
        .card()
    }

    private func benefitRow(_ label: String, _ icon: String, _ tint: Color,
                            _ tile: Color, _ value: String) -> some View {
        HStack(spacing: 12) {
            iconTile(icon, tint, tile, size: 36)
            Text(label).font(.system(size: 13)).foregroundColor(Brand.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Quick Redeem + VAS Services

    private func quickRedeemCard(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quick Redeem")
                .font(.system(size: 15, weight: .bold)).foregroundColor(Brand.textPrimary)
            LazyVGrid(columns: grid, spacing: 16) {
                ForEach(quickRedeem) { service in
                    Button { run(service, proxy) } label: {
                        VStack(spacing: 8) {
                            iconTile(service.icon, service.tint,
                                     service.tint.opacity(0.12), size: 46)
                            Text(service.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Brand.textPrimary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2).minimumScaleFactor(0.8)
                                .frame(height: 28, alignment: .top)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
    }

    private var vasSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("VAS Services")
                    .font(.system(size: 17, weight: .bold)).foregroundColor(Brand.textPrimary)
                Spacer()
                Button("View all") { router.presented = .airtime }
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.purple)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(vasServices) { service in
                        Button { run(service, nil) } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                iconTile(service.icon, service.tint,
                                         service.tint.opacity(0.12), size: 40)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(service.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Brand.textPrimary)
                                    Text(service.subtitle)
                                        .font(.system(size: 11))
                                        .foregroundColor(Brand.textSecondary)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(width: 128, alignment: .leading)
                            .padding(14)
                            .background(Brand.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func run(_ service: Service, _ proxy: ScrollViewProxy?) {
        switch service.action {
        case .airtime:
            router.presented = .airtime
        case .vouchers:
            withAnimation { proxy?.scrollTo(voucherAnchor, anchor: .top) }
        case .soon:
            toastMsg = "\(service.title) is coming soon."
        }
    }

    // MARK: - Promotions

    private var promotionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Promotions & Offers")
                .font(.system(size: 17, weight: .bold)).foregroundColor(Brand.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.promotions) { promo in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(promo.title ?? "—")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Brand.textPrimary)
                                Text(promo.description ?? "")
                                    .font(.system(size: 12))
                                    .foregroundColor(Brand.textSecondary)
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            iconTile("gift", promo.toneColor, promo.toneColor.opacity(0.12), size: 42)
                        }
                        .frame(width: 250, alignment: .leading)
                        .padding(14)
                        .background(Brand.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.border, lineWidth: 1))
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Voucher catalog

    private var vouchersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Redeem with Limes")
                .font(.system(size: 17, weight: .bold)).foregroundColor(Brand.textPrimary)
                .id(voucherAnchor)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.vouchers) { voucher in
                        voucherCard(voucher)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func voucherCard(_ v: RewardVoucherDTO) -> some View {
        // Affordability is decided here rather than at the API: a Redeem button that can
        // only come back with "insufficient balance" should not look live.
        let affordable = store.points >= v.points
        return VStack(spacing: 8) {
            Text(v.initial)
                .font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                .frame(width: 46, height: 46)
                .background(v.brandColor)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(v.brand ?? "—")
                .font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
                .lineLimit(1)
            Text(v.title ?? "")
                .font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2).frame(height: 28, alignment: .top)
            Text(v.pointsLabel)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(affordable ? Brand.success : Brand.textTertiary)

            Button { redeeming = v } label: {
                Text("Redeem")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(affordable ? Brand.success : Brand.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(affordable ? Brand.success : Brand.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!affordable)
        }
        .frame(width: 146)
        .padding(14)
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.border, lineWidth: 1))
    }

    // MARK: - Points ledger

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Points Activity")
                .font(.system(size: 15, weight: .bold)).foregroundColor(Brand.textPrimary)

            if store.activity.isEmpty {
                Text("No points activity yet.")
                    .font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 22)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.activity.enumerated()), id: \.offset) { idx, entry in
                        activityRow(entry)
                        if idx < store.activity.count - 1 { Divider() }
                    }
                }
                if store.hasMoreActivity {
                    Button {
                        Task { await store.loadMore() }
                    } label: {
                        Text(store.loadingMore ? "Loading…" : "Load more")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Brand.purple)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.loadingMore)
                }
                Divider()
            }

            Text("Total Points Earned (\(store.currentMonth)): +\(RewardsFmt.points(store.balance?.earned_this_month ?? 0)) pts")
                .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                .padding(.top, 6)
        }
        .card()
    }

    private func activityRow(_ e: RewardsActivityDTO) -> some View {
        HStack(spacing: 12) {
            iconTile(e.icon, e.tone, e.tone.opacity(0.12), size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.title ?? "—")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary)
                Text(e.description ?? "")
                    .font(.system(size: 11)).foregroundColor(Brand.textSecondary).lineLimit(1)
                Text(RewardsFmt.dateTime(e.date))
                    .font(.system(size: 11)).foregroundColor(Brand.textTertiary)
            }
            Spacer()
            Text(e.signedPoints)
                .font(.system(size: 14, weight: .bold)).foregroundColor(e.tone)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Tier

    private var tierCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 15)).foregroundColor(Brand.purple)
                Text(store.tier?.level.map { "\($0) Level" } ?? "—")
                    .font(.system(size: 16, weight: .bold)).foregroundColor(Brand.textPrimary)
            }

            Text(tierAwayLabel)
                .font(.system(size: 12)).foregroundColor(Brand.textSecondary)

            ProgressView(value: store.tier?.fraction ?? 0)
                .tint(Brand.success)

            Text("\(RewardsFmt.points(store.tier?.current ?? 0)) / \(RewardsFmt.points(store.tier?.target ?? 0)) pts")
                .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
        }
        .card()
    }

    private var tierAwayLabel: String {
        guard let tier = store.tier, tier.hasNextLevel, let next = tier.next_level else {
            return "You are on the top level."
        }
        return "You are \(RewardsFmt.points(tier.points_away ?? 0)) pts away from \(next)"
    }

    // MARK: - Invite & Earn

    private var inviteCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Invite & Earn")
                    .font(.system(size: 15, weight: .bold)).foregroundColor(Brand.textPrimary)
                Spacer()
                iconTile("person.badge.plus", Brand.purple, Brand.purpleLight, size: 40)
            }

            Text(inviteBody)
                .font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let code = store.referral?.code, !code.isEmpty {
                HStack(spacing: 6) {
                    Text("Your code:")
                        .font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                    Text(code)
                        .font(.system(size: 14, weight: .bold)).foregroundColor(Brand.textPrimary)
                        .kerning(1)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = code
                        toastMsg = "Invite code copied"
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14)).foregroundColor(Brand.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Copy invite code")
                }
                .padding(14)
                .background(Brand.surfaceVariant)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = code
                        toastMsg = "Invite code copied"
                    } label: {
                        Text("Copy Invite Code")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    ShareLink(item: "Join me on anokiX and use my invite code \(code) — we both earn Limes points.") {
                        Text("Share")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Brand.textPrimary)
                            .padding(.horizontal, 18).padding(.vertical, 14)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                    }
                }
            }
        }
        .card()
    }

    private var inviteBody: String {
        let reward = RewardsFmt.points(store.referral?.reward ?? 0)
        let earned = store.referral?.earnings ?? 0
        let base = "Invite other spaza traders and earn \(reward) Limes points when they sign up and transact."
        return earned > 0 ? base + " You have earned \(RewardsFmt.points(earned)) pts so far." : base
    }

    // MARK: - Shared

    /// Pale tile, saturated glyph. Keeping the two colours far apart is the whole point —
    /// a saturated icon on a saturated tile is unreadable.
    private func iconTile(_ icon: String, _ tint: Color, _ tile: Color,
                          size: CGFloat) -> some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.4, weight: .medium))
            .foregroundColor(tint)
            .frame(width: size, height: size)
            .background(tile)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

// MARK: - Redeem sheet

/// Confirms a voucher redemption. Spending points is not reversible, so the sheet
/// restates exactly what is being bought, what it costs and what is left afterwards
/// before the button is live.
@MainActor
struct RedeemSheet: View {
    let voucher: RewardVoucherDTO
    let balance: Int
    /// Performs the redemption and returns the server's own wording.
    let redeem: (String?) async throws -> String?
    let onDone: (String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var msisdn = ""
    @State private var submitting = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    figures

                    // Only Limes-fulfilled airtime/data need a number; asking for one
                    // otherwise would be a field the API ignores.
                    if voucher.needsNumber {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Recipient mobile number")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Brand.textSecondary)
                            TextField("e.g. 0821234567", text: $msisdn)
                                .keyboardType(.phonePad)
                                .font(.system(size: 15))
                                .foregroundColor(Brand.textPrimary)
                                .padding(14)
                                .background(Brand.surface)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            Text("The airtime is loaded straight onto this number.")
                                .font(.system(size: 11)).foregroundColor(Brand.textTertiary)
                        }
                    }

                    Text(voucher.fulfilsLive
                         ? "Points are spent as soon as you confirm. Limes loads this straight away, and your points come back if it fails."
                         : "Points are spent as soon as you confirm. The voucher is recorded and issued to you shortly afterwards.")
                        .font(.system(size: 12)).foregroundColor(Brand.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let error {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.system(size: 12)).foregroundColor(Brand.danger)
                    }

                    Button(submitting ? "Please wait…" : "Confirm redemption") {
                        Task { await submit() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(submitting)
                }
                .padding(18)
            }
            .background(Brand.background)
            .navigationTitle("Redeem with Limes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundColor(Brand.textSecondary)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(voucher.initial)
                .font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                .frame(width: 46, height: 46)
                .background(voucher.brandColor)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(voucher.brand ?? "—")
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.textPrimary)
                Text(voucher.title ?? "")
                    .font(.system(size: 13)).foregroundColor(Brand.textSecondary)
            }
            Spacer()
        }
        .card(padding: 14)
    }

    private var figures: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Costs").font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                Text(voucher.pointsLabel)
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text("Balance after").font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                Text("\(RewardsFmt.points(max(0, balance - voucher.points))) pts")
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func submit() async {
        var number: String?
        if voucher.needsNumber {
            let digits = msisdn.filter(\.isNumber)
            guard !digits.isEmpty else {
                error = "Enter the mobile number to load the airtime onto."
                return
            }
            guard digits.count >= 9, digits.count <= 13 else {
                error = "That does not look like a mobile number."
                return
            }
            number = digits
        }

        error = nil
        submitting = true
        defer { submitting = false }

        do {
            let message = try await redeem(number)
            onDone(message)
            dismiss()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription
                ?? "Could not redeem this voucher."
        }
    }
}
