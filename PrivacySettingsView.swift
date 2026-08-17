//
//  PrivacySettingsView.swift
//  Parent Chat
//

import SwiftUI

struct PrivacySettingsView: View {
    @AppStorage("privacy_show_location") private var showLocationOnPosts = true
    @AppStorage("privacy_public_profile") private var publicProfile = true
    @AppStorage("privacy_show_in_search") private var showInSearch = true
    @AppStorage("privacy_allow_messages") private var allowMessages = true

    var body: some View {
        List {
            Section {
                Toggle(isOn: $publicProfile) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Public Profile", systemImage: "person.fill")
                        Text("Anyone can view your profile and posts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle(isOn: $showInSearch) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Appear in Search", systemImage: "magnifyingglass")
                        Text("Let other parents find your profile")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Profile Visibility")
            }

            Section {
                Toggle(isOn: $showLocationOnPosts) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Location on Posts", systemImage: "location.fill")
                        Text("Show location tag when you add one to a post")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Location")
            } footer: {
                Text("Your precise location is never stored. Only place names you explicitly choose are saved.")
            }

            Section {
                Toggle(isOn: $allowMessages) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Allow Messages", systemImage: "message.fill")
                        Text("Let other members send you messages")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Messaging")
            }

            Section {
                NavigationLink {
                    DataAndPrivacyView()
                } label: {
                    Label("Data & Privacy", systemImage: "hand.raised.fill")
                }
            } header: {
                Text("Your Data")
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataAndPrivacyView: View {
    private let privacyPolicyURL = URL(string: "https://parentchat.app/privacy")!
    private let termsOfServiceURL = URL(string: "https://parentchat.app/terms")!
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("What We Collect")
                        .font(.headline)
                    Text("Parent Chat collects only what's needed to provide the service: your Apple ID email, display name, profile photo (if you add one), posts and comments you create, and approximate location only when you tag a post.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("How We Use It")
                        .font(.headline)
                    Text("Your data is used solely to operate Parent Chat — to show your posts, connect you with other parents, and personalise your experience. We do not sell your data or use it for advertising.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section {
                Link(destination: privacyPolicyURL) {
                    Label("Privacy Policy", systemImage: "doc.text.fill")
                }
                Link(destination: termsOfServiceURL) {
                    Label("Terms of Service", systemImage: "doc.plaintext.fill")
                }
            } header: {
                Text("Legal")
            } footer: {
                Text("Replace these links with your final legal pages before App Store submission.")
            }
        }
        .navigationTitle("Data & Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PrivacySettingsView()
    }
}
