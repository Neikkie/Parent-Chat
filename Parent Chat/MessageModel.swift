//
//  MessageModel.swift
//  Parent Chat
//
//  Direct messaging models. A `Conversation` is a 1:1 thread between two
//  parents; its messages live in a `messages` subcollection as `DirectMessage`
//  documents.
//

import Foundation
import FirebaseFirestore

struct Conversation: Codable, Identifiable {
    @DocumentID var id: String?
    var participantIds: [String]
    /// Maps each participant's uid to the display name captured when the
    /// conversation was created / last written. Used so the inbox can show the
    /// other person's name without an extra user lookup.
    var participantNames: [String: String]
    var lastMessage: String
    var lastMessageAt: Date?
    var lastSenderId: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case participantIds
        case participantNames
        case lastMessage
        case lastMessageAt
        case lastSenderId
        case createdAt
    }

    /// The uid of the participant who isn't the current user.
    func otherParticipantId(currentUserId: String) -> String? {
        participantIds.first { $0 != currentUserId }
    }

    /// Display-safe name for the other participant. Hides legacy emails and
    /// falls back to an anonymous handle derived from the uid.
    func otherParticipantName(currentUserId: String) -> String {
        guard let other = otherParticipantId(currentUserId: currentUserId) else {
            return "Parent"
        }
        let raw = participantNames[other]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw, !raw.isEmpty, !raw.contains("@") {
            return raw
        }
        return "Parent #\(String(other.prefix(6)))"
    }
}

struct DirectMessage: Codable, Identifiable {
    @DocumentID var id: String?
    var senderId: String
    var text: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case senderId
        case text
        case createdAt
    }
}
