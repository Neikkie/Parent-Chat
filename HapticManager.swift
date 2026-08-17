//
//  HapticManager.swift
//  Parent Chat
//
//  Created by Shanique Beckford on 4/11/26.
//

import SwiftUI

class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

// Convenience methods
extension HapticManager {
    func light() { impact(.light) }
    func medium() { impact(.medium) }
    func heavy() { impact(.heavy) }
    func soft() { impact(.soft) }
    func rigid() { impact(.rigid) }
    
    func success() { notification(.success) }
    func warning() { notification(.warning) }
    func error() { notification(.error) }
}
