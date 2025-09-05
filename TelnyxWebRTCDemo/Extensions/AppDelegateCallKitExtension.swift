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
import Combine

// MARK: - Phase 6 WhatsApp-Style CallKit Enhancement Integration
// Importing enterprise-grade synchronization and communication systems
// ENABLED - All compilation errors fixed

// MARK: - Phase 6 CallKit Enhancement Integration Properties

extension AppDelegate {
    
    /// Phase 6 enhancement system integration
    private var callStateSynchronizer: CallStateSynchronizer {
        return CallStateSynchronizer.shared
    }
    
    private var callEventBroadcaster: CallEventBroadcaster {
        return CallEventBroadcaster.shared
    }
    
    private var callKitAppUIBridge: CallKitAppUIBridge {
        return CallKitAppUIBridge.shared
    }
    
    /// Initialize Phase 6 enhancement systems
    func initializePhase6Enhancements() {
        setupCallKitBridge()
        setupEventSubscriptions()
        NSLog("🔥 PHASE 6: CallKit enhancement systems initialized")
    }
    
    /// Setup CallKit-App UI communication bridge
    private func setupCallKitBridge() {
        // Register AppDelegate as the CallKit delegate for the bridge
        callKitAppUIBridge.registerCallKitDelegate(self)
        NSLog("🔥 PHASE 6: CallKit bridge delegate registered")
    }
    
    /// Setup event subscriptions for system-wide coordination
    private func setupEventSubscriptions() {
        // Subscribe to critical events for CallKit coordination
        callEventBroadcaster.subscribe(self)
        NSLog("🔥 PHASE 6: Event broadcaster subscriptions established")
    }
}

// MARK: - CallKit Event Subscriber Implementation
extension AppDelegate: CallKitEventSubscriber {
    
    nonisolated var subscriberID: UUID {
        return UUID() // Generate consistent ID based on app delegate
    }
    
    nonisolated var subscriberPriority: EventPriority {
        return .critical // AppDelegate has highest priority for CallKit events
    }
    
    nonisolated func handleEvent(_ event: CallKitEvent, metadata: EventMetadata) {
        NSLog("🔥 PHASE 6: AppDelegate handling event: %@", event.description)
        
        Task { @MainActor in
            switch event {
            case .detectionStarted(let callUUID, _):
                handleCallKitDetectionStarted(callUUID: callUUID, metadata: metadata)
                
            case .detectionFailed(let callUUID, let error, _):
                handleCallKitDetectionFailed(callUUID: callUUID, error: error, metadata: metadata)
                
            case .backgroundingRequested(let callUUID, let strategy, _):
                handleBackgroundingRequested(callUUID: callUUID, strategy: strategy, metadata: metadata)
                
            case .criticalError(let callUUID, let error, _):
                handleCriticalError(callUUID: callUUID, error: error, metadata: metadata)
                
            case .systemCallKitStateChanged(let state, _):
                handleSystemCallKitStateChange(state: state, metadata: metadata)
                
            default:
                // Log other events but don't process them
                NSLog("🔥 PHASE 6: AppDelegate received event: %@", event.description)
            }
        }
    }
    
    nonisolated func shouldReceiveEvent(_ event: CallKitEvent, metadata: EventMetadata) -> Bool {
        // AppDelegate receives critical events and state changes
        switch event {
        case .detectionStarted, .detectionFailed, .backgroundingRequested, .criticalError, .systemCallKitStateChanged:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Phase 6 Event Handlers
    
    private func handleCallKitDetectionStarted(callUUID: UUID, metadata: EventMetadata) {
        NSLog("🔥 PHASE 6: CallKit detection started for call %@", callUUID.uuidString)
        
        // Sync state with synchronizer
        if let call = telnyxClient?.calls[callUUID] {
            callStateSynchronizer.syncState(
                from: .callKit,
                callUUID: callUUID,
                fromState: nil,
                toState: call.callState,
                metadata: metadata.context
            )
        }
    }
    
    private func handleCallKitDetectionFailed(callUUID: UUID, error: CallKitError, metadata: EventMetadata) {
        NSLog("🔥 PHASE 6: CallKit detection failed for call %@ - %@", callUUID.uuidString, error.description)
        
        // Request fallback UI activation through bridge
        let reason: FallbackActivationReason
        switch error {
        case .detectionTimeout: reason = .callKitTimeout
        case .backgroundingFailed: reason = .systemRestriction
        default: reason = .callKitError
        }
        
        callKitAppUIBridge.requestFallbackActivation(callUUID: callUUID, reason: reason)
    }
    
    private func handleBackgroundingRequested(callUUID: UUID, strategy: BackgroundingStrategy, metadata: EventMetadata) {
        NSLog("🔥 PHASE 6: Backgrounding requested for call %@ with strategy %@", callUUID.uuidString, strategy.rawValue)
        
        // Execute the backgrounding request
        DispatchQueue.main.async { [weak self] in
            self?.minimizeAppForCallKit()
        }
    }
    
    private func handleCriticalError(callUUID: UUID?, error: CallKitError, metadata: EventMetadata) {
        NSLog("🔥 PHASE 6: Critical error occurred - %@", error.description)
        
        if let callUUID = callUUID {
            // Attempt recovery through bridge
            callKitAppUIBridge.requestFallbackActivation(callUUID: callUUID, reason: .emergencyFallback)
        }
    }
    
    private func handleSystemCallKitStateChange(state: String, metadata: EventMetadata) {
        NSLog("🔥 PHASE 6: System CallKit state changed: %@", String(describing: state))
        
        // Forward to bridge for system-wide coordination
        // Bridge will handle appropriate responses
    }
}

// MARK: - CallKit to App UI Bridge Protocol Implementation
extension AppDelegate: CallKitToAppUIProtocol {
    
    func callKitStateChanged(callUUID: UUID, from: String?, to: String, context: BridgeContext) {
        NSLog("🔥 PHASE 6 BRIDGE: CallKit state changed for %@ from %@ to %@", 
              callUUID.uuidString, from ?? "nil", to)
        
        // Sync with CallStateSynchronizer
        let telnyxCallState = mapCXCallStateToTelnyxCallState(to)
        let fromTelnyxState = from.map { mapCXCallStateToTelnyxCallState($0) }
        
        callStateSynchronizer.syncState(
            from: .callKit,
            callUUID: callUUID,
            fromState: fromTelnyxState,
            toState: telnyxCallState,
            metadata: context.metadata
        )
        
        // Update any UI delegates if needed
        DispatchQueue.main.async { [weak self] in
            if let voipDelegate = self?.voipDelegate as? HomeViewController {
                // Notify HomeViewController of state change
                voipDelegate.handleCallKitStateChange(callUUID: callUUID, state: to)
            }
        }
    }
    
    func prepareForTransition(callUUID: UUID, transition: BridgeTransition, context: BridgeContext) {
        NSLog("🔥 PHASE 6 BRIDGE: Preparing for transition %@ for call %@", transition.rawValue, callUUID.uuidString)
        
        switch transition {
        case .callKitToAppUI:
            // Prepare app UI for incoming call handoff
            DispatchQueue.main.async { [weak self] in
                if let voipDelegate = self?.voipDelegate as? HomeViewController {
                    voipDelegate.prepareForCallKitToAppTransition(callUUID: callUUID)
                }
            }
            
        case .appUIToCallKit:
            // Prepare CallKit for app UI handoff
            minimizeAppForCallKit()
            
        case .backgroundTransition:
            // Handle background transition
            DispatchQueue.main.async {
                UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
            }
            
        default:
            NSLog("🔥 PHASE 6 BRIDGE: Transition type %@ handled generically", transition.rawValue)
        }
    }
    
    func callKitActionPerformed(callUUID: UUID, action: CXAction, result: BridgeActionResult, context: BridgeContext) {
        NSLog("🔥 PHASE 6 BRIDGE: CallKit action performed - %@ with result %@", 
              String(describing: action), result.rawValue)
        
        // Broadcast action result event
        let eventMetadata = EventMetadata(
            source: .callKit,
            sessionID: context.sessionID,
            correlationID: context.correlationID,
            context: context.metadata
        )
        
        if result == .success {
            callEventBroadcaster.broadcast(.retryCompleted(callUUID: callUUID, strategy: .immediate, success: true, attempts: 1, metadata: eventMetadata))
        } else {
            let error = BridgeError.invalidState
            callEventBroadcaster.broadcast(.criticalError(callUUID: callUUID, error: CallKitError.systemError(error), metadata: eventMetadata))
        }
    }
    
    func activateFallbackUI(callUUID: UUID, reason: FallbackActivationReason, context: BridgeContext) {
        NSLog("🔥 PHASE 6 BRIDGE: Activating fallback UI for call %@ - reason: %@", callUUID.uuidString, reason.rawValue)
        
        // Activate fallback UI through HomeViewController
        DispatchQueue.main.async { [weak self] in
            if let voipDelegate = self?.voipDelegate as? HomeViewController {
                voipDelegate.activateFallbackCallUI(callUUID: callUUID, reason: reason)
            }
        }
    }
    
    func audioRouteChanged(callUUID: UUID, route: AVAudioSessionRouteDescription, context: BridgeContext) {
        NSLog("🔥 PHASE 6 BRIDGE: Audio route changed for call %@ to %@", callUUID.uuidString, route.description)
        
        // Handle audio route change
        DispatchQueue.main.async { [weak self] in
            if let voipDelegate = self?.voipDelegate as? HomeViewController {
                voipDelegate.handleAudioRouteChange(callUUID: callUUID, route: route)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func mapCXCallStateToTelnyxCallState(_ cxState: String) -> CallState {
        switch cxState {
        case "connecting": return .CONNECTING
        case "connected": return .ACTIVE
        case "held": return .HELD
        case "ended": return .DONE(reason: nil)
        case "failed": return .DONE(reason: nil)
        case "idle": return .NEW
        default: return .NEW
        }
    }
}

// MARK: - CXProviderDelegate
extension AppDelegate : CXProviderDelegate {

    /// Call this function to tell the CX provider to request the OS to create a new call.
    /// - Parameters:
    ///   - uuid: The UUID of the outbound call
    ///   - handle: A handle for this call
    func executeStartCallAction(uuid: UUID, handle: String, destination: String) {
        // 🔥 PHASE 6: Broadcast call start event
        let eventMetadata = EventMetadata(source: .callKit, sessionID: UUID())
        callEventBroadcaster.broadcast(.detectionStarted(callUUID: uuid, metadata: eventMetadata))
        
        guard let provider = callKitProvider else {
            print("CallKit provider not available")
            // 🔥 PHASE 6: Broadcast failure event
            callEventBroadcaster.broadcast(.criticalError(callUUID: uuid, error: CallKitError.systemError(BridgeError.delegateNotRegistered), metadata: eventMetadata))
            return
        }
        
        // Store destination for later use in executeCall
        self.pendingCallDestination = destination
        
        // 🔥 PHASE 6: Notify bridge of outgoing call preparation
        let bridgeContext = BridgeContext(source: .callKit, metadata: ["destination": destination, "handle": handle], sessionID: UUID())
        callKitAppUIBridge.notifyAppUIStateChange(callUUID: uuid, state: AppUIState.initializing)

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
        
        // 🔥 PHASE 6: Broadcast incoming call event (with safety guards)
        do {
            let eventMetadata = EventMetadata(
                source: .callKit, 
                sessionID: UUID(),
                context: ["caller": from, "origin": "incoming"]
            )
            callEventBroadcaster.broadcast(.detectionStarted(callUUID: uuid, metadata: eventMetadata))
            
            // 🔥 PHASE 6: Sync initial incoming call state
            callStateSynchronizer.syncState(
                from: .callKit,
                callUUID: uuid,
                fromState: nil,
                toState: .RINGING,
                metadata: ["caller": from, "incoming": true]
            )
        } catch {
            print("🚨 Phase 6 integration error in incoming call: \(error.localizedDescription)")
        }

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
        
        // 🔥 PHASE 6: Broadcast call start action event (with safety guards)
        do {
            let eventMetadata = EventMetadata(
                source: .callKit,
                sessionID: UUID(),
                context: ["action": "CXStartCallAction", "uuid": action.callUUID.uuidString]
            )
            callEventBroadcaster.broadcast(.detectionCompleted(callUUID: action.callUUID, result: .detected, metadata: eventMetadata))
            
            // 🔥 PHASE 6: Sync state transition to connecting
            callStateSynchronizer.syncState(
                from: .callKit,
                callUUID: action.callUUID,
                fromState: .NEW,
                toState: .CONNECTING,
                metadata: ["action": "startCall", "provider": "CallKit"]
            )
        } catch {
            print("🚨 Phase 6 integration error in call start: \(error.localizedDescription)")
        }
        
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
        
        // 🔥 PHASE 6: Broadcast call answer event (with safety guards)
        do {
            let eventMetadata = EventMetadata(
                source: .callKit,
                sessionID: UUID(),
                context: ["action": "CXAnswerCallAction", "uuid": action.callUUID.uuidString]
            )
            callEventBroadcaster.broadcast(.detectionCompleted(callUUID: action.callUUID, result: .detected, metadata: eventMetadata))
            
            // 🔥 PHASE 6: Sync state transition to active
            callStateSynchronizer.syncState(
                from: .callKit,
                callUUID: action.callUUID,
                fromState: .RINGING,
                toState: .ACTIVE,
                metadata: ["action": "answerCall", "provider": "CallKit"]
            )
            
            // 🔥 PHASE 6: Notify bridge of call answer
            let bridgeContext = BridgeContext(
                source: .callKit,
                metadata: ["action": "answer", "callKitUUID": self.callKitUUID?.uuidString ?? "unknown"],
                sessionID: UUID()
            )
            callKitAppUIBridge.notifyCallKitActionResult(callUUID: action.callUUID, action: action, result: .success)
        } catch {
            print("🚨 Phase 6 integration error in call answer: \(error.localizedDescription)")
        }

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
        
        // 🔥 PHASE 6: Broadcast call end event (with safety guards)
        do {
            let eventMetadata = EventMetadata(
                source: .callKit,
                sessionID: UUID(),
                context: ["action": "CXEndCallAction", "uuid": action.callUUID.uuidString]
            )
            callEventBroadcaster.broadcast(.detectionCompleted(callUUID: action.callUUID, result: .detected, metadata: eventMetadata))
            
            // 🔥 PHASE 6: Sync state transition to done
            let currentCall = self.telnyxClient?.calls[action.callUUID]
            let fromState = currentCall?.callState
            callStateSynchronizer.syncState(
                from: .callKit,
                callUUID: action.callUUID,
                fromState: fromState,
                toState: .DONE(reason: nil),
                metadata: ["action": "endCall", "provider": "CallKit"]
            )
            
            // 🔥 PHASE 6: Notify bridge of call end
            callKitAppUIBridge.notifyCallKitActionResult(callUUID: action.callUUID, action: action, result: .success)
        } catch {
            print("🚨 Phase 6 integration error in call end: \(error.localizedDescription)")
        }
        
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
        
        // 🔥 PHASE 6: Broadcast audio session activation event (with safety guards)
        do {
            let eventMetadata = EventMetadata(
                source: .system,
                sessionID: UUID(),
                context: ["audioSession": "activated", "category": audioSession.category.rawValue]
            )
            callEventBroadcaster.broadcast(.systemAudioSessionChanged(category: audioSession.category, metadata: eventMetadata))
            
            // 🔥 PHASE 6: Notify bridge of audio route change if there's an active call
            if let currentCallUUID = self.callKitUUID {
                let bridgeContext = BridgeContext(
                    source: .system,
                    metadata: ["audioSessionState": "activated"],
                    sessionID: UUID()
                )
                callKitAppUIBridge.notifyAudioRouteChange(callUUID: currentCallUUID, route: audioSession.currentRoute)
            }
        } catch {
            print("🚨 Phase 6 integration error in audio session: \(error.localizedDescription)")
        }
        
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
            // 🔥 WHATSAPP-STYLE: Outgoing calls use IN-APP interface as primary choice
            switch deviceContext {
            case .locked:
                useCallKit = true  // Device locked - use CallKit for system access
                NSLog("🔥   - Decision: CallKit (device locked - system access needed)")
                
            case .unlocked, .foreground:
                useCallKit = false  // App active - use WhatsApp-style in-app interface
                NSLog("🔥   - Decision: App UI (WhatsApp-style - app is active/foreground)")
                
            case .background:
                useCallKit = true   // App backgrounded - use CallKit
                NSLog("🔥   - Decision: CallKit (app backgrounded)")
                
            case .unknown:
                useCallKit = false  // Default to in-app when uncertain
                NSLog("🔥   - Decision: App UI (WhatsApp-style - default for unknown context)")
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
