//
//  NotificationManager.swift
//  Parent Chat
//
//  Centralizes notification permission + subscription to topic-based push.
//  The actual delivery requires Firebase Cloud Messaging (FCM) to be linked
//  and an APNs auth key uploaded to Firebase Console — see
//  functions/notifyOnNewPost.js for the trigger Cloud Function.
//

import Foundation
import UserNotifications
import UIKit
import FirebaseAuth
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    /// The most recent FCM registration token for this device (if any).
    private(set) var currentFCMToken: String?

    private init() {}

    /// Persists the FCM token for the signed-in user so pushes can reach this
    /// device. Called from the Messaging delegate and after sign-in. The token
    /// is a plain String, so this compiles whether or not FirebaseMessaging is
    /// linked yet.
    func handleFCMToken(_ token: String?) {
        currentFCMToken = token
        guard let token, let uid = Auth.auth().currentUser?.uid else { return }
        Task { try? await FirestoreManager.shared.saveFCMToken(token, userId: uid) }
    }

    /// Asks Firebase for the current token and stores it. No-op until the
    /// FirebaseMessaging package is linked into the target.
    func refreshFCMTokenIfPossible() {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().token { [weak self] token, _ in
            Task { @MainActor in self?.handleFCMToken(token) }
        }
        #endif
    }

    /// Best-effort removal of this device's token on sign-out.
    func clearFCMTokenOnSignOut(userId: String) {
        guard let token = currentFCMToken else { return }
        Task { try? await FirestoreManager.shared.deleteFCMToken(token, userId: userId) }
    }

    /// Request system permission to show notifications. Safe to call repeatedly.
    /// Returns the resolved authorization status. When the user grants
    /// permission for the first time, a confirmation notification is delivered
    /// so they immediately see one appear on their device.
    @discardableResult
    func requestAuthorization() async -> UNAuthorizationStatus {
        let center = UNUserNotificationCenter.current()
        let previous = await center.notificationSettings().authorizationStatus

        if previous == .notDetermined {
            let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            if granted {
                await registerForRemoteNotificationsIfAuthorized()
                refreshFCMTokenIfPossible()
                await sendEnabledConfirmation()
                return .authorized
            }
        }

        await registerForRemoteNotificationsIfAuthorized()
        refreshFCMTokenIfPossible()
        return await center.notificationSettings().authorizationStatus
    }

    /// Delivers a local notification confirming notifications are on. Because a
    /// local notification doesn't need a server/APNs, it guarantees the user
    /// sees a notification appear the moment they allow them.
    func sendEnabledConfirmation() async {
        let content = UNMutableNotificationContent()
        content.title = "Notifications are on"
        content.body = "You're all set — we'll let you know when there's new activity in Parent Chat."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "notifications-enabled-confirmation",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Subscribes (or unsubscribes) the device from receiving "new post" pushes.
    /// Implementation note: while FirebaseMessaging is not yet linked into the
    /// project, this is a no-op other than recording the user's preference.
    /// Once `import FirebaseMessaging` is added, swap the body for:
    ///
    ///   if enabled {
    ///       try await Messaging.messaging().subscribe(toTopic: "new-posts")
    ///   } else {
    ///       try await Messaging.messaging().unsubscribe(fromTopic: "new-posts")
    ///   }
    func setSubscribedToNewPosts(_ enabled: Bool) async {
        UserDefaults.standard.set(enabled, forKey: "notif_community_posts")
        if enabled {
            await requestAuthorization()
        }
        #if canImport(FirebaseMessaging)
        if enabled {
            try? await Messaging.messaging().subscribe(toTopic: "new-posts")
        } else {
            try? await Messaging.messaging().unsubscribe(fromTopic: "new-posts")
        }
        #endif
    }

    private func registerForRemoteNotificationsIfAuthorized() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }
}
