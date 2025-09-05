//
//  CallKitDetectionManager.swift
//  TelnyxWebRTCDemo
//
//  Enhanced CallKit Detection System - WhatsApp-Style Implementation
//  Detects iOS 18+ CallKit presentation issues and enables intelligent fallbacks
//
//  Created by Claude Code on 04/09/2025.
//

import Foundation
import CallKit
import UIKit
import Combine
import os.log

// MARK: - CallKit Detection Protocols

/// Protocol for CallKit detection state communication
protocol CallKitDetectionDelegate: AnyObject {
    /// Called when CallKit UI state changes
    func callKitDetectionManager(_ manager: CallKitDetectionManager, didDetectStateChange state: CallKitUIState, for callUUID: UUID)
    
    /// Called when detection completes (success or failure)
    func callKitDetectionManager(_ manager: CallKitDetectionManager, didCompleteDetection result: CallKitDetectionResult, for callUUID: UUID)
    
    /// Called when detection encounters an error
    func callKitDetectionManager(_ manager: CallKitDetectionManager, didEncounterError error: CallKitDetectionError, for callUUID: UUID)
}

/// CallKit UI presentation states
enum CallKitUIState: String, CaseIterable {
    case unknown = "unknown"
    case callKitActive = "callkit_active"          // CallKit is handling UI
    case appUIActive = "app_ui_active"             // App is handling UI
    case transitioning = "transitioning"           // Switching between UIs
    case failed = "failed"                         // CallKit failed to present
    case systemBusy = "system_busy"                // System is handling other calls
    
    var isActive: Bool {
        return self == .callKitActive
    }
    
    var isStable: Bool {
        return [.callKitActive, .appUIActive, .failed].contains(self)
    }
}

/// Detection result with comprehensive information
struct CallKitDetectionResult {
    let callUUID: UUID
    let finalState: CallKitUIState
    let detectionDuration: TimeInterval
    let attemptCount: Int
    let systemCallCount: Int
    let appState: UIApplication.State
    let timestamp: Date
    let metadata: [String: Any]
    
    var wasSuccessful: Bool {
        return finalState.isActive
    }
    
    var shouldRetry: Bool {
        return !finalState.isStable && attemptCount < CallKitDetectionConfiguration.maxDetectionAttempts
    }
}

/// Detection errors with specific error codes
enum CallKitDetectionError: Error, LocalizedError {
    case invalidCallUUID
    case systemCallObserverUnavailable
    case detectionTimeout
    case concurrentDetectionLimit
    case appStateInconsistent
    case memoryPressure
    
    var errorDescription: String? {
        switch self {
        case .invalidCallUUID:
            return "Invalid or nil call UUID provided"
        case .systemCallObserverUnavailable:
            return "CXCallObserver unavailable - CallKit framework issue"
        case .detectionTimeout:
            return "CallKit detection timed out after maximum duration"
        case .concurrentDetectionLimit:
            return "Maximum concurrent detection sessions exceeded"
        case .appStateInconsistent:
            return "App lifecycle state inconsistent during detection"
        case .memoryPressure:
            return "Detection suspended due to memory pressure"
        }
    }
}

// MARK: - Configuration

/// Thread-safe configuration for CallKit detection
struct CallKitDetectionConfiguration {
    static let detectionInterval: TimeInterval = 0.75        // 750ms intervals for responsive detection
    static let maxDetectionDuration: TimeInterval = 4.0     // 4 seconds maximum detection time
    static let maxDetectionAttempts: Int = 6                // Maximum detection cycles
    static let maxConcurrentDetections: Int = 3             // Maximum concurrent call detections
    static let backgroundGracePeriod: TimeInterval = 0.5    // Grace period for app backgrounding
    static let systemCallCheckDelay: TimeInterval = 0.2     // Delay before checking system calls
    
    // iOS version-specific adjustments
    static var adjustedDetectionInterval: TimeInterval {
        if #available(iOS 18.0, *) {
            return 0.6  // Faster detection for iOS 18+ due to UI lag
        }
        return detectionInterval
    }
}

// MARK: - Main Detection Manager

/// Enterprise-grade CallKit detection manager with WhatsApp-style intelligence
@objc final class CallKitDetectionManager: NSObject, ObservableObject {
    
    // MARK: - Public Properties
    
    weak var delegate: CallKitDetectionDelegate?
    
    /// Current detection states for all monitored calls
    @Published private(set) var detectionStates: [UUID: CallKitUIState] = [:]
    
    /// Overall detection statistics
    @Published private(set) var detectionStatistics: CallKitDetectionStatistics = .init()
    
    // MARK: - Private Properties
    
    /// Thread-safe call observer for system call monitoring
    private let callObserver = CXCallObserver()
    
    /// Serial queue for all detection operations
    private let detectionQueue = DispatchQueue(label: "com.telnyx.callkit.detection", qos: .userInteractive)
    
    /// Main queue for delegate callbacks and UI updates
    private let delegateQueue = DispatchQueue.main
    
    /// Active detection timers by call UUID
    private var detectionTimers: [UUID: Timer] = [:]
    
    /// Detection start timestamps for duration calculation
    private var detectionStartTimes: [UUID: Date] = [:]
    
    /// Detection attempt counters
    private var detectionAttempts: [UUID: Int] = [:]
    
    /// App lifecycle state monitoring
    private var appStateObserver: NSObjectProtocol?
    
    /// Memory pressure monitoring
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    
    /// Combine cancellables for reactive programming
    private var cancellables = Set<AnyCancellable>()
    
    /// Logging subsystem for comprehensive debugging
    private let logger = Logger(subsystem: "com.telnyx.webrtc.callkit", category: "detection")
    
    /// Thread-safe state management
    private let stateLock = NSLock()
    
    /// Detection session management
    private var activeSessions: Set<UUID> = []
    
    // MARK: - Singleton Pattern
    
    static let shared = CallKitDetectionManager()
    
    override init() {
        super.init()
        setupDetectionSystem()
    }
    
    // MARK: - Setup & Configuration
    
    private func setupDetectionSystem() {
        logger.info("🔍 Initializing CallKit Detection System v2.0")
        
        // Configure call observer
        callObserver.setDelegate(self, queue: detectionQueue)
        
        // Setup app lifecycle monitoring
        setupAppLifecycleMonitoring()
        
        // Setup memory pressure monitoring
        setupMemoryPressureMonitoring()
        
        // Setup performance monitoring
        setupPerformanceMonitoring()
        
        logger.info("✅ CallKit Detection System initialized successfully")
    }
    
    private func setupAppLifecycleMonitoring() {
        appStateObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppDidEnterBackground()
        }
    }
    
    private func setupMemoryPressureMonitoring() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: .warning, queue: detectionQueue)
        memoryPressureSource?.setEventHandler { [weak self] in
            self?.handleMemoryPressure()
        }
        memoryPressureSource?.resume()
    }
    
    private func setupPerformanceMonitoring() {
        // Monitor detection performance and adjust parameters dynamically
        $detectionStatistics
            .sink { [weak self] stats in
                self?.adjustDetectionParametersBasedOnPerformance(stats)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Detection Interface
    
    /// Starts CallKit UI detection for a specific call
    /// - Parameters:
    ///   - callUUID: UUID of the call to monitor
    ///   - metadata: Additional context information
    /// - Returns: Boolean indicating if detection was started successfully
    @discardableResult
    func startDetection(for callUUID: UUID, metadata: [String: Any] = [:]) -> Bool {
        return stateLock.withLock {
            logger.info("🔍 Starting CallKit detection for call: \(callUUID)")
            
            // Validate preconditions
            guard validateDetectionPreconditions(for: callUUID) else {
                return false
            }
            
            // Initialize detection state
            initializeDetectionState(for: callUUID, metadata: metadata)
            
            // Start detection timer
            startDetectionTimer(for: callUUID)
            
            return true
        }
    }
    
    /// Stops CallKit detection for a specific call
    /// - Parameter callUUID: UUID of the call to stop monitoring
    func stopDetection(for callUUID: UUID) {
        stateLock.withLock {
            logger.info("🛑 Stopping CallKit detection for call: \(callUUID)")
            
            cleanupDetectionSession(for: callUUID)
            updateDetectionStatistics(for: callUUID, completed: false)
        }
    }
    
    /// Gets current detection state for a call
    /// - Parameter callUUID: UUID of the call
    /// - Returns: Current CallKitUIState or nil if not being monitored
    func getCurrentState(for callUUID: UUID) -> CallKitUIState? {
        return stateLock.withLock {
            return detectionStates[callUUID]
        }
    }
    
    /// Forces immediate detection check for debugging
    /// - Parameter callUUID: UUID of the call to check
    /// - Returns: Current detection result
    func performImmediateDetection(for callUUID: UUID) -> CallKitDetectionResult? {
        return stateLock.withLock {
            logger.debug("⚡ Performing immediate detection for call: \(callUUID)")
            return performDetectionCheck(for: callUUID)
        }
    }
    
    // MARK: - Detection Logic
    
    private func validateDetectionPreconditions(for callUUID: UUID) -> Bool {
        // Check concurrent detection limit
        guard activeSessions.count < CallKitDetectionConfiguration.maxConcurrentDetections else {
            notifyError(.concurrentDetectionLimit, for: callUUID)
            return false
        }
        
        // Validate call UUID
        guard !callUUID.uuidString.isEmpty else {
            notifyError(.invalidCallUUID, for: callUUID)
            return false
        }
        
        // Check if already monitoring this call
        if activeSessions.contains(callUUID) {
            logger.warning("⚠️ Already monitoring call: \(callUUID)")
            return false
        }
        
        return true
    }
    
    private func initializeDetectionState(for callUUID: UUID, metadata: [String: Any]) {
        activeSessions.insert(callUUID)
        detectionStates[callUUID] = .transitioning
        detectionStartTimes[callUUID] = Date()
        detectionAttempts[callUUID] = 0
        
        // Notify initial state
        notifyStateChange(.transitioning, for: callUUID)
    }
    
    private func startDetectionTimer(for callUUID: UUID) {
        detectionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let timer = Timer.scheduledTimer(withTimeInterval: CallKitDetectionConfiguration.adjustedDetectionInterval, repeats: true) { [weak self] _ in
                self?.handleDetectionTimer(for: callUUID)
            }
            
            RunLoop.current.add(timer, forMode: .common)
            
            DispatchQueue.main.async {
                self.detectionTimers[callUUID] = timer
            }
            
            // Initial detection check after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + CallKitDetectionConfiguration.systemCallCheckDelay) {
                self.handleDetectionTimer(for: callUUID)
            }
        }
    }
    
    private func handleDetectionTimer(for callUUID: UUID) {
        stateLock.withLock {
            guard activeSessions.contains(callUUID) else { return }
            
            // Increment attempt counter
            detectionAttempts[callUUID, default: 0] += 1
            
            // Check for timeout
            if let startTime = detectionStartTimes[callUUID],
               Date().timeIntervalSince(startTime) > CallKitDetectionConfiguration.maxDetectionDuration {
                handleDetectionTimeout(for: callUUID)
                return
            }
            
            // Check for max attempts
            if detectionAttempts[callUUID, default: 0] >= CallKitDetectionConfiguration.maxDetectionAttempts {
                handleDetectionMaxAttempts(for: callUUID)
                return
            }
            
            // Perform detection check
            if let result = performDetectionCheck(for: callUUID) {
                processDetectionResult(result)
            }
        }
    }
    
    private func performDetectionCheck(for callUUID: UUID) -> CallKitDetectionResult? {
        let timestamp = Date()
        let appState = UIApplication.shared.applicationState
        let systemCalls = callObserver.calls
        let systemCallCount = systemCalls.count
        
        // Determine current state using multiple detection methods
        let detectedState = determineCallKitState(
            callUUID: callUUID,
            appState: appState,
            systemCalls: systemCalls
        )
        
        // Calculate detection duration
        let detectionDuration = detectionStartTimes[callUUID].map { timestamp.timeIntervalSince($0) } ?? 0
        
        // Create comprehensive result
        let result = CallKitDetectionResult(
            callUUID: callUUID,
            finalState: detectedState,
            detectionDuration: detectionDuration,
            attemptCount: detectionAttempts[callUUID] ?? 0,
            systemCallCount: systemCallCount,
            appState: appState,
            timestamp: timestamp,
            metadata: createDetectionMetadata(for: callUUID, state: detectedState)
        )
        
        logger.debug("🔍 Detection check - Call: \(callUUID), State: \(detectedState), App: \(appState), Calls: \(systemCallCount)")
        
        return result
    }
    
    private func determineCallKitState(callUUID: UUID, appState: UIApplication.State, systemCalls: [CXCall]) -> CallKitUIState {
        // Method 1: App background state indicates CallKit is active
        if appState == .background && hasActiveSystemCall(callUUID: callUUID, systemCalls: systemCalls) {
            return .callKitActive
        }
        
        // Method 2: App in foreground but system call exists suggests iOS 18 issue
        if appState == .active && hasActiveSystemCall(callUUID: callUUID, systemCalls: systemCalls) {
            // Additional checks for iOS 18+ behavior
            if #available(iOS 18.0, *) {
                return analyzeIOS18CallKitState(callUUID: callUUID, systemCalls: systemCalls)
            } else {
                return .failed  // Pre-iOS 18 should background automatically
            }
        }
        
        // Method 3: No system call found
        if !hasActiveSystemCall(callUUID: callUUID, systemCalls: systemCalls) {
            return .failed
        }
        
        // Method 4: System busy with other calls
        if systemCalls.count > 1 {
            return .systemBusy
        }
        
        return .unknown
    }
    
    @available(iOS 18.0, *)
    private func analyzeIOS18CallKitState(callUUID: UUID, systemCalls: [CXCall]) -> CallKitUIState {
        // iOS 18 specific detection logic
        let targetCall = systemCalls.first { $0.uuid == callUUID }
        
        guard let call = targetCall else {
            return .failed
        }
        
        // Check if call is in connecting or connected state
        if call.hasConnected {
            // Connected calls that keep app in foreground indicate iOS 18 issue
            return .failed
        }
        
        if !call.hasEnded && !call.isOutgoing {
            // Incoming calls that don't background app indicate iOS 18 issue
            return .failed
        }
        
        return .transitioning
    }
    
    private func hasActiveSystemCall(callUUID: UUID, systemCalls: [CXCall]) -> Bool {
        return systemCalls.contains { call in
            call.uuid == callUUID && !call.hasEnded
        }
    }
    
    private func createDetectionMetadata(for callUUID: UUID, state: CallKitUIState) -> [String: Any] {
        var metadata: [String: Any] = [:]
        
        metadata["ios_version"] = UIDevice.current.systemVersion
        metadata["device_model"] = UIDevice.current.model
        metadata["detection_method_version"] = "2.0"
        metadata["timestamp"] = Date().timeIntervalSince1970
        
        if #available(iOS 18.0, *) {
            metadata["ios18_detection"] = true
        }
        
        return metadata
    }
    
    // MARK: - Detection Event Handling
    
    private func processDetectionResult(_ result: CallKitDetectionResult) {
        let callUUID = result.callUUID
        let newState = result.finalState
        
        // Update internal state
        let previousState = detectionStates[callUUID] ?? .unknown
        detectionStates[callUUID] = newState
        
        // Notify state change if different
        if newState != previousState {
            notifyStateChange(newState, for: callUUID)
        }
        
        // Handle stable states (detection complete)
        if newState.isStable {
            completeDetection(with: result)
        }
    }
    
    private func completeDetection(with result: CallKitDetectionResult) {
        let callUUID = result.callUUID
        
        logger.info("✅ Detection completed - Call: \(callUUID), State: \(result.finalState), Duration: \(result.detectionDuration)s")
        
        // Cleanup detection session
        cleanupDetectionSession(for: callUUID)
        
        // Update statistics
        updateDetectionStatistics(for: callUUID, completed: true, result: result)
        
        // Notify completion
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.callKitDetectionManager(self, didCompleteDetection: result, for: callUUID)
        }
    }
    
    private func handleDetectionTimeout(for callUUID: UUID) {
        logger.warning("⏰ Detection timeout for call: \(callUUID)")
        
        let result = createTimeoutResult(for: callUUID)
        completeDetection(with: result)
        notifyError(.detectionTimeout, for: callUUID)
    }
    
    private func handleDetectionMaxAttempts(for callUUID: UUID) {
        logger.warning("🔄 Max detection attempts reached for call: \(callUUID)")
        
        let result = createMaxAttemptsResult(for: callUUID)
        completeDetection(with: result)
    }
    
    private func createTimeoutResult(for callUUID: UUID) -> CallKitDetectionResult {
        return CallKitDetectionResult(
            callUUID: callUUID,
            finalState: .failed,
            detectionDuration: CallKitDetectionConfiguration.maxDetectionDuration,
            attemptCount: detectionAttempts[callUUID] ?? 0,
            systemCallCount: callObserver.calls.count,
            appState: UIApplication.shared.applicationState,
            timestamp: Date(),
            metadata: ["timeout": true]
        )
    }
    
    private func createMaxAttemptsResult(for callUUID: UUID) -> CallKitDetectionResult {
        return CallKitDetectionResult(
            callUUID: callUUID,
            finalState: .failed,
            detectionDuration: detectionStartTimes[callUUID].map { Date().timeIntervalSince($0) } ?? 0,
            attemptCount: CallKitDetectionConfiguration.maxDetectionAttempts,
            systemCallCount: callObserver.calls.count,
            appState: UIApplication.shared.applicationState,
            timestamp: Date(),
            metadata: ["max_attempts": true]
        )
    }
    
    // MARK: - Cleanup & Memory Management
    
    private func cleanupDetectionSession(for callUUID: UUID) {
        // Stop timer
        detectionTimers[callUUID]?.invalidate()
        detectionTimers.removeValue(forKey: callUUID)
        
        // Clear session data
        activeSessions.remove(callUUID)
        detectionStartTimes.removeValue(forKey: callUUID)
        detectionAttempts.removeValue(forKey: callUUID)
    }
    
    private func updateDetectionStatistics(for callUUID: UUID, completed: Bool, result: CallKitDetectionResult? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var stats = self.detectionStatistics
            stats.totalDetections += 1
            
            if completed, let result = result {
                if result.wasSuccessful {
                    stats.successfulDetections += 1
                } else {
                    stats.failedDetections += 1
                }
                
                stats.averageDetectionDuration = (stats.averageDetectionDuration * Double(stats.completedDetections) + result.detectionDuration) / Double(stats.completedDetections + 1)
                stats.completedDetections += 1
            }
            
            stats.lastUpdateTime = Date()
            self.detectionStatistics = stats
        }
    }
    
    // MARK: - System Event Handling
    
    private func handleAppDidEnterBackground() {
        logger.info("📱 App entered background - updating detection states")
        
        stateLock.withLock {
            // Update all active detections to check for CallKit activation
            for callUUID in activeSessions {
                if let result = performDetectionCheck(for: callUUID) {
                    processDetectionResult(result)
                }
            }
        }
    }
    
    private func handleMemoryPressure() {
        logger.warning("💾 Memory pressure detected - suspending non-critical detections")
        
        stateLock.withLock {
            // Temporarily suspend detection for calls in stable states
            let callsToSuspend = activeSessions.filter { callUUID in
                detectionStates[callUUID]?.isStable == true
            }
            
            for callUUID in callsToSuspend {
                notifyError(.memoryPressure, for: callUUID)
                cleanupDetectionSession(for: callUUID)
            }
        }
    }
    
    private func adjustDetectionParametersBasedOnPerformance(_ stats: CallKitDetectionStatistics) {
        // Dynamic performance optimization based on statistics
        logger.debug("📊 Detection stats - Success rate: \(stats.successRate)%, Avg duration: \(stats.averageDetectionDuration)s")
        
        // Future enhancement: Adjust detection parameters based on success rate
    }
    
    // MARK: - Notification Helpers
    
    private func notifyStateChange(_ state: CallKitUIState, for callUUID: UUID) {
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.callKitDetectionManager(self, didDetectStateChange: state, for: callUUID)
        }
    }
    
    private func notifyError(_ error: CallKitDetectionError, for callUUID: UUID) {
        logger.error("❌ Detection error for call \(callUUID): \(error.localizedDescription)")
        
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.callKitDetectionManager(self, didEncounterError: error, for: callUUID)
        }
    }
    
    deinit {
        logger.info("🗑️ CallKit Detection Manager deallocating")
        
        // Cleanup all active sessions
        for callUUID in activeSessions {
            cleanupDetectionSession(for: callUUID)
        }
        
        // Remove observers
        if let observer = appStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Cancel memory pressure monitoring
        memoryPressureSource?.cancel()
        
        // Cancel Combine subscriptions
        cancellables.removeAll()
    }
}

// MARK: - CXCallObserver Delegate

extension CallKitDetectionManager: CXCallObserverDelegate {
    
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        logger.debug("📞 System call changed - UUID: \(call.uuid), Connected: \(call.hasConnected), Ended: \(call.hasEnded)")
        
        stateLock.withLock {
            // Check if we're monitoring this call
            if activeSessions.contains(call.uuid) {
                // Trigger immediate detection check
                if let result = performDetectionCheck(for: call.uuid) {
                    processDetectionResult(result)
                }
            }
        }
    }
}

// MARK: - Statistics

struct CallKitDetectionStatistics {
    var totalDetections: Int = 0
    var successfulDetections: Int = 0
    var failedDetections: Int = 0
    var completedDetections: Int = 0
    var averageDetectionDuration: TimeInterval = 0
    var lastUpdateTime: Date = Date()
    
    var successRate: Double {
        guard completedDetections > 0 else { return 0 }
        return (Double(successfulDetections) / Double(completedDetections)) * 100
    }
}

// MARK: - Thread Safety Extension

extension NSLock {
    func withLock<T>(_ block: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try block()
    }
}