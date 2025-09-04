import SwiftUI
import TelnyxRTC
import CoreData

// MARK: - Call History Item Model
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

// MARK: - Recent Calls Screen
// Clean interface showing call history with search and redial functionality
struct RecentsView: View {
    let onRedial: (String) -> Void
    
    @State private var searchText = ""
    @State private var selectedCall: CallHistoryItem?
    @StateObject private var callHistoryDB = CallHistoryDatabase.shared
    
    // Real call history data from database
    private var callHistory: [CallHistoryItem] {
        return callHistoryDB.callHistory.map { entry in
            let phoneNumber = entry.phoneNumber ?? "Unknown"
            let name = (entry.callerName?.isEmpty == false ? entry.callerName! : "Unknown")
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
        VStack(spacing: 0) {
            content
        }
        .premiumScreenContainer(topPadding: PremiumSpacing.xxl)
    }
    
    private var content: some View {
        VStack(spacing: 0) {
            // Search Bar
            searchBarSection
                .padding(.horizontal, PremiumSpacing.lg)
                .padding(.bottom, PremiumSpacing.md)
            
            // Main Content
            if groupedCalls.isEmpty {
                emptyStateView
            } else {
                callHistoryContent
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBarSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.premiumColors.textSecondary)
            
            TextField("Search Contacts & Places", text: $searchText)
                .font(.premiumFonts.bodyLarge)
                .foregroundColor(Color.premiumColors.textPrimary)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.premiumColors.textSecondary)
                }
            }
        }
        .padding(.horizontal, PremiumSpacing.md)
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
    
    // MARK: - Call History Content
    private var callHistoryContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: PremiumSpacing.xl) {
                ForEach(groupedCalls.indices, id: \.self) { groupIndex in
                    let group = groupedCalls[groupIndex]
                    
                    VStack(spacing: PremiumSpacing.md) {
                        // Date Header
                        HStack {
                            Text(group.0)
                                .font(.system(size: 20, weight: .semibold, design: .default))
                                .foregroundColor(Color.premiumColors.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, PremiumSpacing.lg)
                        
                        // Call History Group
                        VStack(spacing: 0) {
                            ForEach(group.1.indices, id: \.self) { callIndex in
                                let call = group.1[callIndex]
                                callRowView(call: call, isLast: callIndex == group.1.count - 1)
                            }
                        }
                        .premiumCardStyle(padding: 0)
                        .padding(.horizontal, PremiumSpacing.lg)
                    }
                }
                
                Spacer().frame(height: 40)
            }
            .padding(.top, PremiumSpacing.sm)
        }
    }
    
    // MARK: - Call Row View
    private func callRowView(call: CallHistoryItem, isLast: Bool) -> some View {
        HStack(spacing: 14) {
            // Avatar with Call Type Indicator
            avatarView(call: call)
            
            // Call Details
            callDetailsView(call: call)
            
            Spacer()
            
            // Time and Actions
            actionsView(call: call)
        }
        .padding(.horizontal, PremiumSpacing.lg)
        .padding(.vertical, 14)
        .background(call.isMissed ? Color.premiumColors.alert.opacity(0.02) : Color.clear)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 0.5)
                .opacity(isLast ? 0 : 1),
            alignment: .bottom
        )
    }
    
    private func avatarView(call: CallHistoryItem) -> some View {
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
    }
    
    private func callDetailsView(call: CallHistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(call.name)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(call.isMissed ? Color.premiumColors.alert : Color.premiumColors.textPrimary)
                .lineLimit(1)
            
            HStack(spacing: 4) {
                Text(getCallTypeText(call: call))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.premiumColors.textSecondary)
                
                Text("•")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.premiumColors.textSecondary)
                
                Text("Mobile")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.premiumColors.textSecondary)
            }
            
            Text("Telnyx")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.premiumColors.primary)
        }
    }
    
    private func actionsView(call: CallHistoryItem) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(call.time)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.premiumColors.textSecondary)
            
            HStack(spacing: PremiumSpacing.sm) {
                // Info button
                Button(action: { selectedCall = call }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.premiumColors.textSecondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                
                // Call button
                Button(action: { 
                    onRedial(call.phoneNumber)
                    PremiumHaptics.shared.buttonPress()
                }) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
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
                        )
                }
                .shadow(color: Color.premiumColors.success.opacity(0.3), radius: 6, x: 0, y: 3)
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: PremiumSpacing.xl) {
            Spacer()
            
            Image(systemName: "clock")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Color.premiumColors.textSecondary.opacity(0.6))
            
            VStack(spacing: PremiumSpacing.sm) {
                Text("No Recent Calls")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(Color.premiumColors.textPrimary)
                
                Text("Your call history will appear here")
                    .font(.premiumFonts.bodyLarge)
                    .foregroundColor(Color.premiumColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Helper Methods
    private func generateAvatarColor(for name: String) -> Color {
        let colors = [
            Color.premiumColors.primary,
            Color.premiumColors.primaryLight,
            Color(red: 0.16, green: 0.50, blue: 0.73),
            Color(red: 0.20, green: 0.78, blue: 0.65),
            Color(red: 0.61, green: 0.35, blue: 0.71),
            Color(red: 0.85, green: 0.34, blue: 0.61)
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
        if call.isMissed { return Color.premiumColors.alert }
        return call.isIncoming ? Color.premiumColors.success : Color.premiumColors.primary
    }
    
    private func getCallTypeText(call: CallHistoryItem) -> String {
        if call.isMissed { return "Missed" }
        return call.isIncoming ? "Incoming" : "Outgoing"
    }
}

// MARK: - Preview
struct RecentsView_Previews: PreviewProvider {
    static var previews: some View {
        RecentsView(onRedial: { _ in })
    }
}