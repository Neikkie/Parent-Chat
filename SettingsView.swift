//
//  SettingsView.swift
//  Parent Chat
//
//  Created by Shanique Beckford on 4/11/26.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AuthenticationManager.self) var authManager
    @Bindable var appearanceManager: AppearanceManager
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showSavedPosts = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @State private var pendingReportsCount = 0
    @State private var pendingReportsListener: ListenerRegistration?
    @State private var showDeactivateAlert = false
    @State private var isDeactivating = false
    @State private var deactivateError: String?
    
    var currentUser: User? {
        Auth.auth().currentUser
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Profile Section
                Section {
                    NavigationLink {
                        ProfileView()
                            .environment(authManager)
                    } label: {
                        HStack(spacing: 16) {
                            // Profile Image
                            if let urlString = authManager.userProfile?.profileImageUrl,
                               let url = URL.httpsOnly(urlString) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [.blue, .purple],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                        
                                        ProgressView()
                                            .tint(.white)
                                    }
                                }
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 60, height: 60)
                                    
                                    Text(authManager.userProfile?.avatarCharacter ?? userInitials)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                if let username = authManager.userProfile?.username {
                                    Text("@\(username)")
                                        .font(.headline)
                                } else {
                                    Text(currentUser?.displayName ?? "Parent User")
                                        .font(.headline)
                                }
                                
                                Text(currentUser?.email ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                                .font(.caption)
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("Profile")
                }
                
                // Content Section
                Section {
                    NavigationLink {
                        SavedPostsView()
                    } label: {
                        Label("Saved Posts", systemImage: "bookmark.fill")
                    }
                    
                    NavigationLink {
                        SavedActivitiesView()
                    } label: {
                        Label("Saved Activities", systemImage: "bookmark.circle.fill")
                    }

                    NavigationLink {
                        NotificationsSettingsView()
                    } label: {
                        Label("Notifications", systemImage: "bell.fill")
                    }
                } header: {
                    Text("Content")
                }

                // Preferences Section
                Section {
                    Picker(selection: $appearanceManager.selectedMode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            HStack(spacing: 8) {
                                Image(systemName: mode.icon)
                                Text(mode.rawValue)
                            }
                            .tag(mode)
                        }
                    } label: {
                        Label("Appearance", systemImage: "paintbrush.fill")
                    }
                    .onChange(of: appearanceManager.selectedMode) { _, _ in
                        HapticManager.shared.selection()
                    }

                    NavigationLink {
                        PrivacySettingsView()
                    } label: {
                        Label("Privacy", systemImage: "lock.fill")
                    }
                    
                    NavigationLink {
                        CommunitySafetyView()
                    } label: {
                        Label("Community Safety", systemImage: "shield.lefthalf.filled")
                    }

                    NavigationLink {
                        BlockedUsersView()
                            .environment(authManager)
                    } label: {
                        Label("Blocked Users", systemImage: "person.fill.xmark")
                    }

                    if authManager.isAdmin {
                        NavigationLink {
                            AdminReportsView()
                                .environment(authManager)
                        } label: {
                            HStack {
                                Label("Moderation Inbox", systemImage: "tray.fill")
                                Spacer()
                                if pendingReportsCount > 0 {
                                    Text("\(pendingReportsCount)")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.red)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                } header: {
                    Text("Preferences")
                }

                // Support Section
                Section {
                    Link(destination: URL(string: "mailto:support.chaniiapps@gmail.com?subject=Parent%20Chat%20Support")!) {
                        HStack {
                            Label("Contact Support", systemImage: "envelope.fill")
                            Spacer()
                            Text("support.chaniiapps@gmail.com")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Link(destination: URL(string: "mailto:support.chaniiapps@gmail.com?subject=Parent%20Chat%20Feedback")!) {
                        Label("Send Feedback", systemImage: "bubble.left.and.bubble.right.fill")
                    }

                    NavigationLink {
                        HelpCenterView()
                    } label: {
                        Label("Help Center", systemImage: "questionmark.circle.fill")
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle.fill")
                    }
                } header: {
                    Text("Support & Feedback")
                }
                
                // Account Section
                Section {
                    Button(role: .destructive) {
                        showSignOutAlert = true
                    } label: {
                        Label("Sign Out", systemImage: "arrow.right.square.fill")
                    }

                    Button {
                        showDeactivateAlert = true
                    } label: {
                        if isDeactivating {
                            HStack {
                                ProgressView().controlSize(.small)
                                Text("Deactivating…")
                            }
                        } else {
                            Label("Deactivate Account", systemImage: "pause.circle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                    .disabled(isDeactivating || isDeletingAccount)

                    Button(role: .destructive) {
                        showDeleteAccountAlert = true
                    } label: {
                        if isDeletingAccount {
                            HStack {
                                ProgressView().controlSize(.small)
                                Text("Deleting Account...")
                            }
                        } else {
                            Label("Delete Account", systemImage: "trash.fill")
                        }
                    }
                    .disabled(isDeletingAccount || isDeactivating)

                    if let deleteAccountError {
                        Text(deleteAccountError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    if let deactivateError {
                        Text(deactivateError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Account")
                } footer: {
                    VStack(spacing: 8) {
                        Text("Parent Chat v\(appVersion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Made with ❤️ for parents")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                guard authManager.isAdmin else { return }
                pendingReportsListener?.remove()
                pendingReportsListener = FirestoreManager.shared.listenToReports { reports in
                    DispatchQueue.main.async {
                        pendingReportsCount = reports.filter { $0.status == "pending" }.count
                    }
                } onError: { _ in }
            }
            .onDisappear {
                pendingReportsListener?.remove()
                pendingReportsListener = nil
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    authManager.signOut()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Forever", role: .destructive) {
                    Task {
                        isDeletingAccount = true
                        deleteAccountError = nil
                        do {
                            try await authManager.deleteAccount()
                            dismiss()
                        } catch {
                            deleteAccountError = "Failed to delete account. Please sign out and sign back in, then try again."
                        }
                        isDeletingAccount = false
                    }
                }
            } message: {
                Text("This will permanently delete your account, posts, and all associated data. This action cannot be undone.")
            }
            .alert("Deactivate Account", isPresented: $showDeactivateAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Deactivate") {
                    Task {
                        isDeactivating = true
                        deactivateError = nil
                        do {
                            try await authManager.deactivateAccount()
                            dismiss()
                        } catch {
                            deactivateError = "Could not deactivate: \(error.localizedDescription)"
                        }
                        isDeactivating = false
                    }
                }
            } message: {
                Text("Your posts and profile will be hidden and shown as \"Deactivated user\" until you sign back in and reactivate. Your data is not deleted — you can come back anytime.")
            }
        }
        .environment(appearanceManager)
    }
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var userInitials: String {
        guard let name = currentUser?.displayName else { return "U" }
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(1)).uppercased()
        }
        return "U"
    }
}

#Preview {
    SettingsView(appearanceManager: AppearanceManager())
        .environment(AuthenticationManager())
}
