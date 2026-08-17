//
//  SignInView.swift
//  Parent Chat
//
//  Created by Shanique Beckford on 4/6/26.
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.colorScheme) var colorScheme
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.3),
                    Color.purple.opacity(0.3),
                    Color.pink.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 50) {
                Spacer()
                
                // App Logo/Title with animation
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                        
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .foregroundStyle(.white)
                    }
                    .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)
                    
                    Text("Parent Chat")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Connect, Share, and Discover")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    Text("Join a community of parents")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 20)
                
                Spacer()
                
                // Features
                VStack(spacing: 16) {
                    FeatureRow(icon: "house.fill", title: "Community Feed", color: .blue)
                    FeatureRow(icon: "sparkles.square.filled.on.square", title: "Discover Activities", color: .purple)
                }
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 20)
                
                Spacer()
                
                // Sign in with Apple button
                VStack(spacing: 12) {
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            authManager.prepareSignInRequest(request: request)
                        },
                        onCompletion: { result in
                            authManager.handleSignInWithApple(result: result)
                        }
                    )
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 56)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    Text("Secure sign in with Apple ID")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 32)
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 20)
                
                Spacer()
                    .frame(height: 40)
            }
            .padding()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimating = true
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            Text(title)
                .font(.body)
                .fontWeight(.medium)
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    // Create a mock auth manager for preview
    @Previewable @State var mockAuthManager = AuthenticationManager()
    
    SignInView()
        .environment(mockAuthManager)
        .onAppear {
            // Prevent Firebase calls in preview
            mockAuthManager.isAuthenticated = false
        }
}
