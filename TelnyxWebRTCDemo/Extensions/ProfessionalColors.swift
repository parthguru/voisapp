import SwiftUI

extension Color {
    
    // MARK: - Professional Color System
    
    static let professionalPrimary = Color(hex: "#1A365D")        // Navy blue - headers, primary actions
    static let professionalSuccess = Color(hex: "#00C853")        // Green - call/answer buttons
    static let professionalAlert = Color(hex: "#D32F2F")          // Red - end call, critical actions
    static let professionalWarning = Color(hex: "#FF8F00")        // Amber - hold, secondary alerts
    
    // MARK: - Background Colors
    
    static let professionalBackground = Color(hex: "#FAFAFA")     // Clean light background
    static let professionalSurface = Color(hex: "#FFFFFF")       // Card/surface backgrounds
    
    // MARK: - Text Colors
    
    static let professionalTextPrimary = Color(hex: "#1D1D1D")   // Main text, high contrast
    static let professionalTextSecondary = Color(hex: "#616161") // Supporting text
    
    // MARK: - Border and Divider Colors
    
    static let professionalBorder = Color(hex: "#E0E0E0")        // Subtle dividers
    
    // MARK: - Button Styles
    
    static let professionalButtonBackground = professionalSurface.opacity(0.9)
    static let professionalButtonShadow = Color.black.opacity(0.08)
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