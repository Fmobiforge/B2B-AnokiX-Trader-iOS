import SwiftUI

/// Settings home — a sectioned nav list mirroring the web portal's left rail.
/// Each row drills into a dedicated editor (Profile / Business / Notifications /
/// Security / Preferences). Hosted inside ModuleHost's NavigationStack.
struct SettingsView: View {
    @EnvironmentObject var session: Session
    @StateObject private var store = SettingsStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Manage your account, business and portal preferences.")
                    .font(.system(size: 13)).foregroundColor(Brand.textSecondary)

                profileHeader

                navRow(icon: "person", title: "Profile",
                       subtitle: "Update your personal account information.") {
                    ProfileSettingsView(store: store)
                }
                navRow(icon: "building.2", title: "Business Profile",
                       subtitle: "Company identity, documents and services.") {
                    BusinessSummaryView(store: store)
                }
                navRow(icon: "bell", title: "Notifications",
                       subtitle: "Choose which alerts you want to receive.") {
                    NotificationSettingsView(store: store)
                }
                navRow(icon: "lock", title: "Security",
                       subtitle: "Update your password and account security.") {
                    SecuritySettingsView(store: store)
                }
                navRow(icon: "globe", title: "Preferences",
                       subtitle: "Language, currency and regional settings.") {
                    PreferencesSettingsView(store: store)
                }

                Button("Log Out") { session.signOut() }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 4)
            }
            .padding(16)
        }
        .background(Brand.background)
        .task { if !store.loaded { await store.load() } }
        .toast($store.toast)
    }

    private var profileHeader: some View {
        HStack(spacing: 14) {
            AvatarCircle(initials: store.initials, size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.fullName).font(.system(size: 17, weight: .bold)).foregroundColor(Brand.textPrimary)
                if !store.companyName.isEmpty {
                    Text(store.companyName).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .card()
    }

    private func navRow<Destination: View>(icon: String, title: String, subtitle: String,
                                           @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17)).foregroundColor(Brand.purple)
                    .frame(width: 42, height: 42).background(Brand.purpleLight).clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(Brand.textPrimary)
                    Text(subtitle).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Brand.textTertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Profile

struct ProfileSettingsView: View {
    @ObservedObject var store: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SettingsScreen(title: "Profile Settings",
                       subtitle: "Update your personal account information.") {
            HStack(spacing: 14) {
                AvatarCircle(initials: store.initials, size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.fullName).font(.system(size: 17, weight: .bold)).foregroundColor(Brand.textPrimary)
                    if !store.companyName.isEmpty {
                        Text(store.companyName).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            Divider().padding(.vertical, 4)
            HStack(spacing: 10) {
                LabeledField(title: "First name", text: $store.firstName, autocap: .words)
                LabeledField(title: "Last name", text: $store.lastName, autocap: .words)
            }
            LabeledField(title: "Email address", text: $store.email,
                         keyboard: .emailAddress, autocap: .never, disableAutocorrect: true)
            LabeledField(title: "Phone number", text: $store.phone, keyboard: .phonePad)
            SaveFooter(loading: store.savingProfile,
                       cancel: { dismiss() },
                       save: { await store.saveProfile() })
        }
        .navigationTitle("Profile")
    }
}

// MARK: - Notifications

struct NotificationSettingsView: View {
    @ObservedObject var store: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SettingsScreen(title: "Notification Preferences",
                       subtitle: "Choose which alerts you want to receive.") {
            ForEach(SettingsOptions.toggles) { item in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.system(size: 14, weight: .bold)).foregroundColor(Brand.textPrimary)
                        Text(item.desc).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Toggle("", isOn: Binding(
                        get: { store.toggles[item.key] ?? true },
                        set: { store.toggles[item.key] = $0 }
                    )).labelsHidden().tint(Brand.purple)
                }
                .padding(14)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
            }
            SaveFooter(loading: store.savingNotifications,
                       cancel: { dismiss() },
                       save: { await store.saveNotifications() })
        }
        .navigationTitle("Notifications")
    }
}

// MARK: - Security

struct SecuritySettingsView: View {
    @ObservedObject var store: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SettingsScreen(title: "Security",
                       subtitle: "Update your password and account security.") {
            LabeledSecureField(title: "Current Password", text: $store.currentPassword,
                               placeholder: "Enter current password")
            LabeledSecureField(title: "New Password", text: $store.newPassword,
                               placeholder: "Enter new password")
            LabeledSecureField(title: "Confirm Password", text: $store.confirmPassword,
                               placeholder: "Confirm new password")
            SaveFooter(loading: store.savingPassword,
                       cancel: { dismiss() },
                       save: { await store.changePassword() })
        }
        .navigationTitle("Security")
    }
}

// MARK: - Preferences

struct PreferencesSettingsView: View {
    @ObservedObject var store: SettingsStore
    @Environment(\.dismiss) private var dismiss

    private var timezoneLabel: String {
        store.timezones.first { $0.value == store.timezone }?.label ?? store.timezone
    }

    var body: some View {
        SettingsScreen(title: "Preferences",
                       subtitle: "Configure language, currency and regional settings.") {
            optionMenu("Language", options: SettingsOptions.languages, selection: $store.language)
            optionMenu("Currency", options: SettingsOptions.currencies, selection: $store.currency)
            MenuDropdown(title: "Timezone", value: timezoneLabel) {
                ForEach(store.timezones) { tz in
                    Button(tz.label) { store.timezone = tz.value }
                }
            }
            optionMenu("Date Format", options: SettingsOptions.dateFormats, selection: $store.dateFormat)
            SaveFooter(loading: store.savingPrefs,
                       cancel: { dismiss() },
                       save: { await store.savePreferences() })
        }
        .navigationTitle("Preferences")
    }

    private func optionMenu(_ title: String, options: [SettingsOption],
                            selection: Binding<String>) -> some View {
        let current = options.first { $0.value == selection.wrappedValue }?.label ?? selection.wrappedValue
        return MenuDropdown(title: title, value: current) {
            ForEach(options) { opt in
                Button(opt.label) { selection.wrappedValue = opt.value }
            }
        }
    }
}

// MARK: - Business (read-only summary; full editor is the next milestone)

struct BusinessSummaryView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let b = store.business {
                    VStack(alignment: .leading, spacing: 4) {
                        sectionHeader("Business Information",
                                      "Your business identity on record. Editing is coming soon.")
                        infoRow("Trader Code", b.traderCode)
                        infoRow("Business Name", b.businessName)
                        infoRow("Trading Name", b.tradingName)
                        infoRow("Business Email", b.businessEmail)
                        infoRow("Business Phone", b.businessPhone)
                        infoRow("Registration No.", b.registrationNumber)
                        infoRow("ID Number", b.idNumber)
                        infoRow("Passport Number", b.passportNumber)
                        infoRow("Address", b.address)
                        infoRow("Status", b.status,
                                valueColor: b.status.lowercased() == "active" ? Brand.success : Brand.textPrimary)
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 4) {
                        sectionHeader("Verification Documents", nil)
                        ForEach(b.documents) { group in
                            HStack {
                                Text(group.label).font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                                Spacer(minLength: 10)
                                if group.uploaded, let url = URL(string: group.docs[0].fileURL) {
                                    Link("View uploaded file", destination: url)
                                        .font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.purple)
                                } else {
                                    Text("Not uploaded yet").font(.system(size: 13)).foregroundColor(Brand.textTertiary)
                                }
                            }
                            .padding(.vertical, 7)
                            if group.id != b.documents.last?.id { Divider() }
                        }
                    }
                    .card()
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
            .padding(16)
        }
        .background(Brand.background)
        .navigationTitle("Business Profile")
    }

    private func infoRow(_ label: String, _ value: String, valueColor: Color = Brand.textPrimary) -> some View {
        HStack(alignment: .top) {
            Text(label).font(.system(size: 13)).foregroundColor(Brand.textSecondary)
            Spacer(minLength: 10)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(value.isEmpty ? Brand.textTertiary : valueColor)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 6)
    }

    private func sectionHeader(_ title: String, _ subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(Brand.textPrimary)
            if let subtitle {
                Text(subtitle).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
            }
        }
        .padding(.bottom, 4)
    }
}

// MARK: - Shared building blocks

/// A single-card settings screen: title + subtitle header, then the form content,
/// on the standard background. Used by the four editor screens.
struct SettingsScreen<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 18, weight: .bold)).foregroundColor(Brand.textPrimary)
                    Text(subtitle).font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                }
                .padding(.bottom, 4)
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .padding(16)
        }
        .background(Brand.background)
    }
}

/// Cancel (outlined) + Save Changes (filled) footer, right-aligned.
struct SaveFooter: View {
    let loading: Bool
    let cancel: () -> Void
    let save: () async -> Void

    var body: some View {
        HStack(spacing: 10) {
            Spacer()
            Button("Cancel", action: cancel)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Brand.textPrimary)
                .padding(.horizontal, 18).frame(height: 44)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
            Button {
                Task { await save() }
            } label: {
                HStack(spacing: 8) {
                    if loading { ProgressView().tint(.white) }
                    Text(loading ? "Saving…" : "Save Changes")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18).frame(height: 44)
                .background(Brand.purple).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(loading)
        }
        .padding(.top, 6)
    }
}

/// Purple initials avatar.
struct AvatarCircle: View {
    let initials: String
    var size: CGFloat = 52

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.38, weight: .bold))
            .foregroundColor(Brand.purple)
            .frame(width: size, height: size)
            .background(Brand.purpleLight)
            .clipShape(Circle())
    }
}
