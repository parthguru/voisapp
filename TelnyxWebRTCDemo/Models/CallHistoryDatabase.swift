import Foundation
import CoreData
import Combine

class CallHistoryDatabase: ObservableObject {
    
    // Singleton instance for managing the database
    public static let shared = CallHistoryDatabase()
    
    // Publisher for call history
    @Published public var callHistory: [CallHistoryEntry] = []
    
    // Track if Core Data is fully initialized
    private var isInitialized = false
    
    // Create the persistent container here
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "AppModel")
        
        // 🔧 FIX: Ensure persistent storage (not in-memory)
        container.loadPersistentStores { (description, error) in
            if let error = error {
                print("❌ CRITICAL: Core Data failed to load: \(error)")
                fatalError("Core Data error: \(error)")
            }
            print("✅ Core Data store loaded successfully: \(description.url?.absoluteString ?? "unknown")")
            DispatchQueue.main.async {
                self.isInitialized = true
            }
        }
        
        // 🔧 FIX: Enable automatic merging for persistence
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        return container
    }()
    
    // 🔧 FIX: Use viewContext (main context) for proper persistence
    private lazy var context: NSManagedObjectContext = {
        return self.persistentContainer.viewContext
    }()
    
    // Maximum number of call history entries per profile
    private let maxHistoryCount = 100
    
    // 🔧 FIX: Ensure Core Data initialization before any operations
    public func initializeCoreData() {
        // Access persistentContainer to trigger lazy initialization
        _ = self.persistentContainer
        _ = self.context
        print("🔧 CORE DATA: Initialization triggered")
    }
    
    // Function to add a new call history entry
    func createCallHistoryEntry(callerName: String, callId: UUID, callStatus: String, direction: String, metadata: String, phoneNumber: String, profileId: String, timestamp: Date, completion: @escaping (Bool) -> Void) {
        
        let fetchRequest: NSFetchRequest<CallHistoryEntry> = CallHistoryEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "callId == %@", callId as CVarArg)
        
        // 🔧 FIX: Use main thread for viewContext operations
        DispatchQueue.main.async {
            do {
                let existingRecords = try self.context.fetch(fetchRequest)
                
                if existingRecords.isEmpty {
                    // Create a new entry if it doesn't exist
                    let callHistoryEntry = CallHistoryEntry(context: self.context)
                    callHistoryEntry.callerName = callerName
                    callHistoryEntry.callId = callId
                    callHistoryEntry.callStatus = callStatus
                    callHistoryEntry.direction = direction
                    callHistoryEntry.metadata = metadata
                    callHistoryEntry.phoneNumber = phoneNumber
                    callHistoryEntry.profileId = profileId
                    callHistoryEntry.timestamp = timestamp
                    
                    // 🔧 FIX: Save with error handling and ensure persistence
                    try self.context.save()
                    print("📞 CALL HISTORY: Entry saved successfully - \(phoneNumber)")
                    
                    // Refresh the call history on main thread
                    self.fetchCallHistoryFiltered(by: profileId)
                    
                    completion(true)
                } else {
                    print("📞 CALL HISTORY: Entry already exists for callId: \(callId)")
                    completion(false)
                }
            } catch {
                print("❌ CALL HISTORY: Failed to save entry: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    
    // Function to fetch filtered call history by profileId
    func fetchCallHistoryFiltered(by profileId: String){
        // 🔧 FIX: Ensure Core Data is initialized before fetching
        self.initializeCoreData()
        
        let fetchRequest: NSFetchRequest<CallHistoryEntry> = CallHistoryEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "profileId == %@", profileId)
        
        var filteredEntries: [CallHistoryEntry] = []
        
        // 🔧 FIX: Wait for initialization then fetch on main thread
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            do {
                filteredEntries = try self.context.fetch(fetchRequest)
                self.callHistory = filteredEntries  // Update the @Published callHistory property
                print("📞 CALL HISTORY: Fetched \(filteredEntries.count) entries for profile: \(profileId) (initialized: \(self.isInitialized))")
            } catch {
                print("❌ CALL HISTORY: Failed to fetch entries: \(error.localizedDescription)")
            }
        }
        
    }
    
    // Function to update a call history entry's duration or status by callId
    public func updateCallHistoryEntry(callId: UUID, duration: Int32? = nil, status: CallStatus? = nil, completion: @escaping (Bool) -> Void) {
        let fetchRequest: NSFetchRequest<CallHistoryEntry> = CallHistoryEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "callId == %@", callId as CVarArg)
        
        // 🔧 FIX: Use main thread for viewContext operations
        DispatchQueue.main.async {
            do {
                let entries = try self.context.fetch(fetchRequest)
                
                if let entry = entries.first {
                    // Update the duration if provided
                    if let duration = duration {
                        entry.duration = duration
                    }
                    
                    // Update the status if provided
                    if let status = status {
                        entry.callStatus = status.rawValue
                    }
                    
                    // 🔧 FIX: Save with error handling and ensure persistence
                    try self.context.save()
                    print("📞 CALL HISTORY: Entry updated successfully - \(callId)")
                    completion(true)
                } else {
                    print("📞 CALL HISTORY: No entry found with callId: \(callId)")
                    completion(false)
                }
            } catch {
                print("❌ CALL HISTORY: Failed to update entry: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    // Function to delete a specific call history entry by callId
    public func deleteCallHistoryEntry(callId: UUID,profileId:String) {
        let fetchRequest: NSFetchRequest<CallHistoryEntry> = CallHistoryEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "callId == %@", callId as CVarArg)
        
        // 🔧 FIX: Use main thread for viewContext operations
        DispatchQueue.main.async {
            do {
                let entries = try self.context.fetch(fetchRequest)
                if let entry = entries.first {
                    self.context.delete(entry)
                    try self.context.save()
                    print("📞 CALL HISTORY: Entry deleted successfully - \(callId)")
                    self.fetchCallHistoryFiltered(by: profileId)
                } else {
                    print("📞 CALL HISTORY: No entry found to delete with callId: \(callId)")
                }
            } catch {
                print("❌ CALL HISTORY: Failed to delete entry: \(error.localizedDescription)")
            }
        }
    }
    
    // Function to clear call history for a specific profileId
    public func clearCallHistory(for profileId: String) {
        let fetchRequest: NSFetchRequest<CallHistoryEntry> = CallHistoryEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "profileId == %@", profileId)
        
        // 🔧 FIX: Use main thread for viewContext operations
        DispatchQueue.main.async {
            do {
                let entries = try self.context.fetch(fetchRequest)
                for entry in entries {
                    self.context.delete(entry)
                }
                try self.context.save()
                print("📞 CALL HISTORY: Cleared \(entries.count) entries for profile: \(profileId)")
                self.fetchCallHistoryFiltered(by: profileId) // Refresh the callHistory property
            } catch {
                print("❌ CALL HISTORY: Failed to clear history for profile \(profileId): \(error.localizedDescription)")
            }
        }
    }
}
