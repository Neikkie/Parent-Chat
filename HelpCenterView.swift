//
//  HelpCenterView.swift
//  Parent Chat
//

import SwiftUI

struct HelpCenterView: View {
    @State private var expandedQuestion: String?

    let sections: [(title: String, items: [(q: String, a: String)])] = [
        ("Getting Started", [
            ("How do I set up my profile?",
             "After signing in, tap your name in Settings to edit your profile. You can add a username, profile photo, and bio."),
            ("Is Parent Chat free to use?",
             "Yes, Parent Chat is completely free. There are no hidden fees or subscriptions."),
            ("Who can join Parent Chat?",
             "Parent Chat is for parents and guardians. By using the app you confirm you are 18 years or older.")
        ]),
        ("Community & Posts", [
            ("How do I create a post?",
             "Tap the + button in the Community tab to create a new post. You can add text, photos, and a location tag."),
            ("How do I delete my post?",
             "Tap the ••• menu on your post and choose 'Delete Post'. Deletion is immediate and cannot be undone."),
            ("How do I report inappropriate content?",
             "Tap the ••• menu on any post or comment and choose 'Report'. Select a reason and submit. Our team reviews all reports.")
        ]),
        ("Privacy & Safety", [
            ("Who can see my posts?",
             "Posts are visible to all Parent Chat members. You can control location visibility in Settings → Privacy."),
            ("How do I block someone?",
             "Tap ••• on a post or comment from that user and choose 'Block'. You can manage blocked users in Settings → Blocked Users."),
            ("How fast are reports reviewed?",
             "All reports are reviewed within 24 hours. Posts that violate community guidelines are removed immediately."),
            ("What happens when I upload a photo with a person?",
             "We scan every photo on your device using Apple's on-device vision technology — no image data leaves your phone. If a person is detected, you'll be asked to confirm no children (under 18) are pictured before the photo is added. Photos containing nudity or sensitive content are rejected automatically."),
            ("How do I delete my account?",
             "Go to Settings → Account → Delete Account. This permanently removes your account and all your data.")
        ]),
        ("Technical", [
            ("The app isn't loading content. What should I do?",
             "Check your internet connection. If the issue persists, close and reopen the app. If it continues, contact support."),
            ("How do I report a bug?",
             "Email us at support.chaniiapps@gmail.com with a description of the issue and your device model. We'll look into it quickly.")
        ])
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Search hint
                HStack(spacing: 10) {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(Color.brandPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Can't find your answer?")
                            .font(.subheadline).fontWeight(.semibold)
                        Text("Email support.chaniiapps@gmail.com")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.brandPrimary.opacity(0.08))
                .cornerRadius(12)
                .padding(.horizontal)
                .onTapGesture {
                    if let url = URL(string: "mailto:support.chaniiapps@gmail.com?subject=Parent%20Chat%20Help") {
                        UIApplication.shared.open(url)
                    }
                }
                
                NavigationLink {
                    CommunitySafetyView()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "shield.lefthalf.filled")
                            .foregroundStyle(Color.brandPrimary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Community Safety Standards")
                                .font(.subheadline).fontWeight(.semibold)
                            Text("View reporting rules and prohibited content")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.brandPrimary.opacity(0.08))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .buttonStyle(.plain)

                ForEach(sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(section.title)
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.bottom, 6)

                        VStack(spacing: 0) {
                            ForEach(section.items, id: \.q) { item in
                                FAQRow(
                                    question: item.q,
                                    answer: item.a,
                                    isExpanded: expandedQuestion == item.q,
                                    onTap: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            expandedQuestion = expandedQuestion == item.q ? nil : item.q
                                        }
                                        HapticManager.shared.selection()
                                    }
                                )
                                if item.q != section.items.last?.q {
                                    Divider().padding(.leading)
                                }
                            }
                        }
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Help Center")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FAQRow: View {
    let question: String
    let answer: String
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Text(question)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding()
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(answer)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

#Preview {
    NavigationStack {
        HelpCenterView()
    }
}
