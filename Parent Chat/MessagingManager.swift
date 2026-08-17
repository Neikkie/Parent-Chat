//
//  MessagingManager.swift
//  Parent Chat
//
//  Firestore data layer for 1:1 direct messages. Kept separate from
//  FirestoreManager so the messaging surface stays self-contained.
//
//  Firestore layout:
//    conversations/{conversationId}
//      - participantIds: [uidA, uidB]
//      - participantNames: { uid: name }
//      - lastMessage, lastMessageAt, lastSenderId, createdAt
//    conversations/{conversationId}/messages/{messageId}
//      - senderId, text, createdAt
//
//  `conversationId` is deterministic (sorted uids joined by "_") so the same
//  pair of users always resolves to the same thread.
//

import Foundation
import FirebaseFirestore

@MainActor
final class MessagingManager {
    static let shared = MessagingManager()

    private let db = Firestore.firestore()
    private let conversationsCollection = "conversations"
    private let messagesSubcollection = "messages"

    private init() {}

    /// Deterministic 1:1 conversation id from two user ids.
    func conversationId(_ a: String, _ b: String) -> String {
        [a, b].sorted().joined(separator: "_")
    }

    /// Creates the conversation document if it doesn't exist yet, then returns
    /// its id. Safe to call every time a chat opens.
    @discardableResult
    func startConversation(
        currentUserId: String,
        currentUserName: String,
        otherUserId: String,
        otherUserName: String
    ) async throws -> String {
        let convId = conversationId(currentUserId, otherUserId)
        let ref = db.collection(conversationsCollection).document(convId)

        // Create-or-refresh WITHOUT reading first. A read of a not-yet-created
        // conversation is denied by the security rules (they inspect
        // `resource.data.participantIds`, which is null for a missing doc), so
        // we `setData(merge:)` unconditionally instead. We only write identity
        // fields here — never `lastMessage` — so opening a chat can't wipe the
        // existing preview text.
        try await ref.setData([
            "participantIds": [currentUserId, otherUserId],
            "participantNames": [
                currentUserId: currentUserName,
                otherUserId: otherUserName
            ]
        ], merge: true)
        return convId
    }

    /// Live list of the user's conversations, newest activity first.
    func listenToConversations(
        userId: String,
        onChange: @escaping ([Conversation]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerRegistration {
        db.collection(conversationsCollection)
            .whereField("participantIds", arrayContains: userId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onError(error)
                    return
                }
                let conversations = (snapshot?.documents ?? [])
                    .compactMap { try? $0.data(as: Conversation.self) }
                    // Hide empty conversations that were created but never used.
                    .filter { !$0.lastMessage.isEmpty }
                    .sorted { ($0.lastMessageAt ?? .distantPast) > ($1.lastMessageAt ?? .distantPast) }
                onChange(conversations)
            }
    }

    /// Live stream of messages in a conversation, oldest first.
    func listenToMessages(
        conversationId: String,
        onChange: @escaping ([DirectMessage]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerRegistration {
        db.collection(conversationsCollection)
            .document(conversationId)
            .collection(messagesSubcollection)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onError(error)
                    return
                }
                let messages = (snapshot?.documents ?? [])
                    .compactMap { try? $0.data(as: DirectMessage.self) }
                    .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
                onChange(messages)
            }
    }

    /// Writes the conversation summary FIRST, then appends the message. Order
    /// matters: the message-create rule verifies the sender is a participant by
    /// `get()`-ing the parent conversation, so that doc must already exist. The
    /// summary write uses `merge` so it both creates the conversation (if it's
    /// the first message) and refreshes the preview on every send.
    func sendMessage(
        senderId: String,
        senderName: String,
        recipientId: String,
        recipientName: String,
        text: String
    ) async throws {
        let convId = conversationId(senderId, recipientId)
        let convRef = db.collection(conversationsCollection).document(convId)

        try await convRef.setData([
            "participantIds": [senderId, recipientId],
            "participantNames": [
                senderId: senderName,
                recipientId: recipientName
            ],
            "lastMessage": text,
            "lastMessageAt": FieldValue.serverTimestamp(),
            "lastSenderId": senderId
        ], merge: true)

        try await convRef.collection(messagesSubcollection).addDocument(data: [
            "senderId": senderId,
            "text": text,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }
}
