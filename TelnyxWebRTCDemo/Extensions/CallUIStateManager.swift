//
//  CallUIStateManager.swift
//  TelnyxWebRTCDemo
//
//  Created by Claude Code on 2025-01-04.
//  Copyright © 2025 Telnyx LLC. All rights reserved.
//
//  Centralized state management system for CallKit UI coordination
//  Part of WhatsApp-style CallKit enhancement (Phase 4)
//

import UIKit
import Foundation
import CallKit
import Combine
import SwiftUI
import TelnyxRTC

// MARK: - State Management Protocols

protocol CallUIStateManagerDelegate: AnyObject {
    func stateManager(_ manager: CallUIStateManager, didTransitionFrom oldState: CallUIState, to newState: CallUIState, for callUUID: UUID)
    func stateManagerDidUpdateOverallHealth(_ manager: CallUIStateManager, healthScore: Double, trend: HealthTrend)
    func stateManager(_ manager: CallUIStateManager, didDetectCriticalIssue issue: CriticalStateIssue, for callUUID: UUID?)
    func stateManager(_ manager: CallUIStateManager, didReceiveRecommendation recommendation: StateRecommendation)
}

protocol CallUIStateObserver: AnyObject {
    func callUIStateDidChange(_ newState: CallUIState, for callUUID: UUID)
    func callUIMetricsDidUpdate(_ metrics: CallUIMetrics)
}

protocol CallUIStateProvider {
    func getCurrentState(for callUUID: UUID) -> CallUIState?
    func getAllActiveStates() -> [UUID: CallUIState]
    func getStateHistory(for callUUID: UUID, limit: Int) -> [CallUIStateSnapshot]
}

// MARK: - Core State Types

// Health trend for call UI health monitoring
enum HealthTrend {
    case improving
    case stable
    case declining
    case degrading  // Alias for declining
    case critical
}

// Priority levels for state recommendations
enum RecommendationPriority: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
    
    var description: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}

public enum CallUIState: String, CaseIterable, Equatable {
    // Initial States
    case idle = "Idle"
    case initializing = "Initializing"
    
    // Detection States
    case detecting = "Detecting"
    case detectionSucceeded = "DetectionSucceeded"
    case detectionFailed = "DetectionFailed"
    
    // Backgrounding States
    case backgrounding = "Backgrounding"
    case backgrounded = "Backgrounded"
    case backgroundingFailed = "BackgroundingFailed"
    
    // CallKit States
    case callKitActive = "CallKitActive"
    case callKitPending = "CallKitPending"
    case callKitFailed = "CallKitFailed"
    
    // Fallback States
    case fallbackUIRequired = "FallbackUIRequired"
    case fallbackUIActive = "FallbackUIActive"
    case fallbackUITransitioning = "FallbackUITransitioning"
    
    // Retry States
    case retrying = "Retrying"
    case retryExhausted = "RetryExhausted"
    
    // Terminal States
    case completed = "Completed"
    case terminated = "Terminated"
    case error = "Error"
    
    var isActive: Bool {
        switch self {
        case .idle, .completed, .terminated, .error:
            return false
        default:
            return true
        }
    }
    
    var isTerminal: Bool {
        switch self {
        case .completed, .terminated, .error, .retryExhausted:
            return true
        default:
            return false
        }
    }
    
    var requiresUI: Bool {
        switch self {
        case .fallbackUIRequired, .fallbackUIActive, .fallbackUITransitioning:
            return true
        default:
            return false
        }
    }
    
    var priority: Int {
        switch self {
        case .error: return 10
        case .retryExhausted: return 9
        case .callKitFailed: return 8
        case .fallbackUIRequired: return 7
        case .callKitActive: return 6
        case .fallbackUIActive: return 5
        case .backgrounded: return 4
        case .detecting, .retrying: return 3
        case .initializing: return 2
        case .idle: return 1
        default: return 3
        }
    }
}

struct CallUIStateSnapshot {
    let callUUID: UUID
    let state: CallUIState
    let timestamp: Date
    let duration: TimeInterval?
    let metadata: [String: Any]
    let systemContext: SystemContext
    let performance: PerformanceMetrics
    
    init(callUUID: UUID, state: CallUIState, metadata: [String: Any] = [:], previousSnapshot: CallUIStateSnapshot? = nil) {
        self.callUUID = callUUID
        self.state = state
        self.timestamp = Date()
        self.duration = previousSnapshot?.timestamp.timeIntervalSinceNow.magnitude
        self.metadata = metadata
        self.systemContext = SystemContext.current()
        self.performance = PerformanceMetrics.current()
    }
}

struct SystemContext {
    let appState: UIApplication.State
    let memoryUsage: UInt64
    let batteryLevel: Float
    let thermalState: ProcessInfo.ThermalState
    let networkReachability: Bool
    let activeCallsCount: Int
    
    static func current() -> SystemContext {
        return SystemContext(
            appState: UIApplication.shared.applicationState,
            memoryUsage: Self.getCurrentMemoryUsage(),
            batteryLevel: UIDevice.current.batteryLevel,
            thermalState: ProcessInfo.processInfo.thermalState,
            networkReachability: true, // Simplified
            activeCallsCount: CXCallObserver().calls.count
        )
    }
    
    private static func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }
}

struct PerformanceMetrics {
    let cpuUsage: Double
    let memoryPressure: Double
    let frameRate: Double
    let batteryDrain: Double
    
    static func current() -> PerformanceMetrics {
        return PerformanceMetrics(
            cpuUsage: Self.getCurrentCPUUsage(),
            memoryPressure: 0.0, // Simplified
            frameRate: 60.0, // Assumed
            batteryDrain: 0.0 // Simplified
        )
    }
    
    private static func getCurrentCPUUsage() -> Double {
        // Simplified CPU usage calculation
        return 0.0
    }
}

// MARK: - State Transition Types

struct CallUIStateTransition {
    let id: UUID
    let from: CallUIState
    let to: CallUIState
    let callUUID: UUID
    let timestamp: Date
    let trigger: StateTransitionTrigger
    let metadata: [String: Any]
    let validationResult: TransitionValidationResult
    
    init(from: CallUIState, to: CallUIState, callUUID: UUID, trigger: StateTransitionTrigger, metadata: [String: Any] = [:]) {
        self.id = UUID()
        self.from = from
        self.to = to
        self.callUUID = callUUID
        self.timestamp = Date()
        self.trigger = trigger
        self.metadata = metadata
        self.validationResult = Self.validateTransition(from: from, to: to, trigger: trigger)
    }
    
    private static func validateTransition(from: CallUIState, to: CallUIState, trigger: StateTransitionTrigger) -> TransitionValidationResult {
        // Comprehensive state transition validation logic
        let isValid = isValidTransition(from: from, to: to, trigger: trigger)
        let warnings = generateTransitionWarnings(from: from, to: to, trigger: trigger)
        
        return TransitionValidationResult(isValid: isValid, warnings: warnings)
    }
    
    private static func isValidTransition(from: CallUIState, to: CallUIState, trigger: StateTransitionTrigger) -> Bool {
        switch (from, to) {
        case (.idle, .initializing), (.initializing, .detecting), (.detecting, .detectionSucceeded), 
             (.detecting, .detectionFailed), (.detectionSucceeded, .backgrounding),
             (.backgrounding, .backgrounded), (.backgrounding, .backgroundingFailed),
             (.backgrounded, .callKitActive), (.detectionFailed, .retrying),
             (.backgroundingFailed, .retrying), (.callKitFailed, .retrying),
             (.retrying, .detecting), (.retrying, .retryExhausted),
             (.callKitFailed, .fallbackUIRequired), (.fallbackUIRequired, .fallbackUIActive),
             (.fallbackUIActive, .fallbackUITransitioning), (.fallbackUITransitioning, .callKitActive):
            return true
        case (let currentState, let newState) where currentState.isTerminal && newState == .idle:
            return true
        default:
            return false
        }
    }
    
    private static func generateTransitionWarnings(from: CallUIState, to: CallUIState, trigger: StateTransitionTrigger) -> [String] {
        var warnings: [String] = []
        
        if from == to {
            warnings.append("Transition to same state detected")
        }
        
        if from.priority > to.priority {
            warnings.append("Transitioning from higher to lower priority state")
        }
        
        return warnings
    }
}

enum StateTransitionTrigger: String, CaseIterable {
    case userAction = "UserAction"
    case systemEvent = "SystemEvent"
    case detectionResult = "DetectionResult"
    case backgroundingResult = "BackgroundingResult"
    case retryResult = "RetryResult"
    case callKitEvent = "CallKitEvent"
    case timeoutExpired = "TimeoutExpired"
    case errorOccurred = "ErrorOccurred"
    case externalCommand = "ExternalCommand"
    case healthCheckResult = "HealthCheckResult"
}

struct TransitionValidationResult {
    let isValid: Bool
    let warnings: [String]
    let suggestedAlternative: CallUIState?
    
    init(isValid: Bool, warnings: [String], suggestedAlternative: CallUIState? = nil) {
        self.isValid = isValid
        self.warnings = warnings
        self.suggestedAlternative = suggestedAlternative
    }
}

// MARK: - Analytics and Health Types

struct CallUIMetrics {
    let totalStates: Int
    let activeStates: Int
    let averageStateTransitionTime: TimeInterval
    let stateDistribution: [CallUIState: Int]
    let errorRate: Double
    let healthScore: Double
    let performanceScore: Double
    let timestamp: Date
    
    init(totalStates: Int, activeStates: Int, averageStateTransitionTime: TimeInterval, stateDistribution: [CallUIState: Int], errorRate: Double, healthScore: Double, performanceScore: Double) {
        self.totalStates = totalStates
        self.activeStates = activeStates
        self.averageStateTransitionTime = averageStateTransitionTime
        self.stateDistribution = stateDistribution
        self.errorRate = errorRate
        self.healthScore = healthScore
        self.performanceScore = performanceScore
        self.timestamp = Date()
    }
}


enum CriticalStateIssue: String, CaseIterable {
    case stateTransitionLoop = "StateTransitionLoop"
    case prolongedState = "ProlongedState"
    case highErrorRate = "HighErrorRate"
    case memoryLeak = "MemoryLeak"
    case performanceDegradation = "PerformanceDegradation"
    case concurrencyConflict = "ConcurrencyConflict"
    
    var severity: Int {
        switch self {
        case .memoryLeak, .concurrencyConflict: return 5
        case .stateTransitionLoop, .highErrorRate: return 4
        case .performanceDegradation: return 3
        case .prolongedState: return 2
        }
    }
}

struct StateRecommendation {
    let id: UUID
    let title: String
    let description: String
    let priority: RecommendationPriority
    let actionItems: [String]
    let affectedStates: [CallUIState]
    let estimatedImpact: String
    let validUntil: Date
    
    init(title: String, description: String, priority: RecommendationPriority, actionItems: [String], affectedStates: [CallUIState], estimatedImpact: String, validityDuration: TimeInterval = 3600) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.priority = priority
        self.actionItems = actionItems
        self.affectedStates = affectedStates
        self.estimatedImpact = estimatedImpact
        self.validUntil = Date().addingTimeInterval(validityDuration)
    }
}


// MARK: - Main CallUI State Manager

@objc public final class CallUIStateManager: NSObject, ObservableObject, CallUIStateProvider {
    
    // MARK: - Singleton
    static let shared = CallUIStateManager()
    
    // MARK: - Published Properties
    @Published private(set) var activeStates: [UUID: CallUIState] = [:]
    @Published private(set) var currentMetrics = CallUIMetrics(
        totalStates: 0, activeStates: 0, averageStateTransitionTime: 0,
        stateDistribution: [:], errorRate: 0, healthScore: 1.0, performanceScore: 1.0
    )
    @Published private(set) var overallHealthScore: Double = 1.0
    @Published private(set) var healthTrend: HealthTrend = .stable
    @Published private(set) var activeRecommendations: [StateRecommendation] = []
    
    // MARK: - Private Properties
    private let stateQueue = DispatchQueue(label: "com.telnyx.callui.state", qos: .userInteractive)
    private let analysisQueue = DispatchQueue(label: "com.telnyx.callui.analysis", qos: .utility)
    private let stateLock = NSLock()
    
    private var stateSnapshots: [UUID: [CallUIStateSnapshot]] = [:]
    private var stateTransitions: [CallUIStateTransition] = []
    private var stateObservers = NSHashTable<AnyObject>.weakObjects()
    private var cancellables = Set<AnyCancellable>()
    
    weak var delegate: CallUIStateManagerDelegate?
    
    // Configuration
    private let maxSnapshotsPerCall = 50
    private let maxTransitionsToRetain = 200
    private let metricsUpdateInterval: TimeInterval = 30.0
    private let healthAnalysisInterval: TimeInterval = 60.0
    private let stateTimeoutThreshold: TimeInterval = 30.0
    
    // Integration with other systems (optional to prevent circular dependencies)
    private var detectionManagerAvailable: Bool { NSClassFromString("CallKitDetectionManager") != nil }
    private var backgroundingManagerAvailable: Bool { NSClassFromString("AppBackgroundingManager") != nil }
    private var retryManagerAvailable: Bool { NSClassFromString("CallKitRetryManager") != nil }
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupSystemIntegrations()
        startPeriodicAnalysis()
        setupSystemObservers()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Public Interface
    
    func transitionState(for callUUID: UUID, to newState: CallUIState, trigger: StateTransitionTrigger, metadata: [String: Any] = [:]) -> Bool {
        return stateLock.withLock {
            let currentState = activeStates[callUUID] ?? .idle
            let transition = CallUIStateTransition(from: currentState, to: newState, callUUID: callUUID, trigger: trigger, metadata: metadata)
            
            guard transition.validationResult.isValid else {
                recordInvalidTransitionAttempt(transition: transition)
                return false
            }
            
            // Execute the state transition
            executeStateTransition(transition)
            return true
        }
    }
    
    func initializeCall(_ callUUID: UUID, metadata: [String: Any] = [:]) -> Bool {
        return transitionState(for: callUUID, to: .initializing, trigger: .systemEvent, metadata: metadata)
    }
    
    func completeCall(_ callUUID: UUID, success: Bool = true) -> Bool {
        let finalState: CallUIState = success ? .completed : .terminated
        return transitionState(for: callUUID, to: finalState, trigger: .systemEvent)
    }
    
    func addObserver(_ observer: CallUIStateObserver) {
        stateQueue.async { [weak self] in
            self?.stateObservers.add(observer)
        }
    }
    
    func removeObserver(_ observer: CallUIStateObserver) {
        stateQueue.async { [weak self] in
            self?.stateObservers.remove(observer)
        }
    }
    
    // MARK: - CallUIStateProvider Implementation
    
    func getCurrentState(for callUUID: UUID) -> CallUIState? {
        return stateLock.withLock {
            activeStates[callUUID]
        }
    }
    
    func getAllActiveStates() -> [UUID: CallUIState] {
        return stateLock.withLock {
            activeStates
        }
    }
    
    func getStateHistory(for callUUID: UUID, limit: Int = 20) -> [CallUIStateSnapshot] {
        return stateLock.withLock {
            let snapshots = stateSnapshots[callUUID] ?? []
            return Array(snapshots.suffix(limit))
        }
    }
    
    // MARK: - State Transition Execution
    
    private func executeStateTransition(_ transition: CallUIStateTransition) {
        let previousSnapshot = stateSnapshots[transition.callUUID]?.last
        let newSnapshot = CallUIStateSnapshot(
            callUUID: transition.callUUID,
            state: transition.to,
            metadata: transition.metadata,
            previousSnapshot: previousSnapshot
        )
        
        // Update active states
        if transition.to.isTerminal {
            activeStates.removeValue(forKey: transition.callUUID)
            
            // Clean up old snapshots for terminated calls
            cleanupCallSnapshots(for: transition.callUUID)
        } else {
            activeStates[transition.callUUID] = transition.to
        }
        
        // Store snapshot
        if stateSnapshots[transition.callUUID] == nil {
            stateSnapshots[transition.callUUID] = []
        }
        stateSnapshots[transition.callUUID]?.append(newSnapshot)
        
        // Limit snapshot history
        if let snapshots = stateSnapshots[transition.callUUID], snapshots.count > maxSnapshotsPerCall {
            stateSnapshots[transition.callUUID] = Array(snapshots.suffix(maxSnapshotsPerCall))
        }
        
        // Store transition
        stateTransitions.append(transition)
        if stateTransitions.count > maxTransitionsToRetain {
            stateTransitions.removeFirst()
        }
        
        // Notify systems
        notifyStateChange(transition: transition, snapshot: newSnapshot)
        
        // Trigger system integrations
        handleSystemIntegrations(for: transition)
    }
    
    private func notifyStateChange(transition: CallUIStateTransition, snapshot: CallUIStateSnapshot) {
        // Notify delegate
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.stateManager(self, didTransitionFrom: transition.from, to: transition.to, for: transition.callUUID)
        }
        
        // Notify observers
        stateQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.stateObservers.allObjects.forEach { observer in
                if let callUIObserver = observer as? CallUIStateObserver {
                    DispatchQueue.main.async {
                        callUIObserver.callUIStateDidChange(transition.to, for: transition.callUUID)
                    }
                }
            }
        }
    }
    
    private func recordInvalidTransitionAttempt(transition: CallUIStateTransition) {
        // Log invalid transition attempt for analysis
        let metadata: [String: Any] = [
            "from_state": transition.from.rawValue,
            "to_state": transition.to.rawValue,
            "trigger": transition.trigger.rawValue,
            "warnings": transition.validationResult.warnings
        ]
        
        analysisQueue.async { [weak self] in
            self?.analyzeInvalidTransition(transition: transition, metadata: metadata)
        }
    }
    
    // MARK: - System Integrations
    
    private func setupSystemIntegrations() {
        // Integrate with Phase 1: Detection Manager
        NotificationCenter.default.publisher(for: NSNotification.Name("CallKitDetectionStateChanged"))
            .sink { [weak self] notification in
                self?.handleDetectionStateChange(notification: notification)
            }
            .store(in: &cancellables)
        
        // Integrate with Phase 2: Backgrounding Manager
        NotificationCenter.default.publisher(for: NSNotification.Name("AppBackgroundingStateChanged"))
            .sink { [weak self] notification in
                self?.handleBackgroundingStateChange(notification: notification)
            }
            .store(in: &cancellables)
        
        // Integrate with Phase 3: Retry Manager
        NotificationCenter.default.publisher(for: NSNotification.Name("CallKitRetryStateChanged"))
            .sink { [weak self] notification in
                self?.handleRetryStateChange(notification: notification)
            }
            .store(in: &cancellables)
    }
    
    private func handleSystemIntegrations(for transition: CallUIStateTransition) {
        switch transition.to {
        case .detecting:
            // Trigger Phase 1 detection if available
            if detectionManagerAvailable {
                // Detection manager integration would go here
                print("CallKit detection manager is available")
            }
            
        case .backgrounding:
            // Trigger Phase 2 backgrounding if available
            if backgroundingManagerAvailable {
                // Backgrounding manager integration would go here
                print("App backgrounding manager is available")
            }
            
        case .retrying:
            // Trigger Phase 3 retry if available
            if retryManagerAvailable {
                // Retry manager integration would go here
                print("CallKit retry manager is available")
            }
            
        case .fallbackUIRequired:
            // Will be handled by Phase 5 UI system
            break
            
        default:
            break
        }
    }
    
    private func handleDetectionStateChange(notification: Notification) {
        guard let callUUID = notification.userInfo?["callUUID"] as? UUID,
              let detectionResult = notification.userInfo?["result"] as? Bool else { return }
        
        let newState: CallUIState = detectionResult ? .detectionSucceeded : .detectionFailed
        transitionState(for: callUUID, to: newState, trigger: .detectionResult)
    }
    
    private func handleBackgroundingStateChange(notification: Notification) {
        guard let callUUID = notification.userInfo?["callUUID"] as? UUID,
              let backgroundingResult = notification.userInfo?["result"] as? Bool else { return }
        
        let newState: CallUIState = backgroundingResult ? .backgrounded : .backgroundingFailed
        transitionState(for: callUUID, to: newState, trigger: .backgroundingResult)
    }
    
    private func handleRetryStateChange(notification: Notification) {
        guard let callUUID = notification.userInfo?["callUUID"] as? UUID,
              let retryResult = notification.userInfo?["result"] as? Bool else { return }
        
        if retryResult {
            // Retry successful - transition back to detection
            transitionState(for: callUUID, to: .detecting, trigger: .retryResult)
        } else {
            // Check if retries exhausted
            if let exhausted = notification.userInfo?["exhausted"] as? Bool, exhausted {
                transitionState(for: callUUID, to: .retryExhausted, trigger: .retryResult)
            }
        }
    }
    
    // MARK: - Analytics and Health Monitoring
    
    private func startPeriodicAnalysis() {
        // Metrics update timer
        Timer.publish(every: metricsUpdateInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateMetrics()
            }
            .store(in: &cancellables)
        
        // Health analysis timer
        Timer.publish(every: healthAnalysisInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.performHealthAnalysis()
            }
            .store(in: &cancellables)
    }
    
    private func updateMetrics() {
        analysisQueue.async { [weak self] in
            guard let self = self else { return }
            
            let metrics = self.calculateCurrentMetrics()
            
            DispatchQueue.main.async {
                self.currentMetrics = metrics
                
                // Notify observers
                self.stateObservers.allObjects.forEach { observer in
                    if let callUIObserver = observer as? CallUIStateObserver {
                        callUIObserver.callUIMetricsDidUpdate(metrics)
                    }
                }
            }
        }
    }
    
    private func calculateCurrentMetrics() -> CallUIMetrics {
        let totalStates = stateSnapshots.values.reduce(0) { $0 + $1.count }
        let activeStatesCount = activeStates.count
        
        // Calculate average transition time
        let recentTransitions = stateTransitions.suffix(50)
        let totalTransitionTime = recentTransitions.reduce(0.0) { total, transition in
            return total + (transition.timestamp.timeIntervalSinceNow.magnitude)
        }
        let averageTransitionTime = recentTransitions.isEmpty ? 0 : totalTransitionTime / Double(recentTransitions.count)
        
        // Calculate state distribution
        var stateDistribution: [CallUIState: Int] = [:]
        for state in activeStates.values {
            stateDistribution[state, default: 0] += 1
        }
        
        // Calculate error rate
        let errorStates = activeStates.values.filter { $0 == .error || $0 == .callKitFailed || $0 == .backgroundingFailed }
        let errorRate = activeStatesCount > 0 ? Double(errorStates.count) / Double(activeStatesCount) : 0.0
        
        // Calculate health and performance scores
        let healthScore = calculateHealthScore()
        let performanceScore = calculatePerformanceScore()
        
        return CallUIMetrics(
            totalStates: totalStates,
            activeStates: activeStatesCount,
            averageStateTransitionTime: averageTransitionTime,
            stateDistribution: stateDistribution,
            errorRate: errorRate,
            healthScore: healthScore,
            performanceScore: performanceScore
        )
    }
    
    private func calculateHealthScore() -> Double {
        // Comprehensive health score calculation
        var score = 1.0
        
        // Penalize for high error rates
        score *= (1.0 - min(currentMetrics.errorRate, 0.5))
        
        // Penalize for too many active states
        if activeStates.count > 3 {
            score *= 0.9
        }
        
        // Penalize for stuck states
        let stuckStates = detectStuckStates()
        score *= (1.0 - Double(stuckStates.count) * 0.1)
        
        return max(0.0, min(1.0, score))
    }
    
    private func calculatePerformanceScore() -> Double {
        // Performance score based on transition times and system resources
        var score = 1.0
        
        // Factor in transition time performance
        if currentMetrics.averageStateTransitionTime > 1.0 {
            score *= 0.8
        }
        
        // Factor in memory usage
        let currentMemory = SystemContext.current().memoryUsage
        if currentMemory > 200 * 1024 * 1024 { // 200MB
            score *= 0.9
        }
        
        return max(0.0, min(1.0, score))
    }
    
    private func performHealthAnalysis() {
        analysisQueue.async { [weak self] in
            guard let self = self else { return }
            
            let previousScore = self.overallHealthScore
            let currentScore = self.calculateHealthScore()
            let trend = self.determineHealthTrend(previous: previousScore, current: currentScore)
            
            // Detect critical issues
            let criticalIssues = self.detectCriticalIssues()
            
            // Generate recommendations
            let recommendations = self.generateStateRecommendations()
            
            DispatchQueue.main.async {
                self.overallHealthScore = currentScore
                self.healthTrend = trend
                self.activeRecommendations = recommendations
                
                self.delegate?.stateManagerDidUpdateOverallHealth(self, healthScore: currentScore, trend: trend)
                
                // Notify about critical issues
                for issue in criticalIssues {
                    self.delegate?.stateManager(self, didDetectCriticalIssue: issue.issue, for: issue.callUUID)
                }
                
                // Notify about recommendations
                for recommendation in recommendations {
                    self.delegate?.stateManager(self, didReceiveRecommendation: recommendation)
                }
            }
        }
    }
    
    private func determineHealthTrend(previous: Double, current: Double) -> HealthTrend {
        let diff = current - previous
        
        if current < 0.3 {
            return .critical
        } else if diff > 0.05 {
            return .improving
        } else if diff < -0.05 {
            return .degrading
        } else {
            return .stable
        }
    }
    
    private func detectStuckStates() -> [UUID] {
        var stuckStates: [UUID] = []
        let threshold = stateTimeoutThreshold
        
        for (callUUID, snapshots) in stateSnapshots {
            if let lastSnapshot = snapshots.last,
               !lastSnapshot.state.isTerminal,
               Date().timeIntervalSince(lastSnapshot.timestamp) > threshold {
                stuckStates.append(callUUID)
            }
        }
        
        return stuckStates
    }
    
    private func detectCriticalIssues() -> [(issue: CriticalStateIssue, callUUID: UUID?)] {
        var issues: [(CriticalStateIssue, UUID?)] = []
        
        // Detect stuck states
        let stuckStates = detectStuckStates()
        for stuckCallUUID in stuckStates {
            issues.append((.prolongedState, stuckCallUUID))
        }
        
        // Detect high error rate
        if currentMetrics.errorRate > 0.3 {
            issues.append((.highErrorRate, nil))
        }
        
        // Detect state transition loops
        let loopingCalls = detectStateTransitionLoops()
        for loopingCallUUID in loopingCalls {
            issues.append((.stateTransitionLoop, loopingCallUUID))
        }
        
        return issues
    }
    
    private func detectStateTransitionLoops() -> [UUID] {
        var loopingCalls: [UUID] = []
        
        for (callUUID, snapshots) in stateSnapshots {
            let recentSnapshots = snapshots.suffix(10)
            let states = recentSnapshots.map { $0.state }
            
            // Simple loop detection: same state appearing 3+ times in recent history
            let stateCounts = Dictionary(grouping: states) { $0 }.mapValues { $0.count }
            if stateCounts.values.contains(where: { $0 >= 3 }) {
                loopingCalls.append(callUUID)
            }
        }
        
        return loopingCalls
    }
    
    private func generateStateRecommendations() -> [StateRecommendation] {
        var recommendations: [StateRecommendation] = []
        
        // Recommendation for high error rate
        if currentMetrics.errorRate > 0.2 {
            let recommendation = StateRecommendation(
                title: "High Error Rate Detected",
                description: "Multiple CallKit operations are failing. Consider reviewing system configuration.",
                priority: .high,
                actionItems: [
                    "Review CallKit provider configuration",
                    "Check system permissions",
                    "Analyze failure patterns"
                ],
                affectedStates: [.error, .callKitFailed, .backgroundingFailed],
                estimatedImpact: "Reduced call success rate"
            )
            recommendations.append(recommendation)
        }
        
        // Recommendation for performance issues
        if currentMetrics.performanceScore < 0.7 {
            let recommendation = StateRecommendation(
                title: "Performance Degradation",
                description: "State transitions are taking longer than expected.",
                priority: .medium,
                actionItems: [
                    "Monitor system resources",
                    "Optimize state transition logic",
                    "Consider reducing concurrent operations"
                ],
                affectedStates: [.detecting, .backgrounding, .retrying],
                estimatedImpact: "Slower user experience"
            )
            recommendations.append(recommendation)
        }
        
        return recommendations
    }
    
    private func analyzeInvalidTransition(transition: CallUIStateTransition, metadata: [String: Any]) {
        // Analyze patterns in invalid transitions for system improvement
    }
    
    // MARK: - System Observers
    
    private func setupSystemObservers() {
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
    }
    
    private func handleMemoryWarning() {
        analysisQueue.async { [weak self] in
            self?.cleanupOldData()
        }
    }
    
    // MARK: - Cleanup Operations
    
    private func cleanupCallSnapshots(for callUUID: UUID) {
        stateSnapshots.removeValue(forKey: callUUID)
    }
    
    private func cleanupOldData() {
        stateLock.withLock {
            // Keep only recent transitions
            if stateTransitions.count > maxTransitionsToRetain / 2 {
                stateTransitions = Array(stateTransitions.suffix(maxTransitionsToRetain / 2))
            }
            
            // Clean up snapshots for completed calls
            let completedCalls = stateSnapshots.keys.filter { callUUID in
                !activeStates.keys.contains(callUUID)
            }
            
            for callUUID in completedCalls {
                stateSnapshots.removeValue(forKey: callUUID)
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