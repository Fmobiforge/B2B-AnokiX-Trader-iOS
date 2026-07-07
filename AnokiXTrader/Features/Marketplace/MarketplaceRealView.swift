import SwiftUI

/// Trader Marketplace wired to GET /api/trader/marketplace — the iOS counterpart
/// of the Android `MarketplaceActivity`. Uses a custom purple header (same as
/// `activity_marketplace.xml`) so the cart badge is not affected by nav-bar tinting.
struct MarketplaceRealView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var store: MarketStore

    @State private var search = ""
    @State private var activeSheet: ActiveSheet?
    @State private var bannerIndex = 0
    @State private var toastMsg: String?
    @State private var destination: MarketDestination?

    /// Full-screen destinations opened over the marketplace (each in its own
    /// NavigationStack): the "View All" category chooser, a tapped category, or a
    /// "View All" product collection (Recommended / Best Sellers).
    private enum MarketDestination: Identifiable {
        case allCategories
        case category(ProductCategoryDTO)
        case collection(type: String, title: String)
        case promotions
        var id: String {
            switch self {
            case .allCategories: return "all-categories"
            case .category(let c): return "category-\(c.id)"
            case .collection(let type, _): return "collection-\(type)"
            case .promotions: return "promotions"
            }
        }
    }

    /// One sheet at a time — multiple `.sheet` modifiers on a single view are
    /// unreliable, so all three presentations share this enum.
    private enum ActiveSheet: Identifiable {
        case product(ProductDTO)
        case cart
        case distributors
        var id: String {
            switch self {
            case .product(let p): return "product-\(p.id)"
            case .cart: return "cart"
            case .distributors: return "distributors"
            }
        }
    }

    private let bannerTimer = Timer.publish(every: 8.0, on: .main, in: .common).autoconnect()
    private let summaryGrid = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            marketplaceHeader
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Group {
                            distributorCard
                            bannerSlider
                            insightsSection
                            searchRow
                            menuSection(proxy)
                        }
                        Group {
                            categoriesSection
                            opportunitiesCard
                            productSection(title: "Recommended for You", subtitle: "Based on your previous orders",
                                           products: store.data?.recommended, collectionType: "recommended")
                            promotionsSection.id("promotions")
                            productSection(title: "Best Sellers", subtitle: nil,
                                           products: store.data?.best_sellers, collectionType: "best_sellers")
                            featureStrip
                        }
                    }
                    .padding(16)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Brand.background)
        .overlay { if store.loading && store.data == nil { ProgressView() } }
        .task {
            if store.data == nil { await store.loadAll() }
            await store.refreshCart()
        }
        .onAppear {
            Task { await store.refreshCart() }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .product(let p):
                ProductDetailView(productId: p.id, fallback: p,
                                  distributorName: store.data?.selected_distributor?.displayName ?? "",
                                  currency: store.currency, store: store)
            case .cart:
                CartView(store: store)
            case .distributors:
                distributorPicker
            }
        }
        .toast($toastMsg)
        .fullScreenCover(item: $destination) { dest in
            NavigationStack {
                switch dest {
                case .allCategories: AllCategoriesView(store: store)
                case .category(let c): CategoryProductsView(category: c, store: store)
                case .collection(let type, let title): CollectionView(type: type, title: title, store: store)
                case .promotions: PromotionsView(store: store)
                }
            }
        }
        // White status-bar icons over the purple header (same trick as Login / Register).
        // Keep scroll content in light mode; closing the screen restores the tab bar default.
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header (Android activity_marketplace.xml)

    private var marketplaceHeader: some View {
        HStack(spacing: 4) {
            Button { router.presented = nil } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)

            Text("Marketplace")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            marketplaceCartButton
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .frame(minHeight: 44)
        .background(
            LinearGradient(colors: [Brand.purpleDark, Brand.purple],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea(edges: .top)
        )
    }

    private var marketplaceCartButton: some View {
        Button { activeSheet = .cart } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "cart")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                if store.cartBadgeCount > 0 {
                    Text(store.cartBadgeCount > 99 ? "99+" : "\(store.cartBadgeCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Brand.danger)
                        .clipShape(Capsule())
                        .offset(x: 6, y: -6)
                }
            }
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Distributor card

    private var distributorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                DistributorAvatar(logoUrl: store.data?.selected_distributor?.logo_url,
                                  initial: String((store.data?.selected_distributor?.displayName ?? "D").prefix(1)),
                                  size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Preferred Distributor").font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                    Text(store.data?.selected_distributor?.displayName ?? "—")
                        .font(.system(size: 14, weight: .bold)).foregroundColor(Brand.textPrimary).lineLimit(1)
                    Button("Change Distributor") { activeSheet = .distributors }
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.purple)
                }
                Spacer()
            }
            Divider()
            HStack(spacing: 8) {
                miniStat("Delivery Area", store.data?.selected_distributor?.address ?? "—")
                miniStat("Wallet Balance", "R2,800.00")
                miniStat("Available Credit", "R10,000.00")
            }
        }
        .card()
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10)).foregroundColor(Brand.textSecondary)
            Text(value).font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.textPrimary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var distributorPicker: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(store.data?.my_distributors ?? []) { d in
                        Button { store.selectDistributor(d.id); activeSheet = nil } label: {
                            HStack(spacing: 12) {
                                DistributorAvatar(logoUrl: d.logo_url,
                                                  initial: String(d.displayName.prefix(1)), size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(d.displayName).font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Brand.textPrimary)
                                    Text(d.address ?? "").font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                                        .lineLimit(2).multilineTextAlignment(.leading)
                                    if String(d.id) == store.selectedDistributorId {
                                        Text("Current distributor").font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(Brand.purple)
                                    }
                                }
                                Spacer()
                                if String(d.id) == store.selectedDistributorId {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(Brand.purple)
                                }
                            }
                            .padding(14)
                            .background(String(d.id) == store.selectedDistributorId ? Brand.purpleLight : Brand.surface)
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(String(d.id) == store.selectedDistributorId ? Brand.purple : Brand.border, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Change Distributor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { activeSheet = nil } } }
        }
        // The marketplace forces .preferredColorScheme(.dark); this picker sheet inherits
        // that dark style, so force it back to light.
        .preferredColorScheme(.light)
    }

    // MARK: - Banner slider

    /// Custom carousel. A page-style `TabView` inside a vertical `ScrollView`
    /// renders corrupted and overlaps neighbouring content, so we show one
    /// fixed-height `BannerCard` at a time (Kingfisher cross-fades the image as the
    /// URL changes), auto-advance on the timer, and put tappable page dots in their
    /// own row *below* the banner (never overlapping).
    @ViewBuilder
    private var bannerSlider: some View {
        if let banners = store.data?.banners, !banners.isEmpty {
            let safeIndex = max(0, min(bannerIndex, banners.count - 1))
            VStack(spacing: 12) {
                BannerCard(banner: banners[safeIndex],
                           onShop: { toastMsg = "Coming soon" },
                           onPromotions: { destination = .promotions })
                    .id(banners[safeIndex].id)

                if banners.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<banners.count, id: \.self) { i in
                            Capsule()
                                .fill(i == safeIndex ? Brand.purple : Brand.border)
                                .frame(width: i == safeIndex ? 20 : 7, height: 7)
                                .onTapGesture {
                                    withAnimation(.easeInOut) { bannerIndex = i }
                                }
                        }
                    }
                    .animation(.easeInOut, value: safeIndex)
                }
            }
            .onReceive(bannerTimer) { _ in
                guard banners.count > 1 else { return }
                withAnimation(.easeInOut) { bannerIndex = (safeIndex + 1) % banners.count }
            }
        }
    }

    // MARK: - Insights

    @ViewBuilder
    private var insightsSection: some View {
        if let cards = store.data?.business_insights?.summary_cards, !cards.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Business Insights").font(.system(size: 17, weight: .bold)).foregroundColor(Brand.textPrimary)
                LazyVGrid(columns: summaryGrid, spacing: 10) {
                    ForEach(cards) { card in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(card.label ?? "").font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                            Text(card.formatted_value ?? "").font(.system(size: 18, weight: .bold))
                                .foregroundColor(Brand.textPrimary)
                            if let sub = card.subtitle {
                                Text(sub).font(.system(size: 10))
                                    .foregroundColor(card.trendUp ? Brand.success : Brand.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(padding: 12)
                    }
                }
            }
        }
    }

    // MARK: - Search

    private var searchRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(Brand.textSecondary)
                TextField("Search products, brands, categories…", text: $search)
                    .font(.system(size: 14))
            }
            .padding(.horizontal, 12).padding(.vertical, 11)
            .background(Brand.surfaceVariant)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button { toastMsg = "Barcode scanner coming soon." } label: {
                HStack(spacing: 6) {
                    Image(systemName: "barcode.viewfinder"); Text("Scan").font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white).padding(.horizontal, 14).padding(.vertical, 11)
                .background(Brand.purple).clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Menu buttons

    private let menuItems: [(icon: String, label: String)] = [
        ("list.bullet.rectangle", "My Orders"), ("wallet.pass", "Wallet"), ("creditcard", "Credit"),
        ("shippingbox", "Deliveries"), ("percent", "Promotions"), ("simcard", "VAS Services"),
        ("chart.bar", "Analytics"), ("ellipsis", "More")
    ]

    private func menuSection(_ proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(Array(menuItems.enumerated()), id: \.offset) { idx, item in
                    Button { onMenu(idx, proxy) } label: {
                        VStack(spacing: 6) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: item.icon).font(.system(size: 20)).foregroundColor(Brand.purple)
                                    .frame(width: 48, height: 48).background(Brand.purpleLight)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                if idx == 4 {
                                    Text("NEW").font(.system(size: 7, weight: .bold)).foregroundColor(.white)
                                        .padding(.horizontal, 4).padding(.vertical, 1)
                                        .background(Brand.danger).clipShape(Capsule()).offset(x: 6, y: -4)
                                }
                            }
                            Text(item.label).font(.system(size: 10)).foregroundColor(Brand.textPrimary)
                                .multilineTextAlignment(.center).frame(width: 64)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            // Top room so the Promotions "NEW" badge (offset above the icon) isn't
            // clipped by the horizontal ScrollView's content bounds.
            .padding(.top, 8)
        }
    }

    private func onMenu(_ idx: Int, _ proxy: ScrollViewProxy) {
        switch idx {
        case 0, 3: router.presented = nil; router.tab = .orders
        case 1: router.presented = nil; router.tab = .wallet
        case 2: toastMsg = "Coming soon"
        case 4: withAnimation { proxy.scrollTo("promotions", anchor: .top) }
        case 5: router.presented = .airtime
        case 6: router.presented = .analytics
        default: toastMsg = "Coming soon"
        }
    }

    // MARK: - Categories

    @ViewBuilder
    private var categoriesSection: some View {
        if !store.parentCategories.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Categories", actionTitle: "View All") { destination = .allCategories }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(store.parentCategories) { c in
                            Button { destination = .category(c) } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: CategoryIcon.symbol(for: c)).font(.system(size: 18)).foregroundColor(Brand.purple)
                                        .frame(width: 48, height: 48).background(Brand.purpleLight)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    Text(c.title).font(.system(size: 10)).foregroundColor(Brand.textPrimary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .frame(width: 64, alignment: .top)
                                }
                                .frame(width: 64, alignment: .top)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Opportunities

    private var opportunitiesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Business Opportunities").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
            Text("Increase your order volume and earn additional profit on every basket.")
                .font(.system(size: 12)).foregroundColor(.white.opacity(0.9))
            Button { toastMsg = "Coming soon" } label: {
                Text("View Opportunity").font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.purple)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top, 4)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Brand.purple, Brand.purpleDark], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Product rows

    @ViewBuilder
    private func productSection(title: String, subtitle: String?, products: [ProductDTO]?,
                               collectionType: String? = nil) -> some View {
        if let products, !products.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.system(size: 17, weight: .bold)).foregroundColor(Brand.textPrimary)
                        if let subtitle { Text(subtitle).font(.system(size: 11)).foregroundColor(Brand.textSecondary) }
                    }
                    Spacer()
                    if let collectionType {
                        Button("View All") { destination = .collection(type: collectionType, title: title) }
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.purple)
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(products) { p in
                            MarketCard(product: p, currency: store.currency) { activeSheet = .product(p) }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Promotions

    @ViewBuilder
    private var promotionsSection: some View {
        if let promos = store.data?.promotions, !promos.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Current Promotions", actionTitle: "View All") { destination = .promotions }
                ForEach(promos) { promo in
                    PromotionCard(promo: promo) { toastMsg = "Coming soon" }
                }
            }
        }
    }

    // MARK: - Feature strip

    private var featureStrip: some View {
        let features: [(String, String, String)] = [
            ("tag", "Best Prices", "From trusted suppliers"),
            ("shippingbox", "Fast Delivery", "To your business"),
            ("lock.shield", "Secure Payments", "Safe & trusted checkout"),
            ("gift", "Earn Rewards", "On every purchase")
        ]
        return LazyVGrid(columns: summaryGrid, spacing: 10) {
            ForEach(Array(features.enumerated()), id: \.offset) { _, f in
                HStack(spacing: 8) {
                    Image(systemName: f.0).foregroundColor(Brand.purple)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.1).font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.textPrimary)
                        Text(f.2).font(.system(size: 10)).foregroundColor(Brand.textSecondary).lineLimit(1)
                    }
                    Spacer()
                }
                .card(padding: 12)
            }
        }
    }
}

// MARK: - Banner card

struct BannerCard: View {
    let banner: BannerDTO
    var onShop: () -> Void = {}
    var onPromotions: () -> Void = {}
    private let bannerHeight: CGFloat = 180

    var body: some View {
        // Color.clear pins the size; media/gradient/caption are overlays that can't
        // grow the frame (an aspect-fill image under a plain .frame overflows and pushes
        // the caption out of view — the documented banner bug).
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: bannerHeight)
            .overlay(media)
            .overlay(
                LinearGradient(colors: [.black.opacity(0.7), .black.opacity(0.12)],
                               startPoint: .leading, endPoint: .trailing)
            )
            .overlay(alignment: .leading) { caption }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 2)
    }

    @ViewBuilder
    private var media: some View {
        Group {
            if banner.isVideo, let url = MediaUrls.url(banner.mediaURL) {
                ZStack {
                    VideoThumbnailView(url: url)
                    LoopingVideoView(url: url)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if let url = MediaUrls.resolve(banner.mediaURL), !url.isEmpty {
                RemoteImage(url: url)
            } else {
                bannerPlaceholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var bannerPlaceholder: some View {
        LinearGradient(colors: [Brand.purple, Brand.purpleDark],
                       startPoint: .leading, endPoint: .trailing)
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(banner.name ?? "").font(.system(size: 19, weight: .bold)).foregroundColor(.white)
                .lineLimit(2)
                .shadow(color: .black.opacity(0.75), radius: 4, x: 0, y: 1)
            Text(banner.description ?? "").font(.system(size: 12)).foregroundColor(.white.opacity(0.95))
                .lineLimit(2)
                .shadow(color: .black.opacity(0.75), radius: 4, x: 0, y: 1)
            HStack(spacing: 8) {
                Button(action: onShop) {
                    Text("Shop Products").font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.purple)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                Button(action: onPromotions) {
                    Text("View Promotions").font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 6)
        }
        .padding(16)
    }
}

// MARK: - Promotion card

struct PromotionCard: View {
    let promo: PromotionDTO
    var onShop: () -> Void = {}

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .overlay(media)
            .overlay(
                LinearGradient(colors: [.black.opacity(0.72), .black.opacity(0.12)],
                               startPoint: .leading, endPoint: .trailing)
            )
            .overlay(alignment: .leading) { content }
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Dark text shadow ("stroke" effect) keeps the title/description legible
            // over any background image.
            Text(promo.name ?? "")
                .font(.system(size: 19, weight: .bold)).foregroundColor(.white)
                .lineLimit(2)
                .shadow(color: .black.opacity(0.75), radius: 4, x: 0, y: 1)
            Text(promo.description ?? "")
                .font(.system(size: 12)).foregroundColor(.white.opacity(0.95))
                .lineLimit(2)
                .shadow(color: .black.opacity(0.75), radius: 4, x: 0, y: 1)
            if let end = promo.end_date, !end.isEmpty {
                Text(end).font(.system(size: 12)).foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.75), radius: 4, x: 0, y: 1)
                    .padding(.top, 2)
            }
            Button(action: onShop) {
                Text("Shop Now").font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.purple)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .padding(16)
    }

    @ViewBuilder
    private var media: some View {
        Group {
            if promo.isVideo, let url = MediaUrls.url(promo.mediaURL) {
                ZStack {
                    VideoThumbnailView(url: url)
                    LoopingVideoView(url: url)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if let url = MediaUrls.resolve(promo.mediaURL), !url.isEmpty {
                RemoteImage(url: url)
            } else {
                LinearGradient(colors: [Brand.purple, Brand.purpleDark],
                               startPoint: .leading, endPoint: .trailing)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

// MARK: - Product card

struct MarketCard: View {
    let product: ProductDTO
    let currency: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                RemoteImage(url: product.imageURL)
                    .frame(width: 150, height: 120).clipped()
                VStack(alignment: .leading, spacing: 6) {
                    Text(product.name ?? "").font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Brand.textPrimary).lineLimit(2)
                        .frame(height: 32, alignment: .top)
                    HStack {
                        Text(CurrencyFmt.format(product.priceValue, symbol: currency))
                            .font(.system(size: 15, weight: .bold)).foregroundColor(Brand.purple)
                        Spacer()
                        Image(systemName: "plus").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                            .frame(width: 30, height: 30).background(Brand.purple).clipShape(Circle())
                    }
                }
                .padding(10)
            }
            .frame(width: 150)
            .background(Brand.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
