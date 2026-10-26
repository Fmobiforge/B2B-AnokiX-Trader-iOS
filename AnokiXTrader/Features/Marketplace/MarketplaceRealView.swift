import SwiftUI

/// Trader Marketplace wired to GET /api/trader/marketplace — laid out after the Trader
/// Portal's /marketplace page as one mobile column, and kept in step with the Android
/// `MarketplaceActivity`:
///
/// distributor card (tap for details, "Change" to switch) → Airtime / Electricity / POS
/// shortcuts → campaign banners → search + scan (results inline) → categories →
/// recommended → best deals → exclusive deals → promotions → news → stories → top
/// suppliers → best sellers → my distributors → recent orders → feature strip.
///
/// Campaign opens and campaign-driven product views are reported to the analytics
/// endpoints exactly as the portal does (`MarketStore.trackCampaignOpen / trackProductView`).
struct MarketplaceRealView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var store: MarketStore
    @EnvironmentObject var session: Session

    @StateObject private var distributorsStore = DistributorsStore()
    @State private var search = ""
    /// A scanned code already being looked up — the debounced search skips it.
    @State private var scannedCode: String?
    @State private var activeSheet: ActiveSheet?
    @State private var bannerIndex = 0
    @State private var toastMsg: String?
    @State private var destination: MarketDestination?
    @FocusState private var searchFocused: Bool

    /// Full-screen destinations opened over the marketplace: the category chooser, a
    /// category, a "View All" collection, all promotions, or the story viewer.
    private enum MarketDestination: Identifiable {
        case allCategories
        case category(ProductCategoryDTO)
        case collection(type: String, title: String)
        case promotions
        case stories(start: Int)
        var id: String {
            switch self {
            case .allCategories: return "all-categories"
            case .category(let c): return "category-\(c.id)"
            case .collection(let type, _): return "collection-\(type)"
            case .promotions: return "promotions"
            case .stories(let start): return "stories-\(start)"
            }
        }
    }

    /// One sheet at a time — multiple `.sheet` modifiers on a single view are unreliable.
    private enum ActiveSheet: Identifiable {
        case product(ProductDTO)
        case cart
        case distributors
        case campaign(CampaignDTO)
        case distributorDetail(TraderDistributorDTO)
        case order(Int)
        case scan
        var id: String {
            switch self {
            case .product(let p): return "product-\(p.id)"
            case .cart: return "cart"
            case .distributors: return "distributors"
            case .campaign(let c): return "campaign-\(c.id)"
            case .distributorDetail(let d): return "distributor-\(d.id)"
            case .order(let id): return "order-\(id)"
            case .scan: return "scan"
            }
        }
    }

    private let bannerTimer = Timer.publish(every: 8.0, on: .main, in: .common).autoconnect()
    private let twoColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    private let threeColumns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8)]

    private var selectedName: String { store.data?.selected_distributor?.displayName ?? "" }
    private var isSearching: Bool { !store.activeSearch.isEmpty || store.searching }

    var body: some View {
        VStack(spacing: 0) {
            marketplaceHeader
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Group {
                        VStack(spacing: 10) {
                            distributorCard
                            servicesRow
                        }
                        bannerSlider
                        searchRow
                        if isSearching { searchResults } else { categoriesSection }
                    }
                    Group {
                        productSection(title: "Recommended for You", subtitle: "Based on your previous orders",
                                       products: store.data?.recommended, collectionType: "recommended")
                        dealsSection(title: "Best Deals", products: store.data?.best_deal_products,
                                     collectionType: "best_deals", onlyFrom: nil)
                        dealsSection(title: "Exclusive Deals", products: store.data?.exclusive_deal_products,
                                     collectionType: "exclusive_deals", onlyFrom: selectedName)
                        promotionsSection
                        newsSection
                        storiesSection
                    }
                    Group {
                        suppliersSection
                        sellersSection
                        myDistributorsSection
                        recentOrdersSection
                        featureStrip
                    }
                }
                .padding(16)
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                await store.load(distributorId: store.selectedDistributorId)
                await store.refreshCart()
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
        // Debounced live search; a scanned code is looked up directly instead.
        .task(id: search) {
            let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
            if query.isEmpty { store.clearSearch(); return }
            if query == scannedCode { return }
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await store.search(query)
        }
        .sheet(item: $activeSheet) { sheet in
            sheetContent(sheet)
        }
        .toast($toastMsg)
        .fullScreenCover(item: $destination) { dest in
            switch dest {
            case .stories(let start):
                StoryViewerView(stories: store.extras.stories, start: start) { shown in
                    store.trackCampaignOpen(shown.id)
                }
            default:
                NavigationStack {
                    switch dest {
                    case .allCategories: AllCategoriesView(store: store)
                    case .category(let c): CategoryProductsView(category: c, store: store)
                    case .collection(let type, let title): CollectionView(type: type, title: title, store: store)
                    case .promotions: PromotionsView(store: store)
                    case .stories: EmptyView()
                    }
                }
            }
        }
        .onDisappear { store.clearSearch() }
        // White portal header → dark status-bar icons. Keep scroll content in light mode;
        // closing the screen restores the tab bar default.
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .product(let p):
            ProductDetailView(productId: p.id, fallback: p, distributorName: selectedName,
                              currency: store.currency, store: store)
        case .cart:
            CartView(store: store)
        case .distributors:
            distributorPicker
        case .campaign(let c):
            CampaignSheetView(campaign: c, currency: store.currency) { product in
                store.trackProductView(product.productId, campaignId: c.id)
                activeSheet = .product(product.asProduct)
            }
        case .distributorDetail(let d):
            NavigationStack {
                DistributorDetailView(distributor: d, store: distributorsStore) { toastMsg = $0 }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { activeSheet = nil }
                        }
                    }
            }
            .preferredColorScheme(.light)
        case .order(let id):
            NavigationStack {
                OrderDetailLoader(orderId: id)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { activeSheet = nil }
                        }
                    }
            }
            .environmentObject(router)
            .environmentObject(session)
            .preferredColorScheme(.light)
        case .scan:
            MarketScanView { code in lookUpScanned(code) }
        }
    }

    // MARK: - Actions

    private func openCampaign(_ campaign: CampaignDTO) {
        store.trackCampaignOpen(campaign.id)
        activeSheet = .campaign(campaign)
    }

    /// Opens a product page, attributing the view to `campaignId` (or the last campaign).
    private func openProduct(_ p: ProductDTO, campaignId: Int? = nil) {
        store.trackProductView(p.id, campaignId: campaignId)
        activeSheet = .product(p)
    }

    private func openDistributorDetail(id: Int?) {
        guard let id else { return }
        let key = String(id)
        let detail = store.extras.myDistributors.first { $0.id == key }
            ?? (store.extras.selectedDistributor?.id == key ? store.extras.selectedDistributor : nil)
        if let detail { activeSheet = .distributorDetail(detail) }
    }

    /// A scanned barcode / SKU goes through the marketplace search; a single hit opens.
    private func lookUpScanned(_ code: String) {
        scannedCode = code
        search = code
        Task {
            let results = await store.search(code)
            if results.count == 1, let only = results.first {
                // Let the scan sheet finish dismissing before presenting the product.
                try? await Task.sleep(nanoseconds: 450_000_000)
                openProduct(only)
            }
        }
    }

    // MARK: - Header

    private var marketplaceHeader: some View {
        HStack(spacing: 4) {
            Button { router.presented = nil } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Brand.textPrimary)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)

            Text("Marketplace")
                .font(.app(18, .semibold))
                .foregroundColor(Brand.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            marketplaceCartButton
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .frame(minHeight: 44)
        // Portal page header: white bar with a hairline bottom border.
        .background(Brand.surface.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Brand.border.frame(height: 1) }
    }

    private var marketplaceCartButton: some View {
        Button { activeSheet = .cart } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "cart")
                    .font(.system(size: 22))
                    .foregroundColor(Brand.textPrimary)
                    .frame(width: 24, height: 24)
                if store.cartBadgeCount > 0 {
                    Text(store.cartBadgeCount > 99 ? "99+" : "\(store.cartBadgeCount)")
                        .font(.app(10, .bold))
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

    // MARK: - Distributor card + services

    private var distributorCard: some View {
        let dist = store.data?.selected_distributor
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                DistributorAvatar(logoUrl: dist?.logo_url,
                                  initial: String((dist?.displayName ?? "D").prefix(1)), size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Preferred Distributor").font(.app(11)).foregroundColor(Brand.textSecondary)
                    Text(dist?.displayName ?? "—")
                        .font(.app(16, .bold)).foregroundColor(Brand.textPrimary).lineLimit(1)
                }
                Spacer(minLength: 8)
                Button { activeSheet = .distributors } label: {
                    Text("Change").font(.app(12, .semibold)).foregroundColor(Brand.blue)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Brand.blue, lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Divider()
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "mappin.and.ellipse").font(.system(size: 14)).foregroundColor(Brand.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Delivery Area").font(.app(11)).foregroundColor(Brand.textSecondary)
                    Text(dist?.address ?? "—").font(.app(13, .semibold)).foregroundColor(Brand.textPrimary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
        }
        .card(padding: 14)
        .contentShape(Rectangle())
        .onTapGesture { openDistributorDetail(id: dist?.id) }
    }

    private var servicesRow: some View {
        LazyVGrid(columns: threeColumns, spacing: 8) {
            MarketServiceTile(icon: "iphone", tint: Brand.indigo,
                              title: "Airtime & Data", subtitle: "Top up now") {
                router.presented = .airtime
            }
            MarketServiceTile(icon: "bolt.fill", tint: Brand.warningStrong,
                              title: "Electricity", subtitle: "Buy prepaid") {
                router.presented = .airtime
            }
            MarketServiceTile(icon: "creditcard", tint: Brand.blue,
                              title: "POS & Devices", subtitle: "Manage devices") {
                router.presented = nil
                router.tab = .sell
            }
        }
    }

    private var distributorPicker: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Text("Select a distributor to browse products and promotions from their catalogue.")
                        .font(.app(13)).foregroundColor(Brand.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(store.data?.my_distributors ?? []) { d in
                        Button { store.selectDistributor(d.id); activeSheet = nil } label: {
                            HStack(spacing: 12) {
                                DistributorAvatar(logoUrl: d.logo_url,
                                                  initial: String(d.displayName.prefix(1)), size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(d.displayName).font(.app(14, .bold))
                                        .foregroundColor(Brand.textPrimary)
                                    Text(d.address ?? "").font(.app(12)).foregroundColor(Brand.textSecondary)
                                        .lineLimit(2).multilineTextAlignment(.leading)
                                    if String(d.id) == store.selectedDistributorId {
                                        Text("Current distributor").font(.app(11, .semibold))
                                            .foregroundColor(Brand.indigo)
                                    }
                                }
                                Spacer()
                                if String(d.id) == store.selectedDistributorId {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(Brand.indigo)
                                }
                            }
                            .padding(14)
                            .background(String(d.id) == store.selectedDistributorId ? Brand.indigo.opacity(0.06) : Brand.surface)
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(String(d.id) == store.selectedDistributorId ? Brand.indigo : Brand.border, lineWidth: 1))
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
        .preferredColorScheme(.light)
    }

    // MARK: - Banner slider

    /// Custom carousel (a page-style `TabView` inside a vertical `ScrollView` renders
    /// corrupted): one fixed-height slide at a time, auto-advancing, with tappable dots
    /// in their own row below.
    @ViewBuilder
    private var bannerSlider: some View {
        if let banners = store.data?.banners, !banners.isEmpty {
            let safeIndex = max(0, min(bannerIndex, banners.count - 1))
            let banner = banners[safeIndex]
            let campaign = store.extras.banners.first { $0.sourceId == banner.id }
                ?? store.extras.campaign(id: banner.id)
            VStack(spacing: 10) {
                CampaignBannerCard(banner: banner, campaign: campaign) {
                    if let campaign { openCampaign(campaign) }
                }
                .id(banner.id)

                if banners.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<banners.count, id: \.self) { i in
                            Capsule()
                                .fill(i == safeIndex ? Brand.indigo : Brand.border)
                                .frame(width: i == safeIndex ? 20 : 7, height: 7)
                                .onTapGesture { withAnimation(.easeInOut) { bannerIndex = i } }
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

    // MARK: - Search

    private var searchRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(Brand.textSecondary)
                TextField("Search products, brands, categories…", text: $search)
                    .font(.app(14))
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .onSubmit {
                        let q = search
                        Task { await store.search(q) }
                    }
                if !search.isEmpty {
                    Button { clearSearch() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(Brand.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12).frame(height: 46)
            .background(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button { activeSheet = .scan } label: {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 19, weight: .medium)).foregroundColor(Brand.indigo)
                    .frame(width: 46, height: 46)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.indigo, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Scan a product barcode")
        }
    }

    private func clearSearch() {
        scannedCode = nil
        search = ""
        store.clearSearch()
        searchFocused = false
    }

    /// "N results for “q”" with a Clear action — takes the place of Categories (portal).
    @ViewBuilder
    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 12) {
            MarketSectionHeader(title: store.searching ? "Searching…" : resultsTitle,
                                actionTitle: "Clear", onAction: { clearSearch() })
            if store.searching && store.searchResults.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12)
            } else if let error = store.searchError {
                Text(error).font(.app(13)).foregroundColor(Brand.textSecondary)
            } else if store.searchResults.isEmpty {
                Text("No products match “\(store.activeSearch)”.")
                    .font(.app(13)).foregroundColor(Brand.textSecondary)
            } else {
                LazyVGrid(columns: twoColumns, spacing: 10) {
                    ForEach(store.searchResults) { p in
                        CategoryProductCard(product: p, currency: store.currency) { openProduct(p) }
                    }
                }
            }
        }
    }

    private var resultsTitle: String {
        let n = store.searchTotal
        return "\(n) \(n == 1 ? "result" : "results") for “\(store.activeSearch)”"
    }

    // MARK: - Categories

    @ViewBuilder
    private var categoriesSection: some View {
        if !store.parentCategories.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                MarketSectionHeader(title: "Categories") { destination = .allCategories }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(store.parentCategories) { c in
                            Button { destination = .category(c) } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: CategoryIcon.symbol(for: c))
                                        .font(.system(size: 18)).foregroundColor(Brand.textSecondary)
                                        .frame(width: 52, height: 52)
                                        .background(Circle().fill(Brand.surface))
                                        .overlay(Circle().stroke(Brand.border, lineWidth: 1))
                                    Text(c.title).font(.app(10)).foregroundColor(Brand.textSecondary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .frame(width: 72, alignment: .top)
                                }
                                .frame(width: 72, alignment: .top)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
    }

    // MARK: - Product rows

    @ViewBuilder
    private func productSection(title: String, subtitle: String?, products: [ProductDTO]?,
                                collectionType: String) -> some View {
        if let products, !products.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                MarketSectionHeader(title: title, subtitle: subtitle) {
                    destination = .collection(type: collectionType, title: title)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(products) { p in
                            MarketCard(product: p, currency: store.currency) { openProduct(p) }
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
    }

    /// Best / Exclusive Deals. Each product sits on a campaign, so a tap records the
    /// campaign open before the product view (portal behaviour).
    @ViewBuilder
    private func dealsSection(title: String, products: [ProductDTO]?, collectionType: String,
                              onlyFrom: String?) -> some View {
        if let products, !products.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                MarketSectionHeader(title: title) {
                    destination = .collection(type: collectionType, title: title)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(products) { p in
                            DealCard(product: p, currency: store.currency, onlyFrom: onlyFrom) {
                                let cid = store.extras.dealCampaignIds[p.id]
                                if let cid { store.trackCampaignOpen(cid) }
                                openProduct(p, campaignId: cid)
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
    }

    // MARK: - Promotions / news / stories

    @ViewBuilder
    private var promotionsSection: some View {
        if let promos = store.data?.promotions, !promos.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                MarketSectionHeader(title: "Promotions") { destination = .promotions }
                ForEach(promos) { promo in
                    PromotionCard(promo: promo) {
                        if let c = store.extras.campaign(id: promo.id) { openCampaign(c) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var newsSection: some View {
        if !store.extras.posts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                MarketSectionHeader(title: selectedName.isEmpty ? "News" : "News from \(selectedName)")
                MarketListCard(items: store.extras.posts) { post in
                    NewsRow(post: post) { openCampaign(post) }
                }
            }
        }
    }

    @ViewBuilder
    private var storiesSection: some View {
        if !store.extras.stories.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                MarketSectionHeader(title: "Stories")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(store.extras.stories.enumerated()), id: \.element.id) { i, story in
                            StoryBubble(story: story) { destination = .stories(start: i) }
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
    }

    // MARK: - Suppliers / sellers / distributors / orders

    @ViewBuilder
    private var suppliersSection: some View {
        if !store.extras.topSuppliers.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                MarketSectionHeader(title: "Top Suppliers")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.extras.topSuppliers) { SupplierChip(supplier: $0) }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
    }

    @ViewBuilder
    private var sellersSection: some View {
        if !store.extras.topSellers.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                MarketSectionHeader(title: "Best Sellers") { router.presented = .distributors }
                MarketListCard(items: store.extras.topSellers) { SellerRow(seller: $0) }
            }
        }
    }

    @ViewBuilder
    private var myDistributorsSection: some View {
        if let mine = store.data?.my_distributors, !mine.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                MarketSectionHeader(title: "My Distributors") { router.presented = .distributors }
                ForEach(mine) { d in
                    let detail = store.extras.myDistributors.first { $0.id == String(d.id) }
                    MyDistributorCard(distributor: d, productsAvailable: detail?.products_available ?? 0) {
                        openDistributorDetail(id: d.id)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recentOrdersSection: some View {
        if !store.extras.recentOrders.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                MarketSectionHeader(title: "Recent Orders") {
                    router.presented = nil
                    router.tab = .orders
                }
                MarketListCard(items: Array(store.extras.recentOrders.prefix(4))) { order in
                    RecentOrderRow(order: order) { activeSheet = .order(order.id) }
                }
            }
        }
    }

    // MARK: - Feature strip

    private var featureStrip: some View {
        let features: [(String, String, String)] = [
            ("dollarsign.circle", "Best Prices", "From trusted suppliers"),
            ("shippingbox", "Fast Delivery", "To your business"),
            ("checkmark.shield", "Secure Payments", "100% safe & trusted"),
            ("gift", "Earn Rewards", "On every purchase")
        ]
        return LazyVGrid(columns: twoColumns, spacing: 10) {
            ForEach(Array(features.enumerated()), id: \.offset) { _, f in
                HStack(spacing: 10) {
                    Image(systemName: f.0).font(.system(size: 15)).foregroundColor(Brand.indigo)
                        .frame(width: 32, height: 32)
                        .background(Brand.indigo.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.1).font(.app(12, .semibold)).foregroundColor(Brand.textPrimary)
                        Text(f.2).font(.app(10)).foregroundColor(Brand.textSecondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .card(padding: 12)
            }
        }
        .padding(.top, 4)
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
            // Decorative layers non-hittable (aspect-fill hit area overflows the frame).
            .overlay(media.allowsHitTesting(false))
            .overlay(
                LinearGradient(colors: [.black.opacity(0.7), .black.opacity(0.12)],
                               startPoint: .leading, endPoint: .trailing)
                    .allowsHitTesting(false)
            )
            .overlay(alignment: .leading) { caption }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .contentShape(Rectangle())
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
            Text(banner.name ?? "").font(.app(19, .bold)).foregroundColor(.white)
                .lineLimit(2)
                .shadow(color: .black.opacity(0.75), radius: 4, x: 0, y: 1)
            Text(banner.description ?? "").font(.app(12)).foregroundColor(.white.opacity(0.95))
                .lineLimit(2)
                .shadow(color: .black.opacity(0.75), radius: 4, x: 0, y: 1)
            HStack(spacing: 8) {
                Button(action: onShop) {
                    Text("Shop Products").font(.app(12, .semibold)).foregroundColor(Brand.purple)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                Button(action: onPromotions) {
                    Text("View Promotions").font(.app(12, .semibold)).foregroundColor(.white)
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
            // Decorative layers must NOT be hittable: the aspect-fill image's hit area
            // overflows the 180pt frame and, being higher in the VStack z-order, would
            // otherwise cover (and swallow taps meant for) the section's "View All" above.
            .overlay(media.allowsHitTesting(false))
            .overlay(
                LinearGradient(colors: [.black.opacity(0.72), .black.opacity(0.12)],
                               startPoint: .leading, endPoint: .trailing)
                    .allowsHitTesting(false)
            )
            .overlay(alignment: .leading) { content }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .contentShape(Rectangle())
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Dark text shadow ("stroke" effect) keeps the title/description legible
            // over any background image.
            Text(promo.name ?? "")
                .font(.app(19, .bold)).foregroundColor(.white)
                .lineLimit(2)
                .shadow(color: .black.opacity(0.75), radius: 4, x: 0, y: 1)
            Text(promo.description ?? "")
                .font(.app(12)).foregroundColor(.white.opacity(0.95))
                .lineLimit(2)
                .shadow(color: .black.opacity(0.75), radius: 4, x: 0, y: 1)
            if let end = promo.end_date, !end.isEmpty {
                Text(end).font(.app(12)).foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.75), radius: 4, x: 0, y: 1)
                    .padding(.top, 2)
            }
            Button(action: onShop) {
                Text("Shop Now").font(.app(12, .semibold)).foregroundColor(Brand.purple)
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
                    Text(product.name ?? "").font(.app(12, .semibold))
                        .foregroundColor(Brand.textPrimary).lineLimit(2)
                        .frame(height: 32, alignment: .top)
                    HStack {
                        Text(CurrencyFmt.format(product.priceValue, symbol: currency))
                            .font(.app(15, .bold)).foregroundColor(Brand.purple)
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
