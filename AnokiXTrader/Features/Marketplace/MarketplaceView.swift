import SwiftUI

struct MarketplaceView: View {
    @StateObject private var orderCart = Cart()
    @State private var category = "All"
    @State private var toastMsg: String?
    @State private var showOrder = false

    private let grid = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var products: [ProductItem] {
        category == "All" ? MockData.marketplaceProducts
            : MockData.marketplaceProducts.filter { $0.category == category }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // hero
                VStack(alignment: .leading, spacing: 6) {
                    Text("Mega Deals").font(.system(size: 12, weight: .bold)).foregroundColor(.white.opacity(0.9))
                    Text("Stock up & Save Big!").font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                    Text("UP TO 15% OFF").font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                }
                .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [Brand.purple, Brand.warning], startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 18))

                // categories
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MockData.marketCategories, id: \.self) { c in
                            FilterChip(label: c, selected: c == category) { category = c }
                        }
                    }
                }

                // top distributors
                Text("Top Distributors").font(.system(size: 17, weight: .bold))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(MockData.distributors) { d in
                            VStack(spacing: 8) {
                                InitialBadge(text: String(d.name.prefix(2)).uppercased(), color: Color(hex: d.colorHex), size: 54)
                                Text(d.name).font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.textPrimary)
                                HStack(spacing: 3) {
                                    Image(systemName: "star.fill").font(.system(size: 9)).foregroundColor(.orange)
                                    Text(d.rating).font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                                }
                                Text("\(d.products) products").font(.system(size: 10)).foregroundColor(Brand.textTertiary)
                            }
                            .frame(width: 110).padding(.vertical, 12).card(padding: 6)
                        }
                    }
                }

                // promotions
                Text("Exclusive Promotions").font(.system(size: 17, weight: .bold))
                VStack(spacing: 12) {
                    ForEach(MockData.marketPromos) { p in MarketPromoCard(promo: p) }
                }

                // bestsellers
                Text("Bestsellers").font(.system(size: 17, weight: .bold))
                LazyVGrid(columns: grid, spacing: 12) {
                    ForEach(products) { p in
                        MarketProductCard(product: p) {
                            orderCart.add(id: p.id, name: p.name, unitPrice: p.priceValue)
                            toastMsg = "Added \(p.name) to order"
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Brand.background)
        .safeAreaInset(edge: .bottom) {
            if !orderCart.isEmpty {
                Button { showOrder = true } label: {
                    HStack {
                        Text("\(orderCart.itemCount) items").foregroundColor(.white).font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Text("Review Order · \(Money.rand(orderCart.subtotal))").foregroundColor(.white).font(.system(size: 14, weight: .bold))
                    }
                    .padding(16).background(Brand.purple)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14)).padding(.horizontal, 16).padding(.bottom, 8)
            }
        }
        .navigationDestination(isPresented: $showOrder) {
            CheckoutView().environmentObject(orderCart)
        }
        .toast($toastMsg)
    }
}

struct MarketPromoCard: View {
    let promo: MarketPromo
    private var tint: Color {
        switch promo.tone { case "green": return Brand.success; case "orange": return Brand.warning; default: return Brand.purple }
    }
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "tag.fill").foregroundColor(tint)
                .frame(width: 44, height: 44).background(tint.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(promo.offer).font(.system(size: 14, weight: .bold)).foregroundColor(tint)
                Text(promo.detail).font(.system(size: 12)).foregroundColor(Brand.textPrimary)
                Text(promo.expires).font(.system(size: 11)).foregroundColor(Brand.textTertiary)
            }
            Spacer()
        }
        .card()
    }
}

struct MarketProductCard: View {
    let product: ProductItem
    let onAdd: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Color(hex: product.colorHex).opacity(0.18)
                    Text(String(product.name.prefix(1))).font(.system(size: 24, weight: .bold)).foregroundColor(Color(hex: product.colorHex))
                }
                .frame(height: 72).clipShape(RoundedRectangle(cornerRadius: 12))
                if let b = product.badge {
                    Text(b).font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3).background(Brand.purple).clipShape(Capsule()).padding(6)
                }
            }
            Text(product.name).font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary).lineLimit(1)
            Text(product.pack).font(.system(size: 11)).foregroundColor(Brand.textSecondary)
            Text(product.stockStatus).font(.system(size: 10)).foregroundColor(Brand.textTertiary)
            HStack {
                Text(product.price).font(.system(size: 15, weight: .bold)).foregroundColor(Brand.textPrimary)
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                        .frame(width: 30, height: 30).background(Brand.purple).clipShape(Circle())
                }
            }
        }
        .card(padding: 10)
    }
}
