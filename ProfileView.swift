//
//  ProfileView.swift
//  Parent Chat
//
//  User Profile Tab View
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(AppearanceManager.self) var appearanceManager
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var savedPosts: [Post] = []
    @State private var pendingDeleteIds: Set<String> = []
    @State private var isLoadingStats = true
    @State private var savedPostsListener: ListenerRegistration?

    private var savedPostsCount: Int { savedPosts.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Cover banner + profile picture
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [Color.brandPrimary, Color.brandSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 160)

                    profileImageView
                        .padding(.leading, 16)
                        .offset(y: 44)
                }

                // Info section
                VStack(alignment: .leading, spacing: 6) {
                    Spacer().frame(height: 52)

                    if let displayName = authManager.userProfile?.displayName {
                        Text(displayName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                    }

                    if let username = authManager.userProfile?.username {
                        Text("@\(username)")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                    }

                    if let bio = authManager.userProfile?.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.body)
                            .foregroundStyle(Color.textSecondary)
                            .padding(.top, 2)
                    }

                    if let createdAt = authManager.userProfile?.createdAt {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text("Joined \(createdAt.formatted(date: .abbreviated, time: .omitted))")
                        }
                        .font(.caption)
                        .foregroundStyle(Color.textTertiary)
                        .padding(.top, 2)
                    }

                    // Action buttons
                    HStack(spacing: 8) {
                        Button {
                            showEditProfile = true
                            HapticManager.shared.impact(.light)
                        } label: {
                            Text("Edit Profile")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.surfaceSecondary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 42, height: 36)
                                .background(Color.surfaceSecondary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 10)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)

                Divider()

                HStack(spacing: 0) {
                    if isLoadingStats {
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.surfaceSecondary)
                                .frame(width: 32, height: 22)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.surfaceSecondary)
                                .frame(width: 56, height: 13)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.sm)
                    } else {
                        StatItem(value: "\(savedPostsCount)", label: "Saved Posts")
                    }
                }
                .padding(.vertical, 4)
                .background(Color.surfacePrimary)

                Divider()

                // Saved posts — each saved post rendered inline
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Saved Posts", systemImage: "bookmark.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Text("\(savedPostsCount)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if isLoadingStats {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else if savedPosts.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "bookmark")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("No saved posts")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Posts you save will appear here")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(savedPosts) { post in
                                PostRowView(post: post, removeOnUnsave: true) {
                                    if let id = post.id {
                                        pendingDeleteIds.insert(id)
                                    }
                                    withAnimation {
                                        savedPosts.removeAll { $0.id == post.id }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Color.clear.frame(height: 24)
            }
        }
        .background(Color.surfacePrimary)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            if let profile = authManager.userProfile {
                EditProfileView(userProfile: profile)
                    .environment(authManager)
            } else {
                NavigationStack {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading profile...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle("Edit Profile")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showEditProfile = false }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(appearanceManager: appearanceManager)
                .environment(authManager)
        }
        .task {
            startSavedPostsListener()
        }
        .refreshable {
            startSavedPostsListener()
        }
        .onDisappear {
            savedPostsListener?.remove()
            savedPostsListener = nil
        }
    }

    private func startSavedPostsListener() {
        guard let userId = authManager.currentUser?.uid else {
            isLoadingStats = false
            return
        }
        savedPostsListener?.remove()
        isLoadingStats = true

        savedPostsListener = FirestoreManager.shared.listenToSavedPosts(userId: userId) { updated in
            DispatchQueue.main.async {
                savedPosts = updated.filter { post in
                    guard let id = post.id else { return true }
                    return !pendingDeleteIds.contains(id)
                }
                isLoadingStats = false
            }
        } onError: { _ in
            DispatchQueue.main.async {
                isLoadingStats = false
            }
        }
    }

    @ViewBuilder
    private var profileImageView: some View {
        if let urlString = authManager.userProfile?.profileImageUrl,
           let url = URL.httpsOnly(urlString) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ZStack {
                    Circle().fill(Color.primaryGradient)
                    ProgressView().tint(.white)
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.surfacePrimary, lineWidth: 4))
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        } else {
            ZStack {
                Circle()
                    .fill(Color.primaryGradient)
                    .frame(width: 88, height: 88)
                Text(authManager.userProfile?.avatarCharacter ?? "?")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
            }
            .overlay(Circle().stroke(Color.surfacePrimary, lineWidth: 4))
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        }
    }
}

struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Text(value)
                .font(AppTypography.heading3)
                .foregroundStyle(Color.textPrimary)

            Text(label)
                .font(AppTypography.labelMedium)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environment(AuthenticationManager())
    }
}
