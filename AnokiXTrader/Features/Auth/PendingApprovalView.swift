import SwiftUI
import UIKit

/// "Application Under Review" screen shown when login returns a still-pending
/// account (status=true, pending_approval=true, no token). Rendered in the dark
/// auth chrome, mirroring the web portal layout — a details card, the IMB wallet
/// state, a "what happens next" list, and a Back to Login action.
struct PendingApprovalView: View {
    @EnvironmentObject var session: Session

    // Dark-chrome palette (matches the login screen + Android pending screen).
    private let tagline    = Color(hex: "#8A93B2")
    private let cardBg      = Color(hex: "#0F1836")
    private let cardBorder  = Color(hex: "#22314F")
    private let rowDividerC = Color(hex: "#1C2A4A")
    private let link        = Color(hex: "#6EA8FE")
    private let bodyText    = Color(hex: "#C7D0E4")

    private let steps = [
        "We verify your business details and uploaded documents.",
        "You'll get an email as soon as your account is approved.",
        "Sign in again once approved to reach your dashboard."
    ]

    private var data: LoginData? { session.pendingApproval }
    private var walletActivated: Bool { data?.wallet?.isActivated ?? false }

    var body: some View {
        ZStack {
            Brand.loginBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Back to login
                    Button(action: backToLogin) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left").font(.system(size: 14, weight: .semibold))
                            Text("Back to login").font(.system(size: 14))
                        }
                        .foregroundColor(tagline)
                    }
                    .padding(.vertical, 8)

                    // Clock badge
                    ZStack {
                        Circle().fill(Color(hex: "#2A1E4A")).frame(width: 64, height: 64)
                        Circle()
                            .fill(LinearGradient(colors: [Brand.purple, Color(hex: "#6366F1")],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 46, height: 46)
                        Image(systemName: "clock")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 16)

                    Text("Application Under Review")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 18)

                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(tagline)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)

                    detailsCard.padding(.top, 24)

                    if !walletActivated {
                        walletInfoBox.padding(.top, 14)
                    }

                    Text("What happens next")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 26)

                    nextSteps.padding(.top, 8)

                    Button("Back to Login", action: backToLogin)
                        .buttonStyle(WelcomeGradientButtonStyle())
                        .padding(.top, 26)

                    supportFooter.padding(.top, 18)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var detailsCard: some View {
        VStack(spacing: 0) {
            detailRow("Status") { statusBadge }
            divider
            detailRow("Business") { valueText(data?.business_name) }
            divider
            detailRow("Reference") {
                Text(display(data?.reference))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(link)
                    .multilineTextAlignment(.trailing)
            }
            divider
            detailRow("Submitted") { valueText(data?.submitted_at) }
            divider
            detailRow("IMB Wallet") { walletBadge }
        }
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBg)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(cardBorder, lineWidth: 1))
        )
    }

    private var walletInfoBox: some View {
        HStack(spacing: 0) {
            Rectangle().fill(Color(hex: "#6366F1")).frame(width: 3)
            Text(walletMessage)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#A9B4CC"))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
        }
        .background(Color(hex: "#131E3B"))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var nextSteps: some View {
        VStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { idx, text in
                HStack(alignment: .top, spacing: 14) {
                    Text("\(idx + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Brand.purple))
                    Text(text)
                        .font(.system(size: 13))
                        .foregroundColor(bodyText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10)
            }
        }
    }

    private var supportFooter: some View {
        Button(action: emailSupport) {
            HStack(spacing: 6) {
                Image(systemName: "envelope").font(.system(size: 13))
                Text("Need help?").foregroundColor(tagline)
                Text("support@anokix.com").foregroundColor(link).fontWeight(.semibold)
            }
            .font(.system(size: 13))
            .foregroundColor(tagline)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Row helpers

    private func detailRow<V: View>(_ label: String, @ViewBuilder value: () -> V) -> some View {
        HStack(spacing: 12) {
            Text(label).font(.system(size: 13)).foregroundColor(tagline)
            value().frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 14)
    }

    private var divider: some View {
        Rectangle().fill(rowDividerC).frame(height: 1)
    }

    private func valueText(_ value: String?) -> some View {
        Text(display(value))
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .multilineTextAlignment(.trailing)
    }

    private var statusBadge: some View {
        Text(display(data?.registration_status, fallback: "Pending Approval"))
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(Color(hex: "#C4B5FD"))
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Capsule().fill(Color(hex: "#4C3A8C")))
    }

    private var walletBadge: some View {
        Text(walletActivated ? "Activated" : "Not activated")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(walletActivated ? Color(hex: "#4ADE80") : Color(hex: "#B4C3D8"))
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Capsule().fill(walletActivated ? Color(hex: "#16A34A").opacity(0.18)
                                                        : Color.white.opacity(0.10)))
    }

    // MARK: - Derived content

    private var subtitle: String {
        if let name = data?.user?.first_name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return "\(name), thanks for registering. Our team is reviewing your application and documents."
        }
        return "Thanks for registering. Our team is reviewing your application and documents."
    }

    private var walletMessage: String {
        if let err = data?.wallet?.last_error?.trimmingCharacters(in: .whitespacesAndNewlines),
           !err.isEmpty {
            return err
        }
        return "You chose to activate your wallet later. You can set it up from your profile once your account is approved."
    }

    private func display(_ value: String?, fallback: String = "—") -> String {
        guard let v = value?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else {
            return fallback
        }
        return v
    }

    // MARK: - Actions

    private func backToLogin() {
        session.pendingApproval = nil
        session.stage = .login
    }

    private func emailSupport() {
        let subject = "Support Request – anokiX Trader"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:support@anokix.com?subject=\(subject)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}
