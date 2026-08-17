//
//  Parent_ChatApp.swift
//  Parent Chat
//
//  Created by Shanique Beckford on 4/6/26.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import UserNotifications
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    // Firebase is configured in the App's init.
    // Become the notification delegate so alerts display even while the app is
    // in the foreground (otherwise iOS silently suppresses them).
    UNUserNotificationCenter.current().delegate = self
    #if canImport(FirebaseMessaging)
    Messaging.messaging().delegate = self
    #endif
    return true
  }

  // Present banners/sound/badges while the app is open.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .list, .sound, .badge]
  }

  // Hand the APNs device token to Firebase so it can mint an FCM token.
  func application(_ application: UIApplication,
                   didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    #if canImport(FirebaseMessaging)
    Messaging.messaging().apnsToken = deviceToken
    #endif
  }

  func application(_ application: UIApplication,
                   didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("⚠️ Remote notification registration failed: \(error.localizedDescription)")
  }
}

#if canImport(FirebaseMessaging)
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    Task { @MainActor in
      NotificationManager.shared.handleFCMToken(fcmToken)
    }
  }
}
#endif

@main
struct Parent_ChatApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @State private var authManager = AuthenticationManager()
    @State private var appearanceManager = AppearanceManager()

    var body: some View {
        ZStack {
            if authManager.isAuthenticated {
                if authManager.userProfile == nil {
                    if authManager.isLoadingProfile {
                        // Profile fetch in progress — show spinner
                        ZStack {
                            Color.surfacePrimary.ignoresSafeArea()
                            VStack(spacing: 16) {
                                Circle()
                                    .fill(Color.primaryGradient)
                                    .frame(width: 72, height: 72)
                                    .overlay {
                                        Image(systemName: "person.2.fill")
                                            .font(.system(size: 28))
                                            .foregroundStyle(.white)
                                    }
                                ProgressView()
                                    .tint(Color.brandPrimary)
                            }
                        }
                        .transition(.opacity)
                    } else {
                        // Loading finished but profile is nil — show error with retry
                        ZStack {
                            Color.surfacePrimary.ignoresSafeArea()
                            VStack(spacing: 20) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(Color.brandPrimary)
                                Text("Couldn't load your profile")
                                    .font(.headline)
                                    .foregroundStyle(Color.textPrimary)
                                if let msg = authManager.errorMessage {
                                    Text(msg)
                                        .font(.caption)
                                        .foregroundStyle(Color.textSecondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 32)
                                }
                                Button("Try Again") {
                                    authManager.retryLoadProfile()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color.brandPrimary)
                                Button("Sign Out") {
                                    authManager.signOut()
                                }
                                .foregroundStyle(Color.textSecondary)
                                .font(.footnote)
                            }
                        }
                        .transition(.opacity)
                    }
                } else if let profile = authManager.userProfile, profile.ageConfirmed != true {
                    // Adults-only (18+) age assurance — gate before anything else.
                    AgeGateView()
                        .environment(authManager)
                        .environment(appearanceManager)
                        .transition(.opacity)
                } else if let profile = authManager.userProfile, !profile.isProfileComplete {
                    // New user — show onboarding
                    ProfileSetupView()
                        .environment(authManager)
                        .environment(appearanceManager)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                } else if let profile = authManager.userProfile, profile.isDeactivated == true {
                    // Account is deactivated — show reactivation gate.
                    ReactivateAccountView()
                        .environment(authManager)
                        .environment(appearanceManager)
                        .transition(.opacity)
                } else if let profile = authManager.userProfile,
                          (profile.eulaAccepted != true || profile.eulaAcceptedVersion != CURRENT_EULA_VERSION) {
                    // Required community agreement (Apple §1.2 UGC). Re-prompts
                    // every user whose accepted version doesn't match the
                    // current one, so updates to the agreement aren't silent.
                    EULAAcceptanceView()
                        .environment(authManager)
                        .environment(appearanceManager)
                        .transition(.opacity)
                } else {
                    // Returning user — main app
                    ContentView()
                        .environment(authManager)
                        .environment(appearanceManager)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            } else {
                ProfessionalSignInView()
                    .environment(authManager)
                    .environment(appearanceManager)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: authManager.isAuthenticated)
        .animation(.easeInOut(duration: 0.35), value: authManager.isLoadingProfile)
        .preferredColorScheme(appearanceManager.selectedMode.colorScheme)
    }
}
