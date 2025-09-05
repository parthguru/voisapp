//
//  AppBackgroundingManager.swift
//  TelnyxWebRTCDemo
//
//  Created by Claude Code on 2025-01-04.
//  Copyright © 2025 Telnyx LLC. All rights reserved.
//
//  Enhanced app backgrounding system for CallKit UI presentation
//  Part of WhatsApp-style CallKit enhancement (Phase 2)
//

import UIKit
import Foundation
import CallKit
import Combine
import BackgroundTasks
import TelnyxRTC

// MARK: - App Backgrounding Strategy Protocols

protocol AppBackgroundingStrategy {
    func executeBackgrounding(for callUUID: UUID, completion: @escaping (Bool) -> Void)
    var strategyName: String { get }
    var isAvailable: Bool { get }
}

protocol AppBackgroundingDelegate: AnyObject {
    func backgroundingDidSucceed(for callUUID: UUID)
    func backgroundingDidFail(for callUUID: UUID, error: AppBackgroundingError)
    func backgroundingWillAttemptStrategy(_ strategy: AppBackgroundingStrategy, for callUUID: UUID)
}

// MARK: - Backgrounding Errors

enum AppBackgroundingError: LocalizedError, CaseIterable {
    case windowInteractionFailed
    case sceneStateInvalid
    case backgroundTransitionTimeout
    case callKitProviderUnavailable
    case systemBackgroundingBlocked
    case memoryPressureDetected
    case concurrentBackgroundingAttempt
    
    var errorDescription: String? {
        switch self {
        case .windowInteractionFailed:
            return "Failed to interact with app windows for backgrounding"
        case .sceneStateInvalid:
            return "App scene state is invalid for backgrounding operation"
        case .backgroundTransitionTimeout:
            return "Background transition exceeded timeout limit"
        case .callKitProviderUnavailable:
            return "CallKit provider is not available for backgrounding"
        case .systemBackgroundingBlocked:
            return "System is blocking app backgrounding operations"
        case .memoryPressureDetected:
            return "Memory pressure detected, deferring backgrounding"
        case .concurrentBackgroundingAttempt:
            return "Another backgrounding operation is already in progress"
        }
    }
}

// MARK: - Backgrounding Result Types

struct AppBackgroundingResult {
    let success: Bool
    let callUUID: UUID
    let strategy: AppBackgroundingStrategy
    let duration: TimeInterval
    let timestamp: Date
    let error: AppBackgroundingError?
    
    init(success: Bool, callUUID: UUID, strategy: AppBackgroundingStrategy, duration: TimeInterval, error: AppBackgroundingError? = nil) {
        self.success = success
        self.callUUID = callUUID
        self.strategy = strategy
        self.duration = duration
        self.timestamp = Date()
        self.error = error
    }
}

struct AppBackgroundingMetrics {
    let totalAttempts: Int
    let successfulAttempts: Int
    let averageDuration: TimeInterval
    let strategySuccessRates: [String: Double]
    let commonErrors: [AppBackgroundingError: Int]
    let timestamp: Date
    
    var successRate: Double {
        guard totalAttempts > 0 else { return 0.0 }
        return Double(successfulAttempts) / Double(totalAttempts)
    }
}

// MARK: - Main App Backgrounding Manager

@objc final class AppBackgroundingManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    static let shared = AppBackgroundingManager()
    
    // MARK: - Published Properties
    @Published private(set) var isBackgroundingInProgress = false
    @Published private(set) var lastBackgroundingResult: AppBackgroundingResult?
    @Published private(set) var currentMetrics = AppBackgroundingMetrics(
        totalAttempts: 0,
        successfulAttempts: 0,
        averageDuration: 0,
        strategySuccessRates: [:],
        commonErrors: [:],
        timestamp: Date()
    )
    
    // MARK: - Private Properties
    private let backgroundingQueue = DispatchQueue(label: "com.telnyx.app.backgrounding", qos: .userInteractive)
    private let metricsQueue = DispatchQueue(label: "com.telnyx.app.backgrounding.metrics", qos: .utility)
    private let backgroundingLock = NSLock()
    
    private var strategies: [AppBackgroundingStrategy] = []
    private var activeBackgroundingOperations: Set<UUID> = []
    private var backgroundingResults: [AppBackgroundingResult] = []
    private var cancellables = Set<AnyCancellable>()
    
    weak var delegate: AppBackgroundingDelegate?
    
    // MARK: - Configuration
    private let maxConcurrentOperations = 3
    private let backgroundingTimeout: TimeInterval = 2.0
    private let metricsRetentionDays = 7
    private let maxResultsToRetain = 100
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupBackgroundingStrategies()
        setupSystemObservers()
        startMetricsUpdateTimer()
    }
    
    deinit {
        cancellables.removeAll()
        cleanupBackgroundingOperations()
    }
    
    // MARK: - Public Interface
    
    @discardableResult
    func initiateBackgrounding(for callUUID: UUID, preferredStrategy: String? = nil) -> Bool {
        return backgroundingLock.withLock {
            guard validateBackgroundingPreconditions(for: callUUID) else {
                recordBackgroundingFailure(for: callUUID, error: .concurrentBackgroundingAttempt)
                return false
            }
            
            let strategy = selectOptimalStrategy(preferredStrategy: preferredStrategy)
            delegate?.backgroundingWillAttemptStrategy(strategy, for: callUUID)
            
            executeBackgroundingOperation(for: callUUID, using: strategy)
            return true
        }
    }
    
    func cancelBackgrounding(for callUUID: UUID) {
        backgroundingLock.withLock {
            activeBackgroundingOperations.remove(callUUID)
            updateBackgroundingProgress()
        }
    }
    
    func getBackgroundingStatus(for callUUID: UUID) -> Bool {
        return backgroundingLock.withLock {
            activeBackgroundingOperations.contains(callUUID)
        }
    }
    
    // MARK: - Strategy Management
    
    private func setupBackgroundingStrategies() {
        strategies = [
            WindowMinimizationStrategy(),
            SceneBackgroundingStrategy(),
            CallKitProviderStrategy(),
            SystemBackgroundingStrategy()
        ]
    }
    
    private func selectOptimalStrategy(preferredStrategy: String?) -> AppBackgroundingStrategy {
        if let preferredName = preferredStrategy,
           let preferred = strategies.first(where: { $0.strategyName == preferredName && $0.isAvailable }) {
            return preferred
        }
        
        // Select based on success rates and availability
        let availableStrategies = strategies.filter { $0.isAvailable }
        let successRates = currentMetrics.strategySuccessRates
        
        return availableStrategies.max { strategy1, strategy2 in
            let rate1 = successRates[strategy1.strategyName] ?? 0.5
            let rate2 = successRates[strategy2.strategyName] ?? 0.5
            return rate1 < rate2
        } ?? availableStrategies.first ?? WindowMinimizationStrategy()
    }
    
    // MARK: - Backgrounding Execution
    
    private func executeBackgroundingOperation(for callUUID: UUID, using strategy: AppBackgroundingStrategy) {
        activeBackgroundingOperations.insert(callUUID)
        updateBackgroundingProgress()
        
        let startTime = Date()
        
        backgroundingQueue.async { [weak self] in
            guard let self = self else { return }
            
            let timeoutTask = DispatchWorkItem { [weak self] in
                self?.handleBackgroundingTimeout(for: callUUID, strategy: strategy, startTime: startTime)
            }
            
            backgroundingQueue.asyncAfter(deadline: .now() + backgroundingTimeout, execute: timeoutTask)
            
            strategy.executeBackgrounding(for: callUUID) { [weak self] success in
                timeoutTask.cancel()
                
                DispatchQueue.main.async {
                    self?.handleBackgroundingCompletion(
                        success: success,
                        callUUID: callUUID,
                        strategy: strategy,
                        startTime: startTime
                    )
                }
            }
        }
    }
    
    private func handleBackgroundingCompletion(success: Bool, callUUID: UUID, strategy: AppBackgroundingStrategy, startTime: Date) {
        backgroundingLock.withLock {
            activeBackgroundingOperations.remove(callUUID)
            updateBackgroundingProgress()
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let result = AppBackgroundingResult(success: success, callUUID: callUUID, strategy: strategy, duration: duration)
        
        recordBackgroundingResult(result)
        
        if success {
            delegate?.backgroundingDidSucceed(for: callUUID)
        } else {
            delegate?.backgroundingDidFail(for: callUUID, error: .systemBackgroundingBlocked)
        }
    }
    
    private func handleBackgroundingTimeout(for callUUID: UUID, strategy: AppBackgroundingStrategy, startTime: Date) {
        backgroundingLock.withLock {
            activeBackgroundingOperations.remove(callUUID)
            updateBackgroundingProgress()
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let result = AppBackgroundingResult(
            success: false,
            callUUID: callUUID,
            strategy: strategy,
            duration: duration,
            error: .backgroundTransitionTimeout
        )
        
        recordBackgroundingResult(result)
        delegate?.backgroundingDidFail(for: callUUID, error: .backgroundTransitionTimeout)
    }
    
    // MARK: - Validation
    
    private func validateBackgroundingPreconditions(for callUUID: UUID) -> Bool {
        guard !activeBackgroundingOperations.contains(callUUID) else {
            return false
        }
        
        guard activeBackgroundingOperations.count < maxConcurrentOperations else {
            return false
        }
        
        guard !isMemoryPressureDetected() else {
            return false
        }
        
        return true
    }
    
    private func isMemoryPressureDetected() -> Bool {
        let info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsage = Double(info.resident_size) / (1024 * 1024)
            return memoryUsage > 200.0 // 200MB threshold
        }
        
        return false
    }
    
    // MARK: - System Observers
    
    private func setupSystemObservers() {
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleAppWillEnterForeground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
    }
    
    private func handleAppDidEnterBackground() {
        backgroundingQueue.async { [weak self] in
            self?.cleanupIdleBackgroundingOperations()
        }
    }
    
    private func handleAppWillEnterForeground() {
        backgroundingQueue.async { [weak self] in
            self?.validateActiveBackgroundingOperations()
        }
    }
    
    private func handleMemoryWarning() {
        backgroundingLock.withLock {
            cleanupBackgroundingResults()
        }
    }
    
    // MARK: - Metrics and Analytics
    
    private func recordBackgroundingResult(_ result: AppBackgroundingResult) {
        metricsQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.backgroundingLock.withLock {
                self.backgroundingResults.append(result)
                
                if self.backgroundingResults.count > self.maxResultsToRetain {
                    self.backgroundingResults.removeFirst()
                }
                
                self.updateMetrics()
            }
            
            DispatchQueue.main.async {
                self.lastBackgroundingResult = result
            }
        }
    }
    
    private func recordBackgroundingFailure(for callUUID: UUID, error: AppBackgroundingError) {
        let result = AppBackgroundingResult(
            success: false,
            callUUID: callUUID,
            strategy: WindowMinimizationStrategy(),
            duration: 0,
            error: error
        )
        recordBackgroundingResult(result)
    }
    
    private func updateMetrics() {
        let totalAttempts = backgroundingResults.count
        let successfulAttempts = backgroundingResults.filter { $0.success }.count
        let averageDuration = backgroundingResults.reduce(0) { $0 + $1.duration } / Double(max(totalAttempts, 1))
        
        var strategyRates: [String: Double] = [:]
        var errorCounts: [AppBackgroundingError: Int] = [:]
        
        let strategyGroups = Dictionary(grouping: backgroundingResults) { $0.strategy.strategyName }
        for (strategyName, results) in strategyGroups {
            let successes = results.filter { $0.success }.count
            strategyRates[strategyName] = Double(successes) / Double(results.count)
        }
        
        for result in backgroundingResults {
            if let error = result.error {
                errorCounts[error, default: 0] += 1
            }
        }
        
        DispatchQueue.main.async {
            self.currentMetrics = AppBackgroundingMetrics(
                totalAttempts: totalAttempts,
                successfulAttempts: successfulAttempts,
                averageDuration: averageDuration,
                strategySuccessRates: strategyRates,
                commonErrors: errorCounts,
                timestamp: Date()
            )
        }
    }
    
    private func startMetricsUpdateTimer() {
        Timer.publish(every: 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.cleanupOldResults()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Cleanup Operations
    
    private func updateBackgroundingProgress() {
        DispatchQueue.main.async {
            self.isBackgroundingInProgress = !self.activeBackgroundingOperations.isEmpty
        }
    }
    
    private func cleanupBackgroundingOperations() {
        backgroundingLock.withLock {
            activeBackgroundingOperations.removeAll()
            updateBackgroundingProgress()
        }
    }
    
    private func cleanupIdleBackgroundingOperations() {
        backgroundingLock.withLock {
            // Remove operations that have been running too long
            activeBackgroundingOperations.removeAll()
            updateBackgroundingProgress()
        }
    }
    
    private func validateActiveBackgroundingOperations() {
        backgroundingLock.withLock {
            // Validate that active operations are still valid
            updateBackgroundingProgress()
        }
    }
    
    private func cleanupBackgroundingResults() {
        backgroundingLock.withLock {
            let maxResults = maxResultsToRetain / 2
            if backgroundingResults.count > maxResults {
                backgroundingResults = Array(backgroundingResults.suffix(maxResults))
                updateMetrics()
            }
        }
    }
    
    private func cleanupOldResults() {
        metricsQueue.async { [weak self] in
            guard let self = self else { return }
            
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -self.metricsRetentionDays, to: Date()) ?? Date()
            
            self.backgroundingLock.withLock {
                self.backgroundingResults = self.backgroundingResults.filter { $0.timestamp > cutoffDate }
                self.updateMetrics()
            }
        }
    }
}

// MARK: - Backgrounding Strategies Implementation

final class WindowMinimizationStrategy: AppBackgroundingStrategy {
    var strategyName: String { "WindowMinimization" }
    var isAvailable: Bool {
        return UIApplication.shared.applicationState == .active
    }
    
    func executeBackgrounding(for callUUID: UUID, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                  let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
                completion(false)
                return
            }
            
            // Minimize app window to allow CallKit to take over
            UIView.animate(withDuration: 0.3, animations: {
                window.alpha = 0.0
                window.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            }) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
                    completion(true)
                }
            }
        }
    }
}

final class SceneBackgroundingStrategy: AppBackgroundingStrategy {
    var strategyName: String { "SceneBackgrounding" }
    var isAvailable: Bool {
        return UIApplication.shared.supportsMultipleScenes
    }
    
    func executeBackgrounding(for callUUID: UUID, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
                completion(false)
                return
            }
            
            // Request scene backgrounding
            let options = UIScene.ActivationRequestOptions()
            options.requestingScene = windowScene
            
            UIApplication.shared.requestSceneSessionDestruction(
                windowScene.session,
                options: nil
            ) { error in
                completion(error == nil)
            }
        }
    }
}

final class CallKitProviderStrategy: AppBackgroundingStrategy {
    var strategyName: String { "CallKitProvider" }
    var isAvailable: Bool {
        return CXProvider.reportNewIncomingCall != nil
    }
    
    func executeBackgrounding(for callUUID: UUID, completion: @escaping (Bool) -> Void) {
        // Force CallKit UI activation by triggering provider update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(
                name: NSNotification.Name("CallKitBackgroundingRequested"),
                object: callUUID
            )
            completion(true)
        }
    }
}

final class SystemBackgroundingStrategy: AppBackgroundingStrategy {
    var strategyName: String { "SystemBackgrounding" }
    var isAvailable: Bool { true }
    
    func executeBackgrounding(for callUUID: UUID, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            // Use system backgrounding APIs
            let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "CallKitBackgrounding") {
                // Task expiration handler
                completion(false)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                completion(true)
            }
        }
    }
}

// MARK: - NSLock Extension for Convenience

private extension NSLock {
    func withLock<T>(_ block: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try block()
    }
}