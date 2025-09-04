//
//  ProfessionalContactsScreen.swift
//  TelnyxWebRTCDemo
//
//  Created by AI SWE Agent on 02/09/2025.
//  Copyright © 2025 Telnyx LLC. All rights reserved.
//

import SwiftUI
import CoreData

struct ProfessionalContactsScreen: View {
    @ObservedObject private var contactsDatabase = ContactsDatabase.shared
    @State private var searchText = ""
    @State private var showingAddContact = false
    @State private var selectedContact: Contact?
    @State private var showingContactDetail = false
    @State private var filteredContacts: [Contact] = []
    @State private var showingClearAlert = false
    
    let onCall: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Header Section
                headerSection
                
                // MARK: - Search Section
                searchSection
                
                // MARK: - Contacts List
                contactsListSection
            }
            .background(Color.professionalBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .onReceive(contactsDatabase.$contacts) { _ in
                reloadFilteredContacts()
            }
            .onAppear {
                initFilteredContacts()
            }
            .alert("Clear All Contacts", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    clearAllContacts()
                }
            } message: {
                Text("This will permanently delete all contacts.")
            }
        }
        .sheet(isPresented: $showingAddContact) {
            AddEditContactView(
                contact: nil,
                onSave: { name, phoneNumber, image in
                    contactsDatabase.createContact(name: name, phoneNumber: phoneNumber, profileImageData: image) { success in
                        if success {
                            print("📞 CONTACT: Contact created successfully")
                        }
                    }
                },
                onCancel: {
                    showingAddContact = false
                }
            )
        }
        .sheet(isPresented: $showingContactDetail) {
            if let contact = selectedContact {
                ContactDetailView(
                    contact: contact,
                    onCall: { phoneNumber in
                        onCall(phoneNumber)
                        showingContactDetail = false
                    },
                    onEdit: { contact in
                        selectedContact = contact
                        showingContactDetail = false
                        showingAddContact = true
                    },
                    onDelete: { contact in
                        if let contactId = contact.contactId {
                            contactsDatabase.deleteContact(contactId: contactId) { success in
                                if success {
                                    showingContactDetail = false
                                }
                            }
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Text("Contacts")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.professionalTextPrimary)
            
            Spacer()
            
            HStack(spacing: 16) {
                // Clear contacts button
                Button(action: {
                    showingClearAlert = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.professionalTextSecondary)
                        .frame(width: 32, height: 32)
                }
                .disabled(contactsDatabase.contacts.isEmpty)
                
                // Add contact button
                Button(action: {
                    showingAddContact = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.professionalPrimary)
                                .shadow(color: .professionalButtonShadow, radius: 2, x: 0, y: 1)
                        )
                }
            }
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
                
                TextField("Search contacts", text: $searchText)
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
            reloadFilteredContacts()
        }
    }
    
    // MARK: - Contacts List Section
    private var contactsListSection: some View {
        Group {
            if filteredContacts.isEmpty {
                emptyStateView
            } else {
                contactsList
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "person.2.circle")
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
            
            if contactsDatabase.contacts.isEmpty {
                Button(action: {
                    showingAddContact = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Add Contact")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.professionalPrimary)
                            .shadow(color: .professionalButtonShadow, radius: 2, x: 0, y: 1)
                    )
                }
            }
            
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var contactsList: some View {
        List {
            ForEach(filteredContacts, id: \.contactId) { contact in
                ProfessionalContactRow(
                    contact: contact,
                    onCall: { phoneNumber in
                        onCall(phoneNumber)
                    },
                    onTap: { contact in
                        selectedContact = contact
                        showingContactDetail = true
                    }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .onDelete(perform: deleteContacts)
        }
        .listStyle(PlainListStyle())
        .background(Color.professionalBackground)
    }
    
    // MARK: - Helper Functions
    private func initFilteredContacts() {
        contactsDatabase.fetchAllContacts()
    }
    
    private func reloadFilteredContacts() {
        var contacts = contactsDatabase.contacts
        
        // Apply search
        if !searchText.isEmpty {
            contacts = contacts.filter { contact in
                (contact.name?.lowercased().contains(searchText.lowercased()) == true) ||
                (contact.phoneNumber?.lowercased().contains(searchText.lowercased()) == true)
            }
        }
        
        filteredContacts = contacts
    }
    
    private func deleteContacts(at offsets: IndexSet) {
        for index in offsets {
            let contact = filteredContacts[index]
            if let contactId = contact.contactId {
                contactsDatabase.deleteContact(contactId: contactId) { success in
                    print("📞 CONTACT: Contact \(success ? "deleted" : "failed to delete")")
                }
            }
        }
    }
    
    private func clearAllContacts() {
        for contact in contactsDatabase.contacts {
            if let contactId = contact.contactId {
                contactsDatabase.deleteContact(contactId: contactId) { _ in }
            }
        }
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

// MARK: - Professional Contact Row
private struct ProfessionalContactRow: View {
    let contact: Contact
    let onCall: (String) -> Void
    let onTap: (Contact) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Contact Avatar (matches call history style)
            contactAvatar
            
            // Contact Information (exactly matching call history layout)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(contact.name ?? "Unknown")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.professionalTextPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("Contact")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.professionalTextSecondary)
                }
                
                HStack {
                    Text(formatPhoneNumber(contact.phoneNumber ?? ""))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.professionalTextSecondary)
                        .lineLimit(1)
                    
                    Spacer()
                }
            }
            
            // Call Button (exactly matching call history style)
            Button(action: {
                onCall(contact.phoneNumber ?? "")
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
        .onTapGesture {
            onTap(contact)
        }
    }
    
    private var contactAvatar: some View {
        ZStack {
            Circle()
                .fill(avatarColor)
                .frame(width: 32, height: 32)
            
            if let imageData = contact.profileImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            } else {
                Text(avatarInitials)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }
    
    private var avatarColor: Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .indigo, .teal]
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
        // Basic phone number formatting - can be enhanced
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

// MARK: - Preview
struct ProfessionalContactsScreen_Previews: PreviewProvider {
    static var previews: some View {
        ProfessionalContactsScreen(
            onCall: { _ in }
        )
        .previewDisplayName("Professional Contacts")
    }
}