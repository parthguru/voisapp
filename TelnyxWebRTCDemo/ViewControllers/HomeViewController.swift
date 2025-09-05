import AVFoundation
import Contacts
import Reachability
import SwiftUI
import TelnyxRTC
import UIKit

class HomeViewController: UIViewController {
    private var hostingController: UIHostingController<MainTabView>?
    let sipCredentialsVC = SipCredentialsViewController()

    var viewModel = HomeViewModel()
    var profileViewModel = ProfileViewModel()
    var callViewModel = CallViewModel()

    var telnyxClient: TxClient?
    var userDefaults: UserDefaults = UserDefaults()
    var serverConfig: TxServerConfiguration?

    var incomingCall: Bool = false
    var isSpeakerActive: Bool = false
    let reachability = try! Reachability()
    
    // Property to store active fallback controller
    private var activeFallbackCallController: UIViewController?

    // Timer for connection timeout
    private var connectionTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(red: 254 / 255, green: 253 / 255, blue: 245 / 255, alpha: 1.0)

        appDelegate.voipDelegate = self
        telnyxClient = self.appDelegate.telnyxClient
        
        // Set TxClient delegate to receive connection updates (implemented in VoIP extension)
        telnyxClient?.delegate = self

        // Set the TxClient in the HomeViewModel for PreCall Diagnosis
        if let client = self.telnyxClient {
            self.viewModel.setTxClient(client)
        }


        let mainTabView = MainTabView(
            homeViewModel: viewModel,
            callViewModel: callViewModel,
            profileViewModel: profileViewModel,
            onConnect: { [weak self] in
                self?.handleConnect()
            },
            onDisconnect: { [weak self] in
                self?.handleDisconnect()
            },
            onLongPressLogo: { [weak self] in
                self?.showHiddenOptions()
            },
            onStartCall: { [weak self] in
                self?.onCallButton()
            },
            onEndCall: { [weak self] in
                self?.onEndCallButton()
            },
            onRejectCall: { [weak self] in
                self?.onRejectButton()
            },
            onAnswerCall: { [weak self] in
                self?.onAnswerButton()
            },
            onMuteUnmuteSwitch: { [weak self] mute in
                self?.onMuteUnmuteSwitch(mute: mute)
            },
            onToggleSpeaker: { [weak self] in
                self?.onToggleSpeaker()
            },
            onHold: { [weak self] hold in
                self?.onHoldUnholdSwitch(isOnHold: hold)
            },
            onDTMF: { [weak self] key in
                self?.appDelegate.currentCall?.dtmf(dtmf: key)
            },
            onRedial: { [weak self] (phoneNumber: String) in
                self?.callViewModel.sipAddress = phoneNumber
                self?.onCallButton()
            },
            onAddProfile: { [weak self] in
                self?.handleAddProfile()
            },
            onSwitchProfile: { [weak self] in
                self?.handleSwitchProfile()
            }
        )

        let hostingController = UIHostingController(rootView: mainTabView)
        self.hostingController = hostingController

        addChild(hostingController)
        view.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        hostingController.didMove(toParent: self)

        initViews()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)

        setNeedsStatusBarAppearanceUpdate()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func appWillEnterForeground() {
        print("HomeViewController:: App is about to enter the foreground")
        DispatchQueue.main.async {
            self.callViewModel.currentCall = self.appDelegate.currentCall
            self.callViewModel.isMuted = self.appDelegate.currentCall?.isMuted ?? false
            self.callViewModel.isSpeakerOn = self.telnyxClient?.isSpeakerEnabled ?? false
            self.profileViewModel.updateSelectedProfile(SipCredentialsManager.shared.getSelectedCredential())
        }
    }

    private func handleAddProfile() {
        print("Add Profile tapped")
        present(sipCredentialsVC, animated: true, completion: nil)
    }

    private func handleSwitchProfile() {
        print("Switch Profile tapped")
        present(sipCredentialsVC, animated: true, completion: nil)
    }

    func handleConnect() {
        print("Connect tapped")
        let deviceToken = userDefaults.getPushToken()
        if let selectedProfile = profileViewModel.selectedProfile {
            connectToTelnyx(sipCredential: selectedProfile, deviceToken: deviceToken)
// CallHistoryManager.shared.setCurrentProfile(selectedProfile.username)
// CallHistoryManager.shared.getCallHistory()
        }
    }

    func handleDisconnect() {
        print("Disconnect tapped")
        // Stop the connection timer if it's running
        stopConnectionTimer()

        if telnyxClient?.isConnected() ?? false {
            telnyxClient?.disconnect()
        } else {
            // If we are not connected, take the user to the connect screen
            onSocketDisconnected()
        }
    }
}

// MARK: - VIEWS

extension HomeViewController {
    func initViews() {
        sipCredentialsVC.delegate = self
        hideKeyboardWhenTappedAround()
        reachability.whenReachable = { reachability in
            if reachability.connection == .wifi {
                print("Reachable via WiFi")
            } else {
                print("Reachable via Cellular")
            }
        }

        DispatchQueue.main.async {
            let sessionId = self.telnyxClient?.getSessionId() ?? ""
            let isConnected = self.telnyxClient?.isConnected() ?? false
            self.viewModel.socketState = !sessionId.isEmpty && isConnected ? .clientReady : isConnected ? .connected : .disconnected
            self.viewModel.isLoading = false
            self.viewModel.sessionId = sessionId.isEmpty ? "-" : sessionId
            self.viewModel.callState = self.appDelegate.currentCall?.callState ?? .DONE(reason: nil)
            self.callViewModel.callState = self.appDelegate.currentCall?.callState ?? .DONE(reason: nil)
            self.callViewModel.currentCall = self.appDelegate.currentCall
            self.callViewModel.isMuted = self.appDelegate.currentCall?.isMuted ?? false
            self.callViewModel.isSpeakerOn = self.telnyxClient?.isSpeakerEnabled ?? false
        }

        initEnvironment()
        requestRequiredPermissions()
    }
    
    // MARK: - Permissions Management
    
    private func requestRequiredPermissions() {
        NSLog("🎤 PERMISSIONS: Requesting microphone and contacts permissions")
        
        // Request microphone permission
        requestMicrophonePermission()
        
        // Request contacts permission  
        requestContactsPermission()
    }
    
    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    NSLog("✅ PERMISSIONS: Microphone permission granted")
                } else {
                    NSLog("❌ PERMISSIONS: Microphone permission denied")
                    self?.showPermissionDeniedAlert(for: "microphone")
                }
            }
        }
    }
    
    private func requestContactsPermission() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { [weak self] granted, error in
            DispatchQueue.main.async {
                if granted {
                    NSLog("✅ PERMISSIONS: Contacts permission granted")
                } else {
                    NSLog("❌ PERMISSIONS: Contacts permission denied - error: %@", error?.localizedDescription ?? "unknown")
                    self?.showPermissionDeniedAlert(for: "contacts")
                }
            }
        }
    }
    
    private func showPermissionDeniedAlert(for permissionType: String) {
        let alert = UIAlertController(
            title: "Permission Required",
            message: "This app needs \(permissionType) access to work properly. Please enable it in Settings.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
}

// MARK: - SipCredentialsViewControllerDelegate

extension HomeViewController: SipCredentialsViewControllerDelegate {
    func onNewSipCredential(credential: SipCredential?) {
        let deviceToken = userDefaults.getPushToken()
        if let newProfile = credential {
            connectToTelnyx(sipCredential: newProfile, deviceToken: deviceToken)
        }
    }

    func onSipCredentialSelected(credential: SipCredential?) {
        DispatchQueue.main.async {
            self.profileViewModel.updateSelectedProfile(credential)
        }
    }
}

// MARK: - Environment selector

extension HomeViewController {
    private func showHiddenOptions() {
        let alert = UIAlertController(title: "Options", message: "", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Development Environment", style: .default, handler: { _ in
            self.serverConfig = TxServerConfiguration(environment: .development)
            self.userDefaults.saveEnvironment(.development)
            self.updateEnvironment()
        }))

        alert.addAction(UIAlertAction(title: "Production Environment", style: .default, handler: { _ in
            self.serverConfig = nil
            self.userDefaults.saveEnvironment(.production)
            self.updateEnvironment()
        }))

        alert.addAction(UIAlertAction(title: "Copy APNS token", style: .default, handler: { _ in
            // To copy the APNS push token to pasteboard
            let token = UserDefaults().getPushToken()
            UIPasteboard.general.string = token
        }))
        alert.addAction(UIAlertAction(title: "Disable Push Notifications", style: .default, handler: { _ in
            self.telnyxClient?.disablePushNotifications()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        present(alert, animated: true, completion: nil)
    }

    func updateEnvironment() {
        DispatchQueue.main.async {
            // Update selected credentials in UI after switching environment
            let credentials = SipCredentialsManager.shared.getSelectedCredential()
            self.onSipCredentialSelected(credential: credentials)

            let sdkVersion = Bundle(for: TxClient.self).infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

            let env = self.serverConfig?.environment == .development ? "Development" : "Production "
            self.viewModel.environment = "\(env) TelnyxSDK [v\(sdkVersion)] - App [v\(appVersion)]"
        }
    }

    func initEnvironment() {
        if userDefaults.getEnvironment() == .development {
            self.serverConfig = TxServerConfiguration(environment: .development,region: profileViewModel.selectedRegion)
        }
        updateEnvironment()
    }
}

// MARK: - Handle connection

extension HomeViewController {
    private func connectToTelnyx(sipCredential: SipCredential,
                                 deviceToken: String?) {
        print("🌟🌟🌟 CRITICAL: HomeViewController.connectToTelnyx() CALLED!")
        print("🌟 CONNECT PATH: sipCredential.username: '\(sipCredential.username)'")
        print("🌟 CONNECT PATH: Stack trace:")
        Thread.callStackSymbols.forEach { print("  🌟 \($0)") }
        
        guard let telnyxClient = telnyxClient else { return }

        if telnyxClient.isConnected() {
            print("🌟 CONNECT PATH: Client already connected, disconnecting first")
            telnyxClient.disconnect()
            return
        }

        do {
            print("🌟 CONNECT PATH: Setting isLoading = true")
            viewModel.isLoading = true
            // Update local credential

            let isToken = sipCredential.isToken ?? false
            let txConfig = try createTxConfig(telnyxToken: isToken ? sipCredential.username : nil, sipCredential: sipCredential, deviceToken: deviceToken)

            // Start the connection timeout timer
            startConnectionTimer()

            if let serverConfig = serverConfig {
                print("Development Server ")
                try telnyxClient.connect(txConfig: txConfig, serverConfiguration: serverConfig)
            } else {
                print("Production Server ")
                try telnyxClient.connect(txConfig: txConfig,serverConfiguration: TxServerConfiguration(region:profileViewModel.selectedRegion))
            }

            // Store user / password in user defaults
            SipCredentialsManager.shared.addOrUpdateCredential(sipCredential)
            SipCredentialsManager.shared.saveSelectedCredential(sipCredential)
            // Update UI
            onSipCredentialSelected(credential: sipCredential)

        } catch let error {
            print("ViewController:: connect Error \(error)")
            self.viewModel.isLoading = false
            stopConnectionTimer()
        }
    }

    // Start the connection timeout timer
    internal func startConnectionTimer() {
        // Invalidate any existing timer first
        stopConnectionTimer()

        // Create a new timer
        connectionTimer = Timer.scheduledTimer(
            timeInterval: viewModel.connectionTimeout,
            target: self,
            selector: #selector(connectionTimedOut),
            userInfo: nil,
            repeats: false
        )
        print("Connection timer started: \(viewModel.connectionTimeout) seconds")
    }

    // Stop the connection timeout timer
    internal func stopConnectionTimer() {
        connectionTimer?.invalidate()
        connectionTimer = nil
        print("Connection timer stopped")
    }

    // Handle connection timeout
    @objc private func connectionTimedOut() {
        print("Connection timed out after \(viewModel.connectionTimeout) seconds")

        DispatchQueue.main.async {
            // Stop the loading indicator
            self.viewModel.isLoading = false

            // Disconnect the socket
            self.telnyxClient?.disconnect()

            // Show an alert to the user
            let alert = UIAlertController(
                title: "Connection Timeout",
                message: "The connection to the server timed out. Please check your internet connection and try again.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }

    private func createTxConfig(telnyxToken: String?,
                                sipCredential: SipCredential?,
                                deviceToken: String?) throws -> TxConfig {
        var txConfig: TxConfig?

        // Set the connection configuration object.
        // We can login with a user token: https://developers.telnyx.com/docs/v2/webrtc/quickstart
        // Or we can use SIP credentials (SIP user and password)
        if let token = telnyxToken {
            txConfig = TxConfig(token: token,
                                pushDeviceToken: deviceToken,
                                ringtone: "incoming_call.mp3",
                                ringBackTone: "ringback_tone.mp3",
                                // You can choose the appropriate verbosity level of the SDK.
                                logLevel: .all,
                                reconnectClient: true,
                                // Enable webrtc stats debug
                                debug: true,
                                // Force relay candidate
                                forceRelayCandidate: false,
                                // Enable Call Quality Metrics
                                enableQualityMetrics: false)
        } else if let credential = sipCredential {
            // To obtain SIP credentials, please go to https://portal.telnyx.com
            txConfig = TxConfig(sipUser: credential.username,
                                password: credential.password,
                                pushDeviceToken: deviceToken,
                                ringtone: "incoming_call.mp3",
                                ringBackTone: "ringback_tone.mp3",
                                // You can choose the appropriate verbosity level of the SDK.
                                logLevel: .all,
                                reconnectClient: true,
                                // Enable webrtc stats debug
                                debug: true,
                                // Force relay candidate.
                                forceRelayCandidate: false,
                                // Enable Call Quality Metrics
                                enableQualityMetrics: false)
        }

        guard let config = txConfig else {
            throw NSError(domain: "ViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "No valid credentials provided."])
        }

        return config
    }
}

// MARK: - Handle incoming call

extension HomeViewController {
    func onAnswerButton() {
        guard let callID = appDelegate.currentCall?.callInfo?.callId else { return }
        appDelegate.executeAnswerCallAction(uuid: callID)
    }

    func onRejectButton() {
        guard let callID = appDelegate.currentCall?.callInfo?.callId else { return }
        appDelegate.executeEndCallAction(uuid: callID)
    }
}

// MARK: - Handle call

extension HomeViewController {
    func onCallButton() {
        NSLog("🟢 STEP 6: HomeViewController.onCallButton() called - Destination: [%@]", callViewModel.sipAddress)
        
        NSLog("🟢 STEP 7: Validating destination address - isEmpty: %@", callViewModel.sipAddress.isEmpty ? "true" : "false")
        guard !callViewModel.sipAddress.isEmpty else {
            NSLog("🟢 STEP 7: FAILED - Destination address is empty")
            return
        }
        
        NSLog("🟢 STEP 8: Creating call UUID and consulting CallInterfaceRouter")
        let uuid = UUID()
        let destination = callViewModel.sipAddress
        
        // 🔥 WHATSAPP-STYLE ROUTING DECISION 🔥
        let shouldUseCallKit = CallInterfaceRouter.shared.shouldUseCallKit(
            for: uuid, 
            origin: .outgoing, 
            destination: destination
        )
        
        if shouldUseCallKit {
            // Route through CallKit for native iOS experience
            NSLog("🟢 STEP 9A: Router decision: CallKit - Using native iOS interface")
            let handle = "Telnyx"
            NSLog("🟢 STEP 10A: Calling AppDelegate.executeStartCallAction() with UUID: %@, handle: %@, destination: %@", uuid.uuidString, handle, destination)
            appDelegate.executeStartCallAction(uuid: uuid, handle: handle, destination: destination)
            NSLog("🟢 STEP 11A: CallKit routing completed")
            
        } else {
            // Use app UI for rich features - direct TxClient call
            NSLog("🟢 STEP 9B: Router decision: App UI - Using rich in-app interface")
            startDirectAppCall(uuid: uuid, destination: destination)
            NSLog("🟢 STEP 11B: App UI routing completed")
        }
    }
    
    /// Creates a direct call using TxClient without CallKit (for unlocked device rich UI)
    private func startDirectAppCall(uuid: UUID, destination: String) {
        NSLog("🟢 DIRECT CALL STEP 1: Creating direct TxClient call - bypassing CallKit")
        
        do {
            guard let sipCred = SipCredentialsManager.shared.getSelectedCredential() else {
                NSLog("🟢 DIRECT CALL STEP 1: FAILED - No SIP credentials found")
                return
            }
            
            NSLog("🟢 DIRECT CALL STEP 2: Creating TxClient.newCall() directly")
            let headers = [
                "X-direct-call": "app-ui",
                "X-interface": "rich-features"
            ]
            
            let call = try telnyxClient?.newCall(
                callerName: sipCred.callerName ?? "",
                callerNumber: sipCred.callerNumber ?? "",
                destinationNumber: destination,
                callId: uuid,
                customHeaders: headers,
                debug: true
            )
            
            if let directCall = call {
                NSLog("🟢 DIRECT CALL STEP 3: SUCCESS - Direct call created, updating app state")
                
                // Update app state for direct call
                appDelegate.currentCall = directCall
                appDelegate.isCallOutGoing = true
                
                // Update ViewModels for rich UI
                DispatchQueue.main.async {
                    self.callViewModel.currentCall = directCall
                    self.callViewModel.callState = directCall.callState
                    self.viewModel.callState = directCall.callState
                }
                
                NSLog("🟢 DIRECT CALL STEP 4: App UI call initiated successfully")
                
                // 🔥 CRITICAL: Show WhatsApp-style in-app call UI
                NSLog("🟢 DIRECT CALL STEP 5: Activating WhatsApp-style fallback call UI")
                self.activateFallbackCallUI(callUUID: uuid, reason: .userPreference)
                
            } else {
                NSLog("🟢 DIRECT CALL STEP 3: FAILED - TxClient.newCall() returned nil")
            }
            
        } catch let error {
            NSLog("🟢 DIRECT CALL ERROR: %@", error.localizedDescription)
            
            // Fallback to CallKit on error
            NSLog("🟢 DIRECT CALL FALLBACK: Falling back to CallKit due to error")
            let handle = "Telnyx"
            appDelegate.executeStartCallAction(uuid: uuid, handle: handle, destination: destination)
        }
    }

    func onEndCallButton() {
        guard let uuid = appDelegate.currentCall?.callInfo?.callId else { return }
        appDelegate.executeEndCallAction(uuid: uuid)
    }

    func onMuteUnmuteSwitch(mute: Bool) {
        guard let callId = appDelegate.currentCall?.callInfo?.callId else {
            return
        }
        appDelegate.executeMuteUnmuteAction(uuid: callId, mute: mute)
    }

    func onToggleSpeaker() {
        if let isSpeakerEnabled = telnyxClient?.isSpeakerEnabled {
            if isSpeakerEnabled {
                telnyxClient?.setEarpiece()
            } else {
                telnyxClient?.setSpeaker()
            }

            DispatchQueue.main.async {
                self.callViewModel.isSpeakerOn = self.telnyxClient?.isSpeakerEnabled ?? false
            }
        }
    }

    func onHoldUnholdSwitch(isOnHold: Bool) {
        if isOnHold {
            appDelegate.currentCall?.hold()
        } else {
            appDelegate.currentCall?.unhold()
        }
    }
    
    // MARK: - Call Transition Handling
    
    /// Shows transition indicator for switching from CallKit to app UI
    /// - Parameter callId: UUID of the active call
    func showCallTransitionToAppUI(for callId: UUID) {
        NSLog("🔥 TRANSITION UI: HomeViewController showing transition indicator for call %@", callId.uuidString)
        
        DispatchQueue.main.async {
            // Update UI to show that app can provide rich features
            // This could be a banner, status indicator, or other UI element
            
            // For now, just ensure the call state is properly displayed
            if let currentCall = self.appDelegate.currentCall,
               currentCall.callInfo?.callId == callId {
                
                self.callViewModel.currentCall = currentCall
                self.callViewModel.callState = currentCall.callState
                self.viewModel.callState = currentCall.callState
                
                NSLog("🔥 TRANSITION UI: Updated call state in ViewModels for rich UI display")
                
                // You could add a visual indicator here like:
                // - A green status bar (similar to WhatsApp)
                // - A "Tap for advanced features" banner
                // - An overlay with call quality metrics
                
            } else {
                NSLog("🔥 TRANSITION UI: Warning - no matching current call found for transition")
            }
        }
    }
    
    // MARK: - Phase 6 CallKit Enhancement Integration Methods
    
    /// Handle CallKit state changes from Phase 6 bridge
    func handleCallKitStateChange(callUUID: UUID, state: String) {
        NSLog("🔥 PHASE 6: HomeViewController received CallKit state change for %@ to %@", callUUID.uuidString, state)
        // Implement state handling logic here
        DispatchQueue.main.async { [weak self] in
            // Update UI based on CallKit state change
            // This could update call status indicators, button states, etc.
        }
    }
    
    /// Prepare for transition from CallKit to App UI
    func prepareForCallKitToAppTransition(callUUID: UUID) {
        NSLog("🔥 PHASE 6: HomeViewController preparing for CallKit to App transition for %@", callUUID.uuidString)
        DispatchQueue.main.async { [weak self] in
            // Prepare app UI to receive call control from CallKit
            // This could involve setting up the call interface, updating state, etc.
        }
    }
    
    /// Activate fallback call UI when CallKit fails
    func activateFallbackCallUI(callUUID: UUID, reason: FallbackActivationReason) {
        NSLog("🟡 DEBUG: *** activateFallbackCallUI CALLED *** UUID: %@, Reason: %@", callUUID.uuidString, reason.rawValue)
        NSLog("🔥 PHASE 6: HomeViewController activating fallback UI for %@ - reason: %@", callUUID.uuidString, reason.rawValue)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { 
                NSLog("🔥 DEBUG: activateFallbackCallUI - self is nil")
                return 
            }
            
            NSLog("🔥 PHASE 6: Creating FallbackCallView for UUID %@", callUUID.uuidString)
            NSLog("🔥 DEBUG: About to set showFallbackCallUI = true")
            
            // Update the HomeViewModel to show the fallback UI
            self.viewModel.showFallbackCallUI = true
            NSLog("🔥 DEBUG: About to set currentCallUUID = %@", callUUID.uuidString)
            self.viewModel.currentCallUUID = callUUID
            NSLog("🔥 DEBUG: Set currentCallUUID = %@", callUUID.uuidString)
            
            NSLog("✅ PHASE 6: Fallback call interface activated - HomeView will show FallbackCallView")
        }
    }
    
    /// Dismiss the fallback call UI
    private func dismissFallbackCallUI() {
        NSLog("🔥 PHASE 6: Dismissing FallbackCallView")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update the HomeViewModel to hide the fallback UI
            self.viewModel.showFallbackCallUI = false
            self.viewModel.currentCallUUID = nil
            
            NSLog("✅ PHASE 6: FallbackCallView dismissed")
        }
    }
    
    /// Handle audio route changes from Phase 6 bridge
    func handleAudioRouteChange(callUUID: UUID, route: AVAudioSessionRouteDescription) {
        NSLog("🔥 PHASE 6: HomeViewController handling audio route change for %@ to %@", callUUID.uuidString, route.description)
        DispatchQueue.main.async { [weak self] in
            // Update UI to reflect audio route change
            // This could update speaker/headphone indicators, call controls, etc.
        }
    }
}

