import SwiftUI

/// Dark side drawer mirroring the Trader Portal sidebar (18 items + profile footer).
struct DrawerView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var session: Session

    /// The drawer opens over the tab bar, so the screen behind it is always a tab.
    private var activeKey: String? {
        switch router.tab {
        case .home:   return "home"
        case .sell:   return "sell"
        case .orders: return "orders"
        case .more:   return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 10) {
                Image("LogoWhite")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 30)
                Text("Trader Portal")
                    .font(.app(11, .semibold))
                    .foregroundColor(Brand.purpleTextLt)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color(hex: "#161D4E"))
                    .overlay(Capsule().stroke(Color(hex: "#3E3389"), lineWidth: 1))
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)

            Divider().background(Color.white.opacity(0.1))

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(MockData.drawerMenu) { item in
                        let active = item.key == activeKey
                        Button { router.route(item.key) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: item.systemIcon)
                                    .font(.system(size: 17))
                                    .frame(width: 24)
                                    .foregroundColor(active ? .white : Brand.drawerMuted)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.title)
                                        .font(.app(15, active ? .semibold : .medium))
                                        .foregroundColor(active ? .white : Brand.drawerMuted)
                                    if let sub = item.subtitle {
                                        Text(sub).font(.app(11)).foregroundColor(Brand.purpleTextLt)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            // Portal sidebar active item: indigo → violet, 10pt corners.
                            .background(active ? AnyView(Brand.navActiveGradient) : AnyView(Color.clear))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }

            Divider().background(Color.white.opacity(0.1))

            // Profile + logout footer
            HStack(spacing: 12) {
                InitialBadge(text: String(session.storeName.prefix(1)), color: Brand.purple, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.storeName).font(.app(14, .semibold)).foregroundColor(.white)
                    Text(session.accountName).font(.app(11)).foregroundColor(Brand.drawerMuted)
                }
                Spacer()
                Button {
                    router.drawerOpen = false
                    session.signOut()
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(Brand.purpleTextLt)
                        .tapTarget()
                }
                .accessibilityLabel("Sign out")
            }
            .padding(18)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Brand.drawerBg.ignoresSafeArea())
        // Swallow taps that land on the drawer's own padding — without this they fall
        // through to the scrim behind it and close the drawer the user just opened.
        .contentShape(Rectangle())
    }
}
