//
//  CommunityView.swift
//  Parent Chat
//
//  Created by Shanique Beckford on 4/11/26.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import AVKit
import AVFoundation
import UIKit

// MARK: - Main Community View

struct CommunityView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(AppearanceManager.self) var appearanceManager
    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var showAddPost = false
    @State private var showSettings = false
    @State private var showNotifications = false
    @State private var showMessages = false
    @State private var isSearchActive = false
    @State private var searchText = ""
    @State private var postsListener: ListenerRegistration?
    @State private var pendingDeleteIds: Set<String> = []

    var displayedPosts: [Post] {
        guard !searchText.isEmpty else { return posts }
        return posts.filter {
            $0.content.localizedCaseInsensitiveContains(searchText) ||
            $0.userName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if isSearchActive {
                SearchHeaderView(
                    searchText: $searchText,
                    onCancel: {
                        searchText = ""
                        isSearchActive = false
                    }
                )
            } else {
                FeedHeaderView(
                    onSearchTap: {
                        HapticManager.shared.selection()
                        isSearchActive = true
                    },
                    onMessagesTap: {
                        HapticManager.shared.selection()
                        showMessages = true
                    },
                    onNotificationsTap: { showNotifications = true },
                    onSettingsTap: { showSettings = true }
                )
            }

            Divider()

            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if isLoading {
                            ForEach(0..<3, id: \.self) { _ in
                                PostCardSkeleton()
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                Divider()
                            }
                        } else if isSearchActive && displayedPosts.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 42))
                                    .foregroundStyle(Color.textTertiary)
                                Text(searchText.isEmpty
                                     ? "Type to search posts"
                                     : "No results for \"\(searchText)\"")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                        } else if posts.isEmpty && !isSearchActive {
                            FeedEmptyStateView(onCreatePost: {
                                showAddPost = true
                            })
                        } else {
                            ForEach(displayedPosts) { post in
                                PostRowView(post: post, onDelete: {
                                    if let id = post.id {
                                        pendingDeleteIds.insert(id)
                                    }
                                    withAnimation {
                                        posts.removeAll { $0.id == post.id }
                                    }
                                })
                                .padding(.vertical, 4)
                                Divider()
                            }
                        }

                        Color.clear.frame(height: 100)
                    }
                    .readableWidth()
                }
                .refreshable {
                    HapticManager.shared.impact(.light)
                    await loadPosts()
                }

                // FAB — visible when posts exist and not searching
                if !posts.isEmpty && !isSearchActive {
                    Button {
                        HapticManager.shared.impact(.medium)
                        showAddPost = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                Circle()
                                    .fill(Color.primaryGradient)
                                    .shadow(color: Color.brandPrimary.opacity(0.4), radius: 12, x: 0, y: 6)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .sheet(isPresented: $showAddPost) {
            AddPostView()
                .environment(authManager)
        }
        .sheet(isPresented: $showNotifications) {
            NavigationStack {
                NotificationsSettingsView()
            }
        }
        .sheet(isPresented: $showMessages) {
            ConversationsView()
                .environment(authManager)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(appearanceManager: appearanceManager)
                .environment(authManager)
        }
        .task {
            startPostsListener()
        }
        .onDisappear {
            stopPostsListener()
        }
    }

    private func loadPosts() async {
        isLoading = true
        do {
            posts = try await FirestoreManager.shared.fetchPosts()
        } catch {}
        isLoading = false
    }
    
    private func startPostsListener() {
        stopPostsListener()
        isLoading = true
        
        postsListener = FirestoreManager.shared.listenToPosts { updatedPosts in
            DispatchQueue.main.async {
                withAnimation {
                    posts = updatedPosts.filter { post in
                        guard let id = post.id else { return true }
                        return !pendingDeleteIds.contains(id)
                    }
                }
                isLoading = false
            }
        } onError: { _ in
            DispatchQueue.main.async {
                isLoading = false
            }
        }
    }
    
    private func stopPostsListener() {
        postsListener?.remove()
        postsListener = nil
    }
}

// MARK: - Community Header

struct FeedHeaderView: View {
    let onSearchTap: () -> Void
    let onMessagesTap: () -> Void
    let onNotificationsTap: () -> Void
    let onSettingsTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("ParentChat")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.brandPrimary, Color.brandSecondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Spacer()

            // Liquid Glass icon cluster (iOS 26).
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    CircleIconButton(icon: "magnifyingglass", action: onSearchTap)
                    CircleIconButton(icon: "paperplane", action: onMessagesTap)
                    CircleIconButton(icon: "bell", action: onNotificationsTap)
                    CircleIconButton(icon: "gear", action: onSettingsTap)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.surfacePrimary)
    }
}

// MARK: - Search Header

struct SearchHeaderView: View {
    @Binding var searchText: String
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.textSecondary)
                    .font(.system(size: 15))
                TextField("Search updates...", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.surfaceSecondary)
            .cornerRadius(10)

            Button("Cancel", action: onCancel)
                .foregroundStyle(Color.brandPrimary)
                .font(.system(size: 15, weight: .medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.surfacePrimary)
        .onAppear { isFocused = true }
    }
}

// MARK: - Circle Icon Button

struct CircleIconButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 40, height: 40)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

struct FeedEmptyStateView: View {
    let onCreatePost: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.15), .purple.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("Your community is quiet")
                    .font(.title2.bold())
                Text("Be the first to share an update with other parents!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: onCreatePost) {
                Label("Share Update", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.top, 60)
        .padding(.horizontal, 32)
    }
}

// MARK: - Post Row

struct PostRowView: View {
    let post: Post
    let onDelete: () -> Void
    let removeOnUnsave: Bool
    @Environment(AuthenticationManager.self) var authManager

    @State private var isLiked = false
    @State private var isSaved = false
    @State private var liveLikesCount: Int
    @State private var liveCommentsCount: Int
    @State private var likesCountListener: ListenerRegistration?
    @State private var commentsCountListener: ListenerRegistration?
    @State private var showComments = false
    @State private var showLocationPreview = false
    @State private var isProcessingLike = false
    @State private var isProcessingSave = false
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var showReportSheet = false
    @State private var showBlockAlert = false
    @State private var showActionSheet = false
    @State private var showChat = false
    @State private var saveErrorMessage: String?
    @State private var deleteErrorMessage: String?
    @State private var liveAuthorName: String?

    init(post: Post, removeOnUnsave: Bool = false, onDelete: @escaping () -> Void = {}) {
        self.post = post
        self.removeOnUnsave = removeOnUnsave
        self.onDelete = onDelete
        self._liveLikesCount = State(initialValue: post.likesCount)
        self._liveCommentsCount = State(initialValue: post.commentsCount)
    }

    var shareText: String {
        var text = post.content
        if let location = post.location {
            text += "\n\n📍 \(location.name)"
        }
        return text
    }
    
    private var postTimestamp: String {
        let seconds = Int(Date().timeIntervalSince(post.createdAt))
        
        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            return "\(seconds / 60)m"
        } else if seconds < 86_400 {
            return "\(seconds / 3600)h"
        } else {
            return "\(seconds / 86_400)d"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User info
            HStack {
                authorAvatar

                VStack(alignment: .leading, spacing: 2) {
                    Text(authorDisplayName)
                        .font(.headline)

                    Text(postTimestamp)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    print("🔘 ellipsis tapped for post \(post.id ?? "nil") — isOwner=\(post.userId == authManager.currentUser?.uid)")
                    HapticManager.shared.impact(.light)
                    showActionSheet = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            // Post content
            Text(post.content)
                .font(.body)

            // Media content
            if let media = post.media, !media.isEmpty {
                MediaGridView(media: media)
            }

            // Location
            if let location = post.location {
                Button {
                    showLocationPreview = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)

                        Text(location.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            // Interaction buttons
            HStack(spacing: 24) {
                Button {
                    Task { await toggleLike() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundStyle(isLiked ? .red : .primary)
                            .symbolEffect(.bounce, value: isLiked)

                        Text("\(liveLikesCount)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(isProcessingLike)

                Button {
                    showComments = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.right")

                        Text("\(liveCommentsCount)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }

                Spacer()

                Button {
                    Task { await toggleSave() }
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(isSaved ? .blue : .primary)
                        .symbolEffect(.bounce, value: isSaved)
                }
                .disabled(isProcessingSave)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // Tapping anywhere on the card (except the interactive controls,
            // which handle their own taps) opens the post detail.
            HapticManager.shared.selection()
            showComments = true
        }
        .contextMenu {
            if canDelete {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Delete Post", systemImage: "trash")
                }
            }
            if post.userId != authManager.currentUser?.uid {
                Button {
                    showChat = true
                } label: {
                    Label("Message \(authorDisplayName)", systemImage: "bubble.left")
                }
                Button {
                    showReportSheet = true
                } label: {
                    Label("Report Post", systemImage: "flag")
                }
                Button(role: .destructive) {
                    showBlockAlert = true
                } label: {
                    Label("Block \(post.displayName)", systemImage: "person.fill.xmark")
                }
            }
        }
        .task {
            await checkIfLiked()
            await checkIfSaved()
            startCountListeners()
            await resolveAuthorName()
        }
        .onDisappear {
            likesCountListener?.remove()
            likesCountListener = nil
            commentsCountListener?.remove()
            commentsCountListener = nil
        }
        .sheet(isPresented: $showComments) {
            CommentsView(post: post)
                .environment(authManager)
        }
        .sheet(isPresented: $showLocationPreview) {
            if let location = post.location {
                LocationPreviewView(location: location)
            }
        }
        .confirmationDialog("", isPresented: $showActionSheet, titleVisibility: .hidden) {
            if canDelete {
                Button("Delete Post", role: .destructive) {
                    // Delay so the confirmationDialog fully dismisses before
                    // the alert tries to present — avoids a SwiftUI bug where
                    // chained presentations silently drop the second one.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        showDeleteAlert = true
                    }
                }
            }
            if post.userId != authManager.currentUser?.uid {
                Button("Message \(authorDisplayName)") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        showChat = true
                    }
                }
                Button("Report Post") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        showReportSheet = true
                    }
                }
                Button("Block \(post.displayName)", role: .destructive) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        showBlockAlert = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Post", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deletePost() }
            }
        } message: {
            Text("Are you sure you want to delete this post? This action cannot be undone.")
        }
        .alert("Block \(post.displayName)?", isPresented: $showBlockAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Block", role: .destructive) {
                Task { await blockUser() }
            }
        } message: {
            Text("You won't see posts from \(post.displayName). You can unblock them in Settings → Blocked Users.")
        }
        .sheet(isPresented: $showReportSheet) {
            if let postId = post.id, let uid = authManager.currentUser?.uid {
                ReportSheet(target: .post(id: postId), reportedByUserId: uid)
            }
        }
        .sheet(isPresented: $showChat) {
            NavigationStack {
                ChatView(otherUserId: post.userId, otherUserName: authorDisplayName)
                    .environment(authManager)
            }
        }
        .alert("Save Failed", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "Could not save this post.")
        }
        .alert("Delete Failed", isPresented: Binding(
            get: { deleteErrorMessage != nil },
            set: { if !$0 { deleteErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage ?? "Could not delete this post.")
        }
    }

    /// The signed-in user may delete a post if they authored it or are a
    /// moderator/admin (the Firestore rules already permit admin deletes).
    private var canDelete: Bool {
        post.userId == authManager.currentUser?.uid || authManager.isAdmin
    }

    /// What to render as the post author. Falls through the live directory
    /// lookup, then the stored display name (sanitized for legacy emails).
    private var authorDisplayName: String {
        liveAuthorName ?? post.displayName
    }

    /// Author avatar: real profile image when available, otherwise a gradient
    /// monogram derived from the display name.
    @ViewBuilder
    private var authorAvatar: some View {
        if let urlString = post.userProfileImageUrl, let url = URL.httpsOnly(urlString) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.surfaceSecondary
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
        } else {
            ZStack {
                Circle().fill(Color.primaryGradient)
                Text(String(authorDisplayName.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)
        }
    }

    private func resolveAuthorName() async {
        let resolved = await UserDirectory.shared.currentUsername(
            for: post.userId,
            fallback: post.displayName
        )
        liveAuthorName = resolved
    }

    private func checkIfLiked() async {
        guard let postId = post.id,
              let userId = authManager.currentUser?.uid else { return }
        isLiked = (try? await FirestoreManager.shared.hasUserLikedPost(postId: postId, userId: userId)) ?? false
    }

    private func checkIfSaved() async {
        guard let postId = post.id,
              let userId = authManager.currentUser?.uid else { return }
        isSaved = (try? await FirestoreManager.shared.isPostSaved(postId: postId, userId: userId)) ?? false
    }

    private func toggleSave() async {
        guard let postId = post.id,
              let userId = authManager.currentUser?.uid else { return }
        HapticManager.shared.impact(.light)
        isProcessingSave = true
        isSaved.toggle()
        do {
            let nowSaved = try await FirestoreManager.shared.toggleSavePost(postId: postId, userId: userId)
            isSaved = nowSaved
            if removeOnUnsave && !nowSaved {
                await MainActor.run { onDelete() }
            }
        } catch {
            isSaved.toggle()
            saveErrorMessage = error.localizedDescription
        }
        isProcessingSave = false
    }

    private func startCountListeners() {
        guard let postId = post.id else { return }
        likesCountListener?.remove()
        commentsCountListener?.remove()

        likesCountListener = FirestoreManager.shared.listenToPostLikesCount(postId: postId) { count in
            DispatchQueue.main.async {
                liveLikesCount = count
            }
        }
        commentsCountListener = FirestoreManager.shared.listenToPostCommentsCount(postId: postId) { count in
            DispatchQueue.main.async {
                liveCommentsCount = count
            }
        }
    }

    private func toggleLike() async {
        guard let postId = post.id,
              let user = authManager.currentUser else { return }
        HapticManager.shared.impact(isLiked ? .soft : .medium)
        isProcessingLike = true
        let wasLiked = isLiked
        isLiked.toggle()
        do {
            let userName = authManager.publicDisplayName
            let nowLiked = try await FirestoreManager.shared.toggleLikePost(
                postId: postId,
                userId: user.uid,
                userName: userName
            )
            isLiked = nowLiked
        } catch {
            isLiked = wasLiked
        }
        isProcessingLike = false
    }

    private func deletePost() async {
        guard let postId = post.id else {
            deleteErrorMessage = "Could not identify post. Please try again."
            return
        }
        isDeleting = true
        // Collect media URLs directly from the in-memory post object so we
        // don't need an extra Firestore read (which can fail for old documents).
        let mediaUrls: [String] = (post.media ?? []).flatMap { item -> [String] in
            var urls = [item.url]
            if let thumb = item.thumbnailUrl { urls.append(thumb) }
            return urls
        }
        print("🗑️ deletePost: postId=\(postId) mediaCount=\(mediaUrls.count)")
        do {
            try await FirestoreManager.shared.deletePost(postId: postId, mediaUrls: mediaUrls)
            HapticManager.shared.notification(.success)
            await MainActor.run { onDelete() }
        } catch {
            print("❌ deletePost failed: \(error.localizedDescription)")
            HapticManager.shared.notification(.error)
            deleteErrorMessage = error.localizedDescription
        }
        isDeleting = false
    }

    private func blockUser() async {
        guard let uid = authManager.currentUser?.uid else { return }
        try? await FirestoreManager.shared.blockUser(
            blockingUserId: uid,
            blockedUserId: post.userId,
            blockedUserName: post.displayName
        )
        HapticManager.shared.notification(.success)
        withAnimation { onDelete() }
    }
}

// MARK: - Media Grid

struct MediaGridView: View {
    let media: [PostMedia]

    var body: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]

        if media.count == 1 {
            MediaItemView(mediaItem: media[0], isFullWidth: true)
        } else {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(media) { mediaItem in
                    MediaItemView(mediaItem: mediaItem, isFullWidth: false)
                }
            }
        }
    }
}

// Coordinates single-video autoplay across the feed. The active (playing) video
// is the TOPMOST one that's at least half on-screen; everything else pauses.
// Mute is tracked per-video so each clip can be toggled independently.
@MainActor
@Observable
final class VideoPlaybackCoordinator {
    static let shared = VideoPlaybackCoordinator()
    private(set) var activeID: String?
    private var frames: [String: CGRect] = [:]
    private var mutedIDs: Set<String> = []

    private var screenBounds: CGRect {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen.bounds ?? .zero
    }

    /// Reports a video's frame in global coordinates as it scrolls.
    func report(_ id: String, frame: CGRect) {
        frames[id] = frame
        recompute()
    }

    func remove(_ id: String) {
        frames[id] = nil
        recompute()
    }

    private func recompute() {
        let screen = screenBounds
        var best: (id: String, minY: CGFloat)?
        for (id, frame) in frames {
            guard frame.height > 0 else { continue }
            let visibleHeight = min(frame.maxY, screen.maxY) - max(frame.minY, screen.minY)
            guard visibleHeight / frame.height >= 0.5 else { continue }
            if best == nil || frame.minY < best!.minY {
                best = (id, frame.minY)
            }
        }
        activeID = best?.id
    }

    // MARK: Per-video mute
    func isMuted(_ id: String) -> Bool { mutedIDs.contains(id) }
    func toggleMuted(_ id: String) {
        if mutedIDs.contains(id) {
            mutedIDs.remove(id)
        } else {
            mutedIDs.insert(id)
        }
    }
}

// Tracks whether the screen is being recorded or mirrored, so media can be
// hidden to deter downloading via screen capture.
@MainActor
@Observable
final class ScreenCaptureMonitor {
    static let shared = ScreenCaptureMonitor()
    var isCaptured = false

    private init() {
        refresh()
        NotificationCenter.default.addObserver(
            forName: UIScreen.capturedDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    private func refresh() {
        isCaptured = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .contains { $0.screen.isCaptured }
    }
}

// Hides its content behind a "protected" placeholder while the screen is being
// recorded or mirrored — the primary in-app deterrent against saving media.
private struct CaptureShieldModifier: ViewModifier {
    private let monitor = ScreenCaptureMonitor.shared

    func body(content: Content) -> some View {
        ZStack {
            if monitor.isCaptured {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: "eye.slash.fill")
                                .font(.title2)
                            Text("Protected content")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    )
            } else {
                content
            }
        }
    }
}

private extension View {
    func captureShielded() -> some View { modifier(CaptureShieldModifier()) }
}

struct MediaItemView: View {
    let mediaItem: PostMedia
    let isFullWidth: Bool

    private let coordinator = VideoPlaybackCoordinator.shared

    private var height: CGFloat { isFullWidth ? 300 : 150 }
    private var isActiveVideo: Bool { coordinator.activeID == mediaItem.id }

    var body: some View {
        Group {
            if mediaItem.type == .image {
                AsyncImage(url: URL.httpsOnly(mediaItem.url)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .captureShielded()
            } else if mediaItem.type == .video, let url = URL.httpsOnly(mediaItem.url) {
                // Muted, looping inline preview. Autoplays only while on-screen
                // and only if it's the single active video (coordinator).
                InlineLoopingVideoView(url: url, isActive: isActiveVideo, isMuted: coordinator.isMuted(mediaItem.id))
                    .frame(height: height)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .captureShielded()
                    .overlay(alignment: .bottomTrailing) {
                        // Per-video mute toggle. As a Button it consumes its own
                        // tap, so it never triggers anything else, and each clip's
                        // mute state is tracked independently by the coordinator.
                        Button {
                            coordinator.toggleMuted(mediaItem.id)
                            HapticManager.shared.selection()
                        } label: {
                            Image(systemName: coordinator.isMuted(mediaItem.id) ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.black.opacity(0.45), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                    }
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .global)
                    } action: { frame in
                        coordinator.report(mediaItem.id, frame: frame)
                    }
                    .onDisappear { coordinator.remove(mediaItem.id) }
            }
        }
    }
}

// Inline, seamlessly-looping preview backed by AVPlayerLayer. Playback and mute
// are driven from SwiftUI so only the on-screen active video plays.
struct InlineLoopingVideoView: UIViewRepresentable {
    let url: URL
    var isActive: Bool
    var isMuted: Bool

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        let view = LoopingPlayerUIView(url: url)
        view.setMuted(isMuted)
        view.setActive(isActive)
        return view
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {
        uiView.setMuted(isMuted)
        uiView.setActive(isActive)
    }

    static func dismantleUIView(_ uiView: LoopingPlayerUIView, coordinator: ()) {
        uiView.stop()
    }
}

final class LoopingPlayerUIView: UIView {
    private var queuePlayer: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private let playerLayer = AVPlayerLayer()
    private var active = false

    init(url: URL) {
        super.init(frame: .zero)
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = true
        player.actionAtItemEnd = .none
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
        looper = AVPlayerLooper(player: player, templateItem: item)
        queuePlayer = player
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    func setMuted(_ muted: Bool) {
        queuePlayer?.isMuted = muted
    }

    func setActive(_ isActive: Bool) {
        guard isActive != active else { return }
        active = isActive
        if isActive {
            // Route to playback so audio is audible even with the silent switch on.
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
            queuePlayer?.play()
        } else {
            queuePlayer?.pause()
        }
    }

    func stop() {
        queuePlayer?.pause()
        queuePlayer?.removeAllItems()
        looper?.disableLooping()
    }
}

// Full-screen in-app video player: autoplays with sound and controls.
struct VideoPlayerView: View {
    let url: URL
    @Environment(\.dismiss) var dismiss
    @State private var player = AVPlayer()

    var body: some View {
        NavigationStack {
            VideoPlayer(player: player)
                .ignoresSafeArea()
                .captureShielded()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .onAppear {
                    // Play with sound even if the ring/silent switch is silent.
                    try? AVAudioSession.sharedInstance().setCategory(.playback)
                    try? AVAudioSession.sharedInstance().setActive(true)
                    player.replaceCurrentItem(with: AVPlayerItem(url: url))
                    player.play()
                }
                .onDisappear { player.pause() }
        }
    }
}

// Full-screen in-app image viewer with pinch-to-zoom.
struct FullScreenImageView: View {
    let url: URL
    @Environment(\.dismiss) var dismiss
    @State private var scale: CGFloat = 1

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { scale = max(1, $0) }
                                    .onEnded { _ in withAnimation { scale = 1 } }
                            )
                    case .failure:
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                    default:
                        ProgressView().tint(.white)
                    }
                }
                .captureShielded()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}
