import SwiftUI

// MARK: - Payments

struct PaymentsView: View {
    @State private var toastMsg: String?
    @State private var selected: ListItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    StatTile(label: "Settled Today", value: "R 419.50", valueColor: Brand.success, icon: "checkmark.seal", iconTint: Brand.success)
                    StatTile(label: "Pending", value: "R 1,250.00", valueColor: Brand.warning, icon: "clock", iconTint: Brand.warning)
                }
                ListCard(title: "Recent Payments") {
                    VStack(spacing: 0) {
                        ForEach(Array(MockData.payments.enumerated()), id: \.element.id) { idx, p in
                            GenericRow(item: p) { selected = p }
                            if idx < MockData.payments.count - 1 { Divider() }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Brand.background)
        .confirmationDialog(selected?.title ?? "", isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } }), titleVisibility: .visible) {
            Button("Issue Refund", role: .destructive) { toastMsg = "Refund initiated."; selected = nil }
            Button("View Receipt") { toastMsg = "Receipt opened."; selected = nil }
            Button("Cancel", role: .cancel) { selected = nil }
        }
        .toast($toastMsg)
    }
}

// MARK: - Customers

struct CustomersView: View {
    @State private var selected: ListItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    StatTile(label: "Total Customers", value: "59", icon: "person.2", iconTint: Brand.purple)
                    StatTile(label: "VIP", value: "1", valueColor: Brand.success, icon: "star", iconTint: Brand.success)
                }
                ListCard(title: "Your Customers") {
                    VStack(spacing: 0) {
                        ForEach(Array(MockData.customers.enumerated()), id: \.element.id) { idx, c in
                            GenericRow(item: c, leadingInitial: true) { selected = c }
                            if idx < MockData.customers.count - 1 { Divider() }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Brand.background)
        .sheet(item: $selected) { c in
            VStack(spacing: 16) {
                InitialBadge(text: String(c.title.prefix(1)), color: Brand.purple, size: 64).padding(.top, 24)
                Text(c.title).font(.system(size: 20, weight: .bold))
                Text(c.subtitle).font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                StatusBadge(text: c.badge, fg: badgeTone(c.badge).fg, bg: badgeTone(c.badge).bg)
                Spacer()
                HStack(spacing: 12) {
                    Button("Message") {}.buttonStyle(PrimaryButtonStyle())
                    Button("Call") {}.buttonStyle(PrimaryButtonStyle())
                }.padding(.horizontal, 20).padding(.bottom, 20)
            }
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Offers / Promotions

struct OffersView: View {
    @State private var toastMsg: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ListCard(title: "Available Offers") {
                    VStack(spacing: 0) {
                        ForEach(Array(MockData.traderPromotions.enumerated()), id: \.element.id) { idx, o in
                            HStack(spacing: 12) {
                                Image(systemName: "tag.fill").foregroundColor(Brand.purple)
                                    .frame(width: 42, height: 42).background(Brand.purpleLight).clipShape(RoundedRectangle(cornerRadius: 11))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(o.title).font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
                                    Text(o.subtitle).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                                }
                                Spacer()
                                Button(o.badge == "Upcoming" ? "Soon" : "Claim") {
                                    toastMsg = o.badge == "Upcoming" ? "Offer not yet active." : "Offer claimed!"
                                }
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(o.badge == "Upcoming" ? Brand.textTertiary : Brand.purple).clipShape(Capsule())
                            }
                            .padding(.vertical, 10)
                            if idx < MockData.traderPromotions.count - 1 { Divider() }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Brand.background)
        .toast($toastMsg)
    }
}
