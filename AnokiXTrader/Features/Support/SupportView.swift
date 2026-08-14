import SwiftUI
import UIKit

/// Support Centre — GET api/common/support/overview, which returns the channels this
/// merchant may use, the help-article taxonomy and their own tickets.
///
/// From here they can search help articles, open WhatsApp, ask for a call back or write
/// a ticket; tapping a ticket opens the conversation. The System Health and Knowledge
/// Base blocks the web portal shows are deliberately left out — they are not wired to
/// anything yet.
struct SupportView: View {
    @StateObject private var store = SupportStore()
    @Environment(\.openURL) private var openURL

    @State private var request: SupportRequestKind?
    @State private var openTicketId: Int?
    @State private var toastMsg: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                searchBar
                channelCards
                articlesSection
                ticketsSection
            }
            .padding(16)
        }
        .background(Brand.background)
        .task {
            if store.channels == nil { await store.load() }
            await store.loadDistributors()
        }
        .refreshable { await store.load() }
        // Surface a failed load/search as a toast, then clear it so it shows only once.
        .onChange(of: store.error) { message in
            guard let message else { return }
            toastMsg = message
            store.error = nil
        }
        .sheet(item: $request) { kind in
            SupportRequestSheet(kind: kind,
                                categories: store.categories,
                                distributors: store.distributors) { message in
                toastMsg = message
                Task { await store.load() }
            }
        }
        .sheet(item: ticketBinding) { route in
            TicketDetailView(ticketId: route.id) {
                Task { await store.load() }
            }
        }
        .toast($toastMsg)
    }

    // MARK: Search

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(Brand.textSecondary)
                TextField("Search for help articles, topics or keywords…", text: $store.search)
                    .font(.system(size: 14))
                    .foregroundColor(Brand.textPrimary)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { Task { await store.runSearch() } }
                if !store.search.isEmpty {
                    Button {
                        store.search = ""
                        Task { await store.runSearch() }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Brand.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button("Search") { Task { await store.runSearch() } }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .frame(height: 46)
                .background(Brand.purple)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .buttonStyle(.plain)
        }
    }

    // MARK: Channels

    @ViewBuilder
    private var channelCards: some View {
        if let channels = store.channels, store.hasAnyChannel {
            VStack(spacing: 8) {
                if channels.whatsappEnabled, let whatsapp = channels.whatsapp {
                    let number = whatsapp.display.flatMap { $0.isEmpty ? nil : $0 }
                    ChannelCard(icon: "message.fill", tint: Brand.success, tile: Brand.successBg,
                                title: "WhatsApp Support",
                                subtitle: number ?? "Chat to us on WhatsApp") {
                        openWhatsApp(whatsapp)
                    }
                }
                if channels.callbackEnabled {
                    ChannelCard(icon: "phone.fill", tint: Brand.info, tile: Brand.infoBg,
                                title: "Call Back Request",
                                subtitle: "Leave a number and we'll ring you") {
                        request = .callback
                    }
                }
                if channels.ticketsEnabled {
                    ChannelCard(icon: "doc.text.fill", tint: Brand.purple, tile: Brand.purpleLight,
                                title: "Create Ticket",
                                subtitle: "Submit a support request") {
                        request = .ticket
                    }
                }
                if channels.phoneEnabled, let number = channels.phone?.number {
                    ChannelCard(icon: "headphones", tint: Brand.warning, tile: Brand.warningBg,
                                title: "Call Us", subtitle: number) {
                        dial(number)
                    }
                }
                if channels.emailEnabled, let address = channels.email?.address {
                    ChannelCard(icon: "envelope.fill", tint: Brand.textSecondary,
                                tile: Brand.surfaceVariant, title: "Email Us", subtitle: address) {
                        open("mailto:\(address)")
                    }
                }
            }

            if let hours = store.channels?.hours, !hours.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(hours)
                    .font(.system(size: 11))
                    .foregroundColor(Brand.textSecondary)
            }
        } else if store.loading {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
        } else {
            Text("Support channels are being set up. Please check back soon.")
                .font(.system(size: 12))
                .foregroundColor(Brand.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .card()
        }
    }

    // MARK: Articles

    private var articlesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.activeQuery == nil ? "Popular Topics" : "Search")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Brand.textPrimary)

            if store.articles.isEmpty {
                Text(store.activeQuery.map { "No help articles matched “\($0)”." }
                     ?? "Help articles are on their way.")
                    .font(.system(size: 12))
                    .foregroundColor(Brand.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                    .card()
            } else {
                VStack(spacing: 8) {
                    ForEach(store.articles) { article in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 14))
                                .foregroundColor(Brand.textSecondary)
                                .padding(.top, 1)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(article.title ?? "—")
                                    .font(.system(size: 13))
                                    .foregroundColor(Brand.textPrimary)
                                if let excerpt = article.excerpt, !excerpt.isEmpty {
                                    Text(excerpt)
                                        .font(.system(size: 11))
                                        .foregroundColor(Brand.textSecondary)
                                        .lineLimit(2)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .card()
                    }
                }
            }
        }
    }

    // MARK: Tickets

    private var ticketsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("My Support Tickets")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Brand.textPrimary)
                Spacer()
                Button("New ticket") { request = .ticket }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Brand.purple)
            }

            if store.tickets.isEmpty {
                Text("You have not opened any tickets yet.")
                    .font(.system(size: 12))
                    .foregroundColor(Brand.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                    .card()
            } else {
                VStack(spacing: 8) {
                    ForEach(store.tickets) { ticket in
                        Button { openTicketId = ticket.id } label: {
                            TicketRow(ticket: ticket)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: External apps

    /// Open the chat directly in WhatsApp. The server sends a ready-made wa.me link with
    /// the greeting pre-filled; the native scheme is tried first so the app opens rather
    /// than Safari, falling back to the universal link when WhatsApp is not installed.
    private func openWhatsApp(_ whatsapp: SupportWhatsApp) {
        var link = whatsapp.link ?? ""
        if link.isEmpty, let msisdn = whatsapp.msisdn {
            link = "https://wa.me/" + msisdn
        }
        guard !link.isEmpty else {
            toastMsg = "WhatsApp is not set up for this account."
            return
        }
        if let scheme = whatsappScheme(from: link), UIApplication.shared.canOpenURL(scheme) {
            UIApplication.shared.open(scheme)
            return
        }
        open(link, failure: "WhatsApp is not installed on this device.")
    }

    /// "https://wa.me/<number>?text=…" → "whatsapp://send?phone=<number>&text=…".
    private func whatsappScheme(from link: String) -> URL? {
        guard let components = URLComponents(string: link) else { return nil }
        // wa.me carries the number in the path; api.whatsapp.com/send carries it in ?phone=.
        let fromPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let fromQuery = components.queryItems?.first(where: { $0.name == "phone" })?.value
        let phone = fromPath.isEmpty ? fromQuery : fromPath
        guard let phone, !phone.isEmpty else { return nil }

        var scheme = URLComponents()
        scheme.scheme = "whatsapp"
        scheme.host = "send"
        var items = [URLQueryItem(name: "phone", value: phone)]
        if let text = components.queryItems?.first(where: { $0.name == "text" })?.value {
            items.append(URLQueryItem(name: "text", value: text))
        }
        scheme.queryItems = items
        return scheme.url
    }

    private func dial(_ number: String) {
        let digits = number.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty else { return }
        open("tel:" + digits)
    }

    private func open(_ string: String, failure: String? = nil) {
        guard let url = URL(string: string), UIApplication.shared.canOpenURL(url) else {
            if let failure { toastMsg = failure }
            return
        }
        openURL(url)
    }

    /// `.sheet(item:)` needs an Identifiable; wrap the plain ticket id.
    private var ticketBinding: Binding<TicketRoute?> {
        Binding(get: { openTicketId.map(TicketRoute.init) },
                set: { openTicketId = $0?.id })
    }
}

private struct TicketRoute: Identifiable {
    let id: Int
}

// MARK: - Rows

private struct ChannelCard: View {
    let icon: String
    let tint: Color
    let tile: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 40, height: 40)
                    .background(tile)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Brand.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Brand.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(Brand.textTertiary)
            }
            .contentShape(Rectangle())
            .card()
        }
        .buttonStyle(.plain)
    }
}

private struct TicketRow: View {
    let ticket: SupportTicketDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(ticket.ticket_number ?? "—")
                    .font(.system(size: 11))
                    .foregroundColor(Brand.textSecondary)
                StatusBadge(text: ticket.statusLabel,
                            fg: ticket.statusTone.fg, bg: ticket.statusTone.bg)
                Spacer(minLength: 8)
                Text(SupportFmt.shortDateTime(ticket.created_at))
                    .font(.system(size: 11))
                    .foregroundColor(Brand.textTertiary)
            }
            Text(ticket.subject ?? "—")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Brand.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            Text(ticket.waitingLabel)
                .font(.system(size: 12))
                .foregroundColor(Brand.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .card()
    }
}

// MARK: - Request sheets

/// The two ways of opening a ticket. Both POST to .../support/tickets; only the
/// channel and its extra field differ.
enum SupportRequestKind: String, Identifiable {
    case callback, ticket

    var id: String { rawValue }

    var title: String {
        self == .callback ? "Request a call back" : "Tell us what's wrong"
    }

    var submitTitle: String {
        self == .callback ? "Request call" : "Send request"
    }
}

private struct SupportRequestSheet: View {
    let kind: SupportRequestKind
    let categories: [SupportCategoryDTO]
    /// Offered alongside anokiX Support in "Who should answer this?".
    let distributors: [TraderDistributorDTO]
    let onSubmitted: (String) -> Void

    /// Sentinel for the anokiX Support option — an empty id means no distributor_id
    /// is sent, which is how the API routes a ticket to anokiX.
    private static let anokixOption = ""

    @Environment(\.dismiss) private var dismiss
    @State private var phone = ""
    @State private var subject = ""
    @State private var message = ""
    @State private var priority = TicketPriority.normal
    @State private var category = ""
    @State private var distributorId = SupportRequestSheet.anokixOption
    @State private var showPriorityPicker = false
    @State private var showCategoryPicker = false
    @State private var showAudiencePicker = false
    @State private var submitting = false
    @State private var errorMsg: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if kind == .callback {
                        callbackFields
                    } else {
                        ticketFields
                    }

                    if let errorMsg {
                        Text(errorMsg)
                            .font(.system(size: 12))
                            .foregroundColor(Brand.danger)
                    }

                    Button(submitting ? "Sending…" : kind.submitTitle) { submit() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(submitting || !canSubmit)
                        .opacity(submitting || !canSubmit ? 0.6 : 1)
                }
                .padding(20)
            }
            .background(Brand.background)
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showPriorityPicker) {
            SelectOptionsSheet(title: "How urgent is it?",
                               options: TicketPriority.allCases.map { ($0.rawValue, $0.label) },
                               selection: priorityBinding)
        }
        .sheet(isPresented: $showCategoryPicker) {
            SelectOptionsSheet(title: "Topic",
                               options: categories.map { ($0.key, $0.name) },
                               selection: $category)
        }
        .sheet(isPresented: $showAudiencePicker) {
            SelectOptionsSheet(title: "Who should answer this?",
                               options: audienceOptions,
                               selection: $distributorId)
        }
    }

    @ViewBuilder
    private var callbackFields: some View {
        SingleLineField(title: "Number to call", required: true, text: $phone,
                        placeholder: "0821234567", keyboard: .phonePad)
        SingleLineField(title: "What is it about? (optional)", text: $subject,
                        placeholder: "Order not marked as delivered")
        MultilineField(title: "Anything we should know first? (optional)",
                       text: $message, height: 100)
    }

    @ViewBuilder
    private var ticketFields: some View {
        VStack(alignment: .leading, spacing: 5) {
            DropdownField(title: "Who should answer this?",
                          value: selectedAudienceName,
                          placeholder: "anokiX Support") { showAudiencePicker = true }
            Text("Ask your distributor about their stock, prices and deliveries. "
                 + "Ask anokiX about the app, your wallet or payments.")
                .font(.system(size: 11))
                .foregroundColor(Brand.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        SingleLineField(title: "What is this about?", required: true, text: $subject,
                        placeholder: "Wallet top-up hasn't arrived")
        if !categories.isEmpty {
            DropdownField(title: "Topic (optional)",
                          value: selectedCategoryName,
                          placeholder: "Choose a topic") { showCategoryPicker = true }
        }
        DropdownField(title: "How urgent is it?",
                      value: priority.label) { showPriorityPicker = true }
        MultilineField(title: "What happened?", required: true, text: $message,
                       placeholder: "Include amounts, dates and reference numbers.", height: 130)
    }

    /// Empty selection reads as anokiX Support, matching the placeholder.
    private var selectedAudienceName: String {
        distributors.first(where: { $0.id == distributorId })?.displayName ?? ""
    }

    /// anokiX Support first, then the trader's distributors.
    private var audienceOptions: [(String, String)] {
        var options: [(String, String)] = [(Self.anokixOption, "anokiX Support")]
        for distributor in distributors {
            options.append((distributor.id, distributor.displayName))
        }
        return options
    }

    private var selectedCategoryName: String {
        categories.first(where: { $0.key == category })?.name ?? ""
    }

    private var canSubmit: Bool {
        if kind == .callback {
            return !phone.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return !subject.trimmingCharacters(in: .whitespaces).isEmpty
            && !message.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var priorityBinding: Binding<String> {
        Binding(get: { priority.rawValue },
                set: { priority = TicketPriority(rawValue: $0) ?? .normal })
    }

    private func submit() {
        submitting = true
        errorMsg = nil

        // Both call-back fields are optional on the form, but the API wants a subject
        // and a body — fall back to a line that says what was asked for.
        let trimmedPhone = phone.trimmingCharacters(in: .whitespaces)
        let trimmedSubject = subject.trimmingCharacters(in: .whitespaces)
        let trimmedMessage = message.trimmingCharacters(in: .whitespaces)

        let finalSubject: String
        let finalMessage: String
        if kind == .callback {
            finalSubject = trimmedSubject.isEmpty ? "Call-back request" : trimmedSubject
            finalMessage = trimmedMessage.isEmpty
                ? "Call-back requested on \(trimmedPhone)." : trimmedMessage
        } else {
            finalSubject = trimmedSubject
            finalMessage = trimmedMessage
        }

        Task {
            do {
                _ = try await APIClient.shared.createSupportTicket(
                    subject: finalSubject,
                    message: finalMessage,
                    channel: kind == .callback ? "callback" : "web",
                    priority: kind == .callback ? nil : priority.rawValue,
                    callbackPhone: kind == .callback ? trimmedPhone : nil,
                    category: kind == .callback ? nil : (category.isEmpty ? nil : category),
                    // A call-back always goes to anokiX Support — that form has no
                    // audience picker, so no distributor is attached.
                    distributorId: (kind == .callback || distributorId.isEmpty)
                        ? nil : distributorId)
                dismiss()
                onSubmitted("Your request has been logged.")
            } catch {
                submitting = false
                errorMsg = (error as? LocalizedError)?.errorDescription
                    ?? "Could not send your request."
            }
        }
    }
}

/// Field label, with the red asterisk the portal puts on required inputs.
struct FieldLabel: View {
    let text: String
    var required = false

    var body: some View {
        HStack(spacing: 3) {
            if required {
                Text("*").font(.system(size: 13, weight: .medium)).foregroundColor(Brand.danger)
            }
            Text(text).font(.system(size: 13, weight: .medium)).foregroundColor(Brand.textSecondary)
        }
    }
}

/// Single-line text input matching `LabeledField`, with an optional required marker.
struct SingleLineField: View {
    let title: String
    var required = false
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default
    /// Turn off for values the keyboard must not "help" with, e.g. an email address.
    var autocapitalize = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(text: title, required: required)
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocapitalize ? .sentences : .never)
                .autocorrectionDisabled(!autocapitalize)
                .font(.system(size: 15))
                .foregroundColor(Brand.textPrimary)
                .padding(14)
                .background(Brand.surface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// Multi-line text input styled like `LabeledField`. `TextEditor` has no placeholder,
/// so one is drawn behind it while the text is empty.
struct MultilineField: View {
    let title: String
    var required = false
    @Binding var text: String
    var placeholder: String = ""
    var height: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !title.isEmpty {
                FieldLabel(text: title, required: required)
            }
            ZStack(alignment: .topLeading) {
                if text.isEmpty && !placeholder.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 15))
                        .foregroundColor(Brand.textTertiary)
                        .padding(.horizontal, 18)
                        .padding(.top, 22)
                }
                TextEditor(text: $text)
                    .font(.system(size: 15))
                    .foregroundColor(Brand.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 14)
            }
            .frame(height: height)
            .background(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
