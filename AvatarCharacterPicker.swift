//
//  AvatarCharacterPicker.swift
//  Parent Chat
//

import SwiftUI

struct AvatarCharacterPicker: View {
    @Binding var selectedCharacter: String

    private let characters = ["😀", "😊", "🥳", "😎", "🤓", "🧑‍🦱", "👩🏽", "👨🏾", "🧕", "👩‍🦰", "👨‍🦲", "🧑🏾‍🍼"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(characters, id: \.self) { character in
                Button {
                    selectedCharacter = character
                } label: {
                    Text(character)
                        .font(.system(size: 30))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(selectedCharacter == character ? Color.brandPrimary.opacity(0.15) : Color.surfaceSecondary)
                        )
                        .overlay(
                            Circle()
                                .stroke(selectedCharacter == character ? Color.brandPrimary : Color.clear, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
