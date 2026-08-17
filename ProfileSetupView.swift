//
//  ProfileSetupView.swift
//  Parent Chat
//
//  First-time user onboarding flow
//

import SwiftUI
import PhotosUI
import FirebaseAuth

struct ProfileSetupView: View {
    @Environment(AuthenticationManager.self) var authManager

    @State private var currentStep = 0
    @State private var username = ""
    @State private var bio = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var selectedProfileCharacter = "😀"
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var isUsernameValid: Bool {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 3 && trimmed.count <= 20
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.brandPrimary.opacity(0.06), Color.surfacePrimary],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots (hidden on welcome step)
                if currentStep > 0 {
                    OnboardingProgressBar(current: currentStep, total: 2)
                        .padding(.horizontal, 32)
                        .padding(.top, 56)
                        .padding(.bottom, 8)
                }

                // Step content
                ZStack {
                    if currentStep == 0 {
                        WelcomeStep(onContinue: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                currentStep = 1
                            }
                        })
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    } else if currentStep == 1 {
                        PhotoStep(
                            profileImage: $profileImage,
                            selectedImage: $selectedImage,
                            selectedProfileCharacter: $selectedProfileCharacter,
                            onContinue: {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    currentStep = 2
                                }
                            },
                            onBack: {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    currentStep = 0
                                }
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    } else {
                        DetailsStep(
                            username: $username,
                            bio: $bio,
                            isUsernameValid: isUsernameValid,
                            isLoading: isLoading,
                            onComplete: { Task { await completeProfile() } },
                            onBack: {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    currentStep = 1
                                }
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
            }
        }
        .alert("Something went wrong", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .onChange(of: selectedImage) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    profileImage = image
                }
            }
        }
    }

    private func completeProfile() async {
        isLoading = true
        do {
            guard let userId = authManager.currentUser?.uid else {
                throw ProfileError.noUser
            }

            var profileImageUrl: String? = nil
            if let image = profileImage {
                profileImageUrl = try? await StorageManager.shared.uploadProfileImage(image, userId: userId)
            }

            try await FirestoreManager.shared.updateUserProfile(
                userId: userId,
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                bio: bio.isEmpty ? nil : bio.trimmingCharacters(in: .whitespacesAndNewlines),
                profileImageUrl: profileImageUrl,
                profileCharacter: selectedProfileCharacter
            )

            try await authManager.refreshCurrentUser()
            HapticManager.shared.notification(.success)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            HapticManager.shared.notification(.error)
        }
        isLoading = false
    }
}

// MARK: - Progress Bar

struct OnboardingProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...total, id: \.self) { step in
                Capsule()
                    .fill(step <= current ? Color.brandPrimary : Color.surfaceSecondary)
                    .frame(height: 4)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: current)
            }
        }
    }
}

// MARK: - Step 1: Welcome

struct WelcomeStep: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.primaryGradient)
                    .frame(width: 110, height: 110)
                    .shadow(color: Color.brandPrimary.opacity(0.35), radius: 24, x: 0, y: 12)

                Image(systemName: "person.2.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 32)

            // Headline
            VStack(spacing: 14) {
                Text("Welcome to\nParentChat")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text("Connect with parents nearby,\ndiscover kid-friendly activities,\nand build your village.")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()
            Spacer()

            // Feature highlights
            VStack(spacing: 14) {
                OnboardingFeatureRow(icon: "bubble.left.and.bubble.right.fill", color: Color.brandPrimary,
                                    text: "Share updates with local parents")
                OnboardingFeatureRow(icon: "sparkles", color: Color.brandAccent,
                                    text: "Discover activities for every age")
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)

            Button(action: onContinue) {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(isFullWidth: true))
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}

struct OnboardingFeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(color)
            }
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Color.textSecondary)
            Spacer()
        }
    }
}

// MARK: - Step 2: Profile Photo

struct PhotoStep: View {
    @Binding var profileImage: UIImage?
    @Binding var selectedImage: PhotosPickerItem?
    @Binding var selectedProfileCharacter: String
    let onContinue: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.brandPrimary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            VStack(spacing: 12) {
                Text("Add a Profile Photo")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)

                Text("Help other parents recognise you.\nYou can always update this later.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.bottom, 40)

            // Photo picker
            PhotosPicker(selection: $selectedImage, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    if let profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 140, height: 140)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.brandPrimary, lineWidth: 3))
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.primaryGradient)
                                .frame(width: 140, height: 140)
                            Text(selectedProfileCharacter)
                                .font(.system(size: 62))
                        }
                    }

                    ZStack {
                        Circle()
                            .fill(Color.brandPrimary)
                            .frame(width: 44, height: 44)
                            .shadow(color: AppShadow.medium.color, radius: AppShadow.medium.radius,
                                    x: AppShadow.medium.x, y: AppShadow.medium.y)
                        Image(systemName: profileImage == nil ? "camera.fill" : "arrow.triangle.2.circlepath")
                            .foregroundStyle(.white)
                            .font(.system(size: 18))
                    }
                    .offset(x: 4, y: 4)
                }
            }
            .buttonStyle(.plain)

            Text(profileImage == nil ? "Tap to add a photo" : "Tap to change photo")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.brandPrimary)
                .padding(.top, 16)
            
            VStack(spacing: 10) {
                Text("Or pick a character")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                
                AvatarCharacterPicker(selectedCharacter: $selectedProfileCharacter)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 20)

            Spacer()
            Spacer()

            if profileImage == nil {
                Button("Skip for Now", action: onContinue)
                    .buttonStyle(SecondaryButtonStyle(isFullWidth: true))
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
            } else {
                Button("Continue", action: onContinue)
                    .buttonStyle(PrimaryButtonStyle(isFullWidth: true))
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
            }
        }
    }
}

// MARK: - Step 3: Username & Bio

struct DetailsStep: View {
    @Binding var username: String
    @Binding var bio: String
    let isUsernameValid: Bool
    let isLoading: Bool
    let onComplete: () -> Void
    let onBack: () -> Void
    @FocusState private var focusedField: Field?

    enum Field { case username, bio }

    var body: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.brandPrimary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    VStack(spacing: 10) {
                        Text("Almost There!")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textPrimary)

                        Text("Choose a username so parents\ncan find and connect with you.")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .padding(.top, 8)

                    // Username
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Username")
                            .font(AppTypography.labelLarge)
                            .foregroundStyle(Color.textPrimary)

                        TextField("e.g. jane_parent", text: $username)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(AppTypography.bodyLarge)
                            .padding(AppSpacing.md)
                            .background(Color.surfaceSecondary)
                            .cornerRadius(AppCornerRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCornerRadius.md)
                                    .stroke(
                                        username.isEmpty ? Color.clear :
                                        isUsernameValid ? Color.success : Color.error,
                                        lineWidth: 1.5
                                    )
                            )
                            .focused($focusedField, equals: .username)

                        HStack {
                            Text("\(username.count)/20")
                                .font(AppTypography.caption)
                                .foregroundStyle(Color.textTertiary)
                            Spacer()
                            if !username.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: isUsernameValid
                                          ? "checkmark.circle.fill"
                                          : "exclamationmark.circle.fill")
                                        .foregroundStyle(isUsernameValid ? Color.success : Color.error)
                                    Text(isUsernameValid ? "Looks good!" : "3–20 characters required")
                                        .font(AppTypography.labelSmall)
                                        .foregroundStyle(isUsernameValid ? Color.success : Color.error)
                                }
                            }
                        }
                    }

                    // Bio
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack {
                            Text("Bio")
                                .font(AppTypography.labelLarge)
                                .foregroundStyle(Color.textPrimary)
                            Text("Optional")
                                .font(AppTypography.caption)
                                .foregroundStyle(Color.textTertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.surfaceSecondary)
                                .cornerRadius(6)
                        }

                        TextField("Tell other parents a bit about yourself...", text: $bio, axis: .vertical)
                            .font(AppTypography.bodyLarge)
                            .lineLimit(3...6)
                            .padding(AppSpacing.md)
                            .background(Color.surfaceSecondary)
                            .cornerRadius(AppCornerRadius.md)
                            .focused($focusedField, equals: .bio)

                        Text("\(bio.count)/150")
                            .font(AppTypography.caption)
                            .foregroundStyle(Color.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    Button {
                        focusedField = nil
                        onComplete()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Complete Profile")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(isFullWidth: true))
                    .disabled(!isUsernameValid || isLoading)
                    .opacity(isUsernameValid && !isLoading ? 1.0 : 0.6)

                    Color.clear.frame(height: 32)
                }
                .padding(.horizontal, 28)
            }
        }
    }
}

enum ProfileError: LocalizedError {
    case noUser
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .noUser:    return "No user found. Please sign in again."
        case .uploadFailed: return "Failed to upload profile image."
        }
    }
}

#Preview {
    ProfileSetupView()
        .environment(AuthenticationManager())
}
