import SwiftUI

/// Goods Returns (GRN) screen. Lists the trader's returns (GET api/trader/returns)
/// with a KPI summary; each card expands to show its line items + the distributor's
/// decision note, and the credit note once approved. "Return Goods" opens a form to
/// file a new return against a received GRV.
struct GoodsReturnsView: View {
    @StateObject private var store = GoodsReturnsStore()
    @State private var showForm = false
    @State private var toastMsg: String?

    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    statStrip
                    content
                }
                .padding(16)
            }
            bottomBar
        }
        .background(Brand.background)
        .task { if store.returns.isEmpty { await store.load() } }
        .refreshable { await store.load() }
        .sheet(isPresented: $showForm) {
            GoodsReturnForm(store: store) { message in
                showForm = false
                if let message { toastMsg = message }
            }
        }
        .toast($toastMsg)
    }

    private var statStrip: some View {
        LazyVGrid(columns: cols, spacing: 12) {
            StatTile(label: "Total Returns", value: "\(store.totalCount)", icon: "arrowshape.turn.up.left.fill", iconTint: Brand.info)
            StatTile(label: "Approved", value: "\(store.approvedCount)", valueColor: Brand.success, icon: "checkmark.seal.fill", iconTint: Brand.success)
            StatTile(label: "Pending", value: "\(store.pendingCount)", valueColor: Brand.warning, icon: "clock.fill", iconTint: Brand.warning)
            StatTile(label: "Credit Issued", value: GrnFmt.money(store.creditIssued), icon: "doc.plaintext.fill", iconTint: Brand.purple)
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.loading && store.returns.isEmpty {
            ProgressView().padding(.top, 60)
        } else if store.returns.isEmpty {
            emptyState
        } else {
            VStack(spacing: 10) {
                ForEach(store.returns) { grn in
                    ReturnCard(grn: grn)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrowshape.turn.up.left")
                .font(.system(size: 40))
                .foregroundColor(Brand.textTertiary)
            Text("No returns yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Brand.textPrimary)
            Text("Return goods against a received delivery and track credit notes here.")
                .font(.system(size: 12))
                .foregroundColor(Brand.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 24)
    }

    private var bottomBar: some View {
        Button { showForm = true } label: {
            Label("Return Goods", systemImage: "plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Brand.purple)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(16)
        .background(Brand.surface)
        .overlay(Divider(), alignment: .top)
    }
}

// MARK: - Return card (expandable)

private struct ReturnCard: View {
    let grn: ReturnDTO
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: expanded ? "minus.circle" : "plus.circle")
                    .font(.system(size: 17))
                    .foregroundColor(Brand.purple)
                Text(grn.grn_number)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Brand.purple)
                Spacer()
                StatusBadge(text: grn.statusLabel, fg: grn.statusTone.fg, bg: grn.statusTone.bg)
            }
            Text(grn.distributor_name ?? "—")
                .font(.system(size: 13))
                .foregroundColor(Brand.textPrimary)
            Text("\(grn.lineCount) line(s) · \(grn.total_quantity ?? "0") × \(ReturnReasonOption.label(grn.reason))")
                .font(.system(size: 12))
                .foregroundColor(Brand.textSecondary)

            if grn.hasCreditNote {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 11))
                        .foregroundColor(Brand.success)
                    Text("\(grn.credit_note_number ?? "") · \(GrnFmt.money(grn.credit_note_total ?? 0))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Brand.success)
                }
            }

            Text(GrnFmt.date(grn.created_at))
                .font(.system(size: 11))
                .foregroundColor(Brand.textTertiary)

            if expanded {
                Divider().padding(.top, 6)
                ForEach(grn.lineItems) { item in
                    HStack(alignment: .top) {
                        Text(item.name ?? "—")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Brand.textPrimary)
                        Spacer()
                        Text("\(item.qty) × \(ReturnReasonOption.label(item.reason))")
                            .font(.system(size: 12))
                            .foregroundColor(Brand.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
                if let note = grn.decision_note, !note.isEmpty {
                    Text("Distributor note: \(note)")
                        .font(.system(size: 12))
                        .foregroundColor(Brand.textSecondary)
                        .padding(.top, 2)
                }
            }
        }
        .card()
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() } }
    }
}

// MARK: - Return Goods form

private struct GoodsReturnForm: View {
    @ObservedObject var store: GoodsReturnsStore
    /// Called with an optional toast message; passing it dismisses the sheet.
    let onDone: (String?) -> Void

    @State private var grvs: [GrvDTO] = []
    @State private var loadingGrvs = true
    @State private var selectedGrv: GrvDTO?
    @State private var quantities: [Int: Int] = [:]   // item.id → return qty
    @State private var reasonKey = ReturnReasonOption.keys[0]
    @State private var note = ""
    @State private var submitting = false
    @State private var errorMsg: String?

    private var returnableGrvs: [GrvDTO] {
        grvs.filter { g in g.lineItems.contains { $0.received > 0 } }
    }

    private var canSubmit: Bool {
        selectedGrv != nil && quantities.values.contains { $0 > 0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    grvSection
                    if let grv = selectedGrv {
                        itemsSection(grv)
                    }
                    reasonSection
                    noteSection
                    if let errorMsg {
                        Text(errorMsg)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Brand.danger)
                    }
                }
                .padding(16)
            }
            .background(Brand.background)
            .navigationTitle("Return Goods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onDone(nil) }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { submit() } label: {
                        if submitting { ProgressView() } else { Text("Submit").fontWeight(.semibold) }
                    }
                    .disabled(submitting || !canSubmit)
                }
            }
            .task { await loadGrvs() }
        }
    }

    // MARK: sections

    private var grvSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Return against delivery (GRV)").font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary)
            if loadingGrvs {
                fieldBox { HStack { ProgressView().scaleEffect(0.8); Text("Loading deliveries…").foregroundColor(Brand.textSecondary) } }
            } else if returnableGrvs.isEmpty {
                fieldBox { Text("No received goods to return").foregroundColor(Brand.textSecondary) }
                Text("Confirm receipt of a delivery (GRV) before you can return goods.")
                    .font(.system(size: 11)).foregroundColor(Brand.textSecondary)
            } else {
                Menu {
                    ForEach(returnableGrvs) { g in
                        Button(grvLabel(g)) { selectGrv(g) }
                    }
                } label: {
                    fieldBox {
                        HStack {
                            Text(selectedGrv.map(grvLabel) ?? "Select a received GRV")
                                .foregroundColor(selectedGrv == nil ? Brand.textTertiary : Brand.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.down").font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private func itemsSection(_ grv: GrvDTO) -> some View {
        let items = grv.lineItems.filter { $0.received > 0 }
        return VStack(alignment: .leading, spacing: 4) {
            Text("Items to return").font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name ?? "—").font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.textPrimary)
                            Text("\(item.received) available").font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                        }
                        Spacer()
                        qtyStepper(item)
                    }
                    .padding(.vertical, 12)
                    if idx < items.count - 1 { Divider() }
                }
            }
        }
    }

    private var reasonSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Reason").font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary)
            Menu {
                ForEach(Array(ReturnReasonOption.keys.enumerated()), id: \.offset) { idx, key in
                    Button(ReturnReasonOption.labels[idx]) { reasonKey = key }
                }
            } label: {
                fieldBox {
                    HStack {
                        Text(ReturnReasonOption.label(reasonKey)).foregroundColor(Brand.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.down").font(.system(size: 13)).foregroundColor(Brand.textSecondary)
                    }
                }
            }
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Note (optional)").font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.textPrimary)
            TextField("Add a note for the distributor…", text: $note, axis: .vertical)
                .lineLimit(3...6)
                .font(.system(size: 14))
                .padding(14)
                .background(Brand.surface)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
        }
    }

    private func qtyStepper(_ item: GrvItemDTO) -> some View {
        let q = quantities[item.id] ?? 0
        return HStack(spacing: 0) {
            Button { setQty(item, q - 1) } label: {
                Image(systemName: "minus").frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            Text("\(q)").font(.system(size: 15, weight: .bold)).foregroundColor(Brand.textPrimary).frame(minWidth: 34)
            Button { setQty(item, q + 1) } label: {
                Image(systemName: "plus").frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
        }
        .foregroundColor(Brand.purple)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Brand.border, lineWidth: 1))
    }

    private func fieldBox<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        content()
            .font(.system(size: 14))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
    }

    private func grvLabel(_ g: GrvDTO) -> String {
        let dist = (g.distributor_name?.isEmpty == false) ? " · \(g.distributor_name!)" : ""
        return g.grv_number + dist
    }

    // MARK: actions

    private func loadGrvs() async {
        loadingGrvs = true
        do {
            let data = try await APIClient.shared.getGrvs()
            grvs = data.grvs
        } catch {
            grvs = []
        }
        loadingGrvs = false
    }

    private func selectGrv(_ g: GrvDTO) {
        selectedGrv = g
        var q: [Int: Int] = [:]
        for item in g.lineItems where item.received > 0 { q[item.id] = 0 }
        quantities = q
    }

    private func setQty(_ item: GrvItemDTO, _ value: Int) {
        quantities[item.id] = max(0, min(item.received, value))
    }

    private func submit() {
        guard let grv = selectedGrv else {
            errorMsg = "Select a delivery (GRV) to return against."
            return
        }
        var items: [[String: Any]] = []
        for item in grv.lineItems where item.received > 0 {
            let q = quantities[item.id] ?? 0
            if q > 0 {
                items.append(["product_id": item.product_id ?? 0, "quantity": q, "reason": reasonKey])
            }
        }
        if items.isEmpty {
            errorMsg = "Set a return quantity for at least one item."
            return
        }
        submitting = true
        errorMsg = nil
        Task {
            do {
                try await store.create(items: items, reason: reasonKey, note: note, sourceGrvId: grv.id)
                submitting = false
                onDone("Return submitted. Stock updated; awaiting distributor review.")
            } catch {
                submitting = false
                errorMsg = (error as? LocalizedError)?.errorDescription ?? "Failed to submit return."
            }
        }
    }
}
