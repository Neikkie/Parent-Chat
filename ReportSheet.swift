//
//  ReportSheet.swift
//  Parent Chat
//

import SwiftUI

enum ReportTarget {
    case post(id: String)
    case comment(id: String)
}

struct ReportSheet: View {
    let target: ReportTarget
    let reportedByUserId: String
    @Environment(\.dismiss) var dismiss

    @State private var selectedReason: String?
    @State private var isSubmitting = false
    @State private var submitted = false

    let reasons = [
        "Spam or misleading",
        "Inappropriate or offensive",
        "Harassment or bullying",
        "Misinformation",
        "Endangers a child",
        "Other"
    ]

    var body: some View {
        NavigationStack {
            if submitted {
                successView
            } else {
                reasonList
            }
        }
    }

    private var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Report Submitted")
                .font(.title2).fontWeight(.bold)
            Text("Thank you. Our team will review this content and take appropriate action.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Done") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private var reasonList: some View {
        List {
            Section {
                ForEach(reasons, id: \.self) { reason in
                    Button {
                        HapticManager.shared.selection()
                        selectedReason = reason
                    } label: {
                        HStack {
                            Text(reason)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedReason == reason {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.brandPrimary)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Why are you reporting this?")
            } footer: {
                Text("Reports are confidential. The person you report won't be notified.")
            }
        }
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await submitReport() }
                } label: {
                    if isSubmitting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Submit").fontWeight(.semibold)
                    }
                }
                .disabled(selectedReason == nil || isSubmitting)
            }
        }
    }

    private func submitReport() async {
        guard let reason = selectedReason else { return }
        isSubmitting = true
        do {
            switch target {
            case .post(let id):
                try await FirestoreManager.shared.reportPost(postId: id, reportedByUserId: reportedByUserId, reason: reason)
            case .comment(let id):
                try await FirestoreManager.shared.reportComment(commentId: id, reportedByUserId: reportedByUserId, reason: reason)
            }
            HapticManager.shared.notification(.success)
            withAnimation { submitted = true }
        } catch {
            HapticManager.shared.notification(.error)
        }
        isSubmitting = false
    }
}
