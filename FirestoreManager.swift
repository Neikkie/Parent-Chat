//
//  FirestoreManager.swift
//  Parent Chat
//
//  Created by Shanique Beckford on 4/6/26.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class FirestoreManager {
    static let shared = FirestoreManager()
    
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    private let postsCollection = "posts"
    private let commentsCollection = "comments"
    private let likesCollection = "likes"
    private let activitiesCollection = "activities"
    private let savedActivitiesCollection = "savedActivities"
    private let savedPostsCollection = "savedPosts"
    private let ratingsCollection = "ratings"

    private init() {}
    
    // Create or update user in Firestore
    func createOrUpdateUser(authUser: User) async throws {
        let userRef = db.collection(usersCollection).document(authUser.uid)
        
        // Check if user exists
        let document = try await userRef.getDocument()
        
        if document.exists {
            // Update only lastSignInAt for existing users
            try await userRef.updateData([
                "lastSignInAt": FieldValue.serverTimestamp()
            ])

        } else {
            // Create new user document — DO NOT store email here. Email lives
            // in Firebase Auth (private to the user + admin via Admin SDK).
            // Including it here would expose it to every other authenticated
            // user via /users reads.
            try await userRef.setData([
                "uid": authUser.uid,
                "displayName": authUser.displayName ?? "",
                "username": NSNull(),
                "profileImageUrl": NSNull(),
                "profileCharacter": NSNull(),
                "bio": NSNull(),
                "createdAt": FieldValue.serverTimestamp(),
                "lastSignInAt": FieldValue.serverTimestamp(),
                "isProfileComplete": false,
                "isSuspended": false,
                "suspensionReason": NSNull(),
                "suspendedAt": NSNull()
            ])

        }
    }
    
    // Update user profile with username, bio, and profile image
    func updateUserProfile(
        userId: String,
        username: String,
        bio: String?,
        profileImageUrl: String?,
        profileCharacter: String? = nil
    ) async throws {
        var updateData: [String: Any] = [
            "username": username,
            "isProfileComplete": true
        ]
        
        if let bio = bio {
            updateData["bio"] = bio
        }
        
        if let profileImageUrl = profileImageUrl {
            updateData["profileImageUrl"] = profileImageUrl
        }
        
        if let profileCharacter = profileCharacter {
            updateData["profileCharacter"] = profileCharacter
        }
        
        try await db.collection(usersCollection).document(userId).updateData(updateData)

        // Drop the cache so any open feed/comment views pick up the new name
        // on their next render without needing a full refresh.
        UserDirectory.shared.invalidate(userId: userId)

        // Propagate the new username to all of this user's existing posts and
        // comments so legacy content shows the current name. Best-effort: a
        // failure here doesn't roll back the profile write.
        try? await renameUserContent(userId: userId, newName: username)
    }

    /// Batch-updates `userName` on every post and comment authored by `userId`.
    /// Uses Firestore's 500-write batch limit and chunks accordingly.
    func renameUserContent(userId: String, newName: String) async throws {
        async let posts = renameDocs(
            in: postsCollection,
            ownerField: "userId",
            ownerId: userId,
            newName: newName
        )
        async let comments = renameDocs(
            in: commentsCollection,
            ownerField: "userId",
            ownerId: userId,
            newName: newName
        )
        _ = try await (posts, comments)
    }

    private func renameDocs(
        in collection: String,
        ownerField: String,
        ownerId: String,
        newName: String
    ) async throws {
        let snapshot = try await db.collection(collection)
            .whereField(ownerField, isEqualTo: ownerId)
            .getDocuments()

        // Firestore caps a batch at 500 writes. Chunk if the user has more.
        let chunks = stride(from: 0, to: snapshot.documents.count, by: 500).map {
            Array(snapshot.documents[$0 ..< min($0 + 500, snapshot.documents.count)])
        }
        for chunk in chunks {
            let batch = db.batch()
            for doc in chunk {
                batch.updateData(["userName": newName], forDocument: doc.reference)
            }
            try await batch.commit()
        }
    }
    
    // Fetch user profile from Firestore
    func fetchUserProfile(uid: String) async throws -> UserProfile? {
        let document = try await db.collection(usersCollection).document(uid).getDocument()
        return try document.data(as: UserProfile.self)
    }
    
    // Update user profile
    func updateUserProfile(uid: String, data: [String: Any]) async throws {
        try await db.collection(usersCollection).document(uid).updateData(data)
    }
    
    // Delete user
    func deleteUser(uid: String) async throws {
        try await db.collection(usersCollection).document(uid).delete()
    }
    
    // MARK: - Posts
    
    // Create a new post
    func createPost(content: String, userId: String, userName: String, userProfileImageUrl: String? = nil, media: [PostMedia]? = nil, location: PostLocation? = nil) async throws {
        var postData: [String: Any] = [
            "userId": userId,
            "userName": userName,
            "content": content,
            "createdAt": FieldValue.serverTimestamp(),
            "likesCount": 0,
            "commentsCount": 0
        ]

        if let userProfileImageUrl = userProfileImageUrl {
            postData["userProfileImageUrl"] = userProfileImageUrl
        }
        
        // Add media if present
        if let media = media, !media.isEmpty {
            let mediaData = media.map { item -> [String: Any] in
                var data: [String: Any] = [
                    "id": item.id,
                    "url": item.url,
                    "type": item.type.rawValue
                ]
                if let thumbnailUrl = item.thumbnailUrl {
                    data["thumbnailUrl"] = thumbnailUrl
                }
                return data
            }
            postData["media"] = mediaData
        }
        
        // Add location if present
        if let location = location {
            postData["location"] = [
                "name": location.name,
                "latitude": location.latitude,
                "longitude": location.longitude
            ]
        }
        
        try await db.collection(postsCollection).addDocument(data: postData)

    }
    
    // Fetch all posts (newest first)
    func fetchPosts() async throws -> [Post] {
        let snapshot = try await db.collection(postsCollection)
            .getDocuments()

        let posts = snapshot.documents.compactMap { document in
            try? document.data(as: Post.self)
        }

        return posts.sorted { $0.createdAt > $1.createdAt }
    }

    // Listen for real-time post updates (newest first)
    func listenToPosts(
        onChange: @escaping ([Post]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerRegistration {
        db.collection(postsCollection)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onError(error)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    onChange([])
                    return
                }
                
                let posts = documents.compactMap { document in
                    try? document.data(as: Post.self)
                }
                .sorted { $0.createdAt > $1.createdAt }

                onChange(posts)
            }
    }

    // Fetch posts by user
    func fetchUserPosts(userId: String) async throws -> [Post] {
        let snapshot = try await db.collection(postsCollection)
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? document.data(as: Post.self)
        }
    }
    
    // Delete a post and clean up its Storage media.
    // mediaUrls is passed in directly from the caller's Post object so we
    // don't need an extra Firestore read (which can fail for old documents).
    func deletePost(postId: String, mediaUrls: [String] = []) async throws {
        print("🗑️ deletePost: postId=\(postId) mediaCount=\(mediaUrls.count)")

        try await db.collection(postsCollection).document(postId).delete()
        print("✅ Firestore doc deleted: \(postId)")

        guard !mediaUrls.isEmpty else { return }

        Task {
            for url in mediaUrls {
                do {
                    try await StorageManager.shared.deleteMedia(at: url)
                    print("✅ Storage deleted: \(url)")
                } catch {
                    print("⚠️ Storage delete failed for \(url): \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Likes
    
    // Toggle like on a post
    func toggleLikePost(postId: String, userId: String, userName: String) async throws -> Bool {
        let likeRef = db.collection(postsCollection)
            .document(postId)
            .collection(likesCollection)
            .document(userId)

        let likeDoc = try await likeRef.getDocument()
        let postRef = db.collection(postsCollection).document(postId)
        let nowLiked: Bool

        if likeDoc.exists {
            try await likeRef.delete()
            nowLiked = false
        } else {
            try await likeRef.setData([
                "userId": userId,
                "userName": userName,
                "createdAt": FieldValue.serverTimestamp()
            ])
            nowLiked = true
        }

        // Counter update is best-effort: the like itself already succeeded.
        // If counter rules reject the write, surface the issue in logs but
        // don't fail the whole action (the snapshot listener still reflects
        // the new like via the subcollection count, if computed).
        do {
            try await postRef.updateData([
                "likesCount": FieldValue.increment(Int64(nowLiked ? 1 : -1))
            ])
        } catch {
            print("⚠️ likesCount update failed: \(error.localizedDescription)")
        }

        return nowLiked
    }
    
    // Check if user liked a post
    func hasUserLikedPost(postId: String, userId: String) async throws -> Bool {
        let likeDoc = try await db.collection(postsCollection)
            .document(postId)
            .collection(likesCollection)
            .document(userId)
            .getDocument()
        
        return likeDoc.exists
    }

    // Live count of likes for a post (computed from /posts/{postId}/likes subcollection).
    // This bypasses any rule restrictions on updating the denormalized likesCount field.
    func listenToPostLikesCount(
        postId: String,
        onChange: @escaping (Int) -> Void
    ) -> ListenerRegistration {
        db.collection(postsCollection)
            .document(postId)
            .collection(likesCollection)
            .addSnapshotListener { snapshot, _ in
                onChange(snapshot?.documents.count ?? 0)
            }
    }

    // Live count of comments for a post (computed from top-level comments collection).
    func listenToPostCommentsCount(
        postId: String,
        onChange: @escaping (Int) -> Void
    ) -> ListenerRegistration {
        db.collection(commentsCollection)
            .whereField("postId", isEqualTo: postId)
            .addSnapshotListener { snapshot, _ in
                onChange(snapshot?.documents.count ?? 0)
            }
    }

    // MARK: - Comments
    
    // Add a comment to a post
    func addComment(postId: String, userId: String, userName: String, content: String) async throws {
        let commentData: [String: Any] = [
            "postId": postId,
            "userId": userId,
            "userName": userName,
            "content": content,
            "createdAt": FieldValue.serverTimestamp(),
            "likesCount": 0
        ]

        try await db.collection(commentsCollection).addDocument(data: commentData)

        // Counter update is best-effort: the comment was already created.
        // A counter failure must not be surfaced as "Failed to post comment".
        do {
            try await db.collection(postsCollection).document(postId).updateData([
                "commentsCount": FieldValue.increment(Int64(1))
            ])
        } catch {
            print("⚠️ commentsCount update failed: \(error.localizedDescription)")
        }
    }
    
    // Fetch comments for a post
    func fetchComments(postId: String) async throws -> [Comment] {
        let snapshot = try await db.collection(commentsCollection)
            .whereField("postId", isEqualTo: postId)
            .getDocuments()
        
        // Sort in memory instead of requiring an index
        let comments = snapshot.documents.compactMap { document in
            try? document.data(as: Comment.self)
        }
        
        return comments.sorted { $0.createdAt < $1.createdAt }
    }

    // Listen for comment updates on a post
    func listenToComments(
        postId: String,
        onChange: @escaping ([Comment]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerRegistration {
        db.collection(commentsCollection)
            .whereField("postId", isEqualTo: postId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onError(error)
                    return
                }

                let comments = (snapshot?.documents ?? []).compactMap { document in
                    try? document.data(as: Comment.self)
                }
                .sorted { $0.createdAt < $1.createdAt }

                onChange(comments)
            }
    }

    // Delete a comment
    func deleteComment(commentId: String, postId: String) async throws {
        try await db.collection(commentsCollection).document(commentId).delete()

        // Counter update is best-effort: the delete already succeeded.
        do {
            try await db.collection(postsCollection).document(postId).updateData([
                "commentsCount": FieldValue.increment(Int64(-1))
            ])
        } catch {
            print("⚠️ commentsCount decrement failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Saved Posts
    
    // Save/Unsave post
    func toggleSavePost(postId: String, userId: String) async throws -> Bool {
        guard !postId.isEmpty, !userId.isEmpty else {
            throw NSError(domain: "FirestoreManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid post or user id"])
        }

        let savedRef = db.collection(savedPostsCollection).document("\(userId)_\(postId)")
        let savedDoc = try await savedRef.getDocument()
        
        if savedDoc.exists {
            try await savedRef.delete()
            return false
        } else {
            try await savedRef.setData([
                "postId": postId,
                "userId": userId,
                "savedAt": FieldValue.serverTimestamp()
            ], merge: true)
            return true
        }
    }
    
    // Check if post is saved
    func isPostSaved(postId: String, userId: String) async throws -> Bool {
        guard !postId.isEmpty, !userId.isEmpty else { return false }

        do {
            let savedDoc = try await db.collection(savedPostsCollection)
                .document("\(userId)_\(postId)")
                .getDocument()
            
            return savedDoc.exists
        } catch {
            // If permission denied, it means the document doesn't exist (user hasn't saved it)
            if error.localizedDescription.contains("permissions") {
                return false
            }
            throw error
        }
    }
    
    // Get saved posts for user
    func fetchSavedPosts(userId: String) async throws -> [Post] {
        let savedSnapshot = try await db.collection(savedPostsCollection)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        let postIds = savedSnapshot.documents.compactMap { doc -> String? in
            guard let postId = doc.data()["postId"] as? String, !postId.isEmpty else { return nil }
            return postId
        }
        
        guard !postIds.isEmpty else { return [] }
        
        var posts: [Post] = []
        
        for postId in postIds {
            let postDoc = try await db.collection(postsCollection)
                .document(postId)
                .getDocument()
            
            if let post = try? postDoc.data(as: Post.self) {
                posts.append(post)
            }
        }
        
        return posts.sorted { $0.createdAt > $1.createdAt }
    }
    
    func fetchSavedPostsCount(userId: String) async throws -> Int {
        let snapshot = try await db.collection(savedPostsCollection)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        return snapshot.documents.count
    }
    
    func listenToSavedPostsCount(userId: String, onChange: @escaping (Int) -> Void) -> ListenerRegistration {
        db.collection(savedPostsCollection)
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { snapshot, _ in
                onChange(snapshot?.documents.count ?? 0)
            }
    }

    // Listen for saved posts list updates for a user (hydrates posts on every change)
    func listenToSavedPosts(
        userId: String,
        onChange: @escaping ([Post]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerRegistration {
        db.collection(savedPostsCollection)
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onError(error)
                    return
                }

                let postIds = (snapshot?.documents ?? []).compactMap { doc -> String? in
                    guard let postId = doc.data()["postId"] as? String, !postId.isEmpty else { return nil }
                    return postId
                }

                guard !postIds.isEmpty else {
                    onChange([])
                    return
                }

                Task {
                    var posts: [Post] = []
                    for postId in postIds {
                        if let doc = try? await self.db.collection(self.postsCollection)
                            .document(postId)
                            .getDocument(),
                           let post = try? doc.data(as: Post.self) {
                            posts.append(post)
                        }
                    }
                    let sorted = posts.sorted { $0.createdAt > $1.createdAt }
                    onChange(sorted)
                }
            }
    }
    
    func fetchUserCommentsCount(userId: String) async throws -> Int {
        let snapshot = try await db.collection(commentsCollection)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        return snapshot.documents.count
    }
    
    func fetchUserCreatedActivitiesCount(userId: String) async throws -> Int {
        let snapshot = try await db.collection(activitiesCollection)
            .whereField("createdBy", isEqualTo: userId)
            .getDocuments()
        return snapshot.documents.count
    }
    
    // MARK: - Activities
    
    // Fetch all activities (newest first)
    func fetchActivities() async throws -> [Activity] {
        let snapshot = try await db.collection(activitiesCollection)
            .getDocuments()
        
        // Fetch and sort in memory to avoid requiring an index
        let activities = snapshot.documents.compactMap { document in
            try? document.data(as: Activity.self)
        }
        
        return activities.sorted { $0.createdAt > $1.createdAt }
    }

    // Listen for real-time activity updates (newest first)
    func listenToActivities(
        onChange: @escaping ([Activity]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerRegistration {
        db.collection(activitiesCollection)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onError(error)
                    return
                }

                let activities = (snapshot?.documents ?? []).compactMap { document in
                    try? document.data(as: Activity.self)
                }
                .sorted { $0.createdAt > $1.createdAt }

                onChange(activities)
            }
    }
    
    // Create activity
    func createActivity(
        name: String,
        title: String,
        description: String,
        location: PostLocation,
        ageGroups: [String],
        tags: [String],
        userId: String,
        userName: String,
        imageUrls: [String]? = nil,
        website: String? = nil,
        contactInfo: String? = nil
    ) async throws {
        var activityData: [String: Any] = [
            "name": name,
            "title": title,
            "description": description,
            "location": [
                "name": location.name,
                "latitude": location.latitude,
                "longitude": location.longitude
            ],
            "ageGroups": ageGroups,
            "tags": tags,
            "createdBy": userId,
            "createdByName": userName,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        if let imageUrls = imageUrls {
            activityData["imageUrls"] = imageUrls
        }
        if let website = website {
            activityData["website"] = website
        }
        if let contactInfo = contactInfo {
            activityData["contactInfo"] = contactInfo
        }
        
        try await db.collection(activitiesCollection).addDocument(data: activityData)
    }
    
    // Save/Unsave activity
    func toggleSaveActivity(activityId: String, userId: String) async throws -> Bool {
        guard !activityId.isEmpty, !userId.isEmpty else {
            throw NSError(domain: "FirestoreManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid activity or user id"])
        }

        let savedRef = db.collection(savedActivitiesCollection)
            .document("\(userId)_\(activityId)")
        
        let savedDoc = try await savedRef.getDocument()
        
        if savedDoc.exists {
            // Unsave
            try await savedRef.delete()
            return false
        } else {
            // Save
            let saveData: [String: Any] = [
                "activityId": activityId,
                "userId": userId,
                "savedAt": FieldValue.serverTimestamp()
            ]
            try await savedRef.setData(saveData)
            return true
        }
    }
    
    // Check if activity is saved
    func isActivitySaved(activityId: String, userId: String) async throws -> Bool {
        guard !activityId.isEmpty, !userId.isEmpty else { return false }

        let savedDoc = try await db.collection(savedActivitiesCollection)
            .document("\(userId)_\(activityId)")
            .getDocument()

        return savedDoc.exists
    }
    
    // Get saved activities for user
    func fetchSavedActivities(userId: String) async throws -> [Activity] {
        let savedSnapshot = try await db.collection(savedActivitiesCollection)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        let activityIds = savedSnapshot.documents.compactMap { doc -> String? in
            guard let activityId = try? doc.data(as: SavedActivity.self).activityId,
                  !activityId.isEmpty else {
                return nil
            }
            return activityId
        }
        
        guard !activityIds.isEmpty else { return [] }
        
        var activities: [Activity] = []
        
        for activityId in activityIds {
            let activityDoc = try await db.collection(activitiesCollection)
                .document(activityId)
                .getDocument()
            
            if let activity = try? activityDoc.data(as: Activity.self) {
                activities.append(activity)
            }
        }
        
        return activities
    }
    
    func listenToSavedActivityIds(userId: String, onChange: @escaping (Set<String>) -> Void) -> ListenerRegistration {
        db.collection(savedActivitiesCollection)
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { snapshot, _ in
                let ids = Set(snapshot?.documents.compactMap { $0.data()["activityId"] as? String } ?? [])
                onChange(ids)
            }
    }

    // Listen for saved activities list updates (hydrates Activity docs on every change)
    func listenToSavedActivities(
        userId: String,
        onChange: @escaping ([Activity]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerRegistration {
        db.collection(savedActivitiesCollection)
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onError(error)
                    return
                }

                let activityIds = (snapshot?.documents ?? []).compactMap { doc -> String? in
                    guard let id = try? doc.data(as: SavedActivity.self).activityId,
                          !id.isEmpty else { return nil }
                    return id
                }

                guard !activityIds.isEmpty else {
                    onChange([])
                    return
                }

                Task {
                    var activities: [Activity] = []
                    for activityId in activityIds {
                        if let doc = try? await self.db.collection(self.activitiesCollection)
                            .document(activityId)
                            .getDocument(),
                           let activity = try? doc.data(as: Activity.self) {
                            activities.append(activity)
                        }
                    }
                    onChange(activities)
                }
            }
    }
    
    // MARK: - Ratings
    
    // Add or update rating for an activity
    func rateActivity(activityId: String, userId: String, userName: String, rating: Double, review: String?) async throws {
        // Check if user already rated this activity
        let existingRatings = try await db.collection(ratingsCollection)
            .whereField("activityId", isEqualTo: activityId)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        let ratingData: [String: Any] = [
            "activityId": activityId,
            "userId": userId,
            "userName": userName,
            "rating": rating,
            "review": review ?? "",
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        if let existingRating = existingRatings.documents.first {
            // Update existing rating
            try await existingRating.reference.updateData(ratingData)
        } else {
            // Create new rating
            try await db.collection(ratingsCollection).addDocument(data: ratingData)
        }
        
        // Update activity's average rating
        try await updateActivityAverageRating(activityId: activityId)
    }
    
    // Get user's rating for an activity
    func getUserRating(activityId: String, userId: String) async throws -> ActivityRating? {
        let snapshot = try await db.collection(ratingsCollection)
            .whereField("activityId", isEqualTo: activityId)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        return snapshot.documents.first.flatMap { try? $0.data(as: ActivityRating.self) }
    }
    
    // Get all ratings for an activity
    func fetchActivityRatings(activityId: String) async throws -> [ActivityRating] {
        let snapshot = try await db.collection(ratingsCollection)
            .whereField("activityId", isEqualTo: activityId)
            .getDocuments()
        
        let ratings = snapshot.documents.compactMap { try? $0.data(as: ActivityRating.self) }
        return ratings.sorted { $0.createdAt > $1.createdAt }
    }
    
    // Update activity's average rating
    private func updateActivityAverageRating(activityId: String) async throws {
        let ratings = try await fetchActivityRatings(activityId: activityId)
        
        guard !ratings.isEmpty else { return }
        
        let totalRating = ratings.reduce(0.0) { $0 + $1.rating }
        let averageRating = totalRating / Double(ratings.count)
        
        try await db.collection(activitiesCollection).document(activityId).updateData([
            "averageRating": averageRating,
            "ratingsCount": ratings.count
        ])
    }
    
    // MARK: - Moderation

    func suspendUserForViolation(
        userId: String,
        matchedTerm: String,
        content: String,
        supportEmail: String = "support.chaniiapps@gmail.com"
    ) async throws {
        guard !userId.isEmpty else {
            throw NSError(domain: "FirestoreManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid user id"])
        }

        let preview = String(content.prefix(250))

        try await db.collection(usersCollection).document(userId).updateData([
            "isSuspended": true,
            "suspensionReason": "Policy violation: threatening/indecent language",
            "suspendedAt": FieldValue.serverTimestamp(),
            "suspensionStatus": "pending_review"
        ])

        try await db.collection("moderationViolations").addDocument(data: [
            "userId": userId,
            "matchedTerm": matchedTerm,
            "contentPreview": preview,
            "createdAt": FieldValue.serverTimestamp(),
            "status": "pending_review",
            "reviewContact": supportEmail,
            "reviewNotes": "Send release approval notice to support before reinstating account"
        ])
    }

    // MARK: - Account deactivation (soft delete)

    /// Sets/clears the deactivation flag on the user's own profile.
    func setAccountDeactivated(userId: String, deactivated: Bool) async throws {
        var data: [String: Any] = ["isDeactivated": deactivated]
        if deactivated {
            data["deactivatedAt"] = FieldValue.serverTimestamp()
        } else {
            data["deactivatedAt"] = NSNull()
        }
        try await db.collection(usersCollection).document(userId).updateData(data)
    }

    // MARK: - Push Notification Tokens (FCM)

    /// Stores a device's FCM token under the user so a Cloud Function can push
    /// to all of that user's devices. Keyed by token for easy per-device cleanup.
    func saveFCMToken(_ token: String, userId: String) async throws {
        try await db.collection(usersCollection).document(userId)
            .collection("fcmTokens").document(token)
            .setData([
                "token": token,
                "platform": "ios",
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
    }

    /// Removes a device's FCM token (e.g., on sign-out) so it stops receiving push.
    func deleteFCMToken(_ token: String, userId: String) async throws {
        try await db.collection(usersCollection).document(userId)
            .collection("fcmTokens").document(token).delete()
    }

    // MARK: - Age Confirmation

    /// Records that the user confirmed they are 18+. We intentionally store only
    /// a boolean + timestamp — never the date of birth — to minimize PII.
    func setAgeConfirmed(uid: String) async throws {
        try await db.collection(usersCollection).document(uid).updateData([
            "ageConfirmed": true,
            "ageConfirmedAt": FieldValue.serverTimestamp()
        ])
    }

    // MARK: - EULA / Community Agreement

    // Records the user's acceptance of the community agreement (§1.2 App Review).
    func setEulaAccepted(uid: String, version: String) async throws {
        try await db.collection(usersCollection).document(uid).updateData([
            "eulaAccepted": true,
            "eulaAcceptedAt": FieldValue.serverTimestamp(),
            "eulaAcceptedVersion": version
        ])
    }

    // MARK: - Media Audit Log

    // Records every image upload (with a flag for whether face detection
    // matched). Gives a defensible audit trail for App Review and moderation.
    func logImageUpload(
        userId: String,
        imageUrl: String,
        hasDetectedFace: Bool
    ) async throws {
        try await db.collection("mediaUploads").addDocument(data: [
            "userId": userId,
            "imageUrl": imageUrl,
            "hasDetectedFace": hasDetectedFace,
            "uploadedAt": FieldValue.serverTimestamp()
        ])
    }

    // MARK: - Flagged Content (soft moderation)

    // Record content that matched a community-guideline term so a moderator can
    // review later. The content itself still goes live; this is a soft flag,
    // not a takedown.
    func flagContent(
        contentType: String,
        contentId: String?,
        postId: String?,
        userId: String,
        userName: String,
        matchedTerm: String,
        content: String
    ) async throws {
        let preview = String(content.prefix(500))
        var data: [String: Any] = [
            "contentType": contentType,
            "userId": userId,
            "userName": userName,
            "matchedTerm": matchedTerm,
            "contentPreview": preview,
            "createdAt": FieldValue.serverTimestamp(),
            "status": "pending_review"
        ]
        if let contentId { data["contentId"] = contentId }
        if let postId { data["postId"] = postId }

        try await db.collection("flaggedContent").addDocument(data: data)
    }

    // MARK: - Reports

    func reportPost(postId: String, reportedByUserId: String, reason: String) async throws {
        let reportData: [String: Any] = [
            "type": "post",
            "contentId": postId,
            "reportedByUserId": reportedByUserId,
            "reason": reason,
            "createdAt": FieldValue.serverTimestamp(),
            "status": "pending"
        ]
        try await db.collection("reports").addDocument(data: reportData)
    }

    func reportComment(commentId: String, reportedByUserId: String, reason: String) async throws {
        let reportData: [String: Any] = [
            "type": "comment",
            "contentId": commentId,
            "reportedByUserId": reportedByUserId,
            "reason": reason,
            "createdAt": FieldValue.serverTimestamp(),
            "status": "pending"
        ]
        try await db.collection("reports").addDocument(data: reportData)
    }

    /// Live listener for ALL reports — admin-only. Rules must allow admin read.
    func listenToReports(
        onChange: @escaping ([UserReport]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerRegistration {
        db.collection("reports")
            .addSnapshotListener { snapshot, error in
                if let error {
                    onError(error)
                    return
                }
                let reports = (snapshot?.documents ?? []).compactMap {
                    try? $0.data(as: UserReport.self)
                }
                .sorted { $0.createdAt > $1.createdAt }
                onChange(reports)
            }
    }

    /// Fetches the reported post or comment content for admin review.
    func fetchReportedContent(report: UserReport) async throws -> (text: String, ownerUserId: String?) {
        let collection = report.type == "comment" ? commentsCollection : postsCollection
        let doc = try await db.collection(collection).document(report.contentId).getDocument()
        let data = doc.data() ?? [:]
        let text = (data["content"] as? String) ?? "(content unavailable)"
        let owner = data["userId"] as? String
        return (text, owner)
    }

    /// Admin action: update a report's status to "reviewed" or "actioned".
    func updateReportStatus(reportId: String, status: String) async throws {
        try await db.collection("reports").document(reportId).updateData([
            "status": status,
            "reviewedAt": FieldValue.serverTimestamp()
        ])
    }

    /// Admin action: delete the reported post or comment.
    func deleteReportedContent(report: UserReport) async throws {
        let collection = report.type == "comment" ? commentsCollection : postsCollection
        try await db.collection(collection).document(report.contentId).delete()
    }

    // MARK: - Blocked Users

    func blockUser(blockingUserId: String, blockedUserId: String, blockedUserName: String) async throws {
        let docId = "\(blockingUserId)_\(blockedUserId)"
        let blockData: [String: Any] = [
            "blockingUserId": blockingUserId,
            "blockedUserId": blockedUserId,
            "blockedUserName": blockedUserName,
            "createdAt": FieldValue.serverTimestamp()
        ]
        try await db.collection("blockedUsers").document(docId).setData(blockData)
    }

    func unblockUser(blockingUserId: String, blockedUserId: String) async throws {
        let docId = "\(blockingUserId)_\(blockedUserId)"
        try await db.collection("blockedUsers").document(docId).delete()
    }

    func fetchBlockedUsers(userId: String) async throws -> [BlockedUser] {
        let snapshot = try await db.collection("blockedUsers")
            .whereField("blockingUserId", isEqualTo: userId)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: BlockedUser.self) }
    }

    func listenToBlockedUsers(
        userId: String,
        onChange: @escaping ([BlockedUser]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerRegistration {
        db.collection("blockedUsers")
            .whereField("blockingUserId", isEqualTo: userId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onError(error)
                    return
                }
                let users = (snapshot?.documents ?? []).compactMap { try? $0.data(as: BlockedUser.self) }
                onChange(users)
            }
    }

    func isUserBlocked(blockingUserId: String, blockedUserId: String) async throws -> Bool {
        let docId = "\(blockingUserId)_\(blockedUserId)"
        let doc = try await db.collection("blockedUsers").document(docId).getDocument()
        return doc.exists
    }

    // MARK: - Account Deletion (App Store §5.1.1(v) — all account data)

    func deleteAllUserData(userId: String) async throws {
        // Delete user's posts (and their Storage media via deletePost).
        let postsSnapshot = try await db.collection(postsCollection)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        for doc in postsSnapshot.documents {
            let mediaUrls: [String] = {
                guard let mediaArray = doc.data()["media"] as? [[String: Any]] else { return [] }
                return mediaArray.flatMap { entry -> [String] in
                    var urls: [String] = []
                    if let url = entry["url"] as? String { urls.append(url) }
                    if let thumb = entry["thumbnailUrl"] as? String { urls.append(thumb) }
                    return urls
                }
            }()
            try? await deletePost(postId: doc.documentID, mediaUrls: mediaUrls)
        }

        // Delete user's comments.
        let commentsSnapshot = try await db.collection(commentsCollection)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        for doc in commentsSnapshot.documents {
            try? await doc.reference.delete()
        }

        // Saved posts (bookmarks).
        let savedPostsSnapshot = try await db.collection(savedPostsCollection)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        for doc in savedPostsSnapshot.documents {
            try? await doc.reference.delete()
        }

        // Saved activities (bookmarks).
        let savedActivitiesSnapshot = try await db.collection(savedActivitiesCollection)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        for doc in savedActivitiesSnapshot.documents {
            try? await doc.reference.delete()
        }

        // Ratings the user posted on activities.
        let ratingsSnapshot = try await db.collection(ratingsCollection)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        for doc in ratingsSnapshot.documents {
            try? await doc.reference.delete()
        }

        // Block records authored by this user (their block list).
        let blocksSnapshot = try await db.collection("blockedUsers")
            .whereField("blockingUserId", isEqualTo: userId)
            .getDocuments()
        for doc in blocksSnapshot.documents {
            try? await doc.reference.delete()
        }

        // Profile image in Storage (best-effort).
        if let profileUrl = try? await db.collection(usersCollection)
            .document(userId).getDocument().data()?["profileImageUrl"] as? String,
           !profileUrl.isEmpty {
            try? await StorageManager.shared.deleteMedia(at: profileUrl)
        }

        // Delete user profile document LAST so any rules that require the
        // user doc to exist while deleting their content can still resolve.
        try await db.collection(usersCollection).document(userId).delete()

        // NOTE: the following are intentionally NOT deleted from the client:
        //   - flaggedContent  (admin-only collection — purge via Cloud Function)
        //   - mediaUploads    (admin-only collection — purge via Cloud Function)
        //   - moderationViolations (admin-only — keep for compliance audit)
        //   - reports         (admin-only — keep for moderation history)
        //   - /posts/{postId}/likes/{userId}  (subcollection — needs collection
        //                     group query + index; do via Cloud Function)
        // A cleanup Cloud Function on user deletion should sweep these.
    }

}
