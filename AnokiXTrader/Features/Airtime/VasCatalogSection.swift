import SwiftUI

/// Airtime & VAS › Catalog & orders. Flattens the VAS category tree to selectable leaves
/// (horizontal scroll, expandable to a grid), loads that category's products, and mirrors the
/// web portal's "Order summary" — recipient, optional custom amount for ad-hoc products,
/// reference, and a wallet-paid "Sell now".
struct VasCatalogSection: View {
    @ObservedObject var store: VasStore

    private static let productLimit = 60

    @State private var categories: [VasCategoryNode] = []
    @State private var products: [VasProductDTO] = []
    @State private var selectedCategory: VasCategoryNode?
    @State private var selectedProduct: VasProductDTO?
    @State private var categoriesExpanded = false
    @State private var categoriesLoading = false
    @State private var productsLoading = false
    @State private var loaded = false
    @State private var loadedForCustomer = ""
    /// Trader VAS commission rate from api/common/vas/categories (e.g. 0.05 = 5%).
    @State private var commissionRate: Double = 0

    @State private var recipient = ""
    @State private var customAmount = ""
    @State private var reference = ""
    @State private var submitting = false
    @State private var success = false

    private let grid = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    private let wideGrid = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            categorySection
            productSection
            orderSummary
        }
        // The catalog is read on the acting customer's token, so a different customer means
        // what is on screen is dropped and re-read for the new one.
        .task(id: store.actingCustomerId) { await loadIfNeeded() }
        .alert("Sale successful", isPresented: $success) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your VAS sale has been submitted. Check Recent VAS transactions for the outcome.")
        }
    }

    // MARK: Categories

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("1. Choose a category")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Brand.textPrimary)
                Spacer()
                if !categories.isEmpty {
                    Button(categoriesExpanded ? "Show less" : "View all") {
                        withAnimation { categoriesExpanded.toggle() }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Brand.purple)
                }
            }

            if categoriesLoading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
            } else if categoriesExpanded {
                LazyVGrid(columns: wideGrid, spacing: 10) {
                    ForEach(categories) { node in
                        CategoryCard(node: node, selected: node.id == selectedCategory?.id) {
                            select(node)
                        }
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(categories) { node in
                            CategoryCard(node: node, selected: node.id == selectedCategory?.id) {
                                select(node)
                            }
                            .frame(width: 122)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .card()
    }

    // MARK: Products

    private var productSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("2. Select a product")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Brand.textPrimary)

            if let category = selectedCategory {
                // "<Category> powered by Limes", as on the web portal.
                (Text(category.name).font(.system(size: 12, weight: .bold))
                    .foregroundColor(Brand.textPrimary)
                 + Text(" powered by ").font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                 + Text("Limes").font(.system(size: 12, weight: .bold))
                    .foregroundColor(Brand.success))
            }

            if productsLoading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
            } else if products.isEmpty {
                Text("No products available for this category.")
                    .font(.system(size: 12))
                    .foregroundColor(Brand.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                LazyVGrid(columns: grid, spacing: 10) {
                    ForEach(products) { product in
                        ProductCard(product: product, selected: product.id == selectedProduct?.id) {
                            selectedProduct = product
                            if !product.isAdHoc { customAmount = "" }
                        }
                    }
                }
            }
        }
        .card()
    }

    // MARK: Order summary

    private var orderSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order summary")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Brand.textPrimary)

            VasField(title: "Recipient", text: $recipient, placeholder: "082 123 4567",
                     keyboard: .phonePad, autocapitalize: false)

            // Only an ad-hoc product lets the buyer set the amount.
            if selectedProduct?.isAdHoc == true {
                VasField(title: "Custom amount (R)", text: $customAmount,
                         placeholder: "R e.g. 20", keyboard: .decimalPad, autocapitalize: false)
            }

            VStack(alignment: .leading, spacing: 6) {
                VasField(title: "Optional reference", text: $reference,
                         placeholder: "e.g. invoice, customer name")
                Text("\(reference.count)/30")
                    .font(.system(size: 11))
                    .foregroundColor(Brand.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Divider()

            summaryRow("Product",
                       selectedProduct?.name ?? "No product selected",
                       valueColor: selectedProduct == nil ? Brand.textSecondary : Brand.textPrimary)
            if selectedProduct != nil {
                summaryRow("Amount", VasFormat.money(currentAmount))
            }
            summaryRow("Service fee", VasFormat.money(0))
            summaryRow("Your commission (est.)", VasFormat.money(currentAmount * commissionRate))

            Divider()

            HStack {
                Text("Total")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Brand.textPrimary)
                Spacer()
                Text(VasFormat.money(currentAmount))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Brand.purple)
            }

            Button(submitting ? "Processing…" : "Sell now") { purchase() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(submitting)
                .opacity(submitting ? 0.6 : 1)

            Text("Paid from your anokiX wallet. Change how you pay in Settings → Preferences.")
                .font(.system(size: 11))
                .foregroundColor(Brand.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private func summaryRow(_ label: String, _ value: String,
                            valueColor: Color = Brand.textPrimary) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundColor(Brand.textSecondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundColor(valueColor)
                .multilineTextAlignment(.trailing)
        }
    }

    /// The amount that will be charged: ad-hoc → custom input; fixed → the product price.
    private var currentAmount: Double {
        guard let product = selectedProduct else { return 0 }
        return product.isAdHoc ? VasFormat.parse(customAmount) : product.price
    }

    // MARK: Data

    private func loadIfNeeded() async {
        let customerId = store.actingCustomerId
        guard !customerId.isEmpty else { return }
        guard !loaded || loadedForCustomer != customerId else { return }
        loaded = true
        loadedForCustomer = customerId
        categories = []
        products = []
        selectedCategory = nil
        selectedProduct = nil
        customAmount = ""

        categoriesLoading = true
        do {
            let data = try await APIClient.shared.getVasCategories(customerId: customerId)
            commissionRate = data.commission_rate
            categories = data.leaves
        } catch {
            store.error = (error as? LocalizedError)?.errorDescription
                ?? "Could not load the VAS catalog."
        }
        categoriesLoading = false

        if let first = categories.first { select(first) }
    }

    private func select(_ node: VasCategoryNode) {
        selectedCategory = node
        // Reset the product selection when switching category.
        selectedProduct = nil
        customAmount = ""
        Task { await loadProducts(node.id) }
    }

    private func loadProducts(_ categoryId: String) async {
        productsLoading = true
        products = []
        do {
            let data = try await APIClient.shared.getVasProducts(
                category: categoryId, page: 1, limit: Self.productLimit,
                customerId: store.actingCustomerId)
            products = data.products
        } catch {
            store.error = (error as? LocalizedError)?.errorDescription
                ?? "Could not load the products."
        }
        productsLoading = false
    }

    // MARK: Purchase

    /// Sell now stays enabled so a tap always explains what is missing rather than silently
    /// doing nothing.
    private func purchase() {
        guard let product = selectedProduct, let category = selectedCategory else {
            store.error = "Please select a product first."
            return
        }
        let msisdn = recipient.trimmed
        if msisdn.isEmpty {
            store.error = "Please enter the recipient's mobile number."
            return
        }
        if !VasFormat.isValidMsisdn(msisdn) {
            store.error = "Enter a valid mobile number, e.g. 082 123 4567."
            return
        }
        let amount = currentAmount
        if amount <= 0 {
            store.error = "Please enter a valid amount greater than R0.00."
            return
        }
        let customerId = store.actingCustomerId
        guard !customerId.isEmpty else {
            store.error = "Choose the customer you are acting for first."
            return
        }

        submitting = true
        Task {
            do {
                try await APIClient.shared.purchaseVas(
                    productId: product.id, msisdn: msisdn, amount: amount,
                    sku: product.sku ?? "", name: product.name ?? "",
                    category: category.name, customerId: customerId)
                // Reset the form and refresh the dashboard.
                selectedProduct = nil
                customAmount = ""
                reference = ""
                success = true
                await store.loadTransactions()
            } catch {
                store.error = (error as? LocalizedError)?.errorDescription
                    ?? "Could not complete the sale."
            }
            submitting = false
        }
    }
}

// MARK: - Cards

private struct CategoryCard: View {
    let node: VasCategoryNode
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: VasIcons.icon(for: node.id, node.name))
                    .font(.system(size: 18))
                    .foregroundColor(selected ? Brand.success : Brand.purple)
                    .frame(width: 36, height: 36)
                    .background((selected ? Brand.success : Brand.purple).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text(node.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Brand.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text("\(node.productCount) \(node.productCount == 1 ? "bundle" : "bundles")")
                    .font(.system(size: 10))
                    .foregroundColor(Brand.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12).padding(.horizontal, 8)
            .background(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(selected ? Brand.success : Brand.border, lineWidth: selected ? 2 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

private struct ProductCard: View {
    let product: VasProductDTO
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    // Ad-hoc products show "Custom" over the name — the buyer sets the amount.
                    Text(product.isAdHoc ? "Custom" : (product.name ?? "—"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Brand.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Brand.success)
                    }
                }
                Text(product.isAdHoc ? (product.name ?? "") : VasFormat.money(product.price))
                    .font(.system(size: 12))
                    .foregroundColor(Brand.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .topLeading)
            .padding(12)
            .background(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(selected ? Brand.success : Brand.border, lineWidth: selected ? 2 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
