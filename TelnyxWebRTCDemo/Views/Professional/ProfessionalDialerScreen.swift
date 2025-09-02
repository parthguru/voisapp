import SwiftUI
import TelnyxRTC

struct ProfessionalDialerScreen: View {
    @ObservedObject var callViewModel: CallViewModel
    @ObservedObject var homeViewModel: HomeViewModel
    
    @State private var isPhoneNumber: Bool = true
    @State private var showRecentNumbers = false
    @State private var recentNumbers: [String] = []
    
    let onStartCall: () -> Void
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    
    private let keypadButtons = [
        [KeypadButton(number: "1", letters: ""), KeypadButton(number: "2", letters: "ABC"), KeypadButton(number: "3", letters: "DEF")],
        [KeypadButton(number: "4", letters: "GHI"), KeypadButton(number: "5", letters: "JKL"), KeypadButton(number: "6", letters: "MNO")],
        [KeypadButton(number: "7", letters: "PQRS"), KeypadButton(number: "8", letters: "TUV"), KeypadButton(number: "9", letters: "WXYZ")],
        [KeypadButton(number: "*", letters: ""), KeypadButton(number: "0", letters: "+"), KeypadButton(number: "#", letters: "")]
    ]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // MARK: - Header Section
                headerSection
                
                // MARK: - Number Display Section
                numberDisplaySection
                
                // MARK: - Connection Status (Subtle)
                if homeViewModel.socketState != .connected && homeViewModel.socketState != .clientReady {
                    connectionStatusSection
                }
                
                // MARK: - Keypad Section  
                keypadSection
                
                // MARK: - Action Buttons Section
                actionButtonsSection
                
                Spacer(minLength: 20)
            }
            .background(Color.professionalBackground.ignoresSafeArea())
        }
        .onAppear {
            loadRecentNumbers()
            // Auto-connect if disconnected (background management)
            if homeViewModel.socketState == .disconnected {
                onConnect()
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            // Logo (smaller, less prominent)
            Image("telnyx-logo")
                .resizable()
                .scaledToFit()
                .frame(height: 32)
                .opacity(0.8)
            
            Spacer()
            
            // Recent numbers dropdown
            Button(action: {
                showRecentNumbers.toggle()
            }) {
                Image(systemName: "clock")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.professionalTextSecondary)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    // MARK: - Number Display Section  
    private var numberDisplaySection: some View {
        VStack(spacing: 16) {
            // Input type toggle
            inputTypeToggle
            
            // Number display
            numberDisplay
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }
    
    private var inputTypeToggle: some View {
        HStack(spacing: 0) {
            ToggleButton(
                title: "Phone",
                isSelected: isPhoneNumber,
                action: { isPhoneNumber = true }
            )
            
            ToggleButton(
                title: "SIP",
                isSelected: !isPhoneNumber,
                action: { isPhoneNumber = false }
            )
        }
        .professionalCardStyle(padding: 4)
    }
    
    private var numberDisplay: some View {
        VStack(spacing: 8) {
            HStack {
                Text(callViewModel.sipAddress.isEmpty ? (isPhoneNumber ? "Enter phone number" : "Enter SIP address") : callViewModel.sipAddress)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(callViewModel.sipAddress.isEmpty ? .professionalTextSecondary : .professionalTextPrimary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                
                if !callViewModel.sipAddress.isEmpty {
                    Button(action: {
                        if !callViewModel.sipAddress.isEmpty {
                            callViewModel.sipAddress.removeLast()
                        }
                    }) {
                        Image(systemName: "delete.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.professionalTextSecondary)
                    }
                }
            }
            .frame(height: 44)
            
            // Subtle divider
            Rectangle()
                .fill(Color.professionalBorder)
                .frame(height: 1)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Connection Status (Subtle)
    private var connectionStatusSection: some View {
        HStack {
            Circle()
                .fill(connectionStatusColor)
                .frame(width: 8, height: 8)
            
            Text(connectionStatusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.professionalTextSecondary)
            
            Spacer()
            
            if homeViewModel.socketState == .disconnected {
                Button("Connect") {
                    onConnect()
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.professionalPrimary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.professionalSurface.opacity(0.5))
    }
    
    // MARK: - Keypad Section
    private var keypadSection: some View {
        VStack(spacing: 16) {
            ForEach(keypadButtons.indices, id: \.self) { rowIndex in
                HStack(spacing: 24) {
                    ForEach(keypadButtons[rowIndex], id: \.number) { key in
                        KeypadButtonView(
                            keypadButton: key,
                            onTap: { number in
                                appendNumber(number)
                            }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        HStack(spacing: 32) {
            // Call History shortcut (subtle)
            Button(action: {
                // This will be handled by tab switching in parent
            }) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.professionalTextSecondary)
                    .frame(width: 44, height: 44)
            }
            
            // Main Call Button
            Button(action: {
                if !callViewModel.sipAddress.isEmpty && (homeViewModel.socketState == .connected || homeViewModel.socketState == .clientReady) {
                    onStartCall()
                }
            }) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 72, height: 72)
                    .background(
                        Circle()
                            .fill(callButtonColor)
                            .shadow(color: .professionalButtonShadow, radius: 6, x: 0, y: 3)
                    )
            }
            .disabled(callViewModel.sipAddress.isEmpty || (homeViewModel.socketState != .connected && homeViewModel.socketState != .clientReady))
            .accessibilityIdentifier(AccessibilityIdentifiers.callButton)
            
            // Settings shortcut (subtle)
            Button(action: {
                // This will be handled by tab switching in parent
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.professionalTextSecondary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.vertical, 24)
    }
    
    // MARK: - Helper Functions
    private func appendNumber(_ number: String) {
        callViewModel.sipAddress += number
    }
    
    private func loadRecentNumbers() {
        // Load from call history - placeholder for now
        recentNumbers = []
    }
    
    private var connectionStatusColor: Color {
        switch homeViewModel.socketState {
        case .connected, .clientReady:
            return .professionalSuccess
        case .disconnected:
            return .professionalAlert
        }
    }
    
    private var connectionStatusText: String {
        switch homeViewModel.socketState {
        case .connected:
            return "Connected"
        case .clientReady:
            return "Ready"
        case .disconnected:
            return "Disconnected"
        }
    }
    
    private var callButtonColor: Color {
        let isDisabled = callViewModel.sipAddress.isEmpty || (homeViewModel.socketState != .connected && homeViewModel.socketState != .clientReady)
        return isDisabled ? .professionalTextSecondary.opacity(0.3) : .professionalSuccess
    }
}

// MARK: - Supporting Views

private struct KeypadButton {
    let number: String
    let letters: String
}

private struct KeypadButtonView: View {
    let keypadButton: KeypadButton
    let onTap: (String) -> Void
    
    var body: some View {
        Button(action: {
            onTap(keypadButton.number)
        }) {
            VStack(spacing: 2) {
                Text(keypadButton.number)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.professionalTextPrimary)
                
                if !keypadButton.letters.isEmpty {
                    Text(keypadButton.letters)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.professionalTextSecondary)
                        .tracking(1)
                }
            }
            .frame(width: 80, height: 80)
            .background(
                Circle()
                    .fill(Color.professionalSurface)
                    .shadow(color: .professionalButtonShadow, radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct ToggleButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isSelected ? .white : .professionalTextSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.professionalPrimary : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
struct ProfessionalDialerScreen_Previews: PreviewProvider {
    static var previews: some View {
        ProfessionalDialerScreen(
            callViewModel: CallViewModel(),
            homeViewModel: HomeViewModel(),
            onStartCall: {},
            onConnect: {},
            onDisconnect: {}
        )
    }
}