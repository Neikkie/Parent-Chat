//
//  ContentView.swift
//  Parent Chat
//
//  Professional Main View
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthenticationManager.self) var authManager
    @State private var selectedTab: ProfessionalTabBar.Tab = .community
    @State private var isTabBarVisible = true

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            ZStack {
                switch selectedTab {
                case .community:
                    CommunityView()
                        .environment(authManager)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))

                case .activities:
                    ActivitiesView()
                        .environment(authManager)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))

                case .map:
                    MapView(isTabBarVisible: $isTabBarVisible)
                        .environment(authManager)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))

                case .profile:
                    NavigationStack {
                        ProfileView()
                            .environment(authManager)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedTab)

            // Professional Tab Bar
            if isTabBarVisible {
                ProfessionalTabBar(selectedTab: $selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: selectedTab) { _, _ in
            withAnimation {
                isTabBarVisible = true
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthenticationManager())
}
