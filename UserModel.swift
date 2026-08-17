//
//  UserModel.swift
//  Parent Chat
//
//  Created by Shanique Beckford on 4/6/26.
//

import Foundation
import FirebaseFirestore

struct BlockedUser: Codable, Identifiable {
    @DocumentID var id: String?
    var blockingUserId: String
    var blockedUserId: String
    var blockedUserName: String
    var createdAt: Date
}

struct UserReport: Codable, Identifiable {
    @DocumentID var id: String?
    var type: String           // "post" or "comment"
    var contentId: String
    var reportedByUserId: String
    var reason: String
    var createdAt: Date
    var status: String          // "pending" | "reviewed" | "actioned"
}

struct UserProfile: Codable, Identifiable {
    @DocumentID var id: String?
    var uid: String
    // NOTE: email is intentionally NOT stored in Firestore — it lives in
    // Firebase Auth (private). Use authManager.currentUser?.email for the
    // signed-in user's own email; never display other users' emails.
    var displayName: String?
    var username: String?
    var profileImageUrl: String?
    var profileCharacter: String?
    var bio: String?
    var createdAt: Date?
    var lastSignInAt: Date?
    var isProfileComplete: Bool
    var isSuspended: Bool?
    var suspensionReason: String?
    var suspendedAt: Date?
    var eulaAccepted: Bool?
    var eulaAcceptedAt: Date?
    var eulaAcceptedVersion: String?
    var isDeactivated: Bool?
    var deactivatedAt: Date?
    var ageConfirmed: Bool?
    var ageConfirmedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case uid
        case displayName
        case username
        case profileImageUrl
        case profileCharacter
        case bio
        case createdAt
        case lastSignInAt
        case isProfileComplete
        case isSuspended
        case suspensionReason
        case suspendedAt
        case eulaAccepted
        case eulaAcceptedAt
        case eulaAcceptedVersion
        case isDeactivated
        case deactivatedAt
        case ageConfirmed
        case ageConfirmedAt
    }
    
    var initials: String {
        if let username = username, !username.isEmpty {
            return String(username.prefix(1)).uppercased()
        } else if let displayName = displayName, !displayName.isEmpty {
            return String(displayName.prefix(1)).uppercased()
        }
        return "?"
    }
    
    var avatarCharacter: String {
        profileCharacter ?? initials
    }
}
