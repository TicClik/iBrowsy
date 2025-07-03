import SwiftUI
import Combine

class BookmarkManager: ObservableObject {
    // Store the root level items (can be bookmarks or folders)
    @Published var rootItems: [BookmarkItem] = []
    // Use a new key because the data structure has changed
    private let userDefaultsKey = "iBrowsyBookmarkItems_v1"
    private static var hasInitialized = false

    // Designated initializer used by the app
    init() {
        
        // Only do initial setup once per app session
        if !BookmarkManager.hasInitialized {
            BookmarkManager.hasInitialized = true
            
            // Try to load existing bookmarks first
            loadItems()
            
            // Start with empty bookmarks list if none exist
            // Initialize with loaded bookmarks or empty list
        } else {
            // For subsequent initializations, just load existing data
            loadItems()
        }
        
        // Force notification
        DispatchQueue.main.async {
            self.objectWillChange.send()
            print("BookmarkManager: Sent objectWillChange notification")
        }
    }

    // Static instance for SwiftUI Previews - Updated for new structure
    static var preview: BookmarkManager {
        let manager = BookmarkManager()
        // Return an empty manager for previews instead of dummy data
        // let folder1 = BookmarkFolder(name: "Work")
        // let folder2 = BookmarkFolder(name: "Personal")
        // let nestedFolder = BookmarkFolder(name: "Work")
        // 
        // manager.addFolder(folder: folder1) // Add root folder
        // manager.addFolder(folder: folder2)
        // manager.addBookmark(name: "Apple", urlString: "https://apple.com", parentFolderId: nil) // Root bookmark
        // manager.addFolder(folder: nestedFolder, parentFolderId: folder1.id) // Nested folder
        // manager.addBookmark(name: "SwiftUI Docs", urlString: "https://developer.apple.com/documentation/swiftui/", parentFolderId: folder1.id)
        // manager.addBookmark(name: "Example Site", urlString: "https://example.com", parentFolderId: nestedFolder.id)
        // manager.addBookmark(name: "HackingWithSwift", urlString: "https://hackingwithswift.com", parentFolderId: folder2.id)
        
        return manager
    }

    // MARK: - Loading & Saving (Uses new structure)
    private func loadItems() {
        print("BookmarkManager: Loading bookmarks from key: \(userDefaultsKey)")
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { 
            print("BookmarkManager: No existing bookmark data found")
            return 
        }
        
        do {
            let decoder = JSONDecoder()
            rootItems = try decoder.decode([BookmarkItem].self, from: data)
            print("BookmarkManager: Successfully loaded \(rootItems.count) bookmark items")
            
            // Debug: Print what we loaded
            for item in rootItems {
                switch item {
                case .bookmark(let bookmark):
                    print("  - Loaded bookmark: \(bookmark.name) -> \(bookmark.urlString)")
                case .folder(let folder):
                    print("  - Loaded folder: \(folder.name) with \(folder.children.count) children")
                }
            }
        } catch {
            print("BookmarkManager: Error decoding bookmark items: \(error)")
            print("BookmarkManager: Clearing corrupted data and starting fresh")
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            rootItems = []
        }
    }

    private func saveItems() {
        print("BookmarkManager: Saving \(rootItems.count) bookmark items")
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted // Optional: Makes debugging easier
            let data = try encoder.encode(rootItems)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            print("BookmarkManager: Successfully saved bookmarks")
            
            // Force synchronization to ensure data is written
            UserDefaults.standard.synchronize()
        } catch {
            print("BookmarkManager: Error encoding bookmark items: \(error)")
        }
    }

    // MARK: - Finding Items (Recursive Helpers)

    // Finds the parent array containing the item with the given ID and allows modification through a closure
    // Returns true if the item was found and the operation closure was executed
    private func findAndModifyItem(withId itemId: UUID, in items: inout [BookmarkItem], operation: (inout [BookmarkItem], Int) -> Void) -> Bool {
        for i in items.indices {
            if items[i].id == itemId {
                operation(&items, i) // Execute the operation on the found item's array and index
                return true
            }
            // If it's a folder, search recursively within its children
            if case .folder(var folder) = items[i] {
                // Perform the find and modify operation recursively on the children
                if findAndModifyItem(withId: itemId, in: &folder.children, operation: operation) {
                    // If modification happened in children, update the folder in the current array
                    items[i] = .folder(folder)
                    return true // Propagate success upwards
                }
            }
        }
        return false // Item not found in this branch
    }

    // Finds a folder by its ID and allows modification through a closure
    // Returns true if the folder was found and the operation closure was executed
    private func findAndModifyFolder(withId folderId: UUID, in items: inout [BookmarkItem], operation: (inout BookmarkFolder) -> Void) -> Bool {
        for i in items.indices {
            guard case .folder(var folder) = items[i] else { continue } // Use var to allow modification

            if folder.id == folderId {
                operation(&folder) // Execute the operation directly on the folder
                items[i] = .folder(folder) // Write the modified folder back to the array
                return true
            }

            // Recursive search - requires mutable access to folder.children
            if findAndModifyFolder(withId: folderId, in: &folder.children, operation: operation) {
                // If modification happened in children, update the folder in the current array
                items[i] = .folder(folder)
                return true // Propagate success upwards
            }
        }
        return false // Folder not found in this branch
    }

    // MARK: - Add Operations

    func addBookmark(name: String, urlString: String, parentFolderId: UUID?) {
        let newBookmark = Bookmark(name: name.isEmpty ? "Untitled" : name, urlString: urlString)
        let newItem = BookmarkItem.bookmark(newBookmark)
        
        // Add to root if parent ID is nil
        guard let parentId = parentFolderId else {
             // Prevent duplicates at root level (optional)
             if !rootItems.contains(where: { if case .bookmark(let b) = $0 { return b.urlString == urlString } else { return false } }) {
                 rootItems.append(newItem)
                 saveItems()
                 // Force UI update
                 DispatchQueue.main.async {
                     self.objectWillChange.send()
                 }
             } else {
                 // Root bookmark already exists
             }
            return
        }

        // Find the parent folder and add to its children
        let success = findAndModifyFolder(withId: parentId, in: &rootItems) { folder in
            // Prevent duplicates within the folder (optional)
            if !folder.children.contains(where: { if case .bookmark(let b) = $0 { return b.urlString == urlString } else { return false } }) {
                folder.children.append(newItem)
            } else {
                // Bookmark already exists in folder
            }
        }

        if success {
            saveItems()
        } else {
            // Could not find parent folder
        }
    }
    
    // Overload for adding predefined Bookmark object (for preview/testing)
     func addBookmark(_ bookmark: Bookmark, parentFolderId: UUID?) {
         addBookmark(name: bookmark.name, urlString: bookmark.urlString, parentFolderId: parentFolderId)
     }

    func addFolder(name: String, parentFolderId: UUID?) {
        let newFolder = BookmarkFolder(name: name.isEmpty ? "Untitled Folder" : name)
        addFolder(folder: newFolder, parentFolderId: parentFolderId)
    }
    
    // Helper to add a predefined Folder object
     func addFolder(folder: BookmarkFolder, parentFolderId: UUID? = nil) {
         let newItem = BookmarkItem.folder(folder)
         guard let parentId = parentFolderId else {
             // Check for duplicate name at root
             if !rootItems.contains(where: { if case .folder(let f) = $0 { return f.name == folder.name } else { return false } }) {
                 rootItems.append(newItem)
                 saveItems()
                 // Force UI update
                 DispatchQueue.main.async {
                     self.objectWillChange.send()
                 }
             } else {
                 // Root folder already exists
             }
             return
         }
         
         let success = findAndModifyFolder(withId: parentId, in: &rootItems) { folder in
            // Check for duplicate name within parent
             if !folder.children.contains(where: { if case .folder(let f) = $0 { return f.name == folder.name } else { return false } }) {
                 folder.children.append(newItem)
             } else {
                 // Folder already exists in parent folder
             }
         }

         if success {
             saveItems()
         } else {
             // Could not find parent folder
         }
     }

    // MARK: - Update & Delete Operations

    func updateItemName(itemId: UUID, newName: String) {
        let success = findAndModifyItem(withId: itemId, in: &rootItems) { items, index in
            switch items[index] {
            case .bookmark(var bookmark):
                bookmark.name = newName
                items[index] = .bookmark(bookmark)
            case .folder(var folder):
                // TODO: Add check for duplicate folder names within the *same parent* before renaming
                folder.name = newName
                items[index] = .folder(folder)
            }
        }

        if success {
            saveItems()
        } else {
            // Could not find item to rename
        }
    }

    func deleteItem(itemId: UUID) {
        var deletedItemName: String?
        let success = findAndModifyItem(withId: itemId, in: &rootItems) { items, index in
            deletedItemName = items[index].name
            items.remove(at: index) // Modify the array directly
        }

        if success {
            saveItems()
        } else {
            // Could not find item to delete
        }
    }
    
    // MARK: - Debug & Maintenance Methods
    
    func clearAllBookmarks() {
        print("BookmarkManager: Clearing all bookmarks")
        rootItems = []
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.synchronize()
        
        // Force UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func printDebugInfo() {
        print("BookmarkManager Debug Info:")
        print("  - Storage key: \(userDefaultsKey)")
        print("  - Root items count: \(rootItems.count)")
        print("  - Has initialized: \(BookmarkManager.hasInitialized)")
        
        for (index, item) in rootItems.enumerated() {
            switch item {
            case .bookmark(let bookmark):
                print("  [\(index)] Bookmark: '\(bookmark.name)' -> \(bookmark.urlString)")
            case .folder(let folder):
                print("  [\(index)] Folder: '\(folder.name)' (\(folder.children.count) children)")
            }
        }
    }

    // MARK: - Migration/Backward Compatibility (Placeholder)
    // If needed, add code here to migrate old [Bookmark] data 
    // to the new [BookmarkItem] structure when loading.
    // This is complex and depends on the desired migration strategy.

    // --- Deprecated / To be Removed --- 

     // Keep old functions temporarily to avoid breaking previews immediately,
     // but mark as deprecated or remove soon.
     @available(*, deprecated, message: "Use addBookmark(name:urlString:parentFolderId:) instead")
     func addBookmark(name: String, url: URL) {
         addBookmark(name: name, urlString: url.absoluteString, parentFolderId: nil)
     }
     
     @available(*, deprecated, message: "Use updateItemName(itemId:newName:) instead")
     func updateBookmarkName(bookmark: Bookmark, newName: String) {
          updateItemName(itemId: bookmark.id, newName: newName)
     }
 
     @available(*, deprecated, message: "Use deleteItem(itemId:) instead")
     func deleteBookmark(_ bookmark: Bookmark) {
         deleteItem(itemId: bookmark.id)
     }


}
 