//
//  AppearanceManager.swift
//  Parent Chat
//
//  Manages app appearance mode (light, dark, automatic)
//

import SwiftUI

enum AppearanceMode: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case automatic = "Automatic"
    
    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .automatic: return "circle.lefthalf.filled"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .automatic: return nil
        }
    }
}

@Observable
class AppearanceManager {
    var selectedMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(selectedMode.rawValue, forKey: "appearanceMode")
        }
    }
    
    init() {
        if let savedMode = UserDefaults.standard.string(forKey: "appearanceMode"),
           let mode = AppearanceMode(rawValue: savedMode) {
            self.selectedMode = mode
        } else {
            self.selectedMode = .automatic
        }
    }
}
