//
//  ReactivateAccountView.swift
//  Parent Chat
//
//  Shown when a deactivated user signs back in. They can either reactivate
//  (clears the flag and resumes the app) or sign out to leave the account
//  in a deactivated state.
//

import SwiftUI

struct ReactivateAccountView: View {
    @Environment(AuthenticationManager.self) var authManager

    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.surfacePrimary.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)

                VStack(spacing: 10) {
                    Text("Welcome back")
                        .font(.title.bold())
                    Text("Your account is deactivated. Reactivate to restore your profile and content. Your data was kept safe while you were away.")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 24)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        Task { await reactivate() }
                    } label: {
                        Group {
                            if isWorking {
                                ProgressView().tint(.white)
                            } else {
                                Text("Reactivate Account")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.brandPrimary)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isWorking)

                    Button("Sign Out") {
                        authManager.signOut()
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    private func reactivate() async {
        isWorking = true
        errorMessage = nil
        do {
            try await authManager.reactivateAccount()
        } catch {
            errorMessage = "Could not reactivate: \(error.localizedDescription)"
            isWorking = false
        }
    }
}

#Preview {
    ReactivateAccountView()
        .environment(AuthenticationManager())
}
