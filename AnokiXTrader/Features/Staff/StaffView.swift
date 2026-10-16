import SwiftUI
import UIKit

/// Staff — GET api/trader/staff, the people the trader has given till access to.
///
/// Each person signs in to the app with their own email and password. From here the
/// trader can add someone, reset their password, and switch their sign-in on or off.
struct StaffView: View {
    @StateObject private var store = StaffStore()

    @State private var showAdd = false
    @State private var passwordFor: StaffMemberDTO?
    @State private var pendingToggle: StaffMemberDTO?
    @State private var toastMsg: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                capabilitiesNote
                header
                content
            }
            .padding(16)
        }
        .background(Brand.background)
        .task { if store.staff.isEmpty { await store.load() } }
        .refreshable { await store.load() }
        // Surface a failed load as a toast, then clear it so it shows only once.
        .onChange(of: store.error) { message in
            guard let message else { return }
            toastMsg = message
            store.error = nil
        }
        .sheet(isPresented: $showAdd) {
            AddStaffSheet { message in
                toastMsg = message
                Task { await store.load() }
            }
        }
        .sheet(item: $passwordFor) { member in
            SetPasswordSheet(member: member) { message, updated in
                toastMsg = message
                Task { await store.merge(updated) }
            }
        }
        .alert(toggleTitle, isPresented: toggleBinding, presenting: pendingToggle) { member in
            Button(member.isActive ? "Disable" : "Enable",
                   role: member.isActive ? ButtonRole.destructive : nil) {
                toggle(member)
            }
            Button("Cancel", role: .cancel) {}
        } message: { member in
            Text(member.isActive
                 ? "They keep their account, but cannot sign in until you enable them again."
                 : "They will be able to sign in and ring up sales straight away.")
        }
        .toast($toastMsg)
    }

    // MARK: Header

    private var capabilitiesNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 17))
                .foregroundColor(Brand.info)
            VStack(alignment: .leading, spacing: 4) {
                Text("What staff can do")
                    .font(.app(14, .semibold))
                    .foregroundColor(Brand.textPrimary)
                Text("Staff can ring up sales, scan products and print receipts. They cannot "
                     + "manage the wallet, order stock or see what the shop earns.")
                    .font(.app(12))
                    .foregroundColor(Brand.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Brand.infoBg.opacity(0.55))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.info.opacity(0.25), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your staff")
                    .font(.app(17, .bold))
                    .foregroundColor(Brand.textPrimary)
                Text(countLine)
                    .font(.app(12))
                    .foregroundColor(Brand.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 10)
            Button { showAdd = true } label: {
                Label("Add staff", systemImage: "person.badge.plus")
                    .font(.app(13, .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Brand.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
            }
            .buttonStyle(.plain)
        }
    }

    private var countLine: String {
        let n = store.staff.count
        if n == 0 { return "Each person signs in with their own email and password." }
        return "\(n) \(n == 1 ? "person" : "people") can sign in to your till"
    }

    // MARK: List

    @ViewBuilder
    private var content: some View {
        if store.loading && store.staff.isEmpty {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 50)
        } else if store.staff.isEmpty {
            emptyState
        } else {
            VStack(spacing: 10) {
                ForEach(store.staff) { member in
                    StaffCard(member: member,
                              onPassword: { passwordFor = member },
                              onToggle: { pendingToggle = member })
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.2")
                .font(.system(size: 40))
                .foregroundColor(Brand.textTertiary)
            Text("No staff yet")
                .font(.app(15, .semibold))
                .foregroundColor(Brand.textPrimary)
            Text("Add the people who work your till so they can sign in and ring up sales.")
                .font(.app(12))
                .foregroundColor(Brand.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .padding(.horizontal, 24)
        .card()
    }

    // MARK: Actions

    private func toggle(_ member: StaffMemberDTO) {
        let status = member.isActive ? "disabled" : "active"
        Task {
            do {
                let result = try await APIClient.shared
                    .updateStaffStatus(staffId: member.id, status: status)
                toastMsg = result.message ?? "Staff member updated."
                await store.merge(result.data.staff)
            } catch {
                toastMsg = (error as? LocalizedError)?.errorDescription
                    ?? "Could not update the staff member."
            }
        }
    }

    private var toggleTitle: String {
        guard let member = pendingToggle else { return "" }
        return member.isActive
            ? "Stop \(member.displayName) signing in?"
            : "Let \(member.displayName) sign in again?"
    }

    private var toggleBinding: Binding<Bool> {
        Binding(get: { pendingToggle != nil }, set: { if !$0 { pendingToggle = nil } })
    }
}

// MARK: - Staff card

private struct StaffCard: View {
    let member: StaffMemberDTO
    let onPassword: () -> Void
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                InitialBadge(text: member.initials, color: Brand.purple, size: 42)
                VStack(alignment: .leading, spacing: 1) {
                    Text(member.displayName)
                        .font(.app(15, .semibold))
                        .foregroundColor(Brand.textPrimary)
                        .lineLimit(1)
                    Text(member.email ?? "")
                        .font(.app(12))
                        .foregroundColor(Brand.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                StatusBadge(text: member.accessLabel,
                            fg: member.accessTone.fg, bg: member.accessTone.bg)
            }

            Text(member.metaLine)
                .font(.app(12))
                .foregroundColor(Brand.textSecondary)
                .lineLimit(1)

            Divider()

            HStack {
                Button(action: onPassword) {
                    Label("Password", systemImage: "key")
                        .font(.app(13, .semibold))
                        .foregroundColor(Brand.textPrimary)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Spacer()

                Button(member.isActive ? "Disable" : "Enable", action: onToggle)
                    .font(.app(13, .semibold))
                    .foregroundColor(member.isActive ? Brand.danger : Brand.success)
                    .padding(.horizontal, 10).padding(.vertical, 9)
                    .buttonStyle(.plain)
            }
        }
        // A disabled member is dimmed the way the portal greys the row out — but the
        // action row stays at full strength so Enable is still obviously tappable.
        .opacity(member.isActive ? 1 : 0.72)
        .card()
    }
}

// MARK: - Add a staff member

private struct AddStaffSheet: View {
    let onAdded: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var jobTitle = ""
    @State private var phone = ""
    @State private var submitting = false
    @State private var errorMsg: String?

    /// The API rejects anything shorter, and the form says so up front.
    private let minPasswordLength = 8

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        SingleLineField(title: "First name", required: true,
                                        text: $firstName, placeholder: "Thabo")
                        SingleLineField(title: "Last name", required: true,
                                        text: $lastName, placeholder: "Nkosi")
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        SingleLineField(title: "Email", required: true, text: $email,
                                        placeholder: "thabo@yourshop.co.za",
                                        keyboard: .emailAddress, autocapitalize: false)
                        Text("They sign in with this.")
                            .font(.app(11))
                            .foregroundColor(Brand.textTertiary)
                    }

                    PasswordField(title: "Password", text: $password,
                                  placeholder: "At least \(minPasswordLength) characters")

                    SingleLineField(title: "Job title (optional)", text: $jobTitle,
                                    placeholder: "Cashier")
                    SingleLineField(title: "Mobile number (optional)", text: $phone,
                                    placeholder: "082 123 4567", keyboard: .phonePad)

                    if let errorMsg {
                        Text(errorMsg)
                            .font(.app(12))
                            .foregroundColor(Brand.danger)
                    }

                    Button(submitting ? "Saving…" : "Add") { submit() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(submitting || !canSubmit)
                        .opacity(submitting || !canSubmit ? 0.6 : 1)
                }
                .padding(20)
            }
            .background(Brand.background)
            .navigationTitle("Add a staff member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private var canSubmit: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
            && !email.trimmingCharacters(in: .whitespaces).isEmpty
            && password.count >= minPasswordLength
    }

    private func submit() {
        let mail = email.trimmingCharacters(in: .whitespaces)
        guard mail.contains("@"), mail.contains(".") else {
            errorMsg = "That does not look like an email address."
            return
        }
        submitting = true
        errorMsg = nil
        Task {
            do {
                let result = try await APIClient.shared.addStaff(
                    firstName: firstName.trimmingCharacters(in: .whitespaces),
                    lastName: lastName.trimmingCharacters(in: .whitespaces),
                    email: mail,
                    password: password,
                    phone: phone.trimmingCharacters(in: .whitespaces),
                    jobTitle: jobTitle.trimmingCharacters(in: .whitespaces))
                dismiss()
                onAdded(result.message ?? "Staff member added.")
            } catch {
                submitting = false
                errorMsg = (error as? LocalizedError)?.errorDescription
                    ?? "Could not add the staff member."
            }
        }
    }
}

// MARK: - Set password

private struct SetPasswordSheet: View {
    let member: StaffMemberDTO
    let onSet: (String, StaffMemberDTO?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var submitting = false
    @State private var errorMsg: String?

    private let minPasswordLength = 8

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        PasswordField(title: "Password", text: $password,
                                      placeholder: "At least \(minPasswordLength) characters")
                        Text("Tell them the new password — they are not emailed.")
                            .font(.app(11))
                            .foregroundColor(Brand.textTertiary)
                    }

                    if let errorMsg {
                        Text(errorMsg)
                            .font(.app(12))
                            .foregroundColor(Brand.danger)
                    }

                    Button(submitting ? "Saving…" : "Set password") { submit() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(submitting || password.count < minPasswordLength)
                        .opacity(submitting || password.count < minPasswordLength ? 0.6 : 1)
                }
                .padding(20)
            }
            .background(Brand.background)
            .navigationTitle("New password for \(member.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private func submit() {
        submitting = true
        errorMsg = nil
        Task {
            do {
                let result = try await APIClient.shared
                    .setStaffPassword(staffId: member.id, password: password)
                dismiss()
                onSet(result.message ?? "Password updated.", result.data.staff)
            } catch {
                submitting = false
                errorMsg = (error as? LocalizedError)?.errorDescription
                    ?? "Could not update the password."
            }
        }
    }
}

// MARK: - Password input

/// Masked input with the show/hide eye the portal uses, styled like `SingleLineField`.
struct PasswordField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    @State private var visible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(text: title, required: true)
            HStack(spacing: 8) {
                Group {
                    if visible {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .font(.app(15))
                .foregroundColor(Brand.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Button { visible.toggle() } label: {
                    Image(systemName: visible ? "eye.slash" : "eye")
                        .font(.system(size: 15))
                        .foregroundColor(Brand.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
