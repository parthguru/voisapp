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
    let onStartCall: () -> Void
    
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
            onStartCall: {},
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

struct CallQualityIndicator: Equatable {
    let barCount: Int
    let color: Color
    let text: String
    
    static let excellent = CallQualityIndicator(barCount: 4, color: Color(hex: "#10B981"), text: "Excellent")
    static let good = CallQualityIndicator(barCount: 3, color: Color(hex: "#10B981"), text: "Good") 
    static let fair = CallQualityIndicator(barCount: 2, color: Color(hex: "#F59E0B"), text: "Fair")
    static let poor = CallQualityIndicator(barCount: 1, color: Color(hex: "#EF4444"), text: "Poor")
    static let none = CallQualityIndicator(barCount: 0, color: Color.gray, text: "No Signal")
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
// @ObservedObject private var callHistoryManager = CallHistoryManager.shared
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
            callHistoryDB.fetchCallHistoryFiltered(by: "default")
            
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

// MARK: - MainTabView - Fixed compilation issue
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
            // Premium Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.98, green: 0.98, blue: 0.98),
                    Color(red: 0.96, green: 0.96, blue: 0.96)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            TabView(selection: $selectedTab) {
                // MARK: - Dialer Tab (Primary) - Premium Professional Design
                PremiumGlassmorphismDialer(
                    callViewModel: callViewModel,
                    homeViewModel: homeViewModel,
                    onStartCall: {
                        NSLog("🔵 STEP 5.5: MainTabView - onStartCall triggered, invoking HomeViewController callback")
                        onStartCall()
                        // 🔥 CALLKIT-ONLY: CallKit handles all call presentation, no app UI needed
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
                PremiumGlassmorphismRecents(
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
                        // 🔥 CALLKIT-ONLY: CallKit handles all call presentation, no app UI needed
                        NSLog("🔥 CALLKIT-ONLY: Call initiated from contacts, CallKit will handle all UI")
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
            .accentColor(Color(red: 0.23, green: 0.51, blue: 0.96))
            // 🔥 CALLKIT-ONLY: Custom call UI presentation disabled
            // CallKit now handles ALL call presentation (incoming, outgoing, active calls)
            // Custom app call screens are no longer shown automatically
        }
        // MARK: - 🔥 CALLKIT-ONLY: Custom Call Modals Disabled
        // CallKit handles all call presentation - no custom call screens needed
        /*
        .fullScreenCover(isPresented: $showingActiveCall) {
            CallView(
                viewModel: callViewModel,
                isPhoneNumber: true,
                onStartCall: { /* Not used in active call */ },
                onEndCall: {
                    onEndCall()
                    showingActiveCall = false
                },
                onRejectCall: { /* Not used in active call */ },
                onAnswerCall: { /* Not used in active call */ },
                onMuteUnmuteSwitch: onMuteUnmuteSwitch,
                onToggleSpeaker: onToggleSpeaker,
                onHold: onHold,
                onDTMF: onDTMF,
                onRedial: nil
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
        */
    }
}

// MARK: - Premium Dialer View - Matching React Design
struct PremiumDialerView: View {
    @ObservedObject var callViewModel: CallViewModel
    @ObservedObject var homeViewModel: HomeViewModel
    @State private var phoneNumber: String = ""
    
    let onStartCall: () -> Void
    let onConnect: () -> Void  
    let onDisconnect: () -> Void
    
    private var isConnected: Bool {
        homeViewModel.socketState == .connected || homeViewModel.socketState == .clientReady
    }
    
    private var formattedNumber: String {
        if phoneNumber.isEmpty {
            return "Enter number"
        }
        return formatPhoneNumber(phoneNumber)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top padding
            Spacer().frame(height: 60)
            
            // Connection Status
            HStack {
                Circle()
                    .fill(isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(isConnected ? "Connected" : "Disconnected")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                if !isConnected {
                    Button("Connect") {
                        onConnect()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.23, green: 0.51, blue: 0.96))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 20)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
            
            Spacer()
            
            // Phone Number Display
            VStack(spacing: 16) {
                Text(formattedNumber)
                    .font(.system(size: 32, weight: .ultraLight, design: .default))
                    .foregroundColor(phoneNumber.isEmpty ? .secondary : .primary)
                    .tracking(phoneNumber.isEmpty ? 0.5 : 2.0)
                    .frame(minHeight: 48)
                    .animation(.easeInOut(duration: 0.3), value: phoneNumber.isEmpty)
                
                // Animated underline
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.23, green: 0.51, blue: 0.96),
                                Color(red: 0.38, green: 0.65, blue: 0.98)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .frame(width: phoneNumber.isEmpty ? 0 : nil)
                    .animation(.easeInOut(duration: 0.5), value: phoneNumber.isEmpty)
                    .overlay(
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                            .opacity(phoneNumber.isEmpty ? 1 : 0)
                            .animation(.easeInOut(duration: 0.3), value: phoneNumber.isEmpty)
                    )
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Premium Keypad
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 3), spacing: 20) {
                ForEach(keypadButtons, id: \.key) { button in
                    PremiumKeypadButtonView(
                        key: button.key,
                        letters: button.letters,
                        onTap: { key in
                            phoneNumber += key
                            callViewModel.sipAddress = phoneNumber
                        }
                    )
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Call Button
            Button(action: {
                if !phoneNumber.isEmpty && isConnected {
                    onStartCall()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 20, weight: .medium))
                    Text("Call")
                        .font(.system(size: 16, weight: .semibold))
                        .tracking(0.5)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    phoneNumber.isEmpty || !isConnected ? Color.gray.opacity(0.6) : Color(red: 0.065, green: 0.725, blue: 0.506),
                                    phoneNumber.isEmpty || !isConnected ? Color.gray.opacity(0.4) : Color(red: 0.022, green: 0.588, blue: 0.408)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: phoneNumber.isEmpty || !isConnected ? .clear : Color(red: 0.065, green: 0.725, blue: 0.506).opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(phoneNumber.isEmpty || !isConnected)
            .padding(.horizontal, 20)
            .animation(.easeInOut(duration: 0.3), value: phoneNumber.isEmpty)
            .animation(.easeInOut(duration: 0.3), value: isConnected)
            
            Spacer().frame(height: 40)
        }
    }
    
    private var keypadButtons: [KeypadButtonData] = [
        KeypadButtonData(key: "1", letters: ""),
        KeypadButtonData(key: "2", letters: "ABC"),
        KeypadButtonData(key: "3", letters: "DEF"),
        KeypadButtonData(key: "4", letters: "GHI"),
        KeypadButtonData(key: "5", letters: "JKL"),
        KeypadButtonData(key: "6", letters: "MNO"),
        KeypadButtonData(key: "7", letters: "PQRS"),
        KeypadButtonData(key: "8", letters: "TUV"),
        KeypadButtonData(key: "9", letters: "WXYZ"),
        KeypadButtonData(key: "*", letters: ""),
        KeypadButtonData(key: "0", letters: "+"),
        KeypadButtonData(key: "#", letters: "")
    ]
    
    private func formatPhoneNumber(_ number: String) -> String {
        let cleanNumber = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        switch cleanNumber.count {
        case 0:
            return ""
        case 1...3:
            return cleanNumber
        case 4...6:
            let area = String(cleanNumber.prefix(3))
            let exchange = String(cleanNumber.dropFirst(3))
            return "\(area) \(exchange)"
        case 7...10:
            let area = String(cleanNumber.prefix(3))
            let exchange = String(cleanNumber.dropFirst(3).prefix(3))
            let number = String(cleanNumber.dropFirst(6))
            return "\(area) \(exchange) \(number)"
        default:
            let area = String(cleanNumber.prefix(3))
            let exchange = String(cleanNumber.dropFirst(3).prefix(3))
            let number = String(cleanNumber.dropFirst(6).prefix(4))
            let remaining = String(cleanNumber.dropFirst(10))
            return remaining.isEmpty ? "\(area) \(exchange) \(number)" : "\(area) \(exchange) \(number) \(remaining)"
        }
    }
}

struct KeypadButtonData {
    let key: String
    let letters: String
}

struct PremiumKeypadButtonView: View {
    let key: String
    let letters: String
    let onTap: (String) -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            onTap(key)
        }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .fill(Color.white.opacity(0.6))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 6)
                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
                
                VStack(spacing: 2) {
                    Text(key)
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.primary)
                    
                    if !letters.isEmpty {
                        Text(letters)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .tracking(1.5)
                    }
                }
            }
        }
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Enhanced Premium Glassmorphism Dialer - Ultra Premium React Design
struct PremiumGlassmorphismDialer: View {
    @ObservedObject var callViewModel: CallViewModel
    @ObservedObject var homeViewModel: HomeViewModel
    @State private var phoneNumber: String = ""
    @State private var animationOffset: CGFloat = 0
    @State private var showingBackspace = false
    
    let onStartCall: () -> Void
    let onConnect: () -> Void  
    let onDisconnect: () -> Void
    
    init(callViewModel: CallViewModel, homeViewModel: HomeViewModel, onStartCall: @escaping () -> Void, onConnect: @escaping () -> Void, onDisconnect: @escaping () -> Void) {
        NSLog("🔵 INIT: PremiumGlassmorphismDialer created with callbacks!")
        self.callViewModel = callViewModel
        self.homeViewModel = homeViewModel
        self.onStartCall = onStartCall
        self.onConnect = onConnect
        self.onDisconnect = onDisconnect
    }
    
    private var isConnected: Bool {
        homeViewModel.socketState == .connected || homeViewModel.socketState == .clientReady
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Enhanced Multi-Layer Background with Rich Colors for Superior Glassmorphism
                // Layer 1: Rich gradient base
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.88, green: 0.92, blue: 0.98),
                        Color(red: 0.85, green: 0.90, blue: 0.95),
                        Color(red: 0.82, green: 0.88, blue: 0.94),
                        Color(red: 0.90, green: 0.94, blue: 0.98)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Layer 2: Animated mesh gradient
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.23, green: 0.51, blue: 0.96).opacity(0.08),
                        Color(red: 0.38, green: 0.65, blue: 0.98).opacity(0.04),
                        Color.clear
                    ]),
                    center: UnitPoint(x: 0.3 + animationOffset * 0.1, y: 0.2 + animationOffset * 0.1),
                    startRadius: 50,
                    endRadius: 400
                )
                .ignoresSafeArea()
                
                // Layer 3: Floating premium ambient shapes  
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    index % 2 == 0 ? 
                                    Color(red: 0.23, green: 0.51, blue: 0.96).opacity(0.05) :
                                    Color(red: 0.38, green: 0.65, blue: 0.98).opacity(0.03),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 30,
                                endRadius: index == 0 ? 150 : index == 1 ? 200 : 180
                            )
                        )
                        .frame(width: CGFloat(200 + index * 40), height: CGFloat(200 + index * 40))
                        .offset(
                            x: geometry.size.width * (index == 0 ? 0.1 : index == 1 ? 0.9 : index == 2 ? 0.5 : index == 3 ? 0.2 : 0.8) + animationOffset * CGFloat(index + 1) * 0.2,
                            y: geometry.size.height * (index == 0 ? 0.2 : index == 1 ? 0.8 : index == 2 ? 0.4 : index == 3 ? 0.6 : 0.3) + animationOffset * CGFloat(index + 1) * 0.15
                        )
                        .opacity(0.6)
                }
                
                VStack(spacing: 0) {
                    // Compact top padding with safe area
                    Spacer().frame(height: 20)
                    
                    // Enhanced Connection Status - Superior Glassmorphism Card
                    if !isConnected {
                        HStack {
                            // Animated Status Indicator
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.3))
                                    .frame(width: 12, height: 12)
                                    .scaleEffect(1.2)
                                    .opacity(0.8)
                                
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                            }
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isConnected)
                            
                            Text("Disconnected")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button("Connect") {
                                onConnect()
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(red: 0.23, green: 0.51, blue: 0.96))
                                    .shadow(color: Color(red: 0.23, green: 0.51, blue: 0.96).opacity(0.3), radius: 8, x: 0, y: 4)
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.6), Color.white.opacity(0.2)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 0.8
                                        )
                                )
                        )
                        .padding(.horizontal, 20)
                        .shadow(color: .black.opacity(0.08), radius: 25, x: 0, y: 12)
                        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
                    }
                    
                    Spacer()
                    
                    // Enhanced Phone Number Display with Glassmorphism Container
                    VStack(spacing: 24) {
                        HStack {
                            Text(phoneNumber.isEmpty ? "Enter phone number" : formatPhoneNumber(phoneNumber))
                                .font(.system(size: 38, weight: .ultraLight, design: .default))
                                .foregroundColor(phoneNumber.isEmpty ? .secondary : .primary)
                                .tracking(phoneNumber.isEmpty ? 0.5 : 2.8)
                                .frame(minHeight: 52)
                                .animation(.easeInOut(duration: 0.3), value: phoneNumber.isEmpty)
                                .monospacedDigit()
                            
                            // Animated Backspace Button
                            if !phoneNumber.isEmpty {
                                Button(action: {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        if !phoneNumber.isEmpty {
                                            phoneNumber.removeLast()
                                            callViewModel.sipAddress = phoneNumber
                                        }
                                    }
                                }) {
                                    Image(systemName: "delete.left.fill")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            Circle()
                                                .fill(.ultraThinMaterial)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                                                )
                                        )
                                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        
                        // Enhanced Animated Gradient Underline
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.23, green: 0.51, blue: 0.96),
                                        Color(red: 0.38, green: 0.65, blue: 0.98),
                                        Color(red: 0.23, green: 0.51, blue: 0.96)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 2)
                            .frame(width: phoneNumber.isEmpty ? 0 : nil)
                            .animation(.easeInOut(duration: 0.7), value: phoneNumber.isEmpty)
                            .overlay(
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 1)
                                    .opacity(phoneNumber.isEmpty ? 1 : 0)
                                    .animation(.easeInOut(duration: 0.3), value: phoneNumber.isEmpty)
                            )
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                    
                    // Enhanced Premium Glassmorphism Keypad
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 26), count: 3), spacing: 22) {
                        ForEach(0..<12) { index in
                            let keypadData = getKeypadData(for: index)
                            
                            ZStack {
                                VStack(spacing: 5) {
                                    Text(keypadData.key)
                                        .font(.system(size: 34, weight: .light))
                                        .foregroundColor(.primary)
                                    
                                    if !keypadData.letters.isEmpty {
                                        Text(keypadData.letters)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.secondary)
                                            .tracking(1.4)
                                    }
                                }
                                .frame(width: 78, height: 78)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 0.8
                                                )
                                        )
                                        .shadow(color: .black.opacity(0.06), radius: 15, x: 0, y: 8)
                                        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
                                )
                            }
                            .scaleEffect(0.98)
                            .onLongPressGesture(minimumDuration: 0.8) {
                                if keypadData.key == "0" {
                                    handleLongPress0()
                                }
                            }
                            .onTapGesture {
                                handleKeypadTap(key: keypadData.key)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer().frame(height: 35)
                    
                    // Enhanced Premium Call Button with Superior Glassmorphism
                    Button(action: {
                        NSLog("🔵 STEP 0: BUTTON TAP DETECTED! Call button pressed!")
                        NSLog("🔵 STEP 0: Call button action block executed on thread: %@", Thread.current.description)
                        NSLog("🔵 STEP 0: About to call handleCallAction()")
                        handleCallAction()
                        NSLog("🔵 STEP 0: Returned from handleCallAction() successfully")
                    }) {
                        HStack(spacing: 14) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 22, weight: .medium))
                            Text("Call")
                                .font(.system(size: 20, weight: .semibold))
                                .tracking(1.0)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            RoundedRectangle(cornerRadius: 30)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            phoneNumber.isEmpty || !isConnected ? Color.gray.opacity(0.4) : Color(red: 0.065, green: 0.725, blue: 0.506),
                                            phoneNumber.isEmpty || !isConnected ? Color.gray.opacity(0.2) : Color(red: 0.022, green: 0.588, blue: 0.408),
                                            phoneNumber.isEmpty || !isConnected ? Color.gray.opacity(0.3) : Color(red: 0.065, green: 0.725, blue: 0.506)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 30)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                                )
                        )
                        .shadow(
                            color: phoneNumber.isEmpty || !isConnected ? .clear : Color(red: 0.065, green: 0.725, blue: 0.506).opacity(0.4),
                            radius: 16,
                            x: 0,
                            y: 8
                        )
                        .shadow(
                            color: phoneNumber.isEmpty || !isConnected ? .clear : Color(red: 0.065, green: 0.725, blue: 0.506).opacity(0.2),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                    }
                    .disabled(phoneNumber.isEmpty || !isConnected)
                    .padding(.horizontal, 20)
                    .animation(.easeInOut(duration: 0.3), value: phoneNumber.isEmpty)
                    
                    Spacer().frame(height: 50)
                }
            }
        }
        .onAppear {
            phoneNumber = callViewModel.sipAddress
            startBackgroundAnimation()
        }
    }
    
    // MARK: - Enhanced Helper Methods with VoIP Integration
    
    private func handleKeypadTap(key: String) {
        print("🔢 KEYPAD TAP: Key '\(key)' pressed")
        print("🔢 KEYPAD TAP: phoneNumber before: '\(phoneNumber)'")
        withAnimation(.easeOut(duration: 0.2)) {
            phoneNumber += key
            callViewModel.sipAddress = phoneNumber
            print("🔢 KEYPAD TAP: phoneNumber after: '\(phoneNumber)'")
            print("🔢 KEYPAD TAP: callViewModel.sipAddress set to: '\(callViewModel.sipAddress)'")
        }
        
        // Haptic feedback (if available)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func handleLongPress0() {
        withAnimation(.easeOut(duration: 0.2)) {
            // Add + for international dialing
            if phoneNumber.isEmpty {
                phoneNumber = "+"
            } else if phoneNumber.last == "0" {
                phoneNumber.removeLast()
                phoneNumber += "+"
            } else {
                phoneNumber += "+"
            }
            callViewModel.sipAddress = phoneNumber
        }
        
        // Haptic feedback for long press
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func handleCallAction() {
        NSLog("🔵 STEP 1: Call button tapped - Phone: [%@]", phoneNumber)
        
        NSLog("🔵 STEP 2: Validating call conditions - isEmpty: %@, isConnected: %@", phoneNumber.isEmpty ? "true" : "false", isConnected ? "true" : "false")
        guard !phoneNumber.isEmpty && isConnected else {
            NSLog("🔵 STEP 2: FAILED - Phone empty: %@ or not connected: %@", phoneNumber.isEmpty ? "true" : "false", isConnected ? "false" : "true")
            return
        }
        
        NSLog("🔵 STEP 3: Syncing with CallViewModel - setting sipAddress to: [%@]", phoneNumber)
        callViewModel.sipAddress = phoneNumber
        
        NSLog("🔵 STEP 4: Calling onStartCall() callback to parent view")
        onStartCall()
        
        // Success haptic feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
        NSLog("🔵 STEP 5: UI phase completed successfully")
    }
    
    private func startBackgroundAnimation() {
        withAnimation(Animation.linear(duration: 25.0).repeatForever(autoreverses: true)) {
            animationOffset = 1.0
        }
    }
    
    private func formatPhoneNumber(_ number: String) -> String {
        // Handle international format with +
        if number.hasPrefix("+") {
            let cleanNumber = String(number.dropFirst()).components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            return "+\(cleanNumber)"
        }
        
        let cleanNumber = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        switch cleanNumber.count {
        case 0:
            return ""
        case 1...3:
            return cleanNumber
        case 4...6:
            let area = String(cleanNumber.prefix(3))
            let exchange = String(cleanNumber.dropFirst(3))
            return "(\(area)) \(exchange)"
        case 7...10:
            let area = String(cleanNumber.prefix(3))
            let exchange = String(cleanNumber.dropFirst(3).prefix(3))
            let number = String(cleanNumber.dropFirst(6))
            return "(\(area)) \(exchange)-\(number)"
        default:
            // Handle longer international numbers
            let area = String(cleanNumber.prefix(3))
            let exchange = String(cleanNumber.dropFirst(3).prefix(3))
            let number = String(cleanNumber.dropFirst(6).prefix(4))
            let remaining = String(cleanNumber.dropFirst(10))
            return remaining.isEmpty ? "(\(area)) \(exchange)-\(number)" : "(\(area)) \(exchange)-\(number) \(remaining)"
        }
    }
    
    private func getKeypadData(for index: Int) -> (key: String, letters: String) {
        let keypadLayout = [
            ("1", ""), ("2", "ABC"), ("3", "DEF"),
            ("4", "GHI"), ("5", "JKL"), ("6", "MNO"),
            ("7", "PQRS"), ("8", "TUV"), ("9", "WXYZ"),
            ("*", ""), ("0", "+"), ("#", "")
        ]
        return keypadLayout[index]
    }
}

// MARK: - Premium Glassmorphism Recents Screen - Optimized for Performance
struct PremiumGlassmorphismRecents: View {
    let onRedial: (String) -> Void
    
    @State private var searchText = ""
    @State private var selectedCall: CallHistoryItem?
    @StateObject private var callHistoryDB = CallHistoryDatabase.shared
// @ObservedObject private var callHistoryManager = CallHistoryManager.shared
    @ObservedObject private var contactsManager = SimpleContactsManager.shared
    
    // Real call history data from database
    private var callHistory: [CallHistoryItem] {
        return callHistoryDB.callHistory.map { entry in
            let phoneNumber = entry.phoneNumber ?? "Unknown"
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
    
    private var filteredCalls: [CallHistoryItem] {
        if searchText.isEmpty {
            return callHistory
        }
        return callHistory.filter { call in
            call.name.lowercased().contains(searchText.lowercased()) ||
            call.phoneNumber.contains(searchText)
        }
    }
    
    private var groupedCalls: [(String, [CallHistoryItem])] {
        let grouped = Dictionary(grouping: filteredCalls) { call in
            let calendar = Calendar.current
            if calendar.isDateInToday(call.timestamp) {
                return "Today"
            } else if calendar.isDateInYesterday(call.timestamp) {
                return "Yesterday" 
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return formatter.string(from: call.timestamp)
            }
        }
        return grouped.sorted { (first, second) in
            if first.key == "Today" { return true }
            if second.key == "Today" { return false }
            if first.key == "Yesterday" { return true }
            if second.key == "Yesterday" { return false }
            return first.key > second.key
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Enhanced Multi-Layer Background matching keypad
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.88, green: 0.92, blue: 0.98),
                        Color(red: 0.85, green: 0.90, blue: 0.95),
                        Color(red: 0.82, green: 0.88, blue: 0.94),
                        Color(red: 0.90, green: 0.94, blue: 0.98)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Ambient floating shapes (reduced for performance)
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    index % 2 == 0 ? 
                                    Color(red: 0.23, green: 0.51, blue: 0.96).opacity(0.04) :
                                    Color(red: 0.38, green: 0.65, blue: 0.98).opacity(0.03),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 40,
                                endRadius: index == 0 ? 180 : index == 1 ? 220 : 200
                            )
                        )
                        .frame(width: CGFloat(180 + index * 30), height: CGFloat(180 + index * 30))
                        .offset(
                            x: geometry.size.width * (index == 0 ? 0.15 : index == 1 ? 0.85 : 0.5),
                            y: geometry.size.height * (index == 0 ? 0.25 : index == 1 ? 0.75 : 0.4)
                        )
                        .opacity(0.7)
                }
                
                VStack(spacing: 0) {
                    // Compact top padding
                    Spacer().frame(height: 20)
                    
                    // Optimized Search Bar (reduced prominence)
                    searchBarSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    
                    // Main Content
                    if groupedCalls.isEmpty {
                        emptyStateView
                    } else {
                        callHistoryContent
                    }
                }
            }
        }
        .ignoresSafeArea(.all, edges: .top)
    }
    
    // MARK: - Optimized Search Bar
    private var searchBarSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            
            TextField("Search Contacts & Places", text: $searchText)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.primary)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Call History Content with Performance Optimization
    private var callHistoryContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 24) {
                ForEach(groupedCalls.indices, id: \.self) { groupIndex in
                    let group = groupedCalls[groupIndex]
                    
                    VStack(spacing: 16) {
                        // Date Header
                        HStack {
                            Text(group.0)
                                .font(.system(size: 20, weight: .semibold, design: .default))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        // Glass Container for Calls (optimized shadows)
                        VStack(spacing: 0) {
                            ForEach(group.1.indices, id: \.self) { callIndex in
                                let call = group.1[callIndex]
                                callRowView(call: call, isLast: callIndex == group.1.count - 1)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                                )
                        )
                        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
                        .padding(.horizontal, 20)
                    }
                }
                
                Spacer().frame(height: 40)
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Optimized Call Row (65px height for better density)
    private func callRowView(call: CallHistoryItem, isLast: Bool) -> some View {
        HStack(spacing: 14) {
            // Avatar with Glass Effect
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [call.avatarColor, call.avatarColor.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                Text(call.avatar)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                // Call Type Indicator
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: getCallIcon(call: call))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(getCallIconColor(call: call))
                    )
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .offset(x: 16, y: 16)
            }
            
            // Call Details (optimized spacing)
            VStack(alignment: .leading, spacing: 2) {
                Text(call.name)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(call.isMissed ? .red : .primary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(getCallTypeText(call: call))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                    
                    Text("Mobile")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                }
                
                Text("Telnyx")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(red: 0.23, green: 0.51, blue: 0.96))
            }
            
            Spacer()
            
            // Time and Actions (optimized hierarchy)
            VStack(alignment: .trailing, spacing: 4) {
                Text(call.time)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    // Info button (ghost style)
                    Button(action: { selectedCall = call }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    
                    // Call button (dominant hierarchy)
                    Button(action: { onRedial(call.phoneNumber) }) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(red: 0.065, green: 0.725, blue: 0.506),
                                                Color(red: 0.022, green: 0.588, blue: 0.408)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                    }
                    .shadow(color: Color(red: 0.065, green: 0.725, blue: 0.506).opacity(0.3), radius: 6, x: 0, y: 3)
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(call.isMissed ? Color.red.opacity(0.02) : Color.clear)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 0.5)
                .opacity(isLast ? 0 : 1),
            alignment: .bottom
        )
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "clock")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No Recent Calls")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("Your call history will appear here")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Helper Methods
    private func generateAvatarColor(for name: String) -> Color {
        let colors = [
            Color(red: 0.23, green: 0.51, blue: 0.96), // Primary blue
            Color(red: 0.38, green: 0.65, blue: 0.98), // Light blue
            Color(red: 0.16, green: 0.50, blue: 0.73), // Dark blue
            Color(red: 0.20, green: 0.78, blue: 0.65), // Teal
            Color(red: 0.61, green: 0.35, blue: 0.71), // Purple
            Color(red: 0.85, green: 0.34, blue: 0.61)  // Pink
        ]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
    
    private func formatTime(from date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func getCallIcon(call: CallHistoryItem) -> String {
        if call.isMissed { return "phone.down.fill" }
        return call.isIncoming ? "phone.arrow.down.left.fill" : "phone.arrow.up.right.fill"
    }
    
    private func getCallIconColor(call: CallHistoryItem) -> Color {
        if call.isMissed { return .red }
        return call.isIncoming ? .green : .blue
    }
    
    private func getCallTypeText(call: CallHistoryItem) -> String {
        if call.isMissed { return "Missed" }
        return call.isIncoming ? "Incoming" : "Outgoing"
    }
}

