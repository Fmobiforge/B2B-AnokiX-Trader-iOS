import SwiftUI

/// Marketplace › category detail — iOS counterpart of the Android
/// `CategoryProductsActivity`. Browses and filters one category's products via
/// GET /api/trader/marketplace/category, with a Sort-by menu, a Filters sheet driven
/// by the facet counts, promo banners (same as Marketplace) and a recently-purchased row.
struct CategoryProductsView: View {
    let category: ProductCategoryDTO
    @ObservedObject var market: MarketStore
    @StateObject private var store: CategoryProductsStore
    @Environment(\.dismiss) private var dismiss

    @State private var activeSheet: ActiveSheet?
    @State private var bannerIndex = 0

    private let bannerTimer = Timer.publish(every: 8.0, on: .main, in: .common).autoconnect()
    private let grid = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    init(category: ProductCategoryDTO, store market: MarketStore) {
        self.category = category
        self.market = market
        _store = StateObject(wrappedValue: CategoryProductsStore(categoryId: String(category.id)))
    }

    /// One sheet at a time (multiple `.sheet` modifiers are unreliable).
    private enum ActiveSheet: Identifiable {
        case product(ProductDTO)
        case cart
        case filters
        var id: String {
            switch self {
            case .product(let p): return "product-\(p.id)"
            case .cart: return "cart"
            case .filters: return "filters"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            MarketSubHeader(title: category.title, cartBadge: market.cartBadgeCount,
                            onBack: { dismiss() }, onCart: { activeSheet = .cart })
            titleBar
            content
        }
        .background(Brand.background)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .product(let p):
                ProductDetailView(productId: p.id, fallback: p,
                                  distributorName: "", currency: store.currency, store: market)
            case .cart:
                CartView(store: market)
            case .filters:
                CategoryFilterSheet(
                    filters: store.filters,
                    currency: store.currency,
                    selBrands: store.selBrands,
                    selSubCategories: store.selSubCategories,
                    selPackSizes: store.selPackSizes,
                    onPromotion: store.onPromotion,
                    inStock: store.inStock,
                    minPrice: store.minPrice,
                    maxPrice: store.maxPrice
                ) { applied in
                    store.selBrands = applied.brands
                    store.selSubCategories = applied.subCategories
                    store.selPackSizes = applied.packSizes
                    store.onPromotion = applied.onPromotion
                    store.inStock = applied.inStock
                    store.minPrice = applied.minPrice
                    store.maxPrice = applied.maxPrice
                    Task { await store.load() }
                }
            }
        }
        .task {
            if store.page == nil { await store.load() }
            await market.refreshCart()
        }
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.dark)
    }

    // MARK: - Title bar (count + Filters + Sort)

    private var titleBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(store.totalCount) products found")
                .font(.system(size: 13)).foregroundColor(Brand.textSecondary)
            HStack(spacing: 10) {
                Button { activeSheet = .filters } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Filters").font(.system(size: 13, weight: .semibold))
                        if store.activeFilterCount > 0 {
                            Text("\(store.activeFilterCount)")
                                .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Brand.purple).clipShape(Capsule())
                        }
                    }
                    .foregroundColor(Brand.textPrimary)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Brand.surface)
                    .overlay(Capsule().stroke(Brand.border, lineWidth: 1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Sort by:").font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                Menu {
                    ForEach(store.sortOptions) { opt in
                        Button(opt.label ?? opt.value) {
                            store.sortBy = opt.value
                            Task { await store.load() }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(store.sortLabel)
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Brand.surface)
                    .overlay(Capsule().stroke(Brand.border, lineWidth: 1))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 6)
    }

    // MARK: - Scroll content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                bannerSlider
                productsBlock
                recentlyPurchasedSection
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var productsBlock: some View {
        if store.loading && store.page == nil {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
        } else if store.products.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 30)).foregroundColor(Brand.textTertiary)
                Text("No products found").font(.system(size: 14)).foregroundColor(Brand.textSecondary)
                Text("Try adjusting your filters.").font(.system(size: 12)).foregroundColor(Brand.textTertiary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 40)
        } else {
            LazyVGrid(columns: grid, spacing: 12) {
                ForEach(store.products) { p in
                    CategoryProductCard(product: p, currency: store.currency) {
                        activeSheet = .product(p)
                    }
                }
            }
        }
    }

    // MARK: - Banners (same carousel as Marketplace)

    @ViewBuilder
    private var bannerSlider: some View {
        if !store.banners.isEmpty {
            let banners = store.banners
            let safeIndex = max(0, min(bannerIndex, banners.count - 1))
            VStack(spacing: 12) {
                BannerCard(banner: banners[safeIndex])
                    .id(banners[safeIndex].id)
                if banners.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<banners.count, id: \.self) { i in
                            Capsule()
                                .fill(i == safeIndex ? Brand.purple : Brand.border)
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

    // MARK: - Recently purchased

    @ViewBuilder
    private var recentlyPurchasedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recently Purchased")
                .font(.system(size: 16, weight: .bold)).foregroundColor(Brand.textPrimary)
            if store.recentlyPurchased.isEmpty {
                Text("Products you order will appear here.")
                    .font(.system(size: 13)).foregroundColor(Brand.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.recentlyPurchased) { p in
                            MarketCard(product: p, currency: store.currency) { activeSheet = .product(p) }
                        }
                    }
                }
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Product grid card (full-width, two per row)

struct CategoryProductCard: View {
    let product: ProductDTO
    let currency: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Size-anchor: an aspect-fill image with a flexible width would otherwise
                // blow out the grid cell (first row wider than the rest). Color.clear pins
                // the size; the image is a clipped overlay that can't resize its parent.
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .overlay(RemoteImage(url: product.imageURL).allowsHitTesting(false))
                    .clipped()
                VStack(alignment: .leading, spacing: 6) {
                    Text(product.name ?? "")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.textPrimary)
                        .lineLimit(2).frame(height: 32, alignment: .top)
                    HStack {
                        Text(CurrencyFmt.format(product.priceValue, symbol: currency))
                            .font(.system(size: 15, weight: .bold)).foregroundColor(Brand.purple)
                        Spacer()
                        Image(systemName: "plus").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                            .frame(width: 30, height: 30).background(Brand.purple).clipShape(Circle())
                    }
                    stockLine
                }
                .padding(10)
            }
            .background(Brand.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var stockLine: some View {
        if product.inStock {
            HStack(spacing: 5) {
                Circle().fill(Brand.success).frame(width: 6, height: 6)
                Text("In Stock • \(product.stockCount) in stock")
                    .font(.system(size: 10)).foregroundColor(Brand.textSecondary).lineLimit(1)
            }
        } else {
            Text("Out of Stock").font(.system(size: 10)).foregroundColor(Brand.danger)
        }
    }
}
