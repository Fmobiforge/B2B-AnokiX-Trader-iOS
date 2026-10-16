import SwiftUI
import UIKit
import QuickLook

/// Reports — GET api/trader/reports, one call for the KPI summary, the catalogue of
/// report types the trader may build and the reports already generated.
///
/// From here a report can be generated, downloaded (the download service runs on its
/// own port), regenerated for the same type, or deleted. The category tabs, the search
/// field and the period filter all run on the device — the endpoint takes no params.
struct ReportsView: View {
    @StateObject private var store = ReportsStore()

    @State private var showGenerate = false
    /// Pre-fills the Generate sheet for the "Generate again" row action.
    @State private var repeatReport: ReportDTO?
    @State private var showPeriodFilter = false
    @State private var pendingDelete: ReportDTO?
    @State private var rowMenuFor: ReportDTO?
    @State private var downloaded: DownloadedReport?
    @State private var toastMsg: String?

    private let statCols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                statStrip
                generateButton
                categoryTabs
                searchField
                periodPill
                resultCount
                content
            }
            .padding(16)
        }
        .background(Brand.background)
        .task { if store.reports.isEmpty { await store.load() } }
        .refreshable { await store.load() }
        // Surface a failed load as a toast, then clear it so it shows only once.
        .onChange(of: store.error) { message in
            guard let message else { return }
            toastMsg = message
            store.error = nil
        }
        .sheet(isPresented: $showGenerate) {
            GenerateReportSheet(store: store, repeatReport: repeatReport) { message in
                toastMsg = message
                Task { await store.load() }
            }
        }
        .sheet(isPresented: $showPeriodFilter) {
            DateRangeSheet(from: store.periodFrom ?? ReportFmt.defaultPeriod.from,
                           to: store.periodTo ?? ReportFmt.defaultPeriod.to) { from, to in
                store.periodFrom = from
                store.periodTo = to
            }
        }
        .sheet(item: $downloaded) { doc in
            DownloadedReportView(doc: doc)
        }
        // `presenting:` hands the report into the actions, so they still have it once
        // the dialog has dismissed and cleared `rowMenuFor`.
        .confirmationDialog(rowMenuTitle, isPresented: rowMenuBinding,
                            titleVisibility: .visible, presenting: rowMenuFor) { report in
            Button("Generate again") {
                repeatReport = report
                showGenerate = true
            }
            Button("Delete", role: .destructive) { pendingDelete = report }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete this report?", isPresented: deleteBinding, presenting: pendingDelete) { report in
            Button("Delete", role: .destructive) { delete(report) }
            Button("Cancel", role: .cancel) {}
        } message: { report in
            Text("“\(report.name ?? "This report")” will be removed from your list. "
                 + "You can generate it again at any time.")
        }
        .toast($toastMsg)
    }

    // MARK: Header

    private var statStrip: some View {
        LazyVGrid(columns: statCols, spacing: 12) {
            StatTile(label: "Reports Generated", value: "\(store.summary?.generated ?? 0)",
                     icon: "doc.text.fill", iconTint: Brand.purple)
            StatTile(label: "Downloads", value: "\(store.summary?.downloads ?? 0)",
                     icon: "arrow.down.circle.fill", iconTint: Brand.success)
            StatTile(label: "This Month", value: "\(store.summary?.this_month ?? 0)",
                     icon: "calendar", iconTint: Brand.info)
            StatTile(label: "Failed", value: "\(store.summary?.failed ?? 0)",
                     valueColor: (store.summary?.failed ?? 0) > 0 ? Brand.danger : Brand.textPrimary,
                     icon: "exclamationmark.triangle.fill", iconTint: Brand.warning)
        }
    }

    private var generateButton: some View {
        Button {
            repeatReport = nil
            showGenerate = true
        } label: {
            Label("Generate Report", systemImage: "plus")
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(store.available.isEmpty)
        .opacity(store.available.isEmpty ? 0.5 : 1)
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ReportTab.allCases) { tab in
                    FilterChip(label: tab.rawValue, selected: tab == store.tab) {
                        store.tab = tab
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(Brand.textSecondary)
            TextField("Search report name or period…", text: $store.search)
                .font(.app(14))
                .foregroundColor(Brand.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !store.search.isEmpty {
                Button { store.search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Brand.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Brand.surfaceVariant)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var periodPill: some View {
        HStack(spacing: 10) {
            Button { showPeriodFilter = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(store.hasPeriodFilter ? Brand.purple : Brand.textSecondary)
                    Text(store.hasPeriodFilter
                         ? ReportFmt.range(store.periodFrom, store.periodTo)
                         : "Report period")
                        .font(.app(14))
                        .foregroundColor(Brand.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if store.hasPeriodFilter {
                Button("Clear") { store.clearPeriod() }
                    .font(.app(12, .semibold))
                    .foregroundColor(Brand.purple)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Brand.surface)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(store.hasPeriodFilter ? Brand.purple : Brand.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var resultCount: some View {
        let n = store.filtered.count
        return Text("Showing \(n) \(n == 1 ? "report" : "reports")")
            .font(.app(12))
            .foregroundColor(Brand.textSecondary)
    }

    // MARK: List

    @ViewBuilder
    private var content: some View {
        if store.loading && store.reports.isEmpty {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 50)
        } else if store.filtered.isEmpty {
            emptyState
        } else {
            VStack(spacing: 10) {
                ForEach(store.filtered) { report in
                    ReportCard(report: report,
                               onDownload: { download(report) },
                               onMore: { rowMenuFor = report })
                }
            }
        }
    }

    private var emptyState: some View {
        let unfiltered = store.reports.isEmpty
        return VStack(spacing: 10) {
            Image(systemName: "doc.plaintext")
                .font(.system(size: 40))
                .foregroundColor(Brand.textTertiary)
            Text(unfiltered ? "No reports yet" : "Nothing matches")
                .font(.app(15, .semibold))
                .foregroundColor(Brand.textPrimary)
            Text(unfiltered
                 ? "Tap Generate Report to build your first one."
                 : "Try a different category, search or period.")
                .font(.app(12))
                .foregroundColor(Brand.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
        .padding(.horizontal, 24)
    }

    // MARK: Actions

    private func download(_ report: ReportDTO) {
        toastMsg = "Downloading…"
        Task {
            do {
                let file = try await APIClient.shared.downloadReport(id: report.id)
                let name = sanitised(file.fileName) ?? report.suggestedFileName
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                try file.bytes.write(to: url, options: .atomic)
                toastMsg = nil
                downloaded = DownloadedReport(url: url, title: report.name ?? "Report")
                // The server counts the download, so pull the fresh numbers back in.
                await store.load()
            } catch {
                toastMsg = (error as? LocalizedError)?.errorDescription
                    ?? "Could not download the report."
            }
        }
    }

    /// Drop any path a hostile Content-Disposition might carry.
    private func sanitised(_ name: String?) -> String? {
        guard let name = name?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return nil }
        let last = name.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last
        return last.map(String.init)
    }

    private func delete(_ report: ReportDTO) {
        Task {
            do {
                let result = try await APIClient.shared.deleteReport(id: report.id)
                toastMsg = result.message ?? "Report deleted."
                await store.load()
            } catch {
                toastMsg = (error as? LocalizedError)?.errorDescription
                    ?? "Failed to delete the report."
            }
        }
    }

    private var rowMenuTitle: String {
        rowMenuFor.flatMap(\.name) ?? "Report"
    }

    // `.confirmationDialog`/`.alert` want a Bool binding; drive them off the pending item.
    private var rowMenuBinding: Binding<Bool> {
        Binding(get: { rowMenuFor != nil }, set: { if !$0 { rowMenuFor = nil } })
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }
}

// MARK: - Report card

private struct ReportCard: View {
    let report: ReportDTO
    let onDownload: () -> Void
    let onMore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top) {
                Text(report.name ?? "—")
                    .font(.app(15, .bold))
                    .foregroundColor(Brand.textPrimary)
                Spacer(minLength: 8)
                StatusBadge(text: report.statusLabel,
                            fg: report.statusTone.fg, bg: report.statusTone.bg)
            }

            HStack(spacing: 8) {
                if let category = report.category, !category.isEmpty {
                    Text(category)
                        .font(.app(10))
                        .foregroundColor(Brand.purple)
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(Brand.purpleLight)
                        .clipShape(Capsule())
                }
                Text(report.metaLine)
                    .font(.app(11))
                    .foregroundColor(Brand.textSecondary)
                    .lineLimit(1)
            }

            Text(report.periodLabel)
                .font(.app(12))
                .foregroundColor(Brand.textPrimary)
            Text("Generated \(ReportFmt.dateTime(report.created_at))")
                .font(.app(11))
                .foregroundColor(Brand.textSecondary)

            if let message = report.error, !message.isEmpty, !report.isReady {
                Text(message)
                    .font(.app(11))
                    .foregroundColor(Brand.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Brand.dangerBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Divider().padding(.top, 4)

            HStack {
                Text(downloadsLabel)
                    .font(.app(11))
                    .foregroundColor(Brand.textTertiary)
                Spacer()
                Button(action: onDownload) {
                    Label("Download", systemImage: "arrow.down.circle")
                        .font(.app(13, .semibold))
                        .foregroundColor(Brand.purple)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.purple, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(!report.isReady)
                .opacity(report.isReady ? 1 : 0.4)

                Button(action: onMore) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Brand.textSecondary)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .card()
    }

    private var downloadsLabel: String {
        let n = report.downloads ?? 0
        if n == 0 { return "Not downloaded yet" }
        return "Downloaded \(n) \(n == 1 ? "time" : "times")"
    }
}

// MARK: - Generate sheet

/// "Generate a report" — pick a report type and a period, then POST .../generate.
private struct GenerateReportSheet: View {
    @ObservedObject var store: ReportsStore
    /// When set, the sheet opens on that report's type and period ("Generate again").
    let repeatReport: ReportDTO?
    let onGenerated: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selection: Int?
    @State private var from = ReportFmt.defaultPeriod.from
    @State private var to = ReportFmt.defaultPeriod.to
    @State private var showTypePicker = false
    @State private var showPeriodPicker = false
    @State private var submitting = false
    @State private var errorMsg: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Built from your own data and downloaded as a CSV, which opens in "
                         + "Excel, Numbers and Google Sheets.")
                        .font(.app(12))
                        .foregroundColor(Brand.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Brand.surfaceVariant)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 6) {
                        DropdownField(title: "Report",
                                      value: selectedName,
                                      placeholder: "Choose a report") { showTypePicker = true }
                        if let about = selectedAbout, !about.isEmpty {
                            Text(about)
                                .font(.app(11))
                                .foregroundColor(Brand.textSecondary)
                        }
                    }

                    DropdownField(title: "Period",
                                  value: ReportFmt.range(from, to)) { showPeriodPicker = true }

                    if let errorMsg {
                        Text(errorMsg)
                            .font(.app(12))
                            .foregroundColor(Brand.danger)
                    }

                    Button(submitting ? "Generating…" : "Generate") { submit() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(submitting || selection == nil)
                        .opacity(submitting || selection == nil ? 0.6 : 1)
                }
                .padding(20)
            }
            .background(Brand.background)
            .navigationTitle("Generate a report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.light)
        .onAppear(perform: seedFromRepeat)
        .sheet(isPresented: $showTypePicker) {
            SelectOptionsSheet(title: "Choose a report",
                               options: store.available.map { ($0.key, $0.name) },
                               selection: selectionKeyBinding)
        }
        .sheet(isPresented: $showPeriodPicker) {
            DateRangeSheet(from: from, to: to) { newFrom, newTo in
                from = newFrom
                to = newTo
            }
        }
    }

    private var selectedName: String {
        guard let selection, store.available.indices.contains(selection) else { return "" }
        return store.available[selection].name
    }

    private var selectedAbout: String? {
        guard let selection, store.available.indices.contains(selection) else { return nil }
        return store.available[selection].about
    }

    /// `SelectOptionsSheet` binds to the option's id; map that back to the index.
    private var selectionKeyBinding: Binding<String> {
        Binding(
            get: { selection.flatMap { store.available[safe: $0]?.key } ?? "" },
            set: { key in selection = store.available.firstIndex { $0.key == key } })
    }

    private func seedFromRepeat() {
        guard let repeatReport else { return }
        selection = store.availableIndex(for: repeatReport)
        if let start = ReportFmt.parse(repeatReport.period_from) { from = start }
        if let end = ReportFmt.parse(repeatReport.period_to) { to = end }
    }

    private func submit() {
        guard let selection, store.available.indices.contains(selection) else { return }
        submitting = true
        errorMsg = nil
        let key = store.available[selection].key
        Task {
            do {
                let result = try await APIClient.shared.generateReport(
                    reportKey: key, from: ReportFmt.api(from), to: ReportFmt.api(to))
                dismiss()
                onGenerated(result.message ?? "Your report is ready.")
            } catch {
                submitting = false
                errorMsg = (error as? LocalizedError)?.errorDescription
                    ?? "Failed to generate the report."
            }
        }
    }
}

private extension Array {
    /// Index access that returns nil rather than trapping.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Downloaded file preview

/// Identifiable wrapper so a saved report can drive a `.sheet(item:)`.
struct DownloadedReport: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
}

/// Shows the downloaded file. Reports are CSV, which PDFKit cannot render, so this
/// uses QuickLook — the same viewer Files uses — with a Share action beside it.
struct DownloadedReportView: View {
    let doc: DownloadedReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            QuickLookView(url: doc.url)
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

/// QuickLook preview for any file type the system can render (CSV, PDF, XLSX …).
struct QuickLookView: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        context.coordinator.url = url
        controller.reloadData()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL

        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController,
                               previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
