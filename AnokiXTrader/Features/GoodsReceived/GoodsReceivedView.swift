import SwiftUI
import PDFKit

/// Goods Received (GRV) screen. Lists the trader's Goods Received Vouchers (GET
/// api/trader/grvs) with a KPI summary. A GRV is created when an order is
/// delivered; stock is added to inventory only once the trader confirms receipt
/// (full or partial) via the bottom sheet. Each GRV can be exported to PDF.
struct GoodsReceivedView: View {
    @StateObject private var store = GoodsReceivedStore()
    @State private var confirmTarget: GrvDTO?
    @State private var pdfDoc: PDFDoc?
    @State private var toastMsg: String?

    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                statStrip
                content
            }
            .padding(16)
        }
        .background(Brand.background)
        .task { if store.grvs.isEmpty { await store.load() } }
        .refreshable { await store.load() }
        .sheet(item: $confirmTarget) { grv in
            GrvConfirmSheet(grv: grv, store: store) { message in
                confirmTarget = nil
                if let message { toastMsg = message }
            }
        }
        .sheet(item: $pdfDoc) { doc in
            GrvPdfView(doc: doc)
        }
        .toast($toastMsg)
    }

    private var statStrip: some View {
        LazyVGrid(columns: cols, spacing: 12) {
            StatTile(label: "Total GRVs", value: "\(store.totalCount)", icon: "doc.text.fill", iconTint: Brand.info)
            StatTile(label: "Awaiting Receipt", value: "\(store.awaitingCount)", valueColor: Brand.warning, icon: "clock.fill", iconTint: Brand.warning)
            StatTile(label: "Received", value: "\(store.receivedCount)", valueColor: Brand.success, icon: "checkmark.seal.fill", iconTint: Brand.success)
            StatTile(label: "Line Items", value: "\(store.lineItemCount)", icon: "square.grid.2x2.fill", iconTint: Brand.purple)
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.loading && store.grvs.isEmpty {
            ProgressView().padding(.top, 60)
        } else if store.grvs.isEmpty {
            emptyState
        } else {
            VStack(spacing: 10) {
                ForEach(store.grvs) { grv in
                    GrvCard(grv: grv,
                            onPdf: { openPdf(grv) },
                            onConfirm: { confirmTarget = grv })
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 40))
                .foregroundColor(Brand.textTertiary)
            Text("No goods received vouchers yet")
                .font(.app(15, .semibold))
                .foregroundColor(Brand.textPrimary)
            Text("A GRV appears here once an order is delivered, ready for you to confirm.")
                .font(.app(12))
                .foregroundColor(Brand.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 24)
    }

    // MARK: PDF

    private func openPdf(_ grv: GrvDTO) {
        toastMsg = "Generating PDF…"
        Task {
            do {
                let pdf = try await APIClient.shared.getGrvPdf(id: grv.id)
                guard let b64 = pdf.data,
                      let bytes = Data(base64Encoded: b64, options: .ignoreUnknownCharacters) else {
                    toastMsg = "PDF unavailable."
                    return
                }
                let name = (pdf.filename?.isEmpty == false) ? pdf.filename! : "\(grv.grv_number).pdf"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                try bytes.write(to: url)
                toastMsg = nil
                pdfDoc = PDFDoc(url: url, title: grv.grv_number)
            } catch {
                toastMsg = (error as? LocalizedError)?.errorDescription ?? "Couldn't open PDF."
            }
        }
    }
}

// MARK: - GRV card

private struct GrvCard: View {
    let grv: GrvDTO
    let onPdf: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(grv.grv_number)
                    .font(.app(16, .bold))
                    .foregroundColor(Brand.purple)
                Spacer()
                StatusBadge(text: grv.statusLabel, fg: grv.statusTone.fg, bg: grv.statusTone.bg)
            }
            Text("Order \(grv.order_number ?? "—")")
                .font(.app(13))
                .foregroundColor(Brand.textPrimary)
            Text("\(grv.lineCount) line(s) · Delivery \(GrvFmt.deliveryDate(grv.delivery_date))")
                .font(.app(12))
                .foregroundColor(Brand.textSecondary)

            Divider().padding(.top, 6)

            HStack(spacing: 10) {
                Spacer()
                Button(action: onPdf) {
                    Label("PDF", systemImage: "doc.text")
                        .font(.app(13, .semibold))
                        .foregroundColor(Brand.textPrimary)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.border, lineWidth: 1))
                }
                .buttonStyle(.plain)

                if grv.isPending {
                    Button(action: onConfirm) {
                        Text("Confirm Receipt")
                            .font(.app(13, .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .background(Brand.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
    }
}

// MARK: - Confirm Receipt sheet

private struct GrvConfirmSheet: View {
    let grv: GrvDTO
    @ObservedObject var store: GoodsReceivedStore
    /// Called with an optional toast message; passing it dismisses the sheet.
    let onDone: (String?) -> Void

    @State private var fullMode = true
    @State private var receivedText: [String]
    @State private var damagedText: [String]
    @State private var submitting = false
    @State private var errorMsg: String?

    init(grv: GrvDTO, store: GoodsReceivedStore, onDone: @escaping (String?) -> Void) {
        self.grv = grv
        self.store = store
        self.onDone = onDone
        let items = grv.lineItems
        _receivedText = State(initialValue: items.map { String($0.ordered) })
        _damagedText = State(initialValue: items.map { _ in "0" })
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    infoBox
                    Picker("", selection: $fullMode) {
                        Text("Receive Full Order").tag(true)
                        Text("Receive Partial Order").tag(false)
                    }
                    .pickerStyle(.segmented)

                    VStack(spacing: 0) {
                        ForEach(Array(grv.lineItems.enumerated()), id: \.element.id) { idx, item in
                            lineRow(idx, item)
                            if idx < grv.lineCount - 1 { Divider() }
                        }
                    }

                    Text("Accepted items will be added to your inventory.")
                        .font(.app(12))
                        .foregroundColor(Brand.textSecondary)
                }
                .padding(16)
            }
            footer
        }
        .background(Brand.surface)
        .presentationDetents([.large])
    }

    private var header: some View {
        HStack {
            Text("Confirm Receipt · \(grv.grv_number)")
                .font(.app(17, .bold))
                .foregroundColor(Brand.textPrimary)
            Spacer()
            Button { onDone(nil) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Brand.textSecondary)
            }
        }
        .padding(16)
    }

    private var infoBox: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                infoCell("GRV NUMBER", grv.grv_number)
                infoCell("LINKED INVOICE", grv.invoice_number ?? "—")
            }
            HStack(alignment: .top) {
                infoCell("DISTRIBUTOR", grv.distributor_name ?? "—")
                infoCell("DELIVERY DATE", GrvFmt.deliveryDate(grv.delivery_date))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Brand.purpleLight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func infoCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.app(9, .semibold))
                .foregroundColor(Brand.textTertiary)
            Text(value)
                .font(.app(14, .bold))
                .foregroundColor(Brand.purple)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func lineRow(_ idx: Int, _ item: GrvItemDTO) -> some View {
        let received = receivedValue(idx)
        let damaged = damagedValue(idx)
        let missing = item.ordered - received - damaged
        let accepted = max(received, 0)

        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name ?? "—")
                    .font(.app(14, .semibold))
                    .foregroundColor(Brand.textPrimary)
                Text("SKU: \(item.sku ?? "—")")
                    .font(.app(11))
                    .foregroundColor(Brand.textSecondary)
            }
            HStack(alignment: .top, spacing: 6) {
                numCell("ORDERED") { Text("\(item.ordered)").cellValue() }
                numCell("RECEIVED") { qtyField($receivedText, idx, fallback: item.ordered) }
                numCell("DAMAGED") { qtyField($damagedText, idx, fallback: 0) }
                numCell("MISSING") {
                    Text("\(missing)")
                        .cellValue(color: missing < 0 ? Brand.danger : (missing > 0 ? Brand.warning : Brand.textSecondary))
                }
                numCell("ACCEPTED") { Text("\(accepted)").cellValue(color: Brand.success) }
            }
        }
        .padding(.vertical, 12)
    }

    private func numCell<V: View>(_ label: String, @ViewBuilder _ value: () -> V) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.app(9, .semibold))
                .foregroundColor(Brand.textTertiary)
            value()
        }
        .frame(maxWidth: .infinity)
    }

    private func qtyField(_ binding: Binding<[String]>, _ idx: Int, fallback: Int) -> some View {
        Group {
            if fullMode {
                Text("\(fallback)").cellValue(color: Brand.textTertiary)
            } else {
                TextField("", text: Binding(
                    get: { binding.wrappedValue[idx] },
                    set: { binding.wrappedValue[idx] = $0.filter(\.isNumber) }
                ))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.app(15, .bold))
                .frame(height: 36)
                .background(Brand.surface)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Brand.border, lineWidth: 1))
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if let errorMsg {
                Text(errorMsg)
                    .font(.app(12, .medium))
                    .foregroundColor(Brand.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 10) {
                Button { onDone(nil) } label: {
                    Text("Cancel")
                        .font(.app(15, .semibold))
                        .foregroundColor(Brand.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button(action: submit) {
                    HStack(spacing: 8) {
                        if submitting { ProgressView().tint(.white) }
                        Text(submitting ? "Saving…" : "Confirm & Add to Inventory")
                    }
                    .font(.app(15, .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Brand.purple.opacity(submitting ? 0.7 : 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(submitting)
            }
        }
        .padding(16)
        .background(Brand.surface)
        .overlay(Divider(), alignment: .top)
    }

    // MARK: line math

    private func receivedValue(_ idx: Int) -> Int {
        fullMode ? grv.lineItems[idx].ordered : (Int(receivedText[idx]) ?? 0)
    }

    private func damagedValue(_ idx: Int) -> Int {
        fullMode ? 0 : (Int(damagedText[idx]) ?? 0)
    }

    private func submit() {
        var items: [[String: Int]] = []
        for (idx, line) in grv.lineItems.enumerated() {
            let r = receivedValue(idx)
            let d = damagedValue(idx)
            if r < 0 || d < 0 {
                errorMsg = "Quantities can't be negative."
                return
            }
            if r + d > line.ordered {
                errorMsg = "Received + damaged can't exceed ordered for \(line.name ?? "item")."
                return
            }
            items.append(["grv_item_id": line.id, "received_quantity": r, "damaged_quantity": d])
        }
        submitting = true
        errorMsg = nil
        Task {
            do {
                try await store.confirm(id: grv.id, items: items, note: "")
                submitting = false
                onDone("Goods received and added to inventory.")
            } catch {
                submitting = false
                errorMsg = (error as? LocalizedError)?.errorDescription ?? "Failed to confirm receipt."
            }
        }
    }
}

private extension Text {
    /// Shared styling for the static numeric cells (ordered / missing / accepted).
    func cellValue(color: Color = Brand.textPrimary) -> some View {
        self.font(.app(15, .bold))
            .foregroundColor(color)
            .frame(height: 36)
    }
}

// MARK: - PDF preview

/// Identifiable wrapper so a decoded GRV PDF can drive a `.sheet(item:)`.
struct PDFDoc: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
}

/// Dedicated in-app GRV PDF viewer: a branded screen with the GRV number as title,
/// a Done button, and a Share/export action — rendered with PDFKit (pinch-zoom,
/// continuous page scrolling).
struct GrvPdfView: View {
    let doc: PDFDoc
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PDFKitView(url: doc.url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(doc.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: doc.url) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}

/// PDFKit document view (continuous vertical scroll, auto-scaled to width).
struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = PDFDocument(url: url)
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = UIColor(Brand.background)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document == nil {
            view.document = PDFDocument(url: url)
        }
    }
}
