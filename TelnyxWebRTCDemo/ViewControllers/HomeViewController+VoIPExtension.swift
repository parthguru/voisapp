import Foundation
import UIKit
import AVFoundation
import PushKit
import TelnyxRTC
import Network

// MARK: - VoIPDelegate
extension HomeViewController : VoIPDelegate, TxClientDelegate {
    
    func onSocketConnected() {
        print("ViewController:: TxClientDelegate onSocketConnected()")
        DispatchQueue.main.async {
            self.viewModel.socketState = .connected
            self.sipCredentialsVC.dismiss(animated: false)
        }
        // Don't stop the timer here, wait for onClientReady
    }
    
    func onSocketDisconnected() {
        print("ViewController:: TxClientDelegate onSocketDisconnected()")
        
        // Stop the connection timer if it's running
        stopConnectionTimer()
        
        DispatchQueue.main.async {
            self.viewModel.isLoading = false
            self.viewModel.socketState = .disconnected
        }
    }
    
    func onClientError(error: Error) {
        print("ViewController:: TxClientDelegate onClientError() error: \(error)")
        let noActiveCalls = self.telnyxClient?.calls.filter { $0.value.callState.isConsideredActive }.isEmpty
        
        // Stop the connection timer if it's running
        stopConnectionTimer()
        
        if noActiveCalls != true {
            return
        }
        
        DispatchQueue.main.async {
            self.appDelegate.executeEndCallAction(uuid: UUID());
            
            if error.self is NWError {
                print("ERROR: socket connectiontion error \(error)")
                self.showAlert(message: "\(error)")
            } else if(error is TxError) {
                let txError = error as! TxError
                switch txError {
                    case .socketConnectionFailed(let reason):
                        print("Socket Connection Error: \(reason.localizedDescription ?? "Unknown reason")")
                        
                    case .clientConfigurationFailed(let reason):
                        print("Client Configuration Error: \(reason.localizedDescription ?? "Unknown reason")")
                        
                    case .callFailed(let reason):
                        print("Call Failure: \(reason.localizedDescription ?? "Unknown reason")")
                        self.showAlert(message: reason.localizedDescription ?? "")

                    case .serverError(let reason):
                        // Check if it's a signaling server error
                        if case .signalingServerError(let message, let code) = reason {
                            print("Signaling Server Error: \(message) (Code: \(code))")
                            
                            // Only disconnect on serious server errors, not call-related errors
                            let shouldDisconnect = self.shouldDisconnectOnServerError(message: message, code: code)
                            
                            if shouldDisconnect {
                                self.telnyxClient?.disconnect()
                                self.viewModel.isLoading = false
                                self.viewModel.socketState = .disconnected
                            }
                            
                            // Display a popup with the error message
                            let codeInt = Int(code) ?? 0
                            self.showErrorPopup(title: "Signaling Server Error", message: self.formatSignalingErrorMessage(causeCode: codeInt, message: message))
                        } else {
                            print("Server Error: \(reason.localizedDescription)")
                        }
                    }
                print("ERROR: client error \(error)")
            }
        }
    }
    
    func showAlert(message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            self.present(alert, animated: true)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                alert.dismiss(animated: true)
            }
        }
    }
    
    func showErrorPopup(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
    
    /// Formats a signaling server error message based on the cause code
    /// - Parameters:
    ///   - causeCode: The error code from the signaling server
    ///   - message: The error message from the signaling server
    /// - Returns: A user-friendly error message
    func formatSignalingErrorMessage(causeCode: Int, message: String) -> String {
        // Map error codes to user-friendly messages
        switch causeCode {
        case -32000:
            return "Token registration error: \(message)"
        case -32001:
            return "Credential registration error: \(message)"
        case -32002:
            return "Codec error: \(message)"
        case -32003:
            return "Gateway registration timeout: \(message)"
        case -32004:
            return "Gateway registration failed: \(message)"
        default:
            if message.contains("Call not found") {
                return "Call not found: The specified call cannot be found"
            }
            return message
        }
    }
    
    func onClientReady() {
        print("ViewController:: TxClientDelegate onClientReady()")
        
        // Stop the connection timer as the connection is now established
        stopConnectionTimer()
        
        DispatchQueue.main.async {
            self.viewModel.isLoading = false
            self.viewModel.socketState = .clientReady
        }
    }
    
    func onSessionUpdated(sessionId: String) {
        print("ViewController:: TxClientDelegate onSessionUpdated() sessionId: \(sessionId)")
        DispatchQueue.main.async {
            self.viewModel.sessionId = sessionId
        }
    }
    
    func onIncomingCall(call: Call) {
        self.incomingCall = true
        DispatchQueue.main.async {
            // 🔥 CALLKIT-ONLY: Report incoming call to CallKit for native UI
            let callId = call.callInfo?.callId ?? UUID()
            let callerName = call.callInfo?.callerName ?? "Unknown"
            
            NSLog("🔥 CALLKIT-ONLY: onIncomingCall called for callId: %@", callId.uuidString)
            NSLog("🔥 CALLKIT-ONLY: Reporting to CallKit with caller: %@", callerName)
            
            // CRITICAL: Report the call to CallKit to show native incoming call screen
            self.appDelegate.newIncomingCall(from: callerName, uuid: callId) { error in
                NSLog("🔥 iOS 18 CALLKIT: onIncomingCall CallKit reporting completed with error: %@", error?.localizedDescription ?? "none")
            }
            
            // Update backend state for call management (not UI presentation)
            self.callViewModel.callState = call.callState
            self.viewModel.callState = call.callState
            
            //Hide the keyboard
            self.view.endEditing(true)
        }
    }
    
    func onRemoteCallEnded(callId: UUID, reason: CallTerminationReason? = nil) {
        print("ViewController:: TxClientDelegate onRemoteCallEnded() callId: \(callId), reason: \(reason?.cause ?? "None")")
        
        // We no longer show a popup here as the termination reason is displayed inline in the UI
        // The call state will be updated through onCallStateUpdated with the termination reason
    }
    
    private func formatTerminationReason(reason: CallTerminationReason) -> String {
        // If we have a SIP code and reason, use that
        if let sipCode = reason.sipCode, let sipReason = reason.sipReason {
            return "\(sipReason) (SIP \(sipCode))"
        }
        
        // If we have just a SIP code
        if let sipCode = reason.sipCode {
            return "Call ended with SIP code: \(sipCode)"
        }
        
        // If we have a cause
        if let cause = reason.cause {
            switch cause {
            case "USER_BUSY":
                return "Call ended: User busy"
            case "CALL_REJECTED":
                return "Call ended: Call rejected"
            case "UNALLOCATED_NUMBER":
                return "Call ended: Invalid number"
            case "NORMAL_CLEARING":
                return "Call ended normally"
            default:
                return "Call ended: \(cause)"
            }
        }
        
        return "Call ended"
    }
    
    func onCallStateUpdated(callState: CallState, callId: UUID) {        
        DispatchQueue.main.async {
            // 🔥 CALLKIT-ONLY: CallKit handles ALL call UI, app manages backend state
            NSLog("🔥 CALLKIT-ONLY: onCallStateUpdated called for callId: %@, state: %@", callId.uuidString, String(describing: callState))
            NSLog("🔥 CALLKIT-ONLY: CallKit handles all UI presentation - app only manages backend call state")
            
            // Update backend state for call management and metrics (not UI presentation)
            self.callViewModel.callState = callState
            self.viewModel.callState = callState
            
            // Forward call state changes to HomeViewModel for PreCall Diagnosis
            self.viewModel.handleCallStateChange(callId: callId, callState: callState)

            print("CallState : \(callState)")
            switch (callState) {
                case .CONNECTING:
                    break
                case .RINGING:
                    break
                case .NEW:
                    break
                case .ACTIVE:
                    // 🔧 FIX: Update call history when call becomes active (answered)
                    CallHistoryDatabase.shared.updateCallHistoryEntry(
                        callId: callId,
                        status: .answered
                    ) { success in
                        print("📞 CALL HISTORY: Call answered status \(success ? "updated" : "failed to update")")
                    }
                    
                    if let call = self.appDelegate.currentCall {
                        call.onCallQualityChange = { qualityMetric in
                            print("metric_values: \(qualityMetric)")
                            DispatchQueue.main.async {
                                // Update metrics for backend tracking (not UI display)
                                self.callViewModel.callQualityMetrics = qualityMetric
                                // Forward metrics to HomeViewModel for PreCall Diagnosis
                                self.viewModel.handleCallQualityMetrics(qualityMetric)
                            }
                        }
                    }
                    if self.appDelegate.isCallOutGoing {
                        print("Outgoing_reported")
                        self.appDelegate.executeOutGoingCall()
                    }
                    break
                case .DONE(let reason):
                    // 🔧 FIX: Update call history when call ends with final status
                    var finalStatus: CallStatus = .answered // Default to answered for successful calls
                    if let reason = reason {
                        print("Call ended with reason: \(reason.cause ?? "Unknown"), SIP code: \(reason.sipCode ?? 0)")
                        // Determine final status based on termination reason
                        switch reason.cause {
                        case "USER_BUSY":
                            finalStatus = .failed
                        case "CALL_REJECTED":
                            finalStatus = .rejected
                        case "NO_ANSWER":
                            finalStatus = .missed
                        case "NORMAL_CLEARING":
                            finalStatus = .answered // Normal end after successful call
                        default:
                            finalStatus = .answered // Assume successful if unknown
                        }
                    }
                    
                    // Update call history with final status
                    CallHistoryDatabase.shared.updateCallHistoryEntry(
                        callId: callId,
                        status: finalStatus
                    ) { success in
                        print("📞 CALL HISTORY: Call completion status \(success ? "updated" : "failed to update") - \(finalStatus)")
                    }
                    
                    // Clear CallKit UUID when call is done
                    if let callKitUUID = self.appDelegate.callKitUUID, callKitUUID == callId {
                        NSLog("🔥 UI-ROUTING: Call done - clearing CallKit UUID")
                        self.appDelegate.callKitUUID = nil
                    }
                    // Reset incoming call flag
                    self.incomingCall = false
                    break
                case .HELD:
                    break
                case .RECONNECTING(reason: _):
                    break
                case .DROPPED(reason: _):
                    break
            }
//            self.updateButtonsState()
        }
    }
    
    /// Determine if server error should cause disconnection
    /// - Parameters:
    ///   - message: Error message
    ///   - code: Error code
    /// - Returns: true if should disconnect, false otherwise
    private func shouldDisconnectOnServerError(message: String, code: String) -> Bool {
        // Call-related errors that should NOT cause disconnection
        let callRelatedErrors = [
            "CALL DOES NOT EXIST",
            "INVALID_DESTINATION", 
            "USER_BUSY",
            "NO_ANSWER",
            "CALL_REJECTED",
            "INSUFFICIENT_FUNDS",
            "DESTINATION_OUT_OF_ORDER"
        ]
        
        // Check if this is a call-related error
        for errorPattern in callRelatedErrors {
            if message.contains(errorPattern) {
                return false // Don't disconnect for call-specific errors
            }
        }
        
        // Disconnect for serious server/connection errors
        return true
    }
    
    func executeCall(callUUID: UUID, completionHandler: @escaping (Call?) -> Void) {
        NSLog("🔴 STEP 22: VoIPDelegate.executeCall() called with UUID: %@", callUUID.uuidString)
        
        do {
            NSLog("🔴 STEP 23: Getting SIP credentials from SipCredentialsManager")
            guard let sipCred = SipCredentialsManager.shared.getSelectedCredential() else {
                NSLog("🔴 STEP 23: FAILED - No SIP credentials found")
                completionHandler(nil)
                return
            }
            
            NSLog("🔴 STEP 24: SIP credentials found - callerName: [\(sipCred.callerName ?? "nil")], callerNumber: [\(sipCred.callerNumber ?? "nil")]")
            
            NSLog("🔴 STEP 25: Creating custom headers")
            let headers =  [
                "X-test1":"ios-test1",
                "X-test2":"ios-test2"
            ]
            
            NSLog("🔴 STEP 26: Getting destination from appDelegate.pendingCallDestination")
            let destinationNumber = self.appDelegate.pendingCallDestination ?? self.callViewModel.sipAddress
            NSLog("🔴 STEP 27: Destination number: [\(destinationNumber)] (from: \(self.appDelegate.pendingCallDestination != nil ? "appDelegate" : "callViewModel"))")
            
            NSLog("🔴 STEP 28: Checking TxClient availability: \(telnyxClient != nil)")
            guard telnyxClient != nil else {
                NSLog("🔴 STEP 28: FAILED - TxClient is nil")
                completionHandler(nil)
                return
            }
            
            NSLog("🔴 STEP 29: Creating TxClient.newCall() with:")
            NSLog("🔴   - callerName: [\(sipCred.callerName ?? "")]")
            NSLog("🔴   - callerNumber: [\(sipCred.callerNumber ?? "")]") 
            NSLog("🔴   - destinationNumber: [\(destinationNumber)]")
            NSLog("🔴   - callUUID: [\(callUUID)]")
            NSLog("🔴   - customHeaders: \(headers)")
            
            let call = try telnyxClient?.newCall(callerName: sipCred.callerName ?? "",
                                                 callerNumber: sipCred.callerNumber ?? "",
                                                 destinationNumber: destinationNumber,
                                                 callId: callUUID,customHeaders: headers,debug: true)
            
            if call != nil {
                NSLog("🔴 STEP 30: TxClient.newCall() SUCCESSFUL - Call object created")
            } else {
                NSLog("🔴 STEP 30: TxClient.newCall() returned nil call object")
            }
            
            NSLog("🔴 STEP 31: Adding call to CallHistoryDatabase")
            // 🔧 FIX: Track outgoing call in call history database
            CallHistoryDatabase.shared.createCallHistoryEntry(
                callerName: sipCred.callerName ?? "",
                callId: callUUID,
                callStatus: "outgoing", // Initial status for outgoing calls
                direction: "outgoing",
                metadata: "",
                phoneNumber: destinationNumber,
                profileId: "default", // Using default profile as per UI
                timestamp: Date()
            ) { success in
                NSLog("📞 CALL HISTORY: Outgoing call \(success ? "stored" : "failed to store") - \(destinationNumber)")
            }
            
            NSLog("🔴 STEP 32: Calling completionHandler with call: \(call != nil ? "SUCCESS" : "FAILED")")
            completionHandler(call)
            NSLog("🔴 STEP 33: TxClient SDK phase completed")
            
            // Clear pending destination after use
            self.appDelegate.pendingCallDestination = nil
            
        } catch let error {
            NSLog("🔴 STEP 29: TxClient.newCall() EXCEPTION: \(error)")
            // Clear pending destination on error
            self.appDelegate.pendingCallDestination = nil
            completionHandler(nil)
        }
    }
    

    
    func onPushDisabled(success: Bool, message: String) {
        print("HomeViewController:: onPushDisabled() success: \(success), message: \(message)")
        DispatchQueue.main.async {
            // Handle push notification disable result if needed
            // Could show an alert or update UI state
        }
    }
    
    func onPushCall(call: Call) {
        let callId = call.callInfo?.callId ?? UUID()
        print("HomeViewController:: onPushCall() callId: \(callId)")
        DispatchQueue.main.async {
            // 🔥 CALLKIT-ONLY: CallKit handles ALL push call UI
            NSLog("🔥 CALLKIT-ONLY: onPushCall called for callId: %@", callId.uuidString)
            NSLog("🔥 CALLKIT-ONLY: CallKit will handle all push call presentation")
            
            // Update backend state for call management (not UI presentation)
            self.callViewModel.callState = call.callState
            self.viewModel.callState = call.callState
            
            // Hide the keyboard
            self.view.endEditing(true)
        }
    }
}
