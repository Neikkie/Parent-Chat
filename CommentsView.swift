//
//  CommentsView.swift
//  Parent Chat
//
//  Created by Shanique Beckford on 4/6/26.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct CommentsView: View {
    let post: Post
    @Environment(\.dismiss) var dismiss
    @Environment(AuthenticationManager.self) var authManager

    @State private var comments: [Comment] = []
    @State private var newCommentText = ""
    @State private var isLoading = false
    @State private var isPosting = false
    @State private var errorMessage: String?
    @State private var commentsListener: ListenerRegistration?
    @State private var likesListener: ListenerRegistration?
    @State private var liveLikesCount: Int = 0

    // Moderation soft-flag flow
    @State private var showModerationAlert = false
    @State private var pendingMatchedTerm: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Original post
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Post header
                        HStack {
                            postAvatar

                            VStack(alignment: .leading, spacing: 2) {
                                Text(post.displayName)
                                    .font(.headline)

                                Text(post.createdAt, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }

                        // Post content
                        if !post.content.isEmpty {
                            Text(post.content)
                                .font(.body)
                        }

                        // Media (photos / autoplaying video)
                        if let media = post.media, !media.isEmpty {
                            MediaGridView(media: media)
                        }

                        // Location
                        if let location = post.location {
                            HStack(spacing: 6) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                Text(location.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }

                        // Post stats — live counts from the source data, not the
                        // (possibly stale) denormalized fields on the post.
                        HStack(spacing: 20) {
                            Label("\(liveLikesCount)", systemImage: "heart")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Label("\(comments.count)", systemImage: "bubble.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Comments section
                        if isLoading {
                            ProgressView("Loading comments...")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else if comments.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "bubble.right")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                                
                                Text("No comments yet")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                Text("Be the first to comment!")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Comments")
                                    .font(.headline)
                                    .padding(.horizontal)
                                    .padding(.bottom, 8)
                                
                                ForEach(comments) { comment in
                                    VStack(spacing: 0) {
                                        CommentRowView(
                                            comment: comment,
                                            currentUserId: authManager.currentUser?.uid ?? "",
                                            onDelete: {
                                                Task {
                                                    await deleteComment(comment)
                                                }
                                            }
                                        )
                                        
                                        Divider()
                                            .padding(.leading, 60)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                // Comment input
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack(alignment: .bottom, spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(1...5)
                            
                            if let errorMessage = errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        
                        Button {
                            Task {
                                await postComment()
                            }
                        } label: {
                            if isPosting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.blue)
                            }
                        }
                        .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                startCommentsListener()
                startLikesListener()
            }
            .onDisappear {
                stopCommentsListener()
                likesListener?.remove()
                likesListener = nil
            }
            .alert("Content May Violate Guidelines", isPresented: $showModerationAlert) {
                Button("Edit", role: .cancel) {
                    pendingMatchedTerm = nil
                }
                Button("Post Anyway", role: .destructive) {
                    let term = pendingMatchedTerm ?? "unknown"
                    pendingMatchedTerm = nil
                    Task { await performPostComment(matchedTerm: term) }
                }
            } message: {
                Text("Your comment contains language that may violate our community guidelines. You can edit it before posting, or post anyway — our team will review it.")
            }
        }
    }

    private func startCommentsListener() {
        guard let postId = post.id else { return }
        stopCommentsListener()
        isLoading = true

        commentsListener = FirestoreManager.shared.listenToComments(postId: postId) { updated in
            DispatchQueue.main.async {
                comments = updated
                isLoading = false
            }
        } onError: { _ in
            DispatchQueue.main.async {
                errorMessage = "Failed to load comments"
                isLoading = false
            }
        }
    }

    private func stopCommentsListener() {
        commentsListener?.remove()
        commentsListener = nil
    }

    private func startLikesListener() {
        guard let postId = post.id else { return }
        likesListener?.remove()
        liveLikesCount = post.likesCount
        likesListener = FirestoreManager.shared.listenToPostLikesCount(postId: postId) { count in
            DispatchQueue.main.async {
                liveLikesCount = count
            }
        }
    }
    
    @ViewBuilder
    private var postAvatar: some View {
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
                Text(String(post.displayName.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)
        }
    }

    private func postComment() async {
        let trimmedComment = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedComment.isEmpty else { return }

        if let matchedTerm = ContentModerationManager.firstMatchedBlockedTerm(in: trimmedComment) {
            pendingMatchedTerm = matchedTerm
            showModerationAlert = true
            return
        }

        await performPostComment(matchedTerm: nil)
    }

    private func performPostComment(matchedTerm: String?) async {
        guard let user = authManager.currentUser,
              let postId = post.id else { return }

        let trimmedComment = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedComment.isEmpty else { return }

        isPosting = true
        errorMessage = nil

        do {
            let userName = authManager.publicDisplayName
            try await FirestoreManager.shared.addComment(
                postId: postId,
                userId: user.uid,
                userName: userName,
                content: trimmedComment
            )

            // Soft-flag for moderator review if the content matched a guideline term.
            if let matchedTerm {
                try? await FirestoreManager.shared.flagContent(
                    contentType: "comment",
                    contentId: nil,
                    postId: postId,
                    userId: user.uid,
                    userName: userName,
                    matchedTerm: matchedTerm,
                    content: trimmedComment
                )
            }

            newCommentText = ""
        } catch {
            errorMessage = "Failed to post comment"
        }

        isPosting = false
    }
    
    private func deleteComment(_ comment: Comment) async {
        guard let commentId = comment.id,
              let postId = post.id else { return }
        
        do {
            try await FirestoreManager.shared.deleteComment(commentId: commentId, postId: postId)
        } catch { }
    }
}

struct CommentRowView: View {
    let comment: Comment
    let currentUserId: String
    var onDelete: (() -> Void)? = nil

    @State private var showDeleteAlert = false
    @State private var showReportSheet = false
    @State private var liveAuthorName: String?

    private var authorDisplayName: String {
        liveAuthorName ?? comment.displayName
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.title3)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(authorDisplayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(comment.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if comment.userId == currentUserId {
                        Text("• You")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }

                Text(comment.content)
                    .font(.body)
            }

            Spacer()

            Menu {
                if comment.userId == currentUserId {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete Comment", systemImage: "trash")
                    }
                } else {
                    Button {
                        showReportSheet = true
                    } label: {
                        Label("Report Comment", systemImage: "flag")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .alert("Delete Comment", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Are you sure you want to delete this comment?")
        }
        .sheet(isPresented: $showReportSheet) {
            if let commentId = comment.id {
                ReportSheet(target: .comment(id: commentId), reportedByUserId: currentUserId)
            }
        }
        .task {
            liveAuthorName = await UserDirectory.shared.currentUsername(
                for: comment.userId,
                fallback: comment.displayName
            )
        }
    }
}

#Preview {
    CommentsView(post: Post(
        id: "1",
        userId: "123",
        userName: "John Doe",
        content: "This is a test post",
        createdAt: Date(),
        likesCount: 5,
        commentsCount: 3
    ))
    .environment(AuthenticationManager())
}
