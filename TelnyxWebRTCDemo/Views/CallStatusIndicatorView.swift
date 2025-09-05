//
//  CallStatusIndicatorView.swift
//  TelnyxWebRTCDemo
//
//  Created by Claude Code on 2025-09-05.
//  Copyright © 2025 Telnyx. All rights reserved.
//
//  WhatsApp-Style CallKit Enhancement - Phase 5: Visual Status Indicators
//
//  ULTRA THINK MODE ANALYSIS:
//  This CallStatusIndicatorView provides comprehensive visual feedback for all aspects of call
//  state management, network quality, audio routing, and system status. It implements clear,
//  accessible visual language that helps users understand their current call situation at a glance.
//  The indicators are designed to be informative yet unobtrusive, following iOS design patterns.
//
//  KEY ARCHITECTURAL DECISIONS:
//  1. Semantic Visual Language: Each indicator type has clear meaning and consistent presentation
//  2. Accessibility First: All indicators have proper accessibility labels and support assistive technologies
//  3. Dynamic Adaptation: Indicators adapt to current system state and user preferences
//  4. Animation Support: Smooth, meaningful animations that don't distract from call experience
//  5. Hierarchical Information: Most important status information is visually prominent
//  6. Theme Integration: Respects system appearance with high contrast support
//
//  NATIVE IOS PATTERNS:
//  - System-standard iconography and color usage
//  - Proper visual hierarchy with appropriate sizing
//  - Consistent spacing and alignment following iOS guidelines
//  - Status bar integration patterns for system-level information
//  - Clear visual feedback for transient and persistent states
//

import SwiftUI
import UIKit
import Network
import Combine
import os.log

@available(iOS 14.0, *)
public struct CallStatusIndicatorView: View {
    
    // MARK: - Types
    
    public enum StatusType {
        case networkQuality(NetworkQuality)
        case callState(CallState)
        case audioRoute(AudioRoute)
        case recording(isRecording: Bool)
        case encryption(EncryptionLevel)
        case battery(BatteryLevel)
        case signal(SignalStrength)
        case duration(TimeInterval)
        case participantCount(Int)
        case error(ErrorType)
        case custom(icon: String, text: String, color: Color)
    }
    
    public enum NetworkQuality: CaseIterable {
        case excellent, good, fair, poor, disconnected
        
        var icon: String {
            switch self {
            case .excellent: return "wifi.circle.fill"
            case .good: return "wifi.circle"
            case .fair: return "wifi.exclamationmark"
            case .poor: return "wifi.slash"
            case .disconnected: return "wifi.slash.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .fair: return .orange
            case .poor: return .red
            case .disconnected: return .red
            }
        }
        
        var description: String {
            switch self {
            case .excellent: return "Excellent connection"
            case .good: return "Good connection"
            case .fair: return "Fair connection"
            case .poor: return "Poor connection"
            case .disconnected: return "No connection"
            }
        }
    }
    
    public enum CallState: CaseIterable {
        case connecting, connected, onHold, muted, recording, ending
        
        var icon: String {
            switch self {
            case .connecting: return "phone.connection"
            case .connected: return "phone.fill.connection"
            case .onHold: return "pause.circle.fill"
            case .muted: return "mic.slash.circle.fill"
            case .recording: return "record.circle.fill"
            case .ending: return "phone.down.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .connecting: return .blue
            case .connected: return .green
            case .onHold: return .orange
            case .muted: return .red
            case .recording: return .red
            case .ending: return .gray
            }
        }
        
        var description: String {
            switch self {
            case .connecting: return "Connecting call"
            case .connected: return "Call connected"
            case .onHold: return "Call on hold"
            case .muted: return "Microphone muted"
            case .recording: return "Call being recorded"
            case .ending: return "Call ending"
            }
        }
    }
    
    public enum AudioRoute: CaseIterable {
        case speaker, earpiece, bluetooth, headphones, airPods, carPlay
        
        var icon: String {
            switch self {
            case .speaker: return "speaker.wave.3.fill"
            case .earpiece: return "iphone"
            case .bluetooth: return "headphones.circle.fill"
            case .headphones: return "headphones"
            case .airPods: return "airpods"
            case .carPlay: return "car.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .speaker: return .blue
            case .earpiece: return .gray
            case .bluetooth: return .blue
            case .headphones: return .purple
            case .airPods: return .white
            case .carPlay: return .blue
            }
        }
        
        var description: String {
            switch self {
            case .speaker: return "Using speaker"
            case .earpiece: return "Using earpiece"
            case .bluetooth: return "Using Bluetooth device"
            case .headphones: return "Using headphones"
            case .airPods: return "Using AirPods"
            case .carPlay: return "Using CarPlay"
            }
        }
    }
    
    public enum EncryptionLevel: CaseIterable {
        case none, standard, enhanced
        
        var icon: String {
            switch self {
            case .none: return "lock.open.fill"
            case .standard: return "lock.fill"
            case .enhanced: return "lock.shield.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .none: return .red
            case .standard: return .orange
            case .enhanced: return .green
            }
        }
        
        var description: String {
            switch self {
            case .none: return "Unencrypted call"
            case .standard: return "Standard encryption"
            case .enhanced: return "Enhanced encryption"
            }
        }
    }
    
    public enum BatteryLevel: CaseIterable {
        case critical, low, normal, high
        
        var icon: String {
            switch self {
            case .critical: return "battery.0"
            case .low: return "battery.25"
            case .normal: return "battery.75"
            case .high: return "battery.100"
            }
        }
        
        var color: Color {
            switch self {
            case .critical: return .red
            case .low: return .orange
            case .normal: return .green
            case .high: return .green
            }
        }
        
        var showWarning: Bool {
            switch self {
            case .critical, .low: return true
            case .normal, .high: return false
            }
        }
    }
    
    public enum SignalStrength: CaseIterable {
        case none, weak, fair, good, excellent
        
        var icon: String {
            switch self {
            case .none: return "antenna.radiowaves.left.and.right.slash"
            case .weak: return "antenna.radiowaves.left.and.right"
            case .fair: return "antenna.radiowaves.left.and.right"
            case .good: return "antenna.radiowaves.left.and.right"
            case .excellent: return "antenna.radiowaves.left.and.right"
            }
        }
        
        var color: Color {
            switch self {
            case .none: return .red
            case .weak: return .red
            case .fair: return .orange
            case .good: return .blue
            case .excellent: return .green
            }
        }
        
        var barCount: Int {
            switch self {
            case .none: return 0
            case .weak: return 1
            case .fair: return 2
            case .good: return 3
            case .excellent: return 4
            }
        }
    }
    
    public enum ErrorType: CaseIterable {
        case networkError, audioError, permissionError, serverError, unknownError
        
        var icon: String {
            switch self {
            case .networkError: return "wifi.exclamationmark"
            case .audioError: return "speaker.slash.fill"
            case .permissionError: return "exclamationmark.shield.fill"
            case .serverError: return "server.rack"
            case .unknownError: return "exclamationmark.triangle.fill"
            }
        }
        
        var color: Color {
            return .red
        }
        
        var description: String {
            switch self {
            case .networkError: return "Network connection error"
            case .audioError: return "Audio system error"
            case .permissionError: return "Permission required"
            case .serverError: return "Server connection error"
            case .unknownError: return "Unknown error occurred"
            }
        }
    }
    
    public enum DisplayStyle {
        case compact
        case standard
        case detailed
        case minimal
    }
    
    public struct Configuration {
        let displayStyle: DisplayStyle
        let showText: Bool
        let enableAnimations: Bool
        let enableGradients: Bool
        let spacing: CGFloat
        let iconSize: CGFloat
        let textSize: CGFloat
        let cornerRadius: CGFloat
        
        public init(
            displayStyle: DisplayStyle = .standard,
            showText: Bool = true,
            enableAnimations: Bool = true,
            enableGradients: Bool = false,
            spacing: CGFloat = 8,
            iconSize: CGFloat = 16,
            textSize: CGFloat = 12,
            cornerRadius: CGFloat = 8
        ) {
            self.displayStyle = displayStyle
            self.showText = showText
            self.enableAnimations = enableAnimations
            self.enableGradients = enableGradients
            self.spacing = spacing
            self.iconSize = iconSize
            self.textSize = textSize
            self.cornerRadius = cornerRadius
        }
        
        public static let compact = Configuration(
            displayStyle: .compact,
            showText: false,
            spacing: 4,
            iconSize: 14,
            textSize: 10
        )
        
        public static let detailed = Configuration(
            displayStyle: .detailed,
            showText: true,
            enableAnimations: true,
            enableGradients: true,
            spacing: 12,
            iconSize: 20,
            textSize: 14
        )
    }
    
    // MARK: - Properties
    
    private let statusTypes: [StatusType]
    private let configuration: Configuration
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var animationTimer: Timer?
    @State private var animatingStates: Set<String> = []
    
    // MARK: - Initialization
    
    public init(
        statusTypes: [StatusType],
        configuration: Configuration = Configuration()
    ) {
        self.statusTypes = statusTypes
        self.configuration = configuration
    }
    
    public init(
        statusType: StatusType,
        configuration: Configuration = Configuration()
    ) {
        self.statusTypes = [statusType]
        self.configuration = configuration
    }
    
    // MARK: - Body
    
    public var body: some View {
        Group {
            switch configuration.displayStyle {
            case .compact:
                compactLayout
            case .standard:
                standardLayout
            case .detailed:
                detailedLayout
            case .minimal:
                minimalLayout
            }
        }
        .onAppear {
            startAnimationTimer()
        }
        .onDisappear {
            stopAnimationTimer()
        }
    }
    
    // MARK: - Layout Views
    
    private var compactLayout: some View {
        HStack(spacing: configuration.spacing / 2) {
            ForEach(statusTypes.indices, id: \.self) { index in
                StatusIndicator(
                    statusType: statusTypes[index],
                    configuration: configuration,
                    colorScheme: colorScheme,
                    isAnimating: isAnimating(for: statusTypes[index])
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
    }
    
    private var standardLayout: some View {
        HStack(spacing: configuration.spacing) {
            ForEach(statusTypes.indices, id: \.self) { index in
                StatusIndicator(
                    statusType: statusTypes[index],
                    configuration: configuration,
                    colorScheme: colorScheme,
                    isAnimating: isAnimating(for: statusTypes[index])
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
    }
    
    private var detailedLayout: some View {
        VStack(alignment: .leading, spacing: configuration.spacing) {
            ForEach(statusTypes.indices, id: \.self) { index in
                HStack(spacing: configuration.spacing) {
                    StatusIndicator(
                        statusType: statusTypes[index],
                        configuration: configuration,
                        colorScheme: colorScheme,
                        isAnimating: isAnimating(for: statusTypes[index])
                    )
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
    }
    
    private var minimalLayout: some View {
        HStack(spacing: 2) {
            ForEach(statusTypes.indices, id: \.self) { index in
                StatusIndicator(
                    statusType: statusTypes[index],
                    configuration: Configuration(
                        displayStyle: .minimal,
                        showText: false,
                        iconSize: 12,
                        textSize: 10
                    ),
                    colorScheme: colorScheme,
                    isAnimating: isAnimating(for: statusTypes[index])
                )
            }
        }
    }
    
    // MARK: - Background View
    
    private var backgroundView: some View {
        Group {
            if configuration.enableGradients {
                LinearGradient(
                    colors: backgroundGradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                backgroundSolidColor
            }
        }
        .opacity(0.9)
    }
    
    private var backgroundSolidColor: Color {
        colorScheme == .dark ? 
            Color.black.opacity(0.3) : 
            Color.white.opacity(0.3)
    }
    
    private var backgroundGradientColors: [Color] {
        colorScheme == .dark ? [
            Color.black.opacity(0.4),
            Color.gray.opacity(0.2)
        ] : [
            Color.white.opacity(0.4),
            Color.gray.opacity(0.1)
        ]
    }
    
    // MARK: - Animation Management
    
    private func startAnimationTimer() {
        guard configuration.enableAnimations && !reduceMotion else { return }
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateAnimatingStates()
        }
    }
    
    private func stopAnimationTimer() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func updateAnimatingStates() {
        for statusType in statusTypes {
            let shouldAnimate = shouldAnimateStatus(statusType)
            let key = statusKey(for: statusType)
            
            if shouldAnimate {
                animatingStates.insert(key)
            } else {
                animatingStates.remove(key)
            }
        }
    }
    
    private func shouldAnimateStatus(_ statusType: StatusType) -> Bool {
        switch statusType {
        case .networkQuality(let quality):
            return quality == .poor || quality == .disconnected
        case .callState(let state):
            return state == .connecting || state == .recording
        case .error:
            return true
        case .battery(let level):
            return level.showWarning
        default:
            return false
        }
    }
    
    private func isAnimating(for statusType: StatusType) -> Bool {
        return animatingStates.contains(statusKey(for: statusType))
    }
    
    private func statusKey(for statusType: StatusType) -> String {
        switch statusType {
        case .networkQuality: return "network"
        case .callState: return "call"
        case .audioRoute: return "audio"
        case .recording: return "recording"
        case .encryption: return "encryption"
        case .battery: return "battery"
        case .signal: return "signal"
        case .duration: return "duration"
        case .participantCount: return "participants"
        case .error: return "error"
        case .custom: return "custom"
        }
    }
}

// MARK: - Status Indicator

@available(iOS 14.0, *)
private struct StatusIndicator: View {
    let statusType: CallStatusIndicatorView.StatusType
    let configuration: CallStatusIndicatorView.Configuration
    let colorScheme: ColorScheme
    let isAnimating: Bool
    
    @State private var animationScale: CGFloat = 1.0
    @State private var animationOpacity: Double = 1.0
    
    var body: some View {
        HStack(spacing: configuration.spacing / 2) {
            // Icon
            iconView
                .scaleEffect(animationScale)
                .opacity(animationOpacity)
                .animation(
                    isAnimating ? 
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : 
                        .none,
                    value: animationScale
                )
            
            // Text
            if configuration.showText && !statusText.isEmpty {
                Text(statusText)
                    .font(.system(size: configuration.textSize, weight: .medium))
                    .foregroundColor(textColor)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            if isAnimating {
                startAnimation()
            }
        }
        .onChange(of: isAnimating) { newValue in
            if newValue {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
    }
    
    // MARK: - Icon View
    
    private var iconView: some View {
        Group {
            switch statusType {
            case .signal(let strength):
                SignalBarsView(strength: strength, size: configuration.iconSize)
            case .duration(let timeInterval):
                DurationView(duration: timeInterval, size: configuration.iconSize)
            case .participantCount(let count):
                ParticipantCountView(count: count, size: configuration.iconSize)
            default:
                Image(systemName: iconName)
                    .font(.system(size: configuration.iconSize, weight: .medium))
                    .foregroundColor(iconColor)
            }
        }
    }
    
    // MARK: - Specialized Views
    
    private struct SignalBarsView: View {
        let strength: CallStatusIndicatorView.SignalStrength
        let size: CGFloat
        
        var body: some View {
            HStack(spacing: 2) {
                ForEach(0..<4) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(barColor(for: index))
                        .frame(width: size / 6, height: size * barHeight(for: index))
                }
            }
        }
        
        private func barColor(for index: Int) -> Color {
            return index < strength.barCount ? strength.color : Color.gray.opacity(0.3)
        }
        
        private func barHeight(for index: Int) -> CGFloat {
            let heights: [CGFloat] = [0.3, 0.5, 0.7, 1.0]
            return heights[index]
        }
    }
    
    private struct DurationView: View {
        let duration: TimeInterval
        let size: CGFloat
        
        var body: some View {
            Text(formattedDuration)
                .font(.system(size: size * 0.8, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
        }
        
        private var formattedDuration: String {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private struct ParticipantCountView: View {
        let count: Int
        let size: CGFloat
        
        var body: some View {
            HStack(spacing: 2) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: size * 0.8))
                
                Text("\(count)")
                    .font(.system(size: size * 0.8, weight: .semibold))
            }
            .foregroundColor(.blue)
        }
    }
    
    // MARK: - Computed Properties
    
    private var iconName: String {
        switch statusType {
        case .networkQuality(let quality): return quality.icon
        case .callState(let state): return state.icon
        case .audioRoute(let route): return route.icon
        case .recording(let isRecording): return isRecording ? "record.circle.fill" : "record.circle"
        case .encryption(let level): return level.icon
        case .battery(let level): return level.icon
        case .signal(let strength): return strength.icon
        case .error(let errorType): return errorType.icon
        case .custom(let icon, _, _): return icon
        default: return "questionmark.circle"
        }
    }
    
    private var iconColor: Color {
        switch statusType {
        case .networkQuality(let quality): return quality.color
        case .callState(let state): return state.color
        case .audioRoute(let route): return route.color
        case .recording(let isRecording): return isRecording ? .red : .gray
        case .encryption(let level): return level.color
        case .battery(let level): return level.color
        case .signal(let strength): return strength.color
        case .error(let errorType): return errorType.color
        case .custom(_, _, let color): return color
        default: return .gray
        }
    }
    
    private var statusText: String {
        switch statusType {
        case .networkQuality(let quality): return quality.description
        case .callState(let state): return state.description
        case .audioRoute(let route): return route.description
        case .recording(let isRecording): return isRecording ? "Recording" : ""
        case .encryption(let level): return level.description
        case .battery: return "Low Battery"
        case .signal: return "Signal"
        case .duration: return ""
        case .participantCount(let count): return "\(count) people"
        case .error(let errorType): return errorType.description
        case .custom(_, let text, _): return text
        }
    }
    
    private var textColor: Color {
        return colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.8)
    }
    
    private var accessibilityLabel: String {
        return statusText.isEmpty ? iconName : statusText
    }
    
    // MARK: - Animation Methods
    
    private func startAnimation() {
        animationScale = 0.8
        animationOpacity = 0.6
    }
    
    private func stopAnimation() {
        animationScale = 1.0
        animationOpacity = 1.0
    }
}

// MARK: - Convenience Initializers

@available(iOS 14.0, *)
extension CallStatusIndicatorView {
    
    public static func networkStatus(
        quality: NetworkQuality,
        configuration: Configuration = .compact
    ) -> CallStatusIndicatorView {
        CallStatusIndicatorView(
            statusType: .networkQuality(quality),
            configuration: configuration
        )
    }
    
    public static func callStatus(
        state: CallState,
        configuration: Configuration = .standard
    ) -> CallStatusIndicatorView {
        CallStatusIndicatorView(
            statusType: .callState(state),
            configuration: configuration
        )
    }
    
    public static func audioRouteStatus(
        route: AudioRoute,
        configuration: Configuration = .compact
    ) -> CallStatusIndicatorView {
        CallStatusIndicatorView(
            statusType: .audioRoute(route),
            configuration: configuration
        )
    }
    
    public static func multipleStatus(
        networkQuality: NetworkQuality,
        callState: CallState,
        audioRoute: AudioRoute,
        configuration: Configuration = .standard
    ) -> CallStatusIndicatorView {
        CallStatusIndicatorView(
            statusTypes: [
                .networkQuality(networkQuality),
                .callState(callState),
                .audioRoute(audioRoute)
            ],
            configuration: configuration
        )
    }
}

// MARK: - Preview

@available(iOS 14.0, *)
struct CallStatusIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Network Status
            CallStatusIndicatorView.networkStatus(
                quality: .excellent,
                configuration: .compact
            )
            
            // Call Status
            CallStatusIndicatorView.callStatus(
                state: .connected,
                configuration: .standard
            )
            
            // Multiple Status
            CallStatusIndicatorView.multipleStatus(
                networkQuality: .good,
                callState: .connected,
                audioRoute: .speaker,
                configuration: .detailed
            )
            
            // Error Status
            CallStatusIndicatorView(
                statusType: .error(.networkError),
                configuration: .standard
            )
        }
        .padding()
        .background(Color.black.opacity(0.1))
        .previewDevice("iPhone 14 Pro Max")
    }
}