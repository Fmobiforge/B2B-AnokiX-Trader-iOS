import SwiftUI

/// Notifications — live feed from GET api/common/notifications (filter all/unread,
/// paged). KPI tiles (total/read/unread/important), All/Unread tabs, "Mark all as
/// read", and tap-to-open: a tap marks the row read (POST .../read) and routes to
/// the related screen (order → Orders, return → Goods Returns, stock → Inventory).
struct NotificationsView: View {
    @StateObject private var store = NotificationsStore()
    @EnvironmentObject var router: Router
    @State private var orderRouteId: Int?

    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                statStrip
                tabBar
                content
                pagination
            }
            .padding(16)
        }
        .background(Brand.background)
        .task { if store.items.isEmpty { await store.load() } }
        .refreshable { await store.load(page: store.page) }
        .navigationDestination(isPresented: Binding(
            get: { orderRouteId != nil },
            set: { if !$0 { orderRouteId = nil } }
        )) {
            if let id = orderRouteId { OrderDetailLoader(orderId: id) }
        }
    }

    private var statStrip: some View {
        LazyVGrid(columns: cols, spacing: 12) {
            StatTile(label: "All Notifications", value: "\(store.total)", icon: "bell.fill", iconTint: Brand.info)
            StatTile(label: "Read · \(percent(store.readCount))", value: "\(store.readCount)",
                     valueColor: Brand.success, icon: "checkmark.circle.fill", iconTint: Brand.success)
            StatTile(label: "Unread · \(percent(store.unreadCount))", value: "\(store.unreadCount)",
                     valueColor: Brand.warning, icon: "circle.fill", iconTint: Brand.warning)
            StatTile(label: "Important", value: "\(store.importantOnPage)",
                     valueColor: Brand.danger, icon: "exclamationmark.circle.fill", iconTint: Brand.danger)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 20) {
            tab("All", "all")
            tab(store.unreadCount > 0 ? "Unread (\(store.unreadCount))" : "Unread", "unread")
            Spacer()
            Button("Mark all as read") { Task { await store.markAll() } }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Brand.purple)
        }
    }

    private func tab(_ label: String, _ key: String) -> some View {
        Button { Task { await store.setFilter(key) } } label: {
            VStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(store.filter == key ? Brand.purple : Brand.textSecondary)
                Rectangle()
                    .fill(store.filter == key ? Brand.purple : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        if store.loading && store.items.isEmpty {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 50)
        } else if store.items.isEmpty {
            emptyState
        } else {
            VStack(spacing: 10) {
                ForEach(store.items) { n in
                    NotificationRow(n: n).onTapGesture { handleTap(n) }
                }
            }
        }
    }

    private var pagination: some View {
        Group {
            if store.total > 0 {
                HStack {
                    Text(showingText).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                    Spacer()
                    Button { Task { await store.load(page: store.page - 1) } } label: {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    }
                    .disabled(store.page <= 1).opacity(store.page <= 1 ? 0.3 : 1)
                    Text("\(store.page)/\(store.totalPages)").font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Brand.textPrimary).padding(.horizontal, 4)
                    Button { Task { await store.load(page: store.page + 1) } } label: {
                        Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
                    }
                    .disabled(store.page >= store.totalPages).opacity(store.page >= store.totalPages ? 0.3 : 1)
                }
                .foregroundColor(Brand.textPrimary)
                .padding(.top, 4)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bell.slash")
                .font(.system(size: 40))
                .foregroundColor(Brand.textTertiary)
            Text("You're all caught up")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Brand.textPrimary)
            Text("New alerts about your orders, deliveries and stock appear here.")
                .font(.system(size: 12))
                .foregroundColor(Brand.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
        .padding(.horizontal, 24)
    }

    // MARK: actions

    private func handleTap(_ n: NotificationDTO) {
        Task { await store.markRead(n) }
        switch n.route {
        case .order(let oid):
            if let oid {
                orderRouteId = oid          // push the order detail (parity with Android)
            } else {
                router.presented = nil
                router.tab = .orders
            }
        case .returns:
            router.presented = .goodsReturns
        case .inventory:
            router.presented = .inventory
        case .none:
            break
        }
    }

    private func percent(_ part: Int) -> String {
        guard store.total > 0 else { return "0%" }
        return String(format: "%.1f%%", 100.0 * Double(part) / Double(store.total))
    }

    private var showingText: String {
        let from = (store.page - 1) * store.perPage + 1
        let to = min(store.page * store.perPage, store.total)
        return "Showing \(from) to \(to) of \(store.total)"
    }
}

// MARK: - Row

struct NotificationRow: View {
    let n: NotificationDTO

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: n.icon).font(.system(size: 15)).foregroundColor(n.tint)
                .frame(width: 40, height: 40).background(n.tint.opacity(0.12)).clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(n.title).font(.system(size: 14, weight: .bold)).foregroundColor(Brand.textPrimary)
                    if n.isImportant {
                        Text("Important")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Brand.danger)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Brand.danger.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    if !n.is_read { Circle().fill(Brand.purple).frame(width: 7, height: 7) }
                }
                if let body = n.body, !body.isEmpty {
                    Text(body).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(NotifFmt.relative(n.created_at)).font(.system(size: 11)).foregroundColor(Brand.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(n.is_read ? Brand.surface : Brand.purpleLight.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.border, lineWidth: 1))
        .contentShape(Rectangle())
    }
}
