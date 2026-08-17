//
//  AboutView.swift
//  Parent Chat
//
//  About & Support Information
//

import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    private let termsOfServiceURL = URL(string: "https://parentchat.app/terms")!
    private let privacyPolicyURL = URL(string: "https://parentchat.app/privacy")!

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                // App Icon & Name
                VStack(spacing: AppSpacing.lg) {
                    ZStack {
                        Circle()
                            .fill(Color.primaryGradient)
                            .frame(width: 100, height: 100)
                            .shadow(
                                color: AppShadow.large.color,
                                radius: AppShadow.large.radius,
                                x: AppShadow.large.x,
                                y: AppShadow.large.y
                            )
                        
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 45))
                            .foregroundStyle(.white)
                    }
                    
                    VStack(spacing: AppSpacing.sm) {
                        Text("Parent Chat")
                            .font(AppTypography.heading2)
                            .foregroundStyle(Color.textPrimary)
                        
                        Text("Version \(appVersion)")
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .padding(.top, AppSpacing.xl)
                
                // Description
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("About Parent Chat")
                        .font(AppTypography.heading4)
                        .foregroundStyle(Color.textPrimary)
                    
                    Text("Connect with other parents, discover kid-friendly activities, and build a supportive community. Parent Chat makes parenting easier by bringing families together.")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(Color.textSecondary)
                        .lineSpacing(4)
                }
                .professionalCard()
                .padding(.horizontal, AppSpacing.xl)
                
                // Features
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Features")
                        .font(AppTypography.heading4)
                        .foregroundStyle(Color.textPrimary)
                    
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        FeatureItem(
                            icon: "house.fill",
                            title: "Parent Pulse",
                            description: "Share local updates, tips, and trusted recommendations"
                        )
                        
                        FeatureItem(
                            icon: "map.fill",
                            title: "Activity Discovery",
                            description: "Find kid-appropriate places and activities"
                        )
                        
                        FeatureItem(
                            icon: "star.fill",
                            title: "Reviews & Ratings",
                            description: "Rate activities and share recommendations"
                        )
                    }
                }
                .professionalCard()
                .padding(.horizontal, AppSpacing.xl)
                
                // Contact & Support
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Contact & Support")
                        .font(AppTypography.heading4)
                        .foregroundStyle(Color.textPrimary)
                    
                    VStack(spacing: AppSpacing.sm) {
                        ContactItem(
                            icon: "envelope.fill",
                            label: "Email Support",
                            value: "support.chaniiapps@gmail.com",
                            action: {
                                if let url = URL(string: "mailto:support.chaniiapps@gmail.com?subject=Parent%20Chat%20Support") {
                                    UIApplication.shared.open(url)
                                }
                            }
                        )
                        
                        Divider()
                        
                        ContactItem(
                            icon: "bubble.left.and.bubble.right.fill",
                            label: "Send Feedback",
                            value: "We'd love to hear from you",
                            action: {
                                if let url = URL(string: "mailto:support.chaniiapps@gmail.com?subject=Parent%20Chat%20Feedback") {
                                    UIApplication.shared.open(url)
                                }
                            }
                        )
                    }
                }
                .professionalCard()
                .padding(.horizontal, AppSpacing.xl)
                
                // Legal
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Legal")
                        .font(AppTypography.heading4)
                        .foregroundStyle(Color.textPrimary)

                    VStack(spacing: AppSpacing.sm) {
                        ContactItem(
                            icon: "doc.plaintext.fill",
                            label: "Terms of Service",
                            value: "View our terms",
                            action: {
                                UIApplication.shared.open(termsOfServiceURL)
                            }
                        )

                        Divider()

                        ContactItem(
                            icon: "hand.raised.fill",
                            label: "Privacy Policy",
                            value: "How we use your data",
                            action: {
                                UIApplication.shared.open(privacyPolicyURL)
                            }
                        )
                    }
                }
                .professionalCard()
                .padding(.horizontal, AppSpacing.xl)

                // Credits
                VStack(spacing: AppSpacing.sm) {
                    Text("Made with ❤️ for parents")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(Color.textSecondary)
                    
                    Text("© 2026 Chanii Apps")
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(.vertical, AppSpacing.xl)
            }
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(Color.surfaceSecondary.opacity(0.3))
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeatureItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .foregroundStyle(Color.brandPrimary)
                    .font(.system(size: 18))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(Color.textPrimary)
                
                Text(description)
                    .font(AppTypography.labelSmall)
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
        }
    }
}

struct ContactItem: View {
    let icon: String
    let label: String
    let value: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            action()
            HapticManager.shared.impact(.light)
        }) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .foregroundStyle(Color.brandPrimary)
                    .font(.system(size: 20))
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(Color.textPrimary)
                    
                    Text(value)
                        .font(AppTypography.labelSmall)
                        .foregroundStyle(Color.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.textTertiary)
                    .font(.caption)
            }
            .padding(.vertical, AppSpacing.xs)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
