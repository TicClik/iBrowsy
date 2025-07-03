import SwiftUI
import Foundation

// MARK: - Bookmark System Feature Protocol
protocol BookmarkSystemServiceProtocol: ObservableObject {
    // Core bookmark data
    var rootItems: [BookmarkItem] { get }
    
    // Bookmark management
    func addBookmark(name: String, urlString: String, parentFolderId: UUID?)
    func addFolder(name: String, parentFolderId: UUID?)
    func updateItemName(itemId: UUID, newName: String)
    func deleteItem(itemId: UUID)
    
    // Utility methods
    func clearAllBookmarks()
    func printDebugInfo()
}

// MARK: - Bookmark Models (Self-contained)
enum BookmarkItem: Identifiable, Codable, Hashable {
    case bookmark(Bookmark)
    case folder(BookmarkFolder)
    
    var id: UUID {
        switch self {
        case .bookmark(let bookmark):
            return bookmark.id
        case .folder(let folder):
            return folder.id
        }
    }
    
    var name: String {
        switch self {
        case .bookmark(let bookmark):
            return bookmark.name
        case .folder(let folder):
            return folder.name
        }
    }
}

struct Bookmark: Identifiable, Codable, Hashable {
    let id = UUID()
    var name: String
    var urlString: String
    
    init(name: String, urlString: String) {
        self.name = name
        self.urlString = urlString
    }
}

struct BookmarkFolder: Identifiable, Codable, Hashable {
    let id = UUID()
    var name: String
    var children: [BookmarkItem] = []
    
    init(name: String) {
        self.name = name
    }
}

// MARK: - Bookmark System Events Protocol
protocol BookmarkSystemEventsProtocol {
    func onBookmarkAdded(_ bookmark: Bookmark)
    func onFolderAdded(_ folder: BookmarkFolder)
    func onItemDeleted(itemId: UUID)
    func onItemRenamed(itemId: UUID, newName: String)
} 