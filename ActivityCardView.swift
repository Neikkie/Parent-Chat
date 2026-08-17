//
//  ActivityCardView.swift
//  Parent Chat
//
//  Created by Shanique Beckford on 4/11/26.
//

import SwiftUI
import CoreLocation

struct ActivityCardView: View {
    let activity: Activity
    let userLocation: CLLocation?
    let isSaved: Bool
    let onSave: () -> Void
    var onTap: (() -> Void)? = nil
    
    var distance: String {
        guard let userLocation = userLocation else {
            return ""
        }
        
        let activityLocation = CLLocation(
            latitude: activity.location.latitude,
            longitude: activity.location.longitude
        )
        
        let distanceInMeters = userLocation.distance(from: activityLocation)
        let distanceInMiles = distanceInMeters / 1609.34
        
        if distanceInMiles < 0.1 {
            return "Nearby"
        } else if distanceInMiles < 1 {
            return String(format: "%.1f mi", distanceInMiles)
        } else {
            return String(format: "%.0f mi", distanceInMiles)
        }
    }
    
    var shareText: String {
        var text = "\(activity.name)\n\(activity.title)\n\n\(activity.description)"
        text += "\n\n📍 \(activity.location.name)"
        if !distance.isEmpty {
            text += " (\(distance) away)"
        }
        if !activity.tags.isEmpty {
            text += "\n\n🏷️ " + activity.tags.joined(separator: ", ")
        }
        text += "\n\nShared from Parent Chat"
        return text
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image or placeholder
            if let imageUrls = activity.imageUrls, let firstImage = imageUrls.first {
                AsyncImage(url: URL(string: firstImage)) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 200)
                            .overlay {
                                ProgressView()
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 200)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(height: 200)
                    .overlay {
                        VStack {
                            Image(systemName: "figure.play")
                                .font(.system(size: 50))
                                .foregroundStyle(.white)
                            Text(activity.name)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 12) {
                // Header with name and save button
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(activity.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(activity.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        ShareLink(item: shareText) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        
                        Button {
                            HapticManager.shared.impact(.light)
                            onSave()
                        } label: {
                            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                .font(.title2)
                                .foregroundStyle(isSaved ? .blue : .secondary)
                                .symbolEffect(.bounce, value: isSaved)
                        }
                        .buttonStyle(.scale)
                    }
                }
                
                // Location and distance
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                    
                    Text(activity.location.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if !distance.isEmpty {
                        Text("•")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        
                        Text(distance)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                    }
                    
                    // Rating
                    if let averageRating = activity.averageRating, let ratingsCount = activity.ratingsCount, ratingsCount > 0 {
                        Text("•")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", averageRating))
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("(\(ratingsCount))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Age groups
                if !activity.ageGroups.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(activity.ageGroups, id: \.self) { ageGroup in
                                Text(ageGroup)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.purple.opacity(0.1))
                                    .foregroundStyle(.purple)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
                
                // Tags
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(activity.tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                if let icon = tagIcon(for: tag) {
                                    Image(systemName: icon)
                                        .font(.caption2)
                                }
                                Text(tag)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(tagColor(for: tag))
                            .foregroundStyle(tagTextColor(for: tag))
                            .cornerRadius(12)
                        }
                    }
                }
            }
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
    
    private func tagIcon(for tag: String) -> String? {
        switch tag {
        case "Free": return "dollarsign.circle"
        case "Outdoor": return "sun.max"
        case "Indoor": return "house"
        case "Educational": return "book"
        case "Sports": return "figure.run"
        case "Arts & Crafts": return "paintpalette"
        case "Music": return "music.note"
        case "Food & Drinks": return "fork.knife"
        default: return nil
        }
    }
    
    private func tagColor(for tag: String) -> Color {
        switch tag {
        case "Free": return Color.green.opacity(0.1)
        case "Outdoor": return Color.orange.opacity(0.1)
        case "Indoor": return Color.blue.opacity(0.1)
        case "Educational": return Color.purple.opacity(0.1)
        case "Sports": return Color.red.opacity(0.1)
        case "Arts & Crafts": return Color.pink.opacity(0.1)
        case "Music": return Color.indigo.opacity(0.1)
        case "Food & Drinks": return Color.brown.opacity(0.1)
        default: return Color.gray.opacity(0.1)
        }
    }
    
    private func tagTextColor(for tag: String) -> Color {
        switch tag {
        case "Free": return .green
        case "Outdoor": return .orange
        case "Indoor": return .blue
        case "Educational": return .purple
        case "Sports": return .red
        case "Arts & Crafts": return .pink
        case "Music": return .indigo
        case "Food & Drinks": return .brown
        default: return .gray
        }
    }
}

#Preview {
    ActivityCardView(
        activity: Activity(
            name: "Kids Yoga Class",
            title: "Weekly yoga sessions for children",
            description: "Fun and engaging yoga classes",
            location: PostLocation(name: "Central Park, NYC", latitude: 40.7829, longitude: -73.9654),
            ageGroups: ["3-5 years", "5-12 years"],
            tags: ["Free", "Outdoor", "Educational"],
            createdBy: "123",
            createdByName: "Jane Doe",
            createdAt: Date()
        ),
        userLocation: nil,
        isSaved: false,
        onSave: {}
    )
    .padding()
}
