import SwiftUI
import TelnyxRTC
import UIKit

// MARK: - Dialer Screen
// Clean, consistent keypad interface for making calls
struct DialerView: View {
    @ObservedObject var callViewModel: CallViewModel
    @ObservedObject var homeViewModel: HomeViewModel
    @State private var phoneNumber: String = ""
    @State private var showingBackspace = false
    
    let onStartCall: () -> Void
    let onConnect: () -> Void  
    let onDisconnect: () -> Void
    
    init(callViewModel: CallViewModel, homeViewModel: HomeViewModel, onStartCall: @escaping () -> Void, onConnect: @escaping () -> Void, onDisconnect: @escaping () -> Void) {
        NSLog("🔵 INIT: DialerView created with callbacks!")
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
        VStack(spacing: 0) {
            content
        }
        .premiumScreenContainer(topPadding: PremiumSpacing.xxl)
        .onAppear {
            phoneNumber = callViewModel.sipAddress
        }
    }
    
    private var content: some View {
        VStack(spacing: 0) {
            // Connection Status Banner
            if !isConnected {
                connectionStatusBanner
                    .padding(.bottom, PremiumSpacing.lg)
            }
            
            Spacer()
            
            // Phone Number Display
            phoneNumberDisplay
                .padding(.horizontal, PremiumSpacing.xl)
            
            Spacer()
            
            // Keypad
            keypadGrid
                .padding(.horizontal, PremiumSpacing.lg)
            
            Spacer().frame(height: PremiumSpacing.xxl)
            
            // Call Button
            callButton
                .padding(.horizontal, PremiumSpacing.lg)
            
            Spacer().frame(height: PremiumSpacing.xxl)
        }
    }
    
    // MARK: - Connection Status Banner
    private var connectionStatusBanner: some View {
        HStack {
            // Animated Status Indicator
            statusIndicator
            
            Text("Disconnected")
                .font(.premiumFonts.bodyMedium)
                .foregroundColor(Color.premiumColors.textSecondary)
            
            Spacer()
            
            connectButton
        }
        .premiumCardStyle(padding: PremiumSpacing.md)
        .padding(.horizontal, PremiumSpacing.lg)
    }
    
    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(Color.premiumColors.alert.opacity(0.3))
                .frame(width: 12, height: 12)
                .scaleEffect(1.2)
                .opacity(0.8)
            
            Circle()
                .fill(Color.premiumColors.alert)
                .frame(width: 8, height: 8)
        }
        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isConnected)
    }
    
    private var connectButton: some View {
        Button("Connect") {
            onConnect()
        }
        .font(.premiumFonts.bodyMedium)
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.white)
        .padding(.horizontal, PremiumSpacing.md)
        .padding(.vertical, PremiumSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.premiumColors.primary)
                .shadow(color: Color.premiumColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Phone Number Display
    private var phoneNumberDisplay: some View {
        VStack(spacing: PremiumSpacing.xl) {
            HStack {
                Text(phoneNumber.isEmpty ? "Enter phone number" : formatPhoneNumber(phoneNumber))
                    .font(.system(size: 38, weight: .ultraLight, design: .default))
                    .foregroundColor(phoneNumber.isEmpty ? Color.premiumColors.textSecondary : Color.premiumColors.textPrimary)
                    .tracking(phoneNumber.isEmpty ? 0.5 : 2.8)
                    .frame(minHeight: 52)
                    .animation(.easeInOut(duration: 0.3), value: phoneNumber.isEmpty)
                    .monospacedDigit()
                
                // Animated Backspace Button
                if !phoneNumber.isEmpty {
                    backspaceButton
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            // Animated Underline
            underlineIndicator
        }
    }
    
    private var backspaceButton: some View {
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
                .foregroundColor(Color.premiumColors.textSecondary)
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
    }
    
    private var underlineIndicator: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.premiumColors.primary,
                        Color.premiumColors.primaryLight,
                        Color.premiumColors.primary
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
    
    // MARK: - Keypad Grid
    private var keypadGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 26), count: 3), spacing: 22) {
            ForEach(0..<12) { index in
                let keypadData = getKeypadData(for: index)
                keypadButton(keypadData: keypadData)
            }
        }
    }
    
    private func keypadButton(keypadData: (key: String, letters: String)) -> some View {
        VStack(spacing: 5) {
            Text(keypadData.key)
                .font(.system(size: 34, weight: .light))
                .foregroundColor(Color.premiumColors.textPrimary)
            
            if !keypadData.letters.isEmpty {
                Text(keypadData.letters)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.premiumColors.textSecondary)
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
    
    // MARK: - Call Button
    private var callButton: some View {
        Button(action: {
            NSLog("🔵 STEP 0: BUTTON TAP DETECTED! Call button pressed!")
            handleCallAction()
        }) {
            HStack(spacing: 14) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 22, weight: .medium))
                Text("Call")
                    .font(.system(size: 20, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.premiumColors.success,
                                Color.premiumColors.success.opacity(0.9)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.premiumColors.success.opacity(0.4), radius: 15, x: 0, y: 8)
                    .shadow(color: Color.premiumColors.success.opacity(0.2), radius: 25, x: 0, y: 12)
            )
        }
        .disabled(phoneNumber.isEmpty || !isConnected)
        .animation(.easeInOut(duration: 0.3), value: phoneNumber.isEmpty)
    }
    
    // MARK: - Helper Methods
    private func handleKeypadTap(key: String) {
        print("🔢 KEYPAD TAP: Key '\(key)' pressed")
        withAnimation(.easeOut(duration: 0.2)) {
            phoneNumber += key
            callViewModel.sipAddress = phoneNumber
        }
        
        // Haptic feedback
        PremiumHaptics.shared.keypadTap()
    }
    
    private func handleLongPress0() {
        withAnimation(.easeOut(duration: 0.2)) {
            if phoneNumber.isEmpty {
                phoneNumber = "+"
            } else if phoneNumber.last == "0" {
                phoneNumber.removeLast()
                phoneNumber += "+"
            }
            callViewModel.sipAddress = phoneNumber
        }
        
        PremiumHaptics.shared.buttonPress()
    }
    
    private func handleCallAction() {
        NSLog("🔵 STEP 1: handleCallAction() called with phoneNumber: '\(phoneNumber)'")
        NSLog("🔵 STEP 1: callViewModel.sipAddress: '\(callViewModel.sipAddress)'")
        
        guard !phoneNumber.isEmpty else {
            NSLog("❌ ERROR: Phone number is empty, cannot make call")
            return
        }
        
        // Update the call model with the current phone number
        callViewModel.sipAddress = phoneNumber
        NSLog("🔵 STEP 2: Updated callViewModel.sipAddress to: '\(callViewModel.sipAddress)'")
        
        // Trigger the call
        NSLog("🔵 STEP 3: About to call onStartCall()")
        onStartCall()
        NSLog("🔵 STEP 4: onStartCall() completed successfully")
        
        // Success haptic feedback
        PremiumHaptics.shared.callStart()
        NSLog("🔵 STEP 5: UI phase completed successfully")
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

// MARK: - Preview
struct DialerView_Previews: PreviewProvider {
    static var previews: some View {
        DialerView(
            callViewModel: CallViewModel(),
            homeViewModel: HomeViewModel(),
            onStartCall: {},
            onConnect: {},
            onDisconnect: {}
        )
    }
}