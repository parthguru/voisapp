import SwiftUI
import TelnyxRTC
import CoreData

// MARK: - Contacts Screen
// Clean interface for managing contacts with search, add, and delete functionality
struct ContactsView: View {
    @ObservedObject private var contactsDatabase = ContactsDatabase.shared
    @State private var searchText = ""
    @State private var showingAddContact = false
    @State private var filteredContacts: [Contact] = []
    @State private var showingClearAlert = false
    
    let onCall: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .premiumScreenContainer(topPadding: PremiumSpacing.xl)
        .onReceive(contactsDatabase.$contacts) { _ in
            reloadFilteredContacts()
        }
        .onAppear {
            contactsDatabase.fetchAllContacts()
        }
        .alert("Clear All Contacts", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearAllContacts()
            }
        } message: {
            Text("This will permanently delete all contacts.")
        }
        .sheet(isPresented: $showingAddContact) {
            AddContactSheet { name, phoneNumber in
                contactsDatabase.createContact(name: name, phoneNumber: phoneNumber) { success in
                    print("📞 CONTACTS: Contact \(success ? "created" : "failed to create")")
                }
                showingAddContact = false
            }
        }
    }
    
    private var content: some View {
        VStack(spacing: 0) {
            // Header Section
            headerSection
                .padding(.horizontal, PremiumSpacing.lg)
                .padding(.bottom, PremiumSpacing.md)
            
            // Search Bar
            searchBarSection
                .padding(.horizontal, PremiumSpacing.lg)
                .padding(.bottom, PremiumSpacing.md)
                .onChange(of: searchText) { _ in
                    reloadFilteredContacts()
                }
            
            // Main Content
            if filteredContacts.isEmpty {
                emptyStateView
            } else {
                contactsList
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Text("Contacts")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color.premiumColors.textPrimary)
            
            Spacer()
            
            HStack(spacing: 12) {
                // Clear All Button
                Button(action: {
                    showingClearAlert = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.premiumColors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.premiumColors.backgroundSecondary)
                        )
                }
                .disabled(contactsDatabase.contacts.isEmpty)
                
                // Add Contact Button
                Button(action: {
                    showingAddContact = true
                    PremiumHaptics.shared.buttonPress()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.premiumColors.primary)
                        )
                }
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBarSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.premiumColors.textSecondary)
            
            TextField("Search contacts", text: $searchText)
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
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.premiumColors.backgroundSecondary)
        )
    }
    
    // MARK: - Contacts List
    private var contactsList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(filteredContacts, id: \.contactId) { contact in
                    ContactRow(
                        contact: contact,
                        onCall: { phoneNumber in
                            onCall(phoneNumber)
                        },
                        onDelete: {
                            if let contactId = contact.contactId {
                                contactsDatabase.deleteContact(contactId: contactId) { success in
                                    print("📞 CONTACTS: Contact \(success ? "deleted" : "failed to delete")")
                                }
                            }
                        }
                    )
                }
                
                Spacer().frame(height: 40)
            }
            .premiumCardStyle(padding: 0)
            .padding(.horizontal, PremiumSpacing.lg)
            .padding(.top, PremiumSpacing.sm)
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: PremiumSpacing.lg) {
            Spacer()
            
            Image(systemName: "person.2.circle")
                .font(.system(size: 40, weight: .regular))
                .foregroundColor(Color.premiumColors.textSecondary)
            
            VStack(spacing: 6) {
                Text(emptyStateTitle)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color.premiumColors.textPrimary)
                
                Text(emptyStateMessage)
                    .font(.premiumFonts.bodyLarge)
                    .foregroundColor(Color.premiumColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            if contactsDatabase.contacts.isEmpty {
                Button(action: {
                    showingAddContact = true
                    PremiumHaptics.shared.buttonPress()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Add Contact")
                    }
                    .font(.premiumFonts.bodyLarge)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, PremiumSpacing.xl)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.premiumColors.primary)
                    )
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Helper Methods
    private func reloadFilteredContacts() {
        var contacts = contactsDatabase.contacts
        
        if !searchText.isEmpty {
            contacts = contacts.filter { contact in
                (contact.name?.lowercased().contains(searchText.lowercased()) == true) ||
                (contact.phoneNumber?.lowercased().contains(searchText.lowercased()) == true)
            }
        }
        
        filteredContacts = contacts
    }
    
    private func clearAllContacts() {
        for contact in contactsDatabase.contacts {
            if let contactId = contact.contactId {
                contactsDatabase.deleteContact(contactId: contactId) { _ in }
            }
        }
        PremiumHaptics.shared.success()
    }
    
    private var emptyStateTitle: String {
        if searchText.isEmpty {
            return contactsDatabase.contacts.isEmpty ? "No Contacts Yet" : "No Contacts"
        } else {
            return "No Search Results"
        }
    }
    
    private var emptyStateMessage: String {
        if searchText.isEmpty {
            return contactsDatabase.contacts.isEmpty ? "Add your first contact to get started" : "Your contacts will appear here"
        } else {
            return "Try adjusting your search terms"
        }
    }
}

// MARK: - Contact Row Component
struct ContactRow: View {
    let contact: Contact
    let onCall: (String) -> Void
    let onDelete: () -> Void
    @State private var showingActions = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            avatarView
            
            // Contact Details
            contactDetailsView
            
            Spacer()
            
            // Actions
            actionsView
        }
        .padding(.horizontal, PremiumSpacing.lg)
        .padding(.vertical, 14)
        .background(Color.premiumColors.surface)
        .confirmationDialog("Contact Actions", isPresented: $showingActions, titleVisibility: .visible) {
            Button("Call \(formatPhoneNumber(contact.phoneNumber ?? ""))") { 
                onCall(contact.phoneNumber ?? "")
            }
            Button("Delete Contact", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(avatarColor)
                .frame(width: 44, height: 44)
            
            if let imageData = contact.profileImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } else {
                Text(avatarInitials)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // Contact Type Indicator
            Circle()
                .fill(Color.premiumColors.backgroundTertiary)
                .frame(width: 16, height: 16)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color.premiumColors.textSecondary)
                )
                .offset(x: 16, y: 16)
        }
    }
    
    private var contactDetailsView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(contact.name ?? "Unknown Contact")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Color.premiumColors.textPrimary)
                .lineLimit(1)
            
            HStack(spacing: 4) {
                Text("Contact")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.premiumColors.textSecondary)
                
                Text("•")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.premiumColors.textSecondary)
                
                Text("Mobile")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.premiumColors.textSecondary)
            }
            
            Text(formatPhoneNumber(contact.phoneNumber ?? ""))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.premiumColors.primary)
                .lineLimit(1)
        }
    }
    
    private var actionsView: some View {
        HStack(spacing: PremiumSpacing.sm) {
            // Info button
            Button(action: { 
                showingActions.toggle()
                PremiumHaptics.shared.buttonPress()
            }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.premiumColors.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            
            // Call button
            Button(action: { 
                onCall(contact.phoneNumber ?? "")
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
    
    // MARK: - Helper Properties
    private var avatarColor: Color {
        let colors = [
            Color.premiumColors.primary,
            Color.premiumColors.primaryLight,
            Color(red: 0.16, green: 0.50, blue: 0.73),
            Color(red: 0.20, green: 0.78, blue: 0.65),
            Color(red: 0.61, green: 0.35, blue: 0.71),
            Color(red: 0.85, green: 0.34, blue: 0.61)
        ]
        let name = contact.name ?? "Unknown"
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
    
    private var avatarInitials: String {
        let name = contact.name ?? "Unknown"
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
    
    private func formatPhoneNumber(_ phoneNumber: String) -> String {
        let cleaned = phoneNumber.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        if cleaned.hasPrefix("+1") && cleaned.count == 12 {
            let index1 = cleaned.index(cleaned.startIndex, offsetBy: 2)
            let index2 = cleaned.index(cleaned.startIndex, offsetBy: 5)
            let index3 = cleaned.index(cleaned.startIndex, offsetBy: 8)
            return "+1 (\(cleaned[index1..<index2])) \(cleaned[index2..<index3])-\(cleaned[index3...])"
        }
        return phoneNumber
    }
}

// MARK: - Add Contact Sheet
struct AddContactSheet: View {
    let onSave: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var phoneNumber = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: PremiumSpacing.lg) {
                TextField("Name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Phone Number", text: $phoneNumber)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.phonePad)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if !name.isEmpty && !phoneNumber.isEmpty {
                            onSave(name.trimmingCharacters(in: .whitespaces), 
                                  phoneNumber.trimmingCharacters(in: .whitespaces))
                            PremiumHaptics.shared.success()
                        }
                    }
                    .disabled(name.isEmpty || phoneNumber.isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview
struct ContactsView_Previews: PreviewProvider {
    static var previews: some View {
        ContactsView(onCall: { _ in })
    }
}