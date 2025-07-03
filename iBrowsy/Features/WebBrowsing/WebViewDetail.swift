import SwiftUI

struct WebViewDetail: View {
    @ObservedObject var viewModel: WebViewModel
    @Binding var urlInput: String
    // Need access to bookmark manager for the add button
    @EnvironmentObject var bookmarkManager: BookmarkManager 
    // Add binding for assistant visibility
    @Binding var isAssistantVisible: Bool
    // Add access to the citation manager
    @EnvironmentObject var citationManager: CitationManager
    // Add access to the assistant view model
    @EnvironmentObject var assistantViewModel: AssistantViewModel

    // State for bookmarks
    @State private var bookmarkInfoToSave: (name: String, urlString: String)? = nil
    @State private var showingAddBookmarkAlert = false
    @State private var selectedFolderId: UUID? = nil
    
    // REMOVED: Citation generation feature as per user request
    

    
    var body: some View {
        ZStack {
            // Main web view
            VStack(spacing: 0) {
                // Web content area - show the web view or homepage
                if viewModel.isShowingHomepage {
                    HomePageView(viewModel: viewModel)
                        .environmentObject(bookmarkManager)
                } else if viewModel.showingHistoryView {
                    HistoryView(viewModel: viewModel)
                } else if viewModel.showingDownloadsView {
                    DownloadsView(viewModel: viewModel)
                } else if viewModel.showingCitationsView {
                    CitationsView(viewModel: viewModel)
                } else {
                    // This is the container for web content that will be inset
                    VStack { // Added VStack for padding
                        if let tab = viewModel.activeTab {
                            if tab.isSplitView, let secondaryWebView = tab.secondaryWebView {
                                VStack { // This VStack was already here, might be redundant or kept for structure
                                    HSplitView {
                                        WebViewWithContextMenu(viewModel: viewModel, webViewInstance: tab.primaryWebView)
                                            .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                                            .contentShape(Rectangle())
                                            .id("primary-webview-\(tab.id)")
                                            .onChange(of: viewModel.activeTab?.activeSplitViewSide) { newSide in
                                                if newSide == .primary {
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                                        if let window = tab.primaryWebView.window {
                                                            window.makeFirstResponder(tab.primaryWebView)
                                                        }
                                                    }
                                                }
                                            }
                                            .padding(0)
                                            .compositingGroup() // Ensure proper clipping
                                            .clipped()          // Clip to rounded corners
                                            .trackWidth()       // Track width for size preservation
                                            .onPreferenceChange(HorizontalSizeKey.self) { width in
                                                if let width = width, width > 0 {
                                                    // Only store the size if it's significantly changed (avoid noise)
                                                    let currentWidth = tab.primaryPaneDesiredWidth ?? 0
                                                    if abs(width - currentWidth) > 20 {
                                                        DispatchQueue.main.async {
                                                            viewModel.updatePrimaryPaneWidth(for: tab.id, width: width)
                                                        }
                                                    }
                                                }
                                            }

                                        WebViewWithContextMenu(viewModel: viewModel, webViewInstance: secondaryWebView)
                                            .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                                            .contentShape(Rectangle())
                                            .id("secondary-webview-\(tab.id)")
                                            .onChange(of: viewModel.activeTab?.activeSplitViewSide) { newSide in
                                                if newSide == .secondary {
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                                        if let window = secondaryWebView.window {
                                                            window.makeFirstResponder(secondaryWebView)
                                                        }
                                                    }
                                                }
                                            }
                                            .padding(0)
                                            .compositingGroup() // Ensure proper clipping
                                            .clipped()          // Clip to rounded corners
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(16) // Add padding around the HSplitView
                                    // Set initial position of divider if we have a stored width
                                    .onAppear {
                                        if let primaryWidth = tab.primaryPaneDesiredWidth, primaryWidth > 0 {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                // Find the HSplitView
                                                if let hostView = secondaryWebView.superview?.superview as? NSView,
                                                   let splitView = hostView.superview as? NSSplitView {
                                                    // Set position programmatically
                                                    splitView.setPosition(primaryWidth, ofDividerAt: 0)
                                                }
                                            }
                                        }
                                    }
                                }
                                .id("splitView-\(tab.id)-\(tab.isSplitView)")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .onAppear {
                                    // Force focus on the correct WebView after a short delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        if tab.activeSplitViewSide == .primary {
                                            if let window = tab.primaryWebView.window {
                                                window.makeFirstResponder(tab.primaryWebView)
                                            }
                                        } else {
                                            if let window = secondaryWebView.window {
                                                window.makeFirstResponder(secondaryWebView)
                                            }
                                        }
                                    }
                                    
                                    // Also force state update in case it's stale
                                    viewModel.updatePublishedStateFromActiveSplit()
                                }
                            } else {
                                // Show only primary view
                                WebViewWithContextMenu(viewModel: viewModel, webViewInstance: tab.primaryWebView)
                                    .id("singleView-\(tab.id)")
                                    .padding(0)
                                    .compositingGroup() // Ensure proper clipping
                                    .clipped()          // Clip to rounded corners
                                    .padding(16) // Add outer padding around the entire webview area
                            }
                        } else {
                            // In case there's no active tab, create one
                            VStack(spacing: 16) {
                                Text("No active tab detected")
                                    .font(.title)
                                    .foregroundColor(.secondary)
                                
                                Button("Create a new tab") {
                                    viewModel.addNewTab(urlToLoad: nil)
                                }
                                .buttonStyle(.borderedProminent)
                                .padding()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onAppear {
                                // Try to create a tab automatically if there's none
                                if viewModel.tabs.isEmpty {
                                    viewModel.addNewTab(urlToLoad: nil)
                                }
                            }
                        }
                    }
                    .padding(0) // Remove padding around the web content area for maximum space
                }
            }
            
            // REMOVED: Reader view display as per user request
            
            // Loading overlay if needed
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
        // Ensure WebViewDetail's own background is clear so it inherits from ContentView
        .background(Color.clear)
        .toolbar {
            // Only keep essential buttons
            if let tab = viewModel.activeTab, !viewModel.isShowingHomepage, !viewModel.showingHistoryView, !viewModel.showingDownloadsView, !viewModel.showingCitationsView {
                // Split view toggle button - essential button to keep
                ToolbarItem(placement: .primaryAction) {
                    GlassButton(style: .secondary, action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.toggleSplitView(for: tab.id)
                        }
                    }) {
                        Image(systemName: tab.isSplitView ? "rectangle.split.1x2.fill" : "rectangle.split.1x2")
                            .foregroundColor(.primary)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(width: 32, height: 28)
                    .help(tab.isSplitView ? "Exit Split View" : "Enter Split View")
                }
                

            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .onAppear {
            urlInput = viewModel.urlString
            
            // Set up notification observer for bookmark requests
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("AddBookmarkRequest"),
                object: nil,
                queue: .main
            ) { [self] _ in
                triggerAddBookmarkFlow()
            }
        }
        .onDisappear {
            // Remove notification observer
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("AddBookmarkRequest"), object: nil)
        }
        // Add onChange modifier to update URL bar when URL string changes
        .onChange(of: viewModel.urlString) { newValue in
            urlInput = newValue
        }
        // Also update URL input when active tab changes
        .onChange(of: viewModel.activeTab?.id) { _ in
            urlInput = viewModel.urlString
        }
        // Create a computed property for tracking active side changes
        .onChange(of: viewModel.activeTab?.activeSplitViewSide) { _ in
            urlInput = viewModel.urlString
        }
        // Add alert for bookmark saving
        .alert("Add Bookmark", isPresented: $showingAddBookmarkAlert) {
            Group {
                if let info = bookmarkInfoToSave {
                    // Add a button for bookmarks bar
                    Button("Add to Bookmarks Bar") {
                        bookmarkManager.addBookmark(name: info.name, 
                                                 urlString: info.urlString, 
                                                 parentFolderId: nil)
                        bookmarkInfoToSave = nil
                    }
                    
                    // Create buttons for each top-level folder
                    ForEach(bookmarkManager.rootItems.compactMap { item -> BookmarkFolder? in
                        guard case .folder(let folder) = item else { return nil }
                        return folder
                    }, id: \.id) { folder in
                        Button("Add to \(folder.name)") {
                            bookmarkManager.addBookmark(name: info.name, 
                                                     urlString: info.urlString, 
                                                     parentFolderId: folder.id)
                            bookmarkInfoToSave = nil
                        }
                    }
                    
                    Button("Cancel", role: .cancel) {
                        bookmarkInfoToSave = nil
                    }
                }
            }
        } message: {
            if let info = bookmarkInfoToSave {
                Text("Add \"\(info.name)\" to your bookmarks")
            } else {
                EmptyView()
            }
        }
        // REMOVED: Citation generation alert as per user request

    }

    // Updated function to trigger the alert flow
    func triggerAddBookmarkFlow() {
        let currentTitle = viewModel.webView.title ?? "Untitled Page"
        let currentURLString = viewModel.urlString

        // Check if the URL is valid and not the homepage URL
        if !currentURLString.isEmpty && currentURLString != viewModel.homepageURLString, 
           URL(string: currentURLString) != nil {
            // Store info and show the alert
            bookmarkInfoToSave = (name: currentTitle, urlString: currentURLString)
            showingAddBookmarkAlert = true
        } else {
            // Cannot add bookmark, invalid, empty, or homepage URL
        }
    }

    // REMOVED: Citation generation method as per user request
    
    // Helper method to better handle taps in the split view environment
    @MainActor private func hitTestingTap(tabId: UUID, side: SplitViewSide) {
        if let tab = viewModel.activeTab {
            let oldSide = tab.activeSplitViewSide
            
            // First directly modify the model since UI is sometimes slow to update
            if let index = viewModel.tabs.firstIndex(where: { $0.id == tabId }) {
                viewModel.tabs[index].activeSplitViewSide = side
            }
                
            // Now call the view model method to handle state updates
            viewModel.setActiveSplitSide(for: tabId, side: side)
            
            // Update URL input field to reflect the active side's URL
            if let webView = (side == .primary ? tab.primaryWebView : tab.secondaryWebView) {
                DispatchQueue.main.async {
                    self.urlInput = webView.url?.absoluteString ?? self.viewModel.homepageURLString
                }
            }
            
            // Force the split view to redraw with the new active side
            viewModel.objectWillChange.send()
        } else {
            // No active tab found when trying to switch sides
        }
    }
}

// Preference key for storing horizontal size
struct HorizontalSizeKey: PreferenceKey {
    static var defaultValue: CGFloat? = nil
    
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}

// GeometryReader modifier to track view width
extension View {
    func trackWidth() -> some View {
        self.background(
            GeometryReader { geo in
                Color.clear.preference(key: HorizontalSizeKey.self, value: geo.size.width)
            }
        )
    }
} 