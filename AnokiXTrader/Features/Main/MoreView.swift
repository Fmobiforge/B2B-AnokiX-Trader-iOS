import SwiftUI

/// The "More" tab — full module menu (mirrors the Android MoreFragment) + profile card.
struct MoreView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var session: Session

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "More")
            ScrollView {
                VStack(spacing: 16) {
                    // Profile card
                    HStack(spacing: 14) {
                        InitialBadge(text: String(session.storeName.prefix(1)), color: Brand.purple, size: 52)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.storeName).font(.app(17, .bold)).foregroundColor(Brand.textPrimary)
                            Text(session.accountName).font(.app(13)).foregroundColor(Brand.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(Brand.textTertiary)
                    }
                    .card()
                    .onTapGesture { router.presented = .settings }

                    // Module grid
                    VStack(spacing: 0) {
                        ForEach(Array(MockData.moreMenu.enumerated()), id: \.element.id) { idx, item in
                            Button { router.route(item.key) } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: item.systemIcon)
                                        .font(.system(size: 17))
                                        .foregroundColor(Brand.purple)
                                        .frame(width: 38, height: 38)
                                        .background(Brand.purpleLight)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    Text(item.title).font(.app(15, .medium)).foregroundColor(Brand.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(Brand.textTertiary)
                                }
                                .padding(.vertical, 11)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if idx < MockData.moreMenu.count - 1 {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                    .card()

                    Button {
                        session.signOut()
                    } label: {
                        Text("Log Out")
                            .font(.app(15, .semibold))
                            .foregroundColor(Brand.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Brand.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.border, lineWidth: 1))
                    }
                }
                .padding(16)
            }
            .background(Brand.background)
        }
        .navigationBarHidden(true)
    }
}
