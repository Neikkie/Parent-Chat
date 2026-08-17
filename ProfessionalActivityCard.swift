//
//  ProfessionalActivityCard.swift
//  Parent Chat
//
//  Professional Activity Card Component
//

import SwiftUI
import MapKit

struct ProfessionalActivityCard: View {
    let activity: Activity
    let isSaved: Bool
    let userLocation: CLLocation?
    let onTap: () -> Void
    let onSave: () -> Void
    
    private var distance: String {
        guard let userLocation = userLocation else { return "" }
        
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
    
    private var categoryColor: Color {
        if activity.tags.contains("Sports") {
            return Color(red: 0.2, green: 0.6, blue: 0.9)
        } else if activity.tags.contains("Educational") {
            return Color(red: 0.5, green: 0.3, blue: 0.8)
        } else if activity.tags.contains("Arts & Crafts") {
            return Color(red: 0.9, green: 0.4, blue: 0.6)
        } else if activity.tags.contains("Music") {
            return Color(red: 0.3, green: 0.7, blue: 0.5)
        } else {
            return Color.brandPrimary
        }
    }
    
    private var categoryIcon: String {
        if activity.tags.contains("Sports") {
            return "figure.run"
        } else if activity.tags.contains("Educational") {
            return "book.fill"
        } else if activity.tags.contains("Arts & Crafts") {
            return "paintpalette.fill"
        } else if activity.tags.contains("Music") {
            return "music.note"
        } else if activity.tags.contains("Food & Drinks") {
            return "fork.knife"
        }
        return "star.fill"
    }
    
    var body: some View {
        Button(action: {
            onTap()
            HapticManager.shared.impact(.medium)
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // Header with category indicator
                HStack(spacing: AppSpacing.sm) {
                    // Category icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [categoryColor, categoryColor.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: categoryIcon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.name)
                            .font(AppTypography.heading5)
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                        
                        Text(activity.title)
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Save button
                    Button {
                        onSave()
                        HapticManager.shared.impact(.light)
                    } label: {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(isSaved ? Color.brandPrimary : Color.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(Color.surfaceSecondary)
                            .cornerRadius(AppCornerRadius.sm)
                            .symbolEffect(.bounce, value: isSaved)
                    }
                    .buttonStyle(.plain)
                }
                .padding(AppSpacing.md)
                
                // Description
                if !activity.description.isEmpty {
                    Text(activity.description)
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(2)
                        .lineSpacing(3)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.bottom, AppSpacing.sm)
                }
                
                // Location and distance
                HStack(spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "mappin.circle.fill")
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(Color.error)
                        
                        Text(activity.location.name)
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    if !distance.isEmpty {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "location.fill")
                                .font(AppTypography.labelSmall)
                                .foregroundStyle(Color.brandAccent)
                            
                            Text(distance)
                                .font(AppTypography.labelMedium)
                                .foregroundStyle(Color.brandAccent)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 4)
                        .background(Color.brandAccent.opacity(0.08))
                        .cornerRadius(AppCornerRadius.sm)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)
                
                // Tags and age groups
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    if !activity.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppSpacing.xs) {
                                ForEach(activity.tags.prefix(4), id: \.self) { tag in
                                    BadgeView(tag, color: getBadgeColor(for: tag), size: .small)
                                }
                            }
                        }
                    }
                    
                    if !activity.ageGroups.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: "figure.2.and.child.holdinghands")
                                    .font(AppTypography.labelSmall)
                                    .foregroundStyle(Color.success)
                                
                                ForEach(activity.ageGroups.prefix(3), id: \.self) { ageGroup in
                                    Text(ageGroup)
                                        .font(AppTypography.labelSmall)
                                        .foregroundStyle(Color.success)
                                        .padding(.horizontal, AppSpacing.sm)
                                        .padding(.vertical, 4)
                                        .background(Color.success.opacity(0.08))
                                        .cornerRadius(AppCornerRadius.sm)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.md)
                
                // Rating if available
                if let rating = activity.averageRating, let count = activity.ratingsCount {
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(rating.rounded()) ? "star.fill" : "star")
                                .font(AppTypography.labelSmall)
                                .foregroundStyle(Color.warning)
                        }
                        
                        Text(String(format: "%.1f", rating))
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(Color.textPrimary)
                        
                        Text("(\(count))")
                            .font(AppTypography.labelSmall)
                            .foregroundStyle(Color.textTertiary)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.md)
                }
            }
            .background(Color.surfacePrimary)
            .cornerRadius(AppCornerRadius.lg)
            .shadow(
                color: AppShadow.medium.color,
                radius: AppShadow.medium.radius,
                x: AppShadow.medium.x,
                y: AppShadow.medium.y
            )
        }
        .buttonStyle(.plain)
    }
    
    private func getBadgeColor(for tag: String) -> Color {
        switch tag {
        case "Free": return Color.success
        case "Outdoor": return Color(red: 0.2, green: 0.7, blue: 0.4)
        case "Indoor": return Color(red: 0.3, green: 0.5, blue: 0.9)
        default: return categoryColor
        }
    }
}
