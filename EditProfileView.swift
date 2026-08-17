//
//  EditProfileView.swift
//  Parent Chat
//
//  Professional Edit Profile View
//

import SwiftUI
import PhotosUI
import FirebaseAuth

struct EditProfileView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.dismiss) var dismiss
    
    @State private var username: String
    @State private var bio: String
    @State private var selectedImage: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var currentImageUrl: String?
    @State private var selectedProfileCharacter: String
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var hasChanges = false
    
    init(userProfile: UserProfile) {
        _username = State(initialValue: userProfile.username ?? "")
        _bio = State(initialValue: userProfile.bio ?? "")
        _currentImageUrl = State(initialValue: userProfile.profileImageUrl)
        _selectedProfileCharacter = State(initialValue: userProfile.profileCharacter ?? "😀")
    }
    
    private var isValid: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        username.count >= 3 &&
        username.count <= 20
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Profile Image
                    VStack(spacing: AppSpacing.md) {
                        ZStack(alignment: .bottomTrailing) {
                            ZStack {
                                if let profileImage = profileImage {
                                    Image(uiImage: profileImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                } else if let urlString = currentImageUrl,
                                          let url = URL.httpsOnly(urlString) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 120)
                                            .clipShape(Circle())
                                    } placeholder: {
                                        Circle()
                                            .fill(Color.primaryGradient)
                                            .frame(width: 120, height: 120)
                                            .overlay(
                                                ProgressView()
                                                    .tint(.white)
                                            )
                                    }
                                } else {
                                    Circle()
                                        .fill(Color.primaryGradient)
                                        .frame(width: 120, height: 120)
                                        .overlay(
                                            Text(selectedProfileCharacter)
                                                .font(.system(size: 52))
                                        )
                                }
                            }
                            .overlay(
                                Circle()
                                    .stroke(Color.brandPrimary, lineWidth: 3)
                                    .frame(width: 120, height: 120)
                            )
                            
                            PhotosPicker(selection: $selectedImage, matching: .images) {
                                ZStack {
                                    Circle()
                                        .fill(Color.brandPrimary)
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: "camera.fill")
                                        .foregroundStyle(.white)
                                        .font(.system(size: 16))
                                }
                                .shadow(
                                    color: AppShadow.medium.color,
                                    radius: AppShadow.medium.radius,
                                    x: AppShadow.medium.x,
                                    y: AppShadow.medium.y
                                )
                            }
                        }
                    }
                    .padding(.top, AppSpacing.lg)
                    
                    // Form
                    VStack(spacing: AppSpacing.lg) {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Profile Character")
                                .font(AppTypography.labelLarge)
                                .foregroundStyle(Color.textPrimary)
                            
                            AvatarCharacterPicker(selectedCharacter: $selectedProfileCharacter)
                                .onChange(of: selectedProfileCharacter) { _, _ in hasChanges = true }
                        }
                        
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Username")
                                .font(AppTypography.labelLarge)
                                .foregroundStyle(Color.textPrimary)
                            
                            TextField("Enter your username", text: $username)
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
                                            isValid ? Color.success : Color.error,
                                            lineWidth: 1
                                        )
                                )
                                .onChange(of: username) { _, _ in hasChanges = true }
                            
                            HStack {
                                Text("\(username.count)/20")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(Color.textTertiary)
                                
                                Spacer()
                                
                                if !username.isEmpty {
                                    HStack(spacing: AppSpacing.xs) {
                                        Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                            .foregroundStyle(isValid ? Color.success : Color.error)
                                        
                                        Text(isValid ? "Valid username" : "3-20 characters required")
                                            .font(AppTypography.labelSmall)
                                            .foregroundStyle(isValid ? Color.success : Color.error)
                                    }
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Bio")
                                .font(AppTypography.labelLarge)
                                .foregroundStyle(Color.textPrimary)
                            
                            TextField("Tell us about yourself", text: $bio, axis: .vertical)
                                .font(AppTypography.bodyLarge)
                                .lineLimit(3...6)
                                .padding(AppSpacing.md)
                                .background(Color.surfaceSecondary)
                                .cornerRadius(AppCornerRadius.md)
                                .onChange(of: bio) { _, _ in hasChanges = true }
                            
                            Text("\(bio.count)/150")
                                .font(AppTypography.caption)
                                .foregroundStyle(Color.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, AppSpacing.xl)
                    
                    // Save Button
                    Button {
                        Task {
                            await saveProfile()
                        }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Save Changes")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(isFullWidth: true))
                    .disabled(!isValid || !hasChanges || isLoading)
                    .opacity(isValid && hasChanges && !isLoading ? 1.0 : 0.6)
                    .padding(.horizontal, AppSpacing.xl)
                }
                .padding(.bottom, AppSpacing.xxl)
            }
            .background(Color.surfaceSecondary.opacity(0.3))
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.textSecondary)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    profileImage = image
                    hasChanges = true
                }
            }
        }
    }
    
    private func saveProfile() async {
        isLoading = true
        
        do {
            guard let userId = authManager.currentUser?.uid else {
                throw ProfileError.noUser
            }
            
            // Upload new profile image if selected (skipped silently if Storage not enabled)
            var profileImageUrl: String? = currentImageUrl
            if let image = profileImage {
                profileImageUrl = (try? await StorageManager.shared.uploadProfileImage(image, userId: userId)) ?? currentImageUrl
            }
            
            // Update user profile in Firestore
            try await FirestoreManager.shared.updateUserProfile(
                userId: userId,
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                bio: bio.isEmpty ? nil : bio.trimmingCharacters(in: .whitespacesAndNewlines),
                profileImageUrl: profileImageUrl,
                profileCharacter: selectedProfileCharacter
            )
            
            // Refresh current user
            try await authManager.refreshCurrentUser()
            
            HapticManager.shared.notification(.success)
            dismiss()
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            HapticManager.shared.notification(.error)
        }
        
        isLoading = false
    }
}
