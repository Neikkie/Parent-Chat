//
//  ProfessionalPostCard.swift
//  Parent Chat
//
//  Professional Post Card Component
//

import SwiftUI
import FirebaseFirestore

struct ProfessionalPostCard: View {
    let post: Post
    let isLiked: Bool
    let isSaved: Bool
    let onLike: () -> Void
    let onComment: () -> Void
    let onSave: () -> Void
    let onShare: () -> Void
    
    @State private var showFullText = false
    
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: post.createdAt, relativeTo: Date())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: AppSpacing.sm) {
                // User avatar
                ZStack {
                    if let urlString = post.userProfileImageUrl,
                       let url = URL.httpsOnly(urlString) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(Color.primaryGradient)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.7)
                                )
                        }
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.brandPrimary, Color.brandSecondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(String(post.displayName.prefix(1)))
                                    .font(AppTypography.labelLarge)
                                    .foregroundStyle(.white)
                            )
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.displayName)
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(Color.textPrimary)
                    
                    Text(timeAgo)
                        .font(AppTypography.labelSmall)
                        .foregroundStyle(Color.textTertiary)
                }
                
                Spacer()
                
                // More options button
                Button {
                    HapticManager.shared.impact(.light)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Color.surfaceSecondary)
                        .cornerRadius(AppCornerRadius.sm)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)
            
            // Content
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Text content
                Text(post.content)
                    .font(AppTypography.bodyLarge)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(showFullText ? nil : 4)
                    .lineSpacing(4)
                
                if post.content.count > 150 {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showFullText.toggle()
                        }
                        HapticManager.shared.selection()
                    } label: {
                        Text(showFullText ? "Show less" : "Show more")
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(Color.brandPrimary)
                    }
                }
                
                // Location if available
                if let location = post.location {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "mappin.circle.fill")
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(Color.brandAccent)
                        
                        Text(location.name)
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(Color.brandAccent.opacity(0.08))
                    .cornerRadius(AppCornerRadius.sm)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.sm)
            
            // Images if available
            if let media = post.media, !media.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(media.filter { $0.type == .image }) { mediaItem in
                            AsyncImage(url: URL.httpsOnly(mediaItem.url)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.surfaceSecondary)
                                    .overlay(
                                        ProgressView()
                                            .tint(Color.brandPrimary)
                                    )
                            }
                            .frame(width: 280, height: 200)
                            .cornerRadius(AppCornerRadius.md)
                            .clipped()
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                }
                .padding(.bottom, AppSpacing.sm)
            }
            
            // Engagement stats
            HStack(spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "heart.fill")
                        .font(AppTypography.labelSmall)
                        .foregroundStyle(Color.error)

                    Text("\(post.likesCount)")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(Color.textSecondary)
                }

                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "bubble.fill")
                        .font(AppTypography.labelSmall)
                        .foregroundStyle(Color.brandPrimary)

                    Text("\(post.commentsCount)")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.xs)
            
            Divider()
                .padding(.horizontal, AppSpacing.md)
            
            // Action buttons
            HStack(spacing: 0) {
                ActionButton(
                    icon: isLiked ? "heart.fill" : "heart",
                    label: "Like",
                    color: isLiked ? Color.error : Color.textSecondary,
                    action: onLike
                )
                
                ActionButton(
                    icon: "bubble.left",
                    label: "Comment",
                    color: Color.textSecondary,
                    action: onComment
                )
                
                ActionButton(
                    icon: isSaved ? "bookmark.fill" : "bookmark",
                    label: "Save",
                    color: isSaved ? Color.brandPrimary : Color.textSecondary,
                    action: onSave
                )
                
                ActionButton(
                    icon: "square.and.arrow.up",
                    label: "Share",
                    color: Color.textSecondary,
                    action: onShare
                )
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
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
}

struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button {
            action()
            HapticManager.shared.impact(.light)
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    isPressed = false
                }
            }
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(color)
                
                Text(label)
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(isPressed ? Color.surfaceSecondary : Color.clear)
            .cornerRadius(AppCornerRadius.sm)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
