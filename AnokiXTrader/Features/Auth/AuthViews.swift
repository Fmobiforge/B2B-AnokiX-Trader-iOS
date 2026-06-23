import SwiftUI
import UIKit

// MARK: - Splash

struct SplashView: View {
    @EnvironmentObject var session: Session
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Brand.loginBg.ignoresSafeArea()
            VStack(spacing: 18) {
                BrandMark(size: 92)
                Text("AnokiX Trader")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                Text("Africa's Commerce, Payments & Merchant Growth Ecosystem")
                    .font(.system(size: 13))
                    .foregroundColor(Brand.purpleTextLt)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { scale = 1; opacity = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation { session.bootFinished() }
            }
        }
    }
}

/// The anokiX rounded-square logo mark with an "aX" monogram.
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
                BrandMark(size: 96)
                Text("Welcome to anokiX")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 24)
                Text("Africa's Commerce, Payments & Merchant Growth Ecosystem")
                    .font(.system(size: 14))
                    .foregroundColor(Brand.purpleTextLt)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 10)
                Spacer()

                VStack(spacing: 14) {
                    Button("Login") { session.stage = .login }
                        .buttonStyle(PrimaryButtonStyle())

                    Button {
                        session.stage = .register
                    } label: {
                        Text("Create Account")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.4), lineWidth: 1))
                    }

                    HStack(spacing: 4) {
                        Text("Need Help?").foregroundColor(Brand.purpleTextLt)
                        Text("Support Centre").foregroundColor(.white).fontWeight(.semibold)
                    }
                    .font(.system(size: 13))
                    .padding(.top, 6)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Login

struct LoginView: View {
    @EnvironmentObject var session: Session
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false

    var body: some View {
        ZStack {
            Brand.loginBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    BrandMark(size: 76).padding(.top, 60)
                    Text("Welcome back")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 20)
                    Text("Sign in to your trader account")
                        .font(.system(size: 14))
                        .foregroundColor(Brand.purpleTextLt)
                        .padding(.top, 6)

                    VStack(spacing: 16) {
                        field(title: "Email", text: $email, placeholder: "you@business.co.za",
                              keyboard: .emailAddress)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password").font(.system(size: 13, weight: .medium))
                                .foregroundColor(Brand.purpleTextLt)
                            HStack {
                                Group {
                                    if showPassword { TextField("••••••••", text: $password) }
                                    else { SecureField("••••••••", text: $password) }
                                }
                                .foregroundColor(.white)
                                Button { showPassword.toggle() } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(Brand.purpleTextLt)
                                }
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button("Sign In") {
                            session.signIn(email: email, password: password)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.top, 4)

                        Text("Forgot password?")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Brand.purpleTextLt)

                        Button {
                            session.stage = .register
                        } label: {
                            HStack(spacing: 4) {
                                Text("New to anokiX?").foregroundColor(Brand.purpleTextLt)
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
        }
    }

    private func field(title: String, text: Binding<String>, placeholder: String,
                       keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(Brand.purpleTextLt)
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
