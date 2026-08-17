//
//  RateActivityView.swift
//  Parent Chat
//
//  Created by Shanique Beckford on 4/11/26.
//

import SwiftUI
import FirebaseAuth

struct RateActivityView: View {
    @Environment(\.dismiss) var dismiss
    let activity: Activity
    var onRated: () async -> Void
    
    @State private var rating: Double = 0
    @State private var review: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var existingRating: ActivityRating?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 16) {
                        Text(activity.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        // Star rating
                        HStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { star in
                                Button {
                                    HapticManager.shared.impact(.light)
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        rating = Double(star)
                                    }
                                } label: {
                                    Image(systemName: Double(star) <= rating ? "star.fill" : "star")
                                        .font(.system(size: 40))
                                        .foregroundStyle(
                                            Double(star) <= rating ?
                                            LinearGradient(
                                                colors: [.yellow, .orange],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ) :
                                            LinearGradient(
                                                colors: [.gray.opacity(0.3), .gray.opacity(0.3)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .shadow(color: Double(star) <= rating ? .yellow.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
                                }
                                .buttonStyle(.scale)
                            }
                        }
                        
                        if rating > 0 {
                            Text(ratingText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } header: {
                    Text("Your Rating")
                }
                
                Section {
                    TextField("Share your experience (optional)", text: $review, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Review")
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Rate Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task {
                            await submitRating()
                        }
                    }
                    .disabled(rating == 0 || isSubmitting)
                }
            }
            .task {
                await loadExistingRating()
            }
            .disabled(isSubmitting)
            .overlay {
                if isSubmitting {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Submitting rating...")
                                .font(.headline)
                        }
                        .padding(30)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }
    
    var ratingText: String {
        switch rating {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Very Good"
        case 5: return "Excellent"
        default: return ""
        }
    }
    
    private func loadExistingRating() async {
        guard let userId = Auth.auth().currentUser?.uid,
              let activityId = activity.id else { return }
        
        do {
            if let existing = try await FirestoreManager.shared.getUserRating(activityId: activityId, userId: userId) {
                existingRating = existing
                rating = existing.rating
                review = existing.review ?? ""
            }
        } catch {
            print("Error loading existing rating: \(error.localizedDescription)")
        }
    }
    
    private func submitRating() async {
        guard let userId = Auth.auth().currentUser?.uid,
              let activityId = activity.id else { return }
        // Email/password users often have no displayName — fall back so they
        // can still submit a rating.
        let userName = Auth.auth().currentUser?.displayName ?? "Parent"

        isSubmitting = true
        errorMessage = nil
        
        do {
            try await FirestoreManager.shared.rateActivity(
                activityId: activityId,
                userId: userId,
                userName: userName,
                rating: rating,
                review: review.isEmpty ? nil : review
            )
            
            HapticManager.shared.success()
            await onRated()
            dismiss()
        } catch {
            errorMessage = "Failed to submit rating: \(error.localizedDescription)"
            isSubmitting = false
        }
    }
}

#Preview {
    RateActivityView(activity: Activity(
        id: "1",
        name: "Test Activity",
        title: "Fun for all",
        description: "A great activity",
        location: PostLocation(name: "Test Location", latitude: 0, longitude: 0),
        ageGroups: [],
        tags: [],
        createdBy: "123",
        createdByName: "Test User",
        createdAt: Date()
    )) {
        print("Rated")
    }
}
