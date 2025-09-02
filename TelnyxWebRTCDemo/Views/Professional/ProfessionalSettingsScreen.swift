import SwiftUI
import TelnyxRTC

struct ProfessionalSettingsScreen: View {
    @ObservedObject var homeViewModel: HomeViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    @State private var showingCredentials = false
    @State private var showingDebugInfo = false
    @State private var isShowingCredentialsInput = false
    
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let onLongPressLogo: () -> Void
    let onAddProfile: () -> Void
    let onSwitchProfile: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Header Section
                    headerSection
                    
                    // MARK: - Profile Section
                    profileSection
                    
                    // MARK: - Connection Section
                    connectionSection
                    
                    // MARK: - SIP Credentials Section
                    sipCredentialsSection
                    
                    // MARK: - Environment Section
                    environmentSection
                    
                    // MARK: - Debug Section (Expandable)
                    debugSection
                    
                    // MARK: - About Section
                    aboutSection
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
            .background(Color.professionalBackground.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingCredentials) {
            SipCredentialsView(
                isShowingCredentialsInput: $isShowingCredentialsInput,
                onCredentialSelected: { credential in
                    profileViewModel.refreshProfile()
                },
                onSignIn: { credential in
                    profileViewModel.refreshProfile()
                }
            )
        }
        .onAppear {
            profileViewModel.refreshProfile()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.professionalTextPrimary)
                
                Text("Telnyx WebRTC")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.professionalTextSecondary)
            }
            
            Spacer()
            
            Button(action: onLongPressLogo) {
                Image("telnyx-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
                    .opacity(0.8)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
    }
    
    // MARK: - Profile Section
    private var profileSection: some View {
        SettingsSection(title: "Profile", icon: "person.circle") {
            VStack(spacing: 16) {
                if let selectedProfile = profileViewModel.selectedProfile {
                    // Existing profile
                    HStack {
                        Circle()
                            .fill(Color.professionalPrimary.opacity(0.1))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Text(selectedProfile.username.prefix(1).uppercased())
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.professionalPrimary)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedProfile.username)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.professionalTextPrimary)
                            
                            if let callerName = selectedProfile.callerName {
                                Text(callerName)
                                    .font(.system(size: 14))
                                    .foregroundColor(.professionalTextSecondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: onSwitchProfile) {
                            Text("Switch")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.professionalPrimary)
                        }
                    }
                    .padding(.vertical, 8)
                } else {
                    // No profile
                    Button(action: onAddProfile) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.professionalPrimary)
                            
                            Text("Add Profile")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.professionalTextPrimary)
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }
    
    // MARK: - Connection Section
    private var connectionSection: some View {
        SettingsSection(title: "Connection", icon: "network") {
            VStack(spacing: 16) {
                // Connection Status
                HStack {
                    Circle()
                        .fill(connectionStatusColor)
                        .frame(width: 12, height: 12)
                    
                    Text(connectionStatusText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.professionalTextPrimary)
                    
                    Spacer()
                    
                    if homeViewModel.socketState == .disconnected {
                        Button(action: onConnect) {
                            Text("Connect")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Color.professionalSuccess)
                                .cornerRadius(16)
                        }
                    } else {
                        Button(action: onDisconnect) {
                            Text("Disconnect")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.professionalAlert)
                        }
                    }
                }
                
                // Session ID (if connected)
                if homeViewModel.socketState != .disconnected && !homeViewModel.sessionId.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Session ID")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.professionalTextSecondary)
                        
                        Text(homeViewModel.sessionId)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.professionalTextPrimary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                }
            }
        }
    }
    
    // MARK: - SIP Credentials Section
    private var sipCredentialsSection: some View {
        SettingsSection(title: "SIP Credentials", icon: "key") {
            VStack(spacing: 12) {
                Button(action: {
                    showingCredentials = true
                }) {
                    HStack {
                        Image(systemName: "person.badge.key")
                            .font(.system(size: 18))
                            .foregroundColor(.professionalPrimary)
                        
                        Text("Manage Credentials")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.professionalTextPrimary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.professionalTextSecondary)
                    }
                    .padding(.vertical, 8)
                }
                
                Text("Add, edit, and manage your SIP authentication credentials")
                    .font(.system(size: 14))
                    .foregroundColor(.professionalTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    // MARK: - Environment Section
    private var environmentSection: some View {
        SettingsSection(title: "Environment", icon: "globe") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Current Environment")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.professionalTextSecondary)
                    
                    Spacer()
                    
                    Text(homeViewModel.environment)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.professionalPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.professionalPrimary.opacity(0.1))
                        )
                }
                
                Text("WebRTC server environment configuration")
                    .font(.system(size: 12))
                    .foregroundColor(.professionalTextSecondary)
            }
        }
    }
    
    // MARK: - Debug Section
    private var debugSection: some View {
        SettingsSection(title: "Developer", icon: "hammer") {
            VStack(spacing: 12) {
                Button(action: {
                    showingDebugInfo.toggle()
                }) {
                    HStack {
                        Image(systemName: showingDebugInfo ? "chevron.down" : "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.professionalTextSecondary)
                        
                        Text("Debug Information")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.professionalTextPrimary)
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                
                if showingDebugInfo {
                    VStack(alignment: .leading, spacing: 8) {
                        debugInfoRow(label: "Call State", value: callStateText)
                        debugInfoRow(label: "Socket State", value: socketStateText)
                        debugInfoRow(label: "Session ID", value: homeViewModel.sessionId.isEmpty ? "None" : homeViewModel.sessionId)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
    
    // MARK: - About Section
    private var aboutSection: some View {
        SettingsSection(title: "About", icon: "info.circle") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Version")
                        .font(.system(size: 14))
                        .foregroundColor(.professionalTextSecondary)
                    
                    Spacer()
                    
                    Text("2.1.0") // This should be dynamic
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.professionalTextPrimary)
                }
                
                HStack {
                    Text("Build")
                        .font(.system(size: 14))
                        .foregroundColor(.professionalTextSecondary)
                    
                    Spacer()
                    
                    Text("Professional")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.professionalTextPrimary)
                }
            }
        }
    }
    
    // MARK: - Helper Views
    private func debugInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.professionalTextSecondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.professionalTextPrimary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Helper Properties
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
    
    private var callStateText: String {
        switch homeViewModel.callState {
        case .NEW:
            return "New"
        case .CONNECTING:
            return "Connecting"
        case .RINGING:
            return "Ringing"
        case .ACTIVE:
            return "Active"
        case .HELD:
            return "Held"
        case .DONE:
            return "Done"
        case .DROPPED:
            return "Dropped"
        case .RECONNECTING:
            return "Reconnecting"
        }
    }
    
    private var socketStateText: String {
        switch homeViewModel.socketState {
        case .connected:
            return "Connected"
        case .clientReady:
            return "Client Ready"
        case .disconnected:
            return "Disconnected"
        }
    }
}

// MARK: - Settings Section
private struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.professionalPrimary)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.professionalTextPrimary)
            }
            
            content
        }
        .professionalCardStyle(padding: 20)
    }
}

// MARK: - Preview
struct ProfessionalSettingsScreen_Previews: PreviewProvider {
    static var previews: some View {
        ProfessionalSettingsScreen(
            homeViewModel: HomeViewModel(),
            profileViewModel: ProfileViewModel(),
            onConnect: {},
            onDisconnect: {},
            onLongPressLogo: {},
            onAddProfile: {},
            onSwitchProfile: {}
        )
        .previewDisplayName("Settings")
    }
}