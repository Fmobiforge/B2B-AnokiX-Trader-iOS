import SwiftUI

/// Cart review → VAT breakdown → payment method → receipt. Shared by POS sales
/// (mirrors the Android CheckoutActivity reused for both sale & marketplace order).
struct CheckoutView: View {
    @EnvironmentObject var cart: Cart
    @Environment(\.dismiss) private var dismiss
    @State private var paymentMethod = "Card"
    @State private var showReceipt = false

    private let methods = ["Card", "Cash", "anokiX Wallet", "QR / SnapScan"]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Line items with qty steppers
                VStack(alignment: .leading, spacing: 6) {
                    SectionHeader(title: "Order Items")
                    VStack(spacing: 0) {
                        ForEach(cart.lines) { line in
                            HStack(spacing: 12) {
                                InitialBadge(text: String(line.name.prefix(1)), color: Brand.purple, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(line.name).font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
                                    Text(Money.rand(line.unitPrice)).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                                }
                                Spacer()
                                QtyStepper(qty: line.qty,
                                           dec: { cart.setQty(line.id, line.qty - 1) },
                                           inc: { cart.setQty(line.id, line.qty + 1) })
                            }
                            .padding(.vertical, 10)
                            if line.id != cart.lines.last?.id { Divider() }
                        }
                    }
                }
                .card()

                // Totals
                VStack(spacing: 10) {
                    totalRow("Subtotal", Money.rand(cart.subtotal))
                    totalRow("VAT (15%)", Money.rand(cart.vat))
                    Divider()
                    HStack {
                        Text("Total").font(.system(size: 16, weight: .bold))
                        Spacer()
                        Text(Money.rand(cart.total)).font(.system(size: 18, weight: .bold)).foregroundColor(Brand.purple)
                    }
                }
                .card()

                // Payment method
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Payment Method")
                    ForEach(methods, id: \.self) { m in
                        Button { paymentMethod = m } label: {
                            HStack {
                                Image(systemName: paymentMethod == m ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(paymentMethod == m ? Brand.purple : Brand.textTertiary)
                                Text(m).font(.system(size: 14)).foregroundColor(Brand.textPrimary)
                                Spacer()
                            }
                            .padding(.vertical, 8).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .card()

                Button("Charge \(Money.rand(cart.total))") { showReceipt = true }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(cart.isEmpty)
            }
            .padding(16)
        }
        .background(Brand.background)
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showReceipt) {
            ReceiptView(total: cart.total, method: paymentMethod) {
                cart.clear()
                showReceipt = false
                dismiss()
            }
            .presentationDetents([.medium])
        }
    }

    private func totalRow(_ l: String, _ r: String) -> some View {
        HStack {
            Text(l).font(.system(size: 14)).foregroundColor(Brand.textSecondary)
            Spacer()
            Text(r).font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
        }
    }
}

private struct QtyStepper: View {
    let qty: Int
    let dec: () -> Void
    let inc: () -> Void
    var body: some View {
        HStack(spacing: 14) {
            Button(action: dec) { Image(systemName: "minus.circle.fill").foregroundColor(Brand.textTertiary) }
            Text("\(qty)").font(.system(size: 15, weight: .bold)).frame(minWidth: 20)
            Button(action: inc) { Image(systemName: "plus.circle.fill").foregroundColor(Brand.purple) }
        }
    }
}

struct ReceiptView: View {
    let total: Double
    let method: String
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 60)).foregroundColor(Brand.success).padding(.top, 30)
            Text("Payment Successful").font(.system(size: 20, weight: .bold)).foregroundColor(Brand.textPrimary)
            Text("\(Money.rand(total)) · \(method)").font(.system(size: 14)).foregroundColor(Brand.textSecondary)
            Text("A receipt has been issued to the customer.").font(.system(size: 13)).foregroundColor(Brand.textTertiary)
                .multilineTextAlignment(.center).padding(.horizontal, 30)
            Spacer()
            Button("Done", action: onDone).buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 20).padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(Brand.background)
    }
}
