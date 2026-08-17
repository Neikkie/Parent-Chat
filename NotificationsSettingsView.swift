//
//  NotificationsSettingsView.swift
//  Parent Chat
//

import SwiftUI
import UserNotifications

struct NotificationsSettingsView: View {
    @AppStorage("notif_new_comments") private var newComments = true
    @AppStorage("notif_new_likes") private var newLikes = true
    @AppStorage("notif_community_posts") private var communityPosts = false

    @State private var systemPermission: UNAuthorizationStatus = .notDetermined
    @State private var showPermissionAlert = false

    var body: some View {
        List {
            // Not yet asked — offer to turn them on (and fire a confirmation).
            if systemPermission == .notDetermined {
                Section {
                    Button {
                        Task { await enableNotifications() }
                    } label: {
                        Label("Turn On Notifications", systemImage: "bell.badge.fill")
                    }
                } footer: {
                    Text("Allow notifications to get alerts about replies, messages, and community activity.")
                }
            }

            // System permission banner
            if systemPermission == .denied {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.slash.fill")
                            .foregroundStyle(.orange)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notifications Disabled")
                                .font(.headline)
                            Text("Enable notifications in iOS Settings to receive alerts.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Toggle(isOn: $newComments) {
                    Label("New Comments", systemImage: "bubble.right.fill")
                }
                .onChange(of: newComments) { _, on in
                    if on { Task { await enableNotifications() } }
                }
                Toggle(isOn: $newLikes) {
                    Label("Likes on Your Posts", systemImage: "heart.fill")
                }
                .onChange(of: newLikes) { _, on in
                    if on { Task { await enableNotifications() } }
                }
            } header: {
                Text("Community")
            }

            Section {
                Toggle(isOn: $communityPosts) {
                    Label("New Community Posts", systemImage: "newspaper.fill")
                }
                .onChange(of: communityPosts) { _, newValue in
                    Task {
                        await NotificationManager.shared.setSubscribedToNewPosts(newValue)
                        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
                        systemPermission = status
                    }
                }
            } header: {
                Text("Feed")
            } footer: {
                Text("When enabled, you'll get a push notification when a new post is shared. Notification delivery also depends on your iOS Settings.")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            systemPermission = settings.authorizationStatus
        }
    }

    /// Requests permission (if needed) and refreshes the displayed status. On a
    /// first-time grant, NotificationManager delivers a confirmation banner.
    private func enableNotifications() async {
        let status = await NotificationManager.shared.requestAuthorization()
        systemPermission = status
    }
}

#Preview {
    NavigationStack {
        NotificationsSettingsView()
    }
}
