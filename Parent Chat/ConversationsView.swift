//
//  ConversationsView.swift
//  Parent Chat
//
//  Direct messaging UI: an inbox of conversations and the 1:1 chat thread.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Inbox

struct ConversationsView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.dismiss) var dismiss

    @State private var conversations: [Conversation] = []
    @State private var isLoading = true
    @State private var listener: ListenerRegistration?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading messages...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if conversations.isEmpty {
                    ProfessionalEmptyStateView(
                        icon: "bubble.left.and.bubble.right",
                        title: "No messages yet",
                        message: "Start a conversation from any post by tapping the ••• menu and choosing Message."
                    )
                } else {
                    List {
                        ForEach(conversations) { conversation in
                            if let currentUserId = authManager.currentUser?.uid,
                               let otherId = conversation.otherParticipantId(currentUserId: currentUserId) {
                                NavigationLink {
                                    ChatView(
                                        otherUserId: otherId,
                                        otherUserName: conversation.otherParticipantName(currentUserId: currentUserId)
                                    )
                                    .environment(authManager)
                                } label: {
                                    ConversationRow(
                                        conversation: conversation,
                                        currentUserId: currentUserId
                                    )
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                        HapticManager.shared.selection()
                    }
                    .fontWeight(.semibold)
                }
            }
            .task {
                startListener()
            }
            .onDisappear {
                listener?.remove()
                listener = nil
            }
        }
    }

    private func startListener() {
        guard let userId = authManager.currentUser?.uid else {
            isLoading = false
            return
        }
        listener?.remove()
        listener = MessagingManager.shared.listenToConversations(userId: userId) { updated in
            conversations = updated
            isLoading = false
        } onError: { _ in
            isLoading = false
        }
    }
}

// MARK: - Inbox Row

struct ConversationRow: View {
    let conversation: Conversation
    let currentUserId: String

    private var name: String {
        conversation.otherParticipantName(currentUserId: currentUserId)
    }

    private var initial: String {
        String(name.prefix(1)).uppercased()
    }

    private var timestamp: String {
        guard let date = conversation.lastMessageAt else { return "" }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86_400 { return "\(seconds / 3600)h" }
        return "\(seconds / 86_400)d"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.primaryGradient)
                    .frame(width: 48, height: 48)
                Text(initial)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(conversation.lastMessage)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(timestamp)
                .font(.caption)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Chat Thread

struct ChatView: View {
    let otherUserId: String
    let otherUserName: String

    @Environment(AuthenticationManager.self) var authManager

    @State private var messages: [DirectMessage] = []
    @State private var draft = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var listener: ListenerRegistration?
    @State private var errorMessage: String?

    // Moderation soft-flag flow (mirrors comments / posts).
    @State private var showModerationAlert = false
    @State private var pendingMatchedTerm: String?

    var body: some View {
        VStack(spacing: 0) {
            messagesList

            Divider()

            composer
        }
        .navigationTitle(otherUserName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await startConversationIfNeeded()
            startListener()
        }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
        .alert("Content May Violate Guidelines", isPresented: $showModerationAlert) {
            Button("Edit", role: .cancel) {
                pendingMatchedTerm = nil
            }
            Button("Send Anyway", role: .destructive) {
                let term = pendingMatchedTerm ?? "unknown"
                pendingMatchedTerm = nil
                Task { await performSend(matchedTerm: term) }
            }
        } message: {
            Text("Your message may violate our community guidelines. It will be flagged for review if you send it.")
        }
        .alert("Message Failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Could not send your message.")
        }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    } else if messages.isEmpty {
                        Text("Say hello 👋")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                            .padding(.top, 40)
                    }

                    ForEach(messages) { message in
                        MessageBubble(
                            message: message,
                            isFromCurrentUser: message.senderId == authManager.currentUser?.uid
                        )
                        .id(message.id)
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .readableWidth()
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Message...", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.surfaceSecondary)
                .cornerRadius(20)

            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(canSend ? Color.brandPrimary : Color.textTertiary)
            }
            .disabled(!canSend)
        }
        .readableWidth()
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.surfacePrimary)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    private func startConversationIfNeeded() async {
        guard let user = authManager.currentUser else { return }
        _ = try? await MessagingManager.shared.startConversation(
            currentUserId: user.uid,
            currentUserName: authManager.publicDisplayName,
            otherUserId: otherUserId,
            otherUserName: otherUserName
        )
    }

    private func startListener() {
        guard let user = authManager.currentUser else {
            isLoading = false
            return
        }
        let convId = MessagingManager.shared.conversationId(user.uid, otherUserId)
        listener?.remove()
        listener = MessagingManager.shared.listenToMessages(conversationId: convId) { updated in
            messages = updated
            isLoading = false
        } onError: { _ in
            isLoading = false
        }
    }

    private func send() async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let matchedTerm = ContentModerationManager.firstMatchedBlockedTerm(in: trimmed) {
            pendingMatchedTerm = matchedTerm
            showModerationAlert = true
            return
        }
        await performSend(matchedTerm: nil)
    }

    private func performSend(matchedTerm: String?) async {
        guard let user = authManager.currentUser else { return }
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Don't let a user message someone they've blocked.
        if (try? await FirestoreManager.shared.isUserBlocked(
            blockingUserId: user.uid,
            blockedUserId: otherUserId
        )) == true {
            errorMessage = "You've blocked this user. Unblock them in Settings to send a message."
            return
        }

        isSending = true
        HapticManager.shared.impact(.light)
        let senderName = authManager.publicDisplayName

        do {
            try await MessagingManager.shared.sendMessage(
                senderId: user.uid,
                senderName: senderName,
                recipientId: otherUserId,
                recipientName: otherUserName,
                text: trimmed
            )

            // Soft-flag for moderator review if the content matched a term.
            if let matchedTerm {
                try? await FirestoreManager.shared.flagContent(
                    contentType: "message",
                    contentId: nil,
                    postId: nil,
                    userId: user.uid,
                    userName: senderName,
                    matchedTerm: matchedTerm,
                    content: trimmed
                )
            }

            draft = ""
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: DirectMessage
    let isFromCurrentUser: Bool

    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer(minLength: 40) }

            Text(message.text)
                .font(.body)
                .foregroundStyle(isFromCurrentUser ? .white : Color.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isFromCurrentUser
                        ? AnyShapeStyle(Color.primaryGradient)
                        : AnyShapeStyle(Color.surfaceSecondary)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if !isFromCurrentUser { Spacer(minLength: 40) }
        }
    }
}
