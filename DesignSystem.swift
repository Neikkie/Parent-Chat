//
//  DesignSystem.swift
//  Parent Chat
//
//  Professional Design System
//

import SwiftUI

// MARK: - Color Palette
extension Color {
    // Primary Brand Colors
    static let brandPrimary = Color(red: 0.3, green: 0.4, blue: 0.9) // Professional Blue
    static let brandSecondary = Color(red: 0.5, green: 0.3, blue: 0.8) // Premium Purple
    static let brandAccent = Color(red: 0.2, green: 0.7, blue: 0.9) // Vibrant Cyan
    
    // Semantic Colors
    static let success = Color(red: 0.2, green: 0.7, blue: 0.4)
    static let warning = Color(red: 1.0, green: 0.7, blue: 0.0)
    static let error = Color(red: 0.9, green: 0.3, blue: 0.3)
    static let info = Color(red: 0.3, green: 0.6, blue: 0.9)
    
    // Adaptive Neutral Palette - works in both light and dark mode
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(uiColor: .tertiaryLabel)
    
    static let surfacePrimary = Color(uiColor: .systemBackground)
    static let surfaceSecondary = Color(uiColor: .secondarySystemBackground)
    static let surfaceTertiary = Color(uiColor: .tertiarySystemBackground)
    
    // Gradients
    static let primaryGradient = LinearGradient(
        colors: [brandPrimary, brandSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let accentGradient = LinearGradient(
        colors: [brandAccent, brandPrimary],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let subtleGradient = LinearGradient(
        colors: [surfaceSecondary, surfacePrimary],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Typography
struct AppTypography {
    // Display
    static let displayLarge = Font.system(size: 57, weight: .bold, design: .rounded)
    static let displayMedium = Font.system(size: 45, weight: .bold, design: .rounded)
    static let displaySmall = Font.system(size: 36, weight: .semibold, design: .rounded)
    
    // Headings
    static let heading1 = Font.system(size: 32, weight: .bold, design: .rounded)
    static let heading2 = Font.system(size: 28, weight: .semibold, design: .rounded)
    static let heading3 = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let heading4 = Font.system(size: 20, weight: .semibold, design: .default)
    static let heading5 = Font.system(size: 18, weight: .semibold, design: .default)
    
    // Body
    static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 15, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)
    
    // Labels
    static let labelLarge = Font.system(size: 15, weight: .medium, design: .default)
    static let labelMedium = Font.system(size: 13, weight: .medium, design: .default)
    static let labelSmall = Font.system(size: 11, weight: .medium, design: .default)
    
    // Caption
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let captionEmphasis = Font.system(size: 12, weight: .semibold, design: .default)
}

// MARK: - Spacing
struct AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius
struct AppCornerRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let full: CGFloat = 999
}

// MARK: - Shadows
struct AppShadow {
    static let small = Shadow(
        color: Color.black.opacity(0.06),
        radius: 4,
        x: 0,
        y: 2
    )
    
    static let medium = Shadow(
        color: Color.black.opacity(0.08),
        radius: 8,
        x: 0,
        y: 4
    )
    
    static let large = Shadow(
        color: Color.black.opacity(0.1),
        radius: 16,
        x: 0,
        y: 8
    )
    
    static let extraLarge = Shadow(
        color: Color.black.opacity(0.12),
        radius: 24,
        x: 0,
        y: 12
    )
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

// MARK: - Professional Card Style
struct ProfessionalCardStyle: ViewModifier {
    var padding: CGFloat = AppSpacing.md
    var cornerRadius: CGFloat = AppCornerRadius.lg
    var hasShadow: Bool = true
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.surfacePrimary)
            .cornerRadius(cornerRadius)
            .shadow(
                color: hasShadow ? AppShadow.medium.color : .clear,
                radius: hasShadow ? AppShadow.medium.radius : 0,
                x: AppShadow.medium.x,
                y: AppShadow.medium.y
            )
    }
}

extension View {
    func professionalCard(
        padding: CGFloat = AppSpacing.md,
        cornerRadius: CGFloat = AppCornerRadius.lg,
        hasShadow: Bool = true
    ) -> some View {
        modifier(ProfessionalCardStyle(padding: padding, cornerRadius: cornerRadius, hasShadow: hasShadow))
    }

    func glassCard(cornerRadius: CGFloat = AppCornerRadius.lg) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }

    /// Caps content to a comfortable reading width and centers it, so feeds,
    /// chats, and forms don't stretch edge-to-edge on iPad / large screens.
    func readableWidth(_ maxWidth: CGFloat = 700) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Glass Card Style
struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = AppCornerRadius.lg

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Professional Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    var isFullWidth: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.labelLarge)
            .foregroundStyle(.white)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .background(Color.primaryGradient)
            .cornerRadius(AppCornerRadius.md)
            .shadow(
                color: Color.brandPrimary.opacity(configuration.isPressed ? 0.2 : 0.4),
                radius: configuration.isPressed ? 8 : 12,
                x: 0,
                y: configuration.isPressed ? 2 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var isFullWidth: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.labelLarge)
            .foregroundStyle(Color.brandPrimary)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .background(Color.brandPrimary.opacity(0.08))
            .cornerRadius(AppCornerRadius.md)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.labelMedium)
            .foregroundStyle(Color.textSecondary)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Professional Text Field Style
struct ProfessionalTextFieldStyle: ViewModifier {
    @FocusState private var isFocused: Bool
    var icon: String?
    
    func body(content: Content) -> some View {
        HStack(spacing: AppSpacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(isFocused ? Color.brandPrimary : Color.textTertiary)
                    .font(AppTypography.bodyMedium)
            }
            
            content
                .focused($isFocused)
        }
        .padding(AppSpacing.md)
        .background(Color.surfaceSecondary)
        .cornerRadius(AppCornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.md)
                .stroke(isFocused ? Color.brandPrimary : Color.clear, lineWidth: 2)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
    }
}

// MARK: - Badge View
struct BadgeView: View {
    let text: String
    let color: Color
    let size: BadgeSize
    
    enum BadgeSize {
        case small, medium, large
        
        var font: Font {
            switch self {
            case .small: return AppTypography.labelSmall
            case .medium: return AppTypography.labelMedium
            case .large: return AppTypography.labelLarge
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            case .medium: return EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
            case .large: return EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            }
        }
    }
    
    init(_ text: String, color: Color = .brandPrimary, size: BadgeSize = .medium) {
        self.text = text
        self.color = color
        self.size = size
    }
    
    var body: some View {
        Text(text)
            .font(size.font)
            .foregroundStyle(.white)
            .padding(size.padding)
            .background(
                Capsule()
                    .fill(color)
            )
    }
}

// MARK: - Shimmer Effect for Loading States
struct ProfessionalShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            .white.opacity(0.6),
                            .clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: phase * geometry.size.width * 2 - geometry.size.width)
                    .blendMode(.overlay)
                }
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func professionalShimmer() -> some View {
        modifier(ProfessionalShimmerModifier())
    }
}

// MARK: - Empty State View
struct ProfessionalEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(Color.brandPrimary)
            }
            
            VStack(spacing: AppSpacing.sm) {
                Text(title)
                    .font(AppTypography.heading4)
                    .foregroundStyle(Color.textPrimary)
                
                Text(message)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.xl)
    }
}
