//
//  SavedActivitiesView.swift
//  Parent Chat
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SavedActivitiesView: View {
    @State private var activities: [Activity] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var savedActivitiesListener: ListenerRegistration?

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading saved activities...")
                    .padding(.top, 40)
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
            } else if activities.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                    Text("No saved activities")
                        .font(.headline)
                    Text("Activities you bookmark will appear here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 60)
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(activities) { activity in
                        ActivityCardView(
                            activity: activity,
                            userLocation: nil,
                            isSaved: true,
                            onSave: {
                                Task { await toggleSave(for: activity) }
                            }
                        )
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Saved Activities")
        .navigationBarTitleDisplayMode(.inline)
        .task { startSavedActivitiesListener() }
        .onDisappear {
            savedActivitiesListener?.remove()
            savedActivitiesListener = nil
        }
    }

    private func startSavedActivitiesListener() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        savedActivitiesListener?.remove()
        isLoading = true
        errorMessage = nil

        savedActivitiesListener = FirestoreManager.shared.listenToSavedActivities(userId: userId) { updated in
            DispatchQueue.main.async {
                activities = updated
                isLoading = false
            }
        } onError: { error in
            DispatchQueue.main.async {
                errorMessage = "Failed to load saved activities: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    private func toggleSave(for activity: Activity) async {
        guard let userId = Auth.auth().currentUser?.uid,
              let activityId = activity.id else { return }

        do {
            _ = try await FirestoreManager.shared.toggleSaveActivity(activityId: activityId, userId: userId)
        } catch { }
    }
}
