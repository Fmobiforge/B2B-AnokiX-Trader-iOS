import SwiftUI

/// One support ticket — GET api/common/support/tickets/{id}. Shows the conversation as
/// a chat thread and, while the ticket is open, lets the trader reply
/// (POST .../tickets/reply) or close it (POST .../tickets/close). All three endpoints
/// answer with the refreshed ticket, so the screen simply rebinds the result.
struct TicketDetailView: View {
    let ticketId: Int
    /// Called on dismiss so the Support Centre list can pick up a status change.
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var ticket: SupportTicketDTO?
    @State private var reply = ""
    @State private var loading = true
    @State private var submitting = false
    @State private var showCloseConfirm = false
    @State private var toastMsg: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                thread
                if ticket?.open == true {
                    composer
                } else if ticket != nil {
                    closedBanner
                }
            }
            .background(Brand.background)
            .navigationTitle(ticket?.ticket_number ?? "Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        onClose()
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.light)
        .task { await load() }
        .confirmationDialog("Close this ticket?", isPresented: $showCloseConfirm,
                            titleVisibility: .visible) {
            Button("Close ticket", role: .destructive) { closeTicket() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("We will stop working on it. You can always open a new ticket.")
        }
        .toast($toastMsg)
    }

    // MARK: Header

    @ViewBuilder
    private var header: some View {
        if let ticket {
            VStack(alignment: .leading, spacing: 8) {
                Text(ticket.subject ?? "—")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Brand.textPrimary)
                HStack(spacing: 6) {
                    StatusBadge(text: ticket.statusLabel,
                                fg: ticket.statusTone.fg, bg: ticket.statusTone.bg)
                    if let badge = ticket.priorityBadge {
                        StatusBadge(text: badge.label, fg: badge.fg, bg: badge.bg)
                    }
                    Text(openedLine(ticket))
                        .font(.system(size: 12))
                        .foregroundColor(Brand.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Brand.surface)
        }
    }

    // MARK: Thread

    @ViewBuilder
    private var thread: some View {
        if loading && ticket == nil {
            Spacer()
            ProgressView()
            Spacer()
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(messages) { message in
                            MessageBubble(message: message).id(message.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: messages.count) { _ in
                    // Keep the newest reply in view after sending or reloading.
                    if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var messages: [SupportMessageDTO] { ticket?.messages ?? [] }

    /// "Opened 13 Aug, 20:39", plus who it went to when the ticket was raised with a
    /// distributor rather than anokiX Support.
    private func openedLine(_ ticket: SupportTicketDTO) -> String {
        let opened = "Opened \(SupportFmt.shortDateTime(ticket.created_at))"
        guard let name = ticket.distributor_name, !name.isEmpty else { return opened }
        return "\(opened) · Sent to \(name)"
    }

    // MARK: Composer

    private var composer: some View {
        VStack(spacing: 10) {
            MultilineField(title: "", text: $reply,
                           placeholder: "Type your reply…", height: 84)
            HStack {
                Button("Close ticket") { showCloseConfirm = true }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Brand.textPrimary)
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                    .buttonStyle(.plain)
                Spacer()
                Button(submitting ? "Sending…" : "Send reply") { sendReply() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20).padding(.vertical, 11)
                    .background(Brand.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .buttonStyle(.plain)
                    .disabled(submitting || reply.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(submitting || reply.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1)
            }
        }
        .padding(16)
        .background(Brand.surface)
    }

    private var closedBanner: some View {
        Text("This ticket is closed. Open a new one if you still need help.")
            .font(.system(size: 12))
            .foregroundColor(Brand.info)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Brand.infoBg)
    }

    // MARK: Actions

    private func load() async {
        loading = true
        do {
            ticket = try await APIClient.shared.getSupportTicket(id: ticketId).ticket
        } catch {
            toastMsg = (error as? LocalizedError)?.errorDescription
                ?? "Could not load this ticket."
        }
        loading = false
    }

    private func sendReply() {
        let text = reply.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        submitting = true
        Task {
            do {
                ticket = try await APIClient.shared
                    .replySupportTicket(ticketId: ticketId, message: text).ticket
                reply = ""
            } catch {
                toastMsg = (error as? LocalizedError)?.errorDescription
                    ?? "Could not send your reply."
            }
            submitting = false
        }
    }

    private func closeTicket() {
        submitting = true
        Task {
            do {
                ticket = try await APIClient.shared.closeSupportTicket(ticketId: ticketId).ticket
                toastMsg = "Ticket closed."
            } catch {
                toastMsg = (error as? LocalizedError)?.errorDescription
                    ?? "Could not close the ticket."
            }
            submitting = false
        }
    }
}

// MARK: - Message bubble

/// One entry in the thread. The merchant's own messages sit right in a green bubble,
/// support replies left in a white one, and system notes ("Closed by the merchant.")
/// centred in a pill — they read as a divider, not a message.
private struct MessageBubble: View {
    let message: SupportMessageDTO

    var body: some View {
        if message.isSystem {
            Text(message.body ?? "")
                .font(.system(size: 12))
                .foregroundColor(Brand.textSecondary)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Brand.surface)
                .overlay(Capsule().stroke(Brand.border, lineWidth: 1))
                .clipShape(Capsule())
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 3) {
                if !message.isMine, let author = message.author_name, !author.isEmpty {
                    Text(author)
                        .font(.system(size: 10))
                        .foregroundColor(Brand.textTertiary)
                        .padding(.horizontal, 4)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(message.body ?? "")
                        .font(.system(size: 13))
                        .foregroundColor(Brand.textPrimary)
                    Text(SupportFmt.time(message.created_at))
                        .font(.system(size: 10))
                        .foregroundColor(Brand.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(message.isMine ? Brand.successBg : Brand.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(message.isMine ? Color.clear : Brand.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .frame(maxWidth: 280, alignment: message.isMine ? .trailing : .leading)
            }
            .frame(maxWidth: .infinity, alignment: message.isMine ? .trailing : .leading)
        }
    }
}
