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
    @ObservedObject private var contactsManager = ContactsManager.shared
    @ObservedObject private var contactsDatabase = ContactsDatabase.shared
    
    @State private var searchText = ""
    @State private var showingAddContact = false
    @State private var selectedContact: Contact?
    @State private var showingContactDetail = false
    @State private var filteredContacts: [Contact] = []
    
    let onCall: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(text: $searchText, onSearchTextChanged: { text in
                    if text.isEmpty {
                        filteredContacts = contactsDatabase.contacts
                    } else {
                        contactsManager.searchContacts(searchText: text) { results in
                            filteredContacts = results
                        }
                    }
                })
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                if filteredContacts.isEmpty && !searchText.isEmpty {
                    // No search results
                    EmptySearchStateView()
                } else if contactsDatabase.contacts.isEmpty {
                    // No contacts at all
                    EmptyContactsStateView(onAddContact: {
                        showingAddContact = true
                    })
                } else {
                    // Contacts List
                    ContactsListView(
                        contacts: searchText.isEmpty ? contactsDatabase.contacts : filteredContacts,
                        onContactTapped: { contact in
                            selectedContact = contact
                            showingContactDetail = true
                        },
                        onCallContact: { contact in
                            onCall(contact.phoneNumber ?? "")
                        }
                    )
                }
                
                Spacer()
            }
            .background(ProfessionalColors.professionalBackground.ignoresSafeArea())
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddContact = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(ProfessionalColors.professionalPrimary)
                            .font(.system(size: 18, weight: .medium))
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddContact) {
            AddEditContactView(
                contact: nil,
                onSave: { name, phoneNumber, image in
                    contactsManager.createContact(name: name, phoneNumber: phoneNumber, profileImage: image) { success, _ in
                        if success {
                            print("Contact created successfully")
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
                        contactsManager.deleteContact(contactId: contact.contactId!) { success in
                            if success {
                                showingContactDetail = false
                            }
                        }
                    }
                )
            }
        }
        .onReceive(contactsDatabase.$contacts) { contacts in
            if searchText.isEmpty {
                filteredContacts = contacts
            }
        }
        .onAppear {
            contactsManager.refreshContacts()
            filteredContacts = contactsDatabase.contacts
        }
    }
}

// MARK: - Search Bar Component
struct SearchBar: View {
    @Binding var text: String
    let onSearchTextChanged: (String) -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ProfessionalColors.textSecondary)
                .font(.system(size: 16))
            
            TextField("Search Contacts & Places", text: $text)
                .font(.system(size: 16))
                .foregroundColor(ProfessionalColors.textPrimary)
                .onChange(of: text) { newValue in
                    onSearchTextChanged(newValue)
                }
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    onSearchTextChanged("")
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ProfessionalColors.textSecondary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Contacts List Component  
struct ContactsListView: View {
    let contacts: [Contact]
    let onContactTapped: (Contact) -> Void
    let onCallContact: (Contact) -> Void
    
    var groupedContacts: [(String, [Contact])] {
        let grouped = Dictionary(grouping: contacts) { contact in
            String(contact.name?.prefix(1).uppercased() ?? "?")
        }
        return grouped.sorted { $0.key < $1.key }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(groupedContacts, id: \.0) { section, sectionContacts in
                    // Section Header
                    SectionHeaderView(title: section)
                    
                    // Section Contacts
                    ForEach(sectionContacts, id: \.contactId) { contact in
                        ContactRowView(
                            contact: contact,
                            onTap: {
                                onContactTapped(contact)
                            },
                            onCall: {
                                onCallContact(contact)
                            }
                        )
                        
                        if contact.contactId != sectionContacts.last?.contactId {
                            Divider()
                                .padding(.leading, 72)
                        }
                    }
                    
                    if section != groupedContacts.last?.0 {
                        Spacer()
                            .frame(height: 16)
                    }
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Contact Row Component
struct ContactRowView: View {
    let contact: Contact
    let onTap: () -> Void
    let onCall: () -> Void
    
    private var contactsManager = ContactsManager.shared
    
    var body: some View {
        HStack(spacing: 16) {
            // Contact Avatar
            ContactAvatarView(contact: contact)
            
            // Contact Info
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name ?? "Unknown")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(ProfessionalColors.textPrimary)
                
                Text(contactsManager.formatPhoneNumber(contact.phoneNumber ?? ""))
                    .font(.system(size: 14))
                    .foregroundColor(ProfessionalColors.textSecondary)
            }
            
            Spacer()
            
            // Call Button
            Button(action: onCall) {
                Image(systemName: "phone")
                    .font(.system(size: 18))
                    .foregroundColor(ProfessionalColors.textSecondary)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Contact Avatar Component
struct ContactAvatarView: View {
    let contact: Contact
    private let contactsManager = ContactsManager.shared
    
    var body: some View {
        ZStack {
            Circle()
                .fill(contactsManager.avatarColor(for: contact.name ?? "Unknown"))
                .frame(width: 40, height: 40)
            
            if let imageData = contact.profileImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                Text(contactsManager.avatarInitials(for: contact.name ?? "Unknown"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Section Header Component
struct SectionHeaderView: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ProfessionalColors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            
            Spacer()
        }
        .background(ProfessionalColors.professionalBackground)
    }
}

// MARK: - Empty States
struct EmptyContactsStateView: View {
    let onAddContact: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "person.2.circle")
                .font(.system(size: 64))
                .foregroundColor(ProfessionalColors.textSecondary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No Contacts Yet")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(ProfessionalColors.textPrimary)
                
                Text("Add your first contact to get started")
                    .font(.system(size: 14))
                    .foregroundColor(ProfessionalColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: onAddContact) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add Contact")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(ProfessionalColors.professionalPrimary)
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

struct EmptySearchStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(ProfessionalColors.textSecondary.opacity(0.5))
            
            Text("No Results Found")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ProfessionalColors.textPrimary)
            
            Text("Try searching with a different name or number")
                .font(.system(size: 14))
                .foregroundColor(ProfessionalColors.textSecondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}