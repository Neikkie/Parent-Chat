//
//  UserDirectory.swift
//  Parent Chat
//
//  Cached lookup for user display names. Lets post rows and comment rows
//  show the author's CURRENT username — even if the stored userName field
//  is stale (e.g., a legacy email or an empty handle).
//

import Foundation
import FirebaseFirestore

@MainActor
@Observable
final class UserDirectory {
    static let shared = UserDirectory()

    private struct CachedEntry {
        let username: String?
        let isDeactivated: Bool
    }

    private var cache: [String: CachedEntry] = [:]
    private var inFlight: Set<String> = []

    private init() {}

    /// Returns the user's current username if available, otherwise the
    /// provided fallback (typically `post.displayName` / `comment.displayName`).
    /// Deactivated users always resolve to "Deactivated user," regardless of
    /// the stored name.
    func currentUsername(for userId: String, fallback: String) async -> String {
        if let cached = cache[userId] {
            if cached.isDeactivated { return "Deactivated user" }
            return cached.username ?? fallback
        }
        if inFlight.contains(userId) {
            return fallback
        }
        inFlight.insert(userId)
        defer { inFlight.remove(userId) }

        do {
            let doc = try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .getDocument()
            let data = doc.data() ?? [:]
            let username = data["username"] as? String
            let trimmed = username?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolved = (trimmed?.isEmpty == false) ? trimmed : nil
            let deactivated = (data["isDeactivated"] as? Bool) == true
            cache[userId] = CachedEntry(username: resolved, isDeactivated: deactivated)
            if deactivated { return "Deactivated user" }
            return resolved ?? fallback
        } catch {
            cache[userId] = CachedEntry(username: nil, isDeactivated: false)
            return fallback
        }
    }

    /// Force a refresh for one userId — used after the local user renames
    /// themselves so other open views see the change immediately.
    func invalidate(userId: String) {
        cache.removeValue(forKey: userId)
    }

    /// Clear the entire cache (e.g., on sign-out).
    func clearAll() {
        cache.removeAll()
        inFlight.removeAll()
    }
}
