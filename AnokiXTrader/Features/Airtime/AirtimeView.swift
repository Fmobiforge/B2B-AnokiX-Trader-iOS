import SwiftUI

struct AirtimeView: View {
    @State private var service = "Airtime"
    @State private var provider = "Vodacom"
    @State private var number = ""
    @State private var amount = "R50"
    @State private var toastMsg: String?
    @State private var showVoucher = false

    private let services = ["Airtime", "Data", "Electricity", "Water", "DStv"]
    private let providers = ["Vodacom", "MTN", "Cell C", "Telkom"]
    private let amounts = ["R10", "R20", "R50", "R100", "R200", "R500"]
    private let amtCols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                section("Service") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(services, id: \.self) { s in
                                FilterChip(label: s, selected: s == service) { service = s }
                            }
                        }
                    }
                }
                section("Provider") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(providers, id: \.self) { p in
                            Button { provider = p } label: {
                                Text(p).font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(p == provider ? .white : Brand.textPrimary)
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(p == provider ? Brand.purple : Brand.surface)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                section("Mobile Number") {
                    TextField("071 234 5678", text: $number)
                        .keyboardType(.phonePad)
                        .padding(14).background(Brand.surface)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                section("Amount") {
                    LazyVGrid(columns: amtCols, spacing: 10) {
                        ForEach(amounts, id: \.self) { a in
                            Button { amount = a } label: {
                                Text(a).font(.system(size: 15, weight: .bold))
                                    .foregroundColor(a == amount ? .white : Brand.textPrimary)
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(a == amount ? Brand.purple : Brand.surface)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Button("Purchase \(amount) \(service)") {
                    if number.isEmpty { toastMsg = "Enter a mobile number." } else { showVoucher = true }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(16)
        }
        .background(Brand.background)
        .sheet(isPresented: $showVoucher) {
            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundColor(Brand.success).padding(.top, 28)
                Text("Purchase Successful").font(.system(size: 19, weight: .bold))
                Text("\(provider) \(amount) \(service)").font(.system(size: 14)).foregroundColor(Brand.textSecondary)
                Text("Voucher PIN: 1234 5678 9012")
                    .font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(Brand.purple)
                    .padding().background(Brand.purpleLight).clipShape(RoundedRectangle(cornerRadius: 12))
                Text("Recharge sent to \(number)").font(.system(size: 12)).foregroundColor(Brand.textTertiary)
                Spacer()
                Button("Done") { showVoucher = false }.buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 20).padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity).background(Brand.background)
            .presentationDetents([.medium])
        }
        .toast($toastMsg)
    }

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 14, weight: .bold)).foregroundColor(Brand.textPrimary)
            content()
        }
    }
}
