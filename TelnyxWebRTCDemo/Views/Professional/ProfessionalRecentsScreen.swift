import SwiftUI
import TelnyxRTC

struct ProfessionalRecentsScreen: View {
    @StateObject private var database = CallHistoryDatabase.shared
    @State private var searchText = ""
    @State private var showingClearAlert = false
    @State private var filteredHistory: [CallHistoryEntry] = []
    @State private var selectedFilter: CallFilter = .all
    
    let onRedial: (String) -> Void
    
    private enum CallFilter: String, CaseIterable {
        case all = "All"
        case missed = "Missed" 
        case outgoing = "Outgoing"
        case incoming = "Incoming"
        
        var icon: String {
            switch self {
            case .all: return "phone"
            case .missed: return "phone.down"
            case .outgoing: return "phone.arrow.up.right"
            case .incoming: return "phone.arrow.down.left"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Header Section
                headerSection
                
                // MARK: - DEBUG PANEL (Temporary)
                debugPanel
                
                // MARK: - Search Section
                searchSection
                
                // MARK: - Filter Section
                filterSection
                
                // MARK: - Call History List
                callHistoryListSection
            }
            .background(Color.professionalBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .onReceive(database.$callHistory) { _ in
                reloadFilteredHistory()
            }
            .onAppear {
                initFilteredHistory()
            }
            .alert("Clear Call History", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    database.clearCallHistory(for: "default")
                }
            } message: {
                Text("This will permanently delete all call history for this profile.")
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Text("Recents")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.professionalTextPrimary)
            
            Spacer()
            
            // Clear history button
            Button(action: {
                showingClearAlert = true
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.professionalTextSecondary)
                    .frame(width: 32, height: 32)
            }
            .disabled(filteredHistory.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.top, 5)  // Reduced from 10 to 5 for Dynamic Island
        .padding(.bottom, 8)  // Reduced from 16 to 8
    }
    
    // MARK: - Search Section
    private var searchSection: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.professionalTextSecondary)
                
                TextField("Search calls", text: $searchText)
                    .font(.system(size: 16))
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.professionalTextSecondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)  // Reduced from 8 to 6 to make search bar smaller
            .background(
                RoundedRectangle(cornerRadius: 8)  // Reduced from 10 to 8 for smaller appearance
                    .fill(Color.professionalSurface)
                    .shadow(color: .professionalButtonShadow, radius: 1, x: 0, y: 1)
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 35)  // INCREASED: 20-30px top padding for Dynamic Island spacing
        .padding(.bottom, 20)  // Increased from 16 to 20 for better spacing
        .onChange(of: searchText) { _ in
            reloadFilteredHistory()
        }
    }
    
    // MARK: - Filter Section
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CallFilter.allCases, id: \.self) { filter in
                    FilterButton(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        action: {
                            selectedFilter = filter
                            reloadFilteredHistory()
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 16)
    }
    
    // MARK: - Call History List Section
    private var callHistoryListSection: some View {
        Group {
            if filteredHistory.isEmpty {
                emptyStateView
            } else {
                callHistoryList
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: selectedFilter == .missed ? "phone.down.circle" : "phone.circle")
                .font(.system(size: 80, weight: .thin))
                .foregroundColor(.professionalTextSecondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.professionalTextPrimary)
                
                Text(emptyStateMessage)
                    .font(.system(size: 16))
                    .foregroundColor(.professionalTextSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var callHistoryList: some View {
        List {
            ForEach(filteredHistory, id: \.callId) { entry in
                ProfessionalCallHistoryRow(
                    entry: entry,
                    onRedial: { phoneNumber in
                        onRedial(phoneNumber)
                    }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .onDelete(perform: deleteEntries)
        }
        .listStyle(PlainListStyle())
        .background(Color.professionalBackground)
    }
    
    // MARK: - Helper Functions
    private func initFilteredHistory() {
        database.fetchCallHistoryFiltered(by: "default")
    }
    
    private func reloadFilteredHistory() {
        var history = database.callHistory
        
        // Apply filter
        switch selectedFilter {
        case .all:
            break // Show all
        case .missed:
            history = history.filter { $0.callStatus == "missed" }
        case .outgoing:
            history = history.filter { !$0.isIncoming }
        case .incoming:
            history = history.filter { $0.isIncoming }
        }
        
        // Apply search
        if !searchText.isEmpty {
            history = history.filter { entry in
                (entry.callerName?.lowercased().contains(searchText.lowercased()) == true) ||
                (entry.phoneNumber?.lowercased().contains(searchText.lowercased()) == true)
            }
        }
        
        filteredHistory = history
    }
    
    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            let entry = filteredHistory[index]
            database.deleteCallHistoryEntry(
                callId: entry.callId ?? UUID(),
                profileId: "default"
            )
        }
    }
    
    private var emptyStateTitle: String {
        switch selectedFilter {
        case .all:
            return searchText.isEmpty ? "No Recent Calls" : "No Search Results"
        case .missed:
            return "No Missed Calls"
        case .outgoing:
            return "No Outgoing Calls"
        case .incoming:
            return "No Incoming Calls"
        }
    }
    
    private var emptyStateMessage: String {
        switch selectedFilter {
        case .all:
            return searchText.isEmpty ? "Your recent calls will appear here" : "Try adjusting your search terms"
        case .missed:
            return "Missed calls will appear here"
        case .outgoing:
            return "Outgoing calls will appear here"
        case .incoming:
            return "Incoming calls will appear here"
        }
    }
}

// MARK: - Filter Button
private struct FilterButton: View {
    let filter: ProfessionalRecentsScreen.CallFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 14, weight: .medium))
                
                Text(filter.rawValue)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .professionalTextSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.professionalPrimary : Color.professionalSurface)
                    .shadow(color: .professionalButtonShadow, radius: isSelected ? 2 : 1, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Professional Call History Row
private struct ProfessionalCallHistoryRow: View {
    let entry: CallHistoryEntry
    let onRedial: (String) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Call Direction Icon
            callDirectionIcon
            
            // Call Information
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.callerName ?? entry.phoneNumber ?? "Unknown")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.professionalTextPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(entry.formattedTimestamp)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.professionalTextSecondary)
                }
                
                HStack {
                    if entry.callerName != nil, let phoneNumber = entry.phoneNumber {
                        Text(phoneNumber)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.professionalTextSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    if entry.duration > 0 {
                        Text(entry.formattedDuration)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.professionalTextSecondary)
                    }
                }
                
                // Call Status
                if let status = entry.callStatus {
                    Text(status.capitalized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(statusColor)
                }
            }
            
            // Redial Button
            Button(action: {
                onRedial(entry.phoneNumber ?? "")
            }) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.professionalSuccess)
                            .shadow(color: .professionalButtonShadow, radius: 2, x: 0, y: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.professionalSurface)
                .shadow(color: .professionalButtonShadow, radius: 1, x: 0, y: 1)
        )
    }
    
    private var callDirectionIcon: some View {
        Image(systemName: entry.isIncoming ? "phone.arrow.down.left.fill" : "phone.arrow.up.right.fill")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(entry.isIncoming ? .professionalPrimary : .professionalSuccess)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill((entry.isIncoming ? Color.professionalPrimary : Color.professionalSuccess).opacity(0.1))
            )
    }
    
    private var statusColor: Color {
        switch entry.callStatus {
        case "answered":
            return .professionalSuccess
        case "missed":
            return .professionalAlert
        case "rejected":
            return .professionalWarning
        case "failed":
            return .professionalAlert
        case "cancelled":
            return .professionalTextSecondary
        default:
            return .professionalTextSecondary
        }
    }
}

extension ProfessionalRecentsScreen {
    // MARK: - Debug Panel (Temporary)
    private var debugPanel: some View {
        VStack(spacing: 4) {
            Text("🔧 DEBUG INFO")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.orange)
            
            HStack {
                Text("📞 Call History Count: \(database.callHistory.count)")
                    .font(.system(size: 11))
                    .foregroundColor(.professionalTextSecondary)
                Spacer()
            }
            
            HStack {
                Text("📱 Filtered Count: \(filteredHistory.count)")
                    .font(.system(size: 11))
                    .foregroundColor(.professionalTextSecondary)
                Spacer()
            }
            
            Button("🔄 Force Refresh") {
                database.fetchCallHistoryFiltered(by: "default")
            }
            .font(.system(size: 11))
            .foregroundColor(.blue)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.yellow.opacity(0.1))
    }
}

// MARK: - Preview
struct ProfessionalRecentsScreen_Previews: PreviewProvider {
    static var previews: some View {
        ProfessionalRecentsScreen(
            onRedial: { _ in }
        )
        .previewDisplayName("Call History")
    }
}