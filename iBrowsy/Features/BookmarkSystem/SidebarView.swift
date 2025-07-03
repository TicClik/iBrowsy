import SwiftUI

struct SidebarView: View {
    // Inject the environment objects
    @EnvironmentObject var viewModel: WebViewModel
    @EnvironmentObject var bookmarkManager: BookmarkManager
    @EnvironmentObject var assistantViewModel: AssistantViewModel
    
    // State for the list selection (might need adjustment for hierarchy)
    @State private var selection: SidebarNavigationItem? = nil
    
    // State for Alerts
    @State private var showingRenameAlert = false
    @State private var showingAddFolderAlert = false
    @State private var itemToRename: BookmarkItem? = nil
    @State private var parentFolderForNewFolder: BookmarkFolder? = nil // nil for root
    @State private var newName: String = ""
    
    // --- ADD STATE for folder expansion ---
    @State private var isExpanded: Bool = false // Start collapsed
    
    // Add state for URL input field
    @State private var localUrlInput: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                // --- Conditionally include Pinned Section ---
                if viewModel.tabs.contains(where: { $0.isPinned }) {
                    pinnedTabsSection
                }
                
                openTabsSection
                
                browserSection
                bookmarksSection
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(sidebarBackground)
            .font(.system(size: 14, weight: .regular, design: .rounded))
            .toolbar {
                 addFolderToolbarItem
            }
            .alert("Rename Item", isPresented: $showingRenameAlert, presenting: itemToRename, actions: renameAlertActions, message: renameAlertMessage)
            .alert("New Folder", isPresented: $showingAddFolderAlert, actions: addFolderAlertActions, message: addFolderAlertMessage)
        }
        .frame(minWidth: 200)
        .onChange(of: selection) {
             handleSelectionChange(selection)
         }
        .onAppear {
            // Initialize localUrlInput with the current URL
            localUrlInput = viewModel.urlString
            
            // Ensure tab previews are available
            viewModel.refreshAllTabPreviews()
        }
        // Add a listener to update the localUrlInput when the URL changes in the model
        .onChange(of: viewModel.urlString) { newValue in
            localUrlInput = newValue
        }
    }
    
    // MARK: - Computed View Properties for Sections
    
    private var pinnedTabsSection: some View {
        Section("Pinned") {
            // Filter is still needed here inside the ForEach
            ForEach(viewModel.tabs.filter { $0.isPinned }) { tab in
                // Assuming TabItemView exists or we define basic layout here
                HStack { 
                    // Add Pin Indicator
                    Image(systemName: "pin.fill") // Use pin icon
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .padding(.trailing, 2)
                    
                    // Original TabItemView content (or placeholder)
                    TabItemView(
                        tab: tab,
                        isSelected: tab.id == viewModel.activeTab?.id,
                        onClose: { viewModel.closeTab(id: tab.id) },
                        onSelect: { viewModel.switchToTab(id: tab.id) }
                    )
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .padding(.vertical, 2)
                .listRowBackground(Color.clear)
                .contextMenu { // Add context menu for pinning
                    Button("Unpin Tab") { 
                        viewModel.togglePinState(for: tab.id)
                    }
                    // Add other context menu items later if needed (e.g., Close)
                }
            }
        }
    }
    
    private var openTabsSection: some View {
        Section { 
            // Filter for non-pinned tabs
            ForEach(viewModel.tabs.filter { !$0.isPinned }) { tab in 
                // Assuming TabItemView exists or we define basic layout here
                TabItemView(
                    tab: tab,
                    isSelected: tab.id == viewModel.activeTab?.id,
                    onClose: { viewModel.closeTab(id: tab.id) },
                    onSelect: { viewModel.switchToTab(id: tab.id) }
                )
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .padding(.vertical, 2)
                .listRowBackground(Color.clear)
                .contextMenu { // Add context menu for pinning
                    Button("Pin Tab") { 
                        viewModel.togglePinState(for: tab.id)
                    }
                     // Add other context menu items later if needed (e.g., Close)
                }
            }
        } header: { // Keep header for this section
            HStack {
                Text("Open") // Renamed from "Tabs"
                Spacer()
                GlassButton(style: .floating, action: {
                    viewModel.addNewTab(urlToLoad: nil)
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                        .font(.system(size: 12))
                }
                .help("Add New Tab (Cmd+T)")
            }
        }
    }
    
    private var browserSection: some View {
         Section("Browser") {
             Label("History", systemImage: "clock")
                 .tag(SidebarNavigationItem.history)
                 .listRowBackground(Color.clear) 
                 .padding(.vertical, 4)
             Label("Downloads", systemImage: "arrow.down.circle")
                 .tag(SidebarNavigationItem.downloads)
                 .listRowBackground(Color.clear) 
                 .padding(.vertical, 4)
         }
    }
    
    private var bookmarksSection: some View {
         Section {
             if bookmarkManager.rootItems.isEmpty {
                 // Show empty state with glass styling
                 VStack(spacing: 12) {
                     Image(systemName: "bookmark.slash")
                         .font(.title2)
                         .foregroundColor(.secondary)
                     
                     Text("No bookmarks yet")
                         .font(.headline)
                         .foregroundColor(.secondary)
                     
                     Text("Add bookmarks to see them here")
                         .font(.caption)
                         .foregroundColor(.secondary)
                         .multilineTextAlignment(.center)
                 }
                 .padding(.vertical, 20)
                 .frame(maxWidth: .infinity)
                 .background(
                     RoundedRectangle(cornerRadius: 12)
                         .fill(LiquidGlassStyle.secondaryGlass)
                         .overlay(
                             RoundedRectangle(cornerRadius: 12)
                                 .strokeBorder(LiquidGlassStyle.primaryBorder, lineWidth: 1)
                         )
                 )
                 .padding(.horizontal, 8)
                 .listRowBackground(Color.clear)
                 .listRowInsets(EdgeInsets())
             } else {
                 ForEach(bookmarkManager.rootItems) { item in
                     BookmarkListItemView(item: item, 
                                          selection: $selection,
                                          showingRenameAlert: $showingRenameAlert, 
                                          itemToRename: $itemToRename, 
                                          newName: $newName,
                                          showingAddFolderAlert: $showingAddFolderAlert,
                                          parentFolderForNewFolder: $parentFolderForNewFolder)
                         .listRowBackground(Color.clear)
                         .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                 }
             }
         } header: {
             HStack {
                 Label("Bookmarks", systemImage: "bookmark.fill")
                     .font(.headline)
                     .foregroundColor(.primary)
                 
                 Spacer()
                 
                 // Add bookmark folder button
                 GlassButton(style: .floating, action: {
                     parentFolderForNewFolder = nil // Add to root
                     newName = "" // Clear name
                     showingAddFolderAlert = true
                 }) {
                     Image(systemName: "folder.badge.plus")
                         .foregroundColor(.white)
                         .font(.system(size: 10))
                 }
                 .help("Add New Folder")
             }
             .padding(.horizontal, 8)
         }
    }
    
    // MARK: - Toolbar Content
    
    private var addFolderToolbarItem: some ToolbarContent {
         ToolbarItem(placement: .primaryAction) {
             GlassButton(style: .accent, action: {
                 parentFolderForNewFolder = nil // Add to root
                 newName = "" // Clear name
                 showingAddFolderAlert = true
             }) {
                 Image(systemName: "folder.badge.plus")
                     .foregroundColor(.white)
                     .font(.system(size: 12))
             }
             .help("Add New Folder at Root Level")
         }
    }
    
    // Notes button removed
    
    // MARK: - Alert Actions & Messages
    
    @ViewBuilder
    private func renameAlertActions(item: BookmarkItem) -> some View {
        TextField("New name", text: $newName)
            .autocorrectionDisabled()

        Button("Rename") { 
           let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedName.isEmpty {
                bookmarkManager.updateItemName(itemId: item.id, newName: trimmedName)
            }
        }
        Button("Cancel", role: .cancel) { }
    }
    
    private func renameAlertMessage(item: BookmarkItem) -> some View {
         Text("Enter a new name for \"\(item.name)\"")
    }
    
    @ViewBuilder
    private func addFolderAlertActions() -> some View {
        TextField("Folder Name", text: $newName)
            .autocorrectionDisabled()
        
        Button("Create") { 
            let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedName.isEmpty {
                bookmarkManager.addFolder(name: trimmedName, parentFolderId: parentFolderForNewFolder?.id)
            }
        }
        Button("Cancel", role: .cancel) { }
    }
    
    private func addFolderAlertMessage() -> some View {
         Text(parentFolderForNewFolder == nil ? "Create a new folder at the root level." : "Create a new folder inside \"\(parentFolderForNewFolder!.name)\".")
    }
    
    // MARK: - Selection Handling
    
    private func handleSelectionChange(_ newSelection: SidebarNavigationItem?) {
        guard let selection = newSelection else { return }
        
        switch selection {
        case .bookmark(let id):
            // Find the bookmark recursively (BookmarkManager could expose a helper)
            // For now, we assume BookmarkManager handles lookups if needed, 
            // but ideally, we'd get the URL directly or the Bookmark object here.
            // This requires a more robust way to find the bookmark from the ID.
            // Let's search for it manually for now:
            if let urlString = findBookmarkUrl(itemId: id, items: bookmarkManager.rootItems) {
                 viewModel.loadURL(from: urlString)
            } else {
                 print("Sidebar Error: Could not find bookmark URL for ID \(id)")
            }
            
        case .folder(_):
            // Selecting a folder might expand it, but doesn't navigate the webview
            print("Selected Folder - Action TBD (e.g., ensure expansion)")
            break // Do nothing for web navigation
        case .history:
            print("Showing History View")
            viewModel.showHistory()
        case .downloads:
            print("Showing Downloads View")
            viewModel.showDownloads()
        case .citations:
            print("Showing Citations View")
            viewModel.showCitations()
        case .tab(let id):
            print("Selected Tab ID \(id) via SidebarNavigationItem - action handled by TabItemView")
            
            // Force deselect the navigation selection to ensure proper tab switching
            // This ensures we're not stuck in a navigation view when clicking tabs
            DispatchQueue.main.async {
                self.selection = nil 
            }
            break
        }
    }
    
    // Helper function to find bookmark URL (replace with better BookmarkManager method later)
    private func findBookmarkUrl(itemId: UUID, items: [BookmarkItem]) -> String? {
        for item in items {
            switch item {
            case .bookmark(let bookmark):
                if bookmark.id == itemId {
                    return bookmark.urlString
                }
            case .folder(let folder):
                if let url = findBookmarkUrl(itemId: itemId, items: folder.children) {
                    return url
                }
            }
        }
        return nil
    }
    
    // MARK: - Background Styling to Match Homepage
    
    private var sidebarBackground: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.35),    // Same as homepage
                        Color.blue.opacity(0.08),     // Light blue for subtle tint
                        Color.white.opacity(0.25)     // Gentle white highlight
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(
                Rectangle()
                    .fill(Color.white.opacity(0.15))  // Subtle base for contrast
            )
            .ignoresSafeArea()
    }
}

// MARK: - Recursive View for List Items

private struct BookmarkListItemView: View {
    let item: BookmarkItem
    @Binding var selection: SidebarNavigationItem?
    
    // Bindings for alert presentation
    @Binding var showingRenameAlert: Bool
    @Binding var itemToRename: BookmarkItem?
    @Binding var newName: String
    @Binding var showingAddFolderAlert: Bool
    @Binding var parentFolderForNewFolder: BookmarkFolder?
    
    @EnvironmentObject var bookmarkManager: BookmarkManager // Needed for delete
    // --- ADD STATE for folder expansion ---
    @State private var isExpanded: Bool = false // Start collapsed
    // --- ADD STATE for hover --- 
    @State private var isHovering = false

    // Computed property to check if this item is selected
    private var isSelected: Bool {
        switch item {
        case .bookmark(let bookmark):
            return selection == .bookmark(id: bookmark.id)
        case .folder(let folder):
            // Folders might not be directly selectable in the same way, 
            // but we can check if the selection matches the folder's tag.
            return selection == .folder(id: folder.id) 
        }
    }

    var body: some View {
        switch item {
        case .bookmark(let bookmark):
            Label(bookmark.name, systemImage: "bookmark.fill")
                 .tag(SidebarNavigationItem.bookmark(id: bookmark.id))
                 .padding(.vertical, 4) // Keep vertical padding
                 .padding(.horizontal, 8) // Add horizontal padding
                 .frame(maxWidth: .infinity, alignment: .leading) // Ensure it fills width
                 .background( // Apply conditional background
                     RoundedRectangle(cornerRadius: 5)
                         .fill(isSelected ? Color("AppAccentColor").opacity(0.3) : (isHovering ? Color.secondary.opacity(0.15) : Color.clear))
                 )
                 .contentShape(Rectangle()) // Make whole area hoverable/clickable
                 .onHover { hovering in // Add hover modifier
                     isHovering = hovering
                 }
                 .contextMenu { bookmarkContextMenu(item: item) }
                 // Remove listRowBackground from here, apply in parent if needed
                 // .listRowBackground(Color.clear) 

        case .folder(let folder):
            DisclosureGroup(isExpanded: $isExpanded) { 
                 // Recursively display children
                 ForEach(folder.children) { childItem in
                     BookmarkListItemView(item: childItem, 
                                          selection: $selection, 
                                          showingRenameAlert: $showingRenameAlert, 
                                          itemToRename: $itemToRename, 
                                          newName: $newName, 
                                          showingAddFolderAlert: $showingAddFolderAlert, 
                                          parentFolderForNewFolder: $parentFolderForNewFolder)
                                          .padding(.leading, 10) // Indent children
                 }
            } label: {
                 Label(folder.name, systemImage: "folder.fill")
                     .tag(SidebarNavigationItem.folder(id: folder.id))
                     .padding(.vertical, 4) // Keep vertical padding
                     .padding(.horizontal, 8) // Add horizontal padding
                     .frame(maxWidth: .infinity, alignment: .leading) // Ensure it fills width
                     .background( // Apply conditional background
                         RoundedRectangle(cornerRadius: 5)
                             .fill(isSelected ? Color("AppAccentColor").opacity(0.3) : (isHovering ? Color.secondary.opacity(0.15) : Color.clear))
                     )
                     .contentShape(Rectangle()) // Make whole area hoverable/clickable
                     .onHover { hovering in // Add hover modifier
                         isHovering = hovering
                     }
                     .contextMenu { folderContextMenu(item: item, folder: folder) } // Pass folder too
                     // Remove listRowBackground from here, apply in parent if needed
                     // .listRowBackground(Color.clear) 
            }
            // Apply padding to the whole DisclosureGroup if needed, or handle row insets in parent List
            // .padding(.leading, item.depth * 10) // Example for indentation
        }
    }
    
    // Context menu for Bookmarks
    @ViewBuilder
    private func bookmarkContextMenu(item: BookmarkItem) -> some View {
        Button("Rename") { 
            itemToRename = item
            newName = item.name
            showingRenameAlert = true
        }
        Button("Delete", role: .destructive) {
            bookmarkManager.deleteItem(itemId: item.id)
        }
        // TODO: Add "Move To Folder..." option later
    }
    
    // Context menu for Folders
    @ViewBuilder
    private func folderContextMenu(item: BookmarkItem, folder: BookmarkFolder) -> some View {
         Button("New Folder Inside") {
             parentFolderForNewFolder = folder
             newName = ""
             showingAddFolderAlert = true
         }
         // TODO: Add "New Bookmark Inside" option
         Divider()
         Button("Rename") { 
             itemToRename = item
             newName = item.name
             showingRenameAlert = true
         }
         Button("Delete", role: .destructive) {
             // Optional: Add confirmation for deleting non-empty folders
             bookmarkManager.deleteItem(itemId: item.id)
         }
         // TODO: Add "Move To Folder..." option later
    }
}

// MARK: - Updated Navigation Item Enum

// Use a distinct name to avoid conflicts if ContentView has NavigationItem
enum SidebarNavigationItem: Hashable {
    case history
    case downloads
    case citations
    case bookmark(id: UUID)
    case folder(id: UUID) // Add folder case
    case tab(id: UUID) // NEW: Add case for tabs if needed for List selection tracking
}

// MARK: - Preview Provider

#Preview {
     ContentView()
     // For a more isolated preview:
     /*
     SidebarView()
         .environmentObject(WebViewModel.previewInstance)
         .environmentObject(BookmarkManager.preview) // Use preview manager
         .frame(width: 250)
     */
} 