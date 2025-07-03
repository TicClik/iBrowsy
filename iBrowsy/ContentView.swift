import SwiftUI
import WebKit
import AVFoundation

// MARK: - Supporting Components

struct FeatureChip: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.blue)
            
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.20))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.3),
                                    Color.blue.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
        )
    }
}

// MARK: - Color Scheme Preference Enum

enum AppColorScheme: Int, CaseIterable, Identifiable {
    case light = 1

    var id: Int { self.rawValue }

    var swiftUIScheme: ColorScheme? {
        switch self {
        case .light: return .light
        }
    }

    var description: String {
        switch self {
        case .light: return "Light"
        }
    }
}

// MARK: - Shared Definitions

// MARK: - Main Content View

@MainActor
struct ContentView: View {
    // WebViewModel is now an EnvironmentObject
    @EnvironmentObject private var viewModel: WebViewModel
    
    // Additional environment objects
    @EnvironmentObject private var bookmarkManager: BookmarkManager // Assuming BookmarkManager is provided by a higher-level view or App struct
    
    // AssistantViewModel is now an EnvironmentObject
    @EnvironmentObject private var assistantViewModel: AssistantViewModel 
    
    // CitationManager can remain a StateObject if its lifecycle is tied to ContentView, 
    // or become an EnvironmentObject if provided from App level.
    // For now, let's assume it's specific to ContentView or provided from App as well.
    // If provided from App, change to @EnvironmentObject. Let's assume it will be for consistency.
    @EnvironmentObject private var citationManager: CitationManager 
    
 
    
    // Local state for the text field input, synchronized with ViewModel
    @State private var urlInput: String = ""
    
    // State to control the visibility of the Assistant panel
    @State private var isAssistantVisible: Bool = false 
    // State for AssistantView drag gesture
    @State private var assistantDragOffset: CGSize = .zero
    @State private var assistantPosition: CGSize = .zero
    
    // State for Split View Analysis panel
    @State private var isSplitViewAnalysisVisible: Bool = false
    
    // Privacy settings are now integrated into main Settings window
    @StateObject private var privacyWindowManager = PrivacyWindowManager()
    
    // Notes feature removed
    
    // State to track currently hovered tab and position for preview
    @State private var hoveredTab: TabHoverInfo? = nil
    
    // Add state for sidebar visibility
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    
    // State for drag and drop visual feedback
    @State private var isDraggedOver: Bool = false
    
    // --- ADD AppStorage for Color Scheme ---
    @AppStorage("appColorScheme") private var selectedScheme: AppColorScheme = .light
    

    
    // Initializer is removed as StateObjects are no longer initialized here.
    // init() {
    //     // Using the same WebViewModel instance for both StateObjects
    //     let webViewModel = WebViewModel()
    //     _viewModel = StateObject(wrappedValue: webViewModel)
    //     _assistantViewModel = StateObject(wrappedValue: AssistantViewModel(webViewModel: webViewModel))
    //     _bookmarkManager = StateObject(wrappedValue: BookmarkManager()) // This would also need to change if it comes from App
    //     _citationManager = StateObject(wrappedValue: CitationManager()) // This would also need to change

    //     
    //     // Set the assistantViewModel in the WebViewModel
    //     webViewModel.assistantViewModel = _assistantViewModel.wrappedValue
    //     }
    
    /// Handle file drops on the main view (sidebar or detail area)
    private func handleMainViewFileDrop(fileURL: URL) -> Bool {
        print("ContentView: Handling file drop - \\(fileURL.lastPathComponent)")
        
        // Check if file exists and is readable
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("ContentView Error: File doesn't exist at path: \\(fileURL.path)")
            return false
        }
        
        let fileExtension = fileURL.pathExtension.lowercased()
        
        // Check if it's a supported file type
        let supportedTypes = ["pdf", "mp4", "mov", "avi", "mkv", "webm", "m4v", "jpg", "jpeg", "png", "gif", "webp", "bmp", "tiff", "txt", "md", "json", "xml", "csv", "html", "htm"]
        
        guard supportedTypes.contains(fileExtension) else {
            print("ContentView: Unsupported file type: \\(fileExtension)")
            return false
        }
        
        // If there's an active tab, try to load the file there
        if let activeTab = viewModel.activeTab {
            // If the tab is in split view, determine which side to load to
            if activeTab.isSplitView {
                let targetSide = activeTab.activeSplitViewSide
                return viewModel.handleFileDropForSplit(fileURL: fileURL, for: activeTab.id, targetSide: targetSide)
            } else {
                // Load in the primary view
                return viewModel.handleFileDropForSplit(fileURL: fileURL, for: activeTab.id, targetSide: .primary)
            }
        } else {
            // No active tab, create a new one and load the file
            let newTab = viewModel.addNewTab(url: nil)
            
            // Ensure the new tab is properly activated and UI state is updated
            DispatchQueue.main.async {
                viewModel.isShowingHomepage = false
                viewModel.showingHistoryView = false
                viewModel.showingDownloadsView = false
                viewModel.showingCitationsView = false
            }
            
            return viewModel.handleFileDropForSplit(fileURL: fileURL, for: newTab.id, targetSide: .primary)
        }
        
        return false
    }

    // MARK: - Background Views
    @ViewBuilder
    private var backgroundView: some View {
        // Balanced liquid glass background for entire app
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.25),    // Comfortable brightness level
                        Color.blue.opacity(0.06),     // Light blue tint
                        Color.white.opacity(0.20)     // Gentle white highlight
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(
                Rectangle()
                    .fill(Color.white.opacity(0.12))  // Subtle base for good contrast
                )
                .ignoresSafeArea()
    }
    
    @ViewBuilder
    private var mainContentView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar with glass styling
            GlassPanel(style: .sidebar) {
                SidebarView()
                    .environmentObject(bookmarkManager)
                    .environmentObject(viewModel)
                    .environmentObject(assistantViewModel)
                    .frame(minWidth: 200)
                    .sidebarWidth(200)
                    .onPreferenceChange(TabPreviewHoverKey.self) { value in
                        self.hoveredTab = value
                    }
            }
        } detail: {
            // Detail view with enhanced glass styling
            GlassPanel(style: .main) {
                detailContentView
            }
        }
    }
    
    @ViewBuilder
    private var detailContentView: some View {
            if viewModel.isShowingHomepage || viewModel.tabs.isEmpty {
                // Enhanced homepage with liquid glass styling - full screen
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Enhanced Welcome Section with Animations
                    EnhancedWelcomeSection(
                        onNewTabAction: {
                            let newTab = viewModel.addNewTab(url: nil)
                            viewModel.switchToTab(id: newTab.id)
                        }, 
                        onAIAssistantAction: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                isAssistantVisible = true
                            }
                        }
                    )
                    .frame(maxWidth: 800)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    // Balanced liquid glass background for homepage
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.35),    // Much more reasonable brightness
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
                )
            } else {
                // Web view detail with glass container
                WebViewDetail(viewModel: viewModel, urlInput: $urlInput, isAssistantVisible: $isAssistantVisible)
                    .environmentObject(bookmarkManager)
                    .environmentObject(citationManager)
                    .environmentObject(assistantViewModel)
            }
    }
    
    @ViewBuilder
    private var overlayViews: some View {
        ZStack {
            // Floating assistant panel
            if isAssistantVisible {
                GlassPanel(style: .overlay) {
                    AssistantView(viewModel: assistantViewModel, webViewModel: viewModel)
                        .frame(width: 420, height: 600)
                }
                .position(
                    x: 300 + assistantPosition.width + assistantDragOffset.width,
                    y: 350 + assistantPosition.height + assistantDragOffset.height
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            assistantDragOffset = value.translation
                        }
                        .onEnded { value in
                            assistantPosition.width += value.translation.width
                            assistantPosition.height += value.translation.height
                            assistantDragOffset = .zero
                        }
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .opacity
                ))
                .zIndex(1000)
            }
            
            // Tab preview overlay - positioned to the right of the tab to avoid covering other tabs
            if let tabHover = hoveredTab {
                GlassCard(style: .floating) {
                    TabPreviewView(tab: tabHover.tab, isVisible: true)
                        .frame(width: 280, height: 180) // Slightly smaller to be less intrusive
                }
                // Position the preview to the right of the tab, with some offset
                .position(
                    x: min(tabHover.bounds.maxX + 150, (NSScreen.main?.frame.width ?? 1200) - 150), // Keep it on screen
                    y: tabHover.bounds.midY
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(999)
                .allowsHitTesting(false) // Prevent the preview from blocking clicks
            }
            
            // Split View Analysis overlay - show when split view is active and either manually toggled or has analysis content
            if let activeTab = viewModel.activeTab, 
               activeTab.isSplitView, 
               let analyzer = viewModel.splitViewAnalyzer,
               (isSplitViewAnalysisVisible || analyzer.isAnalyzing || !analyzer.combinedContext.isEmpty) {
                
                SplitViewAnalysisPanel(analyzer: analyzer)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
                    .zIndex(998)
            }
        }
    }

    var body: some View {
        ZStack {
            // Liquid glass background system
            backgroundView
            
            // Main interface with glass panels
            mainContentView
            
            // Overlay views
            overlayViews
        }
        .toolbar {
            // Left navigation controls with proper spacing to prevent overlap
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 4) {  // Tight spacing like the right side buttons
                    GlassButton(style: .secondary, action: { viewModel.goBack() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.primary)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .disabled(!viewModel.canGoBack)
                    .frame(width: 32, height: 28)
                    
                    GlassButton(style: .secondary, action: { viewModel.goForward() }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.primary)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .disabled(!viewModel.canGoForward)
                    .frame(width: 32, height: 28)
                    
                    GlassButton(style: .secondary, action: { viewModel.reload() }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.primary)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(width: 32, height: 28)
                }
                .padding(.trailing, 8)  // Add padding to separate from URL field
            }
            
            // Central URL field
            ToolbarItem(placement: .principal) {
                GlassTextField(
                    "Enter URL or search...",
                    text: $urlInput,
                    style: .primary
                )
                .onSubmit {
                    viewModel.loadURL(from: urlInput)
                    urlInput = viewModel.urlString
                }
                .frame(minWidth: 300, maxWidth: 500, minHeight: 34, maxHeight: 34)
            }
            
            // Right side buttons with proper spacing
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    // Bookmark button
                    GlassButton(style: .secondary, action: {
                        // Send notification to trigger bookmark flow
                        NotificationCenter.default.post(name: NSNotification.Name("AddBookmarkRequest"), object: nil)
                    }) {
                        Image(systemName: "bookmark")
                            .foregroundColor(.primary)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(width: 32, height: 28)
                    .help("Add Bookmark")
                    .disabled(viewModel.isShowingHomepage || viewModel.urlString.isEmpty)
                    
                    
                    // AI assistant button
                    GlassButton(
                        style: isAssistantVisible ? .accent : .secondary,
                        action: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                isAssistantVisible.toggle()
                            }
                        }
                    ) {
                        Image(systemName: isAssistantVisible ? "brain.head.profile.fill" : "brain.head.profile")
                            .foregroundColor(isAssistantVisible ? .white : .primary)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(width: 32, height: 28)
                    .help("Toggle AI Assistant")
                }
                .padding(.leading, 8)  // Add padding to separate from URL field
            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)  // Make toolbar background transparent
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isAssistantVisible)
        .animation(.easeInOut(duration: 0.3), value: hoveredTab)
        .onAppear {
            urlInput = viewModel.urlString
        }
        .onChange(of: viewModel.urlString) { newValue in
            urlInput = newValue
        }
        .onDrop(of: [.fileURL], isTargeted: $isDraggedOver) { providers in
            // Handle file drops with visual feedback
            guard let provider = providers.first else { return false }
            
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }
                
                DispatchQueue.main.async {
                    _ = handleMainViewFileDrop(fileURL: url)
                }
            }
            return true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleSplitViewAnalysis"))) { _ in
            // Toggle split view analysis via notification
            if let activeTab = viewModel.activeTab, activeTab.isSplitView {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isSplitViewAnalysisVisible.toggle()
                }
            }
        }
    }

    // REMOVED: Function to add the current page as a bookmark (moved to WebViewDetail)
    /*
    func addCurrentPageAsBookmark() {
        let currentTitle = viewModel.webView.title ?? "Untitled Page"
        let currentURLString = viewModel.urlString

        if !currentURLString.isEmpty, let url = URL(string: currentURLString) {
            bookmarkManager.addBookmark(name: currentTitle, url: url)
        } else {
            print("ContentView: Cannot add bookmark, invalid or empty URL.")
        }
    }
    */
}

// MARK: - New Tab Preview Component
struct TabPreviewView: View {
    let tab: BrowserTab
    let isVisible: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title bar
            HStack {
                Group {
                    if let faviconImage = tab.favicon {
                        faviconImage
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                    } else {
                        Image(systemName: "globe")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(.primary)
                    }
                }
                .frame(width: 16, height: 16)
                
                Text(tab.title ?? "New Tab")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.windowBackgroundColor))
            
            // Preview image
            if let preview = tab.preview {
                Image(nsImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 320, height: 220)
                    .clipped()
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
            } else {
                // Placeholder when no preview is available
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 320, height: 220)
                    .overlay(
                        VStack {
                            ProgressView()
                                .padding(.bottom, 5)
                            Text("Loading preview...")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    )
                    .cornerRadius(4)
            }
        }
        .padding(8)
    }
}

// MARK: - Tab Preview Popup Component
struct TabPreviewPopup: View {
    let tab: BrowserTab
    let isVisible: Bool
    
    var body: some View {
        ZStack {
            // Background with shadow - Increased corner radius for rounder appearance
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.98))
                .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 4)
            
            // Inner content
            VStack(alignment: .leading, spacing: 0) {
                // Title bar
                HStack {
                    Group {
                        if let faviconImage = tab.favicon {
                            faviconImage
                                .resizable()
                                .interpolation(.high)
                                .scaledToFit()
                        } else {
                            Image(systemName: "globe")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.primary)
                        }
                    }
                    .frame(width: 16, height: 16)
                    
                    Text(tab.title ?? "New Tab")
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .padding(.bottom, -16) // Blend with the content below
                )
                
                // Preview image
                if let preview = tab.preview {
                    Image(nsImage: preview)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 336, height: 220)
                        .clipped()
                        .cornerRadius(16) // Rounder corners for preview image
                        .padding([.horizontal, .bottom], 12) // More padding
                } else {
                    // Placeholder when no preview is available
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 320, height: 220)
                        .overlay(
                            VStack {
                                ProgressView()
                                    .padding(.bottom, 5)
                                Text("Loading preview...")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        )
                        .cornerRadius(16) // Rounder corners for placeholder
                        .padding([.horizontal, .bottom], 12) // More padding
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .animation(.easeInOut(duration: 0.15), value: isVisible)
    }
}

// MARK: - Redesigned Tab Item View for Sidebar
struct TabItemView: View {
    let tab: BrowserTab
    let isSelected: Bool
    let onClose: () -> Void
    let onSelect: () -> Void
    @EnvironmentObject var viewModel: WebViewModel

    // State for hover effect on the close button
    @State private var isHoveringClose = false
    // State for hover effect on the main item
    @State private var isHoveringItem = false
    // State for preview display
    @State private var showPreview = false
    // Delay preview appearance for better UX
    @State private var previewTask: DispatchWorkItem?
    // State to track if we're currently attempting a preview capture
    @State private var isCapturingPreview = false

    var body: some View {
        Button(action: {
            print("TabItemView: Tab clicked - calling onSelect()")
            
            // Select the tab
            onSelect()
            
            // IMPORTANT FIX: Ensure we always call switchToTab to reset panel view flags
            // This fixes the issue where users get stuck in History/Downloads/Citations panels
            viewModel.switchToTab(id: tab.id)

            // Refresh the preview when the tab is selected
            viewModel.captureTabPreview(for: tab.id)
            
            // Post notification that a tab was selected
            NotificationCenter.default.post(name: NSNotification.Name("TabSelected"), object: nil)

        }) {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 8) {
                    // Favicon - Display fetched Image or default globe
                    Group { // Use Group to conditionally apply modifiers
                        if let faviconImage = tab.favicon {
                            faviconImage // Display the actual fetched image
                                .resizable()
                                .interpolation(.high)
                                .scaledToFit()
                        } else {
                            Image(systemName: "globe") // Default placeholder
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(isSelected ? .primary : .secondary)
                        }
                    }
                    .frame(width: 18, height: 18, alignment: .center) // Consistent frame for icon area
                    .padding(1) // Add tiny padding if needed for alignment

                    // Title
                    Text(tab.title ?? "Loading...")
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundColor(isSelected ? .primary : .secondary)

                    Spacer() // Push close button to the right

                    // Close button - subtle, appears more clearly on hover
                    Button(action: {
                        // Stop event propagation
                        NSApp.sendEvent(NSEvent.mouseEvent(with: .leftMouseUp, 
                                               location: NSEvent.mouseLocation,
                                               modifierFlags: [],
                                               timestamp: ProcessInfo.processInfo.systemUptime,
                                               windowNumber: NSApp.mainWindow?.windowNumber ?? 0,
                                               context: nil,
                                               eventNumber: 0,
                                               clickCount: 1,
                                               pressure: 0)!)
                        onClose()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .medium))
                            .padding(5) // Slightly larger tap area
                            .background(isHoveringClose ? Color.secondary.opacity(0.2) : Color.clear) // Hover background
                            .clipShape(Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .opacity(isHoveringItem || isSelected ? 1.0 : 0.5) // Show clearly on hover/select
                    .onHover { hovering in
                        isHoveringClose = hovering
                    }
                    .padding(.trailing, -5) // Adjust spacing if needed
                }
                .padding(.horizontal, 8) // Horizontal padding for the whole item
                .padding(.vertical, 6)   // Vertical padding
                .background(
                     // Background changes based on selection and hover
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color("AppAccentColor").opacity(0.3) : (isHoveringItem ? Color.secondary.opacity(0.15) : Color.clear))
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle()) // Make the whole area tappable for selection
        .onHover { hovering in
            // Update hover state first
            isHoveringItem = hovering
            
            // Cancel any existing preview tasks
            previewTask?.cancel()
            
            if hovering {
                // Schedule the preview to appear with minimal delay
                let task = DispatchWorkItem { 
                    // Only capture preview if needed (not already available)
                    if tab.preview == nil || viewModel.doesTabNeedPreviewRefresh(id: tab.id) {
                        viewModel.captureTabPreview(for: tab.id)
                    }
                    
                    // Show preview regardless of whether we just captured it
                    DispatchQueue.main.async {
                        self.showPreview = true
                    }
                }
                
                previewTask = task
                // Use a longer delay to reduce unwanted previews when quickly moving between tabs
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
            } else {
                // Hide preview without additional async calls
                showPreview = false
            }
        }
        // Set up tab preview through preference - only update when both conditions are met to avoid frequent updates
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: TabPreviewHoverKey.self,
                        value: isHoveringItem && showPreview && tab.preview != nil ? TabHoverInfo(tab: tab, bounds: geometry.frame(in: .global)) : nil
                    )
            }
        )
        .onAppear {
            // Only capture when needed
            if tab.preview == nil || viewModel.doesTabNeedPreviewRefresh(id: tab.id) {
                // Use a slight delay to prevent all tabs capturing at once during app startup
                DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.1...0.5)) {
                    viewModel.captureTabPreview(for: tab.id)
                }
            }
        }
    }
}

// MARK: - Custom Preference Key for the Bookmark Button
struct BookmarkButtonKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

// MARK: - Custom Popover Implementation
struct Popover<Content: View>: View {
    @Binding var isPresented: Bool
    let arrowEdge: Edge
    let content: () -> Content
    
    var body: some View {
        NSPopoverWrapper(isPresented: $isPresented, 
                       arrowEdge: arrowEdge, 
                       content: content)
    }
}

// MARK: - NSViewRepresentable for NSPopover
struct NSPopoverWrapper<Content: View>: NSViewRepresentable {
    @Binding var isPresented: Bool
    let arrowEdge: Edge
    let content: () -> Content
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        
        // Create a hosting controller for the SwiftUI content
        let hostingController = NSHostingController(rootView: content())
        hostingController.sizingOptions = .preferredContentSize
        
        // Create and configure the popover
        context.coordinator.popover.contentViewController = hostingController
        context.coordinator.popover.behavior = .transient
        context.coordinator.popover.animates = true
        context.coordinator.popover.delegate = context.coordinator
        
        // Show the popover when isPresented changes to true
        if isPresented {
            DispatchQueue.main.async {
                context.coordinator.showPopover(from: view, edge: arrowEdge)
            }
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update the hosting controller's rootView if needed
        if let contentViewController = context.coordinator.popover.contentViewController as? NSHostingController<Content> {
            contentViewController.rootView = content()
        }
        
        // Show or hide the popover based on isPresented
        if isPresented != context.coordinator.popover.isShown {
            if isPresented {
                context.coordinator.showPopover(from: nsView, edge: arrowEdge)
            } else {
                context.coordinator.popover.close()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }
    
    class Coordinator: NSObject, NSPopoverDelegate {
        var popover = NSPopover()
        @Binding var isPresented: Bool
        
        init(isPresented: Binding<Bool>) {
            self._isPresented = isPresented
            super.init()
        }
        
        func showPopover(from view: NSView, edge: Edge) {
            let rect: NSRect
            switch edge {
            case .top:
                rect = NSRect(x: view.frame.midX, y: view.frame.minY, width: 0, height: 0)
            case .bottom:
                rect = NSRect(x: view.frame.midX, y: view.frame.maxY, width: 0, height: 0)
            case .leading:
                rect = NSRect(x: view.frame.maxX, y: view.frame.midY, width: 0, height: 0)
            case .trailing:
                rect = NSRect(x: view.frame.minX, y: view.frame.midY, width: 0, height: 0)
            }
            
            popover.show(relativeTo: rect, of: view, preferredEdge: NSRectEdge(rawValue: UInt(edge.rawValue))!)
        }
        
        func popoverDidClose(_ notification: Notification) {
            isPresented = false
        }
    }
}

// MARK: - Bookmark Folder Selection View for Popover
// Renamed from AddBookmarkSheetView to reflect its new usage

struct BookmarkFolderSelectionView: View {
    @EnvironmentObject var bookmarkManager: BookmarkManager
    
    let bookmarkName: String
    let bookmarkUrlString: String
    let onSelect: (UUID?) -> Void // Callback with optional folder ID (nil for root)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add \"\(bookmarkName)\" to:")
                .font(.headline)
                .padding(.bottom, 4)
            
            // Button to add to root
            Button {
                onSelect(nil) // Pass nil for root
            } label: {
                Label("Bookmarks Bar", systemImage: "menubar.rectangle")
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle()) // Make entire button tappable
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
            
            Divider()
            
            Text("Folders")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Scrollable list of folders
            ScrollView {
                // Filter for root folders
                let rootFolders = bookmarkManager.rootItems.compactMap { item -> BookmarkFolder? in
                    guard case .folder(let folder) = item else { return nil }
                    return folder
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    if rootFolders.isEmpty {
                        Text("No folders available.")
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        // Display recursive folder list
                        ForEach(rootFolders) { folder in
                            FolderSelectionRowView(folder: folder, onSelect: onSelect)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Recursive View for Folder Selection (New)

private struct FolderSelectionRowView: View {
    let folder: BookmarkFolder
    let onSelect: (UUID?) -> Void // Use the same callback type
    @State private var isExpanded: Bool = false // Allow expansion/collapse

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            // Indent children slightly
            VStack(alignment: .leading) {
                 // Add a button to select *this* folder
                 Button {
                     onSelect(folder.id)
                 } label: {
                     Text("Add to this folder")
                 }
                 .buttonStyle(.link) // Use link style for less emphasis
                 .padding(.leading) 
                 .padding(.bottom, 2)
                 
                 // Recursively list children folders
                let childFolders = folder.children.compactMap { item -> BookmarkFolder? in
                     guard case .folder(let childFolder) = item else { return nil }
                     return childFolder
                }
                
                 ForEach(childFolders) { childFolder in
                     FolderSelectionRowView(folder: childFolder, onSelect: onSelect)
                 }
            }
            .padding(.leading) // Apply padding to the VStack containing children
            
        } label: {
             // Label for the DisclosureGroup (the folder itself)
            Label(folder.name, systemImage: "folder.fill")
                 .padding(.vertical, 2)
                 // Make the label itself tappable to select the folder
                 .contentShape(Rectangle()) // Make the whole label area tappable
                 .onTapGesture {
                     // Toggle expansion AND select folder if tapped directly
                     // isExpanded.toggle() // Let the default DisclosureGroup handle expansion
                     // Decided against selecting on label tap, use the button inside.
                 }
                 // Add context menu or direct selection button if needed, 
                 // but the button inside DisclosureGroup is clearer.
        }
    }
}

// MARK: - NSViewRepresentable for Tab Preview Window
struct TabPreviewNSViewWrapper: NSViewRepresentable {
    let tab: BrowserTab
    let isVisible: Bool
    let trigger: TabItemView // Reference to trigger view
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Handle visibility changes
        if isVisible && context.coordinator.previewWindow == nil {
            // Create and show preview window
            DispatchQueue.main.async {
                context.coordinator.createPreviewWindow(for: tab, attachedTo: nsView)
            }
        } else if !isVisible && context.coordinator.previewWindow != nil {
            // Hide preview window
            DispatchQueue.main.async {
                context.coordinator.closePreviewWindow()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        var previewWindow: NSWindow?
        var previewHostingController: NSHostingController<TabPreviewView>?
        
        func createPreviewWindow(for tab: BrowserTab, attachedTo view: NSView) {
            // Create content
            let previewContent = TabPreviewView(tab: tab, isVisible: true)
            let hostingController = NSHostingController(rootView: previewContent)
            self.previewHostingController = hostingController
            
            // Create window
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 336, height: 270),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentViewController = hostingController
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            window.level = .floating
            
            // Critical: Make the window non-activating so it doesn't steal focus or block clicks
            window.isMovableByWindowBackground = false
            window.ignoresMouseEvents = true
            
            // Position window next to view
            if let viewWindow = view.window, let screen = viewWindow.screen {
                let viewFrameInScreen = viewWindow.convertToScreen(view.convert(view.bounds, to: nil))
                var newPoint = NSPoint(
                    x: viewFrameInScreen.maxX + 20,
                    y: viewFrameInScreen.midY - (window.frame.height / 2)
                )
                
                // Ensure window stays on screen
                if newPoint.x + window.frame.width > screen.visibleFrame.maxX {
                    newPoint.x = viewFrameInScreen.minX - window.frame.width - 20
                }
                
                window.setFrameOrigin(newPoint)
            }
            
            window.orderFront(nil)
            self.previewWindow = window
        }
        
        func closePreviewWindow() {
            previewWindow?.close()
            previewWindow = nil
            previewHostingController = nil
        }
    }
}

// Add a preview provider if needed, ensuring necessary environment objects are provided
#Preview {
    ContentView()
}

// MARK: - Tab Preview Hover Preference Key
struct TabHoverInfo: Equatable {
    let tab: BrowserTab
    let bounds: CGRect
    
    static func == (lhs: TabHoverInfo, rhs: TabHoverInfo) -> Bool {
        lhs.tab.id == rhs.tab.id && lhs.bounds == rhs.bounds
    }
}

struct TabPreviewHoverKey: PreferenceKey {
    static var defaultValue: TabHoverInfo? = nil
    static func reduce(value: inout TabHoverInfo?, nextValue: () -> TabHoverInfo?) {
        value = nextValue() ?? value
    }
}

// MARK: - Window Sizes Environment Object for Preview Positioning
private struct WindowSizeKey: EnvironmentKey {
    static let defaultValue: CGFloat = 200 // Default minimum width of sidebar
}

extension EnvironmentValues {
    var sidebarWidth: CGFloat {
        get { self[WindowSizeKey.self] }
        set { self[WindowSizeKey.self] = newValue }
    }
}

// Extension to add the environment modifier
extension View {
    func sidebarWidth(_ width: CGFloat) -> some View {
        environment(\.sidebarWidth, width)
    }
}

// MARK: - Enhanced Welcome Section with Animations

struct EnhancedWelcomeSection: View {
    let onNewTabAction: () -> Void
    let onAIAssistantAction: () -> Void
    
    // Optimized animation states
    @State private var breathingScale: CGFloat = 1.0
    @State private var iconElements: [IconElement] = []
    @State private var particleOpacity: Double = 0.4
    @State private var gradientPhase: Double = 0
    @State private var floatingOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var orbitalRotation: Double = 0
    @State private var logoGlow: Double = 0.3
    
    // Reduced particle system for performance
    @State private var particles: [ParticleData] = []
    
    var body: some View {
        ZStack {
            // Background with crystal clear glass effect
            RoundedRectangle(cornerRadius: 32)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,              // Completely transparent
                            Color.blue.opacity(0.002), // Nearly invisible hint
                            Color.clear               // Completely transparent
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 32)
                        .fill(Color.clear)  // No material background for crystal clarity
                )
                .overlay(
                    // Nearly invisible floating particles for crystal glass effect
                    ZStack {
                        ForEach(particles.indices, id: \.self) { index in
                            Circle()
                                .fill(Color.blue.opacity(0.01)) // Nearly invisible particles
                                .frame(width: particles[index].size, height: particles[index].size)
                                .position(particles[index].position)
                                .opacity(particleOpacity * 0.1) // Much more transparent
                                .blur(radius: 0.5)
                        }
                    }
                    .clipped()
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.clear,           // Completely invisible border
                                    Color.clear,           // Completely invisible border
                                    Color.clear,           // Completely invisible border
                                    Color.clear            // Completely invisible border
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0  // No border width for crystal glass
                        )
                )
            
            VStack(spacing: 36) {
                // Spectacular iBrowsy Logo
                ZStack {
                    // Outer energy ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(logoGlow),
                                    Color.blue.opacity(logoGlow * 0.6),
                                    Color.blue.opacity(logoGlow)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(pulseScale)
                        .opacity(0.7)
                    
                    // Orbital elements
                    ForEach(iconElements.indices, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue.opacity(0.8))
                            .frame(width: 8, height: 8)
                            .offset(x: 90)
                            .rotationEffect(.degrees(orbitalRotation + Double(index * 72)))
                            .scaleEffect(breathingScale * 0.8)
                    }
                    
                    // Main logo background - Subtle frosted glass
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.15),   // Subtle blue
                                    Color.blue.opacity(0.1),    // Pure light blue
                                    Color.blue.opacity(0.12)    // Light blue
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(Color.white.opacity(0.25))
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(breathingScale)
                        .overlay(
                            // Glass highlight - Subtle border
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.2),  // Subtle white highlight
                                            Color.white.opacity(0.1)   // Gentle glow
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    
                    // Dynamic "i" Logo
                    VStack(spacing: 8) {
                        // Dot of the "i"
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white, Color.blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 16, height: 16)
                            .scaleEffect(logoGlow + 0.7)
                        
                        // Stem of the "i" with modern styling
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white, Color.blue.opacity(0.4)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 12, height: 60)
                            .overlay(
                                // Inner glow effect
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 4, height: 50)
                            )
                    }
                    .offset(y: floatingOffset)
                    
                    // Connecting network lines
                    Path { path in
                        path.move(to: CGPoint(x: -20, y: -30))
                        path.addLine(to: CGPoint(x: 0, y: -10))
                        path.addLine(to: CGPoint(x: 20, y: -30))
                        path.move(to: CGPoint(x: -25, y: 10))
                        path.addLine(to: CGPoint(x: 0, y: 30))
                        path.addLine(to: CGPoint(x: 25, y: 10))
                    }
                    .stroke(
                        Color.white.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                    )
                    .scaleEffect(breathingScale * 0.9)
                    .opacity(logoGlow + 0.3)
                }
                .shadow(
                    color: Color.clear,  // Completely invisible shadow for crystal glass
                    radius: 0,
                    x: 0,
                    y: 0
                )
                
                // Elegant Welcome Text
                VStack(spacing: 16) {
                    Text("iBrowsy")
                        .font(.system(size: 44, weight: .light, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.primary,
                                    Color.blue.opacity(0.8),
                                    Color.primary
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .scaleEffect(breathingScale * 0.99 + 0.01)
                    
                    Text("Browse into the FUTURE, with Ai powered browsing")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .opacity(0.85)
                }
                
                // Enhanced Feature Chips with Animations
                HStack(spacing: 24) {
                    AnimatedFeatureChip(
                        icon: "brain.head.profile",
                        text: "Ai Powered",
                        color: .purple,
                        delay: 0
                    )
                    AnimatedFeatureChip(
                        icon: "shield.fill",
                        text: "Ai AD Blocker",
                        color: .blue,
                        delay: 0.2
                    )
                    AnimatedFeatureChip(
                        icon: "pencil.and.scribble",
                        text: "Sketch Mode",
                        color: .blue,
                        delay: 0.4
                    )
                    AnimatedFeatureChip(
                        icon: "rectangle.split.2x1",
                        text: "Split View",
                        color: .green,
                        delay: 0.6
                    )
                }
                .offset(y: floatingOffset * 0.5)
                
                // Enhanced Action Buttons
                HStack(spacing: 20) {
                    EnhancedActionButton(
                        icon: "plus.circle.fill",
                        text: "New Tab",
                        style: .primary,
                        action: onNewTabAction
                    )
                    
                    EnhancedActionButton(
                        icon: "brain.head.profile",
                        text: "AI Assistant",
                        style: .secondary,
                        action: onAIAssistantAction
                    )
                }
                .offset(y: floatingOffset * 0.3)
            }
            .padding(.vertical, 48)
            .padding(.horizontal, 40)
        }
        .frame(width: 800, height: 600)
        .onAppear {
            generateParticles()
            // Start animations with slight delays for smoother performance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                startAnimations()
            }
        }
    }
    
    private func startAnimations() {
        // Optimized breathing animation
        withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
            breathingScale = 1.05
        }
        
        // Gentle pulse animation
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
            pulseScale = 1.08
        }
        
        // Orbital rotation for elements
        withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
            orbitalRotation = 360
        }
        
        // Logo glow animation
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            logoGlow = 0.8
        }
        
        // Subtle floating animation
        withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
            floatingOffset = -6
        }
        
        // Optimized particle animation
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            particleOpacity = 0.7
        }
    }
    
    private func generateParticles() {
        // Reduced particle count for better performance
        particles = (0..<8).map { _ in
            ParticleData(
                position: CGPoint(
                    x: CGFloat.random(in: 100...800),
                    y: CGFloat.random(in: 100...550)
                ),
                size: CGFloat.random(in: 3...5)
            )
        }
        
        // Generate orbital elements for the logo
        iconElements = (0..<5).map { _ in
            IconElement()
        }
    }
}

// MARK: - Supporting Components

struct ParticleData {
    let position: CGPoint
    let size: CGFloat
}

struct IconElement {
    let id = UUID()
}

struct AnimatedFeatureChip: View {
    let icon: String
    let text: String
    let color: Color
    let delay: Double
    
    @State private var isAnimating = false
    @State private var glowIntensity: Double = 0.3
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(isAnimating ? 1.2 : 1.0)
            
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.clear)  // Crystal clear background
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.clear,  // No border for crystal glass
                                    Color.clear   // No border for crystal glass
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0
                        )
                )
        )
        .shadow(color: Color.clear, radius: 0, x: 0, y: 0)  // No shadow for crystal glass
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowIntensity = 0.8
                }
            }
        }
    }
}

struct EnhancedActionButton: View {
    let icon: String
    let text: String
    let style: ButtonStyle
    let action: () -> Void
    
    enum ButtonStyle {
        case primary, secondary
    }
    
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var shimmerOffset: CGFloat = -200
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                Text(text)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
            }
            .foregroundColor(textColor)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    // Base background - Subtle frosted glass
                    RoundedRectangle(cornerRadius: 16)
                        .fill(backgroundGradient)  // Restored background gradient
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.bar)  // Bright bar material for gorgeous glass
                        )
                    
                    // Shimmer effect
                    if isHovered {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        Color.white.opacity(0.3),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .offset(x: shimmerOffset)
                            .clipped()
                    }
                    
                    // Border - Subtle glass border
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(borderColor, lineWidth: isHovered ? 1 : 0.5)  // Subtle border
                }
            )
            .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.05 : 1.0))
            .shadow(
                color: shadowColor,  // Restored subtle shadow
                radius: isHovered ? 12 : 8,
                x: 0,
                y: isHovered ? 6 : 4
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
            
            if hovering {
                withAnimation(.linear(duration: 0.8)) {
                    shimmerOffset = 200
                }
            } else {
                shimmerOffset = -200
            }
        }
        .pressEvents(
            onPress: {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    isPressed = true
                }
            },
            onRelease: {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    isPressed = false
                }
            }
        )
    }
    
    private var textColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return .primary
        }
    }
    
    private var backgroundGradient: LinearGradient {
        switch style {
        case .primary:
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.5),   // Super bright white base
                    Color.blue.opacity(0.3),    // Pure blue accent
                    Color.white.opacity(0.45)   // Gorgeous bright highlight
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .secondary:
            return LiquidGlassStyle.secondaryGlass
        }
    }
    
    private var borderColor: LinearGradient {
        switch style {
        case .primary:
            return LinearGradient(
                colors: [Color.white.opacity(0.7), Color.blue.opacity(0.4)],  // Super bright borders
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .secondary:
            return LiquidGlassStyle.subtleBorder
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .primary:
            return Color.blue.opacity(0.2)    // Pure blue shadow
        case .secondary:
            return Color.blue.opacity(0.15)   // Light blue shadow
        }
    }
}