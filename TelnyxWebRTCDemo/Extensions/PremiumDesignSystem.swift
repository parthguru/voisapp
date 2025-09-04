//
//  PremiumDesignSystem.swift
//  TelnyxWebRTCDemo
//
//  Created by AI SWE Agent on 02/09/2025.
//  Copyright © 2025 Telnyx LLC. All rights reserved.
//

import SwiftUI
import UIKit

// MARK: - Premium Color System
extension Color {
    static let premiumColors = PremiumColors()
    
    struct PremiumColors {
        // Primary Colors
        let primary = Color(hex: "#1A365D")        // Navy blue - consistent with professional theme
        let primaryLight = Color(hex: "#3B82F6")    
        let primaryDark = Color(hex: "#1D4ED8")
        
        // Action Colors
        let success = Color(hex: "#00C853")         // Green - call/answer buttons
        let alert = Color(hex: "#D32F2F")           // Red - end call, critical actions
        let warning = Color(hex: "#FF8F00")         // Amber - hold, secondary alerts
        
        // Background System - CONSISTENT ACROSS ALL SCREENS
        let background = Color(.systemBackground)   // Clean system background
        let backgroundSecondary = Color(.secondarySystemBackground)
        let backgroundTertiary = Color(.tertiarySystemBackground)
        
        // Surface Colors
        let surface = Color(.systemBackground)      // Card/surface backgrounds
        let surfaceElevated = Color.white.opacity(0.9)
        let surfaceGlass = Color.white.opacity(0.85)
        let surfacePressed = Color.gray.opacity(0.05)
        
        // Text Colors
        let textPrimary = Color(hex: "#1D1D1D")     // Main text, high contrast
        let textSecondary = Color(hex: "#616161")   // Supporting text
        let textTertiary = Color(hex: "#9CA3AF")
        
        // Border Colors
        let border = Color(hex: "#E0E0E0")          // Subtle dividers
        let borderLight = Color(hex: "#E5E7EB").opacity(0.5)
        let borderActive = Color(hex: "#D1D5DB").opacity(0.7)
        
        // Button Colors
        let keypadButton = Color(hex: "#F8F9FA")    // Light keypad button background
        
        // Status Colors
        let statusDisconnected = Color(hex: "#EF4444")
        let statusConnected = Color(hex: "#10B981")
        let statusWarning = Color(hex: "#F59E0B")
    }
}

// MARK: - Color Hex Initializer (Uses existing implementation from Color+Extensions.swift)

// MARK: - Premium Typography System
extension Font {
    static let premiumFonts = PremiumFonts()
    
    struct PremiumFonts {
        // Display Typography
        let displayLarge = Font.system(size: 36, weight: .ultraLight, design: .default)
        let displayMedium = Font.system(size: 28, weight: .thin, design: .default)
        let displaySmall = Font.system(size: 24, weight: .light, design: .default)
        
        // Body Typography
        let bodyLarge = Font.system(size: 16, weight: .regular, design: .default)
        let bodyMedium = Font.system(size: 14, weight: .medium, design: .default)
        let bodySmall = Font.system(size: 12, weight: .medium, design: .default)
        
        // Keypad Typography
        let keypadNumber = Font.system(size: 28, weight: .light, design: .default)
        let keypadLetters = Font.system(size: 10, weight: .medium, design: .default)
        
        // Phone Number Display
        let phoneNumberDisplay = Font.system(size: 32, weight: .ultraLight, design: .default)
        let phoneNumberPlaceholder = Font.system(size: 32, weight: .ultraLight, design: .default)
    }
}

// MARK: - Premium Shadows and Effects
extension View {
    func premiumGlassShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.08), radius: 25, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 3)
    }
    
    func premiumButtonShadow(isPressed: Bool = false) -> some View {
        self.shadow(
            color: Color.black.opacity(isPressed ? 0.1 : 0.08),
            radius: isPressed ? 4 : 25,
            x: 0,
            y: isPressed ? 2 : 8
        )
        .shadow(
            color: Color.black.opacity(isPressed ? 0.05 : 0.05),
            radius: isPressed ? 2 : 10,
            x: 0,
            y: isPressed ? 1 : 3
        )
    }
    
    func premiumCallButtonShadow(color: Color) -> some View {
        self.shadow(color: color.opacity(0.25), radius: 8, x: 0, y: 4)
            .shadow(color: color.opacity(0.15), radius: 16, x: 0, y: 8)
    }
}

// MARK: - Haptic Feedback System
class PremiumHaptics {
    static let shared = PremiumHaptics()
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()
    
    private init() {
        // Pre-prepare generators
        impactLight.prepare()
        impactMedium.prepare()
        selection.prepare()
    }
    
    func keypadTap() {
        impactLight.impactOccurred(intensity: 0.7)
    }
    
    func buttonPress() {
        impactMedium.impactOccurred(intensity: 0.8)
    }
    
    func callStart() {
        impactHeavy.impactOccurred(intensity: 1.0)
    }
    
    func tabSelection() {
        selection.selectionChanged()
    }
    
    func success() {
        notification.notificationOccurred(.success)
    }
    
    func error() {
        notification.notificationOccurred(.error)
    }
}

// MARK: - Animation Presets
extension Animation {
    static let premiumSpring = Animation.interpolatingSpring(
        mass: 1.0,
        stiffness: 120,
        damping: 12,
        initialVelocity: 0
    )
    
    static let premiumEase = Animation.easeInOut(duration: 0.3)
    static let premiumQuick = Animation.easeOut(duration: 0.2)
    static let premiumSlow = Animation.easeInOut(duration: 0.5)
}

// MARK: - Premium View Modifiers
struct GlassmorphismModifier: ViewModifier {
    let cornerRadius: CGFloat
    let opacity: Double
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.premiumColors.surfaceGlass)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.premiumColors.borderLight, lineWidth: 0.5)
                    )
            )
    }
}

struct PressableButtonModifier: ViewModifier {
    @State private var isPressed = false
    let onPress: () -> Void
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.premiumQuick, value: isPressed)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                if pressing {
                    isPressed = true
                    PremiumHaptics.shared.keypadTap()
                    onPress()
                } else {
                    isPressed = false
                }
            }, perform: {})
    }
}

extension View {
    func glassmorphism(cornerRadius: CGFloat = 12, opacity: Double = 0.9) -> some View {
        modifier(GlassmorphismModifier(cornerRadius: cornerRadius, opacity: opacity))
    }
    
    func pressableButton(onPress: @escaping () -> Void) -> some View {
        modifier(PressableButtonModifier(onPress: onPress))
    }
}

// MARK: - Phone Number Formatting
struct PhoneNumberFormatter {
    static func format(_ number: String) -> String {
        let cleanNumber = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Handle different lengths
        switch cleanNumber.count {
        case 0:
            return ""
        case 1...3:
            return cleanNumber
        case 4...6:
            let area = String(cleanNumber.prefix(3))
            let exchange = String(cleanNumber.dropFirst(3))
            return "\(area) \(exchange)"
        case 7...10:
            let area = String(cleanNumber.prefix(3))
            let exchange = String(cleanNumber.dropFirst(3).prefix(3))
            let number = String(cleanNumber.dropFirst(6))
            return "\(area) \(exchange) \(number)"
        default:
            // Handle longer numbers (international)
            let area = String(cleanNumber.prefix(3))
            let exchange = String(cleanNumber.dropFirst(3).prefix(3))
            let number = String(cleanNumber.dropFirst(6).prefix(4))
            let remaining = String(cleanNumber.dropFirst(10))
            return remaining.isEmpty ? "\(area) \(exchange) \(number)" : "\(area) \(exchange) \(number) \(remaining)"
        }
    }
    
    static func isValidPhoneNumber(_ number: String) -> Bool {
        let cleanNumber = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return cleanNumber.count >= 10 && cleanNumber.count <= 15
    }
}

// MARK: - Premium Spacing System
struct PremiumSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

// MARK: - Premium Button Styles
struct PremiumPrimaryButtonStyle: ButtonStyle {
    let isDisabled: Bool
    
    init(isDisabled: Bool = false) {
        self.isDisabled = isDisabled
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.premiumFonts.bodyLarge)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(isDisabled ? Color.gray.opacity(0.5) : Color.premiumColors.primary)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.premiumQuick, value: configuration.isPressed)
    }
}

struct PremiumSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.premiumFonts.bodyLarge)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(Color.premiumColors.primary)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.premiumColors.primary, lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.clear)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.premiumQuick, value: configuration.isPressed)
    }
}

// MARK: - Premium Card Style
struct PremiumCardStyle: ViewModifier {
    let padding: CGFloat
    
    init(padding: CGFloat = PremiumSpacing.md) {
        self.padding = padding
    }
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.premiumColors.surface)
                    .shadow(
                        color: Color.black.opacity(0.08),
                        radius: 4,
                        x: 0,
                        y: 2
                    )
            )
    }
}

// MARK: - Premium Screen Container
struct PremiumScreenContainer<Content: View>: View {
    let content: Content
    let topPadding: CGFloat
    
    init(topPadding: CGFloat = PremiumSpacing.xxl, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.topPadding = topPadding
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: topPadding)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.premiumColors.background)
    }
}

// MARK: - Extended View Modifiers
extension View {
    func premiumCardStyle(padding: CGFloat = PremiumSpacing.md) -> some View {
        modifier(PremiumCardStyle(padding: padding))
    }
    
    func premiumScreenContainer(topPadding: CGFloat = PremiumSpacing.xxl) -> some View {
        PremiumScreenContainer(topPadding: topPadding) {
            self
        }
    }
    
    func premiumPrimaryButtonStyle(isDisabled: Bool = false) -> some View {
        self.buttonStyle(PremiumPrimaryButtonStyle(isDisabled: isDisabled))
    }
    
    func premiumSecondaryButtonStyle() -> some View {
        self.buttonStyle(PremiumSecondaryButtonStyle())
    }
}

// MARK: - Legacy Color Support (for existing code compatibility)
extension Color {
    static let professionalPrimary = Color.premiumColors.primary
    static let professionalSuccess = Color.premiumColors.success
    static let professionalAlert = Color.premiumColors.alert
    static let professionalWarning = Color.premiumColors.warning
    static let professionalBackground = Color.premiumColors.background
    static let professionalSurface = Color.premiumColors.surface
    static let professionalTextPrimary = Color.premiumColors.textPrimary
    static let professionalTextSecondary = Color.premiumColors.textSecondary
    static let professionalBorder = Color.premiumColors.border
    static let professionalButtonBackground = Color.premiumColors.surface.opacity(0.9)
    static let professionalButtonShadow = Color.black.opacity(0.08)
}