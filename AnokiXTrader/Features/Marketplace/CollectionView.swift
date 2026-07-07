import SwiftUI

/// A titled, paginated product collection (Recommended for You / Best Sellers) —
/// iOS counterpart of the Android `CollectionActivity`. Simple 2-column product grid
/// with infinite-scroll pagination; reuses `CategoryProductCard` and `MarketSubHeader`.
struct CollectionView: View {
    @ObservedObject var market: MarketStore
    @StateObject private var store: CollectionStore
    @Environment(\.dismiss) private var dismiss

    @State private var activeSheet: ActiveSheet?

    private let grid = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    init(type: String, title: String, store market: MarketStore) {
        self.market = market
        _store = StateObject(wrappedValue: CollectionStore(type: type, title: title))
    }

    private enum ActiveSheet: Identifiable {
        case product(ProductDTO)
        case cart
        var id: String {
            switch self {
            case .product(let p): return "product-\(p.id)"
            case .cart: return "cart"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            MarketSubHeader(title: store.title, cartBadge: market.cartBadgeCount,
                            onBack: { dismiss() }, onCart: { activeSheet = .cart })
            Text("\(store.total) products")
                .font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)
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
            }
        }
        .task {
            await store.loadFirst()
            await market.refreshCart()
        }
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        if store.loading && store.products.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.products.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "bag").font(.system(size: 30)).foregroundColor(Brand.textTertiary)
                Text("No products found").font(.system(size: 14)).foregroundColor(Brand.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: grid, spacing: 12) {
                    ForEach(store.products) { p in
                        CategoryProductCard(product: p, currency: store.currency) {
                            activeSheet = .product(p)
                        }
                        .onAppear {
                            if p.id == store.products.last?.id { Task { await store.loadMore() } }
                        }
                    }
                }
                .padding(16)
                if store.loadingMore {
                    ProgressView().padding(.bottom, 16)
                }
            }
        }
    }
}
