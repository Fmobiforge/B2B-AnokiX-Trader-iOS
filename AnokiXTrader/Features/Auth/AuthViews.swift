import SwiftUI
import UIKit

// MARK: - Shared welcome/login chrome (mirrors the Distributor iOS app)

/// Portal login CTA: sky → blue → violet pill (bg_welcome_login_gradient on Android).
struct WelcomeGradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(16, .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Brand.ctaGradient)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

private enum AuthPalette {
    static let tagline = Color(hex: "#8A93B2")
    static let createBorder = Color(hex: "#2B3B63")
    static let link = Color(hex: "#6EC8FF")      // portal auth links
}

private let supportEmail = "support@anokix.com"
private let supportSubject = "Support Request – anokiX Trader"

private func openSupportMail() {
    let subject = supportSubject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    if let url = URL(string: "mailto:\(supportEmail)?subject=\(subject)"),
       UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url)
    }
}

// MARK: - Launch screen layout (shared with LaunchScreen.storyboard)

/// Mirrors `LaunchScreen.storyboard`: #000920 background, LogoWhite at 60% width,
/// "Trader App" 18 pt below the logo, vertically centred with a −40 pt offset.
private struct LaunchScreenContent: View {
    var body: some View {
        ZStack {
            Brand.loginBg.ignoresSafeArea()

            GeometryReader { geo in
                VStack(spacing: 16) {
                    Image("LogoWhite")
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width * 0.6)
                    Text("Trader App")
                        .font(.app(18))
                        .foregroundColor(.white)
                }
                .frame(width: geo.size.width)
                .position(x: geo.size.width / 2, y: geo.size.height / 2 - 40)
            }
        }
    }
}

// MARK: - Splash

struct SplashView: View {
    @EnvironmentObject var session: Session

    var body: some View {
        LaunchScreenContent()
            .preferredColorScheme(.dark)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation { session.bootFinished() }
                }
            }
    }
}

/// The anokiX rounded-square logo mark with an "aX" monogram. Still used by the
/// side drawer; the auth screens now use the real LogoWhite artwork instead.
struct BrandMark: View {
    var size: CGFloat = 64
    var body: some View {
        Text("aX")
            .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [Brand.purple, Brand.purpleDark],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .shadow(color: Brand.purple.opacity(0.5), radius: 16, x: 0, y: 8)
    }
}

// MARK: - Welcome

struct WelcomeView: View {
    @EnvironmentObject var session: Session

    var body: some View {
        ZStack {
            Brand.loginBg.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                Image("welcome_storefront")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
                Text("Welcome to anokiX")
                    .font(.app(28, .bold))
                    .foregroundColor(.white)
                    .padding(.top, 22)
                Text("Africa's Commerce, Payments & Merchant Growth Ecosystem")
                    .font(.app(15))
                    .foregroundColor(AuthPalette.tagline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                Spacer()

                VStack(spacing: 16) {
                    Button("Login") { session.stage = .login }
                        .buttonStyle(WelcomeGradientButtonStyle())

                    Button { session.stage = .register } label: {
                        Text("Create Account")
                            .font(.app(16, .bold))
                            .foregroundColor(Brand.success)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .overlay(Capsule().stroke(AuthPalette.createBorder, lineWidth: 1.5))
                    }

                    Button { openSupportMail() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "headphones").foregroundColor(AuthPalette.tagline)
                            Text("Need Help? ").foregroundColor(AuthPalette.tagline)
                                + Text("Support Centre").foregroundColor(AuthPalette.link).bold()
                        }
                        .font(.app(14))
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Login

struct LoginView: View {
    @EnvironmentObject var session: Session
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var emailTab = true
    @State private var toastMsg: String?
    @State private var showReset = false

    var body: some View {
        ZStack {
            Brand.loginBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    Image("LogoWhite")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 190, height: 60)
                        .padding(.top, 56)
                    Text("Welcome back")
                        .font(.app(24, .bold))
                        .foregroundColor(.white)
                        .padding(.top, 22)
                    Text("Sign in to your trader account")
                        .font(.app(14))
                        .foregroundColor(AuthPalette.tagline)
                        .padding(.top, 6)

                    VStack(spacing: 16) {
                        tabs

                        field(title: "Email", text: $email, placeholder: "you@business.co.za",
                              keyboard: .emailAddress)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password").font(.app(13, .medium))
                                .foregroundColor(AuthPalette.tagline)
                            HStack {
                                Group {
                                    if showPassword { TextField("••••••••", text: $password) }
                                    else { SecureField("••••••••", text: $password) }
                                }
                                .foregroundColor(.white)
                                Button { showPassword.toggle() } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(AuthPalette.tagline)
                                }
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                            let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmedEmail.isEmpty || trimmedPassword.isEmpty {
                                toastMsg = "Please enter email and password"
                                return
                            }
                            session.signIn(email: trimmedEmail, password: trimmedPassword)
                        } label: {
                            Text(session.isSigningIn ? "Signing in…" : "Login")
                        }
                        .buttonStyle(WelcomeGradientButtonStyle())
                        .disabled(session.isSigningIn)
                        .padding(.top, 4)

                        Button { showReset = true } label: {
                            Text("Forgot password?")
                                .font(.app(13, .semibold))
                                .foregroundColor(AuthPalette.link)
                        }

                        Button { session.stage = .register } label: {
                            HStack(spacing: 4) {
                                Text("New to anokiX?").foregroundColor(AuthPalette.tagline)
                                Text("Create Account").foregroundColor(AuthPalette.link).fontWeight(.semibold)
                            }
                            .font(.app(13))
                        }
                        .padding(.top, 2)
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                }
            }
            .toast($toastMsg)
        }
        .preferredColorScheme(.dark)   // white status bar text on the dark login
        .fullScreenCover(isPresented: $showReset) {
            ForgotPasswordView(initialEmail: email.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            tabButton("Email", active: emailTab) { emailTab = true }
            tabButton("Phone", active: !emailTab) {
                emailTab = false
                toastMsg = "Phone login coming soon"
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func tabButton(_ title: String, active: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.app(14, .semibold))
                .foregroundColor(active ? .white : AuthPalette.tagline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(active ? Brand.purple : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 9))
        }
    }

    private func field(title: String, text: Binding<String>, placeholder: String,
                       keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.app(13, .medium)).foregroundColor(AuthPalette.tagline)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundColor(.white)
                .padding(14)
                .background(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Forgot / reset password

/// Dedicated "Reset your password" screen (presented over the login screen).
/// Pre-fills the email from login, POSTs it to api/common/forgot-password
/// (portal_type "trader"), then swaps to a neutral "Check your email" confirmation
/// with Resend / Back-to-login actions. Matches the dark auth styling.
struct ForgotPasswordView: View {
    let initialEmail: String
    @Environment(\.dismiss) private var dismiss
    @State private var email: String
    @State private var sending = false
    @State private var sent = false
    @State private var toastMsg: String?

    init(initialEmail: String) {
        self.initialEmail = initialEmail
        _email = State(initialValue: initialEmail)
    }

    var body: some View {
        ZStack {
            Brand.loginBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    Image("LogoWhite")
                        .resizable().scaledToFit()
                        .frame(width: 190, height: 60)
                        .padding(.top, 56)

                    Group { if sent { sentCard } else { formCard } }
                        .padding(24)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 20)
                        .padding(.top, 28)
                }
            }
            .toast($toastMsg)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: form state

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reset your password")
                .font(.app(22, .bold)).foregroundColor(.white)
            Text("Enter your account email and we'll send you a link to reset your password.")
                .font(.app(14)).foregroundColor(AuthPalette.tagline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Email").font(.app(13, .medium)).foregroundColor(AuthPalette.tagline)
                TextField("you@business.co.za", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundColor(.white)
                    .padding(14)
                    .background(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button { submit(firstSend: true) } label: {
                Text(sending ? "Sending…" : "Send reset link")
            }
            .buttonStyle(WelcomeGradientButtonStyle())
            .disabled(sending)
            .padding(.top, 4)

            Button { dismiss() } label: {
                Text("Back to login")
                    .font(.app(14, .medium))
                    .foregroundColor(AuthPalette.link)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 2)
        }
    }

    // MARK: confirmation state

    private var sentCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 72, height: 72)
                .background(Brand.success)
                .clipShape(Circle())

            Text("Check your email")
                .font(.app(22, .bold)).foregroundColor(.white)

            Text("If \(maskedEmail) is registered, we've sent a password reset link to it. Follow the link in the email to set a new password.")
                .font(.app(14)).foregroundColor(AuthPalette.tagline)
                .multilineTextAlignment(.center)

            Button { dismiss() } label: { Text("Back to login") }
                .buttonStyle(WelcomeGradientButtonStyle())
                .padding(.top, 6)

            Button { submit(firstSend: false) } label: {
                Text(sending ? "Sending…" : "Resend link")
                    .font(.app(16, .bold))
                    .foregroundColor(Brand.success)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .overlay(Capsule().stroke(Color(hex: "#2B3B63"), lineWidth: 1.5))
            }
            .disabled(sending)
        }
    }

    // MARK: actions

    private func submit(firstSend: Bool) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            toastMsg = "Please enter your email first"
            return
        }
        sending = true
        Task {
            defer { sending = false }
            do {
                try await APIClient.shared.forgotPassword(email: trimmed)
                sent = true
                if !firstSend { toastMsg = "Reset link sent again." }
            } catch {
                toastMsg = (error as? LocalizedError)?.errorDescription ?? "Couldn't send reset link."
            }
        }
    }

    /// "sipho@business.co.za" → "s•••••@business.co.za" (keeps first char + domain).
    private var maskedEmail: String {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let at = value.firstIndex(of: "@"), at != value.startIndex else { return value }
        let local = value[value.startIndex..<at]
        let domain = value[at...]
        guard local.count > 1 else { return value }
        return String(local.first!) + String(repeating: "•", count: local.count - 1) + domain
    }
}
