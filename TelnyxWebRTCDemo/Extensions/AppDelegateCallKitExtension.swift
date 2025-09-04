//
//  AppDelegateCallKitExtension.swift
//  TelnyxWebRTCDemo
//
//  Created by Guillermo Battistel on 25/08/2021.
//

import Foundation
import UIKit
import AVFoundation
import TelnyxRTC
import CallKit

// MARK: - CXProviderDelegate
extension AppDelegate : CXProviderDelegate {

    /// Call this function to tell the CX provider to request the OS to create a new call.
    /// - Parameters:
    ///   - uuid: The UUID of the outbound call
    ///   - handle: A handle for this call
    func executeStartCallAction(uuid: UUID, handle: String, destination: String) {
        guard let provider = callKitProvider else {
            print("CallKit provider not available")
            return
        }
        
        // Store destination for later use in executeCall
        self.pendingCallDestination = destination

        let callHandle = CXHandle(type: .generic, value: handle)
        let startCallAction = CXStartCallAction(call: uuid, handle: callHandle)
        let transaction = CXTransaction(action: startCallAction)

        callKitCallController.request(transaction) { error in
            if let error = error {
                print("StartCallAction transaction request failed: \(error.localizedDescription)")
                return
            }

            print("StartCallAction transaction request successful")

            let callUpdate = CXCallUpdate()
            

            callUpdate.remoteHandle = callHandle
            callUpdate.supportsDTMF = true
            callUpdate.supportsHolding = true
            callUpdate.supportsGrouping = false
            callUpdate.supportsUngrouping = false
            callUpdate.hasVideo = false
            provider.reportCall(with: uuid, updated: callUpdate)
        }
    }
    
    func executeOutGoingCall() {
        // 🔥 CALLKIT-ONLY: This method is now handled in CXStartCallAction callback
        // Call state reporting is done directly in provider(_ provider: CXProvider, perform action: CXStartCallAction)
        NSLog("🔥 CALLKIT-ONLY: executeOutGoingCall called but state reporting handled in CXStartCallAction")
        self.isCallOutGoing = false
    }

    /// Report a new incoming call. This will generate the Native Incoming call notification
    /// - Parameters:
    ///   - from: Caller name
    ///   - uuid: uuid of the incoming call
    ///   - completion: iOS 18/2025 completion handler for proper PushKit timing
    func newIncomingCall(from: String, uuid: UUID, completion: ((Error?) -> Void)? = nil) {
        print("AppDelegate:: report NEW incoming call from [\(from)] uuid [\(uuid)]")

        // 🔥 iOS 18 FIX: 100% CALLKIT-ONLY - No routing decisions
        // All calls MUST use CallKit for iOS 18 automatic UI switching compatibility
        let shouldUseCallKit = true  // ALWAYS TRUE for iOS 18 compatibility
        
        print("🔥 iOS 18 FIX: CALLKIT-ONLY mode - always using CallKit for [\(from)]")
        
        if let call = self.telnyxClient?.calls[uuid] {
            // 🔧 FIX: Track incoming call in call history database
            let callerName = call.callInfo?.callerName ?? ""
            let phoneNumber = call.callInfo?.callerNumber ?? ""
            
            CallHistoryDatabase.shared.createCallHistoryEntry(
                callerName: callerName,
                callId: uuid,
                callStatus: "incoming", // Initial status for incoming calls
                direction: "incoming",
                metadata: "",
                phoneNumber: phoneNumber,
                profileId: "default", // Using default profile as per UI
                timestamp: Date()
            ) { success in
                print("📞 CALL HISTORY: Incoming call \(success ? "stored" : "failed to store") - \(phoneNumber)")
            }
        }

        #if targetEnvironment(simulator)
        //Do not execute this function when debugging on the simulator.
        //By reporting a call through CallKit from the simulator, it automatically cancels the call.
        print("🔥 SIMULATOR: Skipping CallKit registration (simulator limitation)")
        return
        #endif

        if shouldUseCallKit {
            // Standard incoming call flow - use CallKit for native experience
            print("🔥 INCOMING CALL: Using CallKit for native iOS incoming call experience")
            
            guard let provider = callKitProvider else {
                print("AppDelegate:: CallKit provider not available")
                return
            }

            let callHandle = CXHandle(type: .generic, value: from)
            let callUpdate = CXCallUpdate()
            callUpdate.remoteHandle = callHandle
            callUpdate.hasVideo = false

            provider.reportNewIncomingCall(with: uuid, update: callUpdate) { error in
                if let error = error {
                    print("🔥 iOS 18 CALLKIT: Failed to report incoming call: \(error.localizedDescription)")
                    // Notify router of failure
                    CallInterfaceRouter.shared.callDidEnd(uuid)
                    // Track failed incoming call
                    // CallHistoryManager.shared.handleCallFailed(callId: uuid)
                } else {
                    print("🔥 iOS 18 CALLKIT: Incoming call successfully reported to CallKit")
                }
                
                // 🔥 iOS 18/2025 FIX: Call completion handler after CallKit reporting completes
                completion?(error)
            }
            
        } else {
            // Rare case: Direct app UI for incoming call (very unusual, but supported)
            print("🔥 INCOMING CALL: Using App UI for incoming call (rare case)")
            
            // For completeness - handle direct incoming call to app UI
            // This would be unusual but might be needed for special scenarios
            DispatchQueue.main.async {
                // Update UI to show incoming call directly in app
                if let voipDelegate = self.voipDelegate as? HomeViewController {
                    if let call = self.telnyxClient?.calls[uuid] {
                        voipDelegate.onIncomingCall(call: call)
                    }
                }
                
                // 🔥 iOS 18/2025 FIX: Call completion handler for app UI case too
                completion?(nil)
            }
        }
    }
    
    /// To answer a call using CallKit
    /// - Parameter uuid: the UUID of the CallKit call.
    func executeAnswerCallAction(uuid: UUID) {
        print("AppDelegate:: execute ANSWER call action: callKitUUID [\(String(describing: self.callKitUUID))] uuid [\(uuid)]")
        var endUUID = uuid
        if let callkitUUID = self.callKitUUID {
            endUUID = callkitUUID
        }
        let answerCallAction = CXAnswerCallAction(call: endUUID)
        let transaction = CXTransaction(action: answerCallAction)
        callKitCallController.request(transaction) { error in
            if let error = error {
                print("AppDelegate:: AnswerCallAction transaction request failed: \(error.localizedDescription).")
            } else {
                print("AppDelegate:: AnswerCallAction transaction request successful")
            }
        }
    }

    /// End the current call
    /// - Parameter uuid: The uuid of the call
    func executeEndCallAction(uuid: UUID) {
        print("AppDelegate:: execute END call action: callKitUUID [\(String(describing: self.callKitUUID))] uuid [\(uuid)]")

        var endUUID = uuid
        if let callkitUUID = self.callKitUUID {
            endUUID = callkitUUID
        }

        let endCallAction = CXEndCallAction(call: endUUID)
        let transaction = CXTransaction(action: endCallAction)
        

        callKitCallController.request(transaction) { error in
            if let error = error {
                #if targetEnvironment(simulator)
                //The simulator does not support to register an incoming call through CallKit.
                //For that reason when an incoming call is received on the simulator,
                //we are updating the UI and not registering the callID to callkit.
                //When the user wants to hangup the call and the incoming call was not registered in callkit,
                //the CXEndCallAction fails. That's why we are manually ending the call in this case.
                self.telnyxClient?.calls[uuid]?.hangup() // end the active call
                #endif
                print("AppDelegate:: EndCallAction transaction request failed: \(error.localizedDescription).")
            } else {
                print("AppDelegate:: EndCallAction transaction request successful")
            }
            self.callKitUUID = nil
        }
    }
    
    func executeMuteUnmuteAction(uuid: UUID, mute: Bool) {
        let muteAction = CXSetMutedCallAction(call: uuid, muted: mute)
        let transaction = CXTransaction(action: muteAction)
        
        callKitCallController.request(transaction) { error in
            if let error = error {
                print("Error executing mute/unmute action: \(error.localizedDescription)")
            } else {
                print("Successfully executed mute/unmute action. Mute: \(mute)")
            }
        }
    }
    
    // MARK: - CXProviderDelegate -
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        NSLog("🔥 CALLKIT-ONLY: CXStartCallAction delegate called")
        NSLog("🔥 CALLKIT-ONLY: CallKit UUID received: %@", action.callUUID.uuidString)
        NSLog("🔥 CALLKIT-ONLY: Setting callKitUUID = %@", action.callUUID.uuidString)
        self.callKitUUID = action.callUUID
        
        // 🔥 CALLKIT-ONLY: Let CallKit handle all UI - no app interference
        NSLog("🔥 CALLKIT-ONLY: Requesting CallKit to take foreground control")
        
        // 🔥 CALLKIT OUTGOING: Trigger system UI by backgrounding app and reporting to CallKit
        DispatchQueue.main.async {
            // Step 1: Report outgoing call to CallKit
            provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
            NSLog("🔥 CALLKIT OUTGOING: Reported outgoing call started connecting")
            
            // Step 2: Background the app so CallKit can show system UI
            // This is the key to making outgoing calls show CallKit interface
            self.minimizeAppForCallKit()
        }
        
        NSLog("🟡 STEP 15: Checking PreCallDiagnosticManager.isRunning = %@", PreCallDiagnosticManager.shared.isRunning ? "true" : "false")
        if(!PreCallDiagnosticManager.shared.isRunning){
            NSLog("🟡 STEP 16: PreCallDiagnosticManager not blocking - proceeding with call")
            NSLog("🟡 STEP 17: Calling voipDelegate.executeCall() with UUID: %@", action.callUUID.uuidString)
            
            self.voipDelegate?.executeCall(callUUID: action.callUUID) { call in
                NSLog("🔥 CALLKIT-ONLY: voipDelegate.executeCall() callback received")
                self.currentCall = call
                if call != nil {
                    NSLog("🔥 CALLKIT OUTGOING: Call creation SUCCESSFUL - call object created")
                    self.isCallOutGoing = true
                    
                    // Report call connected to CallKit to maintain system UI
                    DispatchQueue.main.async {
                        provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())
                        NSLog("🔥 CALLKIT OUTGOING: Reported outgoing call connected - system UI should remain active")
                    }
                } else {
                    NSLog("🔥 CALLKIT OUTGOING: Call creation FAILED - call object is nil")
                    // Report call failed to CallKit
                    DispatchQueue.main.async {
                        provider.reportCall(with: action.callUUID, endedAt: Date(), reason: .failed)
                        NSLog("🔥 CALLKIT OUTGOING: Reported call failed to CallKit")
                    }
                }
            }
        } else {
            NSLog("🟡 STEP 16: BLOCKED - PreCallDiagnosticManager is running, call cannot proceed")
        }
        
        NSLog("🟡 STEP 20: Fulfilling CallKit action")
        action.fulfill()
        NSLog("🟡 STEP 21: CallKit phase completed")
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        NSLog("🔥 CALLKIT OUTGOING: ANSWER call action: callKitUUID [\(String(describing: self.callKitUUID))] action [\(action.callUUID)]")

        // 🔥 CALLKIT OUTGOING: Ensure CallKit system UI remains active for answered calls
        DispatchQueue.main.async {
            self.minimizeAppForCallKit()
            NSLog("🔥 CALLKIT OUTGOING: App backgrounded for incoming call answer - system UI active")
        }

        // Track incoming call answer in call history
        if let call = self.telnyxClient?.calls[action.callUUID] {
            let phoneNumber = call.callInfo?.callerNumber ?? "Unknown"
            let callerName = call.callInfo?.callerName
            // CallHistoryManager.shared.handleAnswerCallAction(
            //     action: action,
            //     phoneNumber: phoneNumber,
            //     callerName: callerName
            // )
        }

        self.telnyxClient?.answerFromCallkit(answerAction: action, customHeaders:  ["X-test-answer":"ios-test"],debug: true)
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("AppDelegate:: END call action: callKitUUID [\(String(describing: self.callKitUUID))] action [\(action.callUUID)]")
        
        // Track call end in call history
        if let call = self.telnyxClient?.calls[action.callUUID] {
            // Determine if this was a rejection or normal end
            let status: CallStatus
            switch call.callState {
            case .RINGING:
                status = .rejected
            case .CONNECTING, .NEW:
                status = .cancelled
            default:
                status = .answered
            }
// CallHistoryManager.shared.trackCallEnd(callId: action.callUUID, status: status)
        }



        if previousCall?.callState == .HELD {
            print("AppDelegate:: call held.. unholding call")
            previousCall?.unhold()
        }
        //Run when we want to end or accept/Decline
        if self.callKitUUID == action.callUUID {
            //request to end current call
            print("AppDelegate:: End Current Call")
            if let onGoingCall = self.previousCall {
                self.currentCall = onGoingCall
                self.callKitUUID = onGoingCall.callInfo?.callId
            }
        } else {
            //request to end Previous Call
            print("AppDelegate:: End Previous Call")
        }
        
        // 🔥 NOTIFY ROUTER OF CALL END 🔥
        NSLog("🔥 CALL END: Notifying router that call %@ ended", action.callUUID.uuidString)
        CallInterfaceRouter.shared.callDidEnd(action.callUUID)
        
        self.telnyxClient?.endCallFromCallkit(endAction: action)
    }

    func providerDidReset(_ provider: CXProvider) {
        print("providerDidReset:")
    }
    
    func providerDidBegin(_ provider: CXProvider) {
        print("providerDidBegin")
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("provider:didActivateAudioSession:")
        self.telnyxClient!.enableAudioSession(audioSession: audioSession)
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("provider:didDeactivateAudioSession:")
        self.telnyxClient!.disableAudioSession(audioSession: audioSession)
    }
    
    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        print("provider:timedOutPerformingAction:")
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        print("provider:performSetHeldAction:")
        //request to hold previous call
        previousCall?.hold()
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        print("provider:performSetMutedAction: \(action.isMuted)")
        if let call = currentCall {
            if action.isMuted {
                print("provider:performSetMutedAction: incoming action to mute call")
                call.muteAudio()
            } else {
                print("provider:performSetMutedAction: incoming action to unmute call")
                call.unmuteAudio()
            }
            print("provider:performSetMutedAction: call.isMuted \(call.isMuted)")
        }
        action.fulfill()
    }
    
    func processVoIPNotification(callUUID: UUID,pushMetaData:[String: Any]) {
        print("AppDelegate:: processVoIPNotification \(callUUID)")
        self.callKitUUID = callUUID
        var serverConfig: TxServerConfiguration
        let userDefaults = UserDefaults.init()
        if userDefaults.getEnvironment() == .development {
            serverConfig = TxServerConfiguration(environment: .development)
        } else {
            serverConfig = TxServerConfiguration(environment: .production)
        }
        
        let selectedCredentials = SipCredentialsManager.shared.getSelectedCredential()
        
        if selectedCredentials?.isToken ?? false {
            let token = selectedCredentials?.username ?? ""
            let deviceToken = userDefaults.getPushToken()
            //Sets the login credentials and the ringtone/ringback configurations if required.
            //Ringtone / ringback tone files are not mandatory.
            let txConfig = TxConfig(token: token,
                                    pushDeviceToken: deviceToken,
                                    ringtone: "incoming_call.mp3",
                                    ringBackTone: "ringback_tone.mp3",
                                    //You can choose the appropriate verbosity level of the SDK.
                                    logLevel: .all,
                                    reconnectClient: true,
                                    // Enable WebRTC stats debug
                                    debug: true,
                                    // Force relay candidate
                                    forceRelayCandidate: false,
                                    // Enable Call Quality Metrics
                                    enableQualityMetrics: true)
            
            do {
                try telnyxClient?.processVoIPNotification(txConfig: txConfig, serverConfiguration: serverConfig,pushMetaData: pushMetaData)
            } catch let error {
                print("AppDelegate:: processVoIPNotification Error \(error)")
            }
        } else {
            let sipUser = selectedCredentials?.username ?? ""
            let password = selectedCredentials?.password ?? ""
            let deviceToken = userDefaults.getPushToken()
            //Sets the login credentials and the ringtone/ringback configurations if required.
            //Ringtone / ringback tone files are not mandatory.
            let txConfig = TxConfig(sipUser: sipUser,
                                    password: password,
                                    pushDeviceToken: deviceToken,
                                    ringtone: "incoming_call.mp3",
                                    ringBackTone: "ringback_tone.mp3",
                                    //You can choose the appropriate verbosity level of the SDK.
                                    logLevel: .all,
                                    reconnectClient: true,
                                    // Enable WebRTC stats debug
                                    debug: true,
                                    // Force relay candidate
                                    forceRelayCandidate: false,
                                    // Enable Call Quality Metrics
                                    enableQualityMetrics: true)
            
            do {
                try telnyxClient?.processVoIPNotification(txConfig: txConfig, serverConfiguration: serverConfig,pushMetaData: pushMetaData)
            } catch let error {
                print("AppDelegate:: processVoIPNotification Error \(error)")
            }
        }
        
        
       
    }
    
    // MARK: - Transition Handling
    
    /// Shows WhatsApp-style transition indicator for switching to app UI
    /// - Parameter callId: UUID of the active call
    private func showCallTransitionIndicator(for callId: UUID) {
        NSLog("🔥 TRANSITION INDICATOR: Showing transition indicator for call %@", callId.uuidString)
        
        DispatchQueue.main.async {
            // Notify the HomeViewController to show the transition UI
            if let voipDelegate = self.voipDelegate as? HomeViewController {
                voipDelegate.showCallTransitionToAppUI(for: callId)
            }
            
            // You could also show a system-level indicator here
            // For example, a banner notification or status bar indicator
        }
    }
}

// MARK: - CallInterfaceRouter Implementation

/// Enum defining the call interface strategy
enum CallInterfaceStrategy {
    case appUI          // Use custom app interface
    case callKit        // Use native CallKit interface
    case hybrid         // Dynamic routing based on context
}

/// Enum defining device context states
enum DeviceContext {
    case locked
    case unlocked
    case background
    case foreground
    case unknown
}

/// Enum defining call origin
public enum CallOrigin {
    case outgoing       // User initiated from app
    case incoming       // Incoming from network
    case pushNotification // From push notification
}

/// Protocol for call interface routing decisions
protocol CallInterfaceRouterDelegate: AnyObject {
    func shouldUseCallKit(for origin: CallOrigin, context: DeviceContext) -> Bool
    func callInterfaceDidChange(to strategy: CallInterfaceStrategy, for callId: UUID)
    func shouldTransitionToAppUI(for callId: UUID, from callKitUI: Bool) -> Bool
}

/// Central routing manager for call interfaces - WhatsApp style hybrid approach
public class CallInterfaceRouter: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = CallInterfaceRouter()
    
    // MARK: - Published Properties
    @Published private(set) var currentStrategy: CallInterfaceStrategy = .hybrid
    @Published private(set) var deviceContext: DeviceContext = .unknown
    @Published private(set) var activeCallIds: Set<UUID> = []
    
    // MARK: - Private Properties
    private var callInterfaceStates: [UUID: CallInterfaceStrategy] = [:]
    private var callOrigins: [UUID: CallOrigin] = [:]
    private var contextObserver: Any?
    
    // MARK: - Delegate
    weak var delegate: CallInterfaceRouterDelegate?
    
    // MARK: - Initialization
    private init() {
        setupDeviceContextObserver()
        updateDeviceContext()
    }
    
    deinit {
        if let observer = contextObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Public Interface
    
    /// Main routing decision method - determines interface for call
    /// - Parameters:
    ///   - callId: UUID of the call
    ///   - origin: How the call was initiated
    ///   - destination: Destination number/identifier
    /// - Returns: True if should use CallKit, false if should use app UI
    public func shouldUseCallKit(for callId: UUID, origin: CallOrigin, destination: String) -> Bool {
        
        NSLog("🔥 CallInterfaceRouter: Routing decision for callId: %@", callId.uuidString)
        NSLog("🔥   - Origin: %@", String(describing: origin))
        NSLog("🔥   - Device Context: %@", String(describing: deviceContext))
        NSLog("🔥   - Current Strategy: %@", String(describing: currentStrategy))
        
        // Store call metadata
        callOrigins[callId] = origin
        activeCallIds.insert(callId)
        
        // WhatsApp-style routing logic
        let useCallKit: Bool
        
        switch origin {
        case .incoming, .pushNotification:
            // Incoming calls ALWAYS use CallKit for native iOS experience
            useCallKit = true
            NSLog("🔥   - Decision: CallKit (incoming calls always use CallKit)")
            
        case .outgoing:
            // 🔥 CALLKIT-ONLY: All outgoing calls use CallKit for consistent native experience
            useCallKit = true
            NSLog("🔥   - Decision: CallKit (CALLKIT-ONLY implementation - all outgoing calls use CallKit)")
            
            // Legacy device context logic - now all paths lead to CallKit
            switch deviceContext {
            case .locked:
                NSLog("🔥     - Device Context: locked (CallKit)")
                
            case .unlocked, .foreground:
                NSLog("🔥     - Device Context: unlocked/foreground (CallKit-only override)")
                
            case .background:
                NSLog("🔥     - Device Context: background (CallKit)")
                
            case .unknown:
                NSLog("🔥     - Device Context: unknown (CallKit-only override)")
            }
        }
        
        // Store the decision
        callInterfaceStates[callId] = useCallKit ? .callKit : .appUI
        
        // Notify delegate
        delegate?.callInterfaceDidChange(to: callInterfaceStates[callId] ?? .callKit, for: callId)
        
        NSLog("🔥   - Final Decision: %@", useCallKit ? "CallKit" : "App UI")
        
        return useCallKit
    }
    
    /// Requests transition from CallKit to App UI (user taps app in CallKit)
    /// - Parameter callId: UUID of the call
    /// - Returns: True if transition is allowed
    func requestTransitionToAppUI(for callId: UUID) -> Bool {
        guard activeCallIds.contains(callId) else {
            NSLog("🔥 CallInterfaceRouter: Cannot transition - callId %@ not active", callId.uuidString)
            return false
        }
        
        guard callInterfaceStates[callId] == .callKit else {
            NSLog("🔥 CallInterfaceRouter: Cannot transition - call %@ not in CallKit mode", callId.uuidString)
            return false
        }
        
        NSLog("🔥 CallInterfaceRouter: Transitioning call %@ from CallKit to App UI", callId.uuidString)
        
        // Update state
        callInterfaceStates[callId] = .appUI
        
        // Notify delegate
        delegate?.callInterfaceDidChange(to: .appUI, for: callId)
        
        return true
    }
    
    /// Cleans up call tracking when call ends
    /// - Parameter callId: UUID of the ended call
    func callDidEnd(_ callId: UUID) {
        NSLog("🔥 CallInterfaceRouter: Call %@ ended, cleaning up", callId.uuidString)
        
        activeCallIds.remove(callId)
        callInterfaceStates.removeValue(forKey: callId)
        callOrigins.removeValue(forKey: callId)
    }
    
    /// Gets current interface strategy for a call
    /// - Parameter callId: UUID of the call
    /// - Returns: Current interface strategy, or nil if call not tracked
    func getCurrentStrategy(for callId: UUID) -> CallInterfaceStrategy? {
        return callInterfaceStates[callId]
    }
    
    /// Forces a specific strategy (for testing or special cases)
    /// - Parameter strategy: Strategy to force
    func forceStrategy(_ strategy: CallInterfaceStrategy) {
        NSLog("🔥 CallInterfaceRouter: Forcing strategy to %@", String(describing: strategy))
        currentStrategy = strategy
    }
    
    // MARK: - Private Methods
    
    private func setupDeviceContextObserver() {
        // Listen for app state changes
        contextObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateDeviceContext()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.deviceContext = .background
            NSLog("🔥 CallInterfaceRouter: Device context changed to background")
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateDeviceContext()
        }
    }
    
    private func updateDeviceContext() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let appState = UIApplication.shared.applicationState
            
            // Determine device context based on app state and other factors
            switch appState {
            case .active:
                // App is active and in foreground
                self.deviceContext = self.isDeviceLocked() ? .locked : .unlocked
                
            case .inactive:
                // App is transitioning or overlay is present
                self.deviceContext = .unlocked // Usually during transition
                
            case .background:
                // App is backgrounded
                self.deviceContext = .background
                
            @unknown default:
                self.deviceContext = .unknown
            }
            
            NSLog("🔥 CallInterfaceRouter: Device context updated to %@", String(describing: self.deviceContext))
        }
    }
    
    /// Attempts to detect if device is locked
    /// Note: This is a heuristic approach since iOS doesn't provide direct access
    private func isDeviceLocked() -> Bool {
        // Since iOS doesn't provide direct lock state access, we use heuristics
        // This is a simplified implementation - in production, you might use additional signals
        
        // If app became active from background and there was a significant time gap,
        // likely device was locked
        return false // For now, assume unlocked when app is active
        
        // More sophisticated detection could include:
        // - Monitoring for Face ID/Touch ID authentication events
        // - Tracking time between background/foreground transitions
        // - Using keychain accessibility as a proxy
        // - Monitoring for control center or notification center interactions
    }
}

// MARK: - Debug Extensions
extension CallInterfaceStrategy: CustomStringConvertible {
    var description: String {
        switch self {
        case .appUI: return "App UI"
        case .callKit: return "CallKit"
        case .hybrid: return "Hybrid"
        }
    }
}

extension DeviceContext: CustomStringConvertible {
    var description: String {
        switch self {
        case .locked: return "Locked"
        case .unlocked: return "Unlocked"
        case .background: return "Background"
        case .foreground: return "Foreground"
        case .unknown: return "Unknown"
        }
    }
}

extension CallOrigin: CustomStringConvertible {
    public var description: String {
        switch self {
        case .outgoing: return "Outgoing"
        case .incoming: return "Incoming"
        case .pushNotification: return "Push Notification"
        }
    }
}
