//
//  CustomTabBar.swift
//  Parent Chat
//
//  Created by Shanique Beckford on 4/11/26.
//

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    let tabs: [(icon: String, label: String, gradient: [Color])] = [
        ("house.fill", "Home", [.blue, .cyan]),
        ("map.fill", "Map", [.green, .mint]),
        ("sparkles.square.filled.on.square", "Discover", [.purple, .pink])
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button {
                    HapticManager.shared.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tabs[index].icon)
                            .font(.system(size: 22))
                            .foregroundStyle(
                                selectedTab == index ?
                                LinearGradient(
                                    colors: tabs[index].gradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.textSecondary, Color.textSecondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .symbolEffect(.bounce, value: selectedTab == index)
                            .scaleEffect(selectedTab == index ? 1.1 : 1.0)
                        
                        if selectedTab == index {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: tabs[index].gradient,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 4, height: 4)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == index ?
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                            .matchedGeometryEffect(id: "TAB", in: namespace)
                        : nil
                    )
                }
                .buttonStyle(.scale)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 20)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    @Namespace private var namespace
}
