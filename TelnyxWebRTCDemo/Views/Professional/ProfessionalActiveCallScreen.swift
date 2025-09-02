import SwiftUI
import TelnyxRTC

struct ProfessionalActiveCallScreen: View {
    @ObservedObject var callViewModel: CallViewModel
    @State private var callDuration: TimeInterval = 0
    @State private var callTimer: Timer?
    @State private var showingMoreOptions = false
    
    let onEndCall: () -> Void
    let onMuteUnmuteSwitch: (Bool) -> Void
    let onToggleSpeaker: () -> Void
    let onHold: (Bool) -> Void
    let onDTMF: (String) -> Void
    
    var body: some View {
        ZStack {
            // Background gradient for professional look
            LinearGradient(
                gradient: Gradient(colors: [Color.professionalBackground, Color.professionalSurface]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header Section
                headerSection
                
                // MARK: - Contact Info Section
                contactInfoSection
                
                // MARK: - Call Status Section
                callStatusSection
                
                // MARK: - Audio Visualization Section
                audioVisualizationSection
                
                Spacer()
                
                // MARK: - Primary Call Controls
                primaryCallControlsSection
                
                // MARK: - Secondary Controls
                secondaryControlsSection
                
                // MARK: - End Call Button
                endCallSection
                
                Spacer(minLength: 40)
            }
        }
        .onAppear {
            startCallTimer()
        }
        .onDisappear {
            stopCallTimer()
        }
        .sheet(isPresented: $callViewModel.showDTMFKeyboard) {
            DTMFKeyboardView(
                viewModel: DTMFKeyboardViewModel(),
                onClose: { callViewModel.showDTMFKeyboard = false },
                onDTMF: { key in
                    onDTMF(key)
                }
            )
            .background(Color.professionalSurface)
        }
        .sheet(isPresented: $callViewModel.showCallMetricsPopup) {
            if let metrics = callViewModel.callQualityMetrics {
                CallQualityMetricsView(
                    metrics: metrics,
                    onClose: {
                        callViewModel.showCallMetricsPopup = false
                    }
                )
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Button(action: {
                // Minimize call (return to tab view)
                // This would be handled by dismissing the full screen cover
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.professionalTextSecondary)
                    .frame(width: 32, height: 32)
            }
            
            Spacer()
            
            Text("Telnyx Call")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.professionalTextSecondary)
            
            Spacer()
            
            Button(action: {
                showingMoreOptions.toggle()
            }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.professionalTextSecondary)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    // MARK: - Contact Info Section
    private var contactInfoSection: some View {
        VStack(spacing: 12) {
            // Contact avatar placeholder
            Circle()
                .fill(Color.professionalPrimary.opacity(0.1))
                .frame(width: 120, height: 120)
                .overlay(
                    Text(callViewModel.sipAddress.first?.uppercased() ?? "?")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundColor(.professionalPrimary)
                )
            
            // Contact name/number
            Text(callViewModel.sipAddress)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.professionalTextPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 24)
    }
    
    // MARK: - Call Status Section
    private var callStatusSection: some View {
        VStack(spacing: 8) {
            // Call state
            Text(callStateText)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(callStateColor)
            
            // Call duration
            if callDuration > 0 {
                Text(formatCallDuration(callDuration))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.professionalTextSecondary)
            }
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Audio Visualization Section
    private var audioVisualizationSection: some View {
        VStack(spacing: 12) {
            AudioWaveformView(
                audioLevels: callViewModel.inboundAudioLevels,
                barColor: .green,
                title: "Inbound Audio",
                minBarHeight: 3.0,
                maxBarHeight: 30.0
            )
            
            AudioWaveformView(
                audioLevels: callViewModel.outboundAudioLevels,
                barColor: .blue,
                title: "Outbound Audio", 
                minBarHeight: 3.0,
                maxBarHeight: 30.0
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.professionalSurface.opacity(0.6))
                .shadow(color: .professionalButtonShadow, radius: 2, x: 0, y: 1)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Primary Call Controls
    private var primaryCallControlsSection: some View {
        HStack(spacing: 32) {
            // Mute Button
            CallControlButton(
                icon: callViewModel.isMuted ? "mic.slash.fill" : "mic.fill",
                isActive: callViewModel.isMuted,
                activeColor: .professionalWarning,
                action: {
                    callViewModel.isMuted.toggle()
                    onMuteUnmuteSwitch(callViewModel.isMuted)
                }
            )
            .accessibilityIdentifier(AccessibilityIdentifiers.muteButton)
            
            // Speaker Button  
            CallControlButton(
                icon: callViewModel.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.fill",
                isActive: callViewModel.isSpeakerOn,
                activeColor: .professionalSuccess,
                action: {
                    callViewModel.isSpeakerOn.toggle()
                    onToggleSpeaker()
                }
            )
            .accessibilityIdentifier(AccessibilityIdentifiers.speakerButton)
            
            // Hold Button
            CallControlButton(
                icon: callViewModel.isOnHold ? "play.fill" : "pause.fill",
                isActive: callViewModel.isOnHold,
                activeColor: .professionalWarning,
                action: {
                    callViewModel.isOnHold.toggle()
                    onHold(callViewModel.isOnHold)
                }
            )
            .accessibilityIdentifier(AccessibilityIdentifiers.holdButton)
        }
        .padding(.vertical, 24)
    }
    
    // MARK: - Secondary Controls  
    private var secondaryControlsSection: some View {
        HStack(spacing: 48) {
            // DTMF Keypad
            Button(action: {
                callViewModel.showDTMFKeyboard.toggle()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "grid.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.professionalTextSecondary)
                    
                    Text("Keypad")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.professionalTextSecondary)
                }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.dtmfButton)
            
            // Call Metrics
            Button(action: {
                callViewModel.showCallMetricsPopup.toggle()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.professionalTextSecondary)
                    
                    Text("Stats")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.professionalTextSecondary)
                }
            }
            
            // More Options placeholder
            Button(action: {
                showingMoreOptions.toggle()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.professionalTextSecondary)
                    
                    Text("More")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.professionalTextSecondary)
                }
            }
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - End Call Section
    private var endCallSection: some View {
        Button(action: onEndCall) {
            Image(systemName: "phone.down.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .background(
                    Circle()
                        .fill(Color.professionalAlert)
                        .shadow(color: .professionalAlert.opacity(0.3), radius: 8, x: 0, y: 4)
                )
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.hangupButton)
        .padding(.vertical, 24)
    }
    
    // MARK: - Helper Functions
    private func startCallTimer() {
        callDuration = 0
        callTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            callDuration += 1
        }
    }
    
    private func stopCallTimer() {
        callTimer?.invalidate()
        callTimer = nil
    }
    
    private func formatCallDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var callStateText: String {
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
        case .DROPPED:
            return "Call Dropped"
        default:
            return "In Call"
        }
    }
    
    private var callStateColor: Color {
        switch callViewModel.callState {
        case .CONNECTING:
            return .professionalWarning
        case .RINGING:
            return .professionalPrimary
        case .ACTIVE:
            return .professionalSuccess
        case .HELD:
            return .professionalWarning
        case .RECONNECTING:
            return .professionalWarning
        case .DROPPED:
            return .professionalAlert
        default:
            return .professionalTextSecondary
        }
    }
}

// MARK: - Call Control Button
private struct CallControlButton: View {
    let icon: String
    let isActive: Bool
    let activeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(isActive ? .white : .professionalTextPrimary)
                .frame(width: 64, height: 64)
                .background(
                    Circle()
                        .fill(isActive ? activeColor : Color.professionalSurface)
                        .shadow(color: .professionalButtonShadow, radius: 4, x: 0, y: 2)
                )
        }
        .buttonStyle(ProfessionalButtonStyle(
            backgroundColor: isActive ? activeColor : .professionalSurface,
            foregroundColor: isActive ? .white : .professionalTextPrimary,
            size: 64
        ))
    }
}

// MARK: - Preview
struct ProfessionalActiveCallScreen_Previews: PreviewProvider {
    static var previews: some View {
        ProfessionalActiveCallScreen(
            callViewModel: CallViewModel(),
            onEndCall: {},
            onMuteUnmuteSwitch: { _ in },
            onToggleSpeaker: {},
            onHold: { _ in },
            onDTMF: { _ in }
        )
    }
}