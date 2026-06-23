import SwiftUI

/// Dark side drawer mirroring the Trader Portal sidebar (exact 12 items + profile footer).
struct DrawerView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 10) {
                Image("LogoWhite")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 30)
                Text("Trader Portal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Brand.purpleTextLt)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)

            Divider().background(Color.white.opacity(0.1))

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(MockData.drawerMenu) { item in
                        Button { router.route(item.key) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: item.systemIcon)
                                    .font(.system(size: 17))
                                    .frame(width: 24)
                                    .foregroundColor(.white)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.white)
                                    if let sub = item.subtitle {
                                        Text(sub).font(.system(size: 11)).foregroundColor(Brand.purpleTextLt)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16).padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 10)
            }

            Divider().background(Color.white.opacity(0.1))

            // Profile + logout footer
            HStack(spacing: 12) {
                InitialBadge(text: String(session.storeName.prefix(1)), color: Brand.purple, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.storeName).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                    Text(session.accountName).font(.system(size: 11)).foregroundColor(Brand.purpleTextLt)
                }
                Spacer()
                Button {
                    router.drawerOpen = false
                    session.signOut()
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(Brand.purpleTextLt)
                }
            }
            .padding(18)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Brand.drawerBg.ignoresSafeArea())
    }
}
