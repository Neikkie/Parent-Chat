//
//  ActivityDetailView.swift
//  Parent Chat
//
//  Detail screen for a Discover activity: hero image, description, tags,
//  a Get Directions button, the star rating summary, the list of reviews,
//  and a way to add your own rating.
//

import SwiftUI
import MapKit
import CoreLocation
import FirebaseAuth
import FirebaseFirestore

// Reusable star display for a 0–5 rating (supports half stars).
struct StarRatingView: View {
    let rating: Double
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: symbol(for: index))
                    .font(.system(size: size))
                    .foregroundStyle(.yellow)
            }
        }
        .accessibilityLabel(String(format: "%.1f out of 5 stars", rating))
    }

    private func symbol(for index: Int) -> String {
        let value = Double(index)
        if rating >= value { return "star.fill" }
        if rating >= value - 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }
}

struct ActivityDetailView: View {
    let activity: Activity
    let userLocation: CLLocation?
    var onRated: () async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var ratings: [ActivityRating] = []
    @State private var isLoadingRatings = false
    @State private var showRateSheet = false

    // Live average/count computed from the loaded ratings (falls back to the
    // denormalized values on the activity until ratings load).
    private var averageRating: Double {
        if !ratings.isEmpty {
            return ratings.reduce(0) { $0 + $1.rating } / Double(ratings.count)
        }
        return activity.averageRating ?? 0
    }

    private var ratingsCount: Int {
        ratings.isEmpty ? (activity.ratingsCount ?? 0) : ratings.count
    }

    private var distance: String {
        guard let userLocation else { return "" }
        let loc = CLLocation(latitude: activity.location.latitude, longitude: activity.location.longitude)
        let miles = userLocation.distance(from: loc) / 1609.34
        if miles < 0.1 { return "Nearby" }
        if miles < 1 { return String(format: "%.1f mi away", miles) }
        return String(format: "%.0f mi away", miles)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroImage

                    VStack(alignment: .leading, spacing: 16) {
                        header
                        ratingSummary
                        directionsButton
                        locationRow

                        if !activity.description.isEmpty {
                            section("About") {
                                Text(activity.description).font(.body)
                            }
                        }

                        if !activity.ageGroups.isEmpty {
                            chips(activity.ageGroups, color: .purple, title: "Age Groups")
                        }
                        if !activity.tags.isEmpty {
                            chips(activity.tags, color: .blue, title: "Tags")
                        }

                        if let website = activity.website, let url = URL.httpsOnly(website) {
                            section("Website") {
                                Link(website, destination: url).font(.body)
                            }
                        }
                        if let contact = activity.contactInfo, !contact.isEmpty {
                            section("Contact") {
                                Text(contact).font(.body)
                            }
                        }

                        Divider().padding(.vertical, 4)

                        reviewsSection
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .navigationTitle(activity.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await loadRatings() }
            .sheet(isPresented: $showRateSheet) {
                RateActivityView(activity: activity) {
                    await loadRatings()
                    await onRated()
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var heroImage: some View {
        if let imageUrls = activity.imageUrls, let first = imageUrls.first, let url = URL.httpsOnly(first) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(Color(.systemGray5))
            }
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .clipped()
        } else {
            Rectangle()
                .fill(LinearGradient(colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 220)
                .overlay {
                    Image(systemName: "figure.play")
                        .font(.system(size: 54))
                        .foregroundStyle(.white)
                }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(activity.name).font(.title2).fontWeight(.bold)
            if !activity.title.isEmpty {
                Text(activity.title).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var ratingSummary: some View {
        HStack(spacing: 8) {
            StarRatingView(rating: averageRating, size: 18)
            if ratingsCount > 0 {
                Text(String(format: "%.1f", averageRating))
                    .font(.subheadline).fontWeight(.semibold)
                Text("(\(ratingsCount) \(ratingsCount == 1 ? "rating" : "ratings"))")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text("No ratings yet")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var directionsButton: some View {
        Button {
            openDirections()
            HapticManager.shared.impact(.light)
        } label: {
            HStack {
                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                Text("Get Directions").fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundStyle(.white)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private var locationRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.circle.fill").foregroundStyle(.red)
            Text(activity.location.name).font(.subheadline)
            if !distance.isEmpty {
                Text("• \(distance)").font(.caption).foregroundStyle(.blue)
            }
        }
    }

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ratings & Reviews").font(.headline)
                Spacer()
                Button {
                    showRateSheet = true
                    HapticManager.shared.selection()
                } label: {
                    Label("Rate", systemImage: "star.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if isLoadingRatings {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12)
            } else if ratings.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "star").font(.title2).foregroundStyle(.secondary)
                    Text("Be the first to rate this activity")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
            } else {
                ForEach(ratings) { rating in
                    ReviewRow(rating: rating)
                    if rating.id != ratings.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }

    private func chips(_ items: [String], color: Color, title: String) -> some View {
        section(title) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        Text(item)
                            .font(.caption)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(color.opacity(0.1))
                            .foregroundStyle(color)
                            .cornerRadius(12)
                    }
                }
            }
        }
    }

    private func openDirections() {
        let coordinate = CLLocationCoordinate2D(
            latitude: activity.location.latitude,
            longitude: activity.location.longitude
        )
        let clLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let mapItem = MKMapItem(location: clLocation, address: nil)
        mapItem.name = activity.location.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func loadRatings() async {
        guard let activityId = activity.id else { return }
        isLoadingRatings = true
        ratings = (try? await FirestoreManager.shared.fetchActivityRatings(activityId: activityId)) ?? []
        isLoadingRatings = false
    }
}

private struct ReviewRow: View {
    let rating: ActivityRating

    private var reviewerName: String {
        let raw = rating.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty || raw.contains("@") {
            return "Parent #\(String(rating.userId.prefix(6)))"
        }
        return raw
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(reviewerName).font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text(rating.createdAt, style: .date)
                    .font(.caption).foregroundStyle(.secondary)
            }
            StarRatingView(rating: rating.rating, size: 13)
            if let review = rating.review, !review.isEmpty {
                Text(review).font(.body).foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 6)
    }
}
