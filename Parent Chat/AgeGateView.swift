//
//  AgeGateView.swift
//  Parent Chat
//
//  Age assurance gate shown before a user can set up a profile or use the app.
//  Parent Chat is an adults-only (18+) community. We verify with a date-of-birth
//  check but persist ONLY a boolean confirmation (never the DOB) to minimize PII.
//

import SwiftUI
import FirebaseAuth

struct AgeGateView: View {
    @Environment(AuthenticationManager.self) var authManager

    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
    }

    private var isAdult: Bool { age >= 18 }

    var body: some View {
        ZStack {
            Color.surfacePrimary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.brandPrimary)
                        Text("Confirm your age")
                            .font(.title.bold())
                        Text("Parent Chat is for adults (18 and older) only. Confirm your date of birth to continue. We don't store your date of birth — only that you confirmed you're 18 or older.")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.top, 24)

                    DatePicker(
                        "Date of birth",
                        selection: $birthDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                    if !isAdult {
                        Label("You must be at least 18 years old to use Parent Chat.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    VStack(spacing: 10) {
                        Button {
                            Task { await confirm() }
                        } label: {
                            Group {
                                if isSubmitting {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Continue").fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isAdult && !isSubmitting ? Color.brandPrimary : Color.textTertiary)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!isAdult || isSubmitting)

                        Button("Sign Out") {
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

    private func confirm() async {
        guard isAdult, let uid = authManager.currentUser?.uid else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            try await FirestoreManager.shared.setAgeConfirmed(uid: uid)
            try await authManager.refreshCurrentUser()
        } catch {
            errorMessage = "Could not save. Check your connection and try again."
            isSubmitting = false
        }
    }
}

#Preview {
    AgeGateView()
        .environment(AuthenticationManager())
}
