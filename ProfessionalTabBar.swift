//
//  ProfessionalTabBar.swift
//  Parent Chat
//
//  Professional Tab Bar Navigation
//

import SwiftUI

struct ProfessionalTabBar: View {
    @Binding var selectedTab: Tab

    enum Tab: String, CaseIterable {
        case community = "Home"
        case activities = "Discover"
        case map = "Map"
        case profile = "Me"

        var icon: String {
            switch self {
            case .community: return "house"
            case .activities: return "sparkles"
            case .map: return "map"
            case .profile: return "person.circle"
            }
        }

        var selectedIcon: String {
            switch self {
            case .community: return "house.fill"
            case .activities: return "sparkles"
            case .map: return "map.fill"
            case .profile: return "person.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .community: return Color.brandPrimary
            case .activities: return Color.brandAccent
            case .map: return Color.success
            case .profile: return Color(red: 0.9, green: 0.45, blue: 0.3)
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                    HapticManager.shared.selection()
                }
            }
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, AppSpacing.xs)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: AppCornerRadius.xl, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.xl, style: .continuous)
                .stroke(Color.textTertiary.opacity(0.1), lineWidth: 1)
        )
        .shadow(
            color: AppShadow.large.color,
            radius: AppShadow.large.radius,
            x: AppShadow.large.x,
            y: AppShadow.large.y
        )
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
    }
}

struct TabBarButton: View {
    let tab: ProfessionalTabBar.Tab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                            .fill(tab.color.opacity(0.12))
                            .frame(width: 44, height: 26)
                    }

                    Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                        .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? tab.color : Color.textSecondary)
                        .symbolEffect(.bounce, value: isSelected)
                }

                Text(tab.rawValue)
                    .font(AppTypography.labelSmall)
                    .foregroundStyle(isSelected ? tab.color : Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.xs)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        Spacer()
        ProfessionalTabBar(selectedTab: .constant(.community))
    }
}
