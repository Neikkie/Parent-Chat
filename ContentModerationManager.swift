//
//  ContentModerationManager.swift
//  Parent Chat
//

import Foundation

enum ModerationError: LocalizedError {
    case blockedContent

    var errorDescription: String? {
        switch self {
        case .blockedContent:
            return "Your account has been suspended for community safety review. Contact support.chaniiapps@gmail.com for release after review."
        }
    }
}

enum ContentModerationManager {
    private static let blockedTerms: [String] = [
        "kill", "kys", "suicide", "nude", "porn", "sex", "rape", "molest", "fuck", "shit", "bitch", "slut", "whore", "threat", "i will hurt", "die"
    ]

    static func firstMatchedBlockedTerm(in text: String) -> String? {
        let normalized = text.lowercased()
        return blockedTerms.first(where: { normalized.contains($0) })
    }
}
