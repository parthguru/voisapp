//
//  CallControlsView.swift
//  TelnyxWebRTCDemo
//
//  Created by Claude Code on 2025-09-05.
//  Copyright © 2025 Telnyx. All rights reserved.
//
//  WhatsApp-Style CallKit Enhancement - Phase 5: Native-Style Call Controls
//
//  ULTRA THINK MODE ANALYSIS:
//  This CallControlsView provides a comprehensive, modular system of native iOS-style call
//  control buttons that can be composed into different layouts for various call scenarios.
//  It implements Apple's Human Interface Guidelines with advanced customization, accessibility
//  support, and enterprise-grade configuration options.
//
//  KEY ARCHITECTURAL DECISIONS:
//  1. Component-Based Architecture: Modular, reusable controls that can be composed flexibly
//  2. State-Driven Design: Controls reflect current call state with automatic UI updates
//  3. Accessibility First: Full VoiceOver support, dynamic type, and assistive technology integration
//  4. Theme Integration: Automatic dark/light mode support with custom theming capabilities
//  5. Animation System: Smooth, natural animations that feel native to iOS
//  6. Haptic Integration: Contextual haptic feedback for different interaction types
//
//  NATIVE IOS PATTERNS:
//  - System-standard button sizing and spacing
//  - Native color palette with semantic color usage
//  - Proper touch target sizes following Apple's guidelines (44pt minimum)
//  - Visual feedback patterns consistent with iOS system apps
//  - Accessibility labels and hints following platform conventions
//

import SwiftUI
import UIKit
import Combine
import os.log

@available(iOS 14.0, *)
public struct CallControlsView: View {
    
    // MARK: - Types
    
    public enum ControlType: String, CaseIterable {
        case mute = "mic.slash.fill"
        case unmute = "mic.fill"
        case speaker = "speaker.wave.3.fill"
        case speakerOff = "speaker.fill"
        case video = "video.fill"
        case videoOff = "video.slash.fill"
        case hold = "pause.fill"
        case resume = "play.fill"
        case keypad = "circle.grid.3x3.fill"
        case addCall = "plus"
        case contacts = "person.crop.circle"
        case facetime = "video"
        case hangup = "phone.down.fill"
        case answer = "phone.fill"
        case decline = "phone.down.fill"
        case swap = "arrow.2.squarepath"
        case merge = "phone.2.fill"
        case transfer = "phone.arrow.right"
        case record = "record.circle"
        case bluetooth = "wave.3.right.circle"
        case airplay = "airplayvideo"
        case voicemail = "voicemail"
        case callBack = "phone.arrow.up.right"
        case switchCall = "phone.2"
        
        var iconName: String {
            return self.rawValue
        }
        
        var defaultColor: CallControlColor {
            switch self {
            case .hangup, .decline: return .destructive
            case .answer: return .success
            case .hold, .resume: return .warning
            case .mute, .video, .speaker: return .primary
            default: return .secondary
            }
        }
        
        var accessibilityLabel: String {
            switch self {
            case .mute: return "Mute call"
            case .unmute: return "Unmute call"
            case .speaker: return "Turn on speaker"
            case .speakerOff: return "Turn off speaker"
            case .video: return "Turn on video"
            case .videoOff: return "Turn off video"
            case .hold: return "Hold call"
            case .resume: return "Resume call"
            case .keypad: return "Show keypad"
            case .addCall: return "Add call"
            case .contacts: return "Show contacts"
            case .facetime: return "FaceTime"
            case .hangup: return "End call"
            case .answer: return "Answer call"
            case .decline: return "Decline call"
            case .swap: return "Swap calls"
            case .merge: return "Merge calls"
            case .transfer: return "Transfer call"
            case .record: return "Record call"
            case .bluetooth: return "Bluetooth audio"
            case .airplay: return "AirPlay"
            case .voicemail: return "Voicemail"
            case .callBack: return "Call back"
            case .switchCall: return "Switch call"
            }
        }
    }
    
    public enum CallControlColor {
        case primary
        case secondary
        case success
        case warning
        case destructive
        case info
        case custom(Color)
        
        func color(for colorScheme: ColorScheme) -> Color {
            switch self {
            case .primary:
                return .blue
            case .secondary:
                return colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1)
            case .success:
                return .green
            case .warning:
                return .orange
            case .destructive:
                return .red
            case .info:
                return .blue
            case .custom(let color):
                return color
            }
        }
        
        func foregroundColor(for colorScheme: ColorScheme) -> Color {
            switch self {
            case .secondary:
                return colorScheme == .dark ? .white : .black
            case .custom:
                return .white
            default:
                return .white
            }
        }
    }
    
    public enum ControlSize {
        case small
        case medium
        case large
        case extraLarge
        
        var diameter: CGFloat {
            switch self {
            case .small: return 44
            case .medium: return 56
            case .large: return 68
            case .extraLarge: return 80
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 20
            case .medium: return 24
            case .large: return 28
            case .extraLarge: return 32
            }
        }
        
        var cornerRadius: CGFloat {
            return diameter / 2
        }
    }
    
    public enum LayoutStyle {
        case horizontal
        case vertical
        case grid(columns: Int)
        case custom
    }
    
    public struct ControlConfiguration {
        let type: ControlType
        let color: CallControlColor?
        let size: ControlSize?
        let isEnabled: Bool
        let isSelected: Bool
        let badge: String?
        let action: () -> Void
        
        public init(
            type: ControlType,
            color: CallControlColor? = nil,
            size: ControlSize? = nil,
            isEnabled: Bool = true,
            isSelected: Bool = false,
            badge: String? = nil,
            action: @escaping () -> Void
        ) {
            self.type = type
            self.color = color
            self.size = size
            self.isEnabled = isEnabled
            self.isSelected = isSelected
            self.badge = badge
            self.action = action
        }
    }
    
    public struct ViewConfiguration {
        let layoutStyle: LayoutStyle
        let spacing: CGFloat
        let defaultSize: ControlSize
        let enableHaptics: Bool
        let enableAnimations: Bool
        let accessibilityGroupLabel: String?
        
        public init(
            layoutStyle: LayoutStyle = .horizontal,
            spacing: CGFloat = 20,
            defaultSize: ControlSize = .medium,
            enableHaptics: Bool = true,
            enableAnimations: Bool = true,
            accessibilityGroupLabel: String? = nil
        ) {
            self.layoutStyle = layoutStyle
            self.spacing = spacing
            self.defaultSize = defaultSize
            self.enableHaptics = enableHaptics
            self.enableAnimations = enableAnimations
            self.accessibilityGroupLabel = accessibilityGroupLabel
        }
    }
    
    // MARK: - Properties
    
    private let controls: [ControlConfiguration]
    private let configuration: ViewConfiguration
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sizeCategory) private var sizeCategory
    
    // MARK: - Initialization
    
    public init(
        controls: [ControlConfiguration],
        configuration: ViewConfiguration = ViewConfiguration()
    ) {
        self.controls = controls
        self.configuration = configuration
    }
    
    // MARK: - Body
    
    public var body: some View {
        Group {
            switch configuration.layoutStyle {
            case .horizontal:
                horizontalLayout
            case .vertical:
                verticalLayout
            case .grid(let columns):
                gridLayout(columns: columns)
            case .custom:
                customLayout
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(configuration.accessibilityGroupLabel ?? "Call controls")
    }
    
    // MARK: - Layout Views
    
    private var horizontalLayout: some View {
        HStack(spacing: adaptiveSpacing) {
            ForEach(controls.indices, id: \.self) { index in
                controlButton(for: controls[index])
            }
        }
    }
    
    private var verticalLayout: some View {
        VStack(spacing: adaptiveSpacing) {
            ForEach(controls.indices, id: \.self) { index in
                controlButton(for: controls[index])
            }
        }
    }
    
    private func gridLayout(columns: Int) -> some View {
        let gridColumns = Array(repeating: GridItem(.flexible(), spacing: adaptiveSpacing), count: columns)
        
        return LazyVGrid(columns: gridColumns, spacing: adaptiveSpacing) {
            ForEach(controls.indices, id: \.self) { index in
                controlButton(for: controls[index])
            }
        }
    }
    
    private var customLayout: some View {
        // Custom layout can be implemented based on specific needs
        horizontalLayout
    }
    
    // MARK: - Control Button
    
    private func controlButton(for control: ControlConfiguration) -> some View {
        CallControlButton(
            configuration: control,
            defaultSize: configuration.defaultSize,
            colorScheme: colorScheme,
            enableHaptics: configuration.enableHaptics,
            enableAnimations: configuration.enableAnimations && !reduceMotion
        )
    }
    
    // MARK: - Computed Properties
    
    private var adaptiveSpacing: CGFloat {
        let baseSpacing = configuration.spacing
        
        // Adjust spacing based on accessibility text size
        switch sizeCategory {
        case .accessibilityMedium, .accessibilityLarge:
            return baseSpacing * 1.2
        case .accessibilityExtraLarge, .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
            return baseSpacing * 1.5
        default:
            return baseSpacing
        }
    }
}

// MARK: - Call Control Button

@available(iOS 14.0, *)
private struct CallControlButton: View {
    let configuration: CallControlsView.ControlConfiguration
    let defaultSize: CallControlsView.ControlSize
    let colorScheme: ColorScheme
    let enableHaptics: Bool
    let enableAnimations: Bool
    
    @State private var isPressed = false
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: handleButtonTap) {
            ZStack {
                // Background
                Circle()
                    .fill(backgroundColor)
                    .frame(width: buttonSize.diameter, height: buttonSize.diameter)
                    .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowOffset)
                    .overlay(
                        Circle()
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    )
                
                // Icon
                Image(systemName: configuration.type.iconName)
                    .font(.system(size: buttonSize.iconSize, weight: .medium))
                    .foregroundColor(foregroundColor)
                    .rotationEffect(configuration.isSelected ? .degrees(180) : .degrees(0))
                
                // Badge
                if let badge = configuration.badge {
                    badgeView(badge)
                }
                
                // Selection Indicator
                if configuration.isSelected {
                    selectionIndicator
                }
            }
        }
        .scaleEffect(buttonScale)
        .opacity(configuration.isEnabled ? 1.0 : 0.6)
        .disabled(!configuration.isEnabled)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: handlePressGesture) {}
        .accessibilityLabel(configuration.type.accessibilityLabel)
        .accessibilityAddTraits(configuration.isEnabled ? .isButton : [.isButton, .isNotEnabled])
        .accessibilityHint(configuration.isSelected ? "Currently active" : nil)
    }
    
    // MARK: - Badge View
    
    private func badgeView(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.red)
            )
            .offset(x: buttonSize.diameter / 3, y: -buttonSize.diameter / 3)
    }
    
    // MARK: - Selection Indicator
    
    private var selectionIndicator: some View {
        Circle()
            .stroke(Color.white, lineWidth: 3)
            .frame(width: buttonSize.diameter + 6, height: buttonSize.diameter + 6)
            .opacity(0.8)
    }
    
    // MARK: - Computed Properties
    
    private var buttonSize: CallControlsView.ControlSize {
        return configuration.size ?? defaultSize
    }
    
    private var backgroundColor: Color {
        let controlColor = configuration.color ?? configuration.type.defaultColor
        return controlColor.color(for: colorScheme)
    }
    
    private var foregroundColor: Color {
        let controlColor = configuration.color ?? configuration.type.defaultColor
        return controlColor.foregroundColor(for: colorScheme)
    }
    
    private var shadowColor: Color {
        return Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2)
    }
    
    private var shadowRadius: CGFloat {
        return isPressed ? 2 : (buttonSize == .small ? 4 : 6)
    }
    
    private var shadowOffset: CGFloat {
        return isPressed ? 1 : (buttonSize == .small ? 2 : 3)
    }
    
    private var strokeColor: Color {
        if configuration.isSelected {
            return Color.white.opacity(0.3)
        } else {
            return Color.clear
        }
    }
    
    private var strokeWidth: CGFloat {
        return configuration.isSelected ? 2 : 0
    }
    
    private var buttonScale: CGFloat {
        if !configuration.isEnabled {
            return 0.9
        } else if isPressed {
            return 0.95
        } else {
            return 1.0
        }
    }
    
    // MARK: - Gesture Handlers
    
    private func handleButtonTap() {
        guard configuration.isEnabled else { return }
        
        if enableHaptics {
            generateHapticFeedback()
        }
        
        if enableAnimations {
            withAnimation(.easeInOut(duration: 0.1)) {
                isAnimating = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isAnimating = false
                }
            }
        }
        
        configuration.action()
    }
    
    private func handlePressGesture(pressing: Bool) {
        guard configuration.isEnabled else { return }
        
        if enableAnimations {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }
    }
    
    private func generateHapticFeedback() {
        let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle
        
        switch configuration.type {
        case .hangup, .decline:
            feedbackStyle = .heavy
        case .answer:
            feedbackStyle = .heavy
        default:
            feedbackStyle = .light
        }
        
        let generator = UIImpactFeedbackGenerator(style: feedbackStyle)
        generator.impactOccurred()
    }
}

// MARK: - Convenience Initializers

@available(iOS 14.0, *)
extension CallControlsView {
    
    // Standard call controls for active call
    public static func activeCallControls(
        isMuted: Bool = false,
        isSpeakerOn: Bool = false,
        isOnHold: Bool = false,
        onMute: @escaping () -> Void,
        onSpeaker: @escaping () -> Void,
        onHold: @escaping () -> Void,
        onKeypad: @escaping () -> Void,
        onHangUp: @escaping () -> Void
    ) -> CallControlsView {
        
        let controls: [ControlConfiguration] = [
            ControlConfiguration(
                type: isMuted ? .mute : .unmute,
                color: isMuted ? .destructive : .secondary,
                isSelected: isMuted,
                action: onMute
            ),
            ControlConfiguration(
                type: .keypad,
                action: onKeypad
            ),
            ControlConfiguration(
                type: isSpeakerOn ? .speaker : .speakerOff,
                color: isSpeakerOn ? .primary : .secondary,
                isSelected: isSpeakerOn,
                action: onSpeaker
            ),
            ControlConfiguration(
                type: isOnHold ? .resume : .hold,
                color: isOnHold ? .success : .warning,
                isSelected: isOnHold,
                action: onHold
            ),
            ControlConfiguration(
                type: .hangup,
                size: .large,
                action: onHangUp
            )
        ]
        
        return CallControlsView(
            controls: controls,
            configuration: ViewConfiguration(
                layoutStyle: .grid(columns: 3),
                spacing: 24,
                defaultSize: .medium,
                accessibilityGroupLabel: "Active call controls"
            )
        )
    }
    
    // Incoming call controls
    public static func incomingCallControls(
        onAnswer: @escaping () -> Void,
        onDecline: @escaping () -> Void
    ) -> CallControlsView {
        
        let controls: [ControlConfiguration] = [
            ControlConfiguration(
                type: .decline,
                size: .large,
                action: onDecline
            ),
            ControlConfiguration(
                type: .answer,
                size: .large,
                action: onAnswer
            )
        ]
        
        return CallControlsView(
            controls: controls,
            configuration: ViewConfiguration(
                layoutStyle: .horizontal,
                spacing: 80,
                defaultSize: .large,
                accessibilityGroupLabel: "Incoming call controls"
            )
        )
    }
    
    // Compact controls for mini call interface
    public static func compactCallControls(
        isMuted: Bool = false,
        onMute: @escaping () -> Void,
        onHangUp: @escaping () -> Void
    ) -> CallControlsView {
        
        let controls: [ControlConfiguration] = [
            ControlConfiguration(
                type: isMuted ? .mute : .unmute,
                color: isMuted ? .destructive : .secondary,
                size: .small,
                isSelected: isMuted,
                action: onMute
            ),
            ControlConfiguration(
                type: .hangup,
                size: .small,
                action: onHangUp
            )
        ]
        
        return CallControlsView(
            controls: controls,
            configuration: ViewConfiguration(
                layoutStyle: .horizontal,
                spacing: 16,
                defaultSize: .small,
                accessibilityGroupLabel: "Compact call controls"
            )
        )
    }
    
    // Video call controls
    public static func videoCallControls(
        isMuted: Bool = false,
        isVideoOn: Bool = true,
        isSpeakerOn: Bool = false,
        onMute: @escaping () -> Void,
        onVideo: @escaping () -> Void,
        onSpeaker: @escaping () -> Void,
        onHangUp: @escaping () -> Void
    ) -> CallControlsView {
        
        let controls: [ControlConfiguration] = [
            ControlConfiguration(
                type: isMuted ? .mute : .unmute,
                color: isMuted ? .destructive : .secondary,
                isSelected: isMuted,
                action: onMute
            ),
            ControlConfiguration(
                type: isVideoOn ? .video : .videoOff,
                color: isVideoOn ? .primary : .destructive,
                isSelected: isVideoOn,
                action: onVideo
            ),
            ControlConfiguration(
                type: isSpeakerOn ? .speaker : .speakerOff,
                color: isSpeakerOn ? .primary : .secondary,
                isSelected: isSpeakerOn,
                action: onSpeaker
            ),
            ControlConfiguration(
                type: .hangup,
                size: .large,
                action: onHangUp
            )
        ]
        
        return CallControlsView(
            controls: controls,
            configuration: ViewConfiguration(
                layoutStyle: .horizontal,
                spacing: 32,
                defaultSize: .medium,
                accessibilityGroupLabel: "Video call controls"
            )
        )
    }
}

// MARK: - Preview

@available(iOS 14.0, *)
struct CallControlsView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // Active Call Controls
            CallControlsView.activeCallControls(
                isMuted: false,
                isSpeakerOn: true,
                isOnHold: false,
                onMute: {},
                onSpeaker: {},
                onHold: {},
                onKeypad: {},
                onHangUp: {}
            )
            
            // Incoming Call Controls
            CallControlsView.incomingCallControls(
                onAnswer: {},
                onDecline: {}
            )
            
            // Compact Controls
            CallControlsView.compactCallControls(
                isMuted: true,
                onMute: {},
                onHangUp: {}
            )
            
            // Video Call Controls
            CallControlsView.videoCallControls(
                isMuted: false,
                isVideoOn: true,
                isSpeakerOn: false,
                onMute: {},
                onVideo: {},
                onSpeaker: {},
                onHangUp: {}
            )
        }
        .padding()
        .background(Color.black)
        .previewDevice("iPhone 14 Pro Max")
        .preferredColorScheme(.dark)
    }
}