import SwiftUI

struct SupportView: View {
    @Environment(\.openURL) private var openURL
    @State private var toastMsg: String?

    private let contacts: [(String, String, String)] = [
        ("Live Chat", "message.fill", "chat"),
        ("WhatsApp", "phone.bubble.fill", "whatsapp"),
        ("Call Us", "phone.fill", "tel:0800123456"),
        ("Email Us", "envelope.fill", "mailto:support@anokix.co.za"),
        ("Submit Ticket", "plus.bubble.fill", "ticket"),
    ]
    private let health: [(String, Bool)] = [
        ("POS Connection", true), ("Receipt Printer", true), ("Barcode Scanner", true),
        ("Wallet Sync", true), ("Internet", true), ("App Version", true),
    ]
    private let topics = ["How do I settle my wallet?", "Connecting a barcode scanner", "Understanding Limes points", "Placing a marketplace order"]
    private let kb: [(String, String)] = [
        ("📘", "Getting Started"), ("💳", "Payments & Wallet"), ("📦", "Inventory"),
        ("🎁", "Rewards"), ("🛒", "Marketplace"), ("⚙️", "POS Setup"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Atlas AI card
                VStack(alignment: .leading, spacing: 8) {
                    Label("Ask Atlas AI", systemImage: "sparkles").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                    Text("Get instant answers about your store, orders, wallet and rewards.")
                        .font(.system(size: 13)).foregroundColor(.white.opacity(0.9))
                    Button("Start a conversation") { toastMsg = "Atlas AI — coming soon." }
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.purple)
                        .padding(.horizontal, 16).padding(.vertical, 9).background(Color.white).clipShape(Capsule())
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [Brand.purple, Brand.purpleDark], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Text("Get Help").font(.system(size: 17, weight: .bold))
                VStack(spacing: 0) {
                    ForEach(Array(contacts.enumerated()), id: \.element.0) { idx, c in
                        Button { handle(c.2) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: c.1).foregroundColor(Brand.purple)
                                    .frame(width: 38, height: 38).background(Brand.purpleLight).clipShape(RoundedRectangle(cornerRadius: 10))
                                Text(c.0).font(.system(size: 15, weight: .medium)).foregroundColor(Brand.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(Brand.textTertiary)
                            }.padding(.vertical, 10).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        if idx < contacts.count - 1 { Divider().padding(.leading, 52) }
                    }
                }.card()

                // Device health
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Device Health")
                    ForEach(health, id: \.0) { h in
                        HStack {
                            Image(systemName: h.1 ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(h.1 ? Brand.success : Brand.danger)
                            Text(h.0).font(.system(size: 14)).foregroundColor(Brand.textPrimary)
                            Spacer()
                            Text(h.1 ? "OK" : "Issue").font(.system(size: 12, weight: .semibold)).foregroundColor(h.1 ? Brand.success : Brand.danger)
                        }.padding(.vertical, 6)
                    }
                    Button("Run Health Check") { toastMsg = "All systems healthy ✓" }
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.purple)
                        .frame(maxWidth: .infinity).padding(.vertical, 10).background(Brand.purpleLight).clipShape(RoundedRectangle(cornerRadius: 10))
                }.card()

                Text("Knowledge Base").font(.system(size: 17, weight: .bold))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(kb, id: \.1) { k in
                        VStack(spacing: 6) {
                            Text(k.0).font(.system(size: 24))
                            Text(k.1).font(.system(size: 11, weight: .medium)).multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity).padding(.vertical, 14).card(padding: 6)
                    }
                }

                ListCard(title: "Popular Topics") {
                    VStack(spacing: 0) {
                        ForEach(Array(topics.enumerated()), id: \.offset) { idx, t in
                            HStack {
                                Image(systemName: "doc.text").foregroundColor(Brand.textSecondary)
                                Text(t).font(.system(size: 14)).foregroundColor(Brand.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(Brand.textTertiary)
                            }.padding(.vertical, 10)
                            if idx < topics.count - 1 { Divider() }
                        }
                    }
                }

                ListCard(title: "My Support Tickets") {
                    VStack(spacing: 0) {
                        ForEach(Array(MockData.supportTickets.enumerated()), id: \.element.id) { idx, t in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(t.id) · \(t.title)").font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
                                    Text(t.description).font(.system(size: 12)).foregroundColor(Brand.textSecondary).lineLimit(2)
                                    Text("Updated \(t.updated)").font(.system(size: 11)).foregroundColor(Brand.textTertiary)
                                }
                                Spacer()
                                StatusBadge(text: t.status.replacingOccurrences(of: "_", with: " ").capitalized,
                                            fg: badgeTone(t.status).fg, bg: badgeTone(t.status).bg)
                            }.padding(.vertical, 10)
                            if idx < MockData.supportTickets.count - 1 { Divider() }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Brand.background)
        .toast($toastMsg)
    }

    private func handle(_ action: String) {
        if action.hasPrefix("tel:") || action.hasPrefix("mailto:") {
            if let url = URL(string: action) { openURL(url) }
        } else {
            toastMsg = "\(action.capitalized) — coming soon."
        }
    }
}
