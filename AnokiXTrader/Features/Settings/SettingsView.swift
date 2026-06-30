import SwiftUI
import UIKit
import MapKit
import UniformTypeIdentifiers

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
                    BusinessProfileEditorView()
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
            PhoneEntryField(title: "Phone number", country: $store.phoneCountry, text: $store.phone)
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

// MARK: - Business Profile editor (7 steps, mirrors Android BusinessProfileActivity)

/// Full Business Profile editor: a tappable stepper over 7 sections, each with its own
/// "Save Changes" that posts only that step's subset to api/trader/business/profile/update.
struct BusinessProfileEditorView: View {
    @StateObject private var store = BusinessEditStore()
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0

    private let stepperTitles = ["Owner", "Business", "Type", "Location", "Verify", "Distributor", "Wallet"]
    private let sectionTitles = [
        "Owner Information", "Business Information", "Trader Classification",
        "Business Location", "Business Verification", "Distributor & Delivery",
        "Merchant Wallet"
    ]
    private let sectionSubtitles = [
        "The registered business owner.", "Your business identity and contact.",
        "What type of trader are you?", "Where is your business located?",
        "Upload or replace your documents.", "Preferred distributors, delivery days and payment.",
        "Powered by IMB."
    ]
    private let walletStep = 6

    var body: some View {
        VStack(spacing: 0) {
            WizardStepper(titles: stepperTitles, current: step) { step = $0 }
            Divider().overlay(Brand.border)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    StepIntro(title: sectionTitles[step], subtitle: sectionSubtitles[step])
                    stepContent
                }
                .padding(16)
            }
            footer
        }
        .background(Brand.surface)
        .navigationTitle("Business Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task { if !store.loaded { await store.load() } }
        .toast($store.toast)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: BizOwnerStep(store: store)
        case 1: BizBusinessStep(store: store)
        case 2: BizTypeStep(store: store)
        case 3: BizLocationStep(store: store)
        case 4: BizVerifyStep(store: store)
        case 5: BizDistributorStep(store: store)
        default: BizWalletStep()
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button { if step == 0 { dismiss() } else { step -= 1 } } label: {
                Text(step == 0 ? "Cancel" : "Back")
                    .font(.system(size: 14, weight: .bold)).foregroundColor(Brand.textPrimary)
                    .padding(.horizontal, 22).frame(height: 46)
                    .overlay(RoundedRectangle(cornerRadius: 23).stroke(Brand.border, lineWidth: 1))
            }
            Spacer()
            if step != walletStep {
                Button { Task { await store.saveStep(step) } } label: {
                    HStack(spacing: 8) {
                        if store.saving { ProgressView().tint(.white) }
                        Text(store.saving ? "Saving…" : "Save Changes")
                            .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    }
                    .padding(.horizontal, 24).frame(height: 46)
                    .background(Brand.purple).clipShape(RoundedRectangle(cornerRadius: 23))
                }
                .disabled(store.saving)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Brand.surface)
        .overlay(Divider().overlay(Brand.border), alignment: .top)
    }
}

// MARK: Business editor — Step 0: Owner

private struct BizOwnerStep: View {
    @ObservedObject var store: BusinessEditStore
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LabeledField(title: "ID Number", text: $store.idNumber, placeholder: "Enter ID number")
            LabeledField(title: "Passport Number", text: $store.passportNumber, placeholder: "Enter passport number")
            Text("Provide either an ID number or a passport number.")
                .font(.system(size: 11)).foregroundColor(Brand.textSecondary)
        }
    }
}

// MARK: Business editor — Step 1: Business (logo + country-code phone)

private struct BizBusinessStep: View {
    @ObservedObject var store: BusinessEditStore
    @State private var logoStage: LogoStage?

    private enum LogoStage: Identifiable {
        case sourcePicker
        case picker(UIImagePickerController.SourceType)
        case crop(UIImage)
        var id: Int {
            switch self {
            case .sourcePicker:  return -2
            case .picker(let t): return t.rawValue
            case .crop:          return -1
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Company Logo").font(.system(size: 13, weight: .medium))
                    .foregroundColor(Brand.textSecondary)
                Button { logoStage = .sourcePicker } label: {
                    ZStack {
                        if let logo = store.logo {
                            Image(uiImage: logo).resizable().scaledToFill()
                        } else if let url = store.existingLogoUrl {
                            RemoteImage(url: MediaUrls.resolve(url))
                        } else {
                            VStack(spacing: 2) {
                                Text("+").font(.system(size: 32, weight: .light)).foregroundColor(Brand.textSecondary)
                                Text("Upload logo").font(.system(size: 12)).foregroundColor(Brand.purple)
                            }
                        }
                    }
                    .frame(width: 140, height: 140)
                    .background(Brand.surfaceVariant)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Brand.border, style: StrokeStyle(lineWidth: 1, dash: [6, 4])))
                }
                .buttonStyle(.plain)
            }
            LabeledField(title: "Business Name", text: $store.businessName, placeholder: "Enter business name")
            LabeledField(title: "Trading Name", text: $store.tradingName, placeholder: "Enter trading name")
            LabeledField(title: "Business Registration Number", text: $store.businessRegNumber,
                         placeholder: "Enter registration number")
            PhoneEntryField(title: "Business Phone", country: $store.businessPhoneCountry,
                            text: $store.businessPhone, placeholder: "Business phone number")
            LabeledField(title: "Business Email", text: $store.businessEmail,
                         placeholder: "Enter business email", keyboard: .emailAddress,
                         autocap: .never, disableAutocorrect: true)
        }
        .sheet(item: $logoStage) { stage in
            switch stage {
            case .sourcePicker:
                ImageSourcePickerSheet(
                    onPhotoLibrary: { logoStage = .picker(.photoLibrary) },
                    onCancel: { logoStage = nil }
                )
                .presentationDetents([.height(ImageSourcePickerSheet.detentHeight(includeFileOption: false))])
                .presentationDragIndicator(.hidden)
            case .picker(let type):
                ImagePicker(sourceType: type, allowsEditing: false) { img in
                    DispatchQueue.main.async { logoStage = .crop(img) }
                }
            case .crop(let img):
                LogoCropSheet(image: img,
                              onConfirm: { store.logo = $0 },
                              onUploadNew: { logoStage = .picker(.photoLibrary) })
            }
        }
    }
}

// MARK: Business editor — Step 2: Type + categories

private struct BizTypeStep: View {
    @ObservedObject var store: BusinessEditStore
    @State private var showCategories = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MenuDropdown(title: "Trader Type", value: store.traderTypeName,
                         placeholder: "Select trader type") {
                ForEach(store.traderTypes) { t in
                    Button(t.name) { store.traderTypeId = t.id }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                DropdownField(title: "Primary Product Categories",
                              value: store.selectedCategoryIds.isEmpty ? "" :
                                "\(store.selectedCategoryIds.count) selected",
                              placeholder: "Select categories") { showCategories = true }
                if !store.selectedCategoryIds.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.parentCategories.filter { store.selectedCategoryIds.contains($0.id) }) { c in
                                RemovableChip(label: c.title) { store.selectedCategoryIds.remove(c.id) }
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCategories) {
            MultiSelectSheet(title: "Product Categories",
                             options: store.parentCategories.map { ($0.id, $0.title) },
                             selected: $store.selectedCategoryIds)
        }
    }
}

// MARK: Business editor — Step 3: Location

private struct BizLocationStep: View {
    @ObservedObject var store: BusinessEditStore
    @State private var query = ""
    @State private var suggestions: [AddressSuggestion] = []
    @State private var searching = false
    @State private var focus: CLLocationCoordinate2D?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Address of your business").font(.system(size: 13, weight: .medium))
                .foregroundColor(Brand.textSecondary)
            HStack {
                TextField("Search for your business address", text: $query)
                    .font(.system(size: 15)).foregroundColor(Brand.textPrimary)
                    .onChange(of: query) { _ in search() }
                if searching { ProgressView() }
            }
            .padding(14).background(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(suggestions) { s in
                        Button { resolve(s) } label: {
                            HStack {
                                Image(systemName: "mappin.circle").foregroundColor(Brand.purple)
                                Text(s.description).font(.system(size: 13)).foregroundColor(Brand.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(.vertical, 10).padding(.horizontal, 12)
                        }
                        Divider()
                    }
                }
                .background(Brand.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
            }

            if !store.address.isEmpty {
                Text(store.address).font(.system(size: 13)).foregroundColor(Brand.textSecondary)
            }

            GoogleMapView(latitude: $store.latitude, longitude: $store.longitude,
                          address: $store.address, focus: $focus)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Text("Tap the map to drop a pin, or drag the pin to set the location.")
                .font(.system(size: 11)).foregroundColor(Brand.textSecondary)
        }
        .onAppear { if query.isEmpty { query = store.address } }
    }

    private func search() {
        guard query.count >= 3, query != store.address else { suggestions = []; return }
        searching = true
        Task {
            let result = (try? await APIClient.shared.addressAutocomplete(query)) ?? []
            await MainActor.run { suggestions = result; searching = false }
        }
    }

    private func resolve(_ s: AddressSuggestion) {
        store.address = s.description
        query = s.description
        suggestions = []
        Task {
            if let coord = try? await APIClient.shared.coordinate(placeId: s.place_id) {
                await MainActor.run {
                    store.latitude = coord.lat
                    store.longitude = coord.lng
                    if let a = coord.resolvedAddress { store.address = a; query = a }
                    if let lat = coord.lat, let lng = coord.lng {
                        focus = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                    }
                }
            }
        }
    }
}

// MARK: Business editor — Step 4: Verify (documents)

private struct BizVerifyStep: View {
    @ObservedObject var store: BusinessEditStore
    @State private var activeField: String?
    @State private var docSheet: DocSheet?
    @State private var showFileImporter = false

    private enum DocSheet: Identifiable {
        case sourcePicker
        case imagePicker(UIImagePickerController.SourceType)
        var id: String {
            switch self {
            case .sourcePicker: return "source"
            case .imagePicker(let t): return "picker-\(t.rawValue)"
            }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(BusinessEditStore.verifyDocs, id: \.field) { row in
                HStack(spacing: 12) {
                    Image(systemName: rowDone(row.field) ? "checkmark.circle.fill" : "doc.fill")
                        .font(.system(size: 18))
                        .foregroundColor(rowDone(row.field) ? Brand.success : Brand.textTertiary)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.label + " *")
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
                        Text(rowSubtitle(row.field))
                            .font(.system(size: 11))
                            .foregroundColor(rowDone(row.field) ? Brand.success : Brand.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        activeField = row.field
                        docSheet = .sourcePicker
                    } label: {
                        Text(rowDone(row.field) ? "Replace" : "Upload")
                            .font(.system(size: 12, weight: .bold)).foregroundColor(Brand.purple)
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Brand.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12).card(padding: 12)
            }
            Text("Accepted formats: JPG, PNG, PDF (Max 5MB). Only changed documents are uploaded.")
                .font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(item: $docSheet) { sheet in
            switch sheet {
            case .sourcePicker:
                ImageSourcePickerSheet(
                    includeFileOption: true,
                    onPhotoLibrary: { docSheet = .imagePicker(.photoLibrary) },
                    onFile: {
                        docSheet = nil
                        DispatchQueue.main.async { showFileImporter = true }
                    },
                    onCancel: { docSheet = nil }
                )
                .presentationDetents([.height(ImageSourcePickerSheet.detentHeight(includeFileOption: true))])
                .presentationDragIndicator(.hidden)
            case .imagePicker(let type):
                ImagePicker(sourceType: type, allowsEditing: false) { img in
                    if let field = activeField,
                       let data = img.downscaledJPEG(maxDimension: 1440, quality: 0.6) {
                        store.documents[field] = RegDocument(fileName: "\(field).jpg",
                                                             mimeType: "image/jpeg", data: data)
                    }
                }
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf]) { result in
            if case .success(let url) = result, let field = activeField {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    store.documents[field] = RegDocument(fileName: url.lastPathComponent,
                                                         mimeType: "application/pdf", data: data)
                }
            }
        }
    }

    private func rowDone(_ field: String) -> Bool {
        store.documents[field] != nil || store.uploadedDocNames[field] != nil
    }

    private func rowSubtitle(_ field: String) -> String {
        if let doc = store.documents[field] { return doc.fileName }
        if let name = store.uploadedDocNames[field] { return "Uploaded: \(name)" }
        return "Not uploaded yet"
    }
}

// MARK: Business editor — Step 5: Distributor / delivery / payment

private struct BizDistributorStep: View {
    @ObservedObject var store: BusinessEditStore
    @State private var showDistributors = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                DropdownField(title: "Preferred Distributors",
                              value: store.selectedDistributorIds.isEmpty ? "" :
                                "\(store.selectedDistributorIds.count) selected",
                              placeholder: "Select distributors") { showDistributors = true }
                if !store.selectedDistributorIds.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.distributors.filter { store.selectedDistributorIds.contains($0.id) }) { d in
                                RemovableChip(label: d.displayName) { store.selectedDistributorIds.remove(d.id) }
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Preferred Delivery Days").font(.system(size: 13, weight: .medium))
                    .foregroundColor(Brand.textSecondary)
                DeliveryHoursGrid(rows: $store.deliveryRows)
                Text("24-hour times (e.g. 8 = 08:00); leave a row blank to default to 8–18. The second pair is an optional split window.")
                    .font(.system(size: 11)).foregroundColor(Brand.textSecondary)
            }

            MenuDropdown(title: "Preferred Payment Method", value: store.paymentLabel,
                         placeholder: "Select payment method") {
                ForEach(RegisterStore.paymentOptions, id: \.code) { opt in
                    Button(opt.label) { store.paymentMethod = opt.code }
                }
            }
        }
        .sheet(isPresented: $showDistributors) {
            MultiSelectSheet(title: "Preferred Distributors",
                             options: store.distributors.map { ($0.id, $0.displayName) },
                             selected: $store.selectedDistributorIds)
        }
    }
}

// MARK: Business editor — Step 6: Wallet (display only)

private struct BizWalletStep: View {
    private let benefits = ["Faster payments", "Access to credit", "Insurance solutions",
                            "Rewards & cashback", "Business growth tools"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(Brand.purple)
                Image(systemName: "wallet.pass.fill").font(.system(size: 40)).foregroundColor(.white)
            }
            .frame(width: 96, height: 96)
            .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: 6) {
                Text("Benefits").font(.system(size: 16, weight: .bold)).foregroundColor(Brand.topTitle)
                ForEach(benefits, id: \.self) { benefit in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18)).foregroundColor(Brand.success)
                        Text(benefit).font(.system(size: 14)).foregroundColor(Brand.textPrimary)
                        Spacer()
                    }
                }
            }

            Text("Wallet activation is coming soon.")
                .font(.system(size: 12)).foregroundColor(Brand.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(Brand.purpleLight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
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
