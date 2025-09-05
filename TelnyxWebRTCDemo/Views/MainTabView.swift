import SwiftUI
import TelnyxRTC
import UIKit

// MARK: - Main Tab View
// Clean tab container using individual screen components with consistent UI
struct MainTabView: View {
    @ObservedObject var homeViewModel: HomeViewModel
    @ObservedObject var callViewModel: CallViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    
    @State private var selectedTab = 0
    
    // Callback functions for HomeViewController integration
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let onLongPressLogo: () -> Void
    let onStartCall: () -> Void
    let onEndCall: () -> Void
    let onRejectCall: () -> Void
    let onAnswerCall: () -> Void
    let onMuteUnmuteSwitch: (Bool) -> Void
    let onToggleSpeaker: () -> Void
    let onHold: (Bool) -> Void
    let onDTMF: (String) -> Void
    let onRedial: ((String) -> Void)?
    let onAddProfile: () -> Void
    let onSwitchProfile: () -> Void
    
    var body: some View {
        ZStack {
            // Consistent background across all screens
            Color.premiumColors.background
                .ignoresSafeArea()
            
            TabView(selection: $selectedTab) {
                // MARK: - Dialer Tab (Primary)
                DialerView(
                    callViewModel: callViewModel,
                    homeViewModel: homeViewModel,
                    onStartCall: {
                        NSLog("🔵 STEP 5.5: MainTabView - onStartCall triggered, invoking HomeViewController callback")
                        onStartCall()
                        NSLog("🔥 CALLKIT-ONLY: Call initiated, CallKit will handle all UI")
                    },
                    onConnect: {
                        NSLog("🔵 UI: MainTabView - onConnect triggered")
                        onConnect()
                    },
                    onDisconnect: onDisconnect
                )
                .tabItem {
                    Image(systemName: "phone.fill")
                    Text("Keypad")
                }
                .tag(0)
                
                // MARK: - Recents Tab
                RecentsView(
                    onRedial: { phoneNumber in
                        callViewModel.sipAddress = phoneNumber
                        onStartCall()
                        NSLog("🔥 CALLKIT-ONLY: Redial initiated from call history, CallKit will handle all UI")
                    }
                )
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text("Recents")
                }
                .tag(1)
                
                // MARK: - Contacts Tab
                ContactsView(
                    onCall: { phoneNumber in
                        callViewModel.sipAddress = phoneNumber
                        onStartCall()
                        NSLog("🔥 CALLKIT-ONLY: Call initiated from contacts, CallKit will handle all UI")
                    }
                )
                .tabItem {
                    Image(systemName: "person.2")
                    Text("Contacts")
                }
                .tag(2)
                
                // MARK: - Settings Tab
                SettingsView(
                    homeViewModel: homeViewModel,
                    profileViewModel: profileViewModel,
                    onConnect: onConnect,
                    onDisconnect: onDisconnect,
                    onLongPressLogo: onLongPressLogo,
                    onAddProfile: onAddProfile,
                    onSwitchProfile: onSwitchProfile
                )
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(3)
            }
            .accentColor(Color.premiumColors.primary)
            .onAppear {
                setupTabBarAppearance()
                PremiumHaptics.shared.tabSelection()
            }
            
            // WhatsApp-Style Fallback Call Interface (Overlay on all tabs)
            if homeViewModel.showFallbackCallUI, let callUUID = homeViewModel.currentCallUUID {
                let _ = NSLog("🟡 DEBUG: MainTabView showing SimpleCallView for UUID: %@", callUUID.uuidString)
                SimpleCallView(
                    callUUID: callUUID,
                    callState: homeViewModel.callState,
                    onAnswer: {
                        NSLog("🔥 FALLBACK UI: Answer call %@ - keeping UI active", callUUID.uuidString)
                        onAnswerCall()
                        // Don't dismiss UI - let it transition to active call interface
                    },
                    onDecline: {
                        NSLog("🔥 FALLBACK UI: Decline call %@", callUUID.uuidString) 
                        onEndCall()
                        homeViewModel.showFallbackCallUI = false
                        homeViewModel.currentCallUUID = nil
                    },
                    onHangUp: {
                        NSLog("🔥 FALLBACK UI: Hang up call %@", callUUID.uuidString)
                        onEndCall()
                        homeViewModel.showFallbackCallUI = false
                        homeViewModel.currentCallUUID = nil
                    },
                    onMute: { isMuted in
                        NSLog("🔥 FALLBACK UI: Mute toggle %@", isMuted ? "ON" : "OFF")
                        onMuteUnmuteSwitch(isMuted)
                    },
                    onSpeaker: {
                        NSLog("🔥 FALLBACK UI: Speaker toggle")
                        onToggleSpeaker()
                    },
                    onHold: { isHeld in
                        NSLog("🔥 FALLBACK UI: Hold toggle %@", isHeld ? "ON" : "OFF")
                        onHold(isHeld)
                    }
                )
                .zIndex(100) // Ensure it appears on top
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - Tab Bar Styling
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        // Selected tab styling
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.premiumColors.primary)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color.premiumColors.primary)
        ]
        
        // Unselected tab styling  
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.premiumColors.textSecondary)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(Color.premiumColors.textSecondary)
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

// MARK: - Preview
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView(
            homeViewModel: HomeViewModel(),
            callViewModel: CallViewModel(),
            profileViewModel: ProfileViewModel(),
            onConnect: {},
            onDisconnect: {},
            onLongPressLogo: {},
            onStartCall: {},
            onEndCall: {},
            onRejectCall: {},
            onAnswerCall: {},
            onMuteUnmuteSwitch: { _ in },
            onToggleSpeaker: {},
            onHold: { _ in },
            onDTMF: { _ in },
            onRedial: { _ in },
            onAddProfile: {},
            onSwitchProfile: {}
        )
    }
}

// MARK: - Enhanced Call View for WhatsApp-Style Experience

struct SimpleCallView: View {
    let callUUID: UUID
    let callState: CallState
    let onAnswer: () -> Void
    let onDecline: () -> Void
    let onHangUp: () -> Void
    let onMute: (Bool) -> Void
    let onSpeaker: () -> Void
    let onHold: (Bool) -> Void
    
    @State private var isMuted = false
    @State private var isHeld = false
    @State private var isSpeakerOn = false
    @State private var callTimer: Timer?
    @State private var elapsedTime = 0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    NSLog("🟡 SIMPLE CALL VIEW: Appearing for call %@ with state %@", callUUID.uuidString, String(describing: callState))
                }
            
            VStack(spacing: 30) {
                // Call Status Header
                VStack(spacing: 10) {
                    Text(callStatusText)
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Phone Number")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                    
                    if isActiveCall {
                        Text(formatElapsedTime(elapsedTime))
                            .font(.headline)
                            .foregroundColor(.green)
                            .onAppear {
                                startTimer()
                            }
                    } else {
                        Text("CallID: \(callUUID.uuidString.suffix(8))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 80)
                
                Spacer()
                
                // Call Controls
                if isActiveCall {
                    // Active Call Controls
                    VStack(spacing: 30) {
                        HStack(spacing: 60) {
                            // Mute Button
                            Button(action: {
                                NSLog("🔥 BUTTON DEBUG: Mute button pressed - current state: %@", isMuted ? "muted" : "unmuted")
                                isMuted.toggle()
                                onMute(isMuted)
                            }) {
                                VStack {
                                    Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(isMuted ? .red : .white)
                                        .frame(width: 60, height: 60)
                                        .background(isMuted ? Color.white.opacity(0.2) : Color.gray.opacity(0.3))
                                        .clipShape(Circle())
                                    Text("Mute")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            
                            // Speaker Button
                            Button(action: {
                                NSLog("🔥 BUTTON DEBUG: Speaker button pressed - current state: %@", isSpeakerOn ? "on" : "off")
                                isSpeakerOn.toggle()
                                onSpeaker()
                            }) {
                                VStack {
                                    Image(systemName: isSpeakerOn ? "speaker.wave.3.fill" : "speaker.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(isSpeakerOn ? .blue : .white)
                                        .frame(width: 60, height: 60)
                                        .background(isSpeakerOn ? Color.white.opacity(0.2) : Color.gray.opacity(0.3))
                                        .clipShape(Circle())
                                    Text("Speaker")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            
                            // Hold Button
                            Button(action: {
                                isHeld.toggle()
                                onHold(isHeld)
                            }) {
                                VStack {
                                    Image(systemName: isHeld ? "pause.fill" : "pause")
                                        .font(.system(size: 28))
                                        .foregroundColor(isHeld ? .yellow : .white)
                                        .frame(width: 60, height: 60)
                                        .background(isHeld ? Color.white.opacity(0.2) : Color.gray.opacity(0.3))
                                        .clipShape(Circle())
                                    Text("Hold")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                        
                        // Hang Up Button
                        Button(action: {
                            NSLog("🔥 BUTTON DEBUG: Hang Up button pressed")
                            onHangUp()
                        }) {
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 35))
                                .foregroundColor(.white)
                                .frame(width: 80, height: 80)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                    }
                } else {
                    // Incoming/Outgoing Call Controls
                    HStack(spacing: 80) {
                        // Decline Button
                        Button(action: {
                            NSLog("🔥 BUTTON DEBUG: Decline button pressed")
                            onDecline()
                        }) {
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 35))
                                .foregroundColor(.white)
                                .frame(width: 80, height: 80)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                        
                        // Answer Button (only show for incoming calls)
                        if isIncomingCall {
                            Button(action: onAnswer) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 35))
                                    .foregroundColor(.white)
                                    .frame(width: 80, height: 80)
                                    .background(Color.green)
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
                
                Spacer()
            }
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    // MARK: - Computed Properties
    
    private var callStatusText: String {
        switch callState {
        case .NEW, .CONNECTING:
            return "Calling..."
        case .RINGING:
            return "Ringing..."
        case .ACTIVE:
            return "Connected"
        case .HELD:
            return "On Hold"
        case .RECONNECTING:
            return "Reconnecting..."
        case .DROPPED:
            return "Call Failed"
        case .DONE:
            return "Call Ended"
        }
    }
    
    private var isIncomingCall: Bool {
        // For now, treat RINGING as incoming - this can be enhanced with more context
        return callState == .RINGING
    }
    
    private var isActiveCall: Bool {
        switch callState {
        case .ACTIVE, .HELD:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    private func startTimer() {
        callTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1
        }
    }
    
    private func stopTimer() {
        callTimer?.invalidate()
        callTimer = nil
    }
    
    private func formatElapsedTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}