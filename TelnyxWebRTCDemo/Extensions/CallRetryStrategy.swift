//
//  CallRetryStrategy.swift
//  TelnyxWebRTCDemo
//
//  Created by Claude Code on 2025-01-04.
//  Copyright © 2025 Telnyx LLC. All rights reserved.
//
//  Comprehensive retry strategy implementations for CallKit detection failures
//  Part of WhatsApp-style CallKit enhancement (Phase 3)
//

import UIKit
import Foundation
import CallKit
import Combine
import TelnyxRTC

// MARK: - Strategy Protocol Definitions

protocol CallRetryStrategy: AnyObject {
    var strategyType: CallRetryStrategyType { get }
    var configuration: CallRetryStrategyConfiguration { get set }
    var isAvailable: Bool { get }
    var currentSuccessRate: Double { get }
    
    func calculateDelay(for attempt: Int, previousDelays: [TimeInterval]) -> TimeInterval
    func shouldRetry(for attempt: Int, error: CallKitRetryError, history: [CallKitRetryResult]) -> Bool
    func adjustConfiguration(based successRate: Double, recentResults: [CallKitRetryResult])
    func reset()
}

protocol CallRetryStrategyFactory {
    func createStrategy(type: CallRetryStrategyType, configuration: CallRetryStrategyConfiguration?) -> CallRetryStrategy?
}

protocol CallRetryCoordinator: AnyObject {
    func coordinateRetry(callUUID: UUID, strategy: CallRetryStrategy, attempt: Int) -> Bool
    func notifyRetryOutcome(callUUID: UUID, success: Bool, strategy: CallRetryStrategy, attempt: Int)
}

// MARK: - Strategy Configuration

struct CallRetryStrategyConfiguration {
    let minDelay: TimeInterval
    let maxDelay: TimeInterval
    let maxAttempts: Int
    let timeoutPerAttempt: TimeInterval
    let jitterEnabled: Bool
    let jitterRange: ClosedRange<Double>
    let adaptiveAdjustment: Bool
    let successRateThreshold: Double
    let metadata: [String: Any]
    
    static let ultraFast = CallRetryStrategyConfiguration(
        minDelay: 0.1,
        maxDelay: 2.0,
        maxAttempts: 3,
        timeoutPerAttempt: 1.5,
        jitterEnabled: false,
        jitterRange: 0.9...1.1,
        adaptiveAdjustment: false,
        successRateThreshold: 0.7,
        metadata: ["priority": "ultra_high"]
    )
    
    static let standard = CallRetryStrategyConfiguration(
        minDelay: 0.5,
        maxDelay: 8.0,
        maxAttempts: 5,
        timeoutPerAttempt: 3.0,
        jitterEnabled: true,
        jitterRange: 0.8...1.2,
        adaptiveAdjustment: true,
        successRateThreshold: 0.6,
        metadata: ["priority": "high"]
    )
    
    static let patient = CallRetryStrategyConfiguration(
        minDelay: 1.0,
        maxDelay: 30.0,
        maxAttempts: 10,
        timeoutPerAttempt: 5.0,
        jitterEnabled: true,
        jitterRange: 0.7...1.3,
        adaptiveAdjustment: true,
        successRateThreshold: 0.4,
        metadata: ["priority": "normal"]
    )
}

// MARK: - Base Strategy Implementation

class BaseCallRetryStrategy: CallRetryStrategy {
    var strategyType: CallRetryStrategyType { fatalError("Must be overridden") }
    var configuration: CallRetryStrategyConfiguration
    var isAvailable: Bool { true }
    
    private var successHistory: [Bool] = []
    private let maxHistorySize = 20
    private let strategyLock = NSLock()
    
    var currentSuccessRate: Double {
        return strategyLock.withLock {
            guard !successHistory.isEmpty else { return 0.5 }
            let successes = successHistory.filter { $0 }.count
            return Double(successes) / Double(successHistory.count)
        }
    }
    
    init(configuration: CallRetryStrategyConfiguration) {
        self.configuration = configuration
    }
    
    func calculateDelay(for attempt: Int, previousDelays: [TimeInterval]) -> TimeInterval {
        fatalError("Must be overridden")
    }
    
    func shouldRetry(for attempt: Int, error: CallKitRetryError, history: [CallKitRetryResult]) -> Bool {
        // Common retry decision logic
        guard attempt <= configuration.maxAttempts else { return false }
        
        // Don't retry certain critical errors
        switch error {
        case .maxRetriesExceeded, .circuitBreakerOpen:
            return false
        default:
            break
        }
        
        // Strategy-specific logic (can be overridden)
        return shouldRetrySpecific(for: attempt, error: error, history: history)
    }
    
    func adjustConfiguration(based successRate: Double, recentResults: [CallKitRetryResult]) {
        guard configuration.adaptiveAdjustment else { return }
        
        strategyLock.withLock {
            // Record success/failure
            for result in recentResults {
                successHistory.append(result.success)
            }
            
            // Keep history size manageable
            if successHistory.count > maxHistorySize {
                successHistory.removeFirst(successHistory.count - maxHistorySize)
            }
            
            // Adaptive configuration adjustment (can be overridden)
            adaptiveConfigurationAdjustment(successRate: successRate, results: recentResults)
        }
    }
    
    func reset() {
        strategyLock.withLock {
            successHistory.removeAll()
            performStrategySpecificReset()
        }
    }
    
    // MARK: - Internal Methods for Subclasses
    
    internal func shouldRetrySpecific(for attempt: Int, error: CallKitRetryError, history: [CallKitRetryResult]) -> Bool {
        return true // Default: always retry if attempt count allows
    }
    
    internal func adaptiveConfigurationAdjustment(successRate: Double, results: [CallKitRetryResult]) {
        // Default: no adaptive adjustment
    }
    
    internal func performStrategySpecificReset() {
        // Default: no specific reset logic
    }
    
    internal func applyJitter(to delay: TimeInterval) -> TimeInterval {
        guard configuration.jitterEnabled else { return delay }
        let jitter = Double.random(in: configuration.jitterRange)
        return delay * jitter
    }
    
    internal func constrainDelay(_ delay: TimeInterval) -> TimeInterval {
        return min(max(delay, configuration.minDelay), configuration.maxDelay)
    }
}

// MARK: - Concrete Strategy Implementations

final class ImmediateRetryStrategy: BaseCallRetryStrategy {
    override var strategyType: CallRetryStrategyType { .immediate }
    
    override func calculateDelay(for attempt: Int, previousDelays: [TimeInterval]) -> TimeInterval {
        // Always return minimal delay for immediate retry
        return applyJitter(to: configuration.minDelay)
    }
    
    override func shouldRetrySpecific(for attempt: Int, error: CallKitRetryError, history: [CallKitRetryResult]) -> Bool {
        // Be more aggressive with immediate retries but limit attempts
        return attempt <= min(3, configuration.maxAttempts)
    }
}

final class ExponentialBackoffRetryStrategy: BaseCallRetryStrategy {
    override var strategyType: CallRetryStrategyType { .exponentialBackoff }
    
    private var backoffMultiplier: Double = 1.5
    private let maxBackoffMultiplier: Double = 3.0
    private let minBackoffMultiplier: Double = 1.2
    
    override func calculateDelay(for attempt: Int, previousDelays: [TimeInterval]) -> TimeInterval {
        let baseDelay = configuration.minDelay * pow(backoffMultiplier, Double(attempt - 1))
        let constrainedDelay = constrainDelay(baseDelay)
        return applyJitter(to: constrainedDelay)
    }
    
    override func shouldRetrySpecific(for attempt: Int, error: CallKitRetryError, history: [CallKitRetryResult]) -> Bool {
        // Exponential backoff is good for transient failures
        switch error {
        case .backgroundingFailed, .detectionFailed:
            return true
        case .systemResourcesExhausted:
            return attempt <= 2 // Limited retries for resource issues
        default:
            return true
        }
    }
    
    override func adaptiveConfigurationAdjustment(successRate: Double, results: [CallKitRetryResult]) {
        // Adjust backoff multiplier based on success rate
        if successRate > 0.8 {
            backoffMultiplier = max(minBackoffMultiplier, backoffMultiplier * 0.9)
        } else if successRate < 0.4 {
            backoffMultiplier = min(maxBackoffMultiplier, backoffMultiplier * 1.1)
        }
    }
    
    override func performStrategySpecificReset() {
        backoffMultiplier = 1.5
    }
}

final class LinearBackoffRetryStrategy: BaseCallRetryStrategy {
    override var strategyType: CallRetryStrategyType { .linearBackoff }
    
    private var linearIncrement: TimeInterval = 1.0
    private let maxLinearIncrement: TimeInterval = 3.0
    private let minLinearIncrement: TimeInterval = 0.5
    
    override func calculateDelay(for attempt: Int, previousDelays: [TimeInterval]) -> TimeInterval {
        let baseDelay = configuration.minDelay + (linearIncrement * Double(attempt - 1))
        let constrainedDelay = constrainDelay(baseDelay)
        return applyJitter(to: constrainedDelay)
    }
    
    override func shouldRetrySpecific(for attempt: Int, error: CallKitRetryError, history: [CallKitRetryResult]) -> Bool {
        // Linear backoff is good for steady progress
        return attempt <= configuration.maxAttempts
    }
    
    override func adaptiveConfigurationAdjustment(successRate: Double, results: [CallKitRetryResult]) {
        // Adjust linear increment based on recent performance
        let recentFailures = results.suffix(5).filter { !$0.success }.count
        
        if recentFailures >= 3 {
            linearIncrement = min(maxLinearIncrement, linearIncrement + 0.2)
        } else if successRate > 0.7 {
            linearIncrement = max(minLinearIncrement, linearIncrement - 0.1)
        }
    }
    
    override func performStrategySpecificReset() {
        linearIncrement = 1.0
    }
}

final class FixedIntervalRetryStrategy: BaseCallRetryStrategy {
    override var strategyType: CallRetryStrategyType { .fixedInterval }
    
    private var fixedInterval: TimeInterval
    
    override init(configuration: CallRetryStrategyConfiguration) {
        self.fixedInterval = (configuration.minDelay + configuration.maxDelay) / 2
        super.init(configuration: configuration)
    }
    
    override func calculateDelay(for attempt: Int, previousDelays: [TimeInterval]) -> TimeInterval {
        return applyJitter(to: fixedInterval)
    }
    
    override func shouldRetrySpecific(for attempt: Int, error: CallKitRetryError, history: [CallKitRetryResult]) -> Bool {
        // Fixed interval is predictable but may not be optimal for all scenarios
        switch error {
        case .retryTimeoutExceeded:
            return attempt <= 2 // Limited retries for timeout issues
        default:
            return true
        }
    }
    
    override func adaptiveConfigurationAdjustment(successRate: Double, results: [CallKitRetryResult]) {
        // Adjust fixed interval based on average success timing
        let successfulResults = results.filter { $0.success }
        
        if !successfulResults.isEmpty {
            let averageDuration = successfulResults.reduce(0) { $0 + $1.totalDuration } / Double(successfulResults.count)
            
            if averageDuration < fixedInterval * 0.5 {
                fixedInterval = max(configuration.minDelay, fixedInterval * 0.9)
            } else if averageDuration > fixedInterval * 2.0 {
                fixedInterval = min(configuration.maxDelay, fixedInterval * 1.1)
            }
        }
    }
}

final class AdaptiveRetryStrategy: BaseCallRetryStrategy {
    override var strategyType: CallRetryStrategyType { .adaptive }
    
    private var dynamicDelayMultiplier: Double = 1.0
    private var contextualFactors: [String: Double] = [:]
    private var recentPerformanceWindow: [CallKitRetryResult] = []
    private let maxPerformanceWindowSize = 10
    
    override func calculateDelay(for attempt: Int, previousDelays: [TimeInterval]) -> TimeInterval {
        // Adaptive delay calculation based on multiple factors
        var baseDelay = configuration.minDelay * dynamicDelayMultiplier
        
        // Factor in previous delays performance
        if !previousDelays.isEmpty {
            let averagePreviousDelay = previousDelays.reduce(0, +) / Double(previousDelays.count)
            baseDelay = (baseDelay + averagePreviousDelay) / 2
        }
        
        // Apply contextual factors
        for (_, factor) in contextualFactors {
            baseDelay *= factor
        }
        
        // Progressive increase for repeated attempts
        baseDelay *= (1.0 + Double(attempt - 1) * 0.3)
        
        let constrainedDelay = constrainDelay(baseDelay)
        return applyJitter(to: constrainedDelay)
    }
    
    override func shouldRetrySpecific(for attempt: Int, error: CallKitRetryError, history: [CallKitRetryResult]) -> Bool {
        // Intelligent retry decision based on error patterns and history
        let recentFailures = history.suffix(5).filter { !$0.success }
        
        // If we see the same error repeatedly, be more conservative
        let sameErrorCount = recentFailures.filter { $0.error == error }.count
        if sameErrorCount >= 3 {
            return attempt <= 2
        }
        
        // If recent success rate is good, be more aggressive
        let recentSuccessRate = calculateRecentSuccessRate(from: history)
        if recentSuccessRate > 0.7 {
            return attempt <= configuration.maxAttempts + 2
        }
        
        return attempt <= configuration.maxAttempts
    }
    
    override func adaptiveConfigurationAdjustment(successRate: Double, results: [CallKitRetryResult]) {
        // Update performance window
        recentPerformanceWindow.append(contentsOf: results)
        if recentPerformanceWindow.count > maxPerformanceWindowSize {
            recentPerformanceWindow.removeFirst(recentPerformanceWindow.count - maxPerformanceWindowSize)
        }
        
        // Adjust dynamic delay multiplier
        if successRate > 0.8 {
            dynamicDelayMultiplier = max(0.5, dynamicDelayMultiplier * 0.9)
        } else if successRate < 0.3 {
            dynamicDelayMultiplier = min(2.0, dynamicDelayMultiplier * 1.2)
        }
        
        // Update contextual factors
        updateContextualFactors(results: results)
    }
    
    private func calculateRecentSuccessRate(from history: [CallKitRetryResult]) -> Double {
        let recentResults = history.suffix(min(10, history.count))
        guard !recentResults.isEmpty else { return 0.5 }
        
        let successes = recentResults.filter { $0.success }.count
        return Double(successes) / Double(recentResults.count)
    }
    
    private func updateContextualFactors(results: [CallKitRetryResult]) {
        // Time of day factor
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 9 && hour <= 17 {
            contextualFactors["time_of_day"] = 1.1 // Slightly longer delays during business hours
        } else {
            contextualFactors["time_of_day"] = 0.9
        }
        
        // App state factor
        let appState = UIApplication.shared.applicationState
        switch appState {
        case .background:
            contextualFactors["app_state"] = 1.3
        case .inactive:
            contextualFactors["app_state"] = 1.1
        case .active:
            contextualFactors["app_state"] = 0.9
        @unknown default:
            contextualFactors["app_state"] = 1.0
        }
        
        // Recent error pattern factor
        let recentErrors = results.suffix(5).compactMap { $0.error }
        let uniqueErrors = Set(recentErrors.map { $0.localizedDescription })
        if uniqueErrors.count > 3 {
            contextualFactors["error_diversity"] = 1.2
        } else {
            contextualFactors["error_diversity"] = 0.95
        }
    }
    
    override func performStrategySpecificReset() {
        dynamicDelayMultiplier = 1.0
        contextualFactors.removeAll()
        recentPerformanceWindow.removeAll()
    }
}

final class CircuitBreakerRetryStrategy: BaseCallRetryStrategy {
    override var strategyType: CallRetryStrategyType { .circuitBreaker }
    
    private enum CircuitBreakerState {
        case closed, open, halfOpen
    }
    
    private var circuitState: CircuitBreakerState = .closed
    private var failureCount: Int = 0
    private var lastFailureTime: Date?
    private let failureThreshold: Int = 5
    private let recoveryTimeout: TimeInterval = 30.0
    private let halfOpenMaxAttempts: Int = 2
    private var halfOpenAttempts: Int = 0
    
    override var isAvailable: Bool {
        return circuitState != .open || isRecoveryTimeReached()
    }
    
    override func calculateDelay(for attempt: Int, previousDelays: [TimeInterval]) -> TimeInterval {
        switch circuitState {
        case .closed:
            return applyJitter(to: configuration.minDelay)
        case .open:
            return configuration.maxDelay
        case .halfOpen:
            return applyJitter(to: configuration.minDelay * 2.0)
        }
    }
    
    override func shouldRetrySpecific(for attempt: Int, error: CallKitRetryError, history: [CallKitRetryResult]) -> Bool {
        updateCircuitState(error: error, success: false)
        
        switch circuitState {
        case .closed:
            return attempt <= configuration.maxAttempts
        case .open:
            return false
        case .halfOpen:
            return halfOpenAttempts < halfOpenMaxAttempts
        }
    }
    
    override func adaptiveConfigurationAdjustment(successRate: Double, results: [CallKitRetryResult]) {
        // Handle successful results
        let successes = results.filter { $0.success }
        for _ in successes {
            updateCircuitState(error: nil, success: true)
        }
    }
    
    private func updateCircuitState(error: CallKitRetryError?, success: Bool) {
        if success {
            switch circuitState {
            case .halfOpen:
                // Success in half-open state, close the circuit
                circuitState = .closed
                failureCount = 0
                halfOpenAttempts = 0
                lastFailureTime = nil
            case .closed:
                // Reset failure count on success
                failureCount = max(0, failureCount - 1)
            case .open:
                break // No change from open on success (shouldn't happen)
            }
        } else {
            failureCount += 1
            lastFailureTime = Date()
            
            switch circuitState {
            case .closed:
                if failureCount >= failureThreshold {
                    circuitState = .open
                }
            case .halfOpen:
                // Failure in half-open state, reopen the circuit
                circuitState = .open
                halfOpenAttempts = 0
            case .open:
                break // Already open
            }
        }
    }
    
    private func isRecoveryTimeReached() -> Bool {
        guard let lastFailure = lastFailureTime else { return true }
        
        let timeSinceFailure = Date().timeIntervalSince(lastFailure)
        let isRecoveryTime = timeSinceFailure >= recoveryTimeout
        
        if isRecoveryTime && circuitState == .open {
            circuitState = .halfOpen
            halfOpenAttempts = 0
        }
        
        return isRecoveryTime
    }
    
    override func performStrategySpecificReset() {
        circuitState = .closed
        failureCount = 0
        lastFailureTime = nil
        halfOpenAttempts = 0
    }
}

final class CompositeRetryStrategy: BaseCallRetryStrategy {
    override var strategyType: CallRetryStrategyType { .adaptive }
    
    private var primaryStrategy: CallRetryStrategy
    private var fallbackStrategy: CallRetryStrategy
    private var useFallback: Bool = false
    private var switchThreshold: Int = 3
    private var consecutiveFailures: Int = 0
    
    init(primary: CallRetryStrategy, fallback: CallRetryStrategy, configuration: CallRetryStrategyConfiguration) {
        self.primaryStrategy = primary
        self.fallbackStrategy = fallback
        super.init(configuration: configuration)
    }
    
    override func calculateDelay(for attempt: Int, previousDelays: [TimeInterval]) -> TimeInterval {
        let activeStrategy = useFallback ? fallbackStrategy : primaryStrategy
        return activeStrategy.calculateDelay(for: attempt, previousDelays: previousDelays)
    }
    
    override func shouldRetrySpecific(for attempt: Int, error: CallKitRetryError, history: [CallKitRetryResult]) -> Bool {
        let activeStrategy = useFallback ? fallbackStrategy : primaryStrategy
        
        // Check if we should switch strategies
        let recentFailures = history.suffix(switchThreshold).filter { !$0.success }
        if recentFailures.count >= switchThreshold && !useFallback {
            useFallback = true
            consecutiveFailures = 0
        }
        
        return activeStrategy.shouldRetry(for: attempt, error: error, history: history)
    }
    
    override func adaptiveConfigurationAdjustment(successRate: Double, results: [CallKitRetryResult]) {
        primaryStrategy.adjustConfiguration(based: successRate, recentResults: results)
        fallbackStrategy.adjustConfiguration(based: successRate, recentResults: results)
        
        // Switch back to primary if fallback is performing well
        if useFallback && successRate > 0.8 {
            useFallback = false
        }
    }
    
    override func performStrategySpecificReset() {
        primaryStrategy.reset()
        fallbackStrategy.reset()
        useFallback = false
        consecutiveFailures = 0
    }
}

// MARK: - Context-Aware Strategy

final class ContextAwareRetryStrategy: BaseCallRetryStrategy {
    override var strategyType: CallRetryStrategyType { .adaptive }
    
    private var contextStrategies: [String: CallRetryStrategy] = [:]
    private var currentContext: String = "default"
    
    override init(configuration: CallRetryStrategyConfiguration) {
        super.init(configuration: configuration)
        setupContextStrategies()
    }
    
    private func setupContextStrategies() {
        contextStrategies["default"] = ExponentialBackoffRetryStrategy(configuration: configuration)
        contextStrategies["background"] = LinearBackoffRetryStrategy(configuration: configuration)
        contextStrategies["memory_pressure"] = FixedIntervalRetryStrategy(configuration: configuration)
        contextStrategies["system_busy"] = CircuitBreakerRetryStrategy(configuration: configuration)
    }
    
    override func calculateDelay(for attempt: Int, previousDelays: [TimeInterval]) -> TimeInterval {
        updateCurrentContext()
        let activeStrategy = contextStrategies[currentContext] ?? contextStrategies["default"]!
        return activeStrategy.calculateDelay(for: attempt, previousDelays: previousDelays)
    }
    
    override func shouldRetrySpecific(for attempt: Int, error: CallKitRetryError, history: [CallKitRetryResult]) -> Bool {
        updateCurrentContext()
        let activeStrategy = contextStrategies[currentContext] ?? contextStrategies["default"]!
        return activeStrategy.shouldRetry(for: attempt, error: error, history: history)
    }
    
    private func updateCurrentContext() {
        let appState = UIApplication.shared.applicationState
        let memoryPressure = checkMemoryPressure()
        
        if memoryPressure {
            currentContext = "memory_pressure"
        } else if appState == .background {
            currentContext = "background"
        } else {
            currentContext = "default"
        }
    }
    
    private func checkMemoryPressure() -> Bool {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsage = Double(info.resident_size) / (1024 * 1024)
            return memoryUsage > 250.0 // 250MB threshold
        }
        
        return false
    }
    
    override func adaptiveConfigurationAdjustment(successRate: Double, results: [CallKitRetryResult]) {
        for strategy in contextStrategies.values {
            strategy.adjustConfiguration(based: successRate, recentResults: results)
        }
    }
    
    override func performStrategySpecificReset() {
        for strategy in contextStrategies.values {
            strategy.reset()
        }
        currentContext = "default"
    }
}

// MARK: - Strategy Factory Implementation

final class CallRetryStrategyFactoryImpl: CallRetryStrategyFactory {
    
    func createStrategy(type: CallRetryStrategyType, configuration: CallRetryStrategyConfiguration?) -> CallRetryStrategy? {
        let config = configuration ?? .standard
        
        switch type {
        case .immediate:
            return ImmediateRetryStrategy(configuration: config)
        case .exponentialBackoff:
            return ExponentialBackoffRetryStrategy(configuration: config)
        case .linearBackoff:
            return LinearBackoffRetryStrategy(configuration: config)
        case .fixedInterval:
            return FixedIntervalRetryStrategy(configuration: config)
        case .adaptive:
            return AdaptiveRetryStrategy(configuration: config)
        case .circuitBreaker:
            return CircuitBreakerRetryStrategy(configuration: config)
        }
    }
    
    func createCompositeStrategy(primary: CallRetryStrategyType, fallback: CallRetryStrategyType, configuration: CallRetryStrategyConfiguration?) -> CallRetryStrategy? {
        let config = configuration ?? .standard
        
        guard let primaryStrategy = createStrategy(type: primary, configuration: config),
              let fallbackStrategy = createStrategy(type: fallback, configuration: config) else {
            return nil
        }
        
        return CompositeRetryStrategy(primary: primaryStrategy, fallback: fallbackStrategy, configuration: config)
    }
    
    func createContextAwareStrategy(configuration: CallRetryStrategyConfiguration?) -> CallRetryStrategy {
        let config = configuration ?? .standard
        return ContextAwareRetryStrategy(configuration: config)
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