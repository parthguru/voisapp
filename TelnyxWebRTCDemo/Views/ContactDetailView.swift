//
//  ContactDetailView.swift
//  TelnyxWebRTCDemo
//
//  Created by AI SWE Agent on 02/09/2025.
//  Copyright © 2025 Telnyx LLC. All rights reserved.
//

import SwiftUI

struct ContactDetailView: View {
    let contact: Contact
    let onCall: (String) -> Void
    let onEdit: (Contact) -> Void
    let onDelete: (Contact) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    
    private let contactsManager = ContactsManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Profile Header
                    ProfileHeaderView(contact: contact)
                    
                    // Action Buttons
                    ActionButtonsView(
                        contact: contact,
                        onCall: onCall
                    )
                    
                    // Contact Information
                    ContactInfoSection(contact: contact)
                    
                    Spacer()
                }
                .padding(.top, 32)
                .padding(.horizontal, 24)
            }
            .background(ProfessionalColors.professionalBackground.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(ProfessionalColors.professionalPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            onEdit(contact)
                        }) {
                            Label("Edit Contact", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive, action: {
                            showingDeleteAlert = true
                        }) {
                            Label("Delete Contact", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(ProfessionalColors.professionalPrimary)
                    }
                }
            }
        }
        .alert("Delete Contact", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete(contact)
            }
        } message: {
            Text("Are you sure you want to delete this contact? This action cannot be undone.")
        }
    }
}

// MARK: - Profile Header Component
struct ProfileHeaderView: View {
    let contact: Contact
    private let contactsManager = ContactsManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile Image
            ZStack {
                Circle()
                    .fill(contactsManager.avatarColor(for: contact.name ?? "Unknown"))
                    .frame(width: 120, height: 120)
                
                if let imageData = contact.profileImageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    Text(contactsManager.avatarInitials(for: contact.name ?? "Unknown"))
                        .font(.system(size: 48, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            
            // Contact Name
            Text(contact.name ?? "Unknown Contact")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(ProfessionalColors.textPrimary)
                .multilineTextAlignment(.center)
            
            // Phone Number
            Text(contactsManager.formatPhoneNumber(contact.phoneNumber ?? ""))
                .font(.system(size: 18))
                .foregroundColor(ProfessionalColors.textSecondary)
        }
    }
}

// MARK: - Action Buttons Component
struct ActionButtonsView: View {
    let contact: Contact
    let onCall: (String) -> Void
    
    var body: some View {
        HStack(spacing: 24) {
            // Call Button
            ActionButton(
                icon: "phone.fill",
                title: "Call",
                color: ProfessionalColors.professionalSuccess,
                action: {
                    if let phoneNumber = contact.phoneNumber {
                        onCall(phoneNumber)
                    }
                }
            )
            
            // Message Button (placeholder)
            ActionButton(
                icon: "message.fill",
                title: "Message",
                color: ProfessionalColors.professionalPrimary,
                action: {
                    // TODO: Implement messaging functionality
                }
            )
            
            // Video Call Button (placeholder)
            ActionButton(
                icon: "video.fill",
                title: "Video",
                color: ProfessionalColors.professionalPrimary,
                action: {
                    // TODO: Implement video call functionality
                }
            )
        }
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ProfessionalColors.textSecondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Contact Info Section
struct ContactInfoSection: View {
    let contact: Contact
    private let contactsManager = ContactsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            HStack {
                Text("Contact Info")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ProfessionalColors.textPrimary)
                
                Spacer()
            }
            .padding(.bottom, 16)
            
            // Contact Info Card
            VStack(spacing: 0) {
                ContactInfoRow(
                    icon: "phone.fill",
                    label: "Mobile",
                    value: contactsManager.formatPhoneNumber(contact.phoneNumber ?? ""),
                    isTopRow: true,
                    action: {
                        if let phoneNumber = contact.phoneNumber {
                            // Copy to clipboard or show options
                        }
                    }
                )
                
                Divider()
                    .padding(.leading, 44)
                
                ContactInfoRow(
                    icon: "calendar",
                    label: "Added",
                    value: formatDate(contact.createdDate),
                    isTopRow: false,
                    action: nil
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ProfessionalColors.professionalSurface)
                    .shadow(
                        color: .professionalButtonShadow,
                        radius: 4,
                        x: 0,
                        y: 2
                    )
            )
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct ContactInfoRow: View {
    let icon: String
    let label: String
    let value: String
    let isTopRow: Bool
    let action: (() -> Void)?
    
    var body: some View {
        Button(action: action ?? {}) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(ProfessionalColors.professionalPrimary.opacity(0.1))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ProfessionalColors.professionalPrimary)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(ProfessionalColors.textPrimary)
                    
                    Text(label)
                        .font(.system(size: 12))
                        .foregroundColor(ProfessionalColors.textSecondary)
                }
                
                Spacer()
                
                // Action indicator (only for actionable items)
                if action != nil {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundColor(ProfessionalColors.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(action == nil)
    }
}