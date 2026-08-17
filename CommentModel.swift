//
//  CommentModel.swift
//  Parent Chat
//
//  Created by Shanique Beckford on 4/6/26.
//

import Foundation
import FirebaseFirestore

struct Comment: Codable, Identifiable {
    @DocumentID var id: String?
    var postId: String
    var userId: String
    var userName: String
    var content: String
    var createdAt: Date
    var likesCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId
        case userId
        case userName
        case content
        case createdAt
        case likesCount
    }

    /// Display-safe name. Hides legacy emails in older comments by replacing
    /// them with an anonymous handle derived from the userId.
    var displayName: String {
        let raw = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty || raw.contains("@") {
            let suffix = String(userId.prefix(6))
            return "Parent #\(suffix)"
        }
        return raw
    }
}

struct PostLike: Codable {
    var userId: String
    var userName: String
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId
        case userName
        case createdAt
    }
}
