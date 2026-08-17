//
//  AuthenticationManager.swift
//  Parent Chat
//
//  Created by Shanique Beckford on 4/6/26.
//

import Foundation
import SwiftUI
import FirebaseAuth
import AuthenticationServices
import CryptoKit

@MainActor
@Observable
class AuthenticationManager {
    var isAuthenticated = false
    var currentUser: User?
    var userProfile: UserProfile?
    var errorMessage: String?
    var isLoadingProfile = false

    /// Hard-coded admin emails (moderators with access to the Reports inbox).
    private static let adminEmails: Set<String> = ["support.chaniiapps@gmail.com"]

    var isAdmin: Bool {
        // Backed by Firebase Custom Claims (see setAdminClaim Cloud Function).
        // Falls back to the hardcoded admin email list during transition; the
        // RULE is the security boundary, not this property.
        if isAdminFromClaim { return true }
        guard let email = currentUser?.email?.lowercased() else { return false }
        return Self.adminEmails.contains(email)
    }

    /// Cached value of the `admin` custom claim from the ID token, refreshed on auth state change.
    var isAdminFromClaim: Bool = false

    /// The safest public-facing display name for the current user.
    /// Never falls back to email (which would dox users on every post/comment).
    var publicDisplayName: String {
        if let username = userProfile?.username, !username.isEmpty {
            return username
        }
        if let displayName = userProfile?.displayName, !displayName.isEmpty {
            return displayName
        }
        if let firebaseName = currentUser?.displayName, !firebaseName.isEmpty {
            return firebaseName
        }
        if let uid = currentUser?.uid {
            return "Parent #\(String(uid.prefix(6)))"
        }
        return "Anonymous"
    }

    private var currentNonce: String?
    private let profileCacheKey = "cached_user_profile"

    init() {
        // Restore cached profile immediately so returning users see no spinner
        if let user = Auth.auth().currentUser {
            self.isAuthenticated = true
            self.currentUser = user
            self.userProfile = loadCachedProfile()
            // Mark as loading so RootView shows spinner (not error state) until listener fires
            if self.userProfile == nil {
                self.isLoadingProfile = true
            }
        }

        // Auth state listener fires immediately and refreshes from Firestore in background.
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isAuthenticated = user != nil
                self?.currentUser = user

                if let user = user {
                    try? await self?.loadUserProfile(uid: user.uid)
                    await self?.refreshAdminClaim()
                } else {
                    self?.userProfile = nil
                    self?.isAdminFromClaim = false
                    self?.isLoadingProfile = false
                    self?.clearCachedProfile()
                }
            }
        }
    }

    /// Re-fetch the ID token to pick up server-set custom claims (e.g., admin).
    func refreshAdminClaim() async {
        guard let user = currentUser else {
            isAdminFromClaim = false
            return
        }
        do {
            let result = try await user.getIDTokenResult(forcingRefresh: true)
            isAdminFromClaim = (result.claims["admin"] as? Bool) == true
        } catch {
            isAdminFromClaim = false
        }
    }

    // Load user profile from Firestore and update cache
    func loadUserProfile(uid: String) async throws {
        isLoadingProfile = true
        defer { isLoadingProfile = false }

        let profile = try await FirestoreManager.shared.fetchUserProfile(uid: uid)
        if let profile, profile.isSuspended == true {
            errorMessage = "Your account is suspended pending review. Contact support.chaniiapps@gmail.com for release."
            resetAuthState()
            throw NSError(domain: "AuthenticationManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "Account suspended"])
        }

        userProfile = profile
        if let profile { cacheProfile(profile) }

        // Now that we have a signed-in uid, persist this device's push token.
        NotificationManager.shared.refreshFCMTokenIfPossible()
    }

    // Sign out and reset all auth state — used when profile loading fails
    private func resetAuthState() {
        try? Auth.auth().signOut()
        isAuthenticated = false
        currentUser = nil
        userProfile = nil
        isLoadingProfile = false
        clearCachedProfile()
    }

    // MARK: - Profile cache (UserDefaults)

    private func loadCachedProfile() -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: profileCacheKey),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else { return nil }
        return profile
    }

    private func cacheProfile(_ profile: UserProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileCacheKey)
        }
    }

    private func clearCachedProfile() {
        UserDefaults.standard.removeObject(forKey: profileCacheKey)
    }
    
    // Refresh current user profile from Firestore (throws on failure)
    func refreshCurrentUser() async throws {
        guard let uid = currentUser?.uid else { return }
        try await loadUserProfile(uid: uid)
    }

    // Retry loading profile after a failure (clears error message first)
    func retryLoadProfile() {
        guard let uid = currentUser?.uid else { return }
        errorMessage = nil
        Task {
            do {
                try await FirestoreManager.shared.createOrUpdateUser(authUser: Auth.auth().currentUser!)
                try await loadUserProfile(uid: uid)
            } catch {
                self.errorMessage = "Couldn't load your profile. Check your connection and try again."
                self.isLoadingProfile = false
            }
        }
    }

    // Prepare Sign in with Apple request
    func prepareSignInRequest(request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        let nonce = randomNonceString()
        currentNonce = nonce
        request.nonce = sha256(nonce)
    }
    
    // Handle Sign in with Apple
    func handleSignInWithApple(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard let nonce = currentNonce else {
                    errorMessage = "Invalid state: A login callback was received, but no login request was sent."
                    return
                }
                
                guard let appleIDToken = appleIDCredential.identityToken else {
                    errorMessage = "Unable to fetch identity token"
                    return
                }
                
                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                    errorMessage = "Unable to serialize token string from data"
                    return
                }
                
                // Create Firebase credential
                let credential = OAuthProvider.appleCredential(
                    withIDToken: idTokenString,
                    rawNonce: nonce,
                    fullName: appleIDCredential.fullName
                )
                
                // Sign in with Firebase
                Task {
                    do {
                        let result = try await Auth.auth().signIn(with: credential)
                        errorMessage = nil

                        // Sequential: create the Firestore doc first, then load the
                        // profile. The auth state listener may fire concurrently but
                        // this call guarantees the doc exists before we read it.
                        do {
                            try await FirestoreManager.shared.createOrUpdateUser(authUser: result.user)
                            try await self.loadUserProfile(uid: result.user.uid)
                        } catch {
                            // Don't sign out — user is authenticated. Let them retry from the error state.
                            self.errorMessage = "Couldn't load your profile. Check your connection and try again."
                            self.isLoadingProfile = false
                        }
                    } catch {
                        errorMessage = "Sign in failed: \(error.localizedDescription)"
                    }
                }
            }

        case .failure(let error):
            errorMessage = "Authorization failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Email / Password

    /// Sign in with an email + password so users without an Apple ID configured
    /// in iOS Settings can still access the app.
    func signIn(email: String, password: String) async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }
        errorMessage = nil
        do {
            let result = try await Auth.auth().signIn(withEmail: trimmedEmail, password: password)
            do {
                try await FirestoreManager.shared.createOrUpdateUser(authUser: result.user)
                try await loadUserProfile(uid: result.user.uid)
            } catch {
                errorMessage = "Couldn't load your profile. Check your connection and try again."
                isLoadingProfile = false
            }
        } catch {
            errorMessage = "Sign in failed: \(error.localizedDescription)"
        }
    }

    /// Create a new account with email + password.
    func signUp(email: String, password: String) async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        errorMessage = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: trimmedEmail, password: password)
            do {
                try await FirestoreManager.shared.createOrUpdateUser(authUser: result.user)
                try await loadUserProfile(uid: result.user.uid)
            } catch {
                errorMessage = "Couldn't load your profile. Check your connection and try again."
                isLoadingProfile = false
            }
        } catch {
            errorMessage = "Sign up failed: \(error.localizedDescription)"
        }
    }

    /// Send a password reset email through Firebase Auth.
    func sendPasswordReset(email: String) async -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            errorMessage = "Enter your email to reset your password."
            return false
        }
        do {
            try await Auth.auth().sendPasswordReset(withEmail: trimmedEmail)
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Couldn't send reset email: \(error.localizedDescription)"
            return false
        }
    }

    // Generate nonce for Sign in with Apple
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    // SHA256 hash for nonce
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    // Sign out
    func signOut() {
        // Stop this device from receiving pushes for the account being left.
        if let uid = currentUser?.uid {
            NotificationManager.shared.clearFCMTokenOnSignOut(userId: uid)
        }
        do {
            try Auth.auth().signOut()
            errorMessage = nil
        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
        }
    }

    // Delete account and all associated data
    func deleteAccount() async throws {
        guard let user = currentUser else {
            throw NSError(domain: "AuthenticationManager", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No user signed in"])
        }
        // Delete all Firestore data first
        try await FirestoreManager.shared.deleteAllUserData(userId: user.uid)
        // Delete the Firebase Auth account
        try await user.delete()
    }

    /// Deactivate the account — keeps all data, hides the user from the
    /// community as "Deactivated user," and signs them out. Reversible by
    /// signing back in and tapping Reactivate.
    func deactivateAccount() async throws {
        guard let user = currentUser else {
            throw NSError(domain: "AuthenticationManager", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No user signed in"])
        }
        try await FirestoreManager.shared.setAccountDeactivated(userId: user.uid, deactivated: true)
        UserDirectory.shared.invalidate(userId: user.uid)
        signOut()
    }

    /// Reactivates the currently signed-in account (clears the deactivated flag).
    func reactivateAccount() async throws {
        guard let user = currentUser else { return }
        try await FirestoreManager.shared.setAccountDeactivated(userId: user.uid, deactivated: false)
        UserDirectory.shared.invalidate(userId: user.uid)
        try await loadUserProfile(uid: user.uid)
    }
}
