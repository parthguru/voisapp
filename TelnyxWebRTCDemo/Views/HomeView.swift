import SwiftUI
import TelnyxRTC
import CoreData
import Contacts
import Foundation
import UIKit

// MARK: - Professional Color System
struct ProfessionalColors {
    static let professionalPrimary = Color(hex: "#1A365D")        // Navy blue - headers, primary actions
    static let professionalSuccess = Color(hex: "#00C853")        // Green - call/answer buttons
    static let professionalAlert = Color(hex: "#D32F2F")          // Red - end call, critical actions
    static let professionalWarning = Color(hex: "#FF8F00")        // Amber - hold, secondary alerts
    static let professionalBackground = Color(hex: "#FAFAFA")     // Clean light background
    static let professionalSurface = Color(hex: "#FFFFFF")       // Card/surface backgrounds
    static let textPrimary = Color(hex: "#1D1D1D")               // Main text, high contrast
    static let textSecondary = Color(hex: "#616161")             // Supporting text
    static let professionalBorder = Color(hex: "#E0E0E0")        // Subtle dividers
    static let cardBackground = Color.white
    static let keypadButton = Color(hex: "#F8F9FA")              // Light keypad button background
}

// Legacy support for existing code
extension Color {
    static let professionalPrimary = ProfessionalColors.professionalPrimary
    static let professionalSuccess = ProfessionalColors.professionalSuccess
    static let professionalAlert = ProfessionalColors.professionalAlert
    static let professionalWarning = ProfessionalColors.professionalWarning
    static let professionalBackground = ProfessionalColors.professionalBackground
    static let professionalSurface = ProfessionalColors.professionalSurface
    static let professionalTextPrimary = ProfessionalColors.textPrimary
    static let professionalTextSecondary = ProfessionalColors.textSecondary
    static let professionalBorder = ProfessionalColors.professionalBorder
    static let professionalButtonBackground = ProfessionalColors.professionalSurface.opacity(0.9)
    static let professionalButtonShadow = Color.black.opacity(0.08)
}

// MARK: - Professional Card Style
struct ProfessionalCardStyle: ViewModifier {
    let padding: CGFloat
    
    init(padding: CGFloat = 16) {
        self.padding = padding
    }
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.professionalSurface)
                    .shadow(
                        color: .professionalButtonShadow,
                        radius: 4,
                        x: 0,
                        y: 2
                    )
            )
    }
}

extension View {
    func professionalCardStyle(padding: CGFloat = 16) -> some View {
        modifier(ProfessionalCardStyle(padding: padding))
    }
}

enum SocketState {
    case clientReady
    case connected
    case disconnected
}

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    
    @State private var isAnimating: Bool = false
    @State private var textOpacity: Double = 0.0
    @State private var keyboardHeight: CGFloat = 0
    @State private var scrollToKeyboard: Bool = false
    @State private var showPreCallDiagnosisSheet = false
    @State private var showMenu = false
    
    @State private var showRegionMenu = false
    
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let onLongPressLogo: () -> Void
    
    let profileView: AnyView
    let callView: AnyView
    
    var body: some View {
        ScrollViewReader { proxy in
            
            ZStack {
                VStack {
                    // Top Menu Bar
                  
                    GeometryReader { geometry in
                        let safeHeight = max(geometry.size.height / 2 - 100, 0)
                        
                        ScrollView {
                            VStack {
                                Spacer().frame(height: isAnimating ? 50 : safeHeight)
                                
                                HStack {
                                    Spacer()
                                    
                                    Button(action: {
                                        showMenu.toggle()
                                    }) {
                                        Image(systemName: "ellipsis")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(Color(hex: "#1D1D1D"))
                                            .frame(width: 44, height: 44)
                                            .background(Color.white.opacity(0.8))
                                            .clipShape(Circle())
                                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                    }
                                    .padding(.trailing, 20)
                                    .padding(.top, 10)
                                }
                                .zIndex(1)
                                
                                Image("telnyx-logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 200)
                                    .onLongPressGesture {
                                        onLongPressLogo()
                                    }
                                    .accessibilityIdentifier(AccessibilityIdentifiers.homeViewLogo)
                                
                                
                                if isAnimating {
                                    VStack {
                                        if viewModel.socketState == .connected || viewModel.socketState == .clientReady {
                                            Text("Enter a destination (phone number or SIP user) to initiate your call.")
                                                .font(.system(size: 18, weight: .regular))
                                                .foregroundColor(Color(hex: "1D1D1D"))
                                                .padding(20)
                                        } else {
                                            Text("Please confirm details below and click ‘Connect’ to make a call.")
                                                .font(.system(size: 18, weight: .regular))
                                                .foregroundColor(Color(hex: "1D1D1D"))
                                                .padding(20)
                                        }
                                        statesView()
                                        
                                        // Profile or Call view
                                        profileOrCallView(for: viewModel.socketState)
                                            .padding(.bottom, 16)
                                            .id("keyboard")
                                        
                                        Spacer()
                                    }
                                    .opacity(textOpacity)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, keyboardHeight)
                            .animation(.easeOut(duration: 0.3), value: keyboardHeight)
                            .onChange(of: scrollToKeyboard) { shouldScroll in
                                if shouldScroll {
                                    withAnimation {
                                        proxy.scrollTo("keyboard", anchor: .bottom)
                                    }
                                }
                            }
                            .onAppear {
                                withAnimation(nil) {
                                    isAnimating = true
                                }
                                withAnimation(nil) {
                                    textOpacity = 1.0
                                }
                                setupKeyboardObservers()
                                // Refresh profile and region when view appears
                                profileViewModel.refreshProfile()
                            }
                            .onDisappear {
                                removeKeyboardObservers()
                            }
                        }
                    }
                    if viewModel.callState == .NEW || .DONE(reason: nil) == viewModel.callState {
                        if viewModel.socketState == .disconnected {
                            Button(action: onConnect) {
                                Text("Connect")
                                    .font(.system(size: 16).bold())
                                    .foregroundColor(.white)
                                    .frame(maxWidth: 300)
                                    .padding(.vertical, 12)
                                    .background(Color(hex: "#1D1D1D"))
                                    .cornerRadius(20)
                            }
                            .accessibilityIdentifier(AccessibilityIdentifiers.connectButton)
                            .padding(.horizontal, 60)
                            .padding(.bottom, 20)
                        } else {
                            Button(action: onDisconnect) {
                                Text("Disconnect")
                                    .font(.system(size: 16).bold())
                                    .foregroundColor(.white)
                                    .frame(maxWidth: 300, minHeight: 16)
                                    .padding(.vertical, 12)
                                    .background(Color(hex: "#1D1D1D"))
                                    .cornerRadius(100)
                            }
                            .accessibilityIdentifier(AccessibilityIdentifiers.disconnectButton)
                            .padding(.horizontal, 60)
                            .padding(.bottom, 10)
                        }
                        
                        // Environment Text
                        Text(viewModel.environment)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color(hex: "#525252"))
                            .padding(.bottom, 30)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                if viewModel.isLoading {
                    Color.black.opacity(0.5)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#00E3AA")))
                            .scaleEffect(1.5)
                    }
                }
                
                // Menu Overlay
                OverflowMenuView(
                              showMenu: $showMenu,
                              showPreCallDiagnosisSheet: $showPreCallDiagnosisSheet,
                              showRegionMenu: $showRegionMenu,
                              selectedRegion: $profileViewModel.selectedRegion,
                              viewModel: viewModel
                          )
                
                RegionMenuView(
                      showRegionMenu: $showRegionMenu,
                      profileViewModel: profileViewModel,
                      isRegionSelectionDisabled: viewModel.isRegionSelectionDisabled
                  )
            }
            .background(Color(hex: "#FEFDF5")).ignoresSafeArea()
            .sheet(isPresented: $showPreCallDiagnosisSheet) {
                PreCallDiagnosisBottomSheet(
                    isPresented: $showPreCallDiagnosisSheet,
                    viewModel: viewModel
                )
            }
        }
    }
    
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
                withAnimation {
                    scrollToKeyboard = true
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            keyboardHeight = 0
            withAnimation {
                scrollToKeyboard = false
            }
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @ViewBuilder
    private func statesView() -> some View {
        VStack {
            Text("Socket")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(Color(hex: "#525252"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
            
            HStack {
                Circle()
                    .fill(viewModel.socketState == .connected || viewModel.socketState == .clientReady ? Color(hex: "00E3AA") : Color(hex: "D40000"))
                    .frame(width: 8, height: 8)
                Text(socketStateText(for: viewModel.socketState))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color(hex: "1D1D1D"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 5)
            
            // Call State
            if viewModel.socketState == .connected || viewModel.socketState == .clientReady {
                let stateInfo = callStateInfo(for: viewModel.callState)
                Text("Call State")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color(hex: "1D1D1D"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
                
                HStack(spacing: 8) {
                    
                    Circle()
                        .fill(stateInfo.color)
                        .frame(width: 8, height: 8)
                    
                    Text(stateInfo.text)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color(hex: "1D1D1D"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
            }
            
            // Session
            VStack {
                Text("Session ID")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(Color(hex: "#525252"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
                
                Text(viewModel.sessionId)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color(hex: "1D1D1D"))
                    .padding(.top, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 16)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
        .padding(.horizontal, 30)
    }
    
    
    @ViewBuilder
    private func profileOrCallView(for state: SocketState) -> some View {
        switch state {
            case .disconnected:
                profileView
            case .connected, .clientReady:
                callView
        }
    }
    
    private func socketStateText(for state: SocketState) -> String {
        switch state {
            case .disconnected:
                return "Disconnected"
            case .connected:
                return "Connected"
            case .clientReady:
                return "Client-ready"
        }
    }
    
    private func callStateInfo(for state: CallState) -> (color: Color, text: String) {
        switch state {
        case .DONE(let reason):
            if let reason = reason, let cause = reason.cause {
                return (Color.gray, "DONE - \(cause)")
            }
            return (Color.gray, "DONE")
        case .RINGING:
            return (Color(hex: "#3434EF"), "Ringing")
        case .CONNECTING:
            return (Color(hex: "#008563"), "Connecting")
        case .DROPPED(let reason):
            return (Color(hex: "#D40000"), "Dropped - \(reason.rawValue)")
        case .RECONNECTING(let reason):
            return (Color(hex: "#CF7E20"), "Reconnecting - \(reason.rawValue)")
        case .ACTIVE:
            return (Color(hex: "#008563"), "Active")
        case .NEW:
            return (Color.black, "New")
        case .HELD:
            return (Color(hex: "#008563"), "Held")
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(
            viewModel: HomeViewModel(),
            profileViewModel: ProfileViewModel(),
            onConnect: {},
            onDisconnect: {},
            onLongPressLogo: {},
            profileView: AnyView(
                ProfileView(
                    viewModel: ProfileViewModel(),
                    onAddProfile: {},
                    onSwitchProfile: {})),
            callView: AnyView(
                CallView(
                    viewModel: CallViewModel(), isPhoneNumber: false,
                    onStartCall: {},
                    onEndCall: {},
                    onRejectCall: {},
                    onAnswerCall: {},
                    onMuteUnmuteSwitch: { _ in },
                    onToggleSpeaker: {},
                    onHold: { _ in },
                    onDTMF: { _ in },
                    onRedial: { _ in }
                )
            )
        )
    }
}

// MARK: - Professional Interface Views
// Temporarily added here for compilation - will be moved to separate files later

struct MainTabView: View {
    @ObservedObject var homeViewModel: HomeViewModel
    @ObservedObject var callViewModel: CallViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    
    @State private var selectedTab = 0
    @State private var showingActiveCall = false
    @State private var showingIncomingCall = false
    
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
                        selectedTab = 0
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
                switch callState {
                case .NEW:
                    showingIncomingCall = true
                    showingActiveCall = false
                case .CONNECTING, .RINGING, .ACTIVE, .HELD, .RECONNECTING:
                    showingIncomingCall = false
                    showingActiveCall = true
                case .DONE, .DROPPED:
                    showingIncomingCall = false
                    showingActiveCall = false
                }
            }
        }
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

// MARK: - Professional Dialer Screen
struct ProfessionalDialerScreen: View {
    @ObservedObject var callViewModel: CallViewModel
    @ObservedObject var homeViewModel: HomeViewModel
    
    let onStartCall: () -> Void
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    
    private let keypadButtons = [
        ["1", "2", "3"],
        ["4", "5", "6"], 
        ["7", "8", "9"],
        ["*", "0", "#"]
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with connection status
            HStack {
                Circle()
                    .fill(homeViewModel.socketState == .clientReady ? ProfessionalColors.professionalSuccess : ProfessionalColors.professionalAlert)
                    .frame(width: 8, height: 8)
                
                Text(homeViewModel.socketState == .clientReady ? "Connected" : "Disconnected")
                    .font(.caption)
                    .foregroundColor(ProfessionalColors.textSecondary)
                
                Spacer()
                
                if homeViewModel.socketState == .disconnected {
                    Button("Connect") {
                        onConnect()
                    }
                    .font(.caption)
                    .foregroundColor(ProfessionalColors.professionalPrimary)
                } else {
                    Button("Disconnect") {
                        onDisconnect()
                    }
                    .font(.caption)
                    .foregroundColor(ProfessionalColors.professionalAlert)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            Spacer()
            
            // Number display
            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    Text(callViewModel.sipAddress.isEmpty ? "Enter number" : callViewModel.sipAddress)
                        .font(.system(size: 32, weight: .light, design: .default))
                        .foregroundColor(callViewModel.sipAddress.isEmpty ? ProfessionalColors.textSecondary : ProfessionalColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    if !callViewModel.sipAddress.isEmpty {
                        Button(action: {
                            if !callViewModel.sipAddress.isEmpty {
                                callViewModel.sipAddress.removeLast()
                            }
                        }) {
                            Image(systemName: "delete.left")
                                .font(.title2)
                                .foregroundColor(ProfessionalColors.textSecondary)
                        }
                        .padding(.leading, 8)
                    }
                }
                .padding(.horizontal)
                
                Rectangle()
                    .fill(ProfessionalColors.textSecondary.opacity(0.3))
                    .frame(height: 1)
                    .padding(.horizontal)
            }
            .padding(.vertical, 20)
            
            // Keypad
            VStack(spacing: 15) {
                ForEach(0..<keypadButtons.count, id: \.self) { row in
                    HStack(spacing: 25) {
                        ForEach(0..<keypadButtons[row].count, id: \.self) { col in
                            KeypadButton(
                                number: keypadButtons[row][col],
                                onTap: {
                                    callViewModel.sipAddress += keypadButtons[row][col]
                                },
                                onLongPress: keypadButtons[row][col] == "0" ? {
                                    // Long press on 0 adds + for international dialing
                                    callViewModel.sipAddress += "+"
                                } : nil
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Call button
            Button(action: {
                if !callViewModel.sipAddress.isEmpty && (homeViewModel.socketState == .connected || homeViewModel.socketState == .clientReady) {
                    onStartCall()
                }
            }) {
                HStack {
                    Image(systemName: "phone.fill")
                        .font(.title2)
                    Text("Call")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(callViewModel.sipAddress.isEmpty ? ProfessionalColors.textSecondary : ProfessionalColors.professionalSuccess)
                )
            }
            .disabled(callViewModel.sipAddress.isEmpty || !(homeViewModel.socketState == .connected || homeViewModel.socketState == .clientReady))
            .opacity((callViewModel.sipAddress.isEmpty || !(homeViewModel.socketState == .connected || homeViewModel.socketState == .clientReady)) ? 0.6 : 1.0)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .background(ProfessionalColors.professionalBackground.ignoresSafeArea())
        .onAppear {
            if homeViewModel.socketState == .disconnected {
                onConnect()
            }
        }
    }
}

// MARK: - Keypad Button Component
struct KeypadButton: View {
    let number: String
    let onTap: () -> Void
    let onLongPress: (() -> Void)?
    
    private let letters: [String: String] = [
        "2": "ABC", "3": "DEF", "4": "GHI", "5": "JKL",
        "6": "MNO", "7": "PQRS", "8": "TUV", "9": "WXYZ",
        "0": "+"  // Add + symbol for 0 button
    ]
    
    @State private var isPressed = false
    @State private var isLongPressed = false
    
    init(number: String, onTap: @escaping () -> Void, onLongPress: (() -> Void)? = nil) {
        self.number = number
        self.onTap = onTap
        self.onLongPress = onLongPress
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text(number)
                .font(.system(size: 28, weight: .regular, design: .default))
                .foregroundColor(ProfessionalColors.textPrimary)
            
            if let letterText = letters[number] {
                Text(letterText)
                    .font(.caption2)
                    .foregroundColor(ProfessionalColors.textSecondary)
                    .fontWeight(.medium)
            }
        }
        .frame(width: 75, height: 75)
        .background(
            Circle()
                .fill(isPressed ? ProfessionalColors.professionalPrimary.opacity(0.1) : ProfessionalColors.keypadButton)
                // Enhanced shadow for better visibility
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            onTap()
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
        .onLongPressGesture(
            minimumDuration: 0.8, 
            maximumDistance: .infinity,
            pressing: { pressing in
                isPressed = pressing
                if pressing {
                    // Stronger haptic for long press indication
                    let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                    impactFeedback.impactOccurred()
                }
            },
            perform: {
                if let onLongPress = onLongPress {
                    onLongPress()
                    // Success haptic for + symbol
                    let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                    impactFeedback.impactOccurred()
                }
            }
        )
    }
}

// MARK: - Professional Call Interface
struct ProfessionalActiveCallScreen: View {
    @ObservedObject var callViewModel: CallViewModel
    let onEndCall: () -> Void
    let onMuteUnmuteSwitch: (Bool) -> Void
    let onToggleSpeaker: () -> Void
    let onHold: (Bool) -> Void
    let onDTMF: (String) -> Void
    
    @State private var callDuration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var callStartTime = Date()
    @State private var showingKeypad = false
    @State private var callQuality: CallQualityIndicator = .excellent
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Professional gradient background
                LinearGradient(
                    colors: [
                        Color(hex: "#F8F9FA"),
                        Color(hex: "#FFFFFF")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Status and Call Quality Section
                    VStack(spacing: 8) {
                        HStack {
                            // Call status
                            Text(callStatusText)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(ProfessionalColors.textSecondary)
                            
                            Spacer()
                            
                            // Call quality indicator
                            CallQualityIndicatorView(quality: callQuality)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 60)
                        
                        // Call duration
                        Text(formatCallDuration(callDuration))
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(ProfessionalColors.professionalPrimary)
                            .padding(.top, 4)
                    }
                    
                    Spacer()
                    
                    // Contact Information Section
                    VStack(spacing: 16) {
                        // Contact Avatar
                        ContactAvatarLarge(
                            name: extractDisplayName(from: callViewModel.sipAddress),
                            phoneNumber: callViewModel.sipAddress
                        )
                        
                        // Contact Name
                        Text(extractDisplayName(from: callViewModel.sipAddress))
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(ProfessionalColors.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        // Phone Number
                        Text(extractPhoneNumber(from: callViewModel.sipAddress))
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(ProfessionalColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                    
                    // Call Controls Section
                    VStack(spacing: 32) {
                        // First row of controls
                        HStack(spacing: 60) {
                            CallControlButton(
                                icon: showingKeypad ? "keyboard.fill" : "keyboard",
                                title: "Keypad",
                                isActive: showingKeypad,
                                action: { showingKeypad.toggle() }
                            )
                            
                            CallControlButton(
                                icon: callViewModel.isMuted ? "mic.slash.fill" : "mic.fill",
                                title: "Mute",
                                isActive: callViewModel.isMuted,
                                action: {
                                    callViewModel.isMuted.toggle()
                                    onMuteUnmuteSwitch(callViewModel.isMuted)
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                }
                            )
                            
                            CallControlButton(
                                icon: callViewModel.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.fill",
                                title: "Speaker",
                                isActive: callViewModel.isSpeakerOn,
                                action: {
                                    callViewModel.isSpeakerOn.toggle()
                                    onToggleSpeaker()
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                }
                            )
                        }
                        
                        // Second row of controls
                        HStack(spacing: 60) {
                            CallControlButton(
                                icon: "plus",
                                title: "Add Call",
                                isActive: false,
                                action: {
                                    // Add call functionality
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                }
                            )
                            
                            CallControlButton(
                                icon: "person.fill",
                                title: "Contacts",
                                isActive: false,
                                action: {
                                    // Contacts functionality
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                }
                            )
                            
                            CallControlButton(
                                icon: "ellipsis",
                                title: "More",
                                isActive: false,
                                action: {
                                    // More options
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                }
                            )
                        }
                        
                        // End Call Button
                        Button(action: {
                            onEndCall()
                            let impact = UIImpactFeedbackGenerator(style: .heavy)
                            impact.impactOccurred()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#FF3B30"))
                                    .frame(width: 80, height: 80)
                                    .shadow(color: Color(hex: "#FF3B30").opacity(0.3), radius: 8, x: 0, y: 4)
                                
                                Image(systemName: "phone.down.fill")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 0.15), value: true)
                    }
                    .padding(.bottom, 80)
                }
            }
        }
        .onAppear {
            startCallTimer()
            // Simulate call quality updates
            simulateCallQuality()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .sheet(isPresented: $showingKeypad) {
            ProfessionalCallKeypadSheet(onDTMF: onDTMF)
        }
    }
    
    // MARK: - Helper Properties and Functions
    
    private var callStatusText: String {
        switch callViewModel.callState {
        case .CONNECTING:
            return "Connecting..."
        case .RINGING:
            return "Ringing..."
        case .ACTIVE:
            return "Connected"
        case .HELD:
            return "On Hold"
        case .RECONNECTING:
            return "Reconnecting..."
        default:
            return "Active"
        }
    }
    
    private func startCallTimer() {
        callStartTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            callDuration = Date().timeIntervalSince(callStartTime)
        }
    }
    
    private func formatCallDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func extractDisplayName(from sipAddress: String) -> String {
        // Extract display name from SIP address or use phone number
        let components = sipAddress.components(separatedBy: "@")
        let userPart = components.first ?? sipAddress
        
        // Remove sip: prefix if present
        let cleanUser = userPart.replacingOccurrences(of: "sip:", with: "")
        
        // If it looks like a phone number, try to format it nicely
        if cleanUser.allSatisfy({ $0.isNumber || $0 == "+" }) {
            return formatPhoneNumber(cleanUser)
        }
        
        return cleanUser.isEmpty ? "Unknown" : cleanUser
    }
    
    private func extractPhoneNumber(from sipAddress: String) -> String {
        return sipAddress
    }
    
    private func formatPhoneNumber(_ number: String) -> String {
        // Basic phone number formatting
        let digits = number.filter { $0.isNumber }
        if digits.count == 10 {
            return "(\(digits.prefix(3))) \(digits.dropFirst(3).prefix(3))-\(digits.suffix(4))"
        }
        return number
    }
    
    private func simulateCallQuality() {
        // Simulate real-time call quality updates
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            let qualities: [CallQualityIndicator] = [.excellent, .good, .fair, .poor]
            callQuality = qualities.randomElement() ?? .excellent
        }
    }
}

// MARK: - Supporting Components

enum CallQualityIndicator: CaseIterable {
    case excellent, good, fair, poor
    
    var color: Color {
        switch self {
        case .excellent: return Color(hex: "#00C853")
        case .good: return Color(hex: "#64DD17") 
        case .fair: return Color(hex: "#FF8F00")
        case .poor: return Color(hex: "#D32F2F")
        }
    }
    
    var text: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        }
    }
    
    var barCount: Int {
        switch self {
        case .excellent: return 4
        case .good: return 3
        case .fair: return 2
        case .poor: return 1
        }
    }
}

struct CallQualityIndicatorView: View {
    let quality: CallQualityIndicator
    
    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                ForEach(0..<4) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(index < quality.barCount ? quality.color : Color.gray.opacity(0.3))
                        .frame(width: 3, height: CGFloat(6 + index * 2))
                        .animation(.easeInOut(duration: 0.3), value: quality)
                }
            }
            
            Text(quality.text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(quality.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(quality.color.opacity(0.1))
        )
    }
}

struct ContactAvatarLarge: View {
    let name: String
    let phoneNumber: String
    
    private var initials: String {
        let components = name.components(separatedBy: " ")
        let firstInitial = components.first?.prefix(1) ?? ""
        let lastInitial = components.count > 1 ? components.last?.prefix(1) ?? "" : ""
        return (firstInitial + lastInitial).uppercased()
    }
    
    private var avatarColor: Color {
        let colors = [
            Color(hex: "#64B5F6"), // Blue
            Color(hex: "#81C784"), // Green
            Color(hex: "#FFB74D"), // Orange
            Color(hex: "#F06292"), // Pink
            Color(hex: "#9575CD"), // Purple
            Color(hex: "#4DB6AC"), // Teal
        ]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(avatarColor)
                .frame(width: 160, height: 160)
                .shadow(color: avatarColor.opacity(0.3), radius: 20, x: 0, y: 8)
            
            Text(initials)
                .font(.system(size: 56, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

struct CallControlButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(isActive ? ProfessionalColors.professionalPrimary : Color(hex: "#F1F3F4"))
                        .frame(width: 64, height: 64)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isActive ? .white : ProfessionalColors.textSecondary)
                }
            }
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isActive ? ProfessionalColors.professionalPrimary : ProfessionalColors.textSecondary)
        }
    }
}

struct ProfessionalCallKeypadSheet: View {
    let onDTMF: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .cornerRadius(2)
                .padding(.top, 8)
            
            Text("Keypad")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ProfessionalColors.textPrimary)
                .padding(.vertical, 20)
            
            // Keypad Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 3), spacing: 16) {
                ForEach(keypadButtons, id: \.self) { button in
                    DTMFKeyButton(
                        number: button.number,
                        letters: button.letters,
                        onTap: { onDTMF(button.number) }
                    )
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .background(Color.white)
    }
    
    private let keypadButtons = [
        KeypadButton(number: "1", letters: ""),
        KeypadButton(number: "2", letters: "ABC"),
        KeypadButton(number: "3", letters: "DEF"),
        KeypadButton(number: "4", letters: "GHI"),
        KeypadButton(number: "5", letters: "JKL"),
        KeypadButton(number: "6", letters: "MNO"),
        KeypadButton(number: "7", letters: "PQRS"),
        KeypadButton(number: "8", letters: "TUV"),
        KeypadButton(number: "9", letters: "WXYZ"),
        KeypadButton(number: "*", letters: ""),
        KeypadButton(number: "0", letters: ""),
        KeypadButton(number: "#", letters: ""),
    ]
    
    private struct KeypadButton: Hashable {
        let number: String
        let letters: String
    }
}

struct DTMFKeyButton: View {
    let number: String
    let letters: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            onTap()
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }) {
            VStack(spacing: 2) {
                Text(number)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundColor(ProfessionalColors.textPrimary)
                
                if !letters.isEmpty {
                    Text(letters)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ProfessionalColors.textSecondary)
                }
            }
        }
        .frame(width: 80, height: 80)
        .background(
            Circle()
                .fill(Color(hex: "#F8F9FA"))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

struct ProfessionalIncomingCallScreen: View {
    @ObservedObject var callViewModel: CallViewModel
    let onAnswerCall: () -> Void
    let onRejectCall: () -> Void
    
    var body: some View {
        VStack(spacing: 40) {
            Text("Incoming Call")
                .font(.title)
                .foregroundColor(.professionalTextPrimary)
            
            Text(callViewModel.sipAddress)
                .font(.title2)
                .foregroundColor(.professionalTextSecondary)
            
            HStack(spacing: 60) {
                Button("Decline") {
                    onRejectCall()
                }
                .buttonStyle(.borderedProminent)
                .tint(.professionalAlert)
                
                Button("Answer") {
                    onAnswerCall()
                }
                .buttonStyle(.borderedProminent)
                .tint(.professionalSuccess)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.professionalBackground.ignoresSafeArea())
    }
}

// MARK: - Professional Call History Data Models
struct CallHistoryItem: Identifiable {
    let id = UUID()
    let name: String
    let phoneNumber: String
    let time: String
    let timestamp: Date
    let isIncoming: Bool
    let isMissed: Bool
    let avatar: String
    let avatarColor: Color
}

struct ProfessionalRecentsScreen: View {
    let onRedial: (String) -> Void
    @State private var searchText = ""
    @StateObject private var callHistoryDB = CallHistoryDatabase.shared
    @ObservedObject private var callHistoryManager = CallHistoryManager.shared
    @ObservedObject private var contactsManager = SimpleContactsManager.shared
    // Real call history data from database
    private var callHistory: [CallHistoryItem] {
        return callHistoryDB.callHistory.map { entry in
            let phoneNumber = entry.phoneNumber ?? "Unknown"
            // First try to get contact name, then fallback to caller name, then "Unknown"
            let name = contactsManager.getContactName(for: phoneNumber) ?? 
                      (entry.callerName?.isEmpty == false ? entry.callerName! : "Unknown")
            let isMissed = entry.callStatus == "missed" || entry.callStatus == "rejected"
            let isIncoming = entry.direction == "incoming"
            let avatar = String(name.prefix(1)).uppercased()
            let avatarColor = generateAvatarColor(for: name)
            let time = formatTime(from: entry.timestamp)
            
            return CallHistoryItem(
                name: name,
                phoneNumber: phoneNumber,
                time: time,
                timestamp: entry.timestamp ?? Date(),
                isIncoming: isIncoming,
                isMissed: isMissed,
                avatar: avatar,
                avatarColor: avatarColor
            )
        }.sorted { $0.timestamp > $1.timestamp }
    }
    
    // Helper function to generate consistent avatar colors
    private func generateAvatarColor(for name: String) -> Color {
        let colors = [
            Color(hex: "#E57373"), // Red
            Color(hex: "#64B5F6"), // Blue  
            Color(hex: "#81C784"), // Green
            Color(hex: "#FFB74D"), // Orange
            Color(hex: "#BA68C8"), // Purple
            Color(hex: "#4DB6AC"), // Teal
        ]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
    
    // Helper function to format timestamp 
    private func formatTime(from date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        
        if isToday(date: date) {
            formatter.dateFormat = "h:mm a"
        } else if isYesterday(date: date) {
            formatter.dateFormat = "h:mm a"
        } else {
            formatter.dateFormat = "MMM d"
        }
        return formatter.string(from: date)
    }
    
    // Helper function to get day title
    private func dayTitle(for date: Date) -> String {
        if isToday(date: date) {
            return "Today"
        } else if isYesterday(date: date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d"
            return formatter.string(from: date)
        }
    }
    
    // iOS 15.6 compatible date helpers
    private func isToday(date: Date) -> Bool {
        return Calendar.current.isDate(date, inSameDayAs: Date())
    }
    
    private func isYesterday(date: Date) -> Bool {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else {
            return false
        }
        return Calendar.current.isDate(date, inSameDayAs: yesterday)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Professional Search Bar
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(ProfessionalColors.textSecondary)
                        .font(.system(size: 18))
                    
                    TextField("Search Contacts & Places", text: $searchText)
                        .font(.system(size: 16))
                        .foregroundColor(ProfessionalColors.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "mic")
                        .foregroundColor(ProfessionalColors.textSecondary)
                        .font(.system(size: 18))
                    
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(ProfessionalColors.textSecondary)
                        .font(.system(size: 18))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color(hex: "#F5F5F5"))
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            
            // Call History List
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    let groupedCalls = Dictionary(grouping: callHistory) { call in
                        Calendar.current.startOfDay(for: call.timestamp)
                    }
                    let sortedDays = groupedCalls.keys.sorted(by: >)
                    
                    ForEach(sortedDays, id: \.self) { day in
                        let dayTitle = dayTitle(for: day)
                        let callsForDay = groupedCalls[day]?.sorted { $0.timestamp > $1.timestamp } ?? []
                        
                        SectionHeader(title: dayTitle)
                        
                        ForEach(callsForDay) { call in
                            ProfessionalCallHistoryRow(call: call, onRedial: onRedial)
                            if call.id != callsForDay.last?.id {
                                Divider()
                                    .padding(.leading, 72)
                            }
                        }
                        
                        if day != sortedDays.last {
                            Spacer()
                                .frame(height: 20)
                        }
                    }
                }
                .padding(.top, 16)
            }
            
            Spacer()
        }
        .background(Color.white.ignoresSafeArea())
        .onAppear {
            // Load call history when screen appears
            callHistoryDB.fetchCallHistoryFiltered(by: callHistoryManager.currentProfileId)
            
            // Populate contacts cache
            // TODO: Temporarily disabled
            // populateContactsCache()
        }
        // TODO: Temporarily disabled contacts functionality
        // .onReceive(contactsDatabase.$contacts) { _ in
        //     // Refresh contacts cache when contacts change
        //     populateContactsCache()
        // }
    }
    
    // Helper function to populate contacts cache
    // TODO: Temporarily disabled
    // private func populateContactsCache() {
    //     var cache: [String: Contact] = [:]
    //     for contact in contactsDatabase.contacts {
    //         if let phoneNumber = contact.phoneNumber {
    //             cache[phoneNumber] = contact
    //         }
    //     }
    //     contactsCache = cache
    // }
}

// MARK: - Call History Components
struct SectionHeader: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ProfessionalColors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            
            Spacer()
        }
        .background(Color.white)
    }
}

struct ProfessionalCallHistoryRow: View {
    let call: CallHistoryItem
    let onRedial: (String) -> Void
    @State private var showingActions = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Contact Avatar
            ZStack {
                Circle()
                    .fill(call.avatarColor)
                    .frame(width: 40, height: 40)
                
                Text(call.avatar)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // Contact Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(call.name)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(call.isMissed ? Color(hex: "#E57373") : ProfessionalColors.textPrimary)
                    
                    Spacer()
                    
                    Text(call.time)
                        .font(.system(size: 14))
                        .foregroundColor(ProfessionalColors.textSecondary)
                }
                
                HStack(spacing: 4) {
                    // Call direction icon
                    Image(systemName: call.isIncoming ? "arrow.down.left" : "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundColor(call.isMissed ? Color(hex: "#E57373") : ProfessionalColors.textSecondary)
                    
                    Text("Mobile")
                        .font(.system(size: 14))
                        .foregroundColor(ProfessionalColors.textSecondary)
                    
                    Spacer()
                }
                
                // Provider/Carrier info (similar to "Jazz" in reference)
                Text("Telnyx")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#1976D2"))
            }
            
            // Call button
            Button(action: {
                onRedial(call.phoneNumber)
            }) {
                Image(systemName: "phone")
                    .font(.system(size: 18))
                    .foregroundColor(ProfessionalColors.textSecondary)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            showingActions.toggle()
        }
        .sheet(isPresented: $showingActions) {
            CallActionSheet(call: call, onRedial: onRedial)
        }
    }
}

struct CallActionSheet: View {
    let call: CallHistoryItem
    let onRedial: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddContact = false
    @ObservedObject private var contactsManager = SimpleContactsManager.shared
    
    // Check if this phone number already has a contact
    private var hasExistingContact: Bool {
        let normalizedCallNumber = normalizePhoneNumber(call.phoneNumber)
        return contactsManager.contacts.contains { contact in
            normalizePhoneNumber(contact.phoneNumber) == normalizedCallNumber
        }
    }
    
    private func normalizePhoneNumber(_ phoneNumber: String) -> String {
        // Remove all non-digit characters
        let cleanNumber = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Handle USA phone numbers
        if cleanNumber.count == 11 && cleanNumber.hasPrefix("1") {
            // Remove leading 1 (e.g., 12345678900 -> 2345678900)
            return String(cleanNumber.dropFirst())
        } else if cleanNumber.count == 10 {
            // Already 10 digits, keep as is
            return cleanNumber
        } else {
            // Return as-is for other formats
            return cleanNumber
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Handle bar
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .cornerRadius(2)
                .padding(.top, 8)
            
            // Contact info
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(call.avatarColor)
                        .frame(width: 40, height: 40)
                    
                    Text(call.avatar)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading) {
                    Text(call.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ProfessionalColors.textPrimary)
                    
                    Text(call.phoneNumber)
                        .font(.system(size: 14))
                        .foregroundColor(ProfessionalColors.textSecondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            
            // Action buttons
            HStack(spacing: 16) {
                if !hasExistingContact {
                    Button(action: {
                        showingAddContact = true
                    }) {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.plus")
                            Text("Add Contact")
                        }
                        .foregroundColor(ProfessionalColors.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(ProfessionalColors.textSecondary, lineWidth: 1)
                        )
                    }
                }
                
                Button(action: {
                    onRedial(call.phoneNumber)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "phone.fill")
                        Text("Call")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(ProfessionalColors.professionalSuccess)
                    )
                }
            }
            .padding(.horizontal, 16)
            
            Spacer()
        }
        .background(Color.white)
        .sheet(isPresented: $showingAddContact) {
            ProfessionalAddContactView(
                onSave: { name, phoneNumber in
                    contactsManager.addContact(name: name, phoneNumber: phoneNumber)
                    dismiss() // Dismiss the action sheet after saving contact
                },
                onCancel: {
                    dismiss() // Dismiss the action sheet when canceling
                },
                initialPhoneNumber: call.phoneNumber
            )
        }
    }
}

struct ProfessionalSettingsScreen: View {
    @ObservedObject var homeViewModel: HomeViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let onLongPressLogo: () -> Void
    let onAddProfile: () -> Void
    let onSwitchProfile: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.title)
                .foregroundColor(.professionalTextPrimary)
                .padding()
            
            VStack(spacing: 16) {
                if homeViewModel.socketState == .disconnected {
                    Button("Connect") {
                        onConnect()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.professionalSuccess)
                } else {
                    Button("Disconnect") {
                        onDisconnect()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.professionalAlert)
                }
                
                Button("Manage Profiles") {
                    onAddProfile()
                }
                .buttonStyle(.bordered)
                
                Text("Environment: \(homeViewModel.environment)")
                    .font(.caption)
                    .foregroundColor(.professionalTextSecondary)
                    .padding()
            }
            .padding()
            
            Spacer()
        }
        .background(Color.professionalBackground.ignoresSafeArea())
    }
}

// MARK: - Contact Data Model
struct ContactItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let phoneNumber: String
    let initials: String
    let avatarColor: Color
    let dateAdded: Date
    
    init(name: String, phoneNumber: String) {
        self.name = name
        self.phoneNumber = phoneNumber
        self.dateAdded = Date()
        
        // Generate initials
        let components = name.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces)
        if components.count >= 2 {
            let firstInitial = String(components[0].prefix(1)).uppercased()
            let lastInitial = String(components[1].prefix(1)).uppercased()
            self.initials = "\(firstInitial)\(lastInitial)"
        } else if let firstComponent = components.first, !firstComponent.isEmpty {
            self.initials = String(firstComponent.prefix(2)).uppercased()
        } else {
            self.initials = "?"
        }
        
        // Generate avatar color
        let colors: [Color] = [
            Color(hex: "#FF6B6B"), Color(hex: "#4ECDC4"), Color(hex: "#45B7D1"),
            Color(hex: "#96CEB4"), Color(hex: "#FECA57"), Color(hex: "#FF9FF3"),
            Color(hex: "#54A0FF"), Color(hex: "#5F27CD"), Color(hex: "#00D2D3"),
            Color(hex: "#FF9F43"), Color(hex: "#10AC84"), Color(hex: "#EE5A24")
        ]
        let index = abs(name.hashValue) % colors.count
        self.avatarColor = colors[index]
    }
}

// MARK: - Contacts Manager
class SimpleContactsManager: ObservableObject {
    static let shared = SimpleContactsManager()
    @Published var contacts: [ContactItem] = []
    
    private init() {}
    
    func addContact(name: String, phoneNumber: String) {
        let normalizedNumber = normalizePhoneNumber(phoneNumber)
        let newContact = ContactItem(name: name, phoneNumber: normalizedNumber)
        contacts.append(newContact)
        contacts.sort { $0.name < $1.name }
    }
    
    func deleteContact(_ contact: ContactItem) {
        contacts.removeAll { $0.id == contact.id }
    }
    
    func searchContacts(searchText: String) -> [ContactItem] {
        if searchText.isEmpty {
            return contacts
        }
        return contacts.filter { contact in
            contact.name.localizedCaseInsensitiveContains(searchText) ||
            contact.phoneNumber.contains(searchText)
        }
    }
    
    func getContactName(for phoneNumber: String) -> String? {
        let normalizedNumber = normalizePhoneNumber(phoneNumber)
        return contacts.first { contact in
            normalizePhoneNumber(contact.phoneNumber) == normalizedNumber
        }?.name
    }
    
    private func normalizePhoneNumber(_ phoneNumber: String) -> String {
        // Remove all non-digit characters
        let cleanNumber = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Handle USA phone numbers
        if cleanNumber.count == 11 && cleanNumber.hasPrefix("1") {
            // Remove leading 1 (e.g., 12345678900 -> 2345678900)
            return String(cleanNumber.dropFirst())
        } else if cleanNumber.count == 10 {
            // Already 10 digits, keep as is
            return cleanNumber
        } else {
            // Return as-is for other formats
            return cleanNumber
        }
    }
    
    func formatPhoneNumber(_ phoneNumber: String) -> String {
        let cleanNumber = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        if cleanNumber.count == 10 {
            let area = cleanNumber.prefix(3)
            let exchange = cleanNumber.dropFirst(3).prefix(3)
            let number = cleanNumber.suffix(4)
            return "(\(area)) \(exchange)-\(number)"
        } else if cleanNumber.count == 11 && cleanNumber.hasPrefix("1") {
            let area = cleanNumber.dropFirst(1).prefix(3)
            let exchange = cleanNumber.dropFirst(4).prefix(3)
            let number = cleanNumber.suffix(4)
            return "(\(area)) \(exchange)-\(number)"
        }
        return phoneNumber
    }
}

// MARK: - Professional Contacts Screen
struct ProfessionalContactsScreen: View {
    let onCall: (String) -> Void
    
    @ObservedObject private var contactsManager = SimpleContactsManager.shared
    @State private var searchText = ""
    @State private var showingAddContact = false
    @State private var selectedContact: ContactItem?
    
    private var filteredContacts: [ContactItem] {
        contactsManager.searchContacts(searchText: searchText)
    }
    
    private var groupedContacts: [String: [ContactItem]] {
        Dictionary(grouping: filteredContacts) { contact in
            String(contact.name.prefix(1).uppercased())
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                ContactsSearchBar(searchText: $searchText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                
                if filteredContacts.isEmpty && !searchText.isEmpty {
                    // No search results
                    ContactsEmptySearchView()
                } else if contactsManager.contacts.isEmpty {
                    // No contacts at all
                    ContactsEmptyStateView {
                        showingAddContact = true
                    }
                } else {
                    // Contacts List
                    ContactsListView(
                        groupedContacts: groupedContacts,
                        onContactTap: { contact in
                            selectedContact = contact
                        },
                        onCall: onCall,
                        contactsManager: contactsManager
                    )
                }
            }
            .background(ProfessionalColors.professionalBackground.ignoresSafeArea())
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddContact = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(ProfessionalColors.professionalPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddContact) {
            ProfessionalAddContactView(
                onSave: { name, phoneNumber in
                    contactsManager.addContact(name: name, phoneNumber: phoneNumber)
                }
            )
        }
        .sheet(item: $selectedContact) { contact in
            ContactDetailSheet(
                contact: contact,
                onCall: onCall,
                onDelete: { contactToDelete in
                    contactsManager.deleteContact(contactToDelete)
                },
                contactsManager: contactsManager
            )
        }
    }
}

// MARK: - Search Bar
struct ContactsSearchBar: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ProfessionalColors.textSecondary)
                .font(.system(size: 16))
            
            TextField("Search contacts", text: $searchText)
                .font(.system(size: 16))
                .foregroundColor(ProfessionalColors.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ProfessionalColors.professionalSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(ProfessionalColors.professionalBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Empty States
struct ContactsEmptySearchView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(ProfessionalColors.textSecondary)
            
            Text("No Results Found")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(ProfessionalColors.textPrimary)
            
            Text("Try searching with a different name or number")
                .font(.body)
                .foregroundColor(ProfessionalColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ContactsEmptyStateView: View {
    let onAddContact: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "person.circle")
                    .font(.system(size: 64))
                    .foregroundColor(ProfessionalColors.professionalPrimary)
                
                Text("No Contacts")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(ProfessionalColors.textPrimary)
                
                Text("Add contacts to make calling easier and keep track of your connections")
                    .font(.body)
                    .foregroundColor(ProfessionalColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            Button(action: onAddContact) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add Your First Contact")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ProfessionalColors.professionalPrimary)
                )
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Contacts List
struct ContactsListView: View {
    let groupedContacts: [String: [ContactItem]]
    let onContactTap: (ContactItem) -> Void
    let onCall: (String) -> Void
    let contactsManager: SimpleContactsManager
    
    private var sortedKeys: [String] {
        groupedContacts.keys.sorted()
    }
    
    var body: some View {
        List {
            ForEach(sortedKeys, id: \.self) { letter in
                Section {
                    ForEach(groupedContacts[letter] ?? []) { contact in
                        ContactRowView(
                            contact: contact,
                            onTap: { onContactTap(contact) },
                            onCall: { onCall(contact.phoneNumber) },
                            contactsManager: contactsManager
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    Text(letter)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ProfessionalColors.textSecondary)
                        .padding(.leading, -8)
                }
            }
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - Contact Row
struct ContactRowView: View {
    let contact: ContactItem
    let onTap: () -> Void
    let onCall: () -> Void
    let contactsManager: SimpleContactsManager
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(contact.avatarColor)
                        .frame(width: 40, height: 40)
                    
                    Text(contact.initials)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                
                // Contact Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ProfessionalColors.textPrimary)
                        .lineLimit(1)
                    
                    Text(contactsManager.formatPhoneNumber(contact.phoneNumber))
                        .font(.system(size: 14))
                        .foregroundColor(ProfessionalColors.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Call Button
                Button(action: onCall) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ProfessionalColors.professionalSuccess)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(ProfessionalColors.professionalSuccess.opacity(0.1))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ProfessionalColors.professionalSurface)
                    .shadow(color: ProfessionalColors.professionalBorder, radius: 1, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Professional Add Contact Form
struct ProfessionalAddContactView: View {
    let onSave: (String, String) -> Void
    let onCancel: (() -> Void)?
    let initialPhoneNumber: String?
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var phoneNumber = ""
    @FocusState private var isNameFieldFocused: Bool
    
    init(onSave: @escaping (String, String) -> Void, onCancel: (() -> Void)? = nil, initialPhoneNumber: String? = nil) {
        self.onSave = onSave
        self.onCancel = onCancel
        self.initialPhoneNumber = initialPhoneNumber
        self._phoneNumber = State(initialValue: initialPhoneNumber ?? "")
    }
    
    private var isValidForm: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Avatar Placeholder
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(ProfessionalColors.professionalPrimary.opacity(0.1))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(ProfessionalColors.professionalPrimary)
                        }
                        
                        Text("New Contact")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(ProfessionalColors.textPrimary)
                    }
                    .padding(.top, 20)
                    
                    // Form Fields
                    VStack(spacing: 20) {
                        ProfessionalFormField(
                            title: "Full Name",
                            text: $name,
                            placeholder: "Enter contact name",
                            keyboardType: .default,
                            isFocused: $isNameFieldFocused
                        )
                        
                        ProfessionalFormField(
                            title: "Phone Number",
                            text: $phoneNumber,
                            placeholder: "Enter phone number",
                            keyboardType: .phonePad
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                }
            }
            .background(ProfessionalColors.professionalBackground.ignoresSafeArea())
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                        onCancel?()
                    }
                    .foregroundColor(ProfessionalColors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(name.trimmingCharacters(in: .whitespaces), phoneNumber.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    }
                    .foregroundColor(isValidForm ? ProfessionalColors.professionalPrimary : ProfessionalColors.textSecondary)
                    .font(.system(size: 16, weight: .medium))
                    .disabled(!isValidForm)
                }
            }
        }
        .onAppear {
            isNameFieldFocused = true
        }
    }
}

// MARK: - Professional Form Field
struct ProfessionalFormField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let keyboardType: UIKeyboardType
    var isFocused: FocusState<Bool>.Binding? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ProfessionalColors.textPrimary)
            
            Group {
                if let focusBinding = isFocused {
                    TextField(placeholder, text: $text)
                        .focused(focusBinding)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.system(size: 16))
            .foregroundColor(ProfessionalColors.textPrimary)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(keyboardType == .default ? .words : .none)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(ProfessionalColors.professionalSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(ProfessionalColors.professionalBorder, lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Contact Detail Sheet
struct ContactDetailSheet: View {
    let contact: ContactItem
    let onCall: (String) -> Void
    let onDelete: (ContactItem) -> Void
    let contactsManager: SimpleContactsManager
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Profile Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(contact.avatarColor)
                                .frame(width: 100, height: 100)
                            
                            Text(contact.initials)
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(.white)
                        }
                        
                        Text(contact.name)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(ProfessionalColors.textPrimary)
                        
                        Text(contactsManager.formatPhoneNumber(contact.phoneNumber))
                            .font(.system(size: 18))
                            .foregroundColor(ProfessionalColors.textSecondary)
                    }
                    .padding(.top, 20)
                    
                    // Action Buttons
                    HStack(spacing: 16) {
                        ContactActionButton(
                            icon: "phone.fill",
                            title: "Call",
                            color: ProfessionalColors.professionalSuccess
                        ) {
                            onCall(contact.phoneNumber)
                            dismiss()
                        }
                        
                        ContactActionButton(
                            icon: "message.fill",
                            title: "Message",
                            color: ProfessionalColors.professionalPrimary
                        ) {
                            // TODO: Implement messaging
                        }
                    }
                    
                    // Contact Info
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Contact Information")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(ProfessionalColors.textPrimary)
                        
                        ContactInfoCard(
                            icon: "phone.fill",
                            title: "Phone",
                            value: contactsManager.formatPhoneNumber(contact.phoneNumber)
                        )
                        
                        ContactInfoCard(
                            icon: "calendar",
                            title: "Added",
                            value: formatDate(contact.dateAdded)
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
            .background(ProfessionalColors.professionalBackground.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(ProfessionalColors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Delete Contact", role: .destructive) {
                            showingDeleteAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(ProfessionalColors.textSecondary)
                    }
                }
            }
        }
        .alert("Delete Contact", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete(contact)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete \(contact.name)? This action cannot be undone.")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Contact Action Button
struct ContactActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ProfessionalColors.textSecondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Contact Info Card
struct ContactInfoCard: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ProfessionalColors.professionalPrimary.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(ProfessionalColors.professionalPrimary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ProfessionalColors.textPrimary)
                
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(ProfessionalColors.textSecondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ProfessionalColors.professionalSurface)
                .shadow(color: ProfessionalColors.professionalBorder, radius: 1, x: 0, y: 1)
        )
    }
}

