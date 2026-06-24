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
            RegisterCompletedView { session.stage = .login }
        } else {
            wizard
                .task { await store.loadReference() }
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
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Create Account").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                Text("Join anokiX as a trader").font(.system(size: 12)).foregroundColor(.white.opacity(0.85))
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Brand.purpleDark.ignoresSafeArea(edges: .top))
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button { if step == 0 { session.stage = .welcome } else { step -= 1 } } label: {
                Text("Back")
                    .font(.system(size: 14, weight: .bold))
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
                            .font(.system(size: 14, weight: .bold))
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
                .font(.system(size: 11)).foregroundColor(Brand.textSecondary)

            InfoBox(title: "Account sign-in",
                    text: "Your email address and password will be used to log in to your trader account. Mobile number is required for verification.")

            PhoneField(title: "Mobile Number", text: $store.mobile, placeholder: "Mobile number")
            LabeledField(title: "Email Address", text: $store.email, placeholder: "Enter email address",
                         keyboard: .emailAddress, autocap: .never, disableAutocorrect: true)
            LabeledSecureField(title: "Password", text: $store.password, placeholder: "Enter password")
            LabeledSecureField(title: "Confirm Password", text: $store.confirmPassword, placeholder: "Confirm password")
            Text("Password must be at least 8 characters.")
                .font(.system(size: 11)).foregroundColor(Brand.textSecondary)
        }
    }
}

// MARK: - Phone field (fixed +27 prefix + number) shared by Owner / Business steps

private struct PhoneField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = "Phone number"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Brand.textSecondary)
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("🇿🇦").font(.system(size: 15))
                    Text("+27").font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.textPrimary)
                }
                Rectangle().fill(Brand.border).frame(width: 1, height: 24)
                TextField(placeholder, text: $text)
                    .keyboardType(.phonePad)
                    .font(.system(size: 15))
                    .foregroundColor(Brand.textPrimary)
            }
            .padding(14)
            .background(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Step 2: Business

private struct BusinessStep: View {
    @ObservedObject var store: RegisterStore
    @State private var source: UIImagePickerController.SourceType?
    @State private var showSourceDialog = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Company Logo (Optional)").font(.system(size: 13, weight: .medium))
                    .foregroundColor(Brand.textSecondary)
                Button { showSourceDialog = true } label: {
                    ZStack {
                        if let logo = store.logo {
                            Image(uiImage: logo).resizable().scaledToFill()
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
            PhoneField(title: "Business Phone Number", text: $store.businessPhone,
                       placeholder: "Business phone number")
            LabeledField(title: "Business Email Address", text: $store.businessEmail,
                         placeholder: "Enter business email", keyboard: .emailAddress,
                         autocap: .never, disableAutocorrect: true)
        }
        .confirmationDialog("Choose image source", isPresented: $showSourceDialog, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Camera") { source = .camera }
            }
            Button("Photo Library") { source = .photoLibrary }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: Binding(get: { source.map { SourceWrap(type: $0) } },
                             set: { source = $0?.type })) { wrap in
            ImagePicker(sourceType: wrap.type, allowsEditing: true) { img in store.logo = img }
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
                    .font(.system(size: 16, weight: .bold)).foregroundColor(Brand.topTitle)
                Button { showCategories = true } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        if store.selectedCategoryIds.isEmpty {
                            HStack {
                                Text("Select categories").font(.system(size: 15)).foregroundColor(Brand.textSecondary)
                                Spacer()
                                Image(systemName: "chevron.down").font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Brand.textSecondary)
                            }
                        } else {
                            FlowChips(store.parentCategories.filter { store.selectedCategoryIds.contains($0.id) }
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
                    .font(.system(size: 12))
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

/// Wrapping rows of removable chips (used inside the categories / distributors fields).
private struct FlowChips: View {
    let items: [(Int, String)]
    let onRemove: (Int) -> Void

    init(_ items: [(Int, String)], onRemove: @escaping (Int) -> Void) {
        self.items = items
        self.onRemove = onRemove
    }

    var body: some View {
        // Simple horizontal scroll of chips keeps the layout robust without a custom flow layout.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.0) { id, label in
                    RemovableChip(label: label) { onRemove(id) }
                }
            }
        }
    }
}

// MARK: - Step 4: Location

private struct LocationStep: View {
    @ObservedObject var store: RegisterStore
    @State private var query = ""
    @State private var suggestions: [AddressSuggestion] = []
    @State private var searching = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -33.9249, longitude: 18.4241),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))

    private var pins: [LocationPin] {
        guard let lat = store.latitude, let lng = store.longitude else { return [] }
        return [LocationPin(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))]
    }

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

            Map(coordinateRegion: $region, annotationItems: pins) { pin in
                MapMarker(coordinate: pin.coordinate, tint: Brand.purple)
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Text("Tap the map to drop a pin, or drag the pin to set the location.")
                .font(.system(size: 11)).foregroundColor(Brand.textSecondary)
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
                    if let a = coord.resolvedAddress { store.address = a }
                    if let lat = coord.lat, let lng = coord.lng {
                        region = MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
                    }
                }
            }
        }
    }
}

struct LocationPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Step 5: Documents

private struct DocumentsStep: View {
    @ObservedObject var store: RegisterStore
    @State private var activeField: String?
    @State private var imageSource: UIImagePickerController.SourceType?
    @State private var showDialog = false
    @State private var showFileImporter = false

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
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
                        if let doc = store.documents[row.field] {
                            Text(doc.fileName).font(.system(size: 11)).foregroundColor(Brand.success).lineLimit(1)
                        } else {
                            Text(row.sub).font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                        }
                    }
                    Spacer()
                    Button(store.documents[row.field] != nil ? "Replace" : "Upload") {
                        activeField = row.field
                        showDialog = true
                    }
                    .font(.system(size: 12, weight: .bold)).foregroundColor(Brand.purple)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Brand.border, lineWidth: 1))
                }
                .padding(12).card(padding: 12)
            }
            Text("Accepted formats: JPG, PNG, PDF (Max 5MB)")
                .font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .confirmationDialog("Add document", isPresented: $showDialog, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Camera") { imageSource = .camera }
            }
            Button("Photo Library") { imageSource = .photoLibrary }
            Button("Choose PDF") { showFileImporter = true }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: Binding(get: { imageSource.map { SourceWrap(type: $0) } },
                             set: { imageSource = $0?.type })) { wrap in
            ImagePicker(sourceType: wrap.type, allowsEditing: false) { img in
                if let field = activeField, let data = img.jpegData(compressionQuality: 0.85) {
                    store.documents[field] = RegDocument(fileName: "\(field).jpg",
                                                         mimeType: "image/jpeg", data: data)
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
    @State private var showPayment = false

    static func fullDayName(_ abbr: String) -> String {
        switch abbr {
        case "Mon": return "Monday"
        case "Tue": return "Tuesday"
        case "Wed": return "Wednesday"
        case "Thu": return "Thursday"
        case "Fri": return "Friday"
        case "Sat": return "Saturday"
        default:    return "Sunday"
        }
    }

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
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(RegisterStore.allDays, id: \.self) { day in
                        SelectChip(label: Self.fullDayName(day), selected: store.deliveryDays.contains(day)) {
                            if store.deliveryDays.contains(day) { store.deliveryDays.remove(day) }
                            else { store.deliveryDays.insert(day) }
                        }
                    }
                }
            }

            DropdownField(title: "Preferred Payment Method", value: store.paymentLabel,
                          placeholder: "Select payment method") { showPayment = true }
        }
        .confirmationDialog("Payment Method", isPresented: $showPayment, titleVisibility: .visible) {
            ForEach(RegisterStore.paymentOptions, id: \.code) { opt in
                Button(opt.label) { store.paymentMethod = opt.code }
            }
            Button("Cancel", role: .cancel) {}
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
        }
    }

    private func walletOption(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(selected ? Brand.info : Brand.textTertiary)
                Text(title).font(.system(size: 14)).foregroundColor(Brand.textPrimary)
                Spacer()
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                Text(text).font(.system(size: 14)).foregroundColor(Brand.textPrimary)
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
            Text("Application Submitted!").font(.system(size: 24, weight: .bold))
                .foregroundColor(Brand.textPrimary)
            Text("Your trader account is under review. This usually takes 24–48 hours.")
                .font(.system(size: 14)).foregroundColor(Brand.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 14) {
                Text("What happens next?").font(.system(size: 15, weight: .bold)).foregroundColor(Brand.textPrimary)
                ForEach(Array(steps.enumerated()), id: \.offset) { idx, item in
                    HStack(spacing: 12) {
                        Image(systemName: item.0).foregroundColor(Brand.purple).frame(width: 24)
                        Text(item.1).font(.system(size: 13)).foregroundColor(Brand.textPrimary)
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
