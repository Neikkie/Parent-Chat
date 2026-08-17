//
//  SavedPostsView.swift
//  Parent Chat
//
//  Created by Shanique Beckford on 4/11/26.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SavedPostsView: View {
    @State private var savedPosts: [Post] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var savedPostsListener: ListenerRegistration?
    @State private var pendingDeleteIds: Set<String> = []
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView("Loading saved posts...")
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if savedPosts.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        
                        Text("No saved posts")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Posts you save will appear here")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(savedPosts) { post in
                                PostRowView(post: post, removeOnUnsave: true) {
                                    if let id = post.id {
                                        pendingDeleteIds.insert(id)
                                    }
                                    withAnimation {
                                        savedPosts.removeAll { $0.id == post.id }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Saved Posts")
            .navigationBarTitleDisplayMode(.large)
            .task {
                startSavedPostsListener()
            }
            .onDisappear {
                savedPostsListener?.remove()
                savedPostsListener = nil
            }
        }
    }

    private func startSavedPostsListener() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        savedPostsListener?.remove()
        isLoading = true
        errorMessage = nil

        savedPostsListener = FirestoreManager.shared.listenToSavedPosts(userId: userId) { updated in
            DispatchQueue.main.async {
                savedPosts = updated.filter { post in
                    guard let id = post.id else { return true }
                    return !pendingDeleteIds.contains(id)
                }
                isLoading = false
            }
        } onError: { error in
            DispatchQueue.main.async {
                errorMessage = "Failed to load saved posts: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

#Preview {
    SavedPostsView()
}
