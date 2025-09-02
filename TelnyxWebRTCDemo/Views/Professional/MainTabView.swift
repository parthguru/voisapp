import SwiftUI
import TelnyxRTC

struct MainTabView: View {
    @ObservedObject var homeViewModel: HomeViewModel
    @ObservedObject var callViewModel: CallViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    
    @State private var selectedTab = 0
    @State private var showingActiveCall = false
    @State private var showingIncomingCall = false
    @State private var showingSettings = false
    
    // Existing callback functions - preserved exactly as they were
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
            Color.professionalBackground.ignoresSafeArea()
            
            TabView(selection: $selectedTab) {
                // MARK: - Dialer Tab (Primary)
                ProfessionalDialerScreen(
                    callViewModel: callViewModel,
                    homeViewModel: homeViewModel,
                    onStartCall: {
                        onStartCall()
                        // Show active call screen when call starts
                        if callViewModel.callState != .NEW && callViewModel.callState != .DONE(reason: nil) {
                            showingActiveCall = true
                        }
                    },
                    onConnect: onConnect,
                    onDisconnect: onDisconnect
                )
                .tabItem {
                    Image(systemName: "phone.fill")
                    Text("Keypad")
                }
                .tag(0)
                
                // MARK: - Recents Tab  
                ProfessionalRecentsScreen(
                    onRedial: { phoneNumber in
                        callViewModel.sipAddress = phoneNumber
                        onRedial?(phoneNumber)
                        selectedTab = 0 // Switch back to dialer
                    }
                )
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text("Recents")
                }
                .tag(1)
                
                // MARK: - Contacts Tab
                ProfessionalContactsScreen(
                    onCall: { phoneNumber in
                        callViewModel.sipAddress = phoneNumber
                        onStartCall()
                        // Show active call screen when call starts
                        if callViewModel.callState != .NEW && callViewModel.callState != .DONE(reason: nil) {
                            showingActiveCall = true
                        }
                    }
                )
                .tabItem {
                    Image(systemName: "person.circle.fill")
                    Text("Contacts")
                }
                .tag(2)
                
                // MARK: - Settings Tab
                ProfessionalSettingsScreen(
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
            .accentColor(.professionalPrimary)
            .onReceive(callViewModel.$callState) { callState in
                // Handle call state changes for modal presentations
                switch callState {
                case .NEW:
                    // Incoming call
                    showingIncomingCall = true
                    showingActiveCall = false
                case .CONNECTING, .RINGING, .ACTIVE, .HELD, .RECONNECTING:
                    // Active call states
                    showingIncomingCall = false
                    showingActiveCall = true
                case .DONE, .DROPPED:
                    // Call ended
                    showingIncomingCall = false
                    showingActiveCall = false
                }
            }
        }
        // MARK: - Active Call Modal
        .fullScreenCover(isPresented: $showingActiveCall) {
            ProfessionalActiveCallScreen(
                callViewModel: callViewModel,
                onEndCall: {
                    onEndCall()
                    showingActiveCall = false
                },
                onMuteUnmuteSwitch: onMuteUnmuteSwitch,
                onToggleSpeaker: onToggleSpeaker,
                onHold: onHold,
                onDTMF: onDTMF
            )
        }
        // MARK: - Incoming Call Modal  
        .fullScreenCover(isPresented: $showingIncomingCall) {
            ProfessionalIncomingCallScreen(
                callViewModel: callViewModel,
                onAnswerCall: {
                    onAnswerCall()
                    showingIncomingCall = false
                    showingActiveCall = true
                },
                onRejectCall: {
                    onRejectCall()
                    showingIncomingCall = false
                }
            )
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