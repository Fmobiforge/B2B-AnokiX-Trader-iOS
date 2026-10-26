import SwiftUI

/// The titled, paginated "Current Promotions" list — iOS counterpart of the Android
/// `PromotionsActivity`. Vertical list of overlaid `PromotionCard`s with infinite-scroll
/// pagination. Reuses `MarketSubHeader` and the shared `PromotionCard`.
struct PromotionsView: View {
    @ObservedObject var market: MarketStore
    @StateObject private var store: PromotionsStore
    @Environment(\.dismiss) private var dismiss

    @State private var activeSheet: ActiveSheet?
    @State private var toastMsg: String?

    init(store market: MarketStore) {
        self.market = market
        _store = StateObject(wrappedValue: PromotionsStore())
    }

    /// One sheet at a time: cart, a promotion's campaign sheet, or a product from it.
    private enum ActiveSheet: Identifiable {
        case cart
        case campaign(CampaignDTO)
        case product(ProductDTO)
        var id: String {
            switch self {
            case .cart: return "cart"
            case .campaign(let c): return "campaign-\(c.id)"
            case .product(let p): return "product-\(p.id)"
            }
        }
    }

    /// "Shop Now": record the open and show the campaign's products (portal drawer).
    private func openCampaign(_ promo: PromotionDTO) {
        guard let campaign = market.extras.campaign(id: promo.id) else {
            toastMsg = "Promotion details are unavailable right now."
            return
        }
        market.trackCampaignOpen(campaign.id)
        activeSheet = .campaign(campaign)
    }

    var body: some View {
        VStack(spacing: 0) {
            MarketSubHeader(title: store.title, cartBadge: market.cartBadgeCount,
                            onBack: { dismiss() }, onCart: { activeSheet = .cart })
            Text("\(store.total) promotions")
                .font(.app(13)).foregroundColor(Brand.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)
            content
        }
        .background(Brand.background)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .cart:
                CartView(store: market)
            case .campaign(let c):
                CampaignSheetView(campaign: c, currency: market.currency) { product in
                    market.trackProductView(product.productId, campaignId: c.id)
                    activeSheet = .product(product.asProduct)
                }
            case .product(let p):
                ProductDetailView(productId: p.id, fallback: p, distributorName: "",
                                  currency: market.currency, store: market)
            }
        }
        .task {
            await store.loadFirst()
            await market.refreshCart()
        }
        .toast($toastMsg)
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)   // white portal header → dark status-bar icons
    }

    @ViewBuilder
    private var content: some View {
        if store.loading && store.promotions.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.promotions.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "megaphone")
                    .font(.system(size: 30)).foregroundColor(Brand.textTertiary)
                Text("No promotions").font(.app(14)).foregroundColor(Brand.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(store.promotions) { promo in
                        PromotionCard(promo: promo) { openCampaign(promo) }
                            .onAppear {
                                if promo.id == store.promotions.last?.id { Task { await store.loadMore() } }
                            }
                    }
                    if store.loadingMore {
                        ProgressView().padding(.vertical, 8)
                    }
                }
                .padding(16)
            }
        }
    }
}
