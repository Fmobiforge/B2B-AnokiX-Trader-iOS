import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var session: Session
    @State private var toastMsg: String?

    private let statCols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private let statusCards: [(String, String, Color)] = [
        ("Store", "Active", Brand.success), ("Wallet", "Verified", Brand.success),
        ("Rewards", "Silver", Brand.purple), ("POS Device", "Online", Brand.success),
    ]

    // section title, [field, value, ok?]
    private let sections: [(String, String, [(String, String, Bool)])] = [
        ("Store Profile", "storefront.fill", [("Store Name", "Sipho's Spaza", true), ("Phone", "071 234 5678", true), ("Address", "12 Vilakazi St, Soweto", true)]),
        ("Business", "briefcase.fill", [("Registration", "CK 2019/445566", true), ("VAT Number", "Not added", false), ("Trading Hours", "06:00 – 21:00", true)]),
        ("Wallet & Banking", "wallet.pass.fill", [("IMB Account", "···3345", true), ("Settlement", "Daily", true), ("Auto-settle", "Enabled", true)]),
        ("Rewards", "gift.fill", [("Limes Tier", "Silver", true), ("Auto-redeem", "Disabled", false)]),
        ("POS Device", "printer.fill", [("Device", "anokiX POS v1.4.2", true), ("Receipt Printer", "Connected", true), ("Barcode Scanner", "Connected", true)]),
        ("User Management", "person.2.fill", [("Owner", "Sipho K.", true), ("Cashiers", "2 active", true)]),
        ("Notifications", "bell.fill", [("Order Alerts", "On", true), ("Low Stock Alerts", "On", true), ("Marketing", "Off", false)]),
        ("Security & Access", "lock.fill", [("PIN Lock", "Enabled", true), ("Biometric", "Enabled", true), ("Last Login", "Today, 08:02", true)]),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: statCols, spacing: 12) {
                    ForEach(statusCards, id: \.0) { s in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(s.0).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                            HStack(spacing: 6) {
                                Circle().fill(s.2).frame(width: 8, height: 8)
                                Text(s.1).font(.system(size: 15, weight: .bold)).foregroundColor(s.2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14).card(padding: 0)
                    }
                }

                ForEach(sections, id: \.0) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Label(section.0, systemImage: section.1).font(.system(size: 15, weight: .bold)).foregroundColor(Brand.textPrimary)
                        ForEach(section.2, id: \.0) { field in
                            HStack {
                                Text(field.0).font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                                Spacer()
                                Text(field.1).font(.system(size: 13, weight: .medium))
                                    .foregroundColor(field.2 ? Brand.textPrimary : Brand.textTertiary)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(field.2 ? Brand.successBg.opacity(0.5) : Brand.border.opacity(0.4))
                                    .clipShape(Capsule())
                            }
                        }
                        Button("Edit \(section.0)") { toastMsg = "\(section.0) — editing coming soon." }
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.purple)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Brand.purpleLight).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .card()
                }

                // Danger zone
                VStack(alignment: .leading, spacing: 10) {
                    Text("Danger Zone").font(.system(size: 15, weight: .bold)).foregroundColor(Brand.danger)
                    dangerButton("Export My Data")
                    dangerButton("Reset Settings")
                    dangerButton("Deactivate Account")
                }
                .card()

                Button("Log Out") { session.signOut() }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(16)
        }
        .background(Brand.background)
        .toast($toastMsg)
    }

    private func dangerButton(_ title: String) -> some View {
        Button { toastMsg = "\(title) — confirm required." } label: {
            HStack {
                Text(title).font(.system(size: 14, weight: .medium)).foregroundColor(Brand.danger)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(Brand.danger.opacity(0.6))
            }
            .padding(.vertical, 10)
        }
    }
}
