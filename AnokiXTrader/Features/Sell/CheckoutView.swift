import SwiftUI

/// POS "Current Sale" / Complete Sale (Pagamio). Review lines (qty steppers + remove),
/// apply a discount, pick a payment method, and commit the sale via
/// `api/trader/pos/sale`. VAT (15%) is extracted from the inclusive total; on success
/// a receipt sheet mirrors the portal's Sale Completed modal.
struct CheckoutView: View {
    @EnvironmentObject var cart: Cart
    @Environment(\.dismiss) private var dismiss
    @State private var discountText = ""
    @State private var payment: PosPayment = .wallet
    @State private var submitting = false
    @State private var receipt: PosSaleDTO?
    @State private var errorMsg: String?

    private var inclusive: Double { cart.subtotal }
    private var discount: Double { min(max(0, Double(discountText) ?? 0), inclusive) }
    private var total: Double { max(0, inclusive - discount) }
    private var vat: Double { total * 0.15 / 1.15 }
    private var subtotalExcl: Double { total - vat }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Line items with qty steppers + remove
                VStack(alignment: .leading, spacing: 6) {
                    SectionHeader(title: "Current Sale")
                    if cart.isEmpty {
                        Text("Your cart is empty. Add products to start a sale.")
                            .font(.system(size: 14)).foregroundColor(Brand.textSecondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 24)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(cart.lines) { line in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(line.name).font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
                                        Text("\(Money.rand(line.unitPrice)) each").font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                                        Text(Money.rand(line.lineTotal)).font(.system(size: 13, weight: .bold)).foregroundColor(Brand.purple)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 6) {
                                        Button { cart.remove(line.id) } label: {
                                            Image(systemName: "trash").foregroundColor(Brand.danger).font(.system(size: 15))
                                        }
                                        QtyStepper(qty: line.qty,
                                                   dec: { cart.setQty(line.id, line.qty - 1) },
                                                   inc: { cart.setQty(line.id, line.qty + 1) })
                                    }
                                }
                                .padding(.vertical, 10)
                                if line.id != cart.lines.last?.id { Divider() }
                            }
                        }
                    }
                }
                .card()

                // Discount + totals
                VStack(spacing: 10) {
                    HStack {
                        Text("Discount").font(.system(size: 14)).foregroundColor(Brand.textSecondary)
                        Spacer()
                        TextField("0", text: $discountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 90, height: 36)
                            .padding(.horizontal, 10)
                            .background(Brand.surfaceVariant)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Brand.border, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Divider()
                    totalRow("Subtotal (excl. VAT)", Money.rand(subtotalExcl))
                    totalRow("VAT (15%)", Money.rand(vat))
                    Divider()
                    HStack {
                        Text("Total").font(.system(size: 16, weight: .bold))
                        Spacer()
                        Text(Money.rand(total)).font(.system(size: 18, weight: .bold)).foregroundColor(Brand.purple)
                    }
                }
                .card()

                // Payment method
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Payment Method")
                    Menu {
                        ForEach(PosPayment.allCases) { m in
                            Button(m.label) { payment = m }
                        }
                    } label: {
                        HStack {
                            Text(payment.label).font(.system(size: 14)).foregroundColor(Brand.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.down").font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                        }
                        .padding(.horizontal, 14).frame(height: 48)
                        .background(Brand.surfaceVariant)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .card()

                Button(submitting ? "Processing…" : "Complete Sale · \(Money.rand(total))") {
                    Task { await completeSale() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(cart.isEmpty || submitting)
            }
            .padding(16)
        }
        .background(Brand.background)
        .navigationTitle("Current Sale")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $receipt) { sale in
            PosReceiptView(sale: sale) {
                cart.clear()
                receipt = nil
                dismiss()
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Sale failed", isPresented: .constant(errorMsg != nil)) {
            Button("OK") { errorMsg = nil }
        } message: {
            Text(errorMsg ?? "")
        }
    }

    private func completeSale() async {
        guard !cart.isEmpty, !submitting else { return }
        submitting = true
        let items: [[String: Any]] = cart.lines.map {
            ["product_id": Int($0.id) ?? 0, "quantity": $0.qty, "unit_price": $0.unitPrice]
        }
        do {
            let sale = try await APIClient.shared.createPosSale(
                items: items, paymentMethod: payment.rawValue, discount: discount)
            receipt = sale
        } catch {
            errorMsg = (error as? LocalizedError)?.errorDescription ?? "Failed to complete sale."
        }
        submitting = false
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
