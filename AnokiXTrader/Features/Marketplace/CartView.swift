import SwiftUI

/// My Cart (mirrors My_Cart.png). Renders the shared local cart with per-line
/// quantity steppers + delete, the free-delivery banner, and the order summary.
struct CartView: View {
    @ObservedObject var store: MarketStore
    @Environment(\.dismiss) private var dismiss
    @State private var toastMsg: String?
    @State private var goToOrder = false

    private var currency: String { store.currency }

    var body: some View {
        NavigationStack {
            Group {
                if store.cart.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .background(Brand.background)
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } }
            .navigationDestination(isPresented: $goToOrder) {
                MakeOrderView(store: store) { dismiss() }
            }
            .task { await store.refreshCart() }
            .toast($toastMsg)
        }
        // Force light: presented from screens that set .preferredColorScheme(.dark).
        .preferredColorScheme(.light)
    }

    private func proceedToCheckout() {
        guard !store.selectedLines.isEmpty else {
            toastMsg = "Select at least one item to order."
            return
        }
        goToOrder = true
    }

    private var titleText: String {
        let n = store.cart.count
        return "My Cart (\(n) \(n == 1 ? "item" : "items"))"
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cart").font(.system(size: 56)).foregroundColor(Brand.textTertiary)
            Text("Your cart is empty.").font(.system(size: 14)).foregroundColor(Brand.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 12) {
                VStack(spacing: 0) {
                    ForEach(store.cart) { line in
                        CartRow(line: line, currency: currency,
                                onToggle: { store.toggleSelected(line.id) },
                                onMinus: { store.setQty(line.id, line.qty - 1) },
                                onPlus: { store.setQty(line.id, line.qty + 1) },
                                onDelete: { store.remove(line.id) })
                        if line.id != store.cart.last?.id { Divider() }
                    }
                }
                .card()

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(Brand.success)
                    Text("You've unlocked FREE delivery!").font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Brand.success)
                    Spacer()
                }
                .padding(12).background(Brand.successBg).clipShape(RoundedRectangle(cornerRadius: 12))

                summaryCard
            }
            .padding(16)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Summary").font(.system(size: 18, weight: .bold)).foregroundColor(Brand.textPrimary)
            HStack {
                Text("Subtotal").font(.system(size: 14)).foregroundColor(Brand.textSecondary)
                Spacer()
                Text(CurrencyFmt.format(store.selectedSubtotal, symbol: currency))
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
            }
            HStack {
                Text("Delivery Fee").font(.system(size: 14)).foregroundColor(Brand.textSecondary)
                Spacer()
                Text("FREE").font(.system(size: 14, weight: .bold)).foregroundColor(Brand.success)
            }
            Divider()
            HStack {
                Text("Total").font(.system(size: 18, weight: .bold)).foregroundColor(Brand.textPrimary)
                Spacer()
                Text(CurrencyFmt.format(store.cartSubtotal, symbol: currency))
                    .font(.system(size: 20, weight: .bold)).foregroundColor(Brand.purple)
            }
            Text("Incl. VAT").font(.system(size: 11)).foregroundColor(Brand.textSecondary)
            Button("Proceed to Checkout") { proceedToCheckout() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 4)
        }
        .card()
    }
}

struct CartRow: View {
    let line: MarketCartLine
    let currency: String
    let onToggle: () -> Void
    let onMinus: () -> Void
    let onPlus: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: line.selected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundColor(line.selected ? Brand.purple : Brand.textTertiary)
            }
            .padding(.top, 16)
            RemoteImage(url: line.imageURL)
                .frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 6) {
                Text(line.name).font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary).lineLimit(2)
                Text(CurrencyFmt.format(line.unitPrice, symbol: currency))
                    .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                HStack(spacing: 0) {
                    Button(action: onMinus) { Image(systemName: "minus").frame(width: 32, height: 32) }
                    Text("\(line.qty)").font(.system(size: 14, weight: .bold)).frame(width: 34)
                    Button(action: onPlus) { Image(systemName: "plus").frame(width: 32, height: 32) }
                }
                .foregroundColor(Brand.textPrimary)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 18) {
                Button(action: onDelete) { Image(systemName: "trash").foregroundColor(Brand.danger) }
                Text(CurrencyFmt.format(line.lineTotal, symbol: currency))
                    .font(.system(size: 14, weight: .bold)).foregroundColor(Brand.textPrimary)
            }
        }
        .padding(.vertical, 10)
    }
}
