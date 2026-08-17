//
//  PostModel.swift
//  Parent Chat
//
//  Created by Shanique Beckford on 4/6/26.
//

import Foundation
import FirebaseFirestore
import CoreLocation

enum MediaType: String, Codable {
    case image
    case video
}

struct PostMedia: Codable, Identifiable {
    var id: String = UUID().uuidString
    var url: String
    var type: MediaType
    var thumbnailUrl: String? // For videos
    
    enum CodingKeys: String, CodingKey {
        case id
        case url
        case type
        case thumbnailUrl
    }
}

struct PostLocation: Codable {
    var name: String
    var latitude: Double
    var longitude: Double

    enum CodingKeys: String, CodingKey {
        case name
        case latitude
        case longitude
    }

    /// Privacy-preserving init: rounds coordinates to ~110m precision so
    /// posts don't pinpoint a user's exact location (e.g. their home address).
    /// Three decimal places = ~111m at the equator.
    init(name: String, latitude: Double, longitude: Double) {
        self.name = name
        self.latitude = (latitude * 1000).rounded() / 1000
        self.longitude = (longitude * 1000).rounded() / 1000
    }
}

struct Post: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var userName: String
    var userProfileImageUrl: String?
    var content: String
    var createdAt: Date
    var likesCount: Int
    var commentsCount: Int
    var media: [PostMedia]?
    var location: PostLocation?

    /// Display-safe name. Hides legacy email addresses written into older
    /// posts before we removed the email fallback — replaces them with a
    /// stable, anonymous handle derived from the userId.
    var displayName: String {
        let raw = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty || raw.contains("@") {
            let suffix = String(userId.prefix(6))
            return "Parent #\(suffix)"
        }
        return raw
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case userName
        case userProfileImageUrl
        case content
        case createdAt
        case likesCount
        case commentsCount
        case media
        case location
    }
}
