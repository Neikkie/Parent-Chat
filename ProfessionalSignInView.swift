//
//  ProfessionalSignInView.swift
//  Parent Chat
//
//  Premium Onboarding Experience
//

import SwiftUI
import AuthenticationServices

struct ProfessionalSignInView: View {
    @Environment(AuthenticationManager.self) var authManager
    @State private var currentPage = 0
    @State private var isAnimating = false
    @State private var showEmailSheet = false
    
    let onboardingPages = [
        OnboardingPage(
            icon: "figure.2.and.child.holdinghands",
            title: "Connect with Parents",
            description: "Join a vibrant community of parents sharing experiences, tips, and support",
            gradient: [Color.brandPrimary, Color.brandSecondary]
        ),
        OnboardingPage(
            icon: "map.circle.fill",
            title: "Discover Activities",
            description: "Find kid-friendly places and activities tailored to your child's age group",
            gradient: [Color.success, Color.brandAccent]
        )
    ]
    
    var body: some View {
        ZStack {
            // Dynamic gradient background
            LinearGradient(
                colors: onboardingPages[currentPage].gradient.map { $0.opacity(0.15) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8), value: currentPage)
            
            VStack(spacing: 0) {
                // Top branding
                VStack(spacing: AppSpacing.sm) {
                    Text("Parent Chat")
                        .font(AppTypography.displaySmall)
                        .foregroundStyle(Color.primaryGradient)
                    
                    Text("Your Parenting Community")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.top, AppSpacing.xxl)
                
                // Onboarding carousel
                TabView(selection: $currentPage) {
                    ForEach(onboardingPages.indices, id: \.self) { index in
                        OnboardingPageView(page: onboardingPages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentPage)
                
                // Page indicators
                HStack(spacing: AppSpacing.sm) {
                    ForEach(onboardingPages.indices, id: \.self) { index in
                        Capsule()
                            .fill(currentPage == index ? AnyShapeStyle(Color.primaryGradient) : AnyShapeStyle(Color.textTertiary.opacity(0.3)))
                            .frame(width: currentPage == index ? 32 : 8, height: 8)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentPage)
                    }
                }
                .padding(.vertical, AppSpacing.lg)
                
                // Sign in section
                VStack(spacing: AppSpacing.md) {
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            authManager.prepareSignInRequest(request: request)
                        },
                        onCompletion: { result in
                            authManager.handleSignInWithApple(result: result)
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 56)
                    .cornerRadius(AppCornerRadius.md)
                    .shadow(
                        color: AppShadow.large.color,
                        radius: AppShadow.large.radius,
                        x: AppShadow.large.x,
                        y: AppShadow.large.y
                    )
                    
                    Text("Secure sign-in with Apple ID")
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.textTertiary)

                    // Divider with "or"
                    HStack(spacing: AppSpacing.sm) {
                        Rectangle()
                            .fill(Color.textTertiary.opacity(0.3))
                            .frame(height: 1)
                        Text("or")
                            .font(AppTypography.caption)
                            .foregroundStyle(Color.textTertiary)
                        Rectangle()
                            .fill(Color.textTertiary.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.vertical, AppSpacing.xs)

                    // Email sign-in — works without an Apple ID in iOS Settings
                    Button {
                        authManager.errorMessage = nil
                        showEmailSheet = true
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "envelope.fill")
                            Text("Continue with Email")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .foregroundStyle(Color.textPrimary)
                        .background(
                            RoundedRectangle(cornerRadius: AppCornerRadius.md)
                                .stroke(Color.textTertiary.opacity(0.4), lineWidth: 1)
                        )
                    }

                    // Error message
                    if let errorMsg = authManager.errorMessage {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(Color.error)
                            Text(errorMsg)
                                .font(AppTypography.labelSmall)
                                .foregroundStyle(Color.error)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.vertical, AppSpacing.sm)
                        .padding(.horizontal, AppSpacing.md)
                        .background(Color.error.opacity(0.08))
                        .cornerRadius(AppCornerRadius.sm)
                    }

                    // Privacy notice
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(Color.success)

                        Text("Your privacy is protected")
                            .font(AppTypography.labelSmall)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.vertical, AppSpacing.sm)
                    .padding(.horizontal, AppSpacing.md)
                    .background(Color.success.opacity(0.08))
                    .cornerRadius(AppCornerRadius.sm)

                    // Terms & Privacy links
                    HStack(spacing: 4) {
                        Text("By continuing you agree to our")
                            .font(AppTypography.caption)
                            .foregroundStyle(Color.textTertiary)
                        Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            .font(AppTypography.captionEmphasis)
                            .foregroundStyle(Color.brandPrimary)
                        Text("and")
                            .font(AppTypography.caption)
                            .foregroundStyle(Color.textTertiary)
                        Link("Privacy Policy", destination: URL(string: "https://www.apple.com/legal/privacy/en-ww/")!)
                            .font(AppTypography.captionEmphasis)
                            .foregroundStyle(Color.brandPrimary)
                    }
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xxl)
            }
            .readableWidth()
        }
        .onAppear {
            isAnimating = true
        }
        .sheet(isPresented: $showEmailSheet) {
            EmailSignInSheet()
                .environment(authManager)
        }
    }
}

struct EmailSignInSheet: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.dismiss) var dismiss

    enum Mode { case signIn, signUp }

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var resetConfirmation: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    Picker("", selection: $mode) {
                        Text("Sign In").tag(Mode.signIn)
                        Text("Create Account").tag(Mode.signUp)
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, AppSpacing.md)

                    VStack(spacing: AppSpacing.md) {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: AppCornerRadius.md)
                                    .stroke(Color.textTertiary.opacity(0.4), lineWidth: 1)
                            )

                        SecureField("Password", text: $password)
                            .textContentType(mode == .signUp ? .newPassword : .password)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: AppCornerRadius.md)
                                    .stroke(Color.textTertiary.opacity(0.4), lineWidth: 1)
                            )
                    }

                    if let errorMsg = authManager.errorMessage {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(Color.error)
                            Text(errorMsg)
                                .font(AppTypography.labelSmall)
                                .foregroundStyle(Color.error)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(AppSpacing.md)
                        .background(Color.error.opacity(0.08))
                        .cornerRadius(AppCornerRadius.sm)
                    }

                    if let resetConfirmation {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.success)
                            Text(resetConfirmation)
                                .font(AppTypography.labelSmall)
                                .foregroundStyle(Color.success)
                            Spacer()
                        }
                        .padding(AppSpacing.md)
                        .background(Color.success.opacity(0.08))
                        .cornerRadius(AppCornerRadius.sm)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            if isWorking {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(mode == .signIn ? "Sign In" : "Create Account")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(.white)
                        .background(Color.primaryGradient)
                        .cornerRadius(AppCornerRadius.md)
                    }
                    .disabled(isWorking || email.isEmpty || password.isEmpty)
                    .opacity((isWorking || email.isEmpty || password.isEmpty) ? 0.6 : 1)

                    if mode == .signIn {
                        Button("Forgot password?") {
                            Task {
                                let ok = await authManager.sendPasswordReset(email: email)
                                if ok {
                                    resetConfirmation = "Password reset email sent."
                                } else {
                                    resetConfirmation = nil
                                }
                            }
                        }
                        .font(AppTypography.labelSmall)
                        .foregroundStyle(Color.brandPrimary)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }
            .navigationTitle(mode == .signIn ? "Sign In" : "Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: mode) { _, _ in
                authManager.errorMessage = nil
                resetConfirmation = nil
            }
            .onChange(of: authManager.isAuthenticated) { _, newValue in
                if newValue { dismiss() }
            }
        }
    }

    private func submit() async {
        isWorking = true
        resetConfirmation = nil
        switch mode {
        case .signIn:
            await authManager.signIn(email: email, password: password)
        case .signUp:
            await authManager.signUp(email: email, password: password)
        }
        isWorking = false
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let gradient: [Color]
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var isVisible = false
    
    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: page.gradient.map { $0.opacity(0.15) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 160)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: page.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(
                        color: page.gradient[0].opacity(0.4),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
                
                Image(systemName: page.icon)
                    .font(.system(size: 50, weight: .regular))
                    .foregroundStyle(.white)
            }
            .scaleEffect(isVisible ? 1.0 : 0.5)
            .opacity(isVisible ? 1.0 : 0)
            
            VStack(spacing: AppSpacing.md) {
                Text(page.title)
                    .font(AppTypography.heading2)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(AppTypography.bodyLarge)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, AppSpacing.lg)
            }
            .opacity(isVisible ? 1.0 : 0)
            .offset(y: isVisible ? 0 : 20)
        }
        .padding(.horizontal, AppSpacing.xl)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                isVisible = true
            }
        }
        .onDisappear {
            isVisible = false
        }
    }
}

#Preview {
    ProfessionalSignInView()
        .environment(AuthenticationManager())
}
