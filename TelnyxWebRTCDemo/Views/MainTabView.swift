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