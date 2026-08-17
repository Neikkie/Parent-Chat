//
//  ActivityModel.swift
//  Parent Chat
//
//  Created by Shanique Beckford on 4/11/26.
//

import Foundation
import FirebaseFirestore

enum AgeGroup: String, Codable, CaseIterable {
    case infants = "0-1 years"
    case toddlers = "1-3 years"
    case preschool = "3-5 years"
    case schoolAge = "5-12 years"
    case teens = "13-18 years"
    case allAges = "All Ages"
}

enum ActivityTag: String, Codable, CaseIterable {
    case free = "Free"
    case outdoor = "Outdoor"
    case indoor = "Indoor"
    case educational = "Educational"
    case sports = "Sports"
    case arts = "Arts & Crafts"
    case music = "Music"
    case food = "Food & Drinks"
}

struct Activity: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var title: String
    var description: String
    var location: PostLocation
    var ageGroups: [String]
    var tags: [String]
    var createdBy: String
    var createdByName: String
    var createdAt: Date
    var imageUrls: [String]?
    var website: String?
    var contactInfo: String?
    var averageRating: Double?
    var ratingsCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case title
        case description
        case location
        case ageGroups
        case tags
        case createdBy
        case createdByName
        case createdAt
        case imageUrls
        case website
        case contactInfo
        case averageRating
        case ratingsCount
    }
}

struct SavedActivity: Codable {
    var activityId: String
    var userId: String
    var savedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case activityId
        case userId
        case savedAt
    }
}

struct ActivityRating: Codable, Identifiable {
    @DocumentID var id: String?
    var activityId: String
    var userId: String
    var userName: String
    var rating: Double // 1-5 stars
    var review: String?
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case activityId
        case userId
        case userName
        case rating
        case review
        case createdAt
    }
}
