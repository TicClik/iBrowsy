import SwiftUI

struct HomePageView: View {
    @ObservedObject var viewModel: WebViewModel // Access to loadURL
    @EnvironmentObject var bookmarkManager: BookmarkManager // Access to bookmarks
    @State private var searchInput: String = "" // Local state for the search bar
    @Environment(\.colorScheme) private var colorScheme // For adapting to dark/light mode
    @State private var refreshID = UUID() // Force refresh trigger

    // Grid layout for bookmarks
    let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 130, maximum: 200), spacing: 24)
    ]

    var body: some View {
        GlassPanel(style: .main) {
            VStack(spacing: 60) {
                Spacer(minLength: 40)
                
                // Enhanced Welcome Section with Animations
                EnhancedWelcomeSection {
                    let newTab = viewModel.addNewTab(url: nil)
                    viewModel.isShowingHomepage = false
                } onAIAssistantAction: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        // Toggle assistant visibility
                    }
                }
                
                // MARK: - Search Bar
                GlassCard(style: .primary) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                        
                        TextField("Search or enter website address", text: $searchInput, onCommit: {
                            if !searchInput.isEmpty {
                                viewModel.loadURL(from: searchInput)
                            }
                        })
                        .textFieldStyle(.plain)
                        .font(.headline)
                        .submitLabel(.go)
                        .foregroundColor(.primary)
                        
                        if !searchInput.isEmpty {
                            GlassButton(style: .secondary, action: { 
                                searchInput = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white)
                            }
                        }
                            
                        GlassButton(style: .accent, action: { 
                            if !searchInput.isEmpty {
                                viewModel.loadURL(from: searchInput)
                            }
                        }) {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 18))
                        }
                        .disabled(searchInput.isEmpty)
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 12)
                }
                .frame(width: 700)
                
                // MARK: - Bookmarks Grid (Root Level Only)
                // Get all bookmark items (both individual bookmarks and folders)
                let allRootItems = bookmarkManager.rootItems
                let rootBookmarks = allRootItems.compactMap { item -> Bookmark? in
                    if case .bookmark(let bookmark) = item {
                        return bookmark
                    } else {
                        return nil
                    }
                }
                let rootFolders = allRootItems.compactMap { item -> BookmarkFolder? in
                    if case .folder(let folder) = item {
                        return folder
                    } else {
                        return nil
                    }
                }
                
                // Clear bookmark count and detailed info display for performance
                
                // Show bookmarks section if there are any items
                if !allRootItems.isEmpty {
                    VStack(spacing: 30) {
                        Text("Your Bookmarks")
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 24) {
                                // Show individual bookmarks
                                ForEach(rootBookmarks) { bookmark in
                                    BookmarkItemView(bookmark: bookmark) {
                                        viewModel.loadURL(from: bookmark.urlString)
                                    }
                                }
                                
                                // Show folders
                                ForEach(rootFolders) { folder in
                                    FolderItemView(folder: folder) {
                                        // For now, just show the first bookmark in the folder
                                        if case .bookmark(let firstBookmark) = folder.children.first {
                                            viewModel.loadURL(from: firstBookmark.urlString)
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                        .background(Color.clear)
                        .frame(maxHeight: 500)
                        .frame(width: 800)
                    }
                } else {
                    VStack(spacing: 20) {
                        Text("Quick Bookmarks")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        GlassCard(style: .secondary) {
                            VStack(spacing: 20) {
                                Image(systemName: "bookmark")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                    
                                Text("No bookmarks yet")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                    
                                Text("Browse to websites and bookmark them to see them here")
                                    .font(.headline)
                                    .foregroundColor(.secondary.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    
                                // Quick bookmark buttons for popular sites
                                HStack(spacing: 16) {
                                    GlassButton(style: .primary, action: {
                                        viewModel.loadURL(from: "https://apple.com")
                                    }) {
                                        VStack(spacing: 8) {
                                            Image(systemName: "applelogo")
                                                .font(.system(size: 20))
                                            Text("Apple")
                                                .font(.caption)
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                    }
                                    
                                    GlassButton(style: .primary, action: {
                                        viewModel.loadURL(from: "https://github.com")
                                    }) {
                                        VStack(spacing: 8) {
                                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                                .font(.system(size: 20))
                                            Text("GitHub")
                                                .font(.caption)
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                    }
                                    
                                    GlassButton(style: .primary, action: {
                                        viewModel.loadURL(from: "https://google.com")
                                    }) {
                                        VStack(spacing: 8) {
                                            Image(systemName: "magnifyingglass")
                                                .font(.system(size: 20))
                                            Text("Google")
                                                .font(.caption)
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                    }
                                }
                            }
                            .padding(.vertical, 40)
                            .padding(.horizontal, 30)
                        }
                        .frame(width: 700)
                    }
                }
                
                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 40)
        }
        .edgesIgnoringSafeArea(.all)
        .id(refreshID) // Force refresh when refreshID changes
        .onAppear {
            // Force a check and trigger refresh if needed
            DispatchQueue.main.async {
                if bookmarkManager.rootItems.count > 0 && refreshID == refreshID {
                    refreshID = UUID()
                }
            }
        }
        .onChange(of: bookmarkManager.rootItems.count) { newCount in
            DispatchQueue.main.async {
                refreshID = UUID()
            }
        }
        .onReceive(bookmarkManager.objectWillChange) { _ in
            DispatchQueue.main.async {
                refreshID = UUID()
            }
        }
    }
}

// MARK: - Subview for a single bookmark item

struct BookmarkItemView: View {
    let bookmark: Bookmark
    let action: () -> Void // Action to perform on tap
    
    @State private var faviconImage: Image? = nil
    @Environment(\.colorScheme) private var colorScheme // For adapting to dark/light mode

    var body: some View {
        GlassCard(style: .floating) {
            Button(action: action) {
                VStack(spacing: 12) {
                    // Display fetched favicon or placeholder
                    Group {
                        if let image = faviconImage {
                            image
                                .resizable()
                                .interpolation(.high) // Use high interpolation for clearer icons
                        } else {
                            Image(systemName: "globe")
                                .resizable()
                                .foregroundColor(.secondary)
                        }
                    }
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LiquidGlassStyle.accentGlass.opacity(0.3))
                    )

                    Text(bookmark.name)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .lineLimit(1) // Ensure name doesn't wrap excessively
                        .truncationMode(.tail)
                        .foregroundColor(.primary)
                }
                .padding(12)
                .frame(width: 110, height: 110) // Fixed size for grid consistency
                .contentShape(Rectangle()) // Make entire area tappable
            }
            .buttonStyle(.plain) // Use plain button style to avoid default button appearance
        }
        .onAppear { 
            // Launch a Task to load the favicon asynchronously
            Task {
                await updateFavicon()
            }
        }
    }
    
    // Helper function to update the favicon state - now async
    @MainActor
    private func updateFavicon() async {
        let favicon = await FaviconLoader.shared.getFavicon(for: bookmark.urlString)
        self.faviconImage = favicon
    }
}

// MARK: - Subview for a single bookmark folder

struct FolderItemView: View {
    let folder: BookmarkFolder
    let action: () -> Void // Action to perform on tap
    
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GlassCard(style: .floating) {
            Button(action: action) {
                VStack(spacing: 12) {
                    // Folder icon with child count indicator
                    ZStack {
                        Image(systemName: "folder.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .foregroundColor(.blue)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LiquidGlassStyle.primaryGlass.opacity(0.3))
                            )
                        
                        // Badge showing number of items
                        if !folder.children.isEmpty {
                            Text("\(folder.children.count)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(
                                    Circle()
                                        .fill(.red)
                                )
                                .offset(x: 15, y: -15)
                        }
                    }

                    Text(folder.name)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundColor(.primary)
                }
                .padding(12)
                .frame(width: 110, height: 110)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}





#Preview {
    HomePageView(viewModel: WebViewModel.previewInstance)
        .environmentObject(BookmarkManager.preview)
        .frame(width: 800, height: 600)
} 