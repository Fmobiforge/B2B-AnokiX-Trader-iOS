import SwiftUI
import UIKit
import MapKit
import UniformTypeIdentifiers

struct RegisterView: View {
    @EnvironmentObject var session: Session
    @StateObject private var store = RegisterStore()

    @State private var step = 0
    @State private var error: String?
    @State private var submitted = false

    /// Short labels shown in the top stepper (mirrors the Android STEP_LABELS).
    private let stepperTitles = [
        "Owner", "Business", "Trader", "Location",
        "Verify", "Distributor", "Wallet", "Terms"
    ]

    /// Navy heading + grey subtitle shown at the top of each step (mirrors Android).
    private let sectionTitles = [
        "Owner Information", "Business Information", "Trader Classification",
        "Business Location", "Business Verification", "Select Preferred Distributor",
        "Activate Merchant Wallet", "Terms & Conditions"
    ]
    private let sectionSubtitles = [
        "Tell us about the business owner.", "Tell us about your business.",
        "What type of trader are you?", "Where is your business located?",
        "Upload the required documents.", "Choose the distributor you want to work with.",
        "Powered by IMB.", "Please review and accept to continue."
    ]

    private let lastStep = 7

    var body: some View {
        if submitted {
            // Light success screen — keep the default (dark) status bar so it stays readable.
            RegisterCompletedView { session.stage = .login }
        } else {
            wizard
                .task { await store.loadReference() }
                // White portal header → dark status-bar icons. SwiftUI couples the status-bar
                // style to the scene's color scheme, and the Welcome screen before this one
                // put the scene in dark, so set it back to light explicitly.
                .environment(\.colorScheme, .light)
                .preferredColorScheme(.light)
        }
    }

    private var wizard: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Brand.border)
            WizardStepper(titles: stepperTitles, current: step)
            Divider().overlay(Brand.border)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    StepIntro(title: sectionTitles[step], subtitle: sectionSubtitles[step])
                    stepContent
                }
                .padding(16)
            }
            .background(Brand.surface)
            footer
        }
        .background(Brand.surface.ignoresSafeArea())
        .alert("Please check", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                if step == 0 { session.stage = .welcome } else { step -= 1 }
            } label: {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Brand.textPrimary)
                    .frame(width: 40, height: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Create Account").font(.app(16, .semibold)).foregroundColor(Brand.textPrimary)
                Text("Join anokiX as a trader").font(.app(12)).foregroundColor(Brand.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 10)
        // Portal page header: white bar (the stepper's divider sits right below it).
        .background(Brand.surface.ignoresSafeArea(edges: .top))
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button { if step == 0 { session.stage = .welcome } else { step -= 1 } } label: {
                Text("Back")
                    .font(.app(14, .bold))
                    .foregroundColor(Brand.textPrimary)
                    .padding(.horizontal, 26)
                    .frame(height: 48)
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Brand.border, lineWidth: 1))
            }
            Spacer()
            Button(action: advance) {
                Group {
                    if store.submitting {
                        ProgressView().tint(.white)
                    } else {
                        Text(step == lastStep ? "Register" : "Continue")
                            .font(.app(14, .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(minWidth: 130)
                .padding(.horizontal, 28)
                .frame(height: 48)
                .background(Brand.purple)
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .disabled(store.submitting)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Brand.surface)
        .overlay(Divider().overlay(Brand.border), alignment: .top)
    }

    private func advance() {
        if let err = store.validate(step: step) { error = err; return }
        if step < lastStep { step += 1; return }
        Task {
            do {
                try await store.submit()
                await MainActor.run { submitted = true }
            } catch {
                let msg = (error as? LocalizedError)?.errorDescription ?? "Submission failed."
                await MainActor.run { self.error = msg }
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: OwnerStep(store: store)
        case 1: BusinessStep(store: store)
        case 2: ClassificationStep(store: store)
        case 3: LocationStep(store: store)
        case 4: DocumentsStep(store: store)
        case 5: DistributorsStep(store: store)
        case 6: WalletStep(store: store)
        default: TermsStep(store: store)
        }
    }
}

// MARK: - Step 1: Owner

private struct OwnerStep: View {
    @ObservedObject var store: RegisterStore
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LabeledField(title: "Owner First Name", text: $store.firstName, placeholder: "Enter first name")
            LabeledField(title: "Owner Last Name", text: $store.lastName, placeholder: "Enter last name")
            LabeledField(title: "ID Number", text: $store.idNumber, placeholder: "Enter ID number")
            LabeledField(title: "Passport Number", text: $store.passportNumber, placeholder: "Enter passport number")
            Text("Provide either your ID number or passport number.")
                .font(.app(11)).foregroundColor(Brand.textSecondary)

            InfoBox(title: "Account sign-in",
                    text: "Your email address and password will be used to log in to your trader account. Mobile number is required for verification.")

            PhoneField(title: "Mobile Number", country: $store.mobileCountry, text: $store.mobile,
                       placeholder: "Mobile number")
            LabeledField(title: "Email Address", text: $store.email, placeholder: "Enter email address",
                         keyboard: .emailAddress, autocap: .never, disableAutocorrect: true)
            LabeledSecureField(title: "Password", text: $store.password, placeholder: "Enter password")
            LabeledSecureField(title: "Confirm Password", text: $store.confirmPassword, placeholder: "Confirm password")
            Text("Password must be at least 8 characters.")
                .font(.app(11)).foregroundColor(Brand.textSecondary)
        }
    }
}

// MARK: - Phone field (country picker + number) shared by Owner / Business steps

private struct PhoneField: View {
    let title: String
    @Binding var country: Country
    @Binding var text: String
    var placeholder: String = "Phone number"
    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.app(13, .medium))
                .foregroundColor(Brand.textSecondary)
            HStack(spacing: 8) {
                Button { showPicker = true } label: {
                    HStack(spacing: 4) {
                        Text(country.flag).font(.app(15))
                        Text(country.dialCode).font(.app(15, .semibold))
                            .foregroundColor(Brand.textPrimary)
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Brand.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                Rectangle().fill(Brand.border).frame(width: 1, height: 24)
                TextField(placeholder, text: $text)
                    .keyboardType(.phonePad)
                    .font(.app(15))
                    .foregroundColor(Brand.textPrimary)
            }
            .padding(14)
            .background(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .sheet(isPresented: $showPicker) {
            CountryPickerSheet(selection: $country)
        }
    }
}

// MARK: - Step 2: Business

private struct BusinessStep: View {
    @ObservedObject var store: RegisterStore
    @State private var logoStage: LogoStage?

    /// Single modal driving the logo flow: source picker → library/camera → crop.
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
                Text("Company Logo (Optional)").font(.app(13, .medium))
                    .foregroundColor(Brand.textSecondary)
                Button { logoStage = .sourcePicker } label: {
                    ZStack {
                        if let logo = store.logo {
                            Image(uiImage: logo).resizable().scaledToFill()
                        } else {
                            VStack(spacing: 2) {
                                Text("+").font(.app(32, .light)).foregroundColor(Brand.textSecondary)
                                Text("Upload logo").font(.app(12)).foregroundColor(Brand.purple)
                            }
                        }
                    }
                    .frame(width: 140, height: 140)
                    .background(Brand.surfaceVariant)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Brand.border, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    )
                }
                .buttonStyle(.plain)
            }
            LabeledField(title: "Business Name", text: $store.businessName, placeholder: "Enter business name")
            LabeledField(title: "Trading Name", text: $store.tradingName, placeholder: "Enter trading name")
            LabeledField(title: "Business Registration Number (Optional)", text: $store.businessRegNumber,
                         placeholder: "Enter registration number")
            PhoneField(title: "Business Phone Number", country: $store.businessPhoneCountry,
                       text: $store.businessPhone, placeholder: "Business phone number")
            LabeledField(title: "Business Email Address", text: $store.businessEmail,
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
                // Pick raw (no system crop) → our own scale/rotate cropper. Defer so the
                // picker sheet finishes dismissing before the crop sheet presents.
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

/// Identifiable wrapper so a UIImagePickerController.SourceType can drive `.sheet(item:)`.
struct SourceWrap: Identifiable {
    let type: UIImagePickerController.SourceType
    var id: Int { type.rawValue }
}

// MARK: - Step 3: Classification

private struct ClassificationStep: View {
    @ObservedObject var store: RegisterStore
    @State private var showCategories = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(store.traderTypes) { type in
                    TraderTypeCard(name: type.name, selected: store.traderTypeId == type.id) {
                        store.traderTypeId = type.id
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Primary Product Categories")
                    .font(.app(16, .bold)).foregroundColor(Brand.topTitle)
                Button { showCategories = true } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        if store.selectedCategoryIds.isEmpty {
                            HStack {
                                Text("Select categories").font(.app(15)).foregroundColor(Brand.textSecondary)
                                Spacer()
                                Image(systemName: "chevron.down").font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Brand.textSecondary)
                            }
                        } else {
                            HorizontalRemovableChips(store.parentCategories.filter { store.selectedCategoryIds.contains($0.id) }
                                .map { c in (c.id, c.title) }) { id in store.selectedCategoryIds.remove(id) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .frame(minHeight: 52)
                    .background(Brand.surface)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showCategories) {
            MultiSelectSheet(title: "Product Categories",
                             options: store.parentCategories.map { ($0.id, $0.title) },
                             selected: $store.selectedCategoryIds)
        }
    }
}

/// Selectable trader-classification card (store icon + name), 3 per row.
private struct TraderTypeCard: View {
    let name: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 22))
                    .foregroundColor(selected ? Brand.purple : Brand.textSecondary)
                Text(name)
                    .font(.app(12))
                    .foregroundColor(selected ? Brand.purple : Brand.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .padding(.vertical, 14).padding(.horizontal, 8)
            .background(selected ? Brand.purpleLight : Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(selected ? Brand.purple : Brand.border, lineWidth: selected ? 1.5 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 4: Location

private struct LocationStep: View {
    @ObservedObject var store: RegisterStore
    @State private var query = ""
    @State private var suggestions: [AddressSuggestion] = []
    @State private var searching = false
    @State private var focus: CLLocationCoordinate2D?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Address of your business").font(.app(13, .medium))
                .foregroundColor(Brand.textSecondary)
            HStack {
                TextField("Search for your business address", text: $query)
                    .font(.app(15)).foregroundColor(Brand.textPrimary)
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
                                Text(s.description).font(.app(13)).foregroundColor(Brand.textPrimary)
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
                Text(store.address).font(.app(13)).foregroundColor(Brand.textSecondary)
            }

            GoogleMapView(latitude: $store.latitude, longitude: $store.longitude,
                          address: $store.address, focus: $focus)
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Text("Tap the map to drop a pin, or drag the pin to set the location.")
                .font(.app(11)).foregroundColor(Brand.textSecondary)
        }
    }

    private func search() {
        guard query.count >= 3 else { suggestions = []; return }
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
                    store.placeId = s.place_id
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

// MARK: - Step 5: Documents

private struct DocumentsStep: View {
    @ObservedObject var store: RegisterStore
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

    private var rows: [(field: String, label: String, sub: String, required: Bool)] {
        RegisterStore.requiredDocs.map { ($0.field, $0.label, $0.sub, true) }
            + [("additional_documents", "Additional Documents", "(If any)", false)]
    }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(rows, id: \.field) { row in
                HStack(spacing: 12) {
                    Image(systemName: store.documents[row.field] != nil ? "checkmark.circle.fill" : "doc.fill")
                        .font(.system(size: 18))
                        .foregroundColor(store.documents[row.field] != nil ? Brand.success : Brand.textTertiary)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.label + (row.required ? " *" : ""))
                            .font(.app(14, .semibold)).foregroundColor(Brand.textPrimary)
                        if let doc = store.documents[row.field] {
                            Text(doc.fileName).font(.app(11)).foregroundColor(Brand.success).lineLimit(1)
                        } else {
                            Text(row.sub).font(.app(11)).foregroundColor(Brand.textSecondary)
                        }
                    }
                    Spacer()
                    Button {
                        activeField = row.field
                        docSheet = .sourcePicker
                    } label: {
                        Text(store.documents[row.field] != nil ? "Replace" : "Upload")
                            .font(.app(12, .bold)).foregroundColor(Brand.purple)
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Brand.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12).card(padding: 12)
            }
            Text("Accepted formats: JPG, PNG, PDF (Max 5MB)")
                .font(.app(11)).foregroundColor(Brand.textSecondary)
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
}

// MARK: - Step 6: Distributors / delivery / payment

private struct DistributorsStep: View {
    @ObservedObject var store: RegisterStore
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
                Text("Preferred Delivery Days").font(.app(13, .medium))
                    .foregroundColor(Brand.textSecondary)
                DeliveryHoursGrid(rows: $store.deliveryRows)
                Text("24-hour times (e.g. 8 = 08:00); leave a row blank to default to 8–18. The second pair is an optional split window.")
                    .font(.app(11)).foregroundColor(Brand.textSecondary)
            }

            SelectField(title: "Preferred Payment Method", placeholder: "Select payment method",
                        options: RegisterStore.paymentOptions.map { ($0.code, $0.label) },
                        selection: $store.paymentMethod)
        }
        .sheet(isPresented: $showDistributors) {
            MultiSelectSheet(title: "Preferred Distributors",
                             options: store.distributors.map { ($0.id, $0.displayName) },
                             selected: $store.selectedDistributorIds)
        }
    }
}

// MARK: - Step 7: Wallet

private struct WalletStep: View {
    @ObservedObject var store: RegisterStore

    private let benefits = ["Faster payments", "Access to credit", "Insurance solutions",
                            "Rewards & cashback", "Business growth tools"]

    private var idNumberLabel: String {
        switch store.walletIdType {
        case "passport": return "Passport Number"
        case "asylum":   return "Asylum Document Number"
        default:          return "SA ID Number"
        }
    }
    private var idNumberPlaceholder: String {
        store.walletIdType == "ID" ? "13-digit ID number" : "Document number"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Wallet tile
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(Brand.purple)
                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 40)).foregroundColor(.white)
            }
            .frame(width: 96, height: 96)
            .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: 6) {
                Text("Benefits").font(.app(16, .bold)).foregroundColor(Brand.topTitle)
                ForEach(benefits, id: \.self) { benefit in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18)).foregroundColor(Brand.success)
                        Text(benefit).font(.app(14)).foregroundColor(Brand.textPrimary)
                        Spacer()
                    }
                }
            }

            VStack(spacing: 0) {
                walletOption(title: "Create Wallet Now", selected: store.createWallet) {
                    store.createWallet = true
                }
                walletOption(title: "Activate Later", selected: !store.createWallet) {
                    store.createWallet = false
                }
            }
            .padding(6)
            .background(Brand.surfaceVariant)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Identity + residential address — only when creating the wallet now.
            if store.createWallet {
                walletInfoPanel
            }
        }
    }

    private var walletInfoPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            ownerNotice
            identitySection
            addressSection
            accessSection
        }
    }

    private var ownerNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 15)).foregroundColor(Brand.purple)
            Text("Your bank account is opened in the owner's name, so IMB needs to verify their identity and residential address. This is separate from your business address.")
                .font(.app(12)).foregroundColor(Brand.purpleDark)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Brand.purpleLight)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Owner Identity")
                .font(.app(15, .bold)).foregroundColor(Brand.topTitle)

            SelectField(title: "ID Type", placeholder: "Select ID type",
                        options: RegisterStore.idTypeOptions.map { ($0.code, $0.label) },
                        selection: $store.walletIdType)

            VStack(alignment: .leading, spacing: 6) {
                LabeledField(title: idNumberLabel, text: $store.walletIdNumber,
                             placeholder: idNumberPlaceholder,
                             keyboard: store.walletIdType == "ID" ? .numberPad : .default,
                             autocap: .never,
                             disableAutocorrect: true)
                    .onChange(of: store.walletIdNumber) { newValue in
                        if store.walletIdType == "ID" {
                            let digits = String(newValue.filter { $0.isNumber }.prefix(13))
                            if digits != newValue { store.walletIdNumber = digits }
                        }
                    }
                saIdFeedback
            }

            if store.walletIdType == "passport" {
                VStack(alignment: .leading, spacing: 6) {
                    LabeledField(title: "Passport Country", text: $store.walletPassportCountry,
                                 placeholder: "e.g. ZA", autocap: .characters, disableAutocorrect: true)
                        .onChange(of: store.walletPassportCountry) { v in
                            let capped = String(v.uppercased().prefix(2))
                            if capped != v { store.walletPassportCountry = capped }
                        }
                    Text("Two-letter country code.")
                        .font(.app(11)).foregroundColor(Brand.textSecondary)
                }
                DatePickerField(title: "Passport Expiry Date", date: $store.walletPassportExpDate)
            }

            if store.walletIdType == "ID" {
                ReadOnlyField(title: "Date of Birth",
                              value: store.effectiveDob.map { Self.displayDate.string(from: $0) } ?? "",
                              placeholder: "Read from ID")
                ReadOnlyField(title: "Gender", value: store.effectiveGender, placeholder: "Read from ID")
            } else {
                DatePickerField(title: "Date of Birth", date: $store.walletDob)
                SelectField(title: "Gender", placeholder: "Select gender",
                            options: RegisterStore.genderOptions.map { ($0, $0) },
                            selection: $store.walletGenderManual)
            }
        }
    }

    private var addressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Residential Address")
                .font(.app(15, .bold)).foregroundColor(Brand.topTitle)
                .padding(.top, 4)
            LabeledField(title: "Street Address", text: $store.walletStreet, placeholder: "17 New Haven Ave")
            LabeledField(title: "Suburb", text: $store.walletSuburb, placeholder: "Bethesda")
            LabeledField(title: "City", text: $store.walletCity, placeholder: "Cape Town")
            SelectField(title: "Province", placeholder: "Select province",
                        options: RegisterStore.provinceOptions.map { ($0.code, $0.label) },
                        selection: $store.walletProvinceCode)
            LabeledField(title: "Postal Code", text: $store.walletPostCode, placeholder: "8001", keyboard: .numberPad)
        }
    }

    private var accessSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Wallet Access")
                .font(.app(15, .bold)).foregroundColor(Brand.topTitle)
                .padding(.top, 4)
            accessTile(title: "USSD access",
                       subtitle: "Check balances and transact from any phone, no data needed.",
                       on: store.walletUssd) { store.walletUssd.toggle() }
            accessTile(title: "Online & app access",
                       subtitle: "Use the anokiX app and web portal.",
                       on: store.walletInternet) { store.walletInternet.toggle() }
            accessTile(title: "Cross-border payments",
                       subtitle: "Send and receive outside South Africa.",
                       on: store.walletCrossBorder) { store.walletCrossBorder.toggle() }
        }
    }

    /// Red error / green "read from ID" feedback under the SA-ID field.
    @ViewBuilder
    private var saIdFeedback: some View {
        if store.walletIdType == "ID" {
            switch store.saIdStatus() {
            case .invalidLength:
                feedback("A South African ID number must be 13 digits.", color: Brand.danger, icon: nil)
            case .invalidDate:
                feedback("The first six digits of the ID number are not a valid date.", color: Brand.danger, icon: nil)
            case .invalidChecksum:
                feedback("This ID number is not valid.", color: Brand.danger, icon: nil)
            case .valid:
                feedback("Date of birth and gender read from your ID number.",
                         color: Brand.success, icon: "checkmark.circle.fill")
            case .empty:
                EmptyView()
            }
        }
    }

    private func feedback(_ text: String, color: Color, icon: String?) -> some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 11)).foregroundColor(color) }
            Text(text).font(.app(11)).foregroundColor(color)
        }
    }

    private func accessTile(title: String, subtitle: String, on: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: on ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundColor(on ? Brand.purple : Brand.textTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.app(14, .bold)).foregroundColor(Brand.textPrimary)
                    Text(subtitle).font(.app(12)).foregroundColor(Brand.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(on ? Brand.purpleLight : Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(on ? Brand.purple.opacity(0.4) : Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func walletOption(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(selected ? Brand.info : Brand.textTertiary)
                Text(title).font(.app(14)).foregroundColor(Brand.textPrimary)
                Spacer()
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    static let displayDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MM/dd/yyyy"
        return f
    }()
}

// MARK: - Read-only display field (derived DOB / gender for SA ID)

private struct ReadOnlyField: View {
    let title: String
    let value: String
    var placeholder: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.app(13, .medium)).foregroundColor(Brand.textSecondary)
            Text(value.isEmpty ? placeholder : value)
                .font(.app(15))
                .foregroundColor(value.isEmpty ? Brand.textTertiary : Brand.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Brand.surfaceVariant)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Date field (tappable, opens a graphical DatePicker sheet)

private struct DatePickerField: View {
    let title: String
    @Binding var date: Date?
    var placeholder: String = "Select date"
    @State private var showing = false
    @State private var temp = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.app(13, .medium)).foregroundColor(Brand.textSecondary)
            Button {
                temp = date ?? Date()
                showing = true
            } label: {
                HStack(spacing: 8) {
                    Text(date.map { WalletStep.displayDate.string(from: $0) } ?? placeholder)
                        .font(.app(15))
                        .foregroundColor(date == nil ? Brand.textTertiary : Brand.textPrimary)
                    Spacer(minLength: 8)
                    Image(systemName: "calendar").foregroundColor(Brand.textSecondary)
                }
                .padding(14)
                .background(Brand.surface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showing) {
            NavigationStack {
                DatePicker("", selection: $temp, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding()
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) { Button("Cancel") { showing = false } }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { date = temp; showing = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .preferredColorScheme(.light)
        }
    }
}

// MARK: - Step 8: Terms

private struct TermsStep: View {
    @ObservedObject var store: RegisterStore
    var body: some View {
        VStack(spacing: 12) {
            term("I confirm that the information provided is accurate and correct.", $store.termAccurate)
            term("I agree to the Terms of Service and Privacy Policy.", $store.termTos)
            term("I agree to KYC verification and identity checks.", $store.termKyc)
            term("I consent to receive electronic communications from anokiX.", $store.termComms)
        }
    }

    private func term(_ text: String, _ binding: Binding<Bool>) -> some View {
        Button { binding.wrappedValue.toggle() } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: binding.wrappedValue ? "checkmark.square.fill" : "square")
                    .foregroundColor(binding.wrappedValue ? Brand.purple : Brand.textTertiary)
                Text(text).font(.app(14)).foregroundColor(Brand.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(12).card(padding: 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Multi-select sheet

struct MultiSelectSheet: View {
    let title: String
    let options: [(Int, String)]
    @Binding var selected: Set<Int>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(options, id: \.0) { id, label in
                    Button {
                        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
                    } label: {
                        HStack {
                            Text(label).foregroundColor(Brand.textPrimary)
                            Spacer()
                            if selected.contains(id) {
                                Image(systemName: "checkmark").foregroundColor(Brand.purple)
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.light)   // always render clear/light, even in Dark Mode
    }
}

// MARK: - Completed screen

struct RegisterCompletedView: View {
    let onBackToLogin: () -> Void

    private let steps = [
        ("doc.text", "We review your documents"),
        ("checkmark.shield", "KYC verification"),
        ("person.2", "Distributor approval"),
        ("wallet.pass", "Wallet activation")
    ]

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80)).foregroundColor(Brand.success)
            Text("Application Submitted!").font(.app(24, .bold))
                .foregroundColor(Brand.textPrimary)
            Text("Your trader account is under review. This usually takes 24–48 hours.")
                .font(.app(14)).foregroundColor(Brand.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 14) {
                Text("What happens next?").font(.app(15, .bold)).foregroundColor(Brand.textPrimary)
                ForEach(Array(steps.enumerated()), id: \.offset) { idx, item in
                    HStack(spacing: 12) {
                        Image(systemName: item.0).foregroundColor(Brand.purple).frame(width: 24)
                        Text(item.1).font(.app(13)).foregroundColor(Brand.textPrimary)
                        Spacer()
                    }
                }
            }
            .padding(16).card()
            .padding(.horizontal, 24)

            Spacer()
            Button("Back to Login", action: onBackToLogin)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24).padding(.bottom, 24)
        }
        .background(Brand.background.ignoresSafeArea())
    }
}
