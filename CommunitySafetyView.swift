//
//  CommunitySafetyView.swift
//  Parent Chat
//

import SwiftUI

struct CommunitySafetyView: View {
    var body: some View {
        List {
            Section("What Is Not Allowed") {
                SafetyRuleRow(
                    icon: "exclamationmark.triangle.fill",
                    title: "Harassment or threats",
                    description: "Bullying, intimidation, or threats toward any person are not allowed."
                )
                SafetyRuleRow(
                    icon: "photo.fill.on.rectangle.fill",
                    title: "Photos of children",
                    description: "Do not upload photos that include children."
                )
                SafetyRuleRow(
                    icon: "eye.slash.fill",
                    title: "Sexual or explicit content",
                    description: "Nudity, sexual content, and exploitation are prohibited."
                )
                SafetyRuleRow(
                    icon: "location.slash.fill",
                    title: "Private personal information",
                    description: "Do not share addresses, phone numbers, or private identifying details."
                )
            }

            Section("How Safety Works") {
                Label("All reports are reviewed within 24 hours.", systemImage: "clock.fill")
                Label("Posts violating guidelines are removed immediately.", systemImage: "trash.fill")
                Label("Photos with people require you to confirm no children are pictured; uploads are logged for review.", systemImage: "person.crop.rectangle.fill")
                Label("Photos with sensitive content are rejected automatically.", systemImage: "eye.slash.fill")
                Label("Blocked users cannot interact with you.", systemImage: "person.fill.xmark")
                Label("Serious or repeated violations result in account removal.", systemImage: "hand.raised.fill")
            }

            Section("Need Help?") {
                Link(destination: URL(string: "mailto:support.chaniiapps@gmail.com?subject=Parent%20Chat%20Safety%20Issue")!) {
                    Label("Contact Safety Team", systemImage: "envelope.fill")
                }
            }
        }
        .navigationTitle("Community Safety")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SafetyRuleRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
