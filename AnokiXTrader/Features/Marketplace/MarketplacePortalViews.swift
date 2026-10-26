import SwiftUI

// Building blocks for the Trader Portal–style Marketplace home (`MarketplaceRealView`):
// section header, quick-service tiles, campaign banner, deal cards, news / story / seller /
// distributor / order rows, plus the campaign sheet, story viewer and barcode lookup sheet.
// Mirrors the Android `MarketplaceActivity`, `CampaignSheet` and `StoryViewer`.

// MARK: - Section header

struct MarketSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String = "View All"
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.app(17, .bold)).foregroundColor(Brand.textPrimary).lineLimit(1)
                if let subtitle {
                    Text(subtitle).font(.app(11)).foregroundColor(Brand.textSecondary)
                }
            }
            Spacer()
            if let onAction {
                Button(actionTitle, action: onAction)
                    .font(.app(13, .semibold)).foregroundColor(Brand.blue)
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
            }
        }
    }
}

// MARK: - Quick service tile (Airtime & Data / Electricity / POS & Devices)

struct MarketServiceTile: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.app(12, .semibold)).foregroundColor(Brand.textPrimary).lineLimit(1)
                    Text(subtitle).font(.app(10)).foregroundColor(Brand.textSecondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Campaign banner slide

/// One slide of the campaign carousel: artwork, campaign-type badge, title, blurb and a
/// single CTA ("Shop Products", or "View Details" for an announcement) — portal parity.
struct CampaignBannerCard: View {
    let banner: BannerDTO
    let campaign: CampaignDTO?
    let onOpen: () -> Void
    private let bannerHeight: CGFloat = 190

    private var typeLabel: String? {
        if let c = campaign { return c.typeLabel.isEmpty ? nil : c.typeLabel }
        let t = (banner.campaign_type ?? "").replacingOccurrences(of: "_", with: " ").uppercased()
        return t.isEmpty ? nil : t
    }

    private var ctaTitle: String {
        (campaign?.isAnnouncement ?? (banner.campaign_type == "post")) ? "View Details" : "Shop Products"
    }

    var body: some View {
        // Color.clear pins the size; the media/caption overlays can't grow the frame.
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: bannerHeight)
            .overlay(media.allowsHitTesting(false))
            .overlay(
                LinearGradient(colors: [.black.opacity(0.65), .black.opacity(0.05)],
                               startPoint: .leading, endPoint: .trailing)
                    .allowsHitTesting(false)
            )
            .overlay(alignment: .bottomLeading) { caption }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
    }

    @ViewBuilder
    private var media: some View {
        Group {
            if banner.isVideo, let url = MediaUrls.url(banner.mediaURL) {
                ZStack {
                    VideoThumbnailView(url: url)
                    LoopingVideoView(url: url).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if let url = MediaUrls.resolve(banner.mediaURL), !url.isEmpty {
                RemoteImage(url: url)
            } else {
                LinearGradient(colors: [Brand.indigo, Brand.violet], startPoint: .leading, endPoint: .trailing)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let typeLabel {
                Text(typeLabel)
                    .font(.app(9, .bold)).foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Brand.successStrong).clipShape(Capsule())
            }
            Text(banner.name ?? "").font(.app(20, .bold)).foregroundColor(.white)
                .lineLimit(2).shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 1)
            if let d = banner.description, !d.isEmpty {
                Text(d).font(.app(12)).foregroundColor(.white.opacity(0.95))
                    .lineLimit(2).shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 1)
            }
            Button(action: onOpen) {
                Text(ctaTitle).font(.app(13, .semibold)).foregroundColor(Brand.indigo)
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(Color.white).clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(16)
    }
}

// MARK: - Deal card (Best Deals / Exclusive Deals)

struct DealCard: View {
    let product: ProductDTO
    let currency: String
    /// "Only from {distributor}" badge (Exclusive Deals).
    var onlyFrom: String? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    RemoteImage(url: product.imageURL)
                        .frame(width: 136, height: 96).clipped()
                        .background(Brand.surfaceVariant)
                    if let onlyFrom, !onlyFrom.isEmpty {
                        Text("Only from \(onlyFrom)")
                            .font(.app(9, .bold)).foregroundColor(.white).lineLimit(1)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Brand.successStrong).clipShape(Capsule())
                            .padding(6)
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(product.name ?? "").font(.app(11, .semibold))
                        .foregroundColor(Brand.textPrimary).lineLimit(2)
                        .frame(height: 30, alignment: .top)
                    Text(CurrencyFmt.format(product.priceValue, symbol: currency))
                        .font(.app(15, .bold)).foregroundColor(Brand.textPrimary)
                    StockPill(count: product.stockCount)
                }
                .padding(10)
            }
            .frame(width: 136)
            .background(Brand.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct StockPill: View {
    let count: Int

    var body: some View {
        Text(count > 0 ? "In stock · \(count.formatted())" : "Out of stock")
            .font(.app(10, .medium))
            .foregroundColor(count > 0 ? Brand.successStrong : Brand.danger)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background((count > 0 ? Brand.successStrong : Brand.danger).opacity(0.1))
            .clipShape(Capsule())
    }
}

// MARK: - Rows

struct NewsRow: View {
    let post: CampaignDTO
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Rectangle().fill(Brand.blue).frame(width: 3).frame(maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 3) {
                    Text(post.name).font(.app(13, .semibold)).foregroundColor(Brand.textPrimary).lineLimit(2)
                    if let d = post.description {
                        Text(d).font(.app(12)).foregroundColor(Brand.textSecondary).lineLimit(2)
                    }
                    if let end = post.endDate, !end.isEmpty {
                        Text(end).font(.system(size: 11, design: .monospaced)).foregroundColor(Brand.textTertiary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(Brand.textTertiary)
            }
            // Lets the accent bar stretch to the text's height.
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct StoryBubble: View {
    let story: CampaignDTO
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                RemoteImage(url: story.imageURL)
                    .frame(width: 58, height: 58)
                    .background(Brand.blueBg)
                    .clipShape(Circle())
                    .padding(3)
                    .background(Circle().fill(Brand.surface))
                    .padding(2.5)
                    .background(Circle().fill(LinearGradient(colors: [Brand.sky, Brand.violet],
                                                             startPoint: .topLeading, endPoint: .bottomTrailing)))
                Text(story.name).font(.app(11)).foregroundColor(Brand.textSecondary)
                    .lineLimit(1).frame(width: 72)
            }
        }
        .buttonStyle(.plain)
    }
}

struct SupplierChip: View {
    let supplier: MarketSupplierDTO

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "building.2").font(.system(size: 13)).foregroundColor(Brand.textSecondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(supplier.name).font(.app(12, .semibold)).foregroundColor(Brand.textPrimary).lineLimit(1)
                Text("\(supplier.productCount) products").font(.app(10)).foregroundColor(Brand.textSecondary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Brand.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SellerRow: View {
    let seller: MarketSellerDTO

    var body: some View {
        HStack(spacing: 12) {
            DistributorAvatar(logoUrl: seller.logoURL,
                              initial: String(seller.name.prefix(1)).uppercased(), size: 36)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(seller.name).font(.app(13, .semibold)).foregroundColor(Brand.textPrimary).lineLimit(1)
                    if seller.isMine {
                        Text("YOURS").font(.app(9, .bold)).foregroundColor(Brand.successStrong)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Brand.successStrong.opacity(0.12)).clipShape(Capsule())
                    }
                }
                Text("\(seller.productsAvailable) products").font(.app(11)).foregroundColor(Brand.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }
}

struct MyDistributorCard: View {
    let distributor: DistributorDTO
    let productsAvailable: Int
    let onView: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                DistributorAvatar(logoUrl: distributor.logo_url,
                                  initial: String(distributor.displayName.prefix(1)), size: 40)
                Text(distributor.displayName).font(.app(14, .bold)).foregroundColor(Brand.textPrimary).lineLimit(1)
                Spacer(minLength: 0)
            }
            HStack {
                Text("Products Available").font(.app(12)).foregroundColor(Brand.textSecondary)
                Spacer()
                Text("\(productsAvailable)+").font(.app(12, .bold)).foregroundColor(Brand.textPrimary)
            }
            HStack(alignment: .top, spacing: 12) {
                Label("Coverage Area", systemImage: "mappin.and.ellipse")
                    .font(.app(12)).foregroundColor(Brand.textSecondary).fixedSize()
                Spacer(minLength: 8)
                Text(distributor.address ?? "—").font(.app(12, .semibold)).foregroundColor(Brand.textPrimary)
                    .multilineTextAlignment(.trailing)
            }
            Button(action: onView) {
                Text("View Distributor").font(.app(13, .semibold)).foregroundColor(Brand.blue)
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Brand.blue, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .card(padding: 14)
    }
}

struct RecentOrderRow: View {
    let order: MarketRecentOrderDTO
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("#\(order.number)").font(.app(13, .semibold)).foregroundColor(Brand.textPrimary)
                    Text(order.createdAt).font(.app(11)).foregroundColor(Brand.textSecondary)
                }
                Spacer()
                OrderStatusPill(label: order.status.isEmpty ? order.statusKey.capitalized : order.status,
                                key: order.statusKey)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct OrderStatusPill: View {
    let label: String
    let key: String

    private var tint: Color {
        if key.contains("deliver") || key.contains("complete") || key.contains("receiv") { return Brand.successStrong }
        if key.contains("cancel") || key.contains("reject") || key.contains("fail") { return Brand.danger }
        if key.contains("pending") || key.contains("await") { return Brand.warningStrong }
        return Brand.blue
    }

    var body: some View {
        Text(label).font(.app(10, .semibold)).foregroundColor(tint)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(tint.opacity(0.12)).clipShape(Capsule())
    }
}

/// White card with a hairline border wrapping a list of rows separated by dividers.
struct MarketListCard<Item: Identifiable, Row: View>: View {
    let items: [Item]
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Divider() }
                row(item)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
        .background(Brand.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Campaign sheet

/// Campaign detail sheet — the portal's right-hand drawer for a banner, promotion or news
/// post: artwork, distributor and type chips, description, run dates and every product the
/// campaign puts on offer. Built from the marketplace payload; no extra request.
struct CampaignSheetView: View {
    let campaign: CampaignDTO
    let currency: String
    let onProduct: (CampaignProductDTO) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    artwork
                    HStack(spacing: 8) {
                        if let d = campaign.distributorName {
                            Text(d).font(.app(12)).foregroundColor(Brand.textPrimary)
                                .padding(.horizontal, 12).padding(.vertical, 4)
                                .overlay(Capsule().stroke(Brand.border, lineWidth: 1))
                        }
                        if !campaign.typeLabel.isEmpty {
                            Text(campaign.typeLabel).font(.app(10, .bold)).foregroundColor(.white)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Brand.successStrong).clipShape(Capsule())
                        }
                    }
                    if let d = campaign.description {
                        Text(d).font(.app(13)).foregroundColor(Brand.textPrimary)
                    }
                    let runs = CampaignDates.range(campaign.startDate, campaign.endDate)
                    if !runs.isEmpty {
                        HStack {
                            Text("Runs").font(.app(12)).foregroundColor(Brand.textSecondary)
                            Spacer()
                            Text(runs).font(.app(13, .semibold)).foregroundColor(Brand.textPrimary)
                        }
                        .padding(14)
                        .background(Brand.background)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    productsSection
                    Button { dismiss() } label: {
                        Text("Close").font(.app(14, .semibold)).foregroundColor(Brand.textPrimary)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Brand.border, lineWidth: 1))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .background(Brand.surface)
            .navigationTitle(campaign.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Brand.textSecondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.light)
    }

    private var artwork: some View {
        Color.clear
            .frame(maxWidth: .infinity).frame(height: 180)
            .overlay(
                Group {
                    if let url = campaign.imageURL {
                        RemoteImage(url: url, fill: false)
                    } else {
                        LinearGradient(colors: [Brand.indigo, Brand.violet],
                                       startPoint: .leading, endPoint: .trailing)
                    }
                }
            )
            .background(Brand.background)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.border, lineWidth: 1))
    }

    @ViewBuilder
    private var productsSection: some View {
        (Text("Products in this promotion ").foregroundColor(Brand.textPrimary)
            + Text("\(campaign.products.count)").foregroundColor(Brand.textSecondary))
            .font(.app(14, .semibold))
            .padding(.top, 4)
        if campaign.products.isEmpty {
            Text("This promotion is an announcement — it does not put specific products on offer.")
                .font(.app(12)).foregroundColor(Brand.textSecondary)
        } else {
            MarketListCard(items: campaign.products) { p in
                Button { onProduct(p) } label: { productRow(p) }
                    .buttonStyle(.plain)
            }
        }
    }

    private func productRow(_ p: CampaignProductDTO) -> some View {
        HStack(spacing: 12) {
            RemoteImage(url: p.imageURL)
                .frame(width: 46, height: 46).clipped()
                .background(Brand.surfaceVariant)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if let badge = badge(for: p.role) {
                        Text(badge).font(.app(9, .bold)).foregroundColor(Brand.blue)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Brand.blueBg).clipShape(Capsule())
                    }
                    Text(p.name).font(.app(13)).foregroundColor(Brand.textPrimary).lineLimit(2)
                }
                Text("\(p.availableStock.formatted()) in stock").font(.app(11)).foregroundColor(Brand.textSecondary)
            }
            Spacer(minLength: 8)
            if p.role == .free {
                Text("Free").font(.app(14, .bold)).foregroundColor(Brand.successStrong)
            } else {
                Text(CurrencyFmt.format(p.price, symbol: currency))
                    .font(.app(14, .bold)).foregroundColor(Brand.textPrimary)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func badge(for role: CampaignProductDTO.Role) -> String? {
        switch role {
        case .single: return nil
        case .combo:  return "COMBO DEAL"
        case .buy:    return "BUY"
        case .free:   return "FREE"
        }
    }
}

enum CampaignDates {
    /// "2026-09-28" + "2026-12-31" → "28 Sep 2026 → 31 Dec 2026".
    static func range(_ start: String?, _ end: String?) -> String {
        let s = pretty(start), e = pretty(end)
        if s.isEmpty { return e }
        if e.isEmpty { return s }
        return "\(s) → \(e)"
    }

    private static func pretty(_ raw: String?) -> String {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return "" }
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: String(raw.prefix(10))) else { return raw }
        let output = DateFormatter()
        output.locale = Locale(identifier: "en_US")
        output.dateFormat = "d MMM yyyy"
        return output.string(from: date)
    }
}

// MARK: - Story viewer

/// Full-screen story viewer (portal story modal). Each story plays for five seconds then
/// advances; tap the left third to go back, elsewhere to skip. `onShown` fires once per
/// story so the caller can record the campaign view.
struct StoryViewerView: View {
    let stories: [CampaignDTO]
    let onShown: (CampaignDTO) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var index: Int
    @State private var progress: Double = 0

    private let duration: Double = 5
    private let tick: Double = 0.05
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    init(stories: [CampaignDTO], start: Int, onShown: @escaping (CampaignDTO) -> Void) {
        self.stories = stories
        self.onShown = onShown
        _index = State(initialValue: max(0, min(start, stories.count - 1)))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                if stories.indices.contains(index) {
                    RemoteImage(url: stories[index].imageURL, fill: false)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                HStack(spacing: 0) {
                    Color.clear.contentShape(Rectangle())
                        .frame(width: geo.size.width / 3)
                        .onTapGesture { step(-1) }
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture { step(1) }
                }
                VStack(spacing: 0) {
                    topBar
                    Spacer()
                    caption
                }
            }
        }
        .onAppear { if stories.indices.contains(index) { onShown(stories[index]) } }
        .onReceive(timer) { _ in
            progress += tick / duration
            if progress >= 1 { step(1) }
        }
        .statusBarHidden()
    }

    private var topBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(stories.indices, id: \.self) { i in
                    GeometryReader { g in
                        Capsule().fill(Color.white.opacity(0.3))
                            .overlay(alignment: .leading) {
                                Capsule().fill(Color.white)
                                    .frame(width: g.size.width * fill(for: i))
                            }
                    }
                    .frame(height: 3)
                }
            }
            HStack {
                Text(stories.indices.contains(index) ? (stories[index].distributorName ?? "") : "")
                    .font(.app(13, .semibold)).foregroundColor(.white)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.35)).clipShape(Circle())
                }
                .accessibilityLabel("Close story")
            }
        }
        .padding(.horizontal, 12).padding(.top, 8)
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 4) {
            if stories.indices.contains(index) {
                Text(stories[index].name).font(.app(18, .bold)).foregroundColor(.white)
                if let d = stories[index].description {
                    Text(d).font(.app(13)).foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20).padding(.top, 48).padding(.bottom, 28)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom))
    }

    private func fill(for i: Int) -> CGFloat {
        if i < index { return 1 }
        if i > index { return 0 }
        return CGFloat(min(max(progress, 0), 1))
    }

    private func step(_ delta: Int) {
        let next = index + delta
        if next >= stories.count { dismiss(); return }
        index = max(0, next)
        progress = 0
        onShown(stories[index])
    }
}

// MARK: - Barcode lookup sheet

/// Marketplace "Scan a barcode": camera first (a phone can, unlike the portal's browser),
/// with manual / handheld-scanner entry as the fallback. The first code read is handed to
/// `onCode`, which looks it up through the marketplace search, and the sheet closes.
struct MarketScanView: View {
    let onCode: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = PosScannerController()
    @State private var typed = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Scan a barcode").font(.app(18, .bold)).foregroundColor(Brand.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Brand.textSecondary).frame(width: 36, height: 36)
                }
            }
            .padding(.leading, 20).padding(.trailing, 12).padding(.top, 18).padding(.bottom, 14)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    camera
                    Text("Handheld scanner or type it in")
                        .font(.app(14, .bold)).foregroundColor(Brand.textPrimary)
                        .padding(.top, 18)
                    HStack(spacing: 8) {
                        TextField("Barcode or SKU", text: $typed)
                            .font(.app(14)).foregroundColor(Brand.textPrimary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .submitLabel(.search)
                            .onSubmit { submit(typed) }
                            .padding(.horizontal, 14).frame(height: 48)
                            .background(Brand.surfaceVariant)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        Button("Find") { submit(typed) }
                            .font(.app(14, .semibold)).foregroundColor(.white)
                            .padding(.horizontal, 20).frame(height: 48)
                            .background(Brand.blue).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.top, 8)
                    Text("Point the camera at the label, or type the code and tap Find. A Bluetooth scanner types it in and presses Enter — that works here too.")
                        .font(.app(12)).foregroundColor(Brand.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                }
                .padding(20)
            }
        }
        .background(Brand.surface)
        .onAppear {
            controller.onCode = { code in submit(code) }
            controller.start(mode: .barcode)
        }
        .onDisappear { controller.stop() }
        .preferredColorScheme(.light)
    }

    private var camera: some View {
        ZStack {
            if controller.status == .running {
                CameraPreview(session: controller.session)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.7), lineWidth: 2)
                    .padding(26)
                VStack {
                    HStack {
                        Spacer()
                        if controller.hasTorch {
                            Button { controller.toggleTorch() } label: {
                                Image(systemName: controller.torchOn ? "bolt.fill" : "bolt.slash.fill")
                                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.black.opacity(0.4)).clipShape(Circle())
                            }
                        }
                    }
                    Spacer()
                    Text(PosScanMode.barcode.aimHint)
                        .font(.app(11)).foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Color.black.opacity(0.4)).clipShape(Capsule())
                }
                .padding(10)
            } else {
                VStack(spacing: 12) {
                    Text(controller.status.message ?? "Allow camera access to scan straight off the label.")
                        .font(.app(13)).foregroundColor(Color(hex: "#E2E8F0"))
                        .multilineTextAlignment(.center)
                    if controller.status == .denied {
                        Button("Open settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.app(13, .semibold)).foregroundColor(.white)
                        .padding(.horizontal, 18).frame(height: 42)
                        .background(Brand.blue).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#0F172A"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func submit(_ raw: String) {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        controller.stop()
        onCode(code)
        dismiss()
    }
}
