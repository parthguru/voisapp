//
//  ContactsManager.swift
//  TelnyxWebRTCDemo
//
//  Created by AI SWE Agent on 02/09/2025.
//  Copyright © 2025 Telnyx LLC. All rights reserved.
//

import Foundation
import UIKit
import Contacts
import SwiftUI

/// Manager class to handle contacts operations and integration with the calling system
public class ContactsManager: ObservableObject {
    /// Shared singleton instance
    public static let shared = ContactsManager()
    
    /// Database instance
    private let database = ContactsDatabase.shared
    
    /// CNContactStore for system contacts access
    private let contactStore = CNContactStore()
    
    private init() {
        // Load contacts on initialization
        database.fetchAllContacts()
    }
    
    // MARK: - Public Properties
    
    /// Published contacts array from database
    @Published public var contacts: [Contact] = []
    
    // MARK: - Contact Management
    
    /// Create a new contact
    /// - Parameters:
    ///   - name: Contact name
    ///   - phoneNumber: Phone number
    ///   - profileImage: Optional profile image
    ///   - completion: Completion handler
    public func createContact(name: String, phoneNumber: String, profileImage: UIImage? = nil, completion: @escaping (Bool, Contact?) -> Void) {
        
        let normalizedNumber = normalizePhoneNumber(phoneNumber)
        let imageData = profileImage?.jpegData(compressionQuality: 0.8)
        
        database.createContact(name: name, phoneNumber: normalizedNumber, profileImageData: imageData) { [weak self] success in
            if success {
                // Find the newly created contact
                self?.database.findContact(by: normalizedNumber) { contact in
                    DispatchQueue.main.async {
                        completion(true, contact)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(false, nil)
                }
            }
        }
    }
    
    /// Update an existing contact
    /// - Parameters:
    ///   - contactId: Contact ID
    ///   - name: New name
    ///   - phoneNumber: New phone number
    ///   - profileImage: New profile image
    ///   - completion: Completion handler
    public func updateContact(contactId: UUID, name: String? = nil, phoneNumber: String? = nil, profileImage: UIImage? = nil, completion: @escaping (Bool) -> Void) {
        
        let normalizedNumber = phoneNumber != nil ? normalizePhoneNumber(phoneNumber!) : nil
        let imageData = profileImage?.jpegData(compressionQuality: 0.8)
        
        database.updateContact(contactId: contactId, name: name, phoneNumber: normalizedNumber, profileImageData: imageData) { success in
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
    
    /// Delete a contact
    /// - Parameters:
    ///   - contactId: Contact ID to delete
    ///   - completion: Completion handler
    public func deleteContact(contactId: UUID, completion: @escaping (Bool) -> Void) {
        database.deleteContact(contactId: contactId) { success in
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
    
    /// Search contacts
    /// - Parameters:
    ///   - searchText: Text to search for
    ///   - completion: Completion handler with results
    public func searchContacts(searchText: String, completion: @escaping ([Contact]) -> Void) {
        database.searchContacts(searchText: searchText) { results in
            completion(results)
        }
    }
    
    // MARK: - Contact Resolution
    
    /// Get contact name for a phone number
    /// - Parameter phoneNumber: Phone number to lookup
    /// - Returns: Contact name or nil if not found
    public func getContactName(for phoneNumber: String) -> String? {
        // For now, return nil - this will be filled in real-time as contacts are loaded
        // In a more advanced implementation, we could cache frequently accessed contacts
        return nil
    }
    
    /// Get contact for phone number asynchronously
    /// - Parameters:
    ///   - phoneNumber: Phone number to lookup
    ///   - completion: Completion handler with contact
    public func getContact(for phoneNumber: String, completion: @escaping (Contact?) -> Void) {
        let normalizedNumber = normalizePhoneNumber(phoneNumber)
        database.findContact(by: normalizedNumber, completion: completion)
    }
    
    /// Get contact by ID
    /// - Parameters:
    ///   - contactId: Contact ID
    ///   - completion: Completion handler with contact
    public func getContact(by contactId: UUID, completion: @escaping (Contact?) -> Void) {
        database.getContact(by: contactId, completion: completion)
    }
    
    // MARK: - Phone Number Normalization
    
    /// Normalize phone number for USA numbers (remove +1 prefix)
    /// - Parameter phoneNumber: Raw phone number
    /// - Returns: Normalized phone number
    private func normalizePhoneNumber(_ phoneNumber: String) -> String {
        // Remove all non-digit characters
        let cleanNumber = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Handle USA phone numbers - treat +1 and non-+1 as the same
        if cleanNumber.count == 11 && cleanNumber.hasPrefix("1") {
            // Remove leading 1 (e.g., 12345678900 -> 2345678900)
            return String(cleanNumber.dropFirst())
        } else if cleanNumber.count == 10 {
            // Already 10 digits, keep as is
            return cleanNumber
        } else {
            // Return as-is for other formats
            return cleanNumber
        }
    }
    
    // MARK: - Call Integration
    
    /// Create contact from call history entry
    /// - Parameters:
    ///   - phoneNumber: Phone number from call
    ///   - name: Optional name (from caller ID or user input)
    ///   - completion: Completion handler
    public func createContactFromCall(phoneNumber: String, name: String? = nil, completion: @escaping (Bool, Contact?) -> Void) {
        let contactName = name ?? "Unknown Contact"
        let normalizedNumber = normalizePhoneNumber(phoneNumber)
        createContact(name: contactName, phoneNumber: normalizedNumber, completion: completion)
    }
    
    /// Format phone number for display
    /// - Parameter phoneNumber: Raw phone number
    /// - Returns: Formatted phone number
    public func formatPhoneNumber(_ phoneNumber: String) -> String {
        // Simple formatting - remove non-numeric characters and format if US number
        let cleanNumber = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        if cleanNumber.count == 10 {
            let area = cleanNumber.prefix(3)
            let exchange = cleanNumber.dropFirst(3).prefix(3)
            let number = cleanNumber.suffix(4)
            return "(\(area)) \(exchange)-\(number)"
        } else if cleanNumber.count == 11 && cleanNumber.hasPrefix("1") {
            let area = cleanNumber.dropFirst(1).prefix(3)
            let exchange = cleanNumber.dropFirst(4).prefix(3)
            let number = cleanNumber.suffix(4)
            return "(\(area)) \(exchange)-\(number)"
        }
        
        return phoneNumber // Return original if can't format
    }
    
    // MARK: - Avatar Generation
    
    /// Generate avatar color for contact name
    /// - Parameter name: Contact name
    /// - Returns: Color for avatar background
    public func avatarColor(for name: String) -> Color {
        let colors: [Color] = [
            Color(hex: "#FF6B6B"), Color(hex: "#4ECDC4"), Color(hex: "#45B7D1"),
            Color(hex: "#96CEB4"), Color(hex: "#FECA57"), Color(hex: "#FF9FF3"),
            Color(hex: "#54A0FF"), Color(hex: "#5F27CD"), Color(hex: "#00D2D3"),
            Color(hex: "#FF9F43"), Color(hex: "#10AC84"), Color(hex: "#EE5A24")
        ]
        
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }
    
    /// Generate avatar initials from name
    /// - Parameter name: Contact name
    /// - Returns: Initials (up to 2 characters)
    public func avatarInitials(for name: String) -> String {
        let components = name.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces)
        
        if components.count >= 2 {
            let firstInitial = String(components[0].prefix(1)).uppercased()
            let lastInitial = String(components[1].prefix(1)).uppercased()
            return "\(firstInitial)\(lastInitial)"
        } else if let firstComponent = components.first, !firstComponent.isEmpty {
            return String(firstComponent.prefix(2)).uppercased()
        }
        
        return "?"
    }
    
    // MARK: - System Contacts Permission
    
    /// Check contacts authorization status
    /// - Returns: Authorization status
    public func contactsAuthorizationStatus() -> CNAuthorizationStatus {
        return CNContactStore.authorizationStatus(for: .contacts)
    }
    
    /// Request contacts access
    /// - Parameter completion: Completion handler with granted status
    public func requestContactsAccess(completion: @escaping (Bool) -> Void) {
        contactStore.requestAccess(for: .contacts) { granted, error in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    // MARK: - Refresh Data
    
    /// Refresh contacts from database
    public func refreshContacts() {
        database.fetchAllContacts()
    }
}

