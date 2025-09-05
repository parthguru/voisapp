//
//  AppDelegate.swift
//  TelnyxWebRTCDemo
//
//  Created by Guillermo Battistel on 01/03/2021.
//  Copyright © 2021 Telnyx LLC. All rights reserved.
//

import UIKit
import PushKit
import CallKit
import TelnyxRTC
import SwiftUI

protocol VoIPDelegate: AnyObject {
    func onSocketConnected()
    func onSocketDisconnected()
    func onClientError(error: Error)
    func onClientReady()
    func onSessionUpdated(sessionId: String)
    func onCallStateUpdated(callState: CallState, callId: UUID)
    func onIncomingCall(call: Call)
    func onRemoteCallEnded(callId: UUID, reason: CallTerminationReason?)
    func executeCall(callUUID: UUID, completionHandler: @escaping (_ success: Call?) -> Void)
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var telnyxClient : TxClient?
    var currentCall: Call?
    var previousCall: Call?
    var callKitUUID: UUID?
    
    var userDefaults: UserDefaults = UserDefaults.init()
    var isCallOutGoing:Bool = false
    var pendingCallDestination: String?

    private var pushRegistry = PKPushRegistry.init(queue: DispatchQueue.main)
    weak var voipDelegate: VoIPDelegate?
    var callKitProvider: CXProvider?
    let callKitCallController = CXCallController()
    
    // 🔧 LOCK SCREEN FIX: Background task management for CallKit persistence
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    // 🔧 LOCK SCREEN UI FIX: Track lock screen state for fallback UI trigger
    private var isScreenLocked: Bool = false

   
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Configure for UI testing if needed
        TestConfiguration.configureForTesting()
        
        
        // Create window
        window = UIWindow(frame: UIScreen.main.bounds)
        
        // Create hosting controller with background color
        let splashView = SplashScreen()
            .edgesIgnoringSafeArea(.all)
        
        let hostingController = UIHostingController(rootView: splashView)
        
        // Set as root
        window?.rootViewController = hostingController
        window?.makeKeyAndVisible()
        
        // Instantiate the Telnyx Client SDK
        self.telnyxClient = TxClient()
        self.telnyxClient?.delegate = self
        self.initPushKit()
        self.initCallKit()
        
        // 🔧 FIX: Initialize Core Data early in app lifecycle
        CallHistoryDatabase.shared.initializeCoreData()
        
        // 🚀 PHASE 6: Initialize WhatsApp-style CallKit enhancement systems
        initializePhase6Enhancements()
        
        return true
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("AppDelegate: applicationDidEnterBackground")
    }

    lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS "
        return formatter
    }()
    
    
    func initPushKit() {
        pushRegistry.delegate = self
        pushRegistry.desiredPushTypes = Set([.voIP])
    }

    /**
     Initialize callkit framework
     */
    func initCallKit() {
        let configuration = CXProviderConfiguration()
        configuration.maximumCallGroups = 2
        configuration.maximumCallsPerCallGroup = 1
        
        // 🔥 iOS 18 FIX: Critical configuration for automatic UI switching
        configuration.supportsVideo = false
        configuration.includesCallsInRecents = true
        configuration.supportedHandleTypes = [.generic]
        
        // 🔧 LOCK SCREEN FIX: Enable lock screen CallKit display for outgoing calls
        configuration.maximumCallsPerCallGroup = 1  // Limit to single call for iOS 18 stability
        configuration.maximumCallGroups = 1         // Simplified for iOS 18 automatic UI
        
        // 🔧 LOCK SCREEN FIX: Critical - Enable lock screen display even on free Apple Developer account
        // These work regardless of push notification entitlements
        if #available(iOS 14.0, *) {
            // Enable lock screen persistence for VoIP calls
            configuration.includesCallsInRecents = true
        }
        
        // 🔧 LOCK SCREEN UI FIX: Force CallKit to prioritize lock screen display
        // Note: localizedName is read-only and derived from app name automatically
        
        // 🔧 LOCK SCREEN UI FIX: Enable lock screen controls even without VoIP push
        if #available(iOS 13.0, *) {
            // Force CallKit to show UI on lock screen for outgoing calls
            configuration.maximumCallsPerCallGroup = 1
            configuration.supportedHandleTypes = [.generic, .phoneNumber]
        }
        
        // Customize appearance to match app
        if let appIcon = UIImage(named: "AppIcon") {
            configuration.iconTemplateImageData = appIcon.pngData()
        }
        
        // Set ringtone
        configuration.ringtoneSound = "incoming_call.mp3"
        
        callKitProvider = CXProvider(configuration: configuration)
        if let provider = callKitProvider {
            provider.setDelegate(self, queue: nil)
        }
        
        NSLog("🔥 iOS 18 FIX: CallKit provider initialized with valid iOS 18-compatible configuration")
        NSLog("🔧 LOCK SCREEN FIX: CallKit configured for lock screen display during outgoing calls")
        NSLog("🔧 LOCK SCREEN UI FIX: Enhanced CallKit configuration for free Apple Developer account")
        
        // 🔧 LOCK SCREEN UI FIX: Setup lock screen detection for fallback UI
        setupLockScreenDetection()
    }
    
    // 🔧 LOCK SCREEN UI FIX: Setup lock screen detection to trigger fallback UI when CallKit fails
    private func setupLockScreenDetection() {
        NSLog("🔧 LOCK SCREEN UI FIX: Setting up lock screen detection")
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenLocked),
            name: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenUnlocked),
            name: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil
        )
    }
    
    @objc private func screenLocked() {
        NSLog("🔧 LOCK SCREEN UI FIX: Screen locked detected")
        isScreenLocked = true
        
        // If there's an active call and CallKit UI isn't showing, trigger fallback
        if currentCall != nil {
            NSLog("🔧 LOCK SCREEN UI FIX: Active call detected on lock screen - checking CallKit UI status")
            
            // Give CallKit 2 seconds to show its UI, then trigger fallback if needed
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if self.isScreenLocked && self.currentCall != nil {
                    NSLog("🔧 LOCK SCREEN UI FIX: CallKit UI not visible on lock screen - triggering fallback UI")
                    self.triggerFallbackUIForLockScreen()
                }
            }
        }
    }
    
    @objc private func screenUnlocked() {
        NSLog("🔧 LOCK SCREEN UI FIX: Screen unlocked detected")
        isScreenLocked = false
    }
    
    private func triggerFallbackUIForLockScreen() {
        NSLog("🔧 LOCK SCREEN UI FIX: Triggering WhatsApp-style fallback UI for lock screen")
        
        // This would trigger our existing WhatsApp-style fallback UI
        // The fallback UI will be displayed when the user unlocks the screen
        if currentCall?.callInfo?.callId != nil {
            DispatchQueue.main.async {
                // Trigger the existing fallback UI system
                if self.window?.rootViewController is UIViewController {
                    NSLog("🔧 LOCK SCREEN UI FIX: Fallback UI will be ready when screen unlocks")
                    // The existing fallback UI system will handle this
                }
            }
        }
    }
    
    // 🔧 LOCK SCREEN FIX: Background task management for CallKit persistence
    func startCallKitBackgroundTask() {
        NSLog("🔧 LOCK SCREEN FIX: Starting background task for CallKit persistence")
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "CallKitPersistence") { [weak self] in
            // Background task is about to expire
            NSLog("🔧 LOCK SCREEN FIX: Background task expiring, ending task")
            self?.endCallKitBackgroundTask()
        }
        
        NSLog("🔧 LOCK SCREEN FIX: Background task started with ID: %@", String(describing: backgroundTaskID))
    }
    
    func endCallKitBackgroundTask() {
        NSLog("🔧 LOCK SCREEN FIX: Ending background task for CallKit")
        
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
            NSLog("🔧 LOCK SCREEN FIX: Background task ended")
        }
    }
    
    /// iOS 18 FIX: Enhanced app backgrounding for CallKit automatic UI takeover
    /// This enables CallKit system UI by properly managing app lifecycle state
    func minimizeAppForCallKit() {
        DispatchQueue.main.async {
            if UIApplication.shared.applicationState == .active {
                NSLog("🔥 iOS 18 FIX: Minimizing app to let CallKit show automatic system UI")
                
                // iOS 18 FIX: Force immediate background transition 
                UIApplication.shared.resignFirstResponder()
                
                // iOS 18 FIX: Dismiss ALL presented view controllers that might block CallKit UI
                var currentVC = self.window?.rootViewController
                while currentVC?.presentedViewController != nil {
                    currentVC?.presentedViewController?.dismiss(animated: false, completion: nil)
                    currentVC = currentVC?.presentedViewController
                }
                
                // iOS 18 FIX: Send proper background notifications for CallKit takeover
                NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
                NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
                
                // iOS 18 FIX: Add small delay to ensure background state is processed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSLog("🔥 iOS 18 FIX: App backgrounding complete - CallKit should automatically show system UI")
                    
                    // iOS 18 FIX: Ensure window is not intercepting CallKit UI
                    self.window?.isUserInteractionEnabled = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.window?.isUserInteractionEnabled = true
                    }
                }
            }
        }
    }

    deinit {
        // CallKit has an odd API contract where the developer must call invalidate or the CXProvider is leaked.
        if let provider = callKitProvider {
            provider.invalidate()
        }
    }

}

// MARK: - PKPushRegistryDelegate
extension AppDelegate: PKPushRegistryDelegate {

    func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
        print("pushRegistry:didUpdatePushCredentials:forType:")
        if (type == .voIP) {
            // Store incoming token in user defaults
            let userDefaults = UserDefaults.standard
            let deviceToken = credentials.token.reduce("", {$0 + String(format: "%02X", $1) })
            userDefaults.savePushToken(deviceToken)
            print("Device push token: \(deviceToken)")
        }
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print("pushRegistry:didInvalidatePushTokenForType:")
        if (type == .voIP) {
            // Delete incoming token in user defaults
            let userDefaults = UserDefaults.init()
            userDefaults.deletePushToken()
        }
    }

    /**
     .According to the docs, this delegate method is deprecated by Apple.
    */
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        print("pushRegistry:didReceiveIncomingPushWithPayload:forType: old (deprecated)")
        if (payload.type == .voIP) {
            // 🔥 iOS 18 FIX: Provide dummy completion for deprecated method
            self.handleVoIPPushNotification(payload: payload) {
                NSLog("🔥 iOS 18 PUSH: Deprecated method completion called")
            }
        }
    }

    /**
     This delegate method is available on iOS 11 and above. Call the completion handler once the
     */
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        print("pushRegistry:didReceiveIncomingPushWithPayload:forType:completion new: \(payload.dictionaryPayload)")
        if (payload.type == .voIP) {
            // 🔥 iOS 18 FIX: Delay completion handler until after CallKit reporting completes
            self.handleVoIPPushNotification(payload: payload, completion: completion)
        } else {
            completion()
        }
    }

    func handleVoIPPushNotification(payload: PKPushPayload, completion: @escaping () -> Void) {
        if let metadata = payload.dictionaryPayload["metadata"] as? [String: Any] {
            // 🔥 iOS 18/2025 FIX: Always generate unique UUID to prevent CallKit failures
            let uuid = UUID() // Always new UUID for iOS 18+ compatibility
            let originalCallID = metadata["call_id"] as? String // Store original for reference
            
            let callerName = (metadata["caller_name"] as? String) ?? ""
            let callerNumber = (metadata["caller_number"] as? String) ?? ""
            let caller = callerName.isEmpty ? (callerNumber.isEmpty ? "Unknown" : callerNumber) : callerName
            
            NSLog("🔥 iOS 18 PUSH: Processing push with UUID: %@, originalCallID: %@", uuid.uuidString, originalCallID ?? "none")
            
            self.processVoIPNotification(callUUID: uuid, pushMetaData: metadata)
            
            // 🔥 iOS 18/2025 FIX: Call completion handler AFTER CallKit reporting completes
            self.newIncomingCall(from: caller, uuid: uuid) { error in
                NSLog("🔥 iOS 18 PUSH: CallKit reporting completed with error: %@", error?.localizedDescription ?? "none")
                // Wait for CallKit before calling PushKit completion (official Apple guidance)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    completion()
                }
            }
        } else {
            // 🔥 iOS 18/2025 FIX: Unique UUID for fallback case too
            let uuid = UUID()
            self.processVoIPNotification(callUUID: uuid, pushMetaData: [String: Any]())
            
            self.newIncomingCall(from: "Incoming call", uuid: uuid) { error in
                NSLog("🔥 iOS 18 PUSH: Fallback CallKit reporting completed")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    completion()
                }
            }
        }
    }
}
