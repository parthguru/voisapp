//
//  CallKitStateMonitor.swift
//  TelnyxWebRTCDemo
//
//  Real-time CallKit State Monitoring System - WhatsApp-Style Implementation
//  Provides continuous monitoring and reactive updates for CallKit state changes
//
//  Created by Claude Code on 04/09/2025.
//

import Foundation
import CallKit
import UIKit
import Combine
import TelnyxRTC
import os.log

// MARK: - State Monitoring Types

/// Comprehensive call state information
struct CallKitStateSnapshot {
    let timestamp: Date
    let callUUID: UUID
    let systemCallState: CXCallState
    let appLifecycleState: UIApplication.State
    let callKitUIState: CallKitUIState
    let audioSessionState: AudioSessionState
    let networkState: NetworkConnectionState
    let metadata: [String: Any]
    
    var isConsistentState: Bool {
        // Validate state consistency across different monitoring points
        switch (systemCallState, appLifecycleState, callKitUIState) {
        case (.connected, .background, .callKitActive):
            return true  // Expected: Connected call with CallKit UI active
        case (.connecting, .active, .failed):
            return true  // Expected: iOS 18 issue - call connecting but app in foreground
        case (.connected, .active, .appUIActive):
            return true  // Expected: Fallback UI handling the call
        default:
            return false // Inconsistent state requiring analysis
        }
    }
}

/// System call state enumeration
public enum CXCallState: String, CaseIterable {
    case idle = "idle"
    case connecting = "connecting"
    case connected = "connected"
    case held = "held"
    case ended = "ended"
    case failed = "failed"
    
    static func from(cxCall: CXCall) -> CXCallState {
        if cxCall.hasEnded {
            return .ended
        } else if cxCall.hasConnected {
            return cxCall.isOnHold ? .held : .connected
        } else if cxCall.isOutgoing {
            return .connecting
        } else {
            return .connecting  // Incoming call
        }
    }
}

/// Audio session state for call coordination
enum AudioSessionState: String, CaseIterable {
    case inactive = "inactive"
    case active = "active"
    case interrupted = "interrupted"
    case routeChanged = "route_changed"
}

/// Network connection state for call quality monitoring
enum NetworkConnectionState: String, CaseIterable {
    case unknown = "unknown"
    case connected = "connected"
    case connecting = "connecting"
    case disconnected = "disconnected"
    case reconnecting = "reconnecting"
}

/// State change event for reactive programming
struct CallKitStateChangeEvent {
    let callUUID: UUID
    let previousSnapshot: CallKitStateSnapshot?
    let currentSnapshot: CallKitStateSnapshot
    let changeType: StateChangeType
    let timestamp: Date
    
    var hasSignificantChange: Bool {
        guard let previous = previousSnapshot else { return true }
        
        return previous.systemCallState != currentSnapshot.systemCallState ||
               previous.appLifecycleState != currentSnapshot.appLifecycleState ||
               previous.callKitUIState != currentSnapshot.callKitUIState
    }
}

enum StateChangeType: String, CaseIterable {
    case callStarted = "call_started"
    case callConnected = "call_connected"
    case callEnded = "call_ended"
    case appStateChanged = "app_state_changed"
    case callKitUIChanged = "callkit_ui_changed"
    case audioSessionChanged = "audio_session_changed"
    case networkStateChanged = "network_state_changed"
    case systemInconsistency = "system_inconsistency"
}

// MARK: - Main State Monitor

/// Enterprise-grade real-time CallKit state monitoring system
final class CallKitStateMonitor: NSObject, ObservableObject {
    
    // MARK: - Public Publishers (Combine)
    
    /// Real-time state changes for all monitored calls
    @Published private(set) var currentStates: [UUID: CallKitStateSnapshot] = [:]
    
    /// Latest state change events
    private let stateChangeSubject = PassthroughSubject<CallKitStateChangeEvent, Never>()
    var stateChangePublisher: AnyPublisher<CallKitStateChangeEvent, Never> {
        stateChangeSubject.eraseToAnyPublisher()
    }
    
    /// System call updates from CXCallObserver
    private let systemCallUpdateSubject = PassthroughSubject<CXCall, Never>()
    var systemCallUpdatePublisher: AnyPublisher<CXCall, Never> {
        systemCallUpdateSubject.eraseToAnyPublisher()
    }
    
    /// App lifecycle state changes
    private let appStateChangeSubject = PassthroughSubject<UIApplication.State, Never>()
    var appStateChangePublisher: AnyPublisher<UIApplication.State, Never> {
        appStateChangeSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    
    /// System call observer for CXCall monitoring
    private let callObserver = CXCallObserver()
    
    /// Detection manager integration
    private weak var detectionManager: CallKitDetectionManager?
    
    /// Serial queue for state monitoring operations
    private let monitoringQueue = DispatchQueue(label: "com.telnyx.callkit.monitor", qos: .userInteractive)
    
    /// State history for analysis (limited size for memory efficiency)
    private var stateHistory: [UUID: [CallKitStateSnapshot]] = [:]
    private let maxHistorySize = 50
    
    /// Current app lifecycle state
    private var currentAppState: UIApplication.State = .active
    
    /// Audio session monitoring
    private let audioSession = AVAudioSession.sharedInstance()
    private var audioSessionObserver: NSObjectProtocol?
    
    /// Network monitoring integration
    private var networkMonitor: NetworkMonitoring?
    
    /// Combine cancellables
    private var cancellables = Set<AnyCancellable>()
    
    /// App lifecycle observers
    private var appLifecycleObservers: [NSObjectProtocol] = []
    
    /// Logging subsystem
    private let logger = Logger(subsystem: "com.telnyx.webrtc.callkit", category: "monitor")
    
    /// Thread-safe state management
    private let stateLock = NSLock()
    
    /// Monitoring statistics
    @Published private(set) var monitoringStats = StateMonitoringStatistics()
    
    // MARK: - Singleton
    
    static let shared = CallKitStateMonitor()
    
    override init() {
        super.init()
        setupStateMonitoring()
    }
    
    // MARK: - Setup & Configuration
    
    private func setupStateMonitoring() {
        logger.info("📊 Initializing CallKit State Monitor v2.0")
        
        // Setup system call monitoring
        setupSystemCallMonitoring()
        
        // Setup app lifecycle monitoring
        setupAppLifecycleMonitoring()
        
        // Setup audio session monitoring
        setupAudioSessionMonitoring()
        
        // Setup network monitoring
        setupNetworkMonitoring()
        
        // Setup reactive monitoring pipeline
        setupReactiveMonitoring()
        
        // Integration with detection manager
        detectionManager = CallKitDetectionManager.shared
        
        logger.info("✅ CallKit State Monitor initialized successfully")
    }
    
    private func setupSystemCallMonitoring() {
        callObserver.setDelegate(self, queue: monitoringQueue)
        logger.debug("📞 System call monitoring configured")
    }
    
    private func setupAppLifecycleMonitoring() {
        let notifications: [(Notification.Name, UIApplication.State)] = [
            (UIApplication.willEnterForegroundNotification, .active),
            (UIApplication.didEnterBackgroundNotification, .background),
            (UIApplication.didBecomeActiveNotification, .active),
            (UIApplication.willResignActiveNotification, .inactive)
        ]
        
        for (notification, state) in notifications {
            let observer = NotificationCenter.default.addObserver(
                forName: notification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleAppStateChange(to: state)
            }
            appLifecycleObservers.append(observer)
        }
        
        logger.debug("📱 App lifecycle monitoring configured")
    }
    
    private func setupAudioSessionMonitoring() {
        audioSessionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAudioSessionChange(notification)
        }
        
        logger.debug("🔊 Audio session monitoring configured")
    }
    
    private func setupNetworkMonitoring() {
        // Initialize network monitoring (if available)
        networkMonitor = DefaultNetworkMonitor()
        networkMonitor?.startMonitoring { [weak self] state in
            self?.handleNetworkStateChange(state)
        }
        
        logger.debug("🌐 Network monitoring configured")
    }
    
    private func setupReactiveMonitoring() {
        // Combine multiple state streams for comprehensive monitoring
        Publishers.CombineLatest3(
            systemCallUpdatePublisher,
            appStateChangePublisher,
            Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
        )
        .sink { [weak self] (call, appState, _) in
            self?.processReactiveStateUpdate(call: call, appState: appState)
        }
        .store(in: &cancellables)
        
        logger.debug("⚡ Reactive monitoring pipeline configured")
    }
    
    // MARK: - Public Monitoring Interface
    
    /// Starts monitoring a specific call
    func startMonitoring(callUUID: UUID) {
        stateLock.withLock {
            logger.info("🔍 Starting state monitoring for call: \(callUUID)")
            
            // Initialize state history
            if stateHistory[callUUID] == nil {
                stateHistory[callUUID] = []
            }
            
            // Create initial snapshot
            let initialSnapshot = createStateSnapshot(for: callUUID)
            updateCallState(callUUID: callUUID, snapshot: initialSnapshot)
            
            // Update statistics
            updateMonitoringStatistics(callStarted: true)
        }
    }
    
    /// Stops monitoring a specific call
    func stopMonitoring(callUUID: UUID) {
        stateLock.withLock {
            logger.info("🛑 Stopping state monitoring for call: \(callUUID)")
            
            // Archive final state
            if let finalState = currentStates[callUUID] {
                archiveFinalState(callUUID: callUUID, finalState: finalState)
            }
            
            // Cleanup
            currentStates.removeValue(forKey: callUUID)
            
            // Maintain limited history for analysis
            if var history = stateHistory[callUUID] {
                history = Array(history.suffix(10))  // Keep last 10 states
                stateHistory[callUUID] = history
            }
            
            // Update statistics
            updateMonitoringStatistics(callEnded: true)
        }
    }
    
    /// Gets current state for a specific call
    func getCurrentState(for callUUID: UUID) -> CallKitStateSnapshot? {
        return stateLock.withLock {
            return currentStates[callUUID]
        }
    }
    
    /// Gets state history for a specific call
    func getStateHistory(for callUUID: UUID) -> [CallKitStateSnapshot] {
        return stateLock.withLock {
            return stateHistory[callUUID] ?? []
        }
    }
    
    /// Gets all currently monitored calls
    func getAllMonitoredCalls() -> [UUID] {
        return stateLock.withLock {
            return Array(currentStates.keys)
        }
    }
    
    /// Forces immediate state refresh for debugging
    func refreshAllStates() {
        stateLock.withLock {
            logger.debug("🔄 Refreshing all monitored call states")
            
            for callUUID in currentStates.keys {
                let snapshot = createStateSnapshot(for: callUUID)
                updateCallState(callUUID: callUUID, snapshot: snapshot)
            }
        }
    }
    
    // MARK: - State Creation & Management
    
    private func createStateSnapshot(for callUUID: UUID) -> CallKitStateSnapshot {
        let timestamp = Date()
        let systemCall = findSystemCall(for: callUUID)
        let systemCallState = systemCall.map { CXCallState.from(cxCall: $0) } ?? .idle
        let appState = UIApplication.shared.applicationState
        let callKitUIState = determineCallKitUIState(for: callUUID, systemCall: systemCall)
        let audioState = determineAudioSessionState()
        let networkState = networkMonitor?.currentState ?? .unknown
        
        let metadata = createSnapshotMetadata(
            callUUID: callUUID,
            systemCall: systemCall,
            timestamp: timestamp
        )
        
        return CallKitStateSnapshot(
            timestamp: timestamp,
            callUUID: callUUID,
            systemCallState: systemCallState,
            appLifecycleState: appState,
            callKitUIState: callKitUIState,
            audioSessionState: audioState,
            networkState: networkState,
            metadata: metadata
        )
    }
    
    private func findSystemCall(for callUUID: UUID) -> CXCall? {
        return callObserver.calls.first { $0.uuid == callUUID }
    }
    
    private func determineCallKitUIState(for callUUID: UUID, systemCall: CXCall?) -> CallKitUIState {
        // Integrate with detection manager if available
        if let detectedState = detectionManager?.getCurrentState(for: callUUID) {
            return detectedState
        }
        
        // Fallback to basic detection
        guard let call = systemCall else { return .unknown }
        
        let appState = UIApplication.shared.applicationState
        
        if appState == .background && !call.hasEnded {
            return .callKitActive
        } else if appState == .active && !call.hasEnded {
            return .failed  // Likely iOS 18 issue
        }
        
        return .unknown
    }
    
    private func determineAudioSessionState() -> AudioSessionState {
        let session = AVAudioSession.sharedInstance()
        
        if session.isOtherAudioPlaying {
            return .interrupted
        } else if session.categoryOptions.contains(.duckOthers) {
            return .active
        } else {
            return .inactive
        }
    }
    
    private func createSnapshotMetadata(callUUID: UUID, systemCall: CXCall?, timestamp: Date) -> [String: Any] {
        var metadata: [String: Any] = [:]
        
        metadata["snapshot_version"] = "2.0"
        metadata["ios_version"] = UIDevice.current.systemVersion
        metadata["device_model"] = UIDevice.current.model
        metadata["timestamp"] = timestamp.timeIntervalSince1970
        metadata["monitoring_duration"] = getCurrentMonitoringDuration(for: callUUID)
        
        if let call = systemCall {
            metadata["system_call_outgoing"] = call.isOutgoing
            metadata["system_call_connected"] = call.hasConnected
            metadata["system_call_ended"] = call.hasEnded
            metadata["system_call_hold"] = call.isOnHold
        }
        
        if #available(iOS 18.0, *) {
            metadata["ios18_monitoring"] = true
        }
        
        return metadata
    }
    
    private func getCurrentMonitoringDuration(for callUUID: UUID) -> TimeInterval {
        guard let history = stateHistory[callUUID], let firstSnapshot = history.first else {
            return 0
        }
        return Date().timeIntervalSince(firstSnapshot.timestamp)
    }
    
    // MARK: - State Update Processing
    
    private func updateCallState(callUUID: UUID, snapshot: CallKitStateSnapshot) {
        let previousSnapshot = currentStates[callUUID]
        currentStates[callUUID] = snapshot
        
        // Add to history
        addToStateHistory(callUUID: callUUID, snapshot: snapshot)
        
        // Determine change type
        let changeType = determineChangeType(
            previous: previousSnapshot,
            current: snapshot
        )
        
        // Create change event
        let changeEvent = CallKitStateChangeEvent(
            callUUID: callUUID,
            previousSnapshot: previousSnapshot,
            currentSnapshot: snapshot,
            changeType: changeType,
            timestamp: snapshot.timestamp
        )
        
        // Broadcast change event
        broadcastStateChange(changeEvent)
        
        // Log significant changes
        if changeEvent.hasSignificantChange {
            logger.info("📊 State change - Call: \(callUUID), Type: \(changeType), State: \(snapshot.callKitUIState)")
        }
        
        // Check for system inconsistencies
        if !snapshot.isConsistentState {
            logger.warning("⚠️ Inconsistent system state detected for call: \(callUUID)")
            handleSystemInconsistency(snapshot: snapshot)
        }
    }
    
    private func addToStateHistory(callUUID: UUID, snapshot: CallKitStateSnapshot) {
        var history = stateHistory[callUUID] ?? []
        history.append(snapshot)
        
        // Maintain limited history size
        if history.count > maxHistorySize {
            history.removeFirst(history.count - maxHistorySize)
        }
        
        stateHistory[callUUID] = history
    }
    
    private func determineChangeType(previous: CallKitStateSnapshot?, current: CallKitStateSnapshot) -> StateChangeType {
        guard let previous = previous else {
            return .callStarted
        }
        
        if previous.systemCallState != current.systemCallState {
            switch current.systemCallState {
            case .connected:
                return .callConnected
            case .ended:
                return .callEnded
            default:
                break
            }
        }
        
        if previous.appLifecycleState != current.appLifecycleState {
            return .appStateChanged
        }
        
        if previous.callKitUIState != current.callKitUIState {
            return .callKitUIChanged
        }
        
        if previous.audioSessionState != current.audioSessionState {
            return .audioSessionChanged
        }
        
        if previous.networkState != current.networkState {
            return .networkStateChanged
        }
        
        if !current.isConsistentState {
            return .systemInconsistency
        }
        
        return .callKitUIChanged  // Default fallback
    }
    
    private func broadcastStateChange(_ event: CallKitStateChangeEvent) {
        // Broadcast on main queue for UI updates
        DispatchQueue.main.async { [weak self] in
            self?.stateChangeSubject.send(event)
        }
    }
    
    // MARK: - System Event Handlers
    
    private func handleAppStateChange(to newState: UIApplication.State) {
        currentAppState = newState
        
        logger.debug("📱 App state changed to: \(newState)")
        
        // Broadcast app state change
        appStateChangeSubject.send(newState)
        
        // Update all monitored calls
        stateLock.withLock {
            for callUUID in currentStates.keys {
                let snapshot = createStateSnapshot(for: callUUID)
                updateCallState(callUUID: callUUID, snapshot: snapshot)
            }
        }
    }
    
    private func handleAudioSessionChange(_ notification: Notification) {
        logger.debug("🔊 Audio session changed")
        
        // Update all monitored calls with new audio state
        stateLock.withLock {
            for callUUID in currentStates.keys {
                let snapshot = createStateSnapshot(for: callUUID)
                updateCallState(callUUID: callUUID, snapshot: snapshot)
            }
        }
    }
    
    private func handleNetworkStateChange(_ newState: NetworkConnectionState) {
        logger.debug("🌐 Network state changed to: \(newState)")
        
        // Update all monitored calls with new network state
        stateLock.withLock {
            for callUUID in currentStates.keys {
                let snapshot = createStateSnapshot(for: callUUID)
                updateCallState(callUUID: callUUID, snapshot: snapshot)
            }
        }
    }
    
    private func processReactiveStateUpdate(call: CXCall, appState: UIApplication.State) {
        stateLock.withLock {
            // Check if we're monitoring this call
            let callUUID = call.uuid
            if currentStates[callUUID] != nil {
                let snapshot = createStateSnapshot(for: callUUID)
                updateCallState(callUUID: callUUID, snapshot: snapshot)
            }
        }
    }
    
    private func handleSystemInconsistency(snapshot: CallKitStateSnapshot) {
        // Log inconsistency details
        logger.error("💥 System inconsistency detected:")
        logger.error("  Call: \(snapshot.callUUID)")
        logger.error("  System State: \(snapshot.systemCallState)")
        logger.error("  App State: \(snapshot.appLifecycleState)")
        logger.error("  CallKit UI: \(snapshot.callKitUIState)")
        
        // Trigger detection manager retry if available
        detectionManager?.startDetection(for: snapshot.callUUID, metadata: ["inconsistency_retry": true])
    }
    
    // MARK: - Statistics & Analytics
    
    private func updateMonitoringStatistics(callStarted: Bool = false, callEnded: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var stats = self.monitoringStats
            
            if callStarted {
                stats.totalCallsMonitored += 1
                stats.currentlyMonitored += 1
            }
            
            if callEnded {
                stats.currentlyMonitored = max(0, stats.currentlyMonitored - 1)
            }
            
            stats.lastUpdateTime = Date()
            self.monitoringStats = stats
        }
    }
    
    private func archiveFinalState(callUUID: UUID, finalState: CallKitStateSnapshot) {
        // Archive important final state information
        logger.info("📁 Archiving final state for call: \(callUUID)")
        logger.info("  Final CallKit State: \(finalState.callKitUIState)")
        logger.info("  Final System State: \(finalState.systemCallState)")
        logger.info("  Total Monitoring Duration: \(getCurrentMonitoringDuration(for: callUUID))s")
    }
    
    // MARK: - Cleanup & Memory Management
    
    deinit {
        logger.info("🗑️ CallKit State Monitor deallocating")
        
        // Remove all observers
        for observer in appLifecycleObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        
        if let audioObserver = audioSessionObserver {
            NotificationCenter.default.removeObserver(audioObserver)
        }
        
        // Stop network monitoring
        networkMonitor?.stopMonitoring()
        
        // Cancel Combine subscriptions
        cancellables.removeAll()
    }
}

// MARK: - CXCallObserver Delegate

extension CallKitStateMonitor: CXCallObserverDelegate {
    
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        logger.debug("📞 System call observer - Call changed: \(call.uuid)")
        
        // Broadcast system call update
        systemCallUpdateSubject.send(call)
        
        // Update state if we're monitoring this call
        monitoringQueue.async { [weak self] in
            self?.stateLock.withLock {
                if let self = self, self.currentStates[call.uuid] != nil {
                    let snapshot = self.createStateSnapshot(for: call.uuid)
                    self.updateCallState(callUUID: call.uuid, snapshot: snapshot)
                }
            }
        }
    }
}

// MARK: - Network Monitoring Protocol

protocol NetworkMonitoring {
    var currentState: NetworkConnectionState { get }
    func startMonitoring(completion: @escaping (NetworkConnectionState) -> Void)
    func stopMonitoring()
}

/// Default network monitor implementation
class DefaultNetworkMonitor: NetworkMonitoring {
    var currentState: NetworkConnectionState = .unknown
    private var completionHandler: ((NetworkConnectionState) -> Void)?
    
    func startMonitoring(completion: @escaping (NetworkConnectionState) -> Void) {
        self.completionHandler = completion
        // Simplified network monitoring - can be enhanced with NWPathMonitor
        currentState = .connected
    }
    
    func stopMonitoring() {
        completionHandler = nil
    }
}

// MARK: - Statistics

struct StateMonitoringStatistics {
    var totalCallsMonitored: Int = 0
    var currentlyMonitored: Int = 0
    var totalStateChanges: Int = 0
    var inconsistencyCount: Int = 0
    var lastUpdateTime: Date = Date()
    
    var averageStatesPerCall: Double {
        guard totalCallsMonitored > 0 else { return 0 }
        return Double(totalStateChanges) / Double(totalCallsMonitored)
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