//
//  EULAAcceptanceView.swift
//  Parent Chat
//
//  Required acknowledgement shown to every user on first sign-in before they
//  can post, comment, or upload. Records acceptance to Firestore so it carries
//  across devices. Required for Apple App Review (§1.2 UGC apps).
//

import SwiftUI
import FirebaseAuth

/// Bump this when the community agreement text changes. Users who accepted a
/// prior version will be re-prompted on next launch.
let CURRENT_EULA_VERSION = "2026-08-16"

struct EULAAcceptanceView: View {
    @Environment(AuthenticationManager.self) var authManager

    @State private var isAdult = false
    @State private var hasRightsToShare = false
    @State private var noObjectionable = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var canAgree: Bool {
        isAdult && hasRightsToShare && noObjectionable && !isSubmitting
    }

    var body: some View {
        ZStack {
            Color.surfacePrimary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.brandPrimary)
                        Text("Community Agreement")
                            .font(.title.bold())
                        Text("Before you can post, please read and accept these terms. They keep our community safe.")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 14) {
                        AgreementRow(
                            isChecked: $isAdult,
                            title: "I am 18 years or older",
                            description: "Parent Chat is for adults only."
                        )
                        AgreementRow(
                            isChecked: $hasRightsToShare,
                            title: "I have the right to share what I post",
                            description: "I will only upload photos or videos I own or have permission to share. If a child appears, I am their parent or legal guardian and consent to sharing it. Media may be reviewed and removed."
                        )
                        AgreementRow(
                            isChecked: $noObjectionable,
                            title: "I will not post abusive or exploitative content",
                            description: "Harassment, threats, hate speech, and sexual content are not allowed. Any sexual or exploitative imagery of a minor is strictly prohibited, reported, and results in immediate removal."
                        )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("How moderation works")
                            .font(.subheadline.weight(.semibold))
                        Text("All reports are reviewed within 24 hours. Posts that violate community guidelines are removed immediately, and repeat offenders are removed from the platform.")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(12)
                    .background(Color.surfaceSecondary)
                    .cornerRadius(10)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    VStack(spacing: 10) {
                        Button {
                            Task { await accept() }
                        } label: {
                            Group {
                                if isSubmitting {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("I Agree")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(canAgree ? Color.brandPrimary : Color.textTertiary)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!canAgree)

                        Button("Decline and Sign Out") {
                            authManager.signOut()
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .readableWidth()
            }
        }
    }

    private func accept() async {
        guard let uid = authManager.currentUser?.uid else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            try await FirestoreManager.shared.setEulaAccepted(uid: uid, version: CURRENT_EULA_VERSION)
            try await authManager.refreshCurrentUser()
        } catch {
            errorMessage = "Could not save your agreement. Check your connection and try again."
            isSubmitting = false
        }
    }
}

private struct AgreementRow: View {
    @Binding var isChecked: Bool
    let title: String
    let description: String

    var body: some View {
        Button {
            isChecked.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(isChecked ? Color.brandPrimary : Color.textTertiary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    EULAAcceptanceView()
        .environment(AuthenticationManager())
}
