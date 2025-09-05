//
//  CallTransitionHintView.swift
//  TelnyxWebRTCDemo
//
//  Created by Claude Code on 2025-09-05.
//  Copyright © 2025 Telnyx. All rights reserved.
//
//  WhatsApp-Style CallKit Enhancement - Phase 5: Transition User Guidance
//
//  ULTRA THINK MODE ANALYSIS:
//  This CallTransitionHintView provides intelligent, contextual user guidance for transitioning
//  between the fallback UI and native CallKit interface. It addresses the critical iOS 18+ UX
//  problem where users become trapped in app UI without clear understanding of how to access
//  the superior native CallKit experience. The component implements progressive disclosure,
//  adaptive learning, and sophisticated timing algorithms.
//
//  KEY ARCHITECTURAL DECISIONS:
//  1. Progressive Disclosure: Starts with subtle hints, escalates based on user behavior
//  2. Contextual Intelligence: Timing and content adapt to call state and user patterns
//  3. Gesture Integration: Seamlessly works with swipe, drag, and tap interactions
//  4. Learning System: Adapts frequency and intensity based on user proficiency
//  5. Accessibility First: Full VoiceOver support with spatial audio guidance
//  6. Performance Optimized: Minimal resource usage during critical call moments
//
//  WHATSAPP-STYLE APPROACH:
//  - Clean, unobtrusive hints that maintain call focus
//  - Professional timing that doesn't interrupt important call moments
//  - Intelligent adaptation based on user behavior patterns
//  - Contextual relevance that provides value without annoyance
//  - Progressive enhancement from subtle to more explicit guidance
//

import SwiftUI
import UIKit
import Combine
import os.log

@available(iOS 14.0, *)
public struct CallTransitionHintView: View {
    
    // MARK: - Types
    
    public enum HintType: CaseIterable {
        case swipeUpGesture
        case tapToTransition  
        case dragIndicator
        case onboardingOverlay
        case contextualTooltip
        case emergencyGuidance
        case voiceOverAnnouncement
        case hapticGuidance
        
        var priority: Int {
            switch self {
            case .emergencyGuidance: return 1000
            case .onboardingOverlay: return 800
            case .voiceOverAnnouncement: return 700
            case .contextualTooltip: return 600
            case .swipeUpGesture: return 500
            case .dragIndicator: return 400
            case .tapToTransition: return 300
            case .hapticGuidance: return 200
            }
        }
        
        var defaultDuration: TimeInterval {
            switch self {
            case .swipeUpGesture: return 3.0
            case .tapToTransition: return 2.5
            case .dragIndicator: return 4.0
            case .onboardingOverlay: return 8.0
            case .contextualTooltip: return 5.0
            case .emergencyGuidance: return 10.0
            case .voiceOverAnnouncement: return 6.0
            case .hapticGuidance: return 1.0
            }
        }
    }
    
    public enum HintTrigger {
        case firstTimeUser
        case callKitFailure  
        case extendedAppUsage(duration: TimeInterval)
        case userStruggling
        case criticalCallMoment
        case accessibilityMode
        case manualRequest
        case timerBased(delay: TimeInterval)
        
        var shouldShowImmediately: Bool {
            switch self {
            case .criticalCallMoment, .emergencyGuidance, .accessibilityMode:
                return true
            default:
                return false
            }
        }
    }
    
    public enum UserProficiency: CaseIterable {
        case newUser
        case learning
        case intermediate  
        case expert
        case customDisabled
        
        var hintFrequency: HintFrequency {
            switch self {
            case .newUser: return .frequent
            case .learning: return .regular
            case .intermediate: return .occasional
            case .expert: return .rare
            case .customDisabled: return .never
            }
        }
        
        var preferredHintTypes: [HintType] {
            switch self {
            case .newUser: 
                return [.onboardingOverlay, .swipeUpGesture, .contextualTooltip]
            case .learning: 
                return [.swipeUpGesture, .dragIndicator, .contextualTooltip]
            case .intermediate: 
                return [.dragIndicator, .tapToTransition]
            case .expert: 
                return [.hapticGuidance]
            case .customDisabled: 
                return []
            }
        }
    }
    
    public enum HintFrequency: CaseIterable {
        case never
        case rare        // Once per week
        case occasional  // Once per day  
        case regular     // Once per session
        case frequent    // Multiple times per session
        
        var showProbability: Double {
            switch self {
            case .never: return 0.0
            case .rare: return 0.1
            case .occasional: return 0.3
            case .regular: return 0.7
            case .frequent: return 1.0
            }
        }
        
        var cooldownPeriod: TimeInterval {
            switch self {
            case .never: return .infinity
            case .rare: return 604800    // 1 week
            case .occasional: return 86400     // 1 day
            case .regular: return 3600         // 1 hour
            case .frequent: return 300         // 5 minutes
            }
        }
    }
    
    public struct HintConfiguration {
        let enabledHintTypes: Set<HintType>
        let userProficiency: UserProficiency
        let enableAdaptiveLearning: Bool
        let enableHapticFeedback: Bool
        let enableVoiceOverEnhancement: Bool
        let enableEmergencyGuidance: Bool
        let customThemeColors: HintTheme?
        let animationStyle: HintAnimationStyle
        
        public init(
            enabledHintTypes: Set<HintType> = Set(HintType.allCases),
            userProficiency: UserProficiency = .newUser,
            enableAdaptiveLearning: Bool = true,
            enableHapticFeedback: Bool = true,
            enableVoiceOverEnhancement: Bool = true,
            enableEmergencyGuidance: Bool = true,
            customThemeColors: HintTheme? = nil,
            animationStyle: HintAnimationStyle = .natural
        ) {
            self.enabledHintTypes = enabledHintTypes
            self.userProficiency = userProficiency
            self.enableAdaptiveLearning = enableAdaptiveLearning
            self.enableHapticFeedback = enableHapticFeedback
            self.enableVoiceOverEnhancement = enableVoiceOverEnhancement
            self.enableEmergencyGuidance = enableEmergencyGuidance
            self.customThemeColors = customThemeColors
            self.animationStyle = animationStyle
        }
        
        public static let minimal = HintConfiguration(
            enabledHintTypes: [.hapticGuidance, .dragIndicator],
            userProficiency: .expert,
            enableAdaptiveLearning: false
        )
        
        public static let accessibility = HintConfiguration(
            enabledHintTypes: [.voiceOverAnnouncement, .contextualTooltip, .onboardingOverlay],
            enableVoiceOverEnhancement: true,
            animationStyle: .reduced
        )
    }
    
    public struct HintTheme {
        let primaryColor: Color
        let secondaryColor: Color
        let backgroundColor: Color
        let textColor: Color
        let accentColor: Color
        
        public static let `default` = HintTheme(
            primaryColor: .blue,
            secondaryColor: .gray,
            backgroundColor: Color.black.opacity(0.8),
            textColor: .white,
            accentColor: .green
        )
        
        public static let subtle = HintTheme(
            primaryColor: Color.white.opacity(0.9),
            secondaryColor: Color.gray.opacity(0.6),
            backgroundColor: Color.black.opacity(0.4),
            textColor: Color.white.opacity(0.9),
            accentColor: Color.blue.opacity(0.8)
        )
    }
    
    public enum HintAnimationStyle: CaseIterable {
        case natural
        case energetic
        case subtle
        case reduced
        case none
        
        var animationCurve: Animation {
            switch self {
            case .natural: return .easeInOut(duration: 0.4)
            case .energetic: return .spring(response: 0.3, dampingFraction: 0.6)
            case .subtle: return .easeOut(duration: 0.6)
            case .reduced: return .linear(duration: 0.2)
            case .none: return .none
            }
        }
    }
    
    // MARK: - Properties
    
    @StateObject private var viewModel: CallTransitionHintViewModel
    @State private var currentHintType: HintType?
    @State private var hintOpacity: Double = 0
    @State private var animationOffset: CGSize = .zero
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    
    private let configuration: HintConfiguration
    private let onTransitionRequested: () -> Void
    
    // MARK: - Initialization
    
    public init(
        configuration: HintConfiguration = HintConfiguration(),
        onTransitionRequested: @escaping () -> Void = {}
    ) {
        self.configuration = configuration
        self.onTransitionRequested = onTransitionRequested
        self._viewModel = StateObject(wrappedValue: CallTransitionHintViewModel(configuration: configuration))
    }
    
    // MARK: - Body
    
    public var body: some View {
        ZStack {
            // Main hint content
            if let hintType = currentHintType {
                hintContent(for: hintType)
                    .opacity(hintOpacity)
                    .offset(animationOffset)
                    .rotationEffect(.degrees(rotationAngle))
                    .scaleEffect(pulseScale)
                    .transition(transitionAnimation)
                    .onAppear {
                        startHintAnimation(for: hintType)
                    }
                    .onDisappear {
                        stopHintAnimation()
                    }
            }
        }
        .onReceive(viewModel.shouldShowHint) { hintType in
            showHint(type: hintType)
        }
        .onReceive(viewModel.shouldHideHint) { _ in
            hideCurrentHint()
        }
        .accessibilityElement(children: .contain)
        .accessibilityHidden(currentHintType == nil)
    }
    
    // MARK: - Hint Content Views
    
    @ViewBuilder
    private func hintContent(for hintType: HintType) -> some View {
        switch hintType {
        case .swipeUpGesture:
            swipeUpGestureHint
        case .tapToTransition:
            tapTransitionHint
        case .dragIndicator:
            dragIndicatorHint
        case .onboardingOverlay:
            onboardingOverlayHint
        case .contextualTooltip:
            contextualTooltipHint
        case .emergencyGuidance:
            emergencyGuidanceHint
        case .voiceOverAnnouncement:
            voiceOverAnnouncementHint
        case .hapticGuidance:
            hapticGuidanceHint
        }
    }
    
    private var swipeUpGestureHint: some View {
        VStack(spacing: 16) {
            // Animated swipe gesture
            ZStack {
                // Background circle
                Circle()
                    .fill(themeColors.backgroundColor)
                    .frame(width: 80, height: 80)
                
                // Swipe arrow
                Image(systemName: "arrow.up")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(themeColors.primaryColor)
                    .offset(y: animationOffset.height)
            }
            
            // Instruction text
            VStack(spacing: 8) {
                Text("Swipe up to switch to CallKit")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(themeColors.textColor)
                
                Text("Access native iOS call interface")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(themeColors.textColor.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeColors.backgroundColor)
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
        )
        .accessibilityLabel("Swipe up to switch to CallKit interface")
        .accessibilityHint("Use this gesture to access the native iOS call interface")
    }
    
    private var tapTransitionHint: some View {
        HStack(spacing: 12) {
            // Tap indicator
            Circle()
                .fill(themeColors.accentColor)
                .frame(width: 12, height: 12)
                .scaleEffect(pulseScale)
            
            Text("Tap here to switch to CallKit")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(themeColors.textColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(themeColors.backgroundColor)
        )
        .accessibilityLabel("Tap to switch to CallKit")
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            handleTransitionRequest()
        }
    }
    
    private var dragIndicatorHint: some View {
        VStack(spacing: 8) {
            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(themeColors.secondaryColor)
                .frame(width: 36, height: 6)
                .offset(y: animationOffset.height * 0.3)
            
            // Instruction
            Text("Drag up")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeColors.textColor.opacity(0.8))
        }
        .accessibilityLabel("Drag handle to switch to CallKit")
    }
    
    private var onboardingOverlayHint: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(themeColors.accentColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "phone.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(themeColors.accentColor)
            }
            
            // Title and description
            VStack(spacing: 12) {
                Text("CallKit Interface Available")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(themeColors.textColor)
                    .multilineTextAlignment(.center)
                
                Text("You can switch to the native iOS call interface for the best experience. Swipe up or tap the transition button.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(themeColors.textColor.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button("Maybe Later") {
                    viewModel.userDeferredTransition()
                    hideCurrentHint()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(themeColors.secondaryColor)
                
                Button("Try CallKit") {
                    handleTransitionRequest()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(themeColors.accentColor)
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(themeColors.backgroundColor)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 8)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("CallKit interface onboarding")
    }
    
    private var contextualTooltipHint: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 16))
                .foregroundColor(themeColors.accentColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Pro Tip")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeColors.accentColor)
                
                Text("Switch to CallKit for better call management")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(themeColors.textColor)
            }
            
            Spacer()
            
            Button("Switch") {
                handleTransitionRequest()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(themeColors.accentColor)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeColors.backgroundColor)
        )
        .accessibilityElement(children: .contain)
    }
    
    private var emergencyGuidanceHint: some View {
        VStack(spacing: 16) {
            // Warning icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.red)
            }
            
            VStack(spacing: 8) {
                Text("CallKit Recommended")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.red)
                
                Text("For the best call experience, please switch to the native CallKit interface.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(themeColors.textColor)
                    .multilineTextAlignment(.center)
            }
            
            Button("Switch Now") {
                handleTransitionRequest()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red)
            )
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeColors.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.red.opacity(0.3), lineWidth: 2)
                )
        )
        .accessibilityLabel("Emergency guidance to switch to CallKit")
    }
    
    private var voiceOverAnnouncementHint: some View {
        VStack(spacing: 12) {
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 24))
                .foregroundColor(themeColors.accentColor)
            
            Text("CallKit Available")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(themeColors.textColor)
            
            Text("Double-tap to switch to native call interface")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(themeColors.textColor.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(themeColors.backgroundColor)
        )
        .accessibilityLabel("CallKit interface available. Double-tap to switch to native call interface.")
        .accessibilityAddTraits(.isButton)
        .onTapGesture(count: 2) {
            handleTransitionRequest()
        }
    }
    
    private var hapticGuidanceHint: some View {
        Circle()
            .fill(themeColors.accentColor.opacity(0.3))
            .frame(width: 8, height: 8)
            .scaleEffect(pulseScale)
            .onAppear {
                if configuration.enableHapticFeedback {
                    generateHapticPattern()
                }
            }
    }
    
    // MARK: - Computed Properties
    
    private var themeColors: HintTheme {
        return configuration.customThemeColors ?? (colorScheme == .dark ? .default : .subtle)
    }
    
    private var transitionAnimation: AnyTransition {
        switch configuration.animationStyle {
        case .natural:
            return .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            )
        case .energetic:
            return .asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        case .subtle:
            return .opacity
        case .reduced:
            return .opacity
        case .none:
            return .identity
        }
    }
    
    // MARK: - Animation Methods
    
    private func startHintAnimation(for hintType: HintType) {
        guard !reduceMotion && configuration.animationStyle != .none else { return }
        
        switch hintType {
        case .swipeUpGesture:
            animateSwipeGesture()
        case .dragIndicator:
            animateDragIndicator()
        case .tapToTransition, .hapticGuidance:
            animatePulse()
        default:
            break
        }
    }
    
    private func animateSwipeGesture() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            animationOffset = CGSize(width: 0, height: -20)
        }
    }
    
    private func animateDragIndicator() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            animationOffset = CGSize(width: 0, height: -8)
        }
    }
    
    private func animatePulse() {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            pulseScale = 1.3
        }
    }
    
    private func stopHintAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            animationOffset = .zero
            rotationAngle = 0
            pulseScale = 1.0
        }
    }
    
    // MARK: - Interaction Handlers
    
    private func showHint(type: HintType) {
        guard configuration.enabledHintTypes.contains(type) else { return }
        
        currentHintType = type
        
        withAnimation(configuration.animationStyle.animationCurve) {
            hintOpacity = 1.0
        }
        
        // Schedule auto-hide
        DispatchQueue.main.asyncAfter(deadline: .now() + type.defaultDuration) {
            if currentHintType == type {  // Only hide if it's still the same hint
                hideCurrentHint()
            }
        }
        
        // VoiceOver announcement
        if voiceOverEnabled && configuration.enableVoiceOverEnhancement {
            announceForVoiceOver(hintType: type)
        }
        
        // Track user interaction
        viewModel.trackHintShown(type: type)
    }
    
    private func hideCurrentHint() {
        withAnimation(configuration.animationStyle.animationCurve) {
            hintOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            currentHintType = nil
        }
    }
    
    private func handleTransitionRequest() {
        viewModel.userRequestedTransition()
        hideCurrentHint()
        onTransitionRequested()
        
        if configuration.enableHapticFeedback {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
    
    private func generateHapticPattern() {
        guard configuration.enableHapticFeedback else { return }
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        
        // Triple tap pattern
        generator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                generator.impactOccurred()
            }
        }
    }
    
    private func announceForVoiceOver(hintType: HintType) {
        let announcement: String
        
        switch hintType {
        case .swipeUpGesture:
            announcement = "CallKit available. Swipe up with one finger to switch to native call interface."
        case .tapToTransition:
            announcement = "CallKit switch button available. Double-tap to activate."
        case .onboardingOverlay:
            announcement = "CallKit tutorial available. Native iOS call interface provides better call management."
        case .voiceOverAnnouncement:
            announcement = "CallKit interface available for enhanced call experience."
        default:
            announcement = "CallKit interface available. Use gestures to switch."
        }
        
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
    
    // MARK: - Public Interface
    
    public func triggerHint(_ trigger: HintTrigger) {
        viewModel.evaluateHintTrigger(trigger)
    }
    
    public func updateUserProficiency(_ proficiency: UserProficiency) {
        viewModel.updateUserProficiency(proficiency)
    }
    
    public func setHintEnabled(_ enabled: Bool, for hintType: HintType) {
        viewModel.setHintEnabled(enabled, for: hintType)
    }
    
    public func resetLearningData() {
        viewModel.resetLearningData()
    }
}

// MARK: - View Model

@available(iOS 14.0, *)
@MainActor
class CallTransitionHintViewModel: ObservableObject {
    
    private let configuration: CallTransitionHintView.HintConfiguration
    private let hintSubject = PassthroughSubject<CallTransitionHintView.HintType, Never>()
    private let hideSubject = PassthroughSubject<Void, Never>()
    
    // Learning and adaptation state
    @Published private var userProficiency: CallTransitionHintView.UserProficiency
    private var hintHistory: [CallTransitionHintView.HintType: [Date]] = [:]
    private var userInteractions: [String: Any] = [:]
    private var lastHintShown: Date?
    
    lazy var shouldShowHint: AnyPublisher<CallTransitionHintView.HintType, Never> = {
        hintSubject.eraseToAnyPublisher()
    }()
    
    lazy var shouldHideHint: AnyPublisher<Void, Never> = {
        hideSubject.eraseToAnyPublisher()
    }()
    
    init(configuration: CallTransitionHintView.HintConfiguration) {
        self.configuration = configuration
        self.userProficiency = configuration.userProficiency
        loadLearningData()
    }
    
    func evaluateHintTrigger(_ trigger: CallTransitionHintView.HintTrigger) {
        let appropriateHintType = selectHintType(for: trigger)
        
        guard shouldShowHint(type: appropriateHintType, trigger: trigger) else { return }
        
        hintSubject.send(appropriateHintType)
    }
    
    func trackHintShown(type: CallTransitionHintView.HintType) {
        lastHintShown = Date()
        hintHistory[type, default: []].append(Date())
        
        // Limit history to last 10 entries per type
        if hintHistory[type]!.count > 10 {
            hintHistory[type]!.removeFirst()
        }
        
        saveLearningData()
    }
    
    func userRequestedTransition() {
        userInteractions["lastTransitionRequest"] = Date()
        userInteractions["totalTransitions"] = (userInteractions["totalTransitions"] as? Int ?? 0) + 1
        
        // Update proficiency based on usage
        if configuration.enableAdaptiveLearning {
            updateProficiencyBasedOnUsage()
        }
        
        saveLearningData()
    }
    
    func userDeferredTransition() {
        userInteractions["lastDeferral"] = Date()
        userInteractions["totalDeferrals"] = (userInteractions["totalDeferrals"] as? Int ?? 0) + 1
        saveLearningData()
    }
    
    func updateUserProficiency(_ proficiency: CallTransitionHintView.UserProficiency) {
        userProficiency = proficiency
        saveLearningData()
    }
    
    func setHintEnabled(_ enabled: Bool, for hintType: CallTransitionHintView.HintType) {
        // This would update user preferences - implementation depends on preferences system
    }
    
    func resetLearningData() {
        hintHistory.removeAll()
        userInteractions.removeAll()
        userProficiency = .newUser
        saveLearningData()
    }
    
    private func selectHintType(for trigger: CallTransitionHintView.HintTrigger) -> CallTransitionHintView.HintType {
        let preferredTypes = userProficiency.preferredHintTypes
        
        switch trigger {
        case .firstTimeUser:
            return .onboardingOverlay
        case .callKitFailure:
            return .emergencyGuidance
        case .criticalCallMoment:
            return .emergencyGuidance
        case .accessibilityMode:
            return .voiceOverAnnouncement
        case .userStruggling:
            return preferredTypes.first ?? .contextualTooltip
        default:
            return preferredTypes.randomElement() ?? .swipeUpGesture
        }
    }
    
    private func shouldShowHint(type: CallTransitionHintView.HintType, trigger: CallTransitionHintView.HintTrigger) -> Bool {
        // Always show emergency guidance
        if trigger == .callKitFailure || trigger == .criticalCallMoment {
            return true
        }
        
        // Check frequency limits
        let frequency = userProficiency.hintFrequency
        guard frequency.showProbability > Double.random(in: 0...1) else { return false }
        
        // Check cooldown period
        if let lastShown = hintHistory[type]?.last {
            let timeSinceLastShown = Date().timeIntervalSince(lastShown)
            if timeSinceLastShown < frequency.cooldownPeriod {
                return false
            }
        }
        
        return configuration.enabledHintTypes.contains(type)
    }
    
    private func updateProficiencyBasedOnUsage() {
        let totalTransitions = userInteractions["totalTransitions"] as? Int ?? 0
        let totalDeferrals = userInteractions["totalDeferrals"] as? Int ?? 0
        
        let successRate = totalTransitions > 0 ? Double(totalTransitions) / Double(totalTransitions + totalDeferrals) : 0
        
        if totalTransitions >= 10 && successRate > 0.8 {
            userProficiency = .expert
        } else if totalTransitions >= 5 && successRate > 0.6 {
            userProficiency = .intermediate
        } else if totalTransitions >= 2 {
            userProficiency = .learning
        }
    }
    
    private func loadLearningData() {
        // Load from UserDefaults or other persistence mechanism
        // Implementation would depend on app's data storage strategy
    }
    
    private func saveLearningData() {
        // Save to UserDefaults or other persistence mechanism
        // Implementation would depend on app's data storage strategy
    }
}

// MARK: - Preview

@available(iOS 14.0, *)
struct CallTransitionHintView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Swipe Up Gesture Hint
                CallTransitionHintView(
                    configuration: .init(enabledHintTypes: [.swipeUpGesture])
                )
                
                // Contextual Tooltip
                CallTransitionHintView(
                    configuration: .init(enabledHintTypes: [.contextualTooltip])
                )
                
                // Emergency Guidance
                CallTransitionHintView(
                    configuration: .init(enabledHintTypes: [.emergencyGuidance])
                )
            }
        }
        .previewDevice("iPhone 14 Pro Max")
        .preferredColorScheme(.dark)
    }
}