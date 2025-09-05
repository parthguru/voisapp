//
//  CallKitRetryManager.swift
//  TelnyxWebRTCDemo
//
//  Created by Claude Code on 2025-01-04.
//  Copyright © 2025 Telnyx LLC. All rights reserved.
//
//  Intelligent retry logic for CallKit detection failures
//  Part of WhatsApp-style CallKit enhancement (Phase 3)
//

import UIKit
import Foundation
import CallKit
import Combine
import TelnyxRTC

// MARK: - Retry Strategy Protocols

protocol CallKitRetryDelegate: AnyObject {
    func retryWillBegin(for callUUID: UUID, attempt: Int, strategy: CallRetryStrategyType)
    func retryDidComplete(for callUUID: UUID, success: Bool, attempt: Int, strategy: CallRetryStrategyType)
    func retryDidFail(for callUUID: UUID, error: CallKitRetryError, attempt: Int, strategy: CallRetryStrategyType)
    func retryDidExceedMaximumAttempts(for callUUID: UUID, finalStrategy: CallRetryStrategyType)
}

// MARK: - Retry Configuration

struct CallKitRetryConfiguration {
    let maxRetries: Int
    let initialDelay: TimeInterval
    let maxDelay: TimeInterval
    let backoffMultiplier: Double
    let jitterRange: ClosedRange<Double>
    let timeoutPerAttempt: TimeInterval
    let enableAdaptiveStrategy: Bool
    let prioritizeRecentlySuccessfulStrategies: Bool
    
    static let `default` = CallKitRetryConfiguration(
        maxRetries: 5,
        initialDelay: 0.5,
        maxDelay: 8.0,
        backoffMultiplier: 1.5,
        jitterRange: 0.8...1.2,
        timeoutPerAttempt: 3.0,
        enableAdaptiveStrategy: true,
        prioritizeRecentlySuccessfulStrategies: true
    )
    
    static let aggressive = CallKitRetryConfiguration(
        maxRetries: 8,
        initialDelay: 0.25,
        maxDelay: 5.0,
        backoffMultiplier: 1.3,
        jitterRange: 0.9...1.1,
        timeoutPerAttempt: 2.0,
        enableAdaptiveStrategy: true,
        prioritizeRecentlySuccessfulStrategies: true
    )
    
    static let conservative = CallKitRetryConfiguration(
        maxRetries: 3,
        initialDelay: 1.0,
        maxDelay: 10.0,
        backoffMultiplier: 2.0,
        jitterRange: 0.7...1.3,
        timeoutPerAttempt: 5.0,
        enableAdaptiveStrategy: false,
        prioritizeRecentlySuccessfulStrategies: false
    )
}

// MARK: - Retry Strategy Types

enum CallRetryStrategyType: String, CaseIterable {
    case immediate = "Immediate"
    case exponentialBackoff = "ExponentialBackoff"
    case linearBackoff = "LinearBackoff"
    case fixedInterval = "FixedInterval"
    case adaptive = "Adaptive"
    case circuitBreaker = "CircuitBreaker"
    
    var priority: Int {
        switch self {
        case .immediate: return 10
        case .exponentialBackoff: return 9
        case .adaptive: return 8
        case .linearBackoff: return 7
        case .fixedInterval: return 6
        case .circuitBreaker: return 5
        }
    }
}

// MARK: - Retry Errors

enum CallKitRetryError: LocalizedError, CaseIterable {
    case maxRetriesExceeded
    case retryTimeoutExceeded
    case circuitBreakerOpen
    case strategyNotAvailable
    case callUUIDNotFound
    case systemResourcesExhausted
    case backgroundingFailed
    case detectionFailed
    case concurrentRetryDetected
    case invalidRetryConfiguration
    
    var errorDescription: String? {
        switch self {
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded for CallKit detection"
        case .retryTimeoutExceeded:
            return "Retry operation exceeded timeout limit"
        case .circuitBreakerOpen:
            return "Circuit breaker is open, temporarily suspending retries"
        case .strategyNotAvailable:
            return "Selected retry strategy is not available"
        case .callUUIDNotFound:
            return "Call UUID not found in active retry operations"
        case .systemResourcesExhausted:
            return "System resources are exhausted, cannot perform retry"
        case .backgroundingFailed:
            return "App backgrounding failed during retry operation"
        case .detectionFailed:
            return "CallKit detection failed during retry attempt"
        case .concurrentRetryDetected:
            return "Another retry operation is already in progress for this call"
        case .invalidRetryConfiguration:
            return "Retry configuration contains invalid parameters"
        }
    }
}

// MARK: - Retry Result Types

struct CallKitRetryResult {
    let success: Bool
    let callUUID: UUID
    let strategy: CallRetryStrategyType
    let attemptNumber: Int
    let totalDuration: TimeInterval
    let timestamp: Date
    let error: CallKitRetryError?
    let metadata: [String: Any]
    
    init(success: Bool, callUUID: UUID, strategy: CallRetryStrategyType, attemptNumber: Int, totalDuration: TimeInterval, error: CallKitRetryError? = nil, metadata: [String: Any] = [:]) {
        self.success = success
        self.callUUID = callUUID
        self.strategy = strategy
        self.attemptNumber = attemptNumber
        self.totalDuration = totalDuration
        self.timestamp = Date()
        self.error = error
        self.metadata = metadata
    }
}

struct CallKitRetryMetrics {
    let totalRetryOperations: Int
    let successfulRetries: Int
    let averageAttemptCount: Double
    let averageDuration: TimeInterval
    let strategySuccessRates: [CallRetryStrategyType: Double]
    let commonErrors: [CallKitRetryError: Int]
    let circuitBreakerStatus: CircuitBreakerState
    let timestamp: Date
    
    var successRate: Double {
        guard totalRetryOperations > 0 else { return 0.0 }
        return Double(successfulRetries) / Double(totalRetryOperations)
    }
}

// MARK: - Circuit Breaker State

enum CircuitBreakerState: String {
    case closed = "Closed"
    case open = "Open"
    case halfOpen = "HalfOpen"
}

struct CircuitBreakerMetrics {
    let failureCount: Int
    let consecutiveFailures: Int
    let lastFailureTime: Date?
    let state: CircuitBreakerState
    let recoveryTime: Date?
    
    var isOpen: Bool {
        return state == .open
    }
}

// MARK: - Active Retry Operation

final class ActiveRetryOperation {
    let callUUID: UUID
    let configuration: CallKitRetryConfiguration
    let startTime: Date
    var currentAttempt: Int = 0
    var currentStrategy: CallRetryStrategyType
    var lastError: CallKitRetryError?
    var isCompleted: Bool = false
    
    private var retryTimer: Timer?
    private let operationQueue = DispatchQueue(label: "com.telnyx.retry.operation", qos: .userInteractive)
    
    init(callUUID: UUID, configuration: CallKitRetryConfiguration, strategy: CallRetryStrategyType) {
        self.callUUID = callUUID
        self.configuration = configuration
        self.currentStrategy = strategy
        self.startTime = Date()
    }
    
    func calculateNextDelay() -> TimeInterval {
        let baseDelay: TimeInterval
        
        switch currentStrategy {
        case .immediate:
            baseDelay = 0
        case .exponentialBackoff:
            baseDelay = configuration.initialDelay * pow(configuration.backoffMultiplier, Double(currentAttempt - 1))
        case .linearBackoff:
            baseDelay = configuration.initialDelay * Double(currentAttempt)
        case .fixedInterval:
            baseDelay = configuration.initialDelay
        case .adaptive:
            baseDelay = min(configuration.initialDelay * pow(1.2, Double(currentAttempt - 1)), configuration.maxDelay)
        case .circuitBreaker:
            baseDelay = configuration.initialDelay * 2.0
        }
        
        let cappedDelay = min(baseDelay, configuration.maxDelay)
        let jitterMultiplier = Double.random(in: configuration.jitterRange)
        
        return cappedDelay * jitterMultiplier
    }
    
    func cleanup() {
        retryTimer?.invalidate()
        retryTimer = nil
        isCompleted = true
    }
    
    deinit {
        cleanup()
    }
}

// MARK: - Main CallKit Retry Manager

@objc final class CallKitRetryManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    static let shared = CallKitRetryManager()
    
    // MARK: - Published Properties
    @Published private(set) var activeRetryCount = 0
    @Published private(set) var lastRetryResult: CallKitRetryResult?
    @Published private(set) var currentMetrics = CallKitRetryMetrics(
        totalRetryOperations: 0,
        successfulRetries: 0,
        averageAttemptCount: 0,
        averageDuration: 0,
        strategySuccessRates: [:],
        commonErrors: [:],
        circuitBreakerStatus: .closed,
        timestamp: Date()
    )
    @Published private(set) var circuitBreakerMetrics = CircuitBreakerMetrics(
        failureCount: 0,
        consecutiveFailures: 0,
        lastFailureTime: nil,
        state: .closed,
        recoveryTime: nil
    )
    
    // MARK: - Private Properties
    private let retryQueue = DispatchQueue(label: "com.telnyx.callkit.retry", qos: .userInteractive)
    private let metricsQueue = DispatchQueue(label: "com.telnyx.callkit.retry.metrics", qos: .utility)
    private let retryLock = NSLock()
    
    private var activeOperations: [UUID: ActiveRetryOperation] = [:]
    private var retryResults: [CallKitRetryResult] = []
    private var strategySuccessHistory: [CallRetryStrategyType: [Bool]] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    weak var delegate: CallKitRetryDelegate?
    
    // MARK: - Configuration
    private var currentConfiguration = CallKitRetryConfiguration.default
    private let maxConcurrentRetries = 3
    private let maxResultsToRetain = 500
    private let metricsRetentionDays = 14
    
    // Circuit Breaker Properties
    private let circuitBreakerFailureThreshold = 5
    private let circuitBreakerRecoveryTimeout: TimeInterval = 30.0
    private var circuitBreakerConsecutiveFailures = 0
    private var circuitBreakerLastFailureTime: Date?
    private var circuitBreakerState: CircuitBreakerState = .closed
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupSystemObservers()
        startMetricsUpdateTimer()
        initializeStrategyHistory()
    }
    
    deinit {
        cancellables.removeAll()
        cleanupAllRetryOperations()
    }
    
    // MARK: - Public Interface
    
    @discardableResult
    func startRetry(for callUUID: UUID, preferredStrategy: CallRetryStrategyType? = nil, configuration: CallKitRetryConfiguration? = nil) -> Bool {
        return retryLock.withLock {
            guard validateRetryPreconditions(for: callUUID) else {
                recordRetryFailure(for: callUUID, error: .concurrentRetryDetected, strategy: .immediate, attempt: 0)
                return false
            }
            
            let config = configuration ?? currentConfiguration
            let strategy = selectOptimalStrategy(preferred: preferredStrategy, for: callUUID)
            
            let operation = ActiveRetryOperation(callUUID: callUUID, configuration: config, strategy: strategy)
            activeOperations[callUUID] = operation
            updateActiveRetryCount()
            
            executeRetryAttempt(operation: operation)
            return true
        }
    }
    
    func stopRetry(for callUUID: UUID) {
        retryLock.withLock {
            if let operation = activeOperations.removeValue(forKey: callUUID) {
                operation.cleanup()
                updateActiveRetryCount()
            }
        }
    }
    
    func updateConfiguration(_ configuration: CallKitRetryConfiguration) {
        retryLock.withLock {
            currentConfiguration = configuration
        }
    }
    
    func isRetryActive(for callUUID: UUID) -> Bool {
        return retryLock.withLock {
            activeOperations[callUUID] != nil
        }
    }
    
    func getRetryStatus(for callUUID: UUID) -> (attempt: Int, strategy: CallRetryStrategyType)? {
        return retryLock.withLock {
            guard let operation = activeOperations[callUUID] else { return nil }
            return (operation.currentAttempt, operation.currentStrategy)
        }
    }
    
    // MARK: - Strategy Management
    
    private func initializeStrategyHistory() {
        for strategy in CallRetryStrategyType.allCases {
            strategySuccessHistory[strategy] = []
        }
    }
    
    private func selectOptimalStrategy(preferred: CallRetryStrategyType?, for callUUID: UUID) -> CallRetryStrategyType {
        // Check circuit breaker
        if circuitBreakerState == .open {
            return .circuitBreaker
        }
        
        // Use preferred strategy if provided and available
        if let preferred = preferred {
            return preferred
        }
        
        // Adaptive strategy selection based on success rates
        if currentConfiguration.enableAdaptiveStrategy {
            return selectAdaptiveStrategy()
        }
        
        // Default to exponential backoff
        return .exponentialBackoff
    }
    
    private func selectAdaptiveStrategy() -> CallRetryStrategyType {
        guard currentConfiguration.prioritizeRecentlySuccessfulStrategies else {
            return .exponentialBackoff
        }
        
        let recentHistoryLimit = 20
        var bestStrategy: CallRetryStrategyType = .exponentialBackoff
        var bestSuccessRate: Double = 0.0
        
        for (strategy, history) in strategySuccessHistory {
            let recentHistory = history.suffix(recentHistoryLimit)
            guard !recentHistory.isEmpty else { continue }
            
            let successes = recentHistory.filter { $0 }.count
            let successRate = Double(successes) / Double(recentHistory.count)
            
            if successRate > bestSuccessRate {
                bestSuccessRate = successRate
                bestStrategy = strategy
            }
        }
        
        return bestStrategy
    }
    
    // MARK: - Retry Execution
    
    private func executeRetryAttempt(operation: ActiveRetryOperation) {
        retryQueue.async { [weak self] in
            guard let self = self else { return }
            
            operation.currentAttempt += 1
            
            // Check if we've exceeded max attempts
            guard operation.currentAttempt <= operation.configuration.maxRetries else {
                self.handleMaxRetriesExceeded(operation: operation)
                return
            }
            
            // Check circuit breaker
            if self.circuitBreakerState == .open && !self.isCircuitBreakerRecoveryReady() {
                self.handleCircuitBreakerOpen(operation: operation)
                return
            }
            
            // Notify delegate
            DispatchQueue.main.async {
                self.delegate?.retryWillBegin(for: operation.callUUID, attempt: operation.currentAttempt, strategy: operation.currentStrategy)
            }
            
            // Calculate delay for this attempt
            let delay = operation.calculateNextDelay()
            
            // Execute the retry attempt after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.performRetryAttempt(operation: operation)
            }
        }
    }
    
    private func performRetryAttempt(operation: ActiveRetryOperation) {
        let startTime = Date()
        
        // Simulate retry logic - in real implementation, this would call the detection manager
        let timeoutTask = DispatchWorkItem { [weak self] in
            self?.handleRetryTimeout(operation: operation, startTime: startTime)
        }
        
        retryQueue.asyncAfter(deadline: .now() + operation.configuration.timeoutPerAttempt, execute: timeoutTask)
        
        // Perform the actual retry operation
        performActualRetry(operation: operation) { [weak self] success in
            timeoutTask.cancel()
            
            let duration = Date().timeIntervalSince(startTime)
            
            DispatchQueue.main.async {
                self?.handleRetryCompletion(
                    operation: operation,
                    success: success,
                    duration: duration,
                    startTime: startTime
                )
            }
        }
    }
    
    private func performActualRetry(operation: ActiveRetryOperation, completion: @escaping (Bool) -> Void) {
        // In real implementation, this would:
        // 1. Trigger CallKit detection again
        // 2. Use AppBackgroundingManager to force app backgrounding
        // 3. Use WindowInteractionController to clear UI obstacles
        
        retryQueue.async {
            // Simulate actual retry logic
            let simulatedSuccess = self.simulateRetrySuccess(for: operation)
            completion(simulatedSuccess)
        }
    }
    
    private func simulateRetrySuccess(for operation: ActiveRetryOperation) -> Bool {
        // Simulate different success rates based on strategy and attempt number
        let baseSuccessRate: Double
        
        switch operation.currentStrategy {
        case .immediate:
            baseSuccessRate = 0.3
        case .exponentialBackoff:
            baseSuccessRate = 0.7
        case .linearBackoff:
            baseSuccessRate = 0.6
        case .fixedInterval:
            baseSuccessRate = 0.5
        case .adaptive:
            baseSuccessRate = 0.8
        case .circuitBreaker:
            baseSuccessRate = 0.4
        }
        
        // Decrease success rate with more attempts
        let attemptPenalty = Double(operation.currentAttempt - 1) * 0.1
        let adjustedSuccessRate = max(0.1, baseSuccessRate - attemptPenalty)
        
        return Double.random(in: 0...1) < adjustedSuccessRate
    }
    
    // MARK: - Retry Completion Handling
    
    private func handleRetryCompletion(operation: ActiveRetryOperation, success: Bool, duration: TimeInterval, startTime: Date) {
        if success {
            handleRetrySuccess(operation: operation, duration: duration)
        } else {
            handleRetryFailure(operation: operation, error: .detectionFailed, duration: duration)
        }
    }
    
    private func handleRetrySuccess(operation: ActiveRetryOperation, duration: TimeInterval) {
        retryLock.withLock {
            // Clean up the operation
            activeOperations.removeValue(forKey: operation.callUUID)
            operation.cleanup()
            updateActiveRetryCount()
            
            // Reset circuit breaker on success
            resetCircuitBreaker()
            
            // Record success in strategy history
            recordStrategyResult(strategy: operation.currentStrategy, success: true)
        }
        
        let totalDuration = Date().timeIntervalSince(operation.startTime)
        let result = CallKitRetryResult(
            success: true,
            callUUID: operation.callUUID,
            strategy: operation.currentStrategy,
            attemptNumber: operation.currentAttempt,
            totalDuration: totalDuration
        )
        
        recordRetryResult(result)
        delegate?.retryDidComplete(for: operation.callUUID, success: true, attempt: operation.currentAttempt, strategy: operation.currentStrategy)
    }
    
    private func handleRetryFailure(operation: ActiveRetryOperation, error: CallKitRetryError, duration: TimeInterval) {
        operation.lastError = error
        
        // Record failure in strategy history
        recordStrategyResult(strategy: operation.currentStrategy, success: false)
        
        // Update circuit breaker
        updateCircuitBreakerOnFailure()
        
        // Check if we should continue retrying
        if operation.currentAttempt < operation.configuration.maxRetries && circuitBreakerState != .open {
            // Continue with next attempt
            executeRetryAttempt(operation: operation)
        } else {
            // Final failure
            handleFinalRetryFailure(operation: operation, error: error)
        }
        
        delegate?.retryDidFail(for: operation.callUUID, error: error, attempt: operation.currentAttempt, strategy: operation.currentStrategy)
    }
    
    private func handleFinalRetryFailure(operation: ActiveRetryOperation, error: CallKitRetryError) {
        retryLock.withLock {
            activeOperations.removeValue(forKey: operation.callUUID)
            operation.cleanup()
            updateActiveRetryCount()
        }
        
        let totalDuration = Date().timeIntervalSince(operation.startTime)
        let result = CallKitRetryResult(
            success: false,
            callUUID: operation.callUUID,
            strategy: operation.currentStrategy,
            attemptNumber: operation.currentAttempt,
            totalDuration: totalDuration,
            error: error
        )
        
        recordRetryResult(result)
        delegate?.retryDidExceedMaximumAttempts(for: operation.callUUID, finalStrategy: operation.currentStrategy)
    }
    
    private func handleRetryTimeout(operation: ActiveRetryOperation, startTime: Date) {
        let duration = Date().timeIntervalSince(startTime)
        handleRetryFailure(operation: operation, error: .retryTimeoutExceeded, duration: duration)
    }
    
    private func handleMaxRetriesExceeded(operation: ActiveRetryOperation) {
        handleFinalRetryFailure(operation: operation, error: .maxRetriesExceeded)
    }
    
    private func handleCircuitBreakerOpen(operation: ActiveRetryOperation) {
        handleFinalRetryFailure(operation: operation, error: .circuitBreakerOpen)
    }
    
    // MARK: - Circuit Breaker Management
    
    private func updateCircuitBreakerOnFailure() {
        circuitBreakerConsecutiveFailures += 1
        circuitBreakerLastFailureTime = Date()
        
        if circuitBreakerConsecutiveFailures >= circuitBreakerFailureThreshold {
            circuitBreakerState = .open
            updateCircuitBreakerMetrics()
        }
    }
    
    private func resetCircuitBreaker() {
        circuitBreakerConsecutiveFailures = 0
        circuitBreakerLastFailureTime = nil
        circuitBreakerState = .closed
        updateCircuitBreakerMetrics()
    }
    
    private func isCircuitBreakerRecoveryReady() -> Bool {
        guard let lastFailureTime = circuitBreakerLastFailureTime else { return true }
        return Date().timeIntervalSince(lastFailureTime) >= circuitBreakerRecoveryTimeout
    }
    
    private func updateCircuitBreakerMetrics() {
        DispatchQueue.main.async {
            self.circuitBreakerMetrics = CircuitBreakerMetrics(
                failureCount: self.circuitBreakerConsecutiveFailures,
                consecutiveFailures: self.circuitBreakerConsecutiveFailures,
                lastFailureTime: self.circuitBreakerLastFailureTime,
                state: self.circuitBreakerState,
                recoveryTime: self.circuitBreakerLastFailureTime?.addingTimeInterval(self.circuitBreakerRecoveryTimeout)
            )
        }
    }
    
    // MARK: - Validation and Utilities
    
    private func validateRetryPreconditions(for callUUID: UUID) -> Bool {
        // Check if retry is already active for this call
        guard activeOperations[callUUID] == nil else {
            return false
        }
        
        // Check if we've reached max concurrent retries
        guard activeOperations.count < maxConcurrentRetries else {
            return false
        }
        
        // Check system resources
        guard !isSystemResourcesExhausted() else {
            return false
        }
        
        return true
    }
    
    private func isSystemResourcesExhausted() -> Bool {
        // Check memory pressure
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsage = Double(info.resident_size) / (1024 * 1024)
            return memoryUsage > 300.0 // 300MB threshold
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
        
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
    }
    
    private func handleAppDidEnterBackground() {
        // Pause non-critical retry operations
        retryQueue.async { [weak self] in
            self?.pauseNonCriticalRetries()
        }
    }
    
    private func handleMemoryWarning() {
        metricsQueue.async { [weak self] in
            self?.cleanupOldResults()
        }
    }
    
    private func pauseNonCriticalRetries() {
        // Implementation would pause retries for calls that are not immediately critical
    }
    
    // MARK: - Metrics and Analytics
    
    private func recordRetryResult(_ result: CallKitRetryResult) {
        metricsQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.retryLock.withLock {
                self.retryResults.append(result)
                
                if self.retryResults.count > self.maxResultsToRetain {
                    self.retryResults.removeFirst()
                }
                
                self.updateMetrics()
            }
            
            DispatchQueue.main.async {
                self.lastRetryResult = result
            }
        }
    }
    
    private func recordRetryFailure(for callUUID: UUID, error: CallKitRetryError, strategy: CallRetryStrategyType, attempt: Int) {
        let result = CallKitRetryResult(
            success: false,
            callUUID: callUUID,
            strategy: strategy,
            attemptNumber: attempt,
            totalDuration: 0,
            error: error
        )
        recordRetryResult(result)
    }
    
    private func recordStrategyResult(strategy: CallRetryStrategyType, success: Bool) {
        strategySuccessHistory[strategy, default: []].append(success)
        
        // Keep only recent history
        let maxHistorySize = 50
        if strategySuccessHistory[strategy]!.count > maxHistorySize {
            strategySuccessHistory[strategy]!.removeFirst()
        }
    }
    
    private func updateMetrics() {
        let totalOperations = retryResults.count
        let successfulRetries = retryResults.filter { $0.success }.count
        let totalAttempts = retryResults.reduce(0) { $0 + $1.attemptNumber }
        let averageAttempts = totalOperations > 0 ? Double(totalAttempts) / Double(totalOperations) : 0
        let averageDuration = retryResults.reduce(0) { $0 + $1.totalDuration } / Double(max(totalOperations, 1))
        
        var strategyRates: [CallRetryStrategyType: Double] = [:]
        var errorCounts: [CallKitRetryError: Int] = [:]
        
        let strategyGroups = Dictionary(grouping: retryResults) { $0.strategy }
        for (strategy, results) in strategyGroups {
            let successes = results.filter { $0.success }.count
            strategyRates[strategy] = Double(successes) / Double(results.count)
        }
        
        for result in retryResults {
            if let error = result.error {
                errorCounts[error, default: 0] += 1
            }
        }
        
        DispatchQueue.main.async {
            self.currentMetrics = CallKitRetryMetrics(
                totalRetryOperations: totalOperations,
                successfulRetries: successfulRetries,
                averageAttemptCount: averageAttempts,
                averageDuration: averageDuration,
                strategySuccessRates: strategyRates,
                commonErrors: errorCounts,
                circuitBreakerStatus: self.circuitBreakerState,
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
    
    private func updateActiveRetryCount() {
        DispatchQueue.main.async {
            self.activeRetryCount = self.activeOperations.count
        }
    }
    
    private func cleanupAllRetryOperations() {
        retryLock.withLock {
            for operation in activeOperations.values {
                operation.cleanup()
            }
            activeOperations.removeAll()
            updateActiveRetryCount()
        }
    }
    
    private func cleanupOldResults() {
        metricsQueue.async { [weak self] in
            guard let self = self else { return }
            
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -self.metricsRetentionDays, to: Date()) ?? Date()
            
            self.retryLock.withLock {
                self.retryResults = self.retryResults.filter { $0.timestamp > cutoffDate }
                self.updateMetrics()
            }
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