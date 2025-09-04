import SwiftUI
import TelnyxRTC

// MARK: - Settings Screen
// Clean interface for app settings and profile management
struct SettingsView: View {
    @ObservedObject var homeViewModel: HomeViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let onLongPressLogo: () -> Void
    let onAddProfile: () -> Void
    let onSwitchProfile: () -> Void
    
    private var isConnected: Bool {
        homeViewModel.socketState == .connected || homeViewModel.socketState == .clientReady
    }
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .premiumScreenContainer(topPadding: PremiumSpacing.xl)
    }
    
    private var content: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
                .padding(.horizontal, PremiumSpacing.lg)
                .padding(.bottom, PremiumSpacing.xxl)
            
            // Settings Options
            settingsContent
                .padding(.horizontal, PremiumSpacing.lg)
            
            Spacer()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color.premiumColors.textPrimary)
            
            Spacer()
        }
    }
    
    // MARK: - Settings Content
    private var settingsContent: some View {
        VStack(spacing: PremiumSpacing.lg) {
            // Connection Status Card
            connectionStatusCard
            
            // Profile Management Card
            profileManagementCard
            
            // Environment Info Card
            environmentInfoCard
        }
    }
    
    // MARK: - Connection Status Card
    private var connectionStatusCard: some View {
        VStack(spacing: PremiumSpacing.md) {
            // Header
            HStack {
                Image(systemName: "wifi")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color.premiumColors.primary)
                
                Text("Connection")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.premiumColors.textPrimary)
                
                Spacer()
                
                // Status Indicator
                statusIndicator
            }
            
            // Connection Button
            connectionButton
        }
        .premiumCardStyle(padding: PremiumSpacing.lg)
    }
    
    private var statusIndicator: some View {
        HStack(spacing: PremiumSpacing.sm) {
            Circle()
                .fill(isConnected ? Color.premiumColors.success : Color.premiumColors.alert)
                .frame(width: 8, height: 8)
            
            Text(isConnected ? "Connected" : "Disconnected")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isConnected ? Color.premiumColors.success : Color.premiumColors.alert)
        }
    }
    
    private var connectionButton: some View {
        Button(action: {
            if isConnected {
                onDisconnect()
            } else {
                onConnect()
            }
            PremiumHaptics.shared.buttonPress()
        }) {
            HStack {
                Image(systemName: isConnected ? "wifi.slash" : "wifi")
                    .font(.system(size: 16, weight: .medium))
                
                Text(isConnected ? "Disconnect" : "Connect")
                    .font(.premiumFonts.bodyLarge)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isConnected ? Color.premiumColors.alert : Color.premiumColors.success)
            )
        }
        .animation(.easeInOut(duration: 0.2), value: isConnected)
    }
    
    // MARK: - Profile Management Card
    private var profileManagementCard: some View {
        VStack(spacing: PremiumSpacing.md) {
            // Header
            HStack {
                Image(systemName: "person.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color.premiumColors.primary)
                
                Text("Profile Management")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.premiumColors.textPrimary)
                
                Spacer()
            }
            
            // Profile Actions
            VStack(spacing: PremiumSpacing.md) {
                profileActionButton(
                    icon: "plus.circle",
                    title: "Manage Profiles",
                    subtitle: "Add or switch SIP profiles",
                    action: onAddProfile
                )
                
                profileActionButton(
                    icon: "arrow.2.circlepath",
                    title: "Switch Profile", 
                    subtitle: "Change active profile",
                    action: onSwitchProfile
                )
            }
        }
        .premiumCardStyle(padding: PremiumSpacing.lg)
    }
    
    private func profileActionButton(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            PremiumHaptics.shared.buttonPress()
        }) {
            HStack(spacing: PremiumSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.premiumColors.primary)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.premiumColors.textPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color.premiumColors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.premiumColors.textSecondary)
            }
            .padding(.vertical, PremiumSpacing.sm)
            .padding(.horizontal, PremiumSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.premiumColors.backgroundSecondary)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Environment Info Card
    private var environmentInfoCard: some View {
        VStack(spacing: PremiumSpacing.md) {
            // Header
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color.premiumColors.primary)
                
                Text("Environment Info")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.premiumColors.textPrimary)
                
                Spacer()
            }
            
            // Environment Details
            VStack(spacing: PremiumSpacing.sm) {
                infoRow(label: "Environment", value: homeViewModel.environment)
                infoRow(label: "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                infoRow(label: "Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
            }
        }
        .premiumCardStyle(padding: PremiumSpacing.lg)
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.premiumColors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color.premiumColors.textPrimary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            homeViewModel: HomeViewModel(),
            profileViewModel: ProfileViewModel(),
            onConnect: {},
            onDisconnect: {},
            onLongPressLogo: {},
            onAddProfile: {},
            onSwitchProfile: {}
        )
    }
}