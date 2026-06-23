import SwiftUI
import UIKit

// MARK: - Shared welcome/login chrome (mirrors the Distributor iOS app)

/// Blue → indigo → purple pill, matching the Distributor's `GradientButton`
/// (bg_welcome_login_gradient).
struct WelcomeGradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(colors: [Color(hex: "#3B82F6"), Color(hex: "#6366F1"), Color(hex: "#A855F7")],
                               startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

private enum AuthPalette {
    static let tagline = Color(hex: "#8A93B2")
    static let createBorder = Color(hex: "#2B3B63")
    static let link = Color(hex: "#5B8DEF")
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
                        .font(.system(size: 18))
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
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 22)
                Text("Africa's Commerce, Payments & Merchant Growth Ecosystem")
                    .font(.system(size: 15))
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
                            .font(.system(size: 16, weight: .bold))
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
                        .font(.system(size: 14))
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
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 22)
                    Text("Sign in to your trader account")
                        .font(.system(size: 14))
                        .foregroundColor(AuthPalette.tagline)
                        .padding(.top, 6)

                    VStack(spacing: 16) {
                        tabs

                        field(title: "Email", text: $email, placeholder: "you@business.co.za",
                              keyboard: .emailAddress)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password").font(.system(size: 13, weight: .medium))
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

                        Button { toastMsg = "Password reset coming soon" } label: {
                            Text("Forgot password?")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AuthPalette.tagline)
                        }

                        Button { session.stage = .register } label: {
                            HStack(spacing: 4) {
                                Text("New to anokiX?").foregroundColor(AuthPalette.tagline)
                                Text("Create Account").foregroundColor(.white).fontWeight(.semibold)
                            }
                            .font(.system(size: 13))
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
                .font(.system(size: 14, weight: .semibold))
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
            Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(AuthPalette.tagline)
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
