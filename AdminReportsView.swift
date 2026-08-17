//
//  AdminReportsView.swift
//  Parent Chat
//
//  Live moderation inbox. Only accessible to admin emails (see
//  AuthenticationManager.isAdmin). Backed by a snapshot listener so new
//  reports appear within seconds while the view is open.
//

import SwiftUI
import FirebaseFirestore

struct AdminReportsView: View {
    @Environment(AuthenticationManager.self) var authManager

    @State private var reports: [UserReport] = []
    @State private var listener: ListenerRegistration?
    @State private var selectedReport: UserReport?

    private var pendingCount: Int {
        reports.filter { $0.status == "pending" }.count
    }

    var body: some View {
        List {
            if pendingCount > 0 {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                        Text("\(pendingCount) pending review")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                }
            }

            Section("All Reports") {
                if reports.isEmpty {
                    Text("No reports yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(reports) { report in
                        Button {
                            selectedReport = report
                        } label: {
                            ReportRow(report: report)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.inline)
        .task { startListener() }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
        .sheet(item: $selectedReport) { report in
            ReportDetailView(report: report)
                .environment(authManager)
        }
    }

    private func startListener() {
        listener?.remove()
        listener = FirestoreManager.shared.listenToReports { updated in
            DispatchQueue.main.async { reports = updated }
        } onError: { _ in
            // Silent — likely a permission issue; rule must allow admin read.
        }
    }
}

private struct ReportRow: View {
    let report: UserReport

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(report.type.capitalized, systemImage: report.type == "comment" ? "bubble.left" : "doc.text")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                statusBadge
            }
            Text(report.reason)
                .font(.subheadline.weight(.medium))
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(report.createdAt, style: .relative)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var statusBadge: some View {
        let color: Color = report.status == "pending" ? .orange : (report.status == "actioned" ? .red : .green)
        Text(report.status.capitalized)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color)
            .clipShape(Capsule())
    }
}

private struct ReportDetailView: View {
    let report: UserReport
    @Environment(\.dismiss) var dismiss
    @Environment(AuthenticationManager.self) var authManager

    @State private var contentText: String = "Loading…"
    @State private var contentOwnerId: String?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Reported Content") {
                    Text(contentText)
                        .font(.body)
                        .textSelection(.enabled)
                    if let owner = contentOwnerId {
                        Text("Author UID: \(owner)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                Section("Report") {
                    LabeledContent("Type", value: report.type)
                    LabeledContent("Reason", value: report.reason)
                    LabeledContent("Reporter UID", value: report.reportedByUserId)
                    LabeledContent("Status", value: report.status)
                    LabeledContent("Filed", value: report.createdAt.formatted())
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.caption)
                }

                Section("Actions") {
                    Button(role: .destructive) {
                        Task { await deleteContent() }
                    } label: {
                        Label("Delete \(report.type.capitalized)", systemImage: "trash")
                    }
                    .disabled(isWorking)

                    Button {
                        Task { await markStatus("actioned") }
                    } label: {
                        Label("Mark as Actioned", systemImage: "checkmark.shield")
                    }
                    .disabled(isWorking)

                    Button {
                        Task { await markStatus("reviewed") }
                    } label: {
                        Label("Dismiss (Mark Reviewed)", systemImage: "checkmark")
                    }
                    .disabled(isWorking)
                }
            }
            .navigationTitle("Report Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await loadContent() }
        }
    }

    private func loadContent() async {
        do {
            let (text, owner) = try await FirestoreManager.shared.fetchReportedContent(report: report)
            contentText = text
            contentOwnerId = owner
        } catch {
            contentText = "Could not load content (may have been deleted)."
        }
    }

    private func markStatus(_ status: String) async {
        guard let id = report.id else { return }
        isWorking = true
        errorMessage = nil
        do {
            try await FirestoreManager.shared.updateReportStatus(reportId: id, status: status)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }

    private func deleteContent() async {
        guard let id = report.id else { return }
        isWorking = true
        errorMessage = nil
        do {
            try await FirestoreManager.shared.deleteReportedContent(report: report)
            try await FirestoreManager.shared.updateReportStatus(reportId: id, status: "actioned")
            HapticManager.shared.notification(.success)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }
}
