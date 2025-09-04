//
//  ContactsDatabase.swift
//  TelnyxWebRTCDemo
//
//  Created by AI SWE Agent on 02/09/2025.
//  Copyright © 2025 Telnyx LLC. All rights reserved.
//

import Foundation
import CoreData
import Combine

class ContactsDatabase: ObservableObject {
    
    // Singleton instance for managing the database
    public static let shared = ContactsDatabase()
    
    // Publisher for contacts
    @Published public var contacts: [Contact] = []
    
    // Use the same persistent container as CallHistoryDatabase
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "AppModel")
        container.loadPersistentStores { (description, error) in
            if let error = error {
                print("❌ CONTACTS: Core Data failed to load: \(error)")
                fatalError("Core Data error: \(error)")
            }
            print("✅ CONTACTS: Core Data store loaded successfully: \(description.url?.absoluteString ?? "unknown")")
        }
        
        // Use same configuration as CallHistoryDatabase for consistency
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        return container
    }()
    
    // Use viewContext instead of background context for consistency with CallHistoryDatabase
    private lazy var context: NSManagedObjectContext = {
        return self.persistentContainer.viewContext
    }()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Create a new contact
    /// - Parameters:
    ///   - name: Contact's name
    ///   - phoneNumber: Contact's phone number
    ///   - profileImageData: Optional profile image data
    ///   - completion: Completion handler with success result
    public func createContact(name: String, phoneNumber: String, profileImageData: Data? = nil, completion: @escaping (Bool) -> Void) {
        
        // Check if contact with same phone number already exists
        let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "phoneNumber == %@", phoneNumber)
        
        // Use main thread like CallHistoryDatabase for consistency
        DispatchQueue.main.async {
            do {
                let existingContacts = try self.context.fetch(fetchRequest)
                
                if existingContacts.isEmpty {
                    // Create new contact
                    let contact = Contact(context: self.context)
                    contact.contactId = UUID()
                    contact.name = name
                    contact.phoneNumber = phoneNumber
                    contact.profileImageData = profileImageData
                    contact.createdDate = Date()
                    
                    // Save the context
                    try self.context.save()
                    print("📞 CONTACTS: Contact created successfully - \(name)")
                    
                    // Refresh the contacts list
                    self.fetchAllContacts()
                    
                    completion(true)
                } else {
                    print("📞 CONTACTS: Contact with phone number \(phoneNumber) already exists")
                    completion(false)
                }
            } catch {
                print("❌ CONTACTS: Failed to create contact: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    /// Update an existing contact
    /// - Parameters:
    ///   - contactId: Contact ID to update
    ///   - name: New name
    ///   - phoneNumber: New phone number
    ///   - profileImageData: New profile image data
    ///   - completion: Completion handler with success result
    public func updateContact(contactId: UUID, name: String? = nil, phoneNumber: String? = nil, profileImageData: Data? = nil, completion: @escaping (Bool) -> Void) {
        
        let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "contactId == %@", contactId as CVarArg)
        
        context.perform {
            do {
                let contacts = try self.context.fetch(fetchRequest)
                
                if let contact = contacts.first {
                    if let name = name {
                        contact.name = name
                    }
                    if let phoneNumber = phoneNumber {
                        contact.phoneNumber = phoneNumber
                    }
                    if let profileImageData = profileImageData {
                        contact.profileImageData = profileImageData
                    }
                    
                    // Save the changes
                    try self.context.save()
                    
                    // Refresh the contacts list
                    self.fetchAllContacts()
                    
                    completion(true)
                } else {
                    print("No contact found with contactId: \(contactId)")
                    completion(false)
                }
            } catch {
                print("Failed to update contact: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    /// Delete a contact
    /// - Parameters:
    ///   - contactId: Contact ID to delete
    ///   - completion: Completion handler with success result
    public func deleteContact(contactId: UUID, completion: @escaping (Bool) -> Void) {
        
        let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "contactId == %@", contactId as CVarArg)
        
        context.perform {
            do {
                let contacts = try self.context.fetch(fetchRequest)
                
                if let contact = contacts.first {
                    self.context.delete(contact)
                    try self.context.save()
                    
                    // Refresh the contacts list
                    self.fetchAllContacts()
                    
                    completion(true)
                } else {
                    print("No contact found with contactId: \(contactId)")
                    completion(false)
                }
            } catch {
                print("Failed to delete contact: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    /// Fetch all contacts
    public func fetchAllContacts() {
        let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
        
        // Sort by name alphabetically
        let sortDescriptor = NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.caseInsensitiveCompare))
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        // Use main thread like CallHistoryDatabase for consistency
        DispatchQueue.main.async {
            do {
                let fetchedContacts = try self.context.fetch(fetchRequest)
                self.contacts = fetchedContacts
                print("📞 CONTACTS: Fetched \(fetchedContacts.count) contacts")
            } catch {
                print("❌ CONTACTS: Failed to fetch contacts: \(error.localizedDescription)")
            }
        }
    }
    
    /// Search contacts by name or phone number
    /// - Parameter searchText: Text to search for
    /// - Returns: Array of matching contacts
    public func searchContacts(searchText: String, completion: @escaping ([Contact]) -> Void) {
        let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
        
        // Search in name or phone number
        let namePredicate = NSPredicate(format: "name CONTAINS[cd] %@", searchText)
        let phonePredicate = NSPredicate(format: "phoneNumber CONTAINS %@", searchText)
        fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [namePredicate, phonePredicate])
        
        // Sort by name alphabetically
        let sortDescriptor = NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.caseInsensitiveCompare))
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        context.perform {
            do {
                let results = try self.context.fetch(fetchRequest)
                DispatchQueue.main.async {
                    completion(results)
                }
            } catch {
                print("Failed to search contacts: \(error.localizedDescription)")
                completion([])
            }
        }
    }
    
    /// Find contact by phone number
    /// - Parameter phoneNumber: Phone number to search for
    /// - Returns: Contact if found, nil otherwise
    public func findContact(by phoneNumber: String, completion: @escaping (Contact?) -> Void) {
        let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "phoneNumber == %@", phoneNumber)
        fetchRequest.fetchLimit = 1
        
        context.perform {
            do {
                let results = try self.context.fetch(fetchRequest)
                DispatchQueue.main.async {
                    completion(results.first)
                }
            } catch {
                print("Failed to find contact by phone number: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
    
    /// Get contact by ID
    /// - Parameter contactId: Contact ID to fetch
    /// - Returns: Contact if found, nil otherwise
    public func getContact(by contactId: UUID, completion: @escaping (Contact?) -> Void) {
        let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "contactId == %@", contactId as CVarArg)
        fetchRequest.fetchLimit = 1
        
        context.perform {
            do {
                let results = try self.context.fetch(fetchRequest)
                DispatchQueue.main.async {
                    completion(results.first)
                }
            } catch {
                print("Failed to get contact by ID: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
}