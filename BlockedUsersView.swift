//
//  BlockedUsersView.swift
//  Parent Chat
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct BlockedUsersView: View {
    @Environment(AuthenticationManager.self) var authManager
    @State private var blockedUsers: [BlockedUser] = []
    @State private var isLoading = false
    @State private var unblockingId: String?
    @State private var blockedUsersListener: ListenerRegistration?

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
            } else if blockedUsers.isEmpty {
                emptyState
            } else {
                blockedList
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .task { startBlockedUsersListener() }
        .onDisappear {
            blockedUsersListener?.remove()
            blockedUsersListener = nil
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.fill.checkmark")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No Blocked Users")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Users you block won't be able to interact with your content.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var blockedList: some View {
        List {
            Section {
                ForEach(blockedUsers) { blocked in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.brandSecondary.opacity(0.2))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(String(blocked.blockedUserName.prefix(1)).uppercased())
                                    .font(.headline)
                                    .foregroundStyle(Color.brandSecondary)
                            )

                        Text(blocked.blockedUserName)
                            .font(.body)

                        Spacer()

                        Button {
                            Task { await unblock(blocked) }
                        } label: {
                            if unblockingId == blocked.blockedUserId {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Unblock")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.brandPrimary)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(unblockingId == blocked.blockedUserId)
                    }
                    .padding(.vertical, 4)
                }
            } footer: {
                Text("Blocked users cannot see your posts or send you messages.")
            }
        }
    }

    private func startBlockedUsersListener() {
        guard let uid = authManager.currentUser?.uid else { return }
        blockedUsersListener?.remove()
        isLoading = true
        blockedUsersListener = FirestoreManager.shared.listenToBlockedUsers(userId: uid) { updated in
            DispatchQueue.main.async {
                blockedUsers = updated
                isLoading = false
            }
        } onError: { _ in
            DispatchQueue.main.async {
                isLoading = false
            }
        }
    }

    private func unblock(_ blocked: BlockedUser) async {
        guard let uid = authManager.currentUser?.uid else { return }
        unblockingId = blocked.blockedUserId
        try? await FirestoreManager.shared.unblockUser(blockingUserId: uid, blockedUserId: blocked.blockedUserId)
        HapticManager.shared.notification(.success)
        unblockingId = nil
    }
}

#Preview {
    NavigationStack {
        BlockedUsersView()
            .environment(AuthenticationManager())
    }
}
