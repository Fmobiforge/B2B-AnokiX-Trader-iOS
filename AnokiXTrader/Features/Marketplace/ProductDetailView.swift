import SwiftUI

/// Add to Cart screen (mirrors Add_to_Cart.png). Shows the marketplace product
/// immediately, refreshes from GET /api/common/product-detail, and adds the chosen
/// quantity to the shared local cart on tap.
struct ProductDetailView: View {
    let productId: String
    let fallback: ProductDTO
    let distributorName: String
    let currency: String
    @ObservedObject var store: MarketStore

    @Environment(\.dismiss) private var dismiss
    @State private var product: ProductDTO
    @State private var quantity = 1
    @State private var toastMsg: String?
    @State private var selectedImage: String?

    init(productId: String, fallback: ProductDTO, distributorName: String,
         currency: String, store: MarketStore) {
        self.productId = productId
        self.fallback = fallback
        self.distributorName = distributorName
        self.currency = currency
        self.store = store
        _product = State(initialValue: fallback)
    }

    private var maxQty: Int { max(1, product.stockCount) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        image
                        Text(product.name ?? "").font(.system(size: 22, weight: .bold)).foregroundColor(Brand.textPrimary)
                        if let brand = product.brand_name, !brand.isEmpty {
                            Text("By \(brand)").font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                        }
                        Text(CurrencyFmt.format(product.priceValue, symbol: currency))
                            .font(.system(size: 24, weight: .bold)).foregroundColor(Brand.purple)
                        Text("Incl. VAT").font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                        HStack(spacing: 14) {
                            Label(product.inStock ? "In Stock" : "Out of Stock",
                                  systemImage: "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(product.inStock ? Brand.success : Brand.danger)
                            Label("Next Day Delivery", systemImage: "shippingbox")
                                .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                        }
                    }
                    Group {
                        Divider()
                        infoRow("Distributor", distributorName)
                        infoRow("Category", product.category_title ?? "")
                        infoRow("SKU", product.sku ?? "")
                        infoRow("Barcode", product.barcode ?? "")
                        Divider()
                        HStack(spacing: 12) {
                            stepper
                            Text("(\(product.stockCount) in stock)").font(.system(size: 13))
                                .foregroundColor(Brand.textSecondary)
                            Spacer()
                        }
                        Button { addToCart() } label: {
                            Label("Add to Cart", systemImage: "cart")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        Text("Product Description").font(.system(size: 17, weight: .bold))
                            .foregroundColor(Brand.textPrimary).padding(.top, 8)
                        Text(product.description ?? "").font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Product Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } }
            .task { await refresh() }
            .toast($toastMsg)
        }
        // Presented as a sheet from screens that force .preferredColorScheme(.dark);
        // keep this content in light mode so the fixed Brand colors stay legible.
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder private var image: some View {
        let gallery = product.galleryURLs
        let current = selectedImage.flatMap { gallery.contains($0) ? $0 : nil } ?? gallery.first
        VStack(spacing: 10) {
            RemoteImage(url: current)
                .frame(height: 240).frame(maxWidth: .infinity).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14))
            if gallery.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(gallery, id: \.self) { url in
                            RemoteImage(url: url)
                                .frame(width: 60, height: 60).clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(current == url ? Brand.purple : Brand.border,
                                                lineWidth: current == url ? 2 : 1)
                                )
                                .onTapGesture { selectedImage = url }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var stepper: some View {
        HStack(spacing: 0) {
            Button { if quantity > 1 { quantity -= 1 } } label: {
                Image(systemName: "minus").frame(width: 40, height: 40)
            }
            Text("\(quantity)").font(.system(size: 16, weight: .bold)).frame(width: 44)
            Button { if quantity < maxQty { quantity += 1 } } label: {
                Image(systemName: "plus").frame(width: 40, height: 40)
            }
        }
        .foregroundColor(Brand.textPrimary)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundColor(Brand.textSecondary).frame(width: 110, alignment: .leading)
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary)
            Spacer()
        }
    }

    private func refresh() async {
        if let fresh = try? await APIClient.shared.getProductDetail(id: productId) {
            await MainActor.run { product = fresh }
        }
    }

    private func addToCart() {
        store.addToCart(product, qty: quantity)
        toastMsg = "Added \(product.name ?? "item") to cart"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
    }
}
