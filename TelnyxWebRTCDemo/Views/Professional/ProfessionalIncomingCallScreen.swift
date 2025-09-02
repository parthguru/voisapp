import SwiftUI
import TelnyxRTC

struct ProfessionalIncomingCallScreen: View {
    @ObservedObject var callViewModel: CallViewModel
    @State private var isAnimating = false
    @State private var pulseAnimation = false
    
    let onAnswerCall: () -> Void
    let onRejectCall: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background with subtle gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.professionalPrimary.opacity(0.05),
                        Color.professionalBackground
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - Header Section
                    headerSection
                    
                    Spacer()
                    
                    // MARK: - Incoming Call Animation
                    incomingCallAnimation
                    
                    // MARK: - Caller Info Section
                    callerInfoSection
                    
                    Spacer()
                    
                    // MARK: - Quick Actions
                    quickActionsSection
                    
                    // MARK: - Call Action Buttons
                    callActionButtonsSection
                    
                    Spacer(minLength: 60)
                }
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Text("Incoming Call")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.professionalTextSecondary)
            
            Spacer()
            
            Text("Telnyx")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.professionalTextSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    // MARK: - Incoming Call Animation
    private var incomingCallAnimation: some View {
        ZStack {
            // Pulse rings
            ForEach(0..<3) { index in
                Circle()
                    .stroke(Color.professionalSuccess.opacity(0.3), lineWidth: 2)
                    .frame(width: 200 + CGFloat(index * 40), height: 200 + CGFloat(index * 40))
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .opacity(pulseAnimation ? 0.0 : 0.7)
                    .animation(
                        Animation.easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.3),
                        value: pulseAnimation
                    )
            }
            
            // Center avatar
            callerAvatar
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Caller Avatar
    private var callerAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.professionalPrimary.opacity(0.8),
                        Color.professionalPrimary
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 160, height: 160)
            .overlay(
                Text(callerInitials)
                    .font(.system(size: 64, weight: .medium))
                    .foregroundColor(.white)
            )
            .shadow(color: .professionalPrimary.opacity(0.3), radius: 20, x: 0, y: 8)
            .scaleEffect(isAnimating ? 1.05 : 1.0)
            .animation(
                Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                value: isAnimating
            )
    }
    
    // MARK: - Caller Info Section
    private var callerInfoSection: some View {
        VStack(spacing: 12) {
            // Caller name/number
            Text(displayCallerName)
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(.professionalTextPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 40)
            
            // Secondary info (if different from name)
            if !displayCallerSecondary.isEmpty {
                Text(displayCallerSecondary)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.professionalTextSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Call type indicator
            HStack(spacing: 8) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.professionalSuccess)
                
                Text("Telnyx Voice Call")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.professionalTextSecondary)
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 24)
    }
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        HStack(spacing: 48) {
            // Message
            QuickActionButton(
                icon: "message.fill",
                label: "Message",
                action: {
                    // Quick message functionality
                }
            )
            
            // Remind
            QuickActionButton(
                icon: "bell.fill",
                label: "Remind",
                action: {
                    // Set reminder functionality
                }
            )
            
            // Contact
            QuickActionButton(
                icon: "person.fill",
                label: "Contact",
                action: {
                    // Contact info functionality
                }
            )
        }
        .padding(.vertical, 24)
    }
    
    // MARK: - Call Action Buttons
    private var callActionButtonsSection: some View {
        HStack(spacing: 80) {
            // Decline Button
            CallActionButton(
                icon: "phone.down.fill",
                backgroundColor: .professionalAlert,
                size: 80,
                action: onRejectCall
            )
            .accessibilityIdentifier(AccessibilityIdentifiers.rejectButton)
            .accessibilityLabel("Decline call")
            
            // Answer Button
            CallActionButton(
                icon: "phone.fill", 
                backgroundColor: .professionalSuccess,
                size: 80,
                action: onAnswerCall
            )
            .accessibilityIdentifier(AccessibilityIdentifiers.answerButton)
            .accessibilityLabel("Answer call")
        }
        .padding(.vertical, 32)
    }
    
    // MARK: - Helper Functions
    private func startAnimations() {
        isAnimating = true
        pulseAnimation = true
    }
    
    private var callerInitials: String {
        let caller = callViewModel.sipAddress.isEmpty ? "Unknown" : callViewModel.sipAddress
        let components = caller.components(separatedBy: .whitespacesAndNewlines)
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        } else {
            return String(caller.prefix(2)).uppercased()
        }
    }
    
    private var displayCallerName: String {
        if callViewModel.sipAddress.isEmpty {
            return "Unknown Caller"
        }
        return callViewModel.sipAddress
    }
    
    private var displayCallerSecondary: String {
        // If we have a caller name different from number, show the number here
        // For now, this will be empty as we're using sipAddress for display
        return ""
    }
}

// MARK: - Quick Action Button
private struct QuickActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.professionalTextSecondary)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(Color.professionalSurface.opacity(0.8))
                            .shadow(color: .professionalButtonShadow, radius: 4, x: 0, y: 2)
                    )
                
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.professionalTextSecondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Call Action Button
private struct CallActionButton: View {
    let icon: String
    let backgroundColor: Color
    let size: CGFloat
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.35, weight: .bold))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(backgroundColor)
                        .shadow(
                            color: backgroundColor.opacity(0.4),
                            radius: isPressed ? 4 : 12,
                            x: 0,
                            y: isPressed ? 2 : 6
                        )
                )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, perform: {}, onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        })
    }
}

// MARK: - Preview
struct ProfessionalIncomingCallScreen_Previews: PreviewProvider {
    static var previews: some View {
        ProfessionalIncomingCallScreen(
            callViewModel: CallViewModel(),
            onAnswerCall: {},
            onRejectCall: {}
        )
        .previewDisplayName("Incoming Call")
    }
}