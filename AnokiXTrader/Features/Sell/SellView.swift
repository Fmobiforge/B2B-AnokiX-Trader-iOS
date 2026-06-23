import SwiftUI

struct SellView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var cart: Cart
    @State private var selectedCategory = "All Products"
    @State private var showCheckout = false
    @State private var toastMsg: String?

    private let grid = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var products: [ProductItem] {
        selectedCategory == "All Products"
            ? MockData.posProducts
            : MockData.posProducts.filter { $0.category == selectedCategory }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Sell / POS", subtitle: "Process a customer sale")

            // search + scan
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(Brand.textSecondary)
                    Text("Search products by name, barcode or SKU...")
                        .font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 12).frame(height: 44)
                .background(Brand.surfaceVariant)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Button { toastMsg = "Barcode scanner coming soon." } label: {
                    Label("Scan", systemImage: "barcode.viewfinder")
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                        .padding(.horizontal, 14).frame(height: 44)
                        .background(Brand.purple).clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Brand.surface)

            // category chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MockData.posCategories, id: \.self) { c in
                        FilterChip(label: c, selected: c == selectedCategory) { selectedCategory = c }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .background(Brand.surface)

            // product grid
            ScrollView {
                LazyVGrid(columns: grid, spacing: 12) {
                    ForEach(products) { p in
                        ProductCard(product: p) {
                            cart.add(id: p.id, name: p.name, unitPrice: p.priceValue)
                            toastMsg = "Added \(p.name)"
                        }
                    }
                }
                .padding(12)
            }
            .background(Brand.background)

            // cart bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Cart").font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                        if cart.itemCount > 0 {
                            Text("\(cart.itemCount)")
                                .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Brand.purple).clipShape(Capsule())
                        }
                    }
                    Text(Money.rand(cart.subtotal)).font(.system(size: 20, weight: .bold)).foregroundColor(Brand.textPrimary)
                }
                Spacer()
                Button("Checkout") {
                    if cart.isEmpty { toastMsg = "Your cart is empty." } else { showCheckout = true }
                }
                .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                .padding(.horizontal, 28).padding(.vertical, 14)
                .background(Brand.purple).clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(12)
            .background(Brand.surface.shadow(.drop(color: .black.opacity(0.08), radius: 8, y: -2)))
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showCheckout) { CheckoutView() }
        .toast($toastMsg)
    }
}

struct ProductCard: View {
    let product: ProductItem
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Color(hex: product.colorHex).opacity(0.18)
                    Text(String(product.name.prefix(1)))
                        .font(.system(size: 26, weight: .bold)).foregroundColor(Color(hex: product.colorHex))
                }
                .frame(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                if let badge = product.badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Brand.purple).clipShape(Capsule())
                        .padding(6)
                }
            }
            Text(product.name).font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary).lineLimit(1)
            Text(product.sku).font(.system(size: 11)).foregroundColor(Brand.textSecondary)
            HStack {
                Text(product.price).font(.system(size: 15, weight: .bold)).foregroundColor(Brand.textPrimary)
                Spacer()
                Text(product.stockStatus)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(product.isOutOfStock ? Brand.danger : Brand.success)
            }
            Button(action: onAdd) {
                Text(product.isOutOfStock ? "Out of Stock" : "Add")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(product.isOutOfStock ? Brand.textTertiary : .white)
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background(product.isOutOfStock ? Brand.border : Brand.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
            }
            .disabled(product.isOutOfStock)
        }
        .card(padding: 10)
    }
}
