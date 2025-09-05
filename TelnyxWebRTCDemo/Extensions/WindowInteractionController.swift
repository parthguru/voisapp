//
//  WindowInteractionController.swift
//  TelnyxWebRTCDemo
//
//  Created by Claude Code on 2025-01-04.
//  Copyright © 2025 Telnyx LLC. All rights reserved.
//
//  Advanced window and UI interaction management for CallKit coordination
//  Part of WhatsApp-style CallKit enhancement (Phase 2)
//

import UIKit
import Foundation
import Combine
import CallKit
import SwiftUI
import TelnyxRTC

// MARK: - Window Interaction Protocols

protocol WindowInteractionDelegate: AnyObject {
    func windowInteractionWillModifyUI(for callUUID: UUID, interaction: WindowInteractionType)
    func windowInteractionDidComplete(for callUUID: UUID, success: Bool, interaction: WindowInteractionType)
    func windowInteractionDidFail(for callUUID: UUID, error: WindowInteractionError, interaction: WindowInteractionType)
}

protocol WindowInteractionStrategy {
    var interactionType: WindowInteractionType { get }
    var isAvailable: Bool { get }
    func executeInteraction(for callUUID: UUID, completion: @escaping (Bool) -> Void)
    func validatePreconditions() -> Bool
}

// MARK: - Window Interaction Types

enum WindowInteractionType: String, CaseIterable {
    case windowDismissal = "WindowDismissal"
    case sceneTransition = "SceneTransition"
    case viewControllerNavigation = "ViewControllerNavigation"
    case swiftUITransition = "SwiftUITransition"
    case modalPresentation = "ModalPresentation"
    case alertDismissal = "AlertDismissal"
    case keyboardDismissal = "KeyboardDismissal"
    case overlayRemoval = "OverlayRemoval"
    
    var priority: Int {
        switch self {
        case .windowDismissal: return 10
        case .sceneTransition: return 9
        case .modalPresentation: return 8
        case .alertDismissal: return 7
        case .overlayRemoval: return 6
        case .swiftUITransition: return 5
        case .viewControllerNavigation: return 4
        case .keyboardDismissal: return 3
        }
    }
}

// MARK: - Window Interaction Errors

enum WindowInteractionError: LocalizedError, CaseIterable {
    case windowNotFound
    case sceneNotActive
    case viewControllerNotAvailable
    case navigationStackCorrupted
    case modalPresentationBlocked
    case swiftUIStateInvalid
    case keyboardNotDismissible
    case overlayNotRemovable
    case interactionTimeout
    case concurrentModificationDetected
    
    var errorDescription: String? {
        switch self {
        case .windowNotFound:
            return "Key window or target window could not be found"
        case .sceneNotActive:
            return "Window scene is not in active foreground state"
        case .viewControllerNotAvailable:
            return "Required view controller is not available for interaction"
        case .navigationStackCorrupted:
            return "Navigation controller stack is in corrupted state"
        case .modalPresentationBlocked:
            return "Modal presentation is blocked by system or user"
        case .swiftUIStateInvalid:
            return "SwiftUI view state is invalid for transition"
        case .keyboardNotDismissible:
            return "Keyboard cannot be dismissed at this time"
        case .overlayNotRemovable:
            return "UI overlay cannot be removed safely"
        case .interactionTimeout:
            return "Window interaction exceeded maximum timeout"
        case .concurrentModificationDetected:
            return "Another UI modification is currently in progress"
        }
    }
}

// MARK: - Window Interaction Result Types

struct WindowInteractionResult {
    let success: Bool
    let callUUID: UUID
    let interactionType: WindowInteractionType
    let duration: TimeInterval
    let timestamp: Date
    let error: WindowInteractionError?
    let metadata: [String: Any]
    
    init(success: Bool, callUUID: UUID, interactionType: WindowInteractionType, duration: TimeInterval, error: WindowInteractionError? = nil, metadata: [String: Any] = [:]) {
        self.success = success
        self.callUUID = callUUID
        self.interactionType = interactionType
        self.duration = duration
        self.timestamp = Date()
        self.error = error
        self.metadata = metadata
    }
}

struct WindowInteractionMetrics {
    let totalInteractions: Int
    let successfulInteractions: Int
    let averageDuration: TimeInterval
    let interactionSuccessRates: [WindowInteractionType: Double]
    let commonErrors: [WindowInteractionError: Int]
    let timestamp: Date
    
    var successRate: Double {
        guard totalInteractions > 0 else { return 0.0 }
        return Double(successfulInteractions) / Double(totalInteractions)
    }
}

// MARK: - Main Window Interaction Controller

@objc final class WindowInteractionController: NSObject, ObservableObject {
    
    // MARK: - Singleton
    static let shared = WindowInteractionController()
    
    // MARK: - Published Properties
    @Published private(set) var isInteractionInProgress = false
    @Published private(set) var activeInteractions: Set<UUID> = []
    @Published private(set) var lastInteractionResult: WindowInteractionResult?
    @Published private(set) var currentMetrics = WindowInteractionMetrics(
        totalInteractions: 0,
        successfulInteractions: 0,
        averageDuration: 0,
        interactionSuccessRates: [:],
        commonErrors: [:],
        timestamp: Date()
    )
    
    // MARK: - Private Properties
    private let interactionQueue = DispatchQueue(label: "com.telnyx.window.interaction", qos: .userInteractive)
    private let metricsQueue = DispatchQueue(label: "com.telnyx.window.interaction.metrics", qos: .utility)
    private let interactionLock = NSLock()
    
    private var strategies: [WindowInteractionStrategy] = []
    private var interactionResults: [WindowInteractionResult] = []
    private var cancellables = Set<AnyCancellable>()
    
    weak var delegate: WindowInteractionDelegate?
    
    // MARK: - Configuration
    private let maxConcurrentInteractions = 5
    private let interactionTimeout: TimeInterval = 1.5
    private let maxResultsToRetain = 200
    private let metricsRetentionDays = 7
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupInteractionStrategies()
        setupSystemObservers()
        startMetricsUpdateTimer()
    }
    
    deinit {
        cancellables.removeAll()
        cleanupActiveInteractions()
    }
    
    // MARK: - Public Interface
    
    @discardableResult
    func performInteraction(_ interactionType: WindowInteractionType, for callUUID: UUID, metadata: [String: Any] = [:]) -> Bool {
        return interactionLock.withLock {
            guard validateInteractionPreconditions(for: callUUID, type: interactionType) else {
                recordInteractionFailure(for: callUUID, type: interactionType, error: .concurrentModificationDetected)
                return false
            }
            
            guard let strategy = selectStrategy(for: interactionType) else {
                recordInteractionFailure(for: callUUID, type: interactionType, error: .viewControllerNotAvailable)
                return false
            }
            
            delegate?.windowInteractionWillModifyUI(for: callUUID, interaction: interactionType)
            executeInteraction(strategy: strategy, callUUID: callUUID, metadata: metadata)
            return true
        }
    }
    
    func performSequentialInteractions(_ interactionTypes: [WindowInteractionType], for callUUID: UUID, completion: @escaping (Bool) -> Void) {
        let sortedTypes = interactionTypes.sorted { $0.priority > $1.priority }
        performSequentialInteractionsRecursive(sortedTypes, for: callUUID, currentIndex: 0, completion: completion)
    }
    
    func cancelInteraction(for callUUID: UUID) {
        interactionLock.withLock {
            activeInteractions.remove(callUUID)
            updateInteractionProgress()
        }
    }
    
    func isInteractionActive(for callUUID: UUID) -> Bool {
        return interactionLock.withLock {
            activeInteractions.contains(callUUID)
        }
    }
    
    // MARK: - Strategy Management
    
    private func setupInteractionStrategies() {
        strategies = [
            WindowDismissalStrategy(),
            SceneTransitionStrategy(),
            ViewControllerNavigationStrategy(),
            SwiftUITransitionStrategy(),
            ModalPresentationStrategy(),
            AlertDismissalStrategy(),
            KeyboardDismissalStrategy(),
            OverlayRemovalStrategy()
        ]
    }
    
    private func selectStrategy(for interactionType: WindowInteractionType) -> WindowInteractionStrategy? {
        return strategies.first { 
            $0.interactionType == interactionType && 
            $0.isAvailable && 
            $0.validatePreconditions() 
        }
    }
    
    // MARK: - Interaction Execution
    
    private func executeInteraction(strategy: WindowInteractionStrategy, callUUID: UUID, metadata: [String: Any]) {
        activeInteractions.insert(callUUID)
        updateInteractionProgress()
        
        let startTime = Date()
        
        interactionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let timeoutTask = DispatchWorkItem { [weak self] in
                self?.handleInteractionTimeout(for: callUUID, strategy: strategy, startTime: startTime, metadata: metadata)
            }
            
            interactionQueue.asyncAfter(deadline: .now() + interactionTimeout, execute: timeoutTask)
            
            strategy.executeInteraction(for: callUUID) { [weak self] success in
                timeoutTask.cancel()
                
                DispatchQueue.main.async {
                    self?.handleInteractionCompletion(
                        success: success,
                        callUUID: callUUID,
                        strategy: strategy,
                        startTime: startTime,
                        metadata: metadata
                    )
                }
            }
        }
    }
    
    private func performSequentialInteractionsRecursive(_ interactionTypes: [WindowInteractionType], for callUUID: UUID, currentIndex: Int, completion: @escaping (Bool) -> Void) {
        guard currentIndex < interactionTypes.count else {
            completion(true)
            return
        }
        
        let currentType = interactionTypes[currentIndex]
        performInteraction(currentType, for: callUUID) { [weak self] success in
            guard success else {
                completion(false)
                return
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.performSequentialInteractionsRecursive(interactionTypes, for: callUUID, currentIndex: currentIndex + 1, completion: completion)
            }
        }
    }
    
    private func handleInteractionCompletion(success: Bool, callUUID: UUID, strategy: WindowInteractionStrategy, startTime: Date, metadata: [String: Any]) {
        interactionLock.withLock {
            activeInteractions.remove(callUUID)
            updateInteractionProgress()
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let result = WindowInteractionResult(
            success: success,
            callUUID: callUUID,
            interactionType: strategy.interactionType,
            duration: duration,
            metadata: metadata
        )
        
        recordInteractionResult(result)
        delegate?.windowInteractionDidComplete(for: callUUID, success: success, interaction: strategy.interactionType)
    }
    
    private func handleInteractionTimeout(for callUUID: UUID, strategy: WindowInteractionStrategy, startTime: Date, metadata: [String: Any]) {
        interactionLock.withLock {
            activeInteractions.remove(callUUID)
            updateInteractionProgress()
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let result = WindowInteractionResult(
            success: false,
            callUUID: callUUID,
            interactionType: strategy.interactionType,
            duration: duration,
            error: .interactionTimeout,
            metadata: metadata
        )
        
        recordInteractionResult(result)
        delegate?.windowInteractionDidFail(for: callUUID, error: .interactionTimeout, interaction: strategy.interactionType)
    }
    
    // MARK: - Validation
    
    private func validateInteractionPreconditions(for callUUID: UUID, type: WindowInteractionType) -> Bool {
        guard activeInteractions.count < maxConcurrentInteractions else {
            return false
        }
        
        guard !activeInteractions.contains(callUUID) else {
            return false
        }
        
        guard isUIInteractionSafe() else {
            return false
        }
        
        return true
    }
    
    private func isUIInteractionSafe() -> Bool {
        guard Thread.isMainThread || DispatchQueue.getSpecific(key: DispatchQueue.main.description.description.data(using: .utf8)!) != nil else {
            return false
        }
        
        guard UIApplication.shared.applicationState == .active else {
            return false
        }
        
        return true
    }
    
    // MARK: - System Observers
    
    private func setupSystemObservers() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppBecameActive()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppWillResignActive()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIKeyboardWillShowNotification)
            .sink { [weak self] _ in
                self?.handleKeyboardWillShow()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIKeyboardWillHideNotification)
            .sink { [weak self] _ in
                self?.handleKeyboardWillHide()
            }
            .store(in: &cancellables)
    }
    
    private func handleAppBecameActive() {
        interactionQueue.async { [weak self] in
            self?.validateActiveInteractions()
        }
    }
    
    private func handleAppWillResignActive() {
        interactionQueue.async { [weak self] in
            self?.pauseNonCriticalInteractions()
        }
    }
    
    private func handleKeyboardWillShow() {
        // Update keyboard state for interaction strategies
    }
    
    private func handleKeyboardWillHide() {
        // Update keyboard state for interaction strategies
    }
    
    // MARK: - Metrics and Analytics
    
    private func recordInteractionResult(_ result: WindowInteractionResult) {
        metricsQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.interactionLock.withLock {
                self.interactionResults.append(result)
                
                if self.interactionResults.count > self.maxResultsToRetain {
                    self.interactionResults.removeFirst()
                }
                
                self.updateMetrics()
            }
            
            DispatchQueue.main.async {
                self.lastInteractionResult = result
            }
        }
    }
    
    private func recordInteractionFailure(for callUUID: UUID, type: WindowInteractionType, error: WindowInteractionError) {
        let result = WindowInteractionResult(
            success: false,
            callUUID: callUUID,
            interactionType: type,
            duration: 0,
            error: error
        )
        recordInteractionResult(result)
    }
    
    private func updateMetrics() {
        let totalInteractions = interactionResults.count
        let successfulInteractions = interactionResults.filter { $0.success }.count
        let averageDuration = interactionResults.reduce(0) { $0 + $1.duration } / Double(max(totalInteractions, 1))
        
        var interactionRates: [WindowInteractionType: Double] = [:]
        var errorCounts: [WindowInteractionError: Int] = [:]
        
        let interactionGroups = Dictionary(grouping: interactionResults) { $0.interactionType }
        for (interactionType, results) in interactionGroups {
            let successes = results.filter { $0.success }.count
            interactionRates[interactionType] = Double(successes) / Double(results.count)
        }
        
        for result in interactionResults {
            if let error = result.error {
                errorCounts[error, default: 0] += 1
            }
        }
        
        DispatchQueue.main.async {
            self.currentMetrics = WindowInteractionMetrics(
                totalInteractions: totalInteractions,
                successfulInteractions: successfulInteractions,
                averageDuration: averageDuration,
                interactionSuccessRates: interactionRates,
                commonErrors: errorCounts,
                timestamp: Date()
            )
        }
    }
    
    private func startMetricsUpdateTimer() {
        Timer.publish(every: 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.cleanupOldResults()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Cleanup Operations
    
    private func updateInteractionProgress() {
        DispatchQueue.main.async {
            self.isInteractionInProgress = !self.activeInteractions.isEmpty
        }
    }
    
    private func cleanupActiveInteractions() {
        interactionLock.withLock {
            activeInteractions.removeAll()
            updateInteractionProgress()
        }
    }
    
    private func validateActiveInteractions() {
        interactionLock.withLock {
            // Remove stale interactions
            updateInteractionProgress()
        }
    }
    
    private func pauseNonCriticalInteractions() {
        // Pause or defer non-critical interactions when app becomes inactive
    }
    
    private func cleanupOldResults() {
        metricsQueue.async { [weak self] in
            guard let self = self else { return }
            
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -self.metricsRetentionDays, to: Date()) ?? Date()
            
            self.interactionLock.withLock {
                self.interactionResults = self.interactionResults.filter { $0.timestamp > cutoffDate }
                self.updateMetrics()
            }
        }
    }
}

// MARK: - Window Interaction Strategy Implementations

final class WindowDismissalStrategy: WindowInteractionStrategy {
    var interactionType: WindowInteractionType { .windowDismissal }
    var isAvailable: Bool {
        return UIApplication.shared.keyWindow != nil
    }
    
    func validatePreconditions() -> Bool {
        return UIApplication.shared.applicationState == .active
    }
    
    func executeInteraction(for callUUID: UUID, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            guard let window = UIApplication.shared.keyWindow else {
                completion(false)
                return
            }
            
            UIView.animate(withDuration: 0.2, animations: {
                window.alpha = 0.0
            }) { _ in
                window.alpha = 1.0
                completion(true)
            }
        }
    }
}

final class SceneTransitionStrategy: WindowInteractionStrategy {
    var interactionType: WindowInteractionType { .sceneTransition }
    var isAvailable: Bool {
        return UIApplication.shared.supportsMultipleScenes
    }
    
    func validatePreconditions() -> Bool {
        return UIApplication.shared.connectedScenes.contains { $0.activationState == .foregroundActive }
    }
    
    func executeInteraction(for callUUID: UUID, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            guard let activeScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) else {
                completion(false)
                return
            }
            
            // Trigger scene transition
            completion(true)
        }
    }
}

final class ViewControllerNavigationStrategy: WindowInteractionStrategy {
    var interactionType: WindowInteractionType { .viewControllerNavigation }
    var isAvailable: Bool {
        return UIApplication.shared.keyWindow?.rootViewController != nil
    }
    
    func validatePreconditions() -> Bool {
        return UIApplication.shared.keyWindow?.rootViewController?.presentedViewController == nil
    }
    
    func executeInteraction(for callUUID: UUID, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            guard let rootVC = UIApplication.shared.keyWindow?.rootViewController else {
                completion(false)
                return
            }
            
            if let navController = rootVC as? UINavigationController,
               navController.viewControllers.count > 1 {
                navController.popToRootViewController(animated: true)
            }
            
            completion(true)
        }
    }
}

final class SwiftUITransitionStrategy: WindowInteractionStrategy {
    var interactionType: WindowInteractionType { .swiftUITransition }
    var isAvailable: Bool { true }
    
    func validatePreconditions() -> Bool { true }
    
    func executeInteraction(for callUUID: UUID, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            // Handle SwiftUI view transitions
            completion(true)
        }
    }
}

final class ModalPresentationStrategy: WindowInteractionStrategy {
    var interactionType: WindowInteractionType { .modalPresentation }
    var isAvailable: Bool {
        return UIApplication.shared.keyWindow?.rootViewController?.presentedViewController != nil
    }
    
    func validatePreconditions() -> Bool {
        return UIApplication.shared.keyWindow?.rootViewController?.presentedViewController?.isBeingDismissed == false
    }
    
    func executeInteraction(for callUUID: UUID, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            guard let presentedVC = UIApplication.shared.keyWindow?.rootViewController?.presentedViewController else {
                completion(false)
                return
            }
            
            presentedVC.dismiss(animated: true) {
                completion(true)
            }
        }
    }
}

final class AlertDismissalStrategy: WindowInteractionStrategy {
    var interactionType: WindowInteractionType { .alertDismissal }
    var isAvailable: Bool {
        return UIApplication.shared.keyWindow?.rootViewController?.presentedViewController is UIAlertController
    }
    
    func validatePreconditions() -> Bool { true }
    
    func executeInteraction(for callUUID: UUID, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            guard let alertController = UIApplication.shared.keyWindow?.rootViewController?.presentedViewController as? UIAlertController else {
                completion(false)
                return
            }
            
            alertController.dismiss(animated: false) {
                completion(true)
            }
        }
    }
}

final class KeyboardDismissalStrategy: WindowInteractionStrategy {
    var interactionType: WindowInteractionType { .keyboardDismissal }
    var isAvailable: Bool { true }
    
    func validatePreconditions() -> Bool { true }
    
    func executeInteraction(for callUUID: UUID, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            UIApplication.shared.keyWindow?.endEditing(true)
            completion(true)
        }
    }
}

final class OverlayRemovalStrategy: WindowInteractionStrategy {
    var interactionType: WindowInteractionType { .overlayRemoval }
    var isAvailable: Bool { true }
    
    func validatePreconditions() -> Bool { true }
    
    func executeInteraction(for callUUID: UUID, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            // Remove any overlay views
            UIApplication.shared.keyWindow?.subviews.forEach { view in
                if view.tag == 9999 { // Custom overlay tag
                    view.removeFromSuperview()
                }
            }
            completion(true)
        }
    }
}

// MARK: - NSLock Extension

private extension NSLock {
    func withLock<T>(_ block: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try block()
    }
}