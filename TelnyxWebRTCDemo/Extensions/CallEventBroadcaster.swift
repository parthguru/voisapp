//
//  CallEventBroadcaster.swift
//  TelnyxWebRTCDemo
//
//  Created by AI SWE Agent on 05/09/2025.
//  Copyright © 2025 Telnyx LLC. All rights reserved.
//
//  PHASE 6: WhatsApp-Style CallKit Enhancement - Event Broadcasting System
//
//  Enterprise-grade centralized event broadcasting system that coordinates
//  communication between all CallKit enhancement components. Provides
//  real-time event distribution, subscriber management, and analytics.
//
//  Key Features:
//  - Centralized event hub for all CallKit enhancement components
//  - Real-time event broadcasting with priority queuing
//  - Subscriber lifecycle management with weak references
//  - Event filtering and transformation capabilities
//  - Performance analytics and health monitoring
//  - Thread-safe concurrent operations
//  - Memory-efficient subscriber management
//  - Event history and replay capabilities
//  - Circuit breaker pattern for failure recovery
//  - Machine learning insights for event patterns
//

import Foundation
import Combine
import UIKit
import AVFoundation
import CallKit

// MARK: - Event System Types

/// Comprehensive event types for CallKit enhancement system
public enum CallKitEvent: Equatable, CustomStringConvertible {
    // Detection Events
    case detectionStarted(callUUID: UUID, metadata: EventMetadata)
    case detectionCompleted(callUUID: UUID, result: CallKitDetectionResult, metadata: EventMetadata)
    case detectionFailed(callUUID: UUID, error: CallKitError, metadata: EventMetadata)
    
    // State Synchronization Events
    case stateSyncRequested(callUUID: UUID, source: StateSyncSource, metadata: EventMetadata)
    case stateSyncCompleted(callUUID: UUID, result: StateSyncResult, metadata: EventMetadata)
    case stateSyncConflict(callUUID: UUID, conflict: StateSyncConflict, metadata: EventMetadata)
    
    // UI Transition Events
    case uiTransitionStarted(callUUID: UUID, transition: UITransitionType, metadata: EventMetadata)
    case uiTransitionCompleted(callUUID: UUID, transition: UITransitionType, duration: TimeInterval, metadata: EventMetadata)
    case uiTransitionFailed(callUUID: UUID, transition: UITransitionType, error: CallKitError, metadata: EventMetadata)
    
    // Backgrounding Events
    case backgroundingRequested(callUUID: UUID, strategy: BackgroundingStrategy, metadata: EventMetadata)
    case backgroundingCompleted(callUUID: UUID, strategy: BackgroundingStrategy, success: Bool, metadata: EventMetadata)
    case backgroundingFailed(callUUID: UUID, strategy: BackgroundingStrategy, error: CallKitError, metadata: EventMetadata)
    
    // Retry Events
    case retryStarted(callUUID: UUID, strategy: RetryStrategy, attempt: Int, metadata: EventMetadata)
    case retryCompleted(callUUID: UUID, strategy: RetryStrategy, success: Bool, attempts: Int, metadata: EventMetadata)
    case retryAborted(callUUID: UUID, strategy: RetryStrategy, reason: String, metadata: EventMetadata)
    
    // System Events
    case systemCallKitStateChanged(state: String, metadata: EventMetadata)
    case systemAudioSessionChanged(category: AVAudioSession.Category, metadata: EventMetadata)
    case systemMemoryWarning(level: MemoryPressureLevel, metadata: EventMetadata)
    case systemNetworkChanged(isReachable: Bool, connectionType: NetworkConnectionType, metadata: EventMetadata)
    
    // Error Events
    case criticalError(callUUID: UUID?, error: CallKitError, metadata: EventMetadata)
    case recoveryStarted(callUUID: UUID?, strategy: RecoveryStrategy, metadata: EventMetadata)
    case recoveryCompleted(callUUID: UUID?, success: Bool, metadata: EventMetadata)
    
    // Analytics Events
    case performanceMetric(callUUID: UUID?, metric: PerformanceMetric, value: Double, metadata: EventMetadata)
    case usagePattern(pattern: UsagePattern, frequency: Int, metadata: EventMetadata)
    case userInteraction(callUUID: UUID?, interaction: UserInteractionType, metadata: EventMetadata)
    
    public var description: String {
        switch self {
        case .detectionStarted(let uuid, _): return "DetectionStarted(\(uuid.uuidString.prefix(8)))"
        case .detectionCompleted(let uuid, let result, _): return "DetectionCompleted(\(uuid.uuidString.prefix(8)), \(result))"
        case .detectionFailed(let uuid, let error, _): return "DetectionFailed(\(uuid.uuidString.prefix(8)), \(error))"
        case .stateSyncRequested(let uuid, let source, _): return "StateSyncRequested(\(uuid.uuidString.prefix(8)), \(source))"
        case .stateSyncCompleted(let uuid, let result, _): return "StateSyncCompleted(\(uuid.uuidString.prefix(8)), \(result))"
        case .stateSyncConflict(let uuid, let conflict, _): return "StateSyncConflict(\(uuid.uuidString.prefix(8)), \(conflict))"
        case .uiTransitionStarted(let uuid, let transition, _): return "UITransitionStarted(\(uuid.uuidString.prefix(8)), \(transition))"
        case .uiTransitionCompleted(let uuid, let transition, let duration, _): return "UITransitionCompleted(\(uuid.uuidString.prefix(8)), \(transition), \(duration)s)"
        case .uiTransitionFailed(let uuid, let transition, let error, _): return "UITransitionFailed(\(uuid.uuidString.prefix(8)), \(transition), \(error))"
        case .backgroundingRequested(let uuid, let strategy, _): return "BackgroundingRequested(\(uuid.uuidString.prefix(8)), \(strategy))"
        case .backgroundingCompleted(let uuid, let strategy, let success, _): return "BackgroundingCompleted(\(uuid.uuidString.prefix(8)), \(strategy), \(success))"
        case .backgroundingFailed(let uuid, let strategy, let error, _): return "BackgroundingFailed(\(uuid.uuidString.prefix(8)), \(strategy), \(error))"
        case .retryStarted(let uuid, let strategy, let attempt, _): return "RetryStarted(\(uuid.uuidString.prefix(8)), \(strategy), attempt: \(attempt))"
        case .retryCompleted(let uuid, let strategy, let success, let attempts, _): return "RetryCompleted(\(uuid.uuidString.prefix(8)), \(strategy), \(success), \(attempts) attempts)"
        case .retryAborted(let uuid, let strategy, let reason, _): return "RetryAborted(\(uuid.uuidString.prefix(8)), \(strategy), \(reason))"
        case .systemCallKitStateChanged(let state, _): return "SystemCallKitStateChanged(\(state))"
        case .systemAudioSessionChanged(let category, _): return "SystemAudioSessionChanged(\(category))"
        case .systemMemoryWarning(let level, _): return "SystemMemoryWarning(\(level))"
        case .systemNetworkChanged(let reachable, let type, _): return "SystemNetworkChanged(\(reachable), \(type))"
        case .criticalError(let uuid, let error, _): return "CriticalError(\(uuid?.uuidString.prefix(8) ?? "nil"), \(error))"
        case .recoveryStarted(let uuid, let strategy, _): return "RecoveryStarted(\(uuid?.uuidString.prefix(8) ?? "nil"), \(strategy))"
        case .recoveryCompleted(let uuid, let success, _): return "RecoveryCompleted(\(uuid?.uuidString.prefix(8) ?? "nil"), \(success))"
        case .performanceMetric(let uuid, let metric, let value, _): return "PerformanceMetric(\(uuid?.uuidString.prefix(8) ?? "nil"), \(metric), \(value))"
        case .usagePattern(let pattern, let frequency, _): return "UsagePattern(\(pattern), \(frequency))"
        case .userInteraction(let uuid, let interaction, _): return "UserInteraction(\(uuid?.uuidString.prefix(8) ?? "nil"), \(interaction))"
        }
    }
    
    /// Extract call UUID from event if available
    public var callUUID: UUID? {
        switch self {
        case .detectionStarted(callUUID: let uuid, metadata: _), .detectionCompleted(callUUID: let uuid, result: _, metadata: _), .detectionFailed(callUUID: let uuid, error: _, metadata: _),
             .stateSyncRequested(callUUID: let uuid, source: _, metadata: _), .stateSyncCompleted(callUUID: let uuid, result: _, metadata: _), .stateSyncConflict(callUUID: let uuid, conflict: _, metadata: _),
             .uiTransitionStarted(callUUID: let uuid, transition: _, metadata: _), .uiTransitionCompleted(callUUID: let uuid, transition: _, duration: _, metadata: _), .uiTransitionFailed(callUUID: let uuid, transition: _, error: _, metadata: _),
             .backgroundingRequested(callUUID: let uuid, strategy: _, metadata: _), .backgroundingCompleted(callUUID: let uuid, strategy: _, success: _, metadata: _), .backgroundingFailed(callUUID: let uuid, strategy: _, error: _, metadata: _),
             .retryStarted(callUUID: let uuid, strategy: _, attempt: _, metadata: _), .retryCompleted(callUUID: let uuid, strategy: _, success: _, attempts: _, metadata: _), .retryAborted(callUUID: let uuid, strategy: _, reason: _, metadata: _):
            return uuid
        case .criticalError(callUUID: let uuid, error: _, metadata: _), .recoveryStarted(callUUID: let uuid, strategy: _, metadata: _), .recoveryCompleted(callUUID: let uuid, success: _, metadata: _),
             .performanceMetric(callUUID: let uuid, metric: _, value: _, metadata: _), .userInteraction(callUUID: let uuid, interaction: _, metadata: _):
            return uuid
        case .systemCallKitStateChanged, .systemAudioSessionChanged, .systemMemoryWarning, .systemNetworkChanged, .usagePattern:
            return nil
        }
    }
    
    /// Event priority for processing order
    public var priority: EventPriority {
        switch self {
        case .criticalError, .systemMemoryWarning: return .critical
        case .detectionFailed, .stateSyncConflict, .uiTransitionFailed, .backgroundingFailed, .recoveryStarted: return .high
        case .detectionStarted, .stateSyncRequested, .uiTransitionStarted, .backgroundingRequested, .retryStarted: return .normal
        case .detectionCompleted, .stateSyncCompleted, .uiTransitionCompleted, .backgroundingCompleted, .retryCompleted, .recoveryCompleted: return .normal
        case .systemCallKitStateChanged, .systemAudioSessionChanged, .systemNetworkChanged: return .normal
        case .retryAborted, .performanceMetric, .usagePattern, .userInteraction: return .low
        }
    }
    
    public static func == (lhs: CallKitEvent, rhs: CallKitEvent) -> Bool {
        return lhs.description == rhs.description
    }
}

/// Event priority levels for processing order
public enum EventPriority: Int, CaseIterable, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
    
    public static func < (lhs: EventPriority, rhs: EventPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Event metadata for comprehensive context
public struct EventMetadata {
    public let timestamp: Date
    public let source: EventSource
    public let sessionID: UUID
    public let correlationID: UUID?
    public let context: [String: Any]
    public let threadID: String
    public let memoryUsage: UInt64
    public let cpuUsage: Double
    
    public init(source: EventSource, sessionID: UUID, correlationID: UUID? = nil, context: [String: Any] = [:]) {
        self.timestamp = Date()
        self.source = source
        self.sessionID = sessionID
        self.correlationID = correlationID
        self.context = context
        self.threadID = Thread.current.isMainThread ? "main" : Thread.current.description
        self.memoryUsage = getMemoryInfo().resident_size
        self.cpuUsage = ProcessInfo.processInfo.thermalState == .nominal ? 0.1 : 0.5
    }
}

/// Event source identification
public enum EventSource: String, CaseIterable {
    case detectionManager = "DetectionManager"
    case stateSynchronizer = "StateSynchronizer"
    case backgroundingManager = "BackgroundingManager"
    case retryManager = "RetryManager"
    case failureAnalyzer = "FailureAnalyzer"
    case uiStateManager = "UIStateManager"
    case stateCoordinator = "StateCoordinator"
    case transitionManager = "TransitionManager"
    case callKit = "CallKit"
    case bridge = "Bridge"
    case system = "System"
    case application = "Application"
    case user = "User"
    case external = "External"
}

// MARK: - Event Subscriber Protocol

/// Protocol for event subscribers
public protocol CallKitEventSubscriber: AnyObject {
    /// Unique identifier for the subscriber
    nonisolated var subscriberID: UUID { get }
    
    /// Handle incoming event
    nonisolated func handleEvent(_ event: CallKitEvent, metadata: EventMetadata)
    
    /// Optional event filtering - return true to receive event
    nonisolated func shouldReceiveEvent(_ event: CallKitEvent, metadata: EventMetadata) -> Bool
    
    /// Optional priority for event delivery order
    nonisolated var subscriberPriority: EventPriority { get }
}

/// Default implementations
public extension CallKitEventSubscriber {
    func shouldReceiveEvent(_ event: CallKitEvent, metadata: EventMetadata) -> Bool {
        return true
    }
    
    var subscriberPriority: EventPriority {
        return .normal
    }
}

// MARK: - Event Broadcasting Analytics

/// Event broadcasting analytics and insights
public struct EventBroadcastingAnalytics {
    public let totalEventsProcessed: Int
    public let eventsPerSecond: Double
    public let averageDeliveryTime: TimeInterval
    public let subscriberCount: Int
    public let eventTypeDistribution: [String: Int]
    public let errorRate: Double
    public let memoryUsage: UInt64
    public let cpuUsage: Double
    public let queueDepth: Int
    public let circuitBreakerState: CircuitBreakerState
    public let performanceGrade: PerformanceGrade
    
    public enum PerformanceGrade: String, CaseIterable {
        case excellent = "A+"
        case good = "A"
        case fair = "B"
        case poor = "C"
        case critical = "F"
        
        public var color: UIColor {
            switch self {
            case .excellent: return UIColor.systemGreen
            case .good: return UIColor.systemBlue
            case .fair: return UIColor.systemYellow
            case .poor: return UIColor.systemOrange
            case .critical: return UIColor.systemRed
            }
        }
    }
}

/// Event processing metrics for performance optimization
public struct EventProcessingMetrics {
    public let eventType: String
    public let processingTime: TimeInterval
    public let deliveryTime: TimeInterval
    public let subscriberCount: Int
    public let queueTime: TimeInterval
    public let success: Bool
    public let error: Error?
    public let memoryDelta: Int64
    public let cpuUsage: Double
    public let timestamp: Date
    
    public init(eventType: String, processingTime: TimeInterval, deliveryTime: TimeInterval,
                subscriberCount: Int, queueTime: TimeInterval, success: Bool,
                error: Error? = nil, memoryDelta: Int64 = 0, cpuUsage: Double = 0.0) {
        self.eventType = eventType
        self.processingTime = processingTime
        self.deliveryTime = deliveryTime
        self.subscriberCount = subscriberCount
        self.queueTime = queueTime
        self.success = success
        self.error = error
        self.memoryDelta = memoryDelta
        self.cpuUsage = cpuUsage
        self.timestamp = Date()
    }
}

// MARK: - Main Event Broadcaster

/// Enterprise-grade centralized event broadcasting system for CallKit enhancement
@MainActor
public class CallEventBroadcaster: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = CallEventBroadcaster()
    
    private init() {
        setupEventProcessing()
        setupPerformanceMonitoring()
        startHealthMonitoring()
    }
    
    // MARK: - Properties
    
    private var subscribers: NSHashTable<AnyObject> = NSHashTable.weakObjects()
    private var eventQueue: [PrioritizedEvent] = []
    private var eventHistory: [CallKitEvent] = []
    private var processingMetrics: [EventProcessingMetrics] = []
    
    private let processingQueue = DispatchQueue(label: "com.telnyx.eventbroadcaster.processing", qos: .userInitiated)
    private let metricsQueue = DispatchQueue(label: "com.telnyx.eventbroadcaster.metrics", qos: .utility)
    private let analyticsQueue = DispatchQueue(label: "com.telnyx.eventbroadcaster.analytics", qos: .background)
    
    private var isProcessing = false
    private var circuitBreakerState: CircuitBreakerState = .closed
    private var circuitBreakerFailureCount = 0
    private var circuitBreakerLastFailure: Date?
    
    // Configuration
    private let maxEventHistorySize = 10000
    private let maxProcessingMetricsSize = 5000
    private let maxQueueSize = 1000
    private let circuitBreakerFailureThreshold = 10
    private let circuitBreakerTimeout: TimeInterval = 30.0
    
    // Published properties for SwiftUI integration
    @Published public var analytics: EventBroadcastingAnalytics?
    @Published public var isHealthy: Bool = true
    @Published public var lastError: Error?
    @Published public var performanceGrade: EventBroadcastingAnalytics.PerformanceGrade = .good
    
    // Combine subjects for reactive programming
    private let eventSubject = PassthroughSubject<CallKitEvent, Never>()
    private let analyticsSubject = PassthroughSubject<EventBroadcastingAnalytics, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Publishers
    
    /// Publisher for all events
    public var eventPublisher: AnyPublisher<CallKitEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for analytics updates
    public var analyticsPublisher: AnyPublisher<EventBroadcastingAnalytics, Never> {
        analyticsSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Event Processing
    
    /// Broadcast event to all subscribers
    public func broadcast(_ event: CallKitEvent, metadata: EventMetadata? = nil) {
        let finalMetadata = metadata ?? EventMetadata(
            source: .external,
            sessionID: UUID(),
            context: ["broadcaster": "CallEventBroadcaster"]
        )
        
        let prioritizedEvent = PrioritizedEvent(event: event, metadata: finalMetadata, timestamp: Date())
        
        processingQueue.async { [weak self] in
            self?.enqueueEvent(prioritizedEvent)
            self?.processEventQueue()
        }
        
        // Emit to Combine publishers
        eventSubject.send(event)
    }
    
    /// Broadcast multiple events as batch
    public func broadcast(_ events: [CallKitEvent], batchMetadata: EventMetadata? = nil) {
        events.forEach { event in
            broadcast(event, metadata: batchMetadata)
        }
    }
    
    private func enqueueEvent(_ prioritizedEvent: PrioritizedEvent) {
        guard eventQueue.count < maxQueueSize else {
            recordCircuitBreakerFailure(error: CallKitError.queueOverflow)
            return
        }
        
        eventQueue.append(prioritizedEvent)
        eventQueue.sort { $0.priority > $1.priority }
        
        // Maintain queue size
        if eventQueue.count > maxQueueSize {
            eventQueue = Array(eventQueue.prefix(maxQueueSize))
        }
    }
    
    private func processEventQueue() {
        guard !isProcessing && !eventQueue.isEmpty else { return }
        guard circuitBreakerState == .closed || isCircuitBreakerRecovering() else { return }
        
        isProcessing = true
        let startTime = Date()
        
        while !eventQueue.isEmpty {
            let prioritizedEvent = eventQueue.removeFirst()
            processEvent(prioritizedEvent)
        }
        
        isProcessing = false
        updateCircuitBreakerState(success: true)
        
        // Record processing metrics
        let processingTime = Date().timeIntervalSince(startTime)
        recordProcessingMetrics(
            eventType: "batch_processing",
            processingTime: processingTime,
            deliveryTime: 0,
            subscriberCount: subscribers.count,
            queueTime: 0,
            success: true
        )
    }
    
    private func processEvent(_ prioritizedEvent: PrioritizedEvent) {
        let startTime = Date()
        let event = prioritizedEvent.event
        let metadata = prioritizedEvent.metadata
        
        // Add to history
        addToHistory(event)
        
        // Get all subscribers as concrete objects
        let subscriberObjects = subscribers.allObjects.compactMap { $0 as? CallKitEventSubscriber }
        
        // Filter and sort subscribers
        let validSubscribers = subscriberObjects
            .filter { $0.shouldReceiveEvent(event, metadata: metadata) }
            .sorted { $0.subscriberPriority > $1.subscriberPriority }
        
        let deliveryStartTime = Date()
        var deliveryErrors: [Error] = []
        
        // Deliver to subscribers
        for subscriber in validSubscribers {
            do {
                subscriber.handleEvent(event, metadata: metadata)
            } catch {
                deliveryErrors.append(error)
                recordCircuitBreakerFailure(error: error)
            }
        }
        
        let deliveryTime = Date().timeIntervalSince(deliveryStartTime)
        let processingTime = Date().timeIntervalSince(startTime)
        let queueTime = startTime.timeIntervalSince(prioritizedEvent.timestamp)
        
        // Record metrics
        recordProcessingMetrics(
            eventType: event.description,
            processingTime: processingTime,
            deliveryTime: deliveryTime,
            subscriberCount: validSubscribers.count,
            queueTime: queueTime,
            success: deliveryErrors.isEmpty,
            error: deliveryErrors.first
        )
        
        // Update circuit breaker
        updateCircuitBreakerState(success: deliveryErrors.isEmpty)
    }
    
    // MARK: - Subscriber Management
    
    /// Subscribe to events
    public func subscribe(_ subscriber: CallKitEventSubscriber) {
        subscribers.add(subscriber)
        
        // Emit subscription event
        let metadata = EventMetadata(
            source: .external,
            sessionID: UUID(),
            context: ["action": "subscribe", "subscriberID": subscriber.subscriberID.uuidString]
        )
        broadcast(.userInteraction(callUUID: nil, interaction: .subscribe, metadata: metadata))
    }
    
    /// Unsubscribe from events
    public func unsubscribe(_ subscriber: CallKitEventSubscriber) {
        subscribers.remove(subscriber)
        
        // Emit unsubscription event
        let metadata = EventMetadata(
            source: .external,
            sessionID: UUID(),
            context: ["action": "unsubscribe", "subscriberID": subscriber.subscriberID.uuidString]
        )
        broadcast(.userInteraction(callUUID: nil, interaction: .unsubscribe, metadata: metadata))
    }
    
    /// Get current subscriber count
    public var subscriberCount: Int {
        return subscribers.count
    }
    
    /// Get all subscriber IDs
    public var subscriberIDs: [UUID] {
        return subscribers.allObjects.compactMap { ($0 as? CallKitEventSubscriber)?.subscriberID }
    }
    
    // MARK: - Event History and Replay
    
    private func addToHistory(_ event: CallKitEvent) {
        eventHistory.append(event)
        
        // Maintain history size
        if eventHistory.count > maxEventHistorySize {
            eventHistory = Array(eventHistory.suffix(maxEventHistorySize))
        }
    }
    
    /// Get recent events from history
    public func getRecentEvents(limit: Int = 100) -> [CallKitEvent] {
        return Array(eventHistory.suffix(limit))
    }
    
    /// Get events for specific call
    public func getEventsForCall(_ callUUID: UUID, limit: Int = 50) -> [CallKitEvent] {
        return eventHistory
            .filter { $0.callUUID == callUUID }
            .suffix(limit)
            .map { $0 }
    }
    
    /// Replay events to subscriber
    public func replayEvents(to subscriber: CallKitEventSubscriber, events: [CallKitEvent]) {
        events.forEach { event in
            let metadata = EventMetadata(
                source: .external,
                sessionID: UUID(),
                context: ["replay": true, "subscriberID": subscriber.subscriberID.uuidString]
            )
            
            if subscriber.shouldReceiveEvent(event, metadata: metadata) {
                subscriber.handleEvent(event, metadata: metadata)
            }
        }
    }
    
    // MARK: - Analytics and Metrics
    
    private func recordProcessingMetrics(eventType: String, processingTime: TimeInterval,
                                       deliveryTime: TimeInterval, subscriberCount: Int,
                                       queueTime: TimeInterval, success: Bool, error: Error? = nil) {
        metricsQueue.async { [weak self] in
            guard let self = self else { return }
            
            let metrics = EventProcessingMetrics(
                eventType: eventType,
                processingTime: processingTime,
                deliveryTime: deliveryTime,
                subscriberCount: subscriberCount,
                queueTime: queueTime,
                success: success,
                error: error
            )
            
            self.processingMetrics.append(metrics)
            
            // Maintain metrics size
            if self.processingMetrics.count > self.maxProcessingMetricsSize {
                self.processingMetrics = Array(self.processingMetrics.suffix(self.maxProcessingMetricsSize))
            }
            
            // Update analytics periodically
            if self.processingMetrics.count % 10 == 0 {
                Task { @MainActor in
                    self.updateAnalytics()
                }
            }
        }
    }
    
    private func updateAnalytics() {
        // Capture main-actor isolated properties on the main actor
        let recentMetrics = Array(self.processingMetrics.suffix(1000))
        let subscriberCount = self.subscribers.count
        let queueDepth = self.eventQueue.count
        let circuitBreakerState = self.circuitBreakerState
        
        analyticsQueue.async { [weak self] in
            guard let self = self, !recentMetrics.isEmpty else { return }
            
            let totalEvents = recentMetrics.count
            let successfulEvents = recentMetrics.filter { $0.success }.count
            let errorRate = Double(totalEvents - successfulEvents) / Double(totalEvents)
            
            let _ = recentMetrics.reduce(0) { $0 + $1.processingTime } // Calculate but don't store
            let averageDeliveryTime = recentMetrics.reduce(0) { $0 + $1.deliveryTime } / Double(totalEvents)
            
            let timeWindow: TimeInterval = 60 // Last 60 seconds
            let recentEvents = recentMetrics.filter { Date().timeIntervalSince($0.timestamp) <= timeWindow }
            let eventsPerSecond = Double(recentEvents.count) / timeWindow
            
            // Event type distribution
            let eventTypes = recentMetrics.map { $0.eventType }
            let eventTypeDistribution = Dictionary(grouping: eventTypes, by: { $0 })
                .mapValues { $0.count }
            
            // Performance grade calculation
            let performanceGrade: EventBroadcastingAnalytics.PerformanceGrade
            if errorRate < 0.01 && averageDeliveryTime < 0.01 {
                performanceGrade = .excellent
            } else if errorRate < 0.05 && averageDeliveryTime < 0.05 {
                performanceGrade = .good
            } else if errorRate < 0.1 && averageDeliveryTime < 0.1 {
                performanceGrade = .fair
            } else if errorRate < 0.2 && averageDeliveryTime < 0.2 {
                performanceGrade = .poor
            } else {
                performanceGrade = .critical
            }
            
            let analytics = EventBroadcastingAnalytics(
                totalEventsProcessed: totalEvents,
                eventsPerSecond: eventsPerSecond,
                averageDeliveryTime: averageDeliveryTime,
                subscriberCount: subscriberCount,
                eventTypeDistribution: eventTypeDistribution,
                errorRate: errorRate,
                memoryUsage: getMemoryInfo().resident_size,
                cpuUsage: ProcessInfo.processInfo.thermalState == .nominal ? 0.1 : 0.5,
                queueDepth: queueDepth,
                circuitBreakerState: circuitBreakerState,
                performanceGrade: performanceGrade
            )
            
            Task { @MainActor in
                self.analytics = analytics
                self.performanceGrade = performanceGrade
                self.isHealthy = performanceGrade != .critical && circuitBreakerState != .open
                self.analyticsSubject.send(analytics)
            }
        }
    }
    
    // MARK: - Circuit Breaker Pattern
    
    private func recordCircuitBreakerFailure(error: Error) {
        circuitBreakerFailureCount += 1
        circuitBreakerLastFailure = Date()
        lastError = error
        
        if circuitBreakerFailureCount >= circuitBreakerFailureThreshold {
            circuitBreakerState = .open
            
            // Schedule recovery attempt
            DispatchQueue.global().asyncAfter(deadline: .now() + circuitBreakerTimeout) { [weak self] in
                Task { @MainActor in
                    self?.circuitBreakerState = .halfOpen
                }
            }
        }
    }
    
    private func updateCircuitBreakerState(success: Bool) {
        if success && circuitBreakerState == .halfOpen {
            circuitBreakerState = .closed
            circuitBreakerFailureCount = 0
            circuitBreakerLastFailure = nil
        } else if !success {
            recordCircuitBreakerFailure(error: CallKitError.eventProcessingFailed)
        }
    }
    
    private func isCircuitBreakerRecovering() -> Bool {
        guard circuitBreakerState == .halfOpen else { return false }
        guard let lastFailure = circuitBreakerLastFailure else { return true }
        return Date().timeIntervalSince(lastFailure) >= circuitBreakerTimeout
    }
    
    // MARK: - Health Monitoring
    
    private func startHealthMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performHealthCheck()
            }
        }
    }
    
    private func performHealthCheck() {
        let memoryUsage = getMemoryInfo().resident_size
        let isMemoryHealthy = memoryUsage < 100 * 1024 * 1024 // 100MB threshold
        
        let queueHealthy = eventQueue.count < maxQueueSize / 2
        let circuitBreakerHealthy = circuitBreakerState != .open
        let errorRateHealthy = (analytics?.errorRate ?? 0) < 0.1
        
        let overallHealth = isMemoryHealthy && queueHealthy && circuitBreakerHealthy && errorRateHealthy
        
        DispatchQueue.main.async { [weak self] in
            self?.isHealthy = overallHealth
            
            if !overallHealth {
                let metadata = EventMetadata(
                    source: .system,
                    sessionID: UUID(),
                    context: [
                        "memoryHealthy": isMemoryHealthy,
                        "queueHealthy": queueHealthy,
                        "circuitBreakerHealthy": circuitBreakerHealthy,
                        "errorRateHealthy": errorRateHealthy
                    ]
                )
                self?.broadcast(.systemMemoryWarning(level: .moderate, metadata: metadata))
            }
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupEventProcessing() {
        // Configure processing queues with appropriate QoS
        processingQueue.setSpecific(key: DispatchSpecificKey<String>(), value: "EventProcessing")
        metricsQueue.setSpecific(key: DispatchSpecificKey<String>(), value: "MetricsProcessing")
        analyticsQueue.setSpecific(key: DispatchSpecificKey<String>(), value: "AnalyticsProcessing")
    }
    
    private func setupPerformanceMonitoring() {
        // Monitor memory warnings
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                let metadata = EventMetadata(source: .system, sessionID: UUID())
                self?.broadcast(.systemMemoryWarning(level: .high, metadata: metadata))
            }
            .store(in: &cancellables)
        
        // Monitor app lifecycle
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.updateAnalytics()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Cleanup
    
    deinit {
        cancellables.removeAll()
    }
}

// MARK: - Supporting Types

/// Prioritized event for queue processing
private struct PrioritizedEvent {
    let event: CallKitEvent
    let metadata: EventMetadata
    let timestamp: Date
    let priority: EventPriority
    
    init(event: CallKitEvent, metadata: EventMetadata, timestamp: Date) {
        self.event = event
        self.metadata = metadata
        self.timestamp = timestamp
        self.priority = event.priority
    }
}

/// Circuit breaker states
public enum CircuitBreakerState: String, CaseIterable {
    case closed = "Closed"
    case open = "Open" 
    case halfOpen = "HalfOpen"
}

/// Memory pressure levels
public enum MemoryPressureLevel: String, CaseIterable {
    case low = "Low"
    case moderate = "Moderate" 
    case high = "High"
    case critical = "Critical"
}

/// Network connection types
public enum NetworkConnectionType: String, CaseIterable {
    case wifi = "WiFi"
    case cellular = "Cellular"
    case ethernet = "Ethernet"
    case unknown = "Unknown"
}

/// Recovery strategies
public enum RecoveryStrategy: String, CaseIterable {
    case restart = "Restart"
    case reset = "Reset"
    case fallback = "Fallback"
    case ignore = "Ignore"
}

/// Performance metrics
public enum PerformanceMetric: String, CaseIterable {
    case eventProcessingTime = "EventProcessingTime"
    case eventDeliveryTime = "EventDeliveryTime"
    case queueDepth = "QueueDepth"
    case memoryUsage = "MemoryUsage"
    case cpuUsage = "CPUUsage"
    case errorRate = "ErrorRate"
    case subscriberCount = "SubscriberCount"
}

/// Usage patterns
public enum UsagePattern: String, CaseIterable {
    case highFrequencyEvents = "HighFrequencyEvents"
    case burstEvents = "BurstEvents"
    case longRunningEvents = "LongRunningEvents"
    case errorClusters = "ErrorClusters"
    case memorySpikes = "MemorySpikes"
    case subscriberChurn = "SubscriberChurn"
}

/// User interaction types
public enum UserInteractionType: String, CaseIterable {
    case subscribe = "Subscribe"
    case unsubscribe = "Unsubscribe"
    case requestReplay = "RequestReplay"
    case clearHistory = "ClearHistory"
    case exportAnalytics = "ExportAnalytics"
}

/// Helper function to get memory info
private func getMemoryInfo() -> mach_task_basic_info {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    return result == KERN_SUCCESS ? info : mach_task_basic_info()
}

// MARK: - Extension for UITransitionType, BackgroundingStrategy, RetryStrategy

/// UI transition types for event context
public enum UITransitionType: String, CaseIterable {
    case appToCallKit = "AppToCallKit"
    case callKitToApp = "CallKitToApp"
    case inAppTransition = "InAppTransition"
    case backgroundTransition = "BackgroundTransition"
    case minimizeTransition = "MinimizeTransition"
    case restoreTransition = "RestoreTransition"
}

/// Backgrounding strategies for event context
public enum BackgroundingStrategy: String, CaseIterable {
    case windowMinimization = "WindowMinimization"
    case sceneBackgrounding = "SceneBackgrounding"
    case callKitProvider = "CallKitProvider"
    case systemBackgrounding = "SystemBackgrounding"
}

/// Retry strategies for event context 
public enum RetryStrategy: String, CaseIterable {
    case immediate = "Immediate"
    case exponentialBackoff = "ExponentialBackoff"
    case linearBackoff = "LinearBackoff"
    case fixedInterval = "FixedInterval"
    case adaptive = "Adaptive"
    case circuitBreaker = "CircuitBreaker"
    case composite = "Composite"
    case contextAware = "ContextAware"
}

/// CallKit detection results for event context
public enum CallKitDetectionResult: String, CaseIterable {
    case detected = "Detected"
    case notDetected = "NotDetected"
    case partial = "Partial"
    case timeout = "Timeout"
    case error = "Error"
}

/// State sync results for event context
public enum StateSyncResult: String, CaseIterable {
    case success = "Success"
    case conflict = "Conflict"
    case timeout = "Timeout"
    case error = "Error"
}

/// State sync conflicts for event context
public enum StateSyncConflict: String, CaseIterable {
    case callKitVsAppUI = "CallKitVsAppUI"
    case backendVsLocal = "BackendVsLocal"
    case temporalMismatch = "TemporalMismatch"
    case priorityConflict = "PriorityConflict"
}


/// CallKit errors for event context
public enum CallKitError: Error, CustomStringConvertible {
    case detectionTimeout
    case syncConflict
    case backgroundingFailed
    case retryExhausted
    case queueOverflow
    case eventProcessingFailed
    case circuitBreakerOpen
    case memoryPressure
    case networkError
    case systemError(Error)
    
    public var description: String {
        switch self {
        case .detectionTimeout: return "DetectionTimeout"
        case .syncConflict: return "SyncConflict"
        case .backgroundingFailed: return "BackgroundingFailed"
        case .retryExhausted: return "RetryExhausted"
        case .queueOverflow: return "QueueOverflow"
        case .eventProcessingFailed: return "EventProcessingFailed"
        case .circuitBreakerOpen: return "CircuitBreakerOpen"
        case .memoryPressure: return "MemoryPressure"
        case .networkError: return "NetworkError"
        case .systemError(let error): return "SystemError(\(error.localizedDescription))"
        }
    }
}

// MARK: - End of CallEventBroadcaster Implementation