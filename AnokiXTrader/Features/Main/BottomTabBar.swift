import SwiftUI

/// Custom bottom navigation — mirrors Android `BottomNavigationView` and avoids
/// UITabBar rendering issues on some simulators (e.g. VMware).
struct BottomTabBar: View {
    @Binding var selection: Tab

    private struct Item: Identifiable {
        let tab: Tab
        let title: String
        let icon: String
        var id: Tab { tab }
    }

    private let items: [Item] = [
        Item(tab: .home, title: "Dashboard", icon: "house.fill"),
        Item(tab: .sell, title: "POS", icon: "cart.fill"),
        Item(tab: .orders, title: "Orders", icon: "shippingbox.fill"),
        Item(tab: .wallet, title: "Wallet", icon: "wallet.pass.fill"),
        Item(tab: .more, title: "More", icon: "ellipsis"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Brand.border.frame(height: 1)

            HStack(spacing: 0) {
                ForEach(items) { item in
                    tabButton(item)
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 6)
        }
        .background(Brand.surface.ignoresSafeArea(edges: .bottom))
    }

    private func tabButton(_ item: Item) -> some View {
        let selected = selection == item.tab
        return Button {
            selection = item.tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: item.icon)
                    .font(.system(size: 20, weight: selected ? .semibold : .regular))
                Text(item.title)
                    .font(.system(size: 10, weight: selected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(selected ? Brand.purple : Brand.textSecondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
