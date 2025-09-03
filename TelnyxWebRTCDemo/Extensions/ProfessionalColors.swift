import SwiftUI

extension Color {
    
    // MARK: - Professional-Premium Compatibility Bridge
    // These properties now redirect to Premium design system for unified experience
    
    static let professionalPrimary = Color.premiumColors.primary           // Unified primary blue
    static let professionalSuccess = Color.premiumColors.successStart      // Premium success green
    static let professionalAlert = Color.premiumColors.statusDisconnected  // Premium alert red  
    static let professionalWarning = Color.premiumColors.statusWarning     // Premium warning amber
    
    // MARK: - Background Colors (Premium Bridge)
    
    static let professionalBackground = Color.premiumColors.backgroundPrimary   // Premium background
    static let professionalSurface = Color.premiumColors.backgroundTertiary     // Premium surface
    
    // MARK: - Text Colors (Premium Bridge)
    
    static let professionalTextPrimary = Color.premiumColors.textPrimary        // Premium text primary
    static let professionalTextSecondary = Color.premiumColors.textSecondary    // Premium text secondary
    
    // MARK: - Border and Divider Colors (Premium Bridge)
    
    static let professionalBorder = Color.premiumColors.borderLight             // Premium border
    
    // MARK: - Button Styles (Premium Bridge)
    
    static let professionalButtonBackground = Color.premiumColors.surfaceElevated.opacity(0.9)
    static let professionalButtonShadow = Color.black.opacity(0.08)
}

// MARK: - ProfessionalColors Struct Bridge
// Bridge struct for compatibility with ProfessionalColors.property syntax
struct ProfessionalColors {
    // Primary Colors (Premium Bridge)
    static let professionalPrimary = Color.premiumColors.primary
    static let professionalSuccess = Color.premiumColors.successStart  
    static let professionalAlert = Color.premiumColors.statusDisconnected
    static let professionalWarning = Color.premiumColors.statusWarning
    
    // Background Colors (Premium Bridge)
    static let professionalBackground = Color.premiumColors.backgroundPrimary
    static let professionalSurface = Color.premiumColors.backgroundTertiary
    
    // Text Colors (Premium Bridge)
    static let professionalTextPrimary = Color.premiumColors.textPrimary
    static let professionalTextSecondary = Color.premiumColors.textSecondary
    
    // Border Colors (Premium Bridge)
    static let professionalBorder = Color.premiumColors.borderLight
}

// MARK: - Professional Button Styles

struct ProfessionalButtonStyle: ButtonStyle {
    let backgroundColor: Color
    let foregroundColor: Color
    let size: CGFloat
    
    init(
        backgroundColor: Color = .professionalSurface,
        foregroundColor: Color = .professionalTextPrimary,
        size: CGFloat = 60
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.size = size
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(foregroundColor)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(backgroundColor)
                    .shadow(
                        color: .professionalButtonShadow,
                        radius: configuration.isPressed ? 1 : 4,
                        x: 0,
                        y: configuration.isPressed ? 1 : 2
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Professional Card Style

struct ProfessionalCardStyle: ViewModifier {
    let padding: CGFloat
    
    init(padding: CGFloat = 16) {
        self.padding = padding
    }
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.professionalSurface)
                    .shadow(
                        color: .professionalButtonShadow,
                        radius: 4,
                        x: 0,
                        y: 2
                    )
            )
    }
}

extension View {
    func professionalCardStyle(padding: CGFloat = 16) -> some View {
        modifier(ProfessionalCardStyle(padding: padding))
    }
}