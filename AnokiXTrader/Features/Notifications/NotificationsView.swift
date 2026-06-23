import SwiftUI

struct NotificationsView: View {
    @State private var items = MockData.notifications
    @State private var filter = "All"

    private var unreadCount: Int { items.filter { !$0.read }.count }

    private var filtered: [TraderNotification] {
        switch filter {
        case "Unread": return items.filter { !$0.read }
        case "Important": return items.filter { $0.important }
        case "Orders", "Inventory", "Wallet", "Rewards", "System":
            return items.filter { $0.type == filter.lowercased() }
        default: return items
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("\(unreadCount) unread").font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                    Spacer()
                    Button("Mark all read") {
                        items = items.map { var n = $0; n.read = true; return n }
                    }
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.purple)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MockData.notificationFilters, id: \.self) { f in
                            FilterChip(label: f, selected: f == filter) { filter = f }
                        }
                    }
                }

                VStack(spacing: 10) {
                    ForEach(filtered) { n in
                        NotificationRow(n: n).onTapGesture {
                            if let idx = items.firstIndex(of: n) { items[idx].read = true }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Brand.background)
    }
}

struct NotificationRow: View {
    let n: TraderNotification

    private var tint: Color {
        switch n.type {
        case "orders": return Brand.info
        case "wallet": return Brand.success
        case "inventory": return Brand.warning
        case "rewards": return Brand.purple
        default: return Brand.textSecondary
        }
    }
    private var icon: String {
        switch n.type {
        case "orders": return "shippingbox.fill"
        case "wallet": return "wallet.pass.fill"
        case "inventory": return "archivebox.fill"
        case "rewards": return "gift.fill"
        default: return "gearshape.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 15)).foregroundColor(tint)
                .frame(width: 40, height: 40).background(tint.opacity(0.12)).clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if n.important { Text("★").foregroundColor(Brand.warning) }
                    Text(n.title).font(.system(size: 14, weight: .bold)).foregroundColor(Brand.textPrimary)
                    if !n.read { Circle().fill(Brand.purple).frame(width: 7, height: 7) }
                }
                Text(n.message).font(.system(size: 12)).foregroundColor(Brand.textSecondary).fixedSize(horizontal: false, vertical: true)
                Text(n.time).font(.system(size: 11)).foregroundColor(Brand.textTertiary)
            }
            Spacer()
        }
        .padding(14)
        .background(n.read ? Brand.surface : Brand.purpleLight.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.border, lineWidth: 1))
    }
}
