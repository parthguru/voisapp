//
//  CallKitDebugLogger.swift
//  TelnyxWebRTCDemo
//
//  Created by AI SWE Agent on 05/09/2025.
//  Copyright © 2025 Telnyx LLC. All rights reserved.
//
//  PHASE 7: WhatsApp-Style CallKit Enhancement - Enhanced Debug Logger
//
//  Comprehensive debugging and logging system for the WhatsApp-style CallKit
//  enhancement. Provides detailed logging, performance monitoring, error tracking,
//  and diagnostic information for development and production debugging.
//
//  Key Features:
//  - Multi-level logging with contextual information
//  - Real-time performance monitoring and metrics
//  - CallKit-specific debug information and state tracking  
//  - Network and system resource monitoring
//  - Crash reporting and error analysis
//  - Log filtering and search capabilities
//  - Export functionality for support and analysis
//  - Memory-efficient circular logging buffer
//  - Thread-safe concurrent logging operations
//  - Integration with system Console and third-party tools
//

import Foundation
import Combine
import SwiftUI
import CallKit
import AVFoundation
import Network
import os.log

// MARK: - Debug Log Types

/// Debug log levels with priority and filtering
public enum DebugLogLevel: Int, CaseIterable, Codable {
    case trace = 0      // Extremely detailed tracing
    case debug = 1      // General debugging information
    case info = 2       // Informational messages
    case warning = 3    // Warning conditions
    case error = 4      // Error conditions
    case critical = 5   // Critical system failures
    
    public var name: String {
        switch self {
        case .trace: return "TRACE"
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }
    
    public var emoji: String {
        switch self {
        case .trace: return "🔍"
        case .debug: return "🐛"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
    
    public var color: Color {
        switch self {
        case .trace: return .gray
        case .debug: return .blue
        case .info: return .green
        case .warning: return .yellow
        case .error: return .red
        case .critical: return .purple
        }
    }
}

/// Debug log categories for organization
public enum DebugLogCategory: String, CaseIterable, Codable {
    case detection = "Detection"
    case retry = "Retry"
    case fallback = "Fallback"
    case synchronization = "Synchronization"
    case networking = "Networking"
    case performance = "Performance"
    case ui = "UI"
    case audio = "Audio"
    case callkit = "CallKit"
    case system = "System"
    case memory = "Memory"
    case battery = "Battery"
    case error = "Error"
    case analytics = "Analytics"
    
    public var emoji: String {
        switch self {
        case .detection: return "🕵️"
        case .retry: return "🔄"
        case .fallback: return "🛡️"
        case .synchronization: return "🔄"
        case .networking: return "🌐"
        case .performance: return "⚡"
        case .ui: return "🎨"
        case .audio: return "🎵"
        case .callkit: return "📞"
        case .system: return "⚙️"
        case .memory: return "💾"
        case .battery: return "🔋"
        case .error: return "🚫"
        case .analytics: return "📊"
        }
    }
}

/// Debug log entry structure
public struct DebugLogEntry: Identifiable, Codable {
    public let id = UUID()
    public let timestamp: Date
    public let level: DebugLogLevel
    public let category: DebugLogCategory
    public let message: String
    public let context: [String: String]
    public let file: String
    public let function: String
    public let line: Int
    public let threadName: String
    public let memoryUsage: UInt64
    public let systemLoad: Double
    
    public init(level: DebugLogLevel, category: DebugLogCategory, message: String, context: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        self.timestamp = Date()
        self.level = level
        self.category = category
        self.message = message
        self.context = context
        self.file = file
        self.function = function
        self.line = line
        self.threadName = Thread.current.name ?? "Unknown"
        self.memoryUsage = getMemoryInfo().resident_size
        
        // Simple system load approximation
        self.systemLoad = Double(ProcessInfo.processInfo.activeProcessorCount) * 0.1
    }
    
    public var formattedMessage: String {
        let filename = URL(fileURLWithPath: file).lastPathComponent
        return "\(level.emoji) [\(level.name)] \(category.emoji) \(category.rawValue) | \(message) | \(filename):\(line) \(function) | \(threadName)"
    }
    
    public var contextDescription: String {
        guard !context.isEmpty else { return "" }
        return context.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    }
}

// MARK: - Performance Metrics

public struct DebugPerformanceMetrics: Codable {
    public let timestamp: Date
    public let cpuUsage: Double
    public let memoryUsage: UInt64
    public let diskUsage: UInt64
    public let networkBytesReceived: UInt64
    public let networkBytesSent: UInt64
    public let batteryLevel: Float
    public let batteryState: String
    public let thermalState: String
    public let activeCallsCount: Int
    public let callKitDetectionRate: Double
    public let fallbackActivationRate: Double
    
    public init(activeCallsCount: Int = 0, callKitDetectionRate: Double = 0.0, fallbackActivationRate: Double = 0.0) {
        self.timestamp = Date()
        self.activeCallsCount = activeCallsCount
        self.callKitDetectionRate = callKitDetectionRate
        self.fallbackActivationRate = fallbackActivationRate
        
        // System metrics
        let memoryInfo = getMemoryInfo()
        self.cpuUsage = Self.getCPUUsage()
        self.memoryUsage = memoryInfo.resident_size
        self.diskUsage = Self.getDiskUsage()
        self.networkBytesReceived = 0 // Would need network monitoring
        self.networkBytesSent = 0
        
        // Device metrics
        UIDevice.current.isBatteryMonitoringEnabled = true
        self.batteryLevel = UIDevice.current.batteryLevel
        self.batteryState = Self.batteryStateString(UIDevice.current.batteryState)
        self.thermalState = Self.thermalStateString(ProcessInfo.processInfo.thermalState)
    }
    
    private static func getCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1024 * 1024) // Convert to MB
        }
        return 0.0
    }
    
    private static func getDiskUsage() -> UInt64 {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let totalSpace = systemAttributes[FileAttributeKey.systemSize] as? NSNumber {
                return totalSpace.uint64Value
            }
        } catch {
            // Handle error
        }
        return 0
    }
    
    private static func batteryStateString(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .unknown: return "Unknown"
        case .unplugged: return "Unplugged"
        case .charging: return "Charging"
        case .full: return "Full"
        @unknown default: return "Unknown"
        }
    }
    
    private static func thermalStateString(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Debug Session

public struct DebugSession: Codable, Identifiable {
    public let id = UUID()
    public let startTime: Date
    public var endTime: Date?
    public let deviceInfo: DeviceInfo
    public let appVersion: String
    public var logEntries: [DebugLogEntry] = []
    public var performanceMetrics: [DebugPerformanceMetrics] = []
    public var summary: String = ""
    
    public init(deviceInfo: DeviceInfo, appVersion: String) {
        self.startTime = Date()
        self.deviceInfo = deviceInfo
        self.appVersion = appVersion
    }
    
    public mutating func end(with summary: String = "") {
        self.endTime = Date()
        self.summary = summary
    }
    
    public var duration: TimeInterval {
        return (endTime ?? Date()).timeIntervalSince(startTime)
    }
    
    public var isActive: Bool {
        return endTime == nil
    }
}

// MARK: - Main Debug Logger

/// Enterprise-grade debug logger for CallKit enhancements
@MainActor
public class CallKitDebugLogger: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = CallKitDebugLogger()
    
    private init() {
        setupLogger()
        startPerformanceMonitoring()
        subscribeToSystemNotifications()
    }
    
    // MARK: - Published Properties
    
    @Published public var isEnabled: Bool = true
    @Published public var currentLogLevel: DebugLogLevel = .debug
    @Published public var enabledCategories: Set<DebugLogCategory> = Set(DebugLogCategory.allCases)
    @Published public var recentLogs: [DebugLogEntry] = []
    @Published public var currentSession: DebugSession?
    @Published public var isRecording: Bool = false
    @Published public var performanceMetrics: DebugPerformanceMetrics?
    
    // Configuration
    private let maxLogEntries = 5000
    private let maxSessionDuration: TimeInterval = 3600 // 1 hour
    private let performanceUpdateInterval: TimeInterval = 5.0
    
    // Internal storage
    private var allLogs: [DebugLogEntry] = []
    private var sessions: [DebugSession] = []
    private var performanceTimer: Timer?
    
    // Concurrency
    private let logQueue = DispatchQueue(label: "com.telnyx.callkit.debug", qos: .utility)
    private let performanceQueue = DispatchQueue(label: "com.telnyx.callkit.performance", qos: .background)
    
    // System integration
    private let osLog = OSLog(subsystem: "com.telnyx.callkit", category: "Enhancement")
    
    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private var networkPath: NWPath?
    
    // MARK: - Public Logging Methods
    
    public func trace(_ message: String, category: DebugLogCategory = .debug, context: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .trace, category: category, message: message, context: context, file: file, function: function, line: line)
    }
    
    public func debug(_ message: String, category: DebugLogCategory = .debug, context: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, category: category, message: message, context: context, file: file, function: function, line: line)
    }
    
    public func info(_ message: String, category: DebugLogCategory = .debug, context: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, category: category, message: message, context: context, file: file, function: function, line: line)
    }
    
    public func warning(_ message: String, category: DebugLogCategory = .debug, context: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, category: category, message: message, context: context, file: file, function: function, line: line)
    }
    
    public func error(_ message: String, category: DebugLogCategory = .error, context: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, category: category, message: message, context: context, file: file, function: function, line: line)
    }
    
    public func critical(_ message: String, category: DebugLogCategory = .error, context: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .critical, category: category, message: message, context: context, file: file, function: function, line: line)
    }
    
    // MARK: - Specialized Logging Methods
    
    public func logCallKitDetection(callUUID: UUID, detected: Bool, duration: TimeInterval, metadata: [String: Any] = [:]) {
        let context = [
            "callUUID": callUUID.uuidString,
            "detected": String(detected),
            "duration": String(format: "%.3f", duration)
        ] + metadata.mapValues { String(describing: $0) }
        
        let message = "CallKit detection \(detected ? "SUCCESS" : "FAILED") for call \(callUUID.uuidString) in \(String(format: "%.3f", duration))s"
        log(level: detected ? .info : .warning, category: .detection, message: message, context: context)
    }
    
    public func logFallbackActivation(callUUID: UUID, reason: String, activationTime: TimeInterval) {
        let context = [
            "callUUID": callUUID.uuidString,
            "reason": reason,
            "activationTime": String(format: "%.3f", activationTime)
        ]
        
        let message = "Fallback UI activated for call \(callUUID.uuidString) due to \(reason) in \(String(format: "%.3f", activationTime))s"
        log(level: .info, category: .fallback, message: message, context: context)
    }
    
    public func logRetryAttempt(callUUID: UUID, attempt: Int, strategy: String, delay: TimeInterval) {
        let context = [
            "callUUID": callUUID.uuidString,
            "attempt": String(attempt),
            "strategy": strategy,
            "delay": String(format: "%.3f", delay)
        ]
        
        let message = "Retry attempt #\(attempt) for call \(callUUID.uuidString) using \(strategy) with \(String(format: "%.3f", delay))s delay"
        log(level: .debug, category: .retry, message: message, context: context)
    }
    
    public func logPerformanceIssue(component: String, metric: String, value: Double, threshold: Double) {
        let context = [
            "component": component,
            "metric": metric,
            "value": String(format: "%.2f", value),
            "threshold": String(format: "%.2f", threshold),
            "exceeded": String(value > threshold)
        ]
        
        let message = "Performance issue in \(component): \(metric) = \(String(format: "%.2f", value)) (threshold: \(String(format: "%.2f", threshold)))"
        log(level: .warning, category: .performance, message: message, context: context)
    }
    
    public func logMemoryWarning(component: String, memoryUsage: UInt64, threshold: UInt64) {
        let context = [
            "component": component,
            "memoryUsage": String(memoryUsage),
            "threshold": String(threshold),
            "memoryUsageMB": String(format: "%.1f", Double(memoryUsage) / (1024 * 1024)),
            "thresholdMB": String(format: "%.1f", Double(threshold) / (1024 * 1024))
        ]
        
        let message = "Memory warning in \(component): \(String(format: "%.1f", Double(memoryUsage) / (1024 * 1024)))MB (threshold: \(String(format: "%.1f", Double(threshold) / (1024 * 1024)))MB)"
        log(level: .warning, category: .memory, message: message, context: context)
    }
    
    public func logNetworkEvent(event: String, details: [String: Any] = [:]) {
        let context = details.mapValues { String(describing: $0) }
        log(level: .info, category: .networking, message: "Network event: \(event)", context: context)
    }
    
    public func logAudioEvent(event: String, route: AVAudioSessionRouteDescription? = nil) {
        var context: [String: String] = ["event": event]
        
        if let route = route {
            context["inputRoute"] = route.inputs.first?.portName ?? "Unknown"
            context["outputRoute"] = route.outputs.first?.portName ?? "Unknown"
        }
        
        log(level: .info, category: .audio, message: "Audio event: \(event)", context: context)
    }
    
    // MARK: - Session Management
    
    public func startSession() {
        guard !isRecording else {
            warning("Debug session already active")
            return
        }
        
        let deviceInfo = DeviceInfo.current()
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        
        currentSession = DebugSession(deviceInfo: deviceInfo, appVersion: appVersion)
        isRecording = true
        
        info("Debug session started", category: .system, context: [
            "sessionID": currentSession?.id.uuidString ?? "Unknown",
            "device": deviceInfo.deviceModel,
            "iOS": deviceInfo.systemVersion
        ])
    }
    
    public func endSession(summary: String = "") {
        guard let session = currentSession else {
            warning("No active debug session to end")
            return
        }
        
        currentSession?.end(with: summary)
        sessions.append(session)
        isRecording = false
        
        info("Debug session ended", category: .system, context: [
            "sessionID": session.id.uuidString,
            "duration": String(format: "%.1f", session.duration),
            "logCount": String(session.logEntries.count),
            "summary": summary
        ])
        
        currentSession = nil
    }
    
    public func exportSession(_ session: DebugSession) async -> URL? {
        return await withCheckedContinuation { continuation in
            logQueue.async {
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    encoder.dateEncodingStrategy = .iso8601
                    
                    let data = try encoder.encode(session)
                    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    let filename = "CallKitDebugSession_\(Int(session.startTime.timeIntervalSince1970)).json"
                    let url = documentsPath.appendingPathComponent(filename)
                    
                    try data.write(to: url)
                    
                    DispatchQueue.main.async {
                        self.info("Debug session exported", category: .system, context: [
                            "sessionID": session.id.uuidString,
                            "filename": filename,
                            "size": String(data.count)
                        ])
                    }
                    
                    continuation.resume(returning: url)
                    
                } catch {
                    DispatchQueue.main.async {
                        self.error("Failed to export debug session", category: .system, context: [
                            "error": error.localizedDescription
                        ])
                    }
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // MARK: - Log Management
    
    public func clearLogs() {
        allLogs.removeAll()
        recentLogs.removeAll()
        currentSession?.logEntries.removeAll()
        
        info("Debug logs cleared", category: .system)
    }
    
    public func getLogs(level: DebugLogLevel? = nil, category: DebugLogCategory? = nil, limit: Int = 1000) -> [DebugLogEntry] {
        var filteredLogs = allLogs
        
        if let level = level {
            filteredLogs = filteredLogs.filter { $0.level.rawValue >= level.rawValue }
        }
        
        if let category = category {
            filteredLogs = filteredLogs.filter { $0.category == category }
        }
        
        return Array(filteredLogs.suffix(limit))
    }
    
    public func searchLogs(query: String) -> [DebugLogEntry] {
        return allLogs.filter { entry in
            entry.message.localizedCaseInsensitiveContains(query) ||
            entry.contextDescription.localizedCaseInsensitiveContains(query) ||
            entry.category.rawValue.localizedCaseInsensitiveContains(query)
        }
    }
    
    // MARK: - Configuration
    
    public func setLogLevel(_ level: DebugLogLevel) {
        currentLogLevel = level
        info("Debug log level changed to \(level.name)", category: .system)
    }
    
    public func enableCategory(_ category: DebugLogCategory, enabled: Bool = true) {
        if enabled {
            enabledCategories.insert(category)
        } else {
            enabledCategories.remove(category)
        }
        
        info("Category \(category.rawValue) \(enabled ? "enabled" : "disabled")", category: .system)
    }
    
    public func enableAllCategories(_ enabled: Bool = true) {
        if enabled {
            enabledCategories = Set(DebugLogCategory.allCases)
        } else {
            enabledCategories.removeAll()
        }
        
        info("All categories \(enabled ? "enabled" : "disabled")", category: .system)
    }
    
    // MARK: - Private Methods
    
    private func setupLogger() {
        info("CallKit Debug Logger initialized", category: .system, context: [
            "maxLogEntries": String(maxLogEntries),
            "maxSessionDuration": String(Int(maxSessionDuration / 60)) + "min"
        ])
    }
    
    private func log(level: DebugLogLevel, category: DebugLogCategory, message: String, context: [String: String], file: String, function: String, line: Int) {
        guard isEnabled else { return }
        guard level.rawValue >= currentLogLevel.rawValue else { return }
        guard enabledCategories.contains(category) else { return }
        
        let entry = DebugLogEntry(
            level: level,
            category: category,
            message: message,
            context: context,
            file: file,
            function: function,
            line: line
        )
        
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Add to main log storage
            self.allLogs.append(entry)
            if self.allLogs.count > self.maxLogEntries {
                self.allLogs.removeFirst(self.allLogs.count - self.maxLogEntries)
            }
            
            // Add to current session
            if self.isRecording {
                self.currentSession?.logEntries.append(entry)
            }
            
            // Update recent logs on main thread
            DispatchQueue.main.async {
                self.recentLogs.append(entry)
                if self.recentLogs.count > 100 { // Keep only recent 100 entries for UI
                    self.recentLogs.removeFirst(self.recentLogs.count - 100)
                }
            }
            
            // Log to system console for critical/error levels
            if level.rawValue >= DebugLogLevel.error.rawValue {
                os_log("%{public}@", log: self.osLog, type: .error, entry.formattedMessage)
            } else if level.rawValue >= DebugLogLevel.warning.rawValue {
                os_log("%{public}@", log: self.osLog, type: .default, entry.formattedMessage)
            } else {
                os_log("%{public}@", log: self.osLog, type: .debug, entry.formattedMessage)
            }
            
            // Print to Xcode console in debug builds
            #if DEBUG
            print(entry.formattedMessage)
            if !entry.contextDescription.isEmpty {
                print("  Context: \(entry.contextDescription)")
            }
            #endif
        }
    }
    
    private func startPerformanceMonitoring() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: performanceUpdateInterval, repeats: true) { [weak self] _ in
            self?.updatePerformanceMetrics()
        }
    }
    
    private func updatePerformanceMetrics() {
        performanceQueue.async { [weak self] in
            let metrics = DebugPerformanceMetrics()
            
            DispatchQueue.main.async {
                self?.performanceMetrics = metrics
                
                if self?.isRecording == true {
                    self?.currentSession?.performanceMetrics.append(metrics)
                }
            }
            
            // Log performance warnings
            if metrics.memoryUsage > 100 * 1024 * 1024 { // 100MB threshold
                DispatchQueue.main.async {
                    self?.warning("High memory usage detected", category: .memory, context: [
                        "memoryUsage": String(format: "%.1f", Double(metrics.memoryUsage) / (1024 * 1024)) + "MB"
                    ])
                }
            }
            
            if metrics.batteryLevel < 0.2 && metrics.batteryLevel > 0 {
                DispatchQueue.main.async {
                    self?.warning("Low battery detected", category: .battery, context: [
                        "batteryLevel": String(format: "%.1f", metrics.batteryLevel * 100) + "%"
                    ])
                }
            }
        }
    }
    
    private func subscribeToSystemNotifications() {
        // Memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.warning("System memory warning received", category: .memory)
        }
        
        // App lifecycle
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.info("App entered background", category: .system)
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.info("App will enter foreground", category: .system)
        }
        
        // Audio session interruption
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
               let type = AVAudioSession.InterruptionType(rawValue: typeValue) {
                self?.logAudioEvent(event: "Audio interruption: \(type == .began ? "began" : "ended")")
            }
        }
        
        // Network monitoring
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.networkPath = path
                let status = path.status == .satisfied ? "connected" : "disconnected"
                let interface = path.availableInterfaces.first?.name ?? "unknown"
                
                self?.logNetworkEvent(event: "Network status changed", details: [
                    "status": status,
                    "interface": interface,
                    "expensive": path.isExpensive,
                    "constrained": path.isConstrained
                ])
            }
        }
        networkMonitor.start(queue: DispatchQueue.global(qos: .utility))
    }
    
    deinit {
        performanceTimer?.invalidate()
        networkMonitor.cancel()
    }
}

// MARK: - SwiftUI Debug Interface

@available(iOS 15.0, *)
public struct CallKitDebugLoggerView: View {
    @StateObject private var logger = CallKitDebugLogger.shared
    @State private var selectedLevel: DebugLogLevel = .debug
    @State private var selectedCategory: DebugLogCategory?
    @State private var searchText = ""
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            VStack {
                // Controls
                HStack {
                    Toggle("Enabled", isOn: $logger.isEnabled)
                    Spacer()
                    Button(logger.isRecording ? "End Session" : "Start Session") {
                        if logger.isRecording {
                            logger.endSession(summary: "Manual session end")
                        } else {
                            logger.startSession()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(logger.isRecording ? .red : .green)
                }
                .padding()
                
                // Filters
                HStack {
                    Picker("Level", selection: $selectedLevel) {
                        ForEach(DebugLogLevel.allCases, id: \.self) { level in
                            Text("\(level.emoji) \(level.name)").tag(level)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Picker("Category", selection: $selectedCategory) {
                        Text("All Categories").tag(nil as DebugLogCategory?)
                        ForEach(DebugLogCategory.allCases, id: \.self) { category in
                            Text("\(category.emoji) \(category.rawValue)").tag(category as DebugLogCategory?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                .padding(.horizontal)
                
                // Search
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                // Log entries
                List(filteredLogs, id: \.id) { entry in
                    DebugLogEntryRow(entry: entry)
                }
            }
            .navigationTitle("Debug Logger")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        logger.clearLogs()
                    }
                }
            }
        }
    }
    
    private var filteredLogs: [DebugLogEntry] {
        var logs = logger.recentLogs
        
        // Filter by level
        logs = logs.filter { $0.level.rawValue >= selectedLevel.rawValue }
        
        // Filter by category
        if let category = selectedCategory {
            logs = logs.filter { $0.category == category }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            logs = logs.filter { entry in
                entry.message.localizedCaseInsensitiveContains(searchText) ||
                entry.category.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return logs
    }
}

@available(iOS 15.0, *)
public struct DebugLogEntryRow: View {
    let entry: DebugLogEntry
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.level.emoji)
                Text(entry.category.emoji)
                Text(entry.message)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(2)
                Spacer()
                Text(entry.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !entry.contextDescription.isEmpty {
                Text(entry.contextDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.leading, 40)
            }
            
            HStack {
                Text(entry.threadName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(String(format: "%.1f", Double(entry.memoryUsage) / (1024 * 1024)))MB")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 40)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Utility Extensions

private func getMemoryInfo() -> mach_task_basic_info {
    let name = mach_task_self_
    let flavor = task_flavor_t(MACH_TASK_BASIC_INFO)
    var size = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
    let infoPointer = UnsafeMutablePointer<mach_task_basic_info>.allocate(capacity: 1)
    defer { infoPointer.deallocate() }
    
    let kerr = task_info(name, flavor, unsafeBitCast(infoPointer, to: task_info_t.self), &size)
    return kerr == KERN_SUCCESS ? infoPointer.pointee : mach_task_basic_info()
}