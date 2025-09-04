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
        let primary = Color(hex: "#3B82F6")
        let primaryLight = Color(hex: "#60A5FA")
        let primaryDark = Color(hex: "#1D4ED8")
        
        // Success Gradient
        let successStart = Color(hex: "#10B981")
        let successMiddle = Color(hex: "#059669")
        let successEnd = Color(hex: "#047857")
        
        // Background System
        let backgroundPrimary = Color(hex: "#FAFAFA")
        let backgroundSecondary = Color(hex: "#F5F5F5")
        let backgroundTertiary = Color(hex: "#FFFFFF")
        
        // Surface Colors
        let surfaceElevated = Color.white.opacity(0.9)
        let surfaceGlass = Color.white.opacity(0.85)
        let surfacePressed = Color.gray.opacity(0.05)
        
        // Text Colors
        let textPrimary = Color(hex: "#111827")
        let textSecondary = Color(hex: "#6B7280")
        let textTertiary = Color(hex: "#9CA3AF")
        
        // Border Colors
        let borderLight = Color(hex: "#E5E7EB").opacity(0.5)
        let borderActive = Color(hex: "#D1D5DB").opacity(0.7)
        
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