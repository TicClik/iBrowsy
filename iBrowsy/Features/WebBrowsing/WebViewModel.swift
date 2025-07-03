import SwiftUI
import WebKit
import Combine // Needed for ObservableObject
import Foundation // Make explicit import for Bundle

#if os(macOS)
import AppKit
#endif

// Define WKContextMenuElementInfo in case it's not available in the WebKit version
#if !canImport(WKContextMenuElementInfo)
@objc protocol WKContextMenuElementInfo: NSObjectProtocol {
    @objc var linkURL: URL? { get }
    @objc var imageURL: URL? { get }
    @objc var mediaURL: URL? { get }
}
#endif

// Add an extension for WKUIDelegate to ensure correct protocol conformance
extension WKUIDelegate {
    // Default implementation was here - now removed.
    // We still need the extension block if other default implementations are needed later.
}

// Import the BrowserReader for the BrowserReaderManager
import SwiftUI

// --- NEW: Enum to represent split view side ---
enum SplitViewSide {
    case primary
    case secondary
}

// Represents a single browser tab
struct BrowserTab: Identifiable {
    let id = UUID()
    let primaryWebView: WKWebView // RENAMED from webView
    var secondaryWebView: WKWebView? = nil // NEW: Optional secondary view
    var urlString: String // Represents primary view's URL initially, then active split?
    var title: String?    // Represents primary view's title initially, then active split?
    var isActive: Bool
    var favicon: Image? 
    var isPinned: Bool = false
    var isSplitView: Bool = false // NEW: Split view state
    var activeSplitViewSide: SplitViewSide = .primary // NEW: Track active split
    var primaryPaneDesiredWidth: CGFloat? = nil // NEW: To store user-defined width for primary pane
    var preview: NSImage? = nil // NEW: Store preview thumbnail for hover
    var isLoading: Bool = false // NEW: Track loading state
    var loadingProgress: Double = 0.0 // NEW: Track loading progress
    var lastLoadedPageTitle: String? = nil // NEW: Track the last loaded page title
}

// Represents a history item
struct HistoryItem: Identifiable, Codable {
    let id = UUID()
    let title: String
    let urlString: String
    let date: Date
    
    enum CodingKeys: String, CodingKey {
        case id, title, urlString, date
    }
}

// Represents a download item
struct DownloadItem: Identifiable, Codable {
    let id = UUID()
    var filename: String
    let urlString: String
    let date: Date
    var fileSize: Int64
    var progress: Double
    var state: DownloadState
    var localURL: URL?
    
    enum DownloadState: Int, Codable {
        case inProgress
        case completed
        case failed
    }
    
    enum CodingKeys: String, CodingKey {
        case id, filename, urlString, date, fileSize, progress, state, localURL
    }
}

@MainActor // Ensure all methods in this class run on the main thread
class WebViewModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    
    // MARK: - AI Privacy Manager
    @Published var privacyManager = AIPrivacyManager()
    // Current primary webView (the active tab's primary webView)
    // NOTE: This might need refinement later if secondary view needs direct access
    var webView: WKWebView { 
        return activeTab?.primaryWebView ?? createNewWebView() // Use primary for now
    }
    
    // Collection of browser tabs
    @Published var tabs: [BrowserTab] = []
    // Current active tab
    @Published var activeTab: BrowserTab?
    
    // Published properties to drive UI updates
    @Published var urlString: String = "Home Screen" // Default to homepage URL
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var error: Error? = nil // Optional: To show errors
    @Published var pageTitle: String? = nil
    @Published var isShowingHomepage: Bool = true // Start by showing the homepage
    
    // History and download tracking
    @Published var historyItems: [HistoryItem] = []
    @Published var downloadItems: [DownloadItem] = []
    @Published var showingHistoryView: Bool = false
    @Published var showingDownloadsView: Bool = false
    @Published var showingCitationsView: Bool = false
    
    // Add Reader Mode Manager
    // REMOVED: Reader mode manager as per user request

    // Add these properties:
    @Published var isActivePageLoaded: Bool = false
    
    // Also add to Reader Mode Manager
    // REMOVED: Reader mode availability as per user request
    
    // NEW: Properties for navigation error handling
    @Published var navigationErrorOccurred: Bool = false
    @Published var navigationError: String? = nil
    
    // Add AppStorage for search provider
    @AppStorage("defaultSearchProvider") private var defaultSearchProvider: SearchProvider = .duckDuckGo

    private var cancellables = Set<AnyCancellable>()
    private var activeDownloads: [UUID: WKDownload] = [:]

    // Special URL string for the homepage
            let homepageURLString = "ibrowsy://home"
    
    // Add AppStorage for custom homepage
    @AppStorage("defaultHomepageURL") private var defaultHomepageURL: String = ""
    
    // Get actual homepage URL to load
    var effectiveHomepageURL: String {
        return !defaultHomepageURL.isEmpty ? defaultHomepageURL : homepageURLString
    }

    // NEW: Dictionary to track when previews need refreshing
    private var previewRefreshNeeded: [UUID: Bool] = [:]

    // --- NEW: Static preview instance for use in SwiftUI previews ---
    /// Shared instance for SwiftUI previews to avoid multiple initializations
    static let previewInstance: WebViewModel = {
        let instance = WebViewModel()
        return instance
    }()

    // Add this property to expose the assistantViewModel
    weak var assistantViewModel: AssistantViewModel?
    
    // Track WebViews that have PiP enabled
    var pipEnabledWebViews: Set<ObjectIdentifier> = []
    
    // Add cooldown tracking for auto-PiP to prevent infinite loops
    private var lastAutoPiPTrigger: Date?
    private let autoPiPCooldown: TimeInterval = 0.1 // 0.1 seconds between auto-PiP checks

    // Add a new property to track PiP check times
    private var lastPiPCheckTime: [String: Date] = [:]

    // MARK: - Split-View Analysis Properties
    @Published var splitViewAnalyzer: SplitViewAnalyzer?
    
    // MARK: - Screen Annotation Properties

    
    // MARK: - File Content Tracking
    // Track when tabs are displaying file content (to preserve file URLs in address bar)
    private var fileContentTabs: [UUID: URL] = [:]
    
    override init() {
        super.init() // Call NSObject's init first since we'll use self below
        
        // Don't create an initial tab automatically
        tabs = []
        activeTab = nil
        
        // Show homepage by default
        isShowingHomepage = true
        
        loadHistoryFromDisk()
        loadDownloadsFromDisk()
        
        showingCitationsView = false
        
        print("WebViewModel: Initialized with homepage view only. No tabs created.")
    }
    
    // Create a new WKWebView with proper configuration
    private func createNewWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        
        // Configure preferences for better file handling and media support
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self // ViewModel handles navigation
        webView.uiDelegate = self // ViewModel handles UI events (like popups)
        
        // Set modern User Agent to get current website versions
        let modernUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Version/18.0 Safari/537.36"
        webView.customUserAgent = modernUserAgent
        
        // Additional settings for better file support
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        
        // Configure AI Privacy Protection
        privacyManager.configureWebView(webView)
        
        // Ensure bundle access is properly handled
                    if let bundle = Bundle(identifier: "com.dayanfernandez.iBrowsy") {
            // Use bundle if needed
            print("WebViewModel: Successfully accessed application bundle")
        } else {
            // This will prevent "Unable to create bundle at URL (null)" errors
            print("WebViewModel: Using main bundle as fallback")
        }
        
        return webView
    }
    
    // Create a new browser tab
    private func createNewTab() -> BrowserTab {
        let primaryWebView = createNewWebView()
        return BrowserTab(
            primaryWebView: primaryWebView, // Use renamed property
            // secondaryWebView: nil, // Explicitly nil initially
            urlString: homepageURLString,
            title: "New Tab",
            isActive: true,
            favicon: nil,
            isPinned: false,
            isSplitView: false, // Initialize as not split
            activeSplitViewSide: .primary // Set default active split
        )
    }
    
    // --- NEW: Create Tab Structure ONLY ---
    // This creates the BrowserTab struct and its WebViews without adding to the list or loading
    func createNewTabStructure(url: URL?, title: String?, isPinned: Bool) -> BrowserTab {
        let primaryWebView = createNewWebView()
        return BrowserTab(
            primaryWebView: primaryWebView,
            urlString: url?.absoluteString ?? homepageURLString,
            title: title ?? (url == nil ? "New Tab" : nil), // Set title or let WKWebView decide
                            isActive: false, // Tabs created are initially inactive
            favicon: nil,
            isPinned: isPinned,
            isSplitView: false, // Default to not split
            activeSplitViewSide: .primary
        )
    }
    
    // --- NEW: Method to explicitly show the homepage ---
    func showHomepage() {
        activeTab = nil // No active tab when showing homepage
        isShowingHomepage = true
        showingHistoryView = false
        showingDownloadsView = false
        showingCitationsView = false
        urlString = effectiveHomepageURL // Use effective homepage URL instead of hardcoded one
        pageTitle = "Home"
        isLoading = false
        canGoBack = false
        canGoForward = false
        objectWillChange.send() // Notify UI
    }
    
    // Set up Combine subscribers for the active tab
    // NOTE: This needs significant rework to correctly reflect the active split's state.
    // For now, it still primarily reflects the primary view.
    // TODO: Refactor this or rely on delegate methods.
    private func setupActiveTabObservers() {
        cancellables.removeAll()
        guard let tab = activeTab, let tabIndex = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        
        // Observe PRIMARY WKWebView properties
        tab.primaryWebView.publisher(for: \.canGoBack)
            .assign(to: \.canGoBack, on: self)
            .store(in: &cancellables)
        
        tab.primaryWebView.publisher(for: \.canGoForward)
            .assign(to: \.canGoForward, on: self)
            .store(in: &cancellables)
        
        // Consider combining isLoading from both views if split?
        tab.primaryWebView.publisher(for: \.isLoading)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        // URL and Title should reflect the *active* split later.
        // For now, they reflect the primary view.
        tab.primaryWebView.publisher(for: \.url)
            .map { $0?.absoluteString ?? self.homepageURLString }
            .filter { $0 != self.homepageURLString || !self.isShowingHomepage }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] urlString in
                guard let self = self else { return }
                self.urlString = urlString // Update main URL bar
                if let index = self.tabs.firstIndex(where: { $0.id == tab.id }) {
                    self.tabs[index].urlString = urlString // Update tab model's primary URL
                }
            }
            .store(in: &cancellables)
            
        tab.primaryWebView.publisher(for: \.title)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] title in
                guard let self = self else { return }
                self.pageTitle = title // Update main title
                if tabIndex < self.tabs.count {
                    var updatedTab = self.tabs[tabIndex]
                    updatedTab.title = title ?? "New Tab" // Update tab model's primary title
                    self.tabs[tabIndex] = updatedTab
                }
            }
            .store(in: &cancellables)
    }
    
    // --- NEW: Set Active Split Side ---
    // This updates which split is considered "active" for a given tab
    func setActiveSplitSide(for tabId: UUID, side: SplitViewSide) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { 
            print("WebViewModel: setActiveSplitSide called with invalid tab ID")
            return 
        }
        
        // Only proceed if we're actually changing the side or forcing an update
        let currentSide = tabs[index].activeSplitViewSide
        if currentSide != side {
            print("WebViewModel: setActiveSplitSide called for tab \(tabId) - changing to \(side) from \(currentSide)")
            
            // Update the active side for the tab
            tabs[index].activeSplitViewSide = side
            print("WebViewModel: Set active split side to \(side) for tab \(tabId)")
            
            // Refresh the activeTab reference to ensure it has the updated activeSplitViewSide
            if activeTab?.id == tabId {
                activeTab = tabs[index]
            }
            
            // Update published properties based on the newly active side
            updatePublishedStateFromActiveSplit()
            
            // Additional focus setting - ensure WebView gets keyboard focus
            DispatchQueue.main.async {
                // Force UI refresh
                self.forceUIRefresh(for: tabId)
                
                // Explicitly set first responder status - may be redundant with WebView's own focus code
                // but better to be thorough
                if side == .primary, let window = self.tabs[index].primaryWebView.window {
                    window.makeFirstResponder(self.tabs[index].primaryWebView)
                } else if side == .secondary, let secondaryWebView = self.tabs[index].secondaryWebView, 
                          let window = secondaryWebView.window {
                    window.makeFirstResponder(secondaryWebView)
                }
            }
        } else {
            print("WebViewModel: setActiveSplitSide called but already on \(side)")
            
            // Even if the side hasn't changed, force a state update to ensure UI consistency
            if activeTab?.id == tabId {
                updatePublishedStateFromActiveSplit()
            }
        }
    }
    
    // --- NEW: Update Published State based on Active Split ---
    // This updates the published properties based on which split is active
    func updatePublishedStateFromActiveSplit() {
        guard let tab = activeTab else { return }
        
        // Determine which WebView to use based on the active split
        let activeWebView: WKWebView
        let activeSide = tab.activeSplitViewSide
        
        switch activeSide {
        case .primary:
            activeWebView = tab.primaryWebView
            print("WebViewModel: Updated published state from active split: primary")
        case .secondary:
            if let secondaryWebView = tab.secondaryWebView {
                activeWebView = secondaryWebView
                print("WebViewModel: Updated published state from active split: secondary")
            } else {
                // Fallback to primary if secondary doesn't exist
                activeWebView = tab.primaryWebView
                print("WebViewModel WARNING: Tried to use secondary view but it doesn't exist")
            }
        }
        
        // Update published properties from the active WebView
        DispatchQueue.main.async {
            // First update navigation state properties
            self.canGoBack = activeWebView.canGoBack
            self.canGoForward = activeWebView.canGoForward
            
            // Critical fix: properly update isLoading state for the active view
            self.isLoading = activeWebView.isLoading
            
            self.pageTitle = activeWebView.title
            
            // Then update URL string - this is critical for URL bar sync
            // Check if this tab is displaying file content and preserve the original file URL
            if let fileURL = self.fileContentTabs[tab.id] {
                self.urlString = fileURL.absoluteString
                print("WebViewModel: Preserved file URL for display: \(fileURL.absoluteString)")
            } else {
                let currentURL = activeWebView.url?.absoluteString ?? self.homepageURLString
                self.urlString = currentURL
                print("WebViewModel: Updated URL string to: \(currentURL)")
            }
            
            // Explicitly trigger UI update
            self.objectWillChange.send()
        }
    }
    
    // Create and add a new browser tab
    func addNewTab(urlToLoad: String?) {
        print("WebViewModel: Created new tab")
        
        // Start with a new tab that's not active yet
        var newTab = createNewTab()
        
        // Add the tab to our collection first
        self.tabs.append(newTab)
        
        // Get the index of the new tab
        let tabIndex = self.tabs.count - 1
        
        // Now set it as active to trigger UI updates
        self.tabs[tabIndex].isActive = true
        self.activeTab = self.tabs[tabIndex]
        self.setupActiveTabObservers()
        
        // Handle the URL to load:
        // First preference is explicit URL,
        // otherwise load homepage if effectiveHomepageURL is not empty
        if let urlString = urlToLoad, !urlString.isEmpty {
            loadURL(from: urlString)
        } else if !defaultHomepageURL.isEmpty {
            // If we have a custom homepage, load it 
            loadURL(from: defaultHomepageURL)
        } else {
            // Otherwise show the default homepage
            loadURL(from: homepageURLString)
        }
    }
    
    // Variant that returns the new tab for code that relies on the return value
    func addNewTab(url: URL? = nil) -> BrowserTab {
        // First create and activate the tab
        let urlString = url?.absoluteString
        
        // Start with a new tab that's not active yet
        var newTab = createNewTab()
        
        // Add the tab to our collection first
        self.tabs.append(newTab)
        
        // Get the index of the new tab
        let tabIndex = self.tabs.count - 1
        
        // Now set it as active to trigger UI updates
        self.tabs[tabIndex].isActive = true
        self.activeTab = self.tabs[tabIndex]
        self.setupActiveTabObservers()
        
        // Handle the URL to load:
        // First preference is explicit URL,
        // otherwise load homepage if effectiveHomepageURL is not empty
        if let urlString = urlString, !urlString.isEmpty {
            loadURL(from: urlString)
        } else if !defaultHomepageURL.isEmpty {
            // If we have a custom homepage, load it 
            loadURL(from: defaultHomepageURL)
        } else {
            // Otherwise show the default homepage
            loadURL(from: homepageURLString)
        }
        
        return newTab
    }

    // Load a URL in the active tab
    func loadURL(from urlString: String) {
        // Validate basic URL format before proceeding
        guard !urlString.isEmpty else {
            print("WebViewModel: Cannot load empty URL")
            return
        }
        
        // If no active tab exists, create one first
        if activeTab == nil {
            print("WebViewModel: No active tab, creating one before loading URL")
            addNewTab(urlToLoad: nil)
            
            // If tab creation failed, return
            if activeTab == nil { 
                print("WebViewModel Error: Failed to create initial tab for loading.")
                return 
            }
        }
        
        // Don't proceed without an active tab
        guard let activeTab = activeTab, let tabIndex = tabs.firstIndex(where: { $0.id == activeTab.id }) else {
            print("WebViewModel: Cannot load URL, no active tab creation failed")
            return
        }
        
        // Check for homepage URL and set flag
        if urlString == homepageURLString || urlString == effectiveHomepageURL {
            isShowingHomepage = true
            // No need to continue with WebView loading for homepage
            return
        } else {
            isShowingHomepage = false
        }
        
        // Normalize URL format (adding scheme if needed)
        var normalizedURL: URL?
        
        if urlString.starts(with: "http://") || urlString.starts(with: "https://") || urlString.starts(with: "file://") {
            // URL already has scheme, just parse
            normalizedURL = URL(string: urlString)
        } else if urlString.starts(with: "ibrowsy://") {
            // Handle custom protocol for internal pages
            if urlString == homepageURLString {
                isShowingHomepage = true
                normalizedURL = nil // No need to load in WebView
            } else {
                // Other custom handlers could go here
                normalizedURL = nil
            }
        } else if urlString.contains(".") || urlString.contains(":") {
            // Likely a domain, add scheme
            normalizedURL = URL(string: "https://\(urlString)")
            
            if normalizedURL == nil {
                // Try fallback with http://
                normalizedURL = URL(string: "http://\(urlString)")
            }
        } else {
            // Treat as search query
            let searchQuery = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            // Use the selected search provider from settings
            normalizedURL = URL(string: "\(defaultSearchProvider.searchURL)\(searchQuery)")
        }
        
        // Ensure URL is valid
        guard let url = normalizedURL else {
            print("WebViewModel: Could not create valid URL from: \(urlString)")
            return
        }
        
        // Determine which webView to use based on split view state
        let webViewToLoad: WKWebView
        if activeTab.isSplitView && activeTab.activeSplitViewSide == .secondary && activeTab.secondaryWebView != nil {
            webViewToLoad = activeTab.secondaryWebView!
            print("WebViewModel: Loading in secondary view: \(url.absoluteString)")
        } else {
            webViewToLoad = activeTab.primaryWebView
            print("WebViewModel: Loading in primary view: \(url.absoluteString)")
        }
        
        // Update the URL string
        self.urlString = url.absoluteString
        
        // Update the tab's URL string
        var updatedTab = tabs[tabIndex]
        updatedTab.urlString = url.absoluteString
        tabs[tabIndex] = updatedTab
        
        // Load the URL
        webViewToLoad.load(URLRequest(url: url))
        
        // Mark this tab for preview refresh
        markTabForPreviewRefresh(id: activeTab.id)
        
        // Update history
        addToHistory(title: activeTab.title ?? "Untitled", urlString: url.absoluteString)
    }
    
    // Switch to a specific tab
    func switchToTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { 
            print("WebViewModel: Could not find tab with ID \(id)")
            return 
        }
        
        // If already selected, do nothing
        if activeTab?.id == id { return }
        
        print("WebViewModel: Switching to tab at index \(index)")
        
        // Check for playing videos in the current tab before switching and trigger PiP if needed
        if let currentTab = activeTab, currentTab.id != id {
            checkAndTriggerAutoPiP(for: currentTab)
        }
        
        // Store the tab's URL before switching - this is important to preserve
        let tabToSelect = tabs[index]
        let tabURLString = tabToSelect.urlString
        
        // --- Animate the change --- 
        withAnimation(.easeInOut(duration: 0.2)) { // Add animation block
            // Update active states
            for i in 0..<tabs.count {
                tabs[i].isActive = (i == index)
            }
            
            activeTab = tabs[index]
            
            // CRITICAL: Reset ALL panel states when switching tabs to ensure proper navigation
            showingHistoryView = false
            showingDownloadsView = false
            showingCitationsView = false
            
            // Update UI state based on the tab's content - CRITICAL FIX HERE!
            // Check using the stored URL string, not the one from activeTab which might be reset
            if tabURLString == homepageURLString {
                isShowingHomepage = true
            } else {
                // For non-homepage URLs, ensure we're not showing homepage
                isShowingHomepage = false
                
                // Ensure the tab's URL is loaded if needed
                if activeTab?.primaryWebView.url == nil || 
                   activeTab?.primaryWebView.url?.absoluteString != tabURLString {
                    // This is a key change - make sure we load the correct URL
                    if let url = URL(string: tabURLString) {
                        print("WebViewModel: Loading tab's stored URL: \(tabURLString)")
                        activeTab?.primaryWebView.load(URLRequest(url: url))
                    }
                }
            }
            
            // Reset published values based on active tab
            if let tab = activeTab {
                // Use the stored URL string to avoid showing homepage
                urlString = tabURLString
                pageTitle = tab.title
                canGoBack = tab.primaryWebView.canGoBack
                canGoForward = tab.primaryWebView.canGoForward
                isLoading = tab.primaryWebView.isLoading
                // No need to reload favicon here, it's loaded on didFinish
            }
        } // End animation block
        
        // Post TabSelected notification
        // IMPORTANT: This notification must be posted even if animation is in progress
        NotificationCenter.default.post(name: NSNotification.Name("TabSelected"), object: nil)
        
        // Set up observers for the newly active tab (outside animation)
        setupActiveTabObservers()
        
        // --- Update state when switching tabs --- 
        updatePublishedStateFromActiveSplit() 
        
        // Ensure we have a preview for this tab
        if activeTab?.preview == nil && doesTabNeedPreviewRefresh(id: id) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.captureTabPreview(for: id)
            }
        }
    }
    
    // MARK: - Auto PiP Methods
    
    private func checkAndTriggerAutoPiP(for tab: BrowserTab, immediate: Bool = false) {
        let webView = tab.isSplitView && tab.activeSplitViewSide == .secondary ? tab.secondaryWebView : tab.primaryWebView
        guard let targetWebView = webView else { return }
        
        // RESTRICT AUTO-PIP TO YOUTUBE ONLY
        guard let currentURL = targetWebView.url?.absoluteString,
              (currentURL.contains("youtube.com") || currentURL.contains("youtu.be")) else {
            print("WebViewModel: Auto-PiP skipped - not on YouTube (URL: \(targetWebView.url?.absoluteString ?? "unknown"))")
            return
        }
        
        // Skip cooldown check for immediate triggers (browser minimize)
        if !immediate {
            let tabKey = tab.id.uuidString
            let now = Date()
            if let lastCheck = lastPiPCheckTime[tabKey] {
                let timeSinceLastCheck = now.timeIntervalSince(lastCheck)
                if timeSinceLastCheck < 0.1 {
                    print("WebViewModel: Skipping duplicate PiP check for tab - too recent (\(timeSinceLastCheck)s)")
                    return
                }
            }
            lastPiPCheckTime[tabKey] = now
        }
        
        print("WebViewModel: \(immediate ? "Immediately" : "Auto") checking for YouTube video PiP")
        // Check if there are playing videos on this tab that should trigger PiP
        VideoDetectionService.shared.checkForPlayingVideosWithAccurateTime(targetWebView) { [weak self] playingVideos in
            DispatchQueue.main.async {
                if !playingVideos.isEmpty {
                    for videoInfo in playingVideos {
                        // For YouTube videos, create PiP if video has content, not just if it's playing
                        // This handles cases where video gets paused when app loses focus
                        let shouldCreatePiP = videoInfo.isPlaying || 
                                             (videoInfo.currentTime > 0) || 
                                             (videoInfo.duration > 0 && videoInfo.elementType == .iframe)
                        
                        if shouldCreatePiP {
                            print("WebViewModel: \(immediate ? "Immediately" : "Auto")-triggering PiP for YouTube video: \(videoInfo.title) at time \(videoInfo.currentTime)s (isPlaying: \(videoInfo.isPlaying))")
                            PiPManager.shared.createPiPWindow(for: videoInfo, from: targetWebView)
                        } else {
                            print("WebViewModel: Skipping PiP for video without content: \(videoInfo.title) (isPlaying: \(videoInfo.isPlaying), currentTime: \(videoInfo.currentTime), duration: \(videoInfo.duration))")
                        }
                    }
                } else {
                    // Fallback to regular detection if accurate method fails
                    print("WebViewModel: Accurate video detection found no videos, trying fallback method")
                    VideoDetectionService.shared.checkForPlayingVideos(targetWebView) { [weak self] fallbackVideos in
                        DispatchQueue.main.async {
                            for videoInfo in fallbackVideos {
                                let shouldCreatePiP = videoInfo.isPlaying || 
                                                     (videoInfo.currentTime > 0) || 
                                                     (videoInfo.duration > 0 && videoInfo.elementType == .iframe)
                                
                                if shouldCreatePiP {
                                    print("WebViewModel: \(immediate ? "Immediately" : "Auto")-triggering PiP (fallback) for video: \(videoInfo.title) at time \(videoInfo.currentTime)s (isPlaying: \(videoInfo.isPlaying))")
                                    PiPManager.shared.createPiPWindow(for: videoInfo, from: targetWebView)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Close a specific tab
    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        
        let isActiveTab = tabs[index].isActive
        
        // Clean up file content tracking for this tab
        fileContentTabs.removeValue(forKey: id)
        
        // --- Animate the removal --- 
        withAnimation(.easeInOut(duration: 0.2)) {
             tabs.remove(at: index)
        }
        
        // If we removed the last tab, set activeTab to nil and show homepage
        if tabs.isEmpty {
             // Create a new tab instead of just setting activeTab to nil
             withAnimation(.easeInOut(duration: 0.2)) {
                 addNewTab(urlToLoad: nil) // This will create a new tab, set it as active, and show homepage
                 isShowingHomepage = true
             }
             return
        }
        
        // If we closed the active tab, activate another one
        if isActiveTab {
             // Animate the selection of the new active tab
             withAnimation(.easeInOut(duration: 0.2)) {
                 // Activate the previous tab, or the first one if we closed the first tab
                 let newActiveIndex = index > 0 ? index - 1 : 0
                 for i in 0..<tabs.count {
                     tabs[i].isActive = (i == newActiveIndex)
                 }
                 activeTab = tabs[newActiveIndex]
                 
                 // Update UI state based on the new active tab
                 if activeTab?.urlString == homepageURLString {
                     isShowingHomepage = true
                 } else {
                     isShowingHomepage = false
                 }
             }
            
            // Set up observers (outside animation)
            setupActiveTabObservers()
        }
    }

    // MARK: - Navigation Methods (Updated)
    
    /// Parses input and loads it into the specified side of the active tab.
    /// If no side is specified, loads into the currently active split side.
    func loadURL(from input: String, specificSide: SplitViewSide? = nil) {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { 
            print("WebViewModel: Cannot load URL - input is empty.")
            return 
        }
        
        // If no active tab, create one first
        if activeTab == nil {
            print("WebViewModel: No active tab, creating one before loading URL")
            addNewTab(urlToLoad: nil)
            
            // If tab creation failed, return
            if activeTab == nil { 
                print("WebViewModel Error: Failed to create initial tab for loading.")
                return 
            }
        }

        guard let currentTabId = activeTab?.id else {
            print("WebViewModel: Cannot load URL - no active tab after creation attempt")
            return
        }

        // Check for homepage URL first (always loads normally, not in split)
        if trimmedInput == homepageURLString {
            DispatchQueue.main.async {
                // If currently split, exit split view when going home?
                if let index = self.tabs.firstIndex(where: { $0.id == currentTabId }), self.tabs[index].isSplitView {
                     self.tabs[index].isSplitView = false
                     self.tabs[index].secondaryWebView = nil // Clean up secondary view
                     print("WebViewModel: Exited split view due to navigating home.")
                }
                
                self.isShowingHomepage = true
                self.urlString = self.homepageURLString
                self.showingHistoryView = false
                self.showingDownloadsView = false
                self.showingCitationsView = false
                if let webView = self.activeWebViewInSplit, webView.isLoading { webView.stopLoading() }
                print("WebViewModel: Navigating to homepage view.")
                self.updatePublishedStateFromActiveSplit() // Update state for homepage
            }
            return
        }
        
        // Prepare URL to load (same parsing logic as before)
        var urlToLoad: URL?
        if trimmedInput.contains(".") && !trimmedInput.contains(" ") {
            var correctedInput = trimmedInput
            if !correctedInput.hasPrefix("http://") && !correctedInput.hasPrefix("https://") {
                correctedInput = "https://" + correctedInput
            }
            urlToLoad = URL(string: correctedInput)
        } else {
            print("WebViewModel: Input \"\(trimmedInput)\" doesn't look like a URL, performing search.")
            let query = trimmedInput.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            urlToLoad = URL(string: "\(defaultSearchProvider.searchURL)\(query)")
        }

        guard let finalURL = urlToLoad else {
            print("WebViewModel: Could not construct a valid URL or search query from \"\(input)\".")
            // Optionally show error or revert to homepage
            return
        }
        
        // Determine the target side
        let targetSide = specificSide ?? activeTab?.activeSplitViewSide ?? .primary
        
        // Perform the load on the main thread
        DispatchQueue.main.async {
            self.isShowingHomepage = false
            self.showingHistoryView = false
            self.showingDownloadsView = false
            self.showingCitationsView = false
            
            self.loadURLInSplit(url: finalURL, for: currentTabId, targetSide: targetSide)
        }
    }
    
    /// Helper function to load a specific URL into a specific side of a tab.
    func loadURLInSplit(url: URL, for tabId: UUID, targetSide: SplitViewSide) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else {
            print("WebViewModel Error: Cannot find tab with ID \\(tabId) to load URL.")
            return
        }

        // Store the current primary pane width before loading if it exists
        let existingWidth = tabs[index].primaryPaneDesiredWidth
        
        let request = URLRequest(url: url)
        var targetWebView: WKWebView?

        switch targetSide {
        case .primary:
            targetWebView = tabs[index].primaryWebView
            print("WebViewModel: Loading URL in PRIMARY view for tab \\(tabId) - \\(url.absoluteString)")
        case .secondary:
            if let secondary = tabs[index].secondaryWebView {
                targetWebView = secondary
                print("WebViewModel: Loading URL in SECONDARY view for tab \\(tabId) - \\(url.absoluteString)")
            } else {
                print("WebViewModel Error: Attempted to load in secondary view, but it doesn't exist for tab \\(tabId). Falling back to primary.")
                // If secondary doesn't exist (shouldn't happen if isSplitView is true and it was the drop target),
                // we might need to create it or handle this case more gracefully.
                // For now, if it was a drop target, it MUST exist. If not, something is wrong.
                // However, to prevent crashes, we can log and avoid loading.
                // Or, as a safety, if targetSide is .secondary but secondaryWebView is nil, we could potentially try to create it.
                // For now, let's assume if it's a drop target, it exists.
                // If secondaryWebView is nil but targetSide is .secondary, it's an inconsistent state.
                 print("WebViewModel CRITICAL Error: targetSide is .secondary but secondaryWebView is nil for tab \\(tabId). Cannot load.")
                 return // Or handle by creating the secondary view
            }
        }

        if let webViewToLoad = targetWebView {
            webViewToLoad.load(request)
            // CRUCIAL: Set the target side as active AFTER initiating the load.
            // This ensures focus, URL bar, and other UI elements update correctly.
            setActiveSplitSide(for: tabId, side: targetSide)
            
            // Restore the stored width after changing active side
            if let width = existingWidth, width > 0 {
                // Find the tab again after potential modifications
                if let updatedIndex = tabs.firstIndex(where: { $0.id == tabId }) {
                    tabs[updatedIndex].primaryPaneDesiredWidth = width
                    
                    // Update the active tab reference if needed
                    if activeTab?.id == tabId {
                        activeTab = tabs[updatedIndex]
                    }
                    print("WebViewModel: Preserved primary pane width \(width) during URL load")
                }
            }
        } else {
            // This case should ideally not be reached if targetSide implies an existing WebView.
            // If primary is the target, primaryWebView should always exist.
            // If secondary is the target, secondaryWebView should exist if tab.isSplitView is true.
            print("WebViewModel Error: Could not determine target WebView to load URL for tab \\(tabId) and side \\(targetSide).")
        }
    }
    
    /// Handle file drops (PDFs, videos, etc.) for split view
    func handleFileDropForSplit(fileURL: URL, for tabId: UUID, targetSide: SplitViewSide) -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else {
            print("WebViewModel Error: Cannot find tab with ID \\(tabId) to load file.")
            return false
        }
        
        // Check if file exists and is readable
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("WebViewModel Error: File doesn't exist at path: \\(fileURL.path)")
            return false
        }
        
        let fileExtension = fileURL.pathExtension.lowercased()
        print("WebViewModel: Handling file drop with extension: \\(fileExtension)")
        
        // Store the current primary pane width before loading if it exists
        let existingWidth = tabs[index].primaryPaneDesiredWidth
        
        var targetWebView: WKWebView?
        
        switch targetSide {
        case .primary:
            targetWebView = tabs[index].primaryWebView
            print("WebViewModel: Loading file in PRIMARY view for tab \\(tabId) - \\(fileURL.lastPathComponent)")
        case .secondary:
            if let secondary = tabs[index].secondaryWebView {
                targetWebView = secondary
                print("WebViewModel: Loading file in SECONDARY view for tab \\(tabId) - \\(fileURL.lastPathComponent)")
            } else {
                print("WebViewModel Error: Attempted to load file in secondary view, but it doesn't exist for tab \\(tabId).")
                return false
            }
        }
        
        guard let webViewToLoad = targetWebView else {
            print("WebViewModel Error: Could not determine target WebView to load file for tab \\(tabId) and side \\(targetSide).")
            return false
        }
        
        // Handle different file types
        switch fileExtension {
        case "pdf":
            // PDFs need sandbox-compatible loading
            loadPDFFile(fileURL: fileURL, in: webViewToLoad)
            
        case "mp4", "mov", "avi", "mkv", "webm", "m4v":
            // Videos need to be wrapped in HTML
            loadVideoFile(fileURL: fileURL, in: webViewToLoad)
            
        case "jpg", "jpeg", "png", "gif", "webp", "bmp", "tiff", "heic", "heif":
            // Images can be wrapped in HTML for better display
            loadImageFile(fileURL: fileURL, in: webViewToLoad)
            
        case "txt", "md", "json", "xml", "csv", "log", "swift", "js", "ts", "py", "java", "cpp", "c", "h":
            // Text files can be loaded directly or wrapped for better formatting
            loadTextFile(fileURL: fileURL, in: webViewToLoad)
            
        case "html", "htm":
            // HTML files can be loaded directly
            let request = URLRequest(url: fileURL)
            webViewToLoad.load(request)
            
        // Office Suite Files - Microsoft Office
        case "docx", "doc", "xlsx", "xls", "pptx", "ppt":
            loadOfficeFile(fileURL: fileURL, in: webViewToLoad)
            
        // Office Suite Files - Apple iWork
        case "pages", "numbers", "key":
            loadAppleOfficeFile(fileURL: fileURL, in: webViewToLoad)
            
        // Office Suite Files - OpenDocument Format
        case "odt", "ods", "odp", "odg", "odf":
            loadOpenDocumentFile(fileURL: fileURL, in: webViewToLoad)
            
        // Archive Files
        case "zip", "rar", "7z", "tar", "gz":
            loadArchiveFile(fileURL: fileURL, in: webViewToLoad)
            
        // Audio Files
        case "mp3", "wav", "aac", "flac", "m4a", "ogg":
            loadAudioFile(fileURL: fileURL, in: webViewToLoad)
            
        // Rich Text and Document Files
        case "rtf", "rtfd":
            loadRichTextFile(fileURL: fileURL, in: webViewToLoad)
            
        default:
            // For unsupported file types, try to load directly and let the system handle it
            print("WebViewModel: Unsupported file type \\(fileExtension), attempting direct load")
            let request = URLRequest(url: fileURL)
            webViewToLoad.load(request)
        }
        
        // Set the target side as active AFTER initiating the load
        setActiveSplitSide(for: tabId, side: targetSide)
        
        // Track this tab as displaying file content
        fileContentTabs[tabId] = fileURL
        
        // Store the original file URL for proper display in the URL bar
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Update the URL string to show the file path instead of the temporary HTML
            self.urlString = fileURL.absoluteString
            
            // Also update the tab's URL string
            if let index = self.tabs.firstIndex(where: { $0.id == tabId }) {
                self.tabs[index].urlString = fileURL.absoluteString
                
                // Update activeTab reference if needed
                if self.activeTab?.id == tabId {
                    self.activeTab = self.tabs[index]
                }
            }
        }
        
        // Restore the stored width after changing active side
        if let width = existingWidth, width > 0 {
            // Find the tab again after potential modifications
            if let updatedIndex = tabs.firstIndex(where: { $0.id == tabId }) {
                tabs[updatedIndex].primaryPaneDesiredWidth = width
                
                // Update the active tab reference if needed
                if activeTab?.id == tabId {
                    activeTab = tabs[updatedIndex]
                }
                print("WebViewModel: Preserved primary pane width \\(width) during file load")
            }
        }
        
        return true
    }
    
    /// Load video file with sandbox-compatible approach
    private func loadVideoFile(fileURL: URL, in webView: WKWebView) {
        let fileName = fileURL.lastPathComponent
        let fileExtension = fileURL.pathExtension.lowercased()
        
        print("WebViewModel: Loading video file: \(fileName)")
        
        // First, verify the file exists and is readable
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("WebViewModel Error: Video file does not exist at path: \(fileURL.path)")
            return
        }
        
        // Copy file to app's temporary directory to avoid sandbox issues
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            // Remove existing temp file if it exists
            if FileManager.default.fileExists(atPath: tempFileURL.path) {
                try FileManager.default.removeItem(at: tempFileURL)
            }
            
            // Copy the original file to temp directory
            try FileManager.default.copyItem(at: fileURL, to: tempFileURL)
            print("WebViewModel: Copied video file to temp directory: \(tempFileURL.path)")
            
            // Load the temp file using loadFileURL (this should work within sandbox)
            webView.loadFileURL(tempFileURL, allowingReadAccessTo: tempDirectory)
            print("WebViewModel: Loading temp video file with directory access")
            
            // Notify AI about the loaded video file
            if let assistantViewModel = assistantViewModel {
                let videoContent = "Video file: \(fileName). This is a video file that has been loaded for viewing."
                assistantViewModel.addFileContext(filePath: fileURL.path, fileName: fileName, fileType: "Video", content: videoContent)
            }
            
        } catch {
            print("WebViewModel Error: Failed to copy video file to temp directory: \(error)")
            
            // Fallback: Try HTML wrapper approach
            loadVideoFileWithHTMLWrapper(fileURL: fileURL, in: webView)
        }
    }
    
    /// Fallback method: Load video with HTML wrapper
    private func loadVideoFileWithHTMLWrapper(fileURL: URL, in webView: WKWebView) {
        let fileName = fileURL.lastPathComponent
        let fileExtension = fileURL.pathExtension.lowercased()
        
        // Try to copy to temp directory first for sandbox compatibility
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirectory.appendingPathComponent(fileName)
        var actualFileURL = fileURL
        var baseURL = fileURL.deletingLastPathComponent()
        
        do {
            // Remove existing temp file if it exists
            if FileManager.default.fileExists(atPath: tempFileURL.path) {
                try FileManager.default.removeItem(at: tempFileURL)
            }
            
            // Copy the original file to temp directory
            try FileManager.default.copyItem(at: fileURL, to: tempFileURL)
            actualFileURL = tempFileURL
            baseURL = tempDirectory
            print("WebViewModel: Using temp file for HTML wrapper: \(tempFileURL.path)")
            
        } catch {
            print("WebViewModel: Could not copy to temp directory, using original: \(error)")
            // Use original file if copy fails
        }
        
        // Determine proper MIME type based on file extension
        let mimeType: String
        switch fileExtension {
        case "mp4":
            mimeType = "video/mp4"
        case "mov":
            mimeType = "video/quicktime"
        case "avi":
            mimeType = "video/x-msvideo"
        case "mkv":
            mimeType = "video/x-matroska"
        case "webm":
            mimeType = "video/webm"
        case "m4v":
            mimeType = "video/x-m4v"
        default:
            mimeType = "video/mp4"
        }
        
        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(fileName)</title>
            <style>
                body {
                    margin: 0;
                    padding: 20px;
                    background-color: #1a1a1a;
                    color: white;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    min-height: 100vh;
                }
                .video-container {
                    max-width: 100%;
                    text-align: center;
                }
                video {
                    max-width: 100%;
                    max-height: 80vh;
                    background-color: #000;
                    border-radius: 8px;
                    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.5);
                    outline: none;
                }
                .file-info {
                    margin-top: 20px;
                    color: #999;
                    font-size: 14px;
                }
                .controls-info {
                    margin-top: 10px;
                    color: #666;
                    font-size: 12px;
                }
                .error-info {
                    margin-top: 10px;
                    color: #ff6b6b;
                    font-size: 12px;
                    display: none;
                }
            </style>
            <script>
                document.addEventListener('DOMContentLoaded', function() {
                    const video = document.querySelector('video');
                    const errorInfo = document.querySelector('.error-info');
                    
                    video.addEventListener('error', function(e) {
                        console.error('Video error:', e);
                        errorInfo.style.display = 'block';
                        errorInfo.textContent = 'Error loading video: ' + (e.target.error ? e.target.error.message : 'Unknown error');
                    });
                    
                    video.addEventListener('loadstart', function() {
                        console.log('Video started loading');
                    });
                    
                    video.addEventListener('canplay', function() {
                        console.log('Video can start playing');
                    });
                    
                    video.addEventListener('loadedmetadata', function() {
                        console.log('Video metadata loaded - Duration:', video.duration, 'seconds');
                    });
                    
                    video.addEventListener('loadeddata', function() {
                        console.log('Video data loaded');
                    });
                });
            </script>
        </head>
        <body>
            <div class="video-container">
                <video controls preload="metadata">
                    <source src="\(actualFileURL.lastPathComponent)" type="\(mimeType)">
                    <p>Your browser doesn't support HTML5 video or this video format. 
                       <a href="\(actualFileURL.lastPathComponent)" download>Download the video</a> instead.</p>
                </video>
                <div class="file-info">
                    <strong>\(fileName)</strong> • \(fileExtension.uppercased()) Video
                </div>
                <div class="controls-info">
                    Use video controls to play, pause, adjust volume, and seek through the video
                </div>
                <div class="error-info">
                    <!-- Error message will appear here if video fails to load -->
                </div>
            </div>
        </body>
        </html>
        """
        
        print("WebViewModel: Loading video with HTML wrapper and baseURL: \(baseURL.path)")
        webView.loadHTMLString(htmlContent, baseURL: baseURL)
    }
    
    /// Load PDF file with sandbox-compatible approach
    private func loadPDFFile(fileURL: URL, in webView: WKWebView) {
        let fileName = fileURL.lastPathComponent
        
        print("WebViewModel: Loading PDF file: \(fileName)")
        
        // First, verify the file exists and is readable
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("WebViewModel Error: PDF file does not exist at path: \(fileURL.path)")
            return
        }
        
        // Copy file to app's temporary directory to avoid sandbox issues
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            // Remove existing temp file if it exists
            if FileManager.default.fileExists(atPath: tempFileURL.path) {
                try FileManager.default.removeItem(at: tempFileURL)
            }
            
            // Copy the original file to temp directory
            try FileManager.default.copyItem(at: fileURL, to: tempFileURL)
            print("WebViewModel: Copied PDF file to temp directory: \(tempFileURL.path)")
            
            // Load the temp file using loadFileURL (this should work within sandbox)
            webView.loadFileURL(tempFileURL, allowingReadAccessTo: tempDirectory)
            print("WebViewModel: Loading temp PDF file with directory access")
            
            // Notify AI about the loaded PDF file
            if let assistantViewModel = assistantViewModel {
                let pdfContent = "PDF file: \(fileName). This is a PDF document that has been loaded in the browser."
                assistantViewModel.addFileContext(filePath: fileURL.path, fileName: fileName, fileType: "PDF", content: pdfContent)
            }
            
        } catch {
            print("WebViewModel Error: Failed to copy PDF file to temp directory: \(error)")
            
            // Fallback: Try HTML wrapper approach with error message
            loadPDFFileWithHTMLWrapper(fileURL: fileURL, in: webView)
        }
    }
    
    /// Fallback method: Load PDF with HTML wrapper and error message
    private func loadPDFFileWithHTMLWrapper(fileURL: URL, in webView: WKWebView) {
        let fileName = fileURL.lastPathComponent
        
        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(fileName)</title>
            <style>
                body {
                    margin: 0;
                    padding: 20px;
                    background-color: #1a1a1a;
                    color: white;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    min-height: 100vh;
                }
                .pdf-container {
                    max-width: 600px;
                    text-align: center;
                    background-color: #2d2d2d;
                    padding: 40px;
                    border-radius: 12px;
                    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.5);
                }
                .pdf-icon {
                    font-size: 48px;
                    margin-bottom: 20px;
                }
                .file-info {
                    margin: 20px 0;
                    color: #e0e0e0;
                    font-size: 16px;
                }
                .error-message {
                    color: #ff6b6b;
                    font-size: 14px;
                    margin: 20px 0;
                    line-height: 1.5;
                }
                .suggestions {
                    color: #999;
                    font-size: 13px;
                    line-height: 1.5;
                    text-align: left;
                    margin-top: 20px;
                }
                .path-info {
                    color: #666;
                    font-size: 11px;
                    margin-top: 15px;
                    word-break: break-all;
                    font-family: monospace;
                }
            </style>
        </head>
        <body>
            <div class="pdf-container">
                <div class="pdf-icon">📄</div>
                <div class="file-info">
                    <strong>\(fileName)</strong>
                </div>
                <div class="error-message">
                    Unable to display PDF file due to sandbox restrictions.
                </div>
                <div class="suggestions">
                    <strong>Suggestions:</strong><br>
                    • Try opening the file directly in Preview or Adobe Acrobat<br>
                    • Copy the file to your Downloads folder and drag it again<br>
                    • Use File → Open to select the PDF from within the app
                </div>
                <div class="path-info">
                    File location: \(fileURL.path)
                </div>
            </div>
        </body>
        </html>
        """
        
        print("WebViewModel: Loading PDF with error message HTML wrapper")
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }
    
    /// Load image file with HTML wrapper for better display
    private func loadImageFile(fileURL: URL, in webView: WKWebView) {
        let fileName = fileURL.lastPathComponent
        let fileURLString = fileURL.absoluteString
        
        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(fileName)</title>
            <style>
                body {
                    margin: 0;
                    padding: 20px;
                    background-color: #1a1a1a;
                    color: white;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    min-height: 100vh;
                }
                .image-container {
                    max-width: 100%;
                    text-align: center;
                }
                img {
                    max-width: 100%;
                    max-height: 80vh;
                    object-fit: contain;
                    border-radius: 8px;
                    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.5);
                }
                .file-info {
                    margin-top: 20px;
                    color: #999;
                    font-size: 14px;
                }
            </style>
        </head>
        <body>
            <div class="image-container">
                <img src="\(fileURLString)" alt="\(fileName)" />
                <div class="file-info">
                    <strong>\(fileName)</strong>
                </div>
            </div>
        </body>
        </html>
        """
        
        // Create a temporary HTML file to maintain the proper URL
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("\(UUID().uuidString)_\(fileName).html")
        
        do {
            try htmlContent.write(to: tempFile, atomically: true, encoding: .utf8)
            let request = URLRequest(url: tempFile)
            webView.load(request)
        } catch {
            print("WebViewModel Error: Could not create temporary HTML file for image: \(error)")
            // Fallback to original method
            webView.loadHTMLString(htmlContent, baseURL: fileURL.deletingLastPathComponent())
        }
    }
    
    /// Load text file with HTML wrapper for better formatting
    private func loadTextFile(fileURL: URL, in webView: WKWebView) {
        let fileName = fileURL.lastPathComponent
        let fileExtension = fileURL.pathExtension.lowercased()
        
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let escapedContent = content
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            
            let isCode = ["json", "xml", "csv", "js", "css", "py", "swift", "java", "cpp", "c", "h"].contains(fileExtension)
            
            let htmlContent = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>\(fileName)</title>
                <style>
                    body {
                        margin: 0;
                        padding: 20px;
                        background-color: #1a1a1a;
                        color: #e0e0e0;
                        font-family: \(isCode ? "'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace" : "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif");
                        line-height: 1.6;
                    }
                    .header {
                        border-bottom: 1px solid #333;
                        padding-bottom: 10px;
                        margin-bottom: 20px;
                        color: #999;
                        font-size: 14px;
                    }
                    .content {
                        white-space: pre-wrap;
                        word-wrap: break-word;
                        \(isCode ? "background-color: #2d2d2d; padding: 15px; border-radius: 8px; overflow-x: auto;" : "")
                    }
                </style>
            </head>
            <body>
                <div class="header">
                    <strong>\(fileName)</strong> • \(fileExtension.uppercased()) File
                </div>
                <div class="content">\(escapedContent)</div>
            </body>
            </html>
            """
            
            // Create a temporary HTML file to maintain the proper URL
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent("\(UUID().uuidString)_\(fileName).html")
            
            do {
                try htmlContent.write(to: tempFile, atomically: true, encoding: .utf8)
                let request = URLRequest(url: tempFile)
                webView.load(request)
            } catch {
                print("WebViewModel Error: Could not create temporary HTML file for text: \(error)")
                // Fallback to original method
                webView.loadHTMLString(htmlContent, baseURL: fileURL.deletingLastPathComponent())
            }
        } catch {
            print("WebViewModel Error: Could not read text file: \\(error)")
            // Fallback to direct load
            let request = URLRequest(url: fileURL)
            webView.load(request)
        }
    }
    
    /// Load Office files (Microsoft Office: .docx, .doc, .xlsx, .xls, .pptx, .ppt)
    private func loadOfficeFile(fileURL: URL, in webView: WKWebView) {
        let fileName = fileURL.lastPathComponent
        let fileExtension = fileURL.pathExtension.lowercased()
        
        // Try to load directly first (might work on some systems)
        let request = URLRequest(url: fileURL)
        webView.load(request)
        
        // Also extract text content for AI analysis
        Task {
            await extractOfficeFileContent(fileURL: fileURL)
        }
    }
    
    /// Load Apple iWork files (.pages, .numbers, .key)
    private func loadAppleOfficeFile(fileURL: URL, in webView: WKWebView) {
        let fileName = fileURL.lastPathComponent
        let fileExtension = fileURL.pathExtension.lowercased()
        
        // Try to load directly first
        let request = URLRequest(url: fileURL)
        webView.load(request)
        
        // Also extract text content for AI analysis
        Task {
            await extractAppleOfficeContent(fileURL: fileURL)
        }
    }
    
    /// Load OpenDocument Format files (.odt, .ods, .odp, .odg, .odf)
    private func loadOpenDocumentFile(fileURL: URL, in webView: WKWebView) {
        let fileName = fileURL.lastPathComponent
        let fileExtension = fileURL.pathExtension.lowercased()
        
        // Try to load directly first
        let request = URLRequest(url: fileURL)
        webView.load(request)
        
        // Also extract text content for AI analysis
        Task {
            await extractOpenDocumentContent(fileURL: fileURL)
        }
    }
    
    /// Load archive files (.zip, .rar, .7z, .tar, .gz)
    private func loadArchiveFile(fileURL: URL, in webView: WKWebView) {
        let fileName = fileURL.lastPathComponent
        let fileExtension = fileURL.pathExtension.lowercased()
        
        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(fileName)</title>
            <style>
                body {
                    margin: 0;
                    padding: 40px;
                    background-color: #1a1a1a;
                    color: #e0e0e0;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    text-align: center;
                }
                .archive-info {
                    background-color: #2d2d2d;
                    border-radius: 12px;
                    padding: 30px;
                    max-width: 500px;
                    margin: 0 auto;
                    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
                }
                .icon {
                    font-size: 48px;
                    margin-bottom: 20px;
                }
                h1 { color: #fff; margin-bottom: 10px; }
                .file-type { color: #999; font-size: 14px; margin-bottom: 20px; }
                .open-button {
                    background-color: #007AFF;
                    color: white;
                    border: none;
                    padding: 12px 24px;
                    border-radius: 8px;
                    font-size: 16px;
                    cursor: pointer;
                    text-decoration: none;
                    display: inline-block;
                }
                .open-button:hover { background-color: #0056B3; }
            </style>
        </head>
        <body>
            <div class="archive-info">
                <div class="icon">📦</div>
                <h1>\(fileName)</h1>
                <div class="file-type">\(fileExtension.uppercased()) Archive</div>
                <p>This is an archive file. Click below to open it with your system's default archive utility.</p>
                <a href="file://\(fileURL.path)" class="open-button">Open Archive</a>
            </div>
        </body>
        </html>
        """
        
        webView.loadHTMLString(htmlContent, baseURL: fileURL.deletingLastPathComponent())
    }
    
    /// Load audio files (.mp3, .wav, .aac, .flac, .m4a, .ogg)
    private func loadAudioFile(fileURL: URL, in webView: WKWebView) {
        let fileName = fileURL.lastPathComponent
        let fileExtension = fileURL.pathExtension.lowercased()
        let fileURLString = fileURL.absoluteString
        
        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(fileName)</title>
            <style>
                body {
                    margin: 0;
                    padding: 40px;
                    background-color: #1a1a1a;
                    color: #e0e0e0;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    text-align: center;
                    min-height: 100vh;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                .audio-container {
                    background-color: #2d2d2d;
                    border-radius: 12px;
                    padding: 30px;
                    max-width: 500px;
                    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
                }
                .icon { font-size: 48px; margin-bottom: 20px; }
                h1 { color: #fff; margin-bottom: 10px; }
                .file-type { color: #999; font-size: 14px; margin-bottom: 30px; }
                audio {
                    width: 100%;
                    margin: 20px 0;
                    border-radius: 8px;
                }
            </style>
        </head>
        <body>
            <div class="audio-container">
                <div class="icon">🎵</div>
                <h1>\(fileName)</h1>
                <div class="file-type">\(fileExtension.uppercased()) Audio File</div>
                <audio controls preload="metadata">
                    <source src="\(fileURLString)" type="audio/\(fileExtension)">
                    Your browser does not support the audio element.
                </audio>
            </div>
        </body>
        </html>
        """
        
        // Create a temporary HTML file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("\(UUID().uuidString)_\(fileName).html")
        
        do {
            try htmlContent.write(to: tempFile, atomically: true, encoding: .utf8)
            let request = URLRequest(url: tempFile)
            webView.load(request)
        } catch {
            print("WebViewModel Error: Could not create temporary HTML file for audio: \(error)")
            webView.loadHTMLString(htmlContent, baseURL: fileURL.deletingLastPathComponent())
        }
    }
    
    /// Load rich text files (.rtf, .rtfd)
    private func loadRichTextFile(fileURL: URL, in webView: WKWebView) {
        let fileName = fileURL.lastPathComponent
        
        // Try to load directly first (WebKit can handle RTF)
        let request = URLRequest(url: fileURL)
        webView.load(request)
        
        // Also extract plain text for AI analysis
        Task {
            await extractRichTextContent(fileURL: fileURL)
        }
    }

    // Navigate back in the active tab
    func goBack() {
        // --- CORRECT Use activeWebViewInSplit --- 
        if let webView = activeWebViewInSplit, webView.canGoBack {
            webView.goBack()
            DispatchQueue.main.async { 
                self.isShowingHomepage = false
                
                // Update state after navigation starts
                if let activeTab = self.activeTab {
                    let side = activeTab.activeSplitViewSide
                    print("WebViewModel: Going back in \(side) view")
                    
                    // Ensure UI state is updated for the correct side
                    self.updatePublishedStateFromActiveSplit()
                    
                    // Mark for preview refresh
                    self.markTabForPreviewRefresh(id: activeTab.id)
                }
            }
        } else {
            // If the *active* view cannot go back, consider going home?
            if !isShowingHomepage {
                print("WebViewModel: Cannot go back, no history available")
            }
        }
    }
    
    // Navigate forward in the active tab
    func goForward() {
        // --- CORRECT Use activeWebViewInSplit --- 
        if let webView = activeWebViewInSplit, webView.canGoForward {
            webView.goForward()
            DispatchQueue.main.async { 
                self.isShowingHomepage = false
                
                // Update state after navigation starts
                if let activeTab = self.activeTab {
                    let side = activeTab.activeSplitViewSide
                    print("WebViewModel: Going forward in \(side) view")
                    
                    // Ensure UI state is updated for the correct side
                    self.updatePublishedStateFromActiveSplit()
                    
                    // Mark for preview refresh
                    self.markTabForPreviewRefresh(id: activeTab.id)
                }
            }
        } else {
            print("WebViewModel: Cannot go forward, no forward history available")
        }
    }
    
    // Reload the active tab
    func reload() {
        if isShowingHomepage {
             print("WebViewModel: Reload called on homepage, doing nothing.")
        } else {
            // --- CORRECTED: Target the active web view ---
            if let webView = activeWebViewInSplit {
                webView.reload()
                print("WebViewModel: Reload triggered for active split: \(activeTab?.activeSplitViewSide ?? .primary)")
                
                // Update state after reload starts
                DispatchQueue.main.async {
                    self.updatePublishedStateFromActiveSplit()
                    
                    // Mark for preview refresh
                    if let activeTab = self.activeTab {
                        self.markTabForPreviewRefresh(id: activeTab.id)
                    }
                }
            } else {
                print("WebViewModel WARNING: Could not find active web view to reload.")
            }
        }
    }
    
    func stopLoading() {
        // --- CORRECTED: Target the active web view --- 
        if let webView = activeWebViewInSplit {
             webView.stopLoading()
             print("WebViewModel: Stop loading triggered for active split: \(activeTab?.activeSplitViewSide ?? .primary)")
        } else {
            print("WebViewModel Warning: Could not find active web view to stop loading.")
        }
    }
    
    func goHome() {
         // Ensure we have a tab before loading the homepage
         if activeTab == nil {
             print("WebViewModel: Creating tab before going home")
             addNewTab(urlToLoad: nil)
         }
         
         loadURL(from: homepageURLString)
         showingCitationsView = false
    }
    
    // MARK: - History Management
    
    func showHistory() {
        // Hide other views
        isShowingHomepage = false
        showingDownloadsView = false
        
        // Show history view
        DispatchQueue.main.async {
            self.showingHistoryView = true
        }
    }
    
    func clearHistory() {
        historyItems.removeAll()
        saveHistoryToDisk()
    }
    
    func removeHistoryItem(id: UUID) {
        historyItems.removeAll { $0.id == id }
        saveHistoryToDisk()
    }
    
    private func addToHistory(title: String, urlString: String) {
        // Don't add homepage or empty URLs to history
        if urlString == homepageURLString || urlString.isEmpty {
            return
        }
        
        // Create new history item
        let newItem = HistoryItem(title: title, urlString: urlString, date: Date())
        
        // Add to the beginning of the array
        historyItems.insert(newItem, at: 0)
        
        // Limit history to 100 items
        if historyItems.count > 100 {
            historyItems = Array(historyItems.prefix(100))
        }
        
        // Save history to disk
        saveHistoryToDisk()
    }
    
    private func saveHistoryToDisk() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(historyItems)
            
            let fileManager = FileManager.default
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentsDirectory.appendingPathComponent("browsing_history.json")
            
            try data.write(to: fileURL)
        } catch {
            print("WebViewModel: Failed to save history: \(error)")
        }
    }
    
    private func loadHistoryFromDisk() {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent("browsing_history.json")
        
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                historyItems = try decoder.decode([HistoryItem].self, from: data)
            } catch {
                print("WebViewModel: Failed to load history: \(error)")
                historyItems = []
            }
        }
    }
    
    // MARK: - Downloads Management
    
    func showDownloads() {
        // Hide other views
        isShowingHomepage = false
        showingHistoryView = false
        
        // Show downloads view
        DispatchQueue.main.async {
            self.showingDownloadsView = true
        }
    }
    
    func startDownload(url: URL, suggestedFilename: String? = nil) async {
        let download = await webView.startDownload(using: URLRequest(url: url))
        download.delegate = self
        
        let filename = suggestedFilename ?? url.lastPathComponent
        
        // Create download item
        let downloadItem = DownloadItem(
            filename: filename,
            urlString: url.absoluteString,
            date: Date(),
            fileSize: 0,
            progress: 0.0,
            state: .inProgress,
            localURL: nil
        )
        
        // Add to downloads list
        downloadItems.insert(downloadItem, at: 0)
        activeDownloads[downloadItem.id] = download
        
        // Save downloads to disk
        saveDownloadsToDisk()
    }
    
    func clearDownloadHistory() {
        // Only remove completed downloads from the list
        downloadItems.removeAll { $0.state != .inProgress }
        saveDownloadsToDisk()
    }
    
    func cancelDownload(id: UUID) {
        if let download = activeDownloads[id] {
            download.cancel()
            activeDownloads.removeValue(forKey: id)
            
            // Update download item status
            if let index = downloadItems.firstIndex(where: { $0.id == id }) {
                downloadItems[index].state = .failed
                saveDownloadsToDisk()
            }
        }
    }
    
    func openDownloadedFile(id: UUID) {
        guard let item = downloadItems.first(where: { $0.id == id }),
              let localURL = item.localURL else {
            return
        }
        
        NSWorkspace.shared.open(localURL)
    }
    
    private func saveDownloadsToDisk() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(downloadItems)
            
            let fileManager = FileManager.default
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentsDirectory.appendingPathComponent("downloads.json")
            
            try data.write(to: fileURL)
        } catch {
            print("WebViewModel: Failed to save downloads: \(error)")
        }
    }
    
    private func loadDownloadsFromDisk() {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent("downloads.json")
        
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                downloadItems = try decoder.decode([DownloadItem].self, from: data)
            } catch {
                print("WebViewModel: Failed to load downloads: \(error)")
                downloadItems = []
            }
        }
    }
    
    // MARK: - WKNavigationDelegate Methods
    
    // Called when navigation starts
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("WebViewModel: didStartProvisionalNavigation")
        
        // Reset navigation error
        navigationErrorOccurred = false
        navigationError = nil
        
        // REMOVED: Reader mode availability reset
        
        // Find which tab this webView belongs to
        if let tabId = getTabId(forWebView: webView) {
            // Update the loading state
            if let index = tabs.firstIndex(where: { $0.id == tabId }) {
                var updatedTab = tabs[index]
                
                // Determine which webview (primary or secondary) is being used
                let isSecondaryView = updatedTab.secondaryWebView === webView
                
                // Only set isLoading to true for the tab and update UI
                // if the webview being loaded is the active view in split mode
                let isPrimaryActive = (!updatedTab.isSplitView || updatedTab.activeSplitViewSide == .primary)
                let isSecondaryActive = (updatedTab.isSplitView && updatedTab.activeSplitViewSide == .secondary)
                
                // Set tab isLoading property correctly based on which view is loading
                updatedTab.isLoading = true
                updatedTab.loadingProgress = 0.1 // Starting progress
                tabs[index] = updatedTab
                
                // Update activeTab reference if needed
                if activeTab?.id == tabId {
                    activeTab = updatedTab
                    
                    // Only update the global isLoading indicator if the active view is loading
                    if (isSecondaryView && isSecondaryActive) || (!isSecondaryView && isPrimaryActive) {
                        DispatchQueue.main.async {
                            self.isLoading = true
                            // Update published state to ensure UI is consistent
                            self.updatePublishedStateFromActiveSplit()
                        }
                    }
                }
                
                // Notify of the change
                objectWillChange.send()
            }
        }
    }
    
    // Called when content starts arriving
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        print("WebViewModel: didCommit navigation")
        
        // Find which tab this webView belongs to
        if let tabId = getTabId(forWebView: webView) {
            // Update the loading state
            if let index = tabs.firstIndex(where: { $0.id == tabId }) {
                var updatedTab = tabs[index]
                
                // Determine which webview (primary or secondary) is being used
                let isSecondaryView = updatedTab.secondaryWebView === webView
                
                // Only set isLoading to true for the tab and update UI
                // if the webview being loaded is the active view in split mode
                let isPrimaryActive = (!updatedTab.isSplitView || updatedTab.activeSplitViewSide == .primary)
                let isSecondaryActive = (updatedTab.isSplitView && updatedTab.activeSplitViewSide == .secondary)
                
                // Set tab isLoading property correctly
                updatedTab.isLoading = true
                updatedTab.loadingProgress = 0.5 // Mid-way progress
                tabs[index] = updatedTab
                
                // Update activeTab reference if needed
                if activeTab?.id == tabId {
                    activeTab = updatedTab
                    
                    // Only update the global isLoading indicator if the active view is loading
                    if (isSecondaryView && isSecondaryActive) || (!isSecondaryView && isPrimaryActive) {
                        DispatchQueue.main.async {
                            self.isLoading = true
                            // Update published state to ensure UI is consistent
                            self.updatePublishedStateFromActiveSplit()
                        }
                    }
                }
                
                // Notify of the change
                objectWillChange.send()
            }
        }
    }
    
    // Called when navigation finishes successfully
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("WebViewModel: didFinish navigation")
        
        // Find which tab this webView belongs to
        if let tabId = getTabId(forWebView: webView) {
            // Update the loading state
            if let index = tabs.firstIndex(where: { $0.id == tabId }) {
                var updatedTab = tabs[index]
                
                // Determine which webview (primary or secondary) is being used
                let isSecondaryView = updatedTab.secondaryWebView === webView
                
                // Only update the global isLoading indicator if the active view finished loading
                let isPrimaryActive = (!updatedTab.isSplitView || updatedTab.activeSplitViewSide == .primary)
                let isSecondaryActive = (updatedTab.isSplitView && updatedTab.activeSplitViewSide == .secondary)
                
                // Set tab isLoading property correctly
                updatedTab.isLoading = false
                updatedTab.loadingProgress = 1.0 // Complete
                updatedTab.lastLoadedPageTitle = webView.title
                
                // Update the title for the correct webview
                let pageTitle = webView.title ?? "Untitled"
                if !pageTitle.isEmpty {
                    if isSecondaryView && updatedTab.isSplitView {
                        // If it's the secondary view and we're in split mode, update the title
                        // only if it's the active side
                        if isSecondaryActive {
                            updatedTab.title = pageTitle
                        }
                    } else {
                        // Otherwise it's the primary view, update the title
                        updatedTab.title = pageTitle
                    }
                }
                
                tabs[index] = updatedTab
                
                // Update activeTab reference if needed
                if activeTab?.id == tabId {
                    activeTab = updatedTab
                    
                    // Only update the global isLoading indicator if the active view finished loading
                    if (isSecondaryView && isSecondaryActive) || (!isSecondaryView && isPrimaryActive) {
                        DispatchQueue.main.async {
                            self.isLoading = false
                            // Update published state to ensure UI is consistent
                            self.updatePublishedStateFromActiveSplit()
                        }
                    }
                }
                
                // Notify of the change
                objectWillChange.send()
                
                // Update favicon if it's the primary webview
                if !isSecondaryView {
                    updateFavicon(for: tabId, in: webView)
                }
                
                // REMOVED: Reader mode availability check
                
                // Enable automatic PiP for this WebView if it's tracked
                if pipEnabledWebViews.contains(ObjectIdentifier(webView)) {
                    VideoDetectionService.shared.enableAutomaticPiP(for: webView)
                }
                
                // FOR INSTANT PiP: Check for videos immediately after navigation, especially for YouTube
                if let url = webView.url?.absoluteString, 
                   (url.contains("youtube.com") || url.contains("youtu.be")) {
                    print("WebViewModel: YouTube page loaded, setting up immediate video detection")
                    
                    // Add a short delay to allow YouTube to initialize its player
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        // Set up enhanced video detection for YouTube with more frequent checks
                        self.setupYouTubeVideoDetection(for: webView)
                    }
                }
                
                // Capture a preview for the tab after page is fully loaded
                // Add a slight delay to ensure all resources have loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Check again if the tab still exists and isn't loading
                    if let index = self.tabs.firstIndex(where: { $0.id == tabId }), 
                       !self.tabs[index].isLoading {
                        self.captureTabPreview(for: tabId)
                    }
                }
                
                // TRIGGER SPLIT-VIEW ANALYSIS: Update analysis when content changes in split view
                if updatedTab.isSplitView {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.updateSplitViewAnalysis()
                    }
                }
            }
        }
    }
    
    // Handle navigation failures
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("WebViewModel: didFailProvisionalNavigation with error: \(error.localizedDescription)")
        
        // Find which tab this webView belongs to
        if let tabId = getTabId(forWebView: webView) {
            // Update the loading state
            if let index = tabs.firstIndex(where: { $0.id == tabId }) {
                var updatedTab = tabs[index]
                
                // Determine which webview (primary or secondary) is being used
                let isSecondaryView = updatedTab.secondaryWebView === webView
                
                // Determine which side is active
                let isPrimaryActive = (!updatedTab.isSplitView || updatedTab.activeSplitViewSide == .primary)
                let isSecondaryActive = (updatedTab.isSplitView && updatedTab.activeSplitViewSide == .secondary)
                
                updatedTab.isLoading = false
                tabs[index] = updatedTab
                
                // Update activeTab reference if needed
                if activeTab?.id == tabId {
                    activeTab = updatedTab
                    
                    // Only update the global isLoading indicator if the active view failed loading
                    if (isSecondaryView && isSecondaryActive) || (!isSecondaryView && isPrimaryActive) {
                        DispatchQueue.main.async {
                            self.isLoading = false
                            // Update published state to ensure UI is consistent
                            self.updatePublishedStateFromActiveSplit()
                        }
                    }
                }
                
                // Store the error information
                navigationErrorOccurred = true
                navigationError = error.localizedDescription
                
                // Notify of the change
                objectWillChange.send()
                
                // Create an error preview only for primary view
                if !isSecondaryView {
                    DispatchQueue.main.async {
                        let placeholderImage = self.createErrorPlaceholderImage(
                            size: CGSize(width: 800, height: 600),
                            error: error.localizedDescription
                        )
                        
                        var updatedTab = self.tabs[index]
                        updatedTab.preview = placeholderImage
                        self.tabs[index] = updatedTab
                        self.previewRefreshNeeded[tabId] = false
                        
                        // Notify of the change
                        self.objectWillChange.send()
                    }
                }
            }
        }
    }
    
    // Handle navigation failures
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("WebViewModel: didFail with error: \(error.localizedDescription)")
        
        // Find which tab this webView belongs to
        if let tabId = getTabId(forWebView: webView) {
            // Update the loading state
            if let index = tabs.firstIndex(where: { $0.id == tabId }) {
                var updatedTab = tabs[index]
                
                // Determine which webview (primary or secondary) is being used
                let isSecondaryView = updatedTab.secondaryWebView === webView
                
                // Determine which side is active
                let isPrimaryActive = (!updatedTab.isSplitView || updatedTab.activeSplitViewSide == .primary)
                let isSecondaryActive = (updatedTab.isSplitView && updatedTab.activeSplitViewSide == .secondary)
                
                updatedTab.isLoading = false
                tabs[index] = updatedTab
                
                // Update activeTab reference if needed
                if activeTab?.id == tabId {
                    activeTab = updatedTab
                    
                    // Only update the global isLoading indicator if the active view failed loading
                    if (isSecondaryView && isSecondaryActive) || (!isSecondaryView && isPrimaryActive) {
                        DispatchQueue.main.async {
                            self.isLoading = false
                            // Update published state to ensure UI is consistent
                            self.updatePublishedStateFromActiveSplit()
                        }
                    }
                }
                
                // Store the error information
                navigationErrorOccurred = true
                navigationError = error.localizedDescription
                
                // Notify of the change
                objectWillChange.send()
            }
        }
    }
    
    // MARK: - WKDownloadDelegate Methods
    
    // --- REQUIRED: Decide Download Destination ---
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let fileManager = FileManager.default
        // Get the default Downloads directory URL
        guard let downloadsDirectory = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            print("WebViewModel Error: Could not find Downloads directory.")
            completionHandler(nil) // Cancel download if directory not found
            return
        }
        
        // Create a unique filename to avoid overwriting
        let fileName = "\(UUID().uuidString)_\(suggestedFilename)"
        let destinationURL = downloadsDirectory.appendingPathComponent(fileName)
        
        print("WebViewModel: Decided download destination: \(destinationURL.path)")
        completionHandler(destinationURL)
    }
    
    // --- Handle Download Progress ---
    func download(_ download: WKDownload, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let index = downloadItems.firstIndex(where: { item in
            activeDownloads[item.id] === download
        }) else { return }
        
        DispatchQueue.main.async {
            self.downloadItems[index].progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            self.downloadItems[index].fileSize = totalBytesExpectedToWrite // Update total size
        }
    }
    
    // --- Handle Download Completion ---
    func download(_ download: WKDownload, didFinishDownloadingTo location: URL) {
        guard let index = downloadItems.firstIndex(where: { item in
            activeDownloads[item.id] === download
        }) else { return }
        
        DispatchQueue.main.async {
            // The file is already at the destination decided earlier
            // We just need to update the state and store the final URL
            self.downloadItems[index].state = .completed
            self.downloadItems[index].progress = 1.0
            // The 'location' provided here is temporary, the actual file is at the
            // destination we chose in decideDestinationUsing. We need to find that URL again.
            // This requires associating the download object with the destination URL better.
            
            // For now, let's try to reconstruct based on filename (less robust)
             let fileManager = FileManager.default
             if let downloadsDirectory = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                 // Assume the filename we constructed earlier is correct
                 let fileName = "\(self.downloadItems[index].id.uuidString)_\(self.downloadItems[index].filename)" // Reconstruct filename based on original logic. This is fragile.
                 let potentialFinalURL = downloadsDirectory.appendingPathComponent(fileName)
                 
                 if fileManager.fileExists(atPath: potentialFinalURL.path) {
                     self.downloadItems[index].localURL = potentialFinalURL
                     print("WebViewModel: Download finished, confirmed file at: \(potentialFinalURL.path)")
                 } else {
                     // Fallback: Try to move the temporary file (might fail due to sandbox)
                     print("WebViewModel Warning: Could not confirm file at originally decided path. Trying to use temporary location: \(location.path)")
                      do {
                           let downloadsDirectory = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first!
                           let finalFilename = self.downloadItems[index].filename // Use original suggested filename as fallback
                           let finalDestination = downloadsDirectory.appendingPathComponent(finalFilename)
                           // Ensure unique filename if fallback is used
                           var uniqueURL = finalDestination
                           var counter = 1
                           while fileManager.fileExists(atPath: uniqueURL.path) {
                               let name = finalDestination.deletingPathExtension().lastPathComponent
                               let ext = finalDestination.pathExtension
                               uniqueURL = downloadsDirectory.appendingPathComponent("\(name)_\(counter).\(ext)")
                               counter += 1
                           }
                           
                           try fileManager.moveItem(at: location, to: uniqueURL)
                           self.downloadItems[index].localURL = uniqueURL
                           print("WebViewModel: Successfully moved temporary download to: \(uniqueURL.path)")
                      } catch {
                          print("WebViewModel Error: Failed to move downloaded file from temporary location: \(error)")
                          self.downloadItems[index].state = .failed
                      }
                 }
             } else {
                 print("WebViewModel Error: Could not get Downloads directory to finalize download path.")
                 self.downloadItems[index].state = .failed
             }
            
            self.activeDownloads.removeValue(forKey: self.downloadItems[index].id)
            self.saveDownloadsToDisk()
        }
    }
    
    // --- Handle Download Failure ---
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        guard let index = downloadItems.firstIndex(where: { item in
            activeDownloads[item.id] === download
        }) else { return }
        
        DispatchQueue.main.async {
            print("WebViewModel: Download failed: \(error.localizedDescription)")
            self.downloadItems[index].state = .failed
            self.activeDownloads.removeValue(forKey: self.downloadItems[index].id)
            self.saveDownloadsToDisk()
        }
    }

    // MARK: - WKUIDelegate Methods
    
    // --- Context Menu Handling (macOS) ---
    // Implementation for the standard WKContextMenuElementInfo API
    @available(macOS 10.10, *)
    func webView(_ webView: WKWebView, contextMenuConfigurationForElement elementInfo: Any, completionHandler: @escaping (NSMenu?) -> Void) {
        
        // !!! ADDED DIAGNOSTIC LOG !!!
        print("DEBUG: WebViewModel - contextMenuConfigurationForElement CALLED")
        
        // Find which tab and side this webView belongs to
        guard let tabIndex = self.tabs.firstIndex(where: { $0.primaryWebView === webView || $0.secondaryWebView === webView }) else {
            completionHandler(nil) // Use default menu if webView is unknown
            return
        }
        let tabId = self.tabs[tabIndex].id
        let isCurrentTabSplit = self.tabs[tabIndex].isSplitView
        let currentSide: SplitViewSide = (self.tabs[tabIndex].primaryWebView === webView) ? .primary : .secondary
        
        let newMenu = NSMenu(title: "")
        var addedCustomItems = false
        
        // --- Link Actions ---
        if let typedInfo = elementInfo as? WKContextMenuElementInfo, let linkURL = typedInfo.linkURL {
            
            // Action: Open in Other/New Split
            if isCurrentTabSplit {
                let otherSide: SplitViewSide = (currentSide == .primary) ? .secondary : .primary
                let menuItem = NSMenuItem(title: "Open Link in Other Split", action: #selector(openLinkInOtherSplitFromMenu(_:)), keyEquivalent: "")
                menuItem.representedObject = ["url": linkURL, "tabId": tabId, "targetSide": otherSide] as [String: Any]
                menuItem.target = self // Action is in this ViewModel
                newMenu.addItem(menuItem)
                addedCustomItems = true
            } else {
                let menuItem = NSMenuItem(title: "Open Link in New Split View", action: #selector(openLinkInNewSplitFromMenu(_:)), keyEquivalent: "")
                menuItem.representedObject = ["url": linkURL, "tabId": tabId] as [String: Any]
                menuItem.target = self
                newMenu.addItem(menuItem)
                addedCustomItems = true
            }
            
            // Action: Open in New Tab
            let openInNewTabItem = NSMenuItem(title: "Open Link in New Tab", action: #selector(openLinkInNewTabFromMenu(_:)), keyEquivalent: "")
            openInNewTabItem.representedObject = linkURL // Pass URL directly
            openInNewTabItem.target = self
            newMenu.addItem(openInNewTabItem)
            addedCustomItems = true
            
            // Action: Copy Link Address
            let copyLinkItem = NSMenuItem(title: "Copy Link Address", action: #selector(copyLinkFromMenu(_:)), keyEquivalent: "")
            copyLinkItem.representedObject = linkURL // Pass URL directly
            copyLinkItem.target = self
            newMenu.addItem(copyLinkItem)
            addedCustomItems = true
            
            newMenu.addItem(NSMenuItem.separator())
        } else {
            // Try more general way to get URL if WKContextMenuElementInfo cast fails
            #if os(macOS)
            // This is macOS-specific code that tries to extract URL from the element if the cast fails
            if let dictionary = elementInfo as? [String: Any], 
               let url = dictionary["URL"] as? URL {
                // Add similar menu items for the URL
                // ... 
                addedCustomItems = true
            }
            #endif
        }
        
        // Return custom menu or nil to use default
        completionHandler(addedCustomItems ? newMenu : nil)
    }
    
    // Alternate implementation for older WebKit versions (if needed)
    // --- ADDED DEPRECATED METHOD FOR DIAGNOSTICS ---
    @available(macOS, deprecated: 10.15, message: "Use contextMenuConfigurationForElement instead")
    func webView(_ webView: WKWebView, contextMenu: NSMenu, forElement element: Any, defaultMenuItems: [NSMenuItem]) -> NSMenu? {
        // !!! ADDED DIAGNOSTIC LOG FOR DEPRECATED METHOD !!!
        print("DEBUG: WebViewModel - DEPRECATED contextMenu FOR ELEMENT CALLED")
        
        // For diagnostics, let's just return the default items for now if this gets called
        return contextMenu
        // We could try building our custom menu here too if needed for further debugging
    }
    
    // --- @objc Helper Methods for Context Menu Actions ---
    
    @objc func openLinkInOtherSplitFromMenu(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: Any],
              let url = info["url"] as? URL,
              let tabId = info["tabId"] as? UUID,
              let targetSide = info["targetSide"] as? SplitViewSide else {
            print("WebViewModel Error: Could not get info from openLinkInOtherSplitFromMenu sender.")
            return
        }
        print("Context Menu: Open Link in Other Split (\(targetSide)) for tab \(tabId)")
        self.loadURLInSplit(url: url, for: tabId, targetSide: targetSide)
    }
    
    @objc func openLinkInNewSplitFromMenu(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: Any],
              let url = info["url"] as? URL,
              let tabId = info["tabId"] as? UUID else {
            print("WebViewModel Error: Could not get info from openLinkInNewSplitFromMenu sender.")
            return
        }
        print("Context Menu: Open Link in New Split View for tab \(tabId)")
        // Activate split view FIRST
        self.toggleSplitView(for: tabId)
        // Load into secondary AFTER toggle (might need slight delay)
        DispatchQueue.main.async { // No delay needed if toggleSplitView is synchronous now
            self.loadURLInSplit(url: url, for: tabId, targetSide: .secondary)
        }
    }
    
    @objc func openLinkInNewTabFromMenu(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else {
            print("WebViewModel Error: Could not get URL from openLinkInNewTabFromMenu sender.")
            return
        }
        print("Context Menu: Open Link in New Tab")
        self.addNewTab(urlToLoad: nil) // Creates and activates the new tab
        // Load URL into the newly active tab
        // addNewTab should set activeTab synchronously
        if activeTab != nil {
            self.loadURL(from: url.absoluteString)
        } else {
            print("WebViewModel Error: activeTab is nil after addNewTab during context menu action.")
        }
    }
    
    @objc func copyLinkFromMenu(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else {
            print("WebViewModel Error: Could not get URL from copyLinkFromMenu sender.")
            return
        }
        print("Context Menu: Copy Link Address")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }

    // --- createWebViewWith handling ---
    // (Keep existing logic using loadURLInSplit)
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        print("WebViewModel WKUIDelegate: createWebViewWith triggered.")
        if let url = navigationAction.request.url {
            // Check if this is a drag operation within split view
            if let tab = findTabForWebView(webView) {
                let isActiveSplitView = tab.isSplitView
                let isFromPrimaryView = webView === tab.primaryWebView
                
                // If we have an active split view, try to detect drag between panes
                if isActiveSplitView && navigationAction.targetFrame == nil {
                    if isFromPrimaryView && tab.secondaryWebView != nil {
                        // If dragged from primary and secondary exists, load in secondary
                        print("WebViewModel: Drag detected from primary view to secondary. Loading URL: \(url)")
                        loadURLInSplit(url: url, for: tab.id, targetSide: .secondary)
                        
                        // Make secondary the active side
                        setActiveSplitSide(for: tab.id, side: .secondary)
                        return nil
                    } else if !isFromPrimaryView {
                        // If dragged from secondary, load in primary
                        print("WebViewModel: Drag detected from secondary view to primary. Loading URL: \(url)")
                        loadURLInSplit(url: url, for: tab.id, targetSide: .primary)
                        
                        // Make primary the active side
                        setActiveSplitSide(for: tab.id, side: .primary)
                        return nil
                    }
                }
                
                // If not handled as drag between split panes, create a new tab
                print("WebViewModel: Opening URL in new tab: \(url)")
                self.addNewTab(urlToLoad: url.absoluteString)
                return nil
            } else {
                // Fallback if tab not found - create new tab
                print("WebViewModel: Could not find containing tab. Opening URL in new tab: \(url)")
                self.addNewTab(urlToLoad: url.absoluteString)
                return nil
            }
        }
        return nil // Prevent AppKit from creating a new window if URL is nil
    }

    // MARK: - Helper Methods
    
    // --- Helper to get page text --- 
    func getPageText(completion: @escaping (Result<String, Error>) -> Void) {
        guard !isShowingHomepage, let _ = webView.url else {
            completion(.failure(NSError(domain: "WebViewModelError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot get text from homepage or invalid URL."])))
            return
        }
        
        webView.evaluateJavaScript("document.body.innerText") { result, error in
            if let error = error {
                completion(.failure(error))
            } else if let text = result as? String {
                completion(.success(text))
            } else {
                completion(.failure(NSError(domain: "WebViewModelError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not extract text from page."])))
            }
        }
    }
    
    /// Get the currently selected text in the active web view
    func getSelectedText(completion: @escaping (String?) -> Void) {
        // Make sure we have an active web view
        guard let webView = activeTab?.primaryWebView else {
            completion(nil)
            return
        }
        
        // JavaScript to get the selected text
        let script = """
        (function() {
            return window.getSelection().toString();
        })();
        """
        
        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("WebViewModel: Error getting selected text: \(error)")
                completion(nil)
                return
            }
            
            guard let selectedText = result as? String, !selectedText.isEmpty else {
                completion(nil)
                return
            }
            
            completion(selectedText)
        }
    }

    /// Show citations view
    func showCitations() {
        // Hide other views
        isShowingHomepage = false
        showingHistoryView = false
        showingDownloadsView = false
        
        // Show citations view
        DispatchQueue.main.async {
            self.showingCitationsView = true
        }
    }

    // REMOVED: All toolbar action methods and AIActionType enum as per user request

    // --- NEW: Toggle Pin State ---
    func togglePinState(for tabId: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        
        tabs[index].isPinned.toggle()
        
        // Optional: Re-sort the tabs array to keep pinned tabs grouped?
        // For simplicity now, we'll rely on the View filtering.
        // If sorting is desired:
        // tabs.sort { $0.isPinned && !$1.isPinned } // Pinned first
        
        // If we're toggling on, we should ensure there's a preview
        if tabs[index].isPinned && (tabs[index].preview == nil || doesTabNeedPreviewRefresh(id: tabId)) {
            captureTabPreview(for: tabId)
        }
        
        print("WebViewModel: Toggled pin state for tab \(tabId) to \(tabs[index].isPinned)")
        // No persistence yet
    }

    // --- NEW: Toggle Split View State ---
    func toggleSplitView(for tabId: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        
        // First update the model state
        let newSplitState = !tabs[index].isSplitView
        tabs[index].isSplitView = newSplitState
        print("WebViewModel: Toggled split view for tab \(tabId) to \(newSplitState)")
        
        // If entering split view and no secondary view exists, create it
        if newSplitState {
            if tabs[index].secondaryWebView == nil {
                print("WebViewModel: Creating secondary WebView for split view.")
                tabs[index].secondaryWebView = createNewWebView()
                
                // --- BEHAVIOR CHANGE: Load primary URL into secondary view ---
                if let primaryURL = tabs[index].primaryWebView.url {
                    print("WebViewModel: Loading primary URL (\(primaryURL.absoluteString)) into new secondary view.")
                    tabs[index].secondaryWebView?.load(URLRequest(url: primaryURL))
                } else if let homepage = URL(string: self.homepageURLString) {
                    print("WebViewModel: Primary URL not available, loading homepage into new secondary view.")
                    tabs[index].secondaryWebView?.load(URLRequest(url: homepage))
                } else {
                    print("WebViewModel: Neither primary nor homepage URL available for secondary view.")
                    tabs[index].secondaryWebView?.loadHTMLString("<html><body>Error: Could not load initial content.</body></html>", baseURL: nil)
                }
            } else {
                print("WebViewModel: Secondary WebView already exists, reusing it")
            }
            
            // Set active split side to secondary when toggling on (new behavior for better UX)
            tabs[index].activeSplitViewSide = .secondary
            // Make sure to update the published state to reflect the secondary side
            updatePublishedStateFromActiveSplit()
            
            // TRIGGER SPLIT-VIEW ANALYSIS: Start monitoring both views for AI analysis
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.updateSplitViewAnalysis()
            }
        } else {
            // If exiting split view, clean up secondary view
            print("WebViewModel: Exiting split view, cleaning up secondary webview")
            tabs[index].secondaryWebView = nil
            
            // Since we're exiting split view, ensure primary is active
            tabs[index].activeSplitViewSide = .primary
            
            // Important: Reset isLoading to match the primary WebView's state
            // Fixes the issue where loading indicator stays active after exiting split view
            let tab = tabs[index]
            if tab.isActive {
                DispatchQueue.main.async {
                    self.isLoading = tab.primaryWebView.isLoading
                    print("WebViewModel: Reset isLoading to \(tab.primaryWebView.isLoading) when exiting split view")
                }
            }
            
            // Update published state to reflect primary side
            updatePublishedStateFromActiveSplit()
            
            // STOP SPLIT-VIEW ANALYSIS: Stop monitoring when exiting split view
            splitViewAnalyzer?.stopMonitoring()
        }
        
        // Ensure view update
        DispatchQueue.main.async {
            // Explicitly update tab
            if let index = self.tabs.firstIndex(where: { $0.id == tabId }) {
                // Make a copy of the tab and update it to ensure the view updates
                var updatedTab = self.tabs[index]
                self.tabs[index] = updatedTab
                
                // Update active tab reference if this is the active tab
                if self.activeTab?.id == tabId {
                    self.activeTab = updatedTab
                }
            }
            
            // Notify all observers of the change immediately
            self.objectWillChange.send()
            
            // Log the refresh
            print("WebViewModel: Forced UI refresh for tab \(tabId)")
        }
    }

    // New method to force UI state synchronization after critical state changes
    private func forceUIRefresh(for tabId: UUID) {
        // This method is called after operations that require immediate UI updates
        // First, ensure we're on the main thread
        DispatchQueue.main.async {
            // Only update if the tab exists
            guard let index = self.tabs.firstIndex(where: { $0.id == tabId }) else { return }
            
            // First refresh the activeTab reference if needed
            if self.activeTab?.id == tabId {
                self.activeTab = self.tabs[index]
            }
            
            // Sync all published properties with the active WebView's state
            self.updatePublishedStateFromActiveSplit()
            
            // Then send an objectWillChange notification to trigger UI updates
            self.objectWillChange.send()
            
            // Log the refresh
            print("WebViewModel: Forced UI refresh for tab \(tabId)")
        }
    }

    // --- CORRECTED: activeWebViewInSplit implementation ---
    // Returns the WKWebView instance that should be considered active
    // based on the current tab's split state and focus.
    var activeWebViewInSplit: WKWebView? { 
        guard let tab = activeTab else { return nil }
        
        if tab.isSplitView {
            switch tab.activeSplitViewSide {
            case .primary:
                print("WebViewModel: Using primary webview for active operations")
                return tab.primaryWebView
            case .secondary:
                // Ensure secondary exists before returning (should always exist if isSplitView is true after toggle logic)
                if let secondaryWebView = tab.secondaryWebView {
                    print("WebViewModel: Using secondary webview for active operations")
                    return secondaryWebView
                } else {
                    print("WebViewModel WARNING: Secondary webview requested but is nil, falling back to primary")
                    return tab.primaryWebView // Fallback to primary if secondary is somehow nil
                }
            }
        } else {
            // In single view mode, always use primary
            return tab.primaryWebView
        }
    }

    // NEW: Capture a preview thumbnail of a tab's webview
    func captureTabPreview(for tabId: UUID) {
        // Skip if tab doesn't exist
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else {
            print("WebViewModel: Cannot capture preview, tab not found")
            return
        }
        
        // Avoid capturing preview when the WebView is still loading
        if tabs[index].primaryWebView.isLoading {
            print("WebViewModel: Skipping preview capture - tab is not loaded yet or is still loading")
            // Mark for refresh later when loading is complete
            markTabForPreviewRefresh(id: tabId)
            return
        }
        
        // Avoid redundant captures if we already have a preview and it's not marked for refresh
        if tabs[index].preview != nil && !doesTabNeedPreviewRefresh(id: tabId) {
            return
        }
        
        // Don't use animation for capturing previews to avoid layout recursion
        let webView = tabs[index].primaryWebView
        
        // Define the snapshot size with a wider view to show more content
        let width: CGFloat = 1000.0 // Increased from 800 to capture more content
        
        // Use a scaled-down version of actual aspect ratio to show more vertical content
        // This creates a more "zoomed out" view that shows more of the page
        let webViewAspectRatio = webView.frame.height / webView.frame.width
        let adjustedAspectRatio = webViewAspectRatio * 0.75 // Reduce aspect ratio to show more vertical content
        let height = width * adjustedAspectRatio
        
        // Skip if the webview size is invalid
        if width <= 0 || height <= 0 || webView.frame.width <= 0 {
            return
        }
        
        // Create configuration for the snapshot
        let config = WKSnapshotConfiguration()
        config.rect = CGRect(x: 0, y: 0, width: width, height: height)
        
        // Use a debounce mechanism to avoid multiple rapid captures
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            print("WebViewModel: Capturing preview for tab \(tabId)")
            
            // Take the snapshot asynchronously to avoid blocking UI
            webView.takeSnapshot(with: config) { [weak self] image, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("WebViewModel: Error capturing tab preview: \(error)")
                    return
                }
                
                if let image = image, let index = self.tabs.firstIndex(where: { $0.id == tabId }) {
                    // Update the tab preview on the main thread without unnecessary UI updates
                    DispatchQueue.main.async {
                        // Check again if the tab still exists
                        guard index < self.tabs.count else { return }
                        
                        // Update the tab preview - Assign the NSImage directly
                        self.tabs[index].preview = image
                        
                        // Clear refresh flag
                        self.previewRefreshNeeded[tabId] = false
                        
                        print("WebViewModel: Successfully captured preview for tab \(tabId) - image size: \(image.size.width)x\(image.size.height)")
                        
                        // Only update UI if this is the active tab to avoid unnecessary redraws
                        if self.activeTab?.id == tabId {
                            self.objectWillChange.send()
                        }
                    }
                }
            }
        }
    }

    // Helper function to create placeholder images for special cases
    private func createPlaceholderImage(size: CGSize, text: String) -> NSImage {
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Fill with a light gray background
        NSColor.lightGray.withAlphaComponent(0.2).setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        
        // Draw the text
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .medium),
            .foregroundColor: NSColor.darkGray,
            .paragraphStyle: paragraphStyle
        ]
        
        let textRect = NSRect(
            x: 0,
            y: (size.height - 30) / 2,  // Center vertically
            width: size.width,
            height: 30
        )
        
        text.draw(in: textRect, withAttributes: attributes)
        
                    // Add the iBrowsy logo or icon if available
        if let appIcon = NSImage(named: "AppIcon") {
            let iconSize = CGSize(width: 64, height: 64)
            let iconRect = NSRect(
                x: (size.width - iconSize.width) / 2,
                y: (size.height - iconSize.height) / 2 - 50,  // Above the text
                width: iconSize.width,
                height: iconSize.height
            )
            appIcon.draw(in: iconRect)
        }
        
        image.unlockFocus()
        
        return image
    }

    // Helper method to process and resize snapshot images
    private func processSnapshotImage(_ image: NSImage, targetSize: CGSize) -> NSImage {
        // Create a new image with the desired size
        let resizedImage = NSImage(size: targetSize)
        
        resizedImage.lockFocus()
        
        // Draw the original image in the new image
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            NSGraphicsContext.current?.imageInterpolation = .high
            let rect = CGRect(origin: .zero, size: targetSize)
            let context = NSGraphicsContext.current?.cgContext
            context?.draw(cgImage, in: rect)
        }
        
        resizedImage.unlockFocus()
        
        return resizedImage
    }
    
    // NEW: Mark a tab as needing preview refresh
    func markTabForPreviewRefresh(id: UUID) {
        previewRefreshNeeded[id] = true
    }
    
    // NEW: Check if tab needs preview refresh
    func doesTabNeedPreviewRefresh(id: UUID) -> Bool {
        return previewRefreshNeeded[id] ?? true
    }
    
    // NEW: Force refresh previews for all tabs
    func refreshAllTabPreviews() {
        print("WebViewModel: Refreshing all tab previews")
        
        for tab in tabs {
            // Force refresh for all tabs to ensure consistent previews
            if !tab.primaryWebView.isLoading && tab.primaryWebView.url != nil {
                print("WebViewModel: Refreshing preview for tab \(tab.id)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1 * Double(tabs.firstIndex(where: { $0.id == tab.id }) ?? 0)) {
                    self.captureTabPreview(for: tab.id)
                }
            } else {
                // Mark for later refresh
                self.previewRefreshNeeded[tab.id] = true
                print("WebViewModel: Marking tab \(tab.id) for future preview refresh")
            }
        }
    }

    // Helper method to update favicon for a tab
    private func updateFavicon(for tabId: UUID, in webView: WKWebView) {
        guard let url = webView.url, !url.absoluteString.hasPrefix("ibrowsy://") else { return }
        
        Task {
            if let favicon = await FaviconLoader.shared.getFavicon(for: url.absoluteString) {
                await MainActor.run {
                    if let index = self.tabs.firstIndex(where: { $0.id == tabId }) {
                        var updatedTab = self.tabs[index]
                        updatedTab.favicon = favicon
                        self.tabs[index] = updatedTab
                        
                        // Update active tab reference if needed
                        if self.activeTab?.id == tabId {
                            self.activeTab = updatedTab
                        }
                        
                        // Notify UI
                        self.objectWillChange.send()
                    }
                }
            }
        }
    }

    // REMOVED: Reader mode availability check as per user request

    // Helper method to find which tab a webView belongs to
    private func getTabId(forWebView webView: WKWebView) -> UUID? {
        if let tab = tabs.first(where: { $0.primaryWebView === webView || $0.secondaryWebView === webView }) {
            return tab.id
        }
        return nil
    }
    
    // Helper function to create error placeholder images
    private func createErrorPlaceholderImage(size: CGSize, error: String) -> NSImage {
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Fill with a light red background
        NSColor.red.withAlphaComponent(0.1).setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        
        // Draw the error icon
        if let errorIcon = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil) {
            let iconSize = CGSize(width: 64, height: 64)
            let iconRect = NSRect(
                x: (size.width - iconSize.width) / 2,
                y: (size.height - iconSize.height) / 2 + 30,  // Above the text
                width: iconSize.width,
                height: iconSize.height
            )
            
            // Set the icon color
            NSColor.red.withAlphaComponent(0.8).set()
            errorIcon.draw(in: iconRect)
        }
        
        // Draw the error text
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        // Title attributes
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: NSColor.red.withAlphaComponent(0.8),
            .paragraphStyle: paragraphStyle
        ]
        
        let titleRect = NSRect(
            x: 0,
            y: (size.height - 30) / 2,  // Center vertically
            width: size.width,
            height: 30
        )
        
        "Page Load Error".draw(in: titleRect, withAttributes: titleAttributes)
        
        // Error message attributes
        let errorAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.darkGray,
            .paragraphStyle: paragraphStyle
        ]
        
        // Truncate error message if too long
        let truncatedError = error.count > 80 ? error.prefix(80) + "..." : error
        
        let errorRect = NSRect(
            x: 40,
            y: (size.height - 30) / 2 - 40,  // Below the title
            width: size.width - 80,
            height: 60
        )
        
        truncatedError.draw(in: errorRect, withAttributes: errorAttributes)
        
        image.unlockFocus()
        
        return image
    }

    // Get the current scroll position for a tab
    func getScrollPosition(for tabId: UUID) -> CGPoint? {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else {
            return nil
        }
        
        let tab = tabs[index]
        
        // Determine which webView to check based on active split
        let webViewToCheck: WKWebView
        if tab.isSplitView && tab.activeSplitViewSide == .secondary && tab.secondaryWebView != nil {
            webViewToCheck = tab.secondaryWebView!
        } else {
            webViewToCheck = tab.primaryWebView
        }
        
        // Get scroll position using JavaScript
        var scrollPosition: CGPoint?
        let semaphore = DispatchSemaphore(value: 0)
        
        webViewToCheck.evaluateJavaScript("{ x: window.scrollX, y: window.scrollY }") { (result, error) in
            if let scrollDict = result as? [String: CGFloat], 
               let x = scrollDict["x"], 
               let y = scrollDict["y"] {
                scrollPosition = CGPoint(x: x, y: y)
            }
            semaphore.signal()
        }
        
        // Wait briefly for the result (don't block UI thread)
        _ = semaphore.wait(timeout: .now() + 0.1)
        return scrollPosition
    }

    // Restore scroll position for a tab
    func restoreScrollPosition(tabId: UUID, position: CGPoint) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else {
            return
        }
        
        let tab = tabs[index]
        
        // Determine which webView to use based on active split
        let webViewToUpdate: WKWebView
        if tab.isSplitView && tab.activeSplitViewSide == .secondary && tab.secondaryWebView != nil {
            webViewToUpdate = tab.secondaryWebView!
        } else {
            webViewToUpdate = tab.primaryWebView
        }
        
        // Use JavaScript to restore scroll position
        let js = "window.scrollTo(\(position.x), \(position.y));"
        webViewToUpdate.evaluateJavaScript(js, completionHandler: nil)
    }

    // Add this method to execute JavaScript in the active tab
    func executeJavaScript(_ script: String, in tab: BrowserTab?, completion: @escaping (Any?) -> Void) {
        guard let tab = tab ?? activeTab else {
            completion(nil)
            return
        }
        
        let webViewToUse: WKWebView?
        if tab.isSplitView {
            webViewToUse = (tab.activeSplitViewSide == .primary) ? tab.primaryWebView : tab.secondaryWebView
        } else {
            webViewToUse = tab.primaryWebView
        }
        
        guard let webView = webViewToUse else {
            completion(nil)
            return
        }
        
        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("WebViewModel: JavaScript execution error - \(error.localizedDescription)")
                completion(nil)
            } else {
                completion(result)
            }
        }
    }

    // Add these drag and drop methods to properly handle dragged content between web views
    @available(macOS 10.13, *)
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
        // If the dragged element is a link, handle it
        if navigationAction.navigationType == .linkActivated, 
           let url = navigationAction.request.url,
           let tab = findTabForWebView(webView) {
            
            let isFromPrimaryView = webView === tab.primaryWebView
            print("WKUIDelegate: Link activated from \(isFromPrimaryView ? "primary" : "secondary") view: \(url.absoluteString)")
            
            // Enhanced drag detection: Check for modifier keys (shift, option) or middle-click
            // which are common ways to trigger "open in new window/tab" behavior
            let hasDragModifier = navigationAction.modifierFlags.contains(.shift) || 
                                 navigationAction.modifierFlags.contains(.option) ||
                                 navigationAction.buttonNumber == 2 // Middle click detection
            
            // Handle drag operations between split views
            if tab.isSplitView && hasDragModifier {
                // Use modifier key or middle click as indicator for a drag operation between panes
                // Determine the target view based on where the drag originated
                let targetSide: SplitViewSide = isFromPrimaryView ? .secondary : .primary
                
                // Check if target side exists
                if (targetSide == .secondary && tab.secondaryWebView != nil) || targetSide == .primary {
                    print("WebViewModel: Drag detected from \(isFromPrimaryView ? "primary to secondary" : "secondary to primary") view. Loading URL: \(url)")
                    
                    // Run on main queue to avoid threading issues
                    Task { @MainActor in
                        loadURLInSplit(url: url, for: tab.id, targetSide: targetSide)
                        setActiveSplitSide(for: tab.id, side: targetSide)
                    }
                    
                    return (.cancel, preferences) // Cancel the original navigation
                }
            }
            
            return (.allow, preferences)
        }
        
        // Default behavior
        return (.allow, preferences)
    }

    // Helper to find which tab contains a given WebView
    private func findTabForWebView(_ webView: WKWebView) -> BrowserTab? {
        return tabs.first { tab in
            return tab.primaryWebView === webView || tab.secondaryWebView === webView
        }
    }

    // Add method to update the primary pane width for split view
    func updatePrimaryPaneWidth(for tabId: UUID, width: CGFloat) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { 
            return
        }
        
        // Only update if the value actually changed
        if tabs[index].primaryPaneDesiredWidth != width {
            tabs[index].primaryPaneDesiredWidth = width
            print("WebViewModel: Updated primary pane width for tab \(tabId) to \(width)")
            
            // If this is the active tab, update its reference
            if activeTab?.id == tabId {
                activeTab = tabs[index]
            }
        }
    }

    // Trigger auto-PiP when app/window loses focus
    func triggerAutoPiPOnFocusLoss() {
        guard let currentTab = activeTab else { return }
        
        // Reduce cooldown for immediate response on minimize
        let now = Date()
        if let lastTrigger = lastAutoPiPTrigger {
            let timeSinceLastTrigger = now.timeIntervalSince(lastTrigger)
            if timeSinceLastTrigger < 0.05 { // Very short cooldown for immediate response
                print("WebViewModel: Skipping focus loss trigger - cooldown active (\(timeSinceLastTrigger)s < 0.05s)")
                return
            }
        }
        
        lastAutoPiPTrigger = now
        print("WebViewModel: App lost focus, immediately triggering PiP for playing videos")
        checkAndTriggerAutoPiP(for: currentTab, immediate: true)
    }
    
    // Track focus return to prevent duplicate calls
    private var lastBrowserReturnFocusTime: Date?
    private let browserReturnFocusCooldown: TimeInterval = 0.3
    
    // Handle browser returning to focus - stop PiP and sync timeline
    func handleBrowserReturnFocus() {
        // Prevent duplicate calls within short time period
        let now = Date()
        if let lastReturn = lastBrowserReturnFocusTime {
            let timeSinceLastReturn = now.timeIntervalSince(lastReturn)
            if timeSinceLastReturn < browserReturnFocusCooldown {
                print("WebViewModel: Skipping browser return focus - cooldown active (\(timeSinceLastReturn)s < \(browserReturnFocusCooldown)s)")
                return
            }
        }
        
        lastBrowserReturnFocusTime = now
        print("WebViewModel: Browser returned to focus, checking for PiP windows to close")
        
        // Only close PiP windows if there are actually any active
        guard !PiPManager.shared.activePiPWindows.isEmpty else {
            print("WebViewModel: No active PiP windows to close")
            return
        }
        
        // Get current active tab
        guard let currentTab = activeTab else { return }
        let webView = currentTab.isSplitView && currentTab.activeSplitViewSide == .secondary ? currentTab.secondaryWebView : currentTab.primaryWebView
        guard let targetWebView = webView else { return }
        
        // Check if we're on a YouTube page
        guard let currentURL = targetWebView.url?.absoluteString,
              (currentURL.contains("youtube.com") || currentURL.contains("youtu.be")) else {
            print("WebViewModel: Not on YouTube page, closing PiP windows without sync")
            PiPManager.shared.closeAllPiPWindows()
            return
        }
        
        // Close PiP windows and sync timeline back to main video
        PiPManager.shared.closeAllPiPWindowsAndSyncTimeline(to: targetWebView)
    }
    
    // Emergency method to clean up excessive PiP windows
    func cleanupExcessivePiPWindows() {
        Task { @MainActor in
            PiPManager.shared.cleanupExcessivePiPWindows()
        }
    }
    
    // MARK: - YouTube Video Detection for Instant PiP
    
    private func setupYouTubeVideoDetection(for webView: WKWebView) {
        let script = """
        (function() {
            console.log('Setting up enhanced YouTube video detection for instant PiP');
            
            var pipCheckInterval;
            var isVideoPlaying = false;
            var lastVideoId = null;
            
            function checkForVideoAndPiP() {
                try {
                    var ytPlayer = document.querySelector('#movie_player, .html5-video-player');
                    if (ytPlayer) {
                        var video = ytPlayer.querySelector('video');
                        if (video && !video.paused && !video.ended) {
                            var currentVideoId = new URLSearchParams(window.location.search).get('v');
                            
                            // If this is a new video or video just started playing
                            if (!isVideoPlaying || currentVideoId !== lastVideoId) {
                                console.log('YouTube video detected as playing:', currentVideoId);
                                isVideoPlaying = true;
                                lastVideoId = currentVideoId;
                                
                                // Immediately check if app has focus - if not, trigger PiP
                                setTimeout(function() {
                                    // Use the page visibility API to check if browser is active
                                    if (document.hidden || !document.hasFocus()) {
                                        console.log('Browser not focused, triggering immediate PiP');
                                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.pipRequest) {
                                            window.webkit.messageHandlers.pipRequest.postMessage({
                                            src: window.location.href,
                                            title: document.title || 'YouTube Video',
                                            currentTime: video.currentTime || 0,
                                            duration: video.duration || 0,
                                            width: video.videoWidth || 640,
                                            height: video.videoHeight || 360,
                                            isPlaying: true,
                                            elementType: 'iframe'
                                        });
                                            console.log('PiP Detection: Successfully sent immediate PiP request');
                                        } else {
                                            console.log('PiP Detection: Error - pipRequest message handler not available');
                                        }
                                    }
                                }, 100);
                            }
                        } else if (isVideoPlaying) {
                            // Video stopped playing
                            isVideoPlaying = false;
                            console.log('YouTube video stopped playing');
                        }
                    }
                } catch (error) {
                    console.log('Error in YouTube video detection:', error);
                }
            }
            
            // Set up immediate checking when video events occur
            function setupVideoEventListeners() {
                var videos = document.querySelectorAll('video');
                videos.forEach(function(video) {
                    video.addEventListener('play', function() {
                        console.log('YouTube video play event detected');
                        setTimeout(checkForVideoAndPiP, 100);
                    });
                    
                    video.addEventListener('playing', function() {
                        console.log('YouTube video playing event detected');
                        setTimeout(checkForVideoAndPiP, 100);
                    });
                });
            }
            
            // Initial setup
            setupVideoEventListeners();
            
            // Also set up a MutationObserver to catch dynamically loaded videos
            var observer = new MutationObserver(function(mutations) {
                var shouldCheck = false;
                mutations.forEach(function(mutation) {
                    if (mutation.addedNodes.length > 0) {
                        for (var i = 0; i < mutation.addedNodes.length; i++) {
                            var node = mutation.addedNodes[i];
                            if (node.nodeType === 1) { // Element node
                                if (node.tagName === 'VIDEO' || node.querySelector('video')) {
                                    shouldCheck = true;
                                    break;
                                }
                            }
                        }
                    }
                });
                
                if (shouldCheck) {
                    console.log('New video element detected, setting up listeners');
                    setupVideoEventListeners();
                    setTimeout(checkForVideoAndPiP, 200);
                }
            });
            
            observer.observe(document.body, {
                childList: true,
                subtree: true
            });
            
            // Set up periodic checking (less frequent than before, but still present as backup)
            pipCheckInterval = setInterval(checkForVideoAndPiP, 1000); // Every 1 second instead of 2
            
            // Also check when page visibility changes (user switches tabs/apps)
            document.addEventListener('visibilitychange', function() {
                if (document.hidden && isVideoPlaying) {
                    console.log('Page became hidden while video playing, checking for PiP');
                    setTimeout(checkForVideoAndPiP, 100);
                }
            });
            
            // Initial check
            setTimeout(checkForVideoAndPiP, 500);
            
            console.log('Enhanced YouTube video detection setup complete');
        })();
        """
        
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("Error setting up YouTube video detection: \(error)")
            } else {
                print("Successfully set up enhanced YouTube video detection")
            }
        }
    }
    
    // MARK: - Split-View Analysis Integration
    
    func initializeSplitViewAnalyzer(assistantViewModel: AssistantViewModel) {
        guard splitViewAnalyzer == nil else { return }
        
        splitViewAnalyzer = SplitViewAnalyzer(assistantViewModel: assistantViewModel)
        print("WebViewModel: Initialized SplitViewAnalyzer")
    }
    
    func updateSplitViewAnalysis() {
        guard let analyzer = splitViewAnalyzer,
              let tab = activeTab,
              tab.isSplitView else {
            // Stop monitoring if not in split view
            splitViewAnalyzer?.stopMonitoring()
            return
        }
        
        let primaryWebView = tab.primaryWebView
        let secondaryWebView = tab.secondaryWebView
        
        print("WebViewModel: Updating split-view analysis monitoring")
        analyzer.startMonitoring(primaryWebView: primaryWebView, secondaryWebView: secondaryWebView)
    }
    
    // MARK: - File Content Extraction for AI Analysis
    
    /// Extract content from Microsoft Office files for AI analysis
    private func extractOfficeFileContent(fileURL: URL) async {
        let fileName = fileURL.lastPathComponent
        print("WebViewModel: Extracting content from Office file: \(fileName)")
        
        // Store file information for AI access
        await MainActor.run {
            if let assistantVM = assistantViewModel {
                assistantVM.addFileContext(filePath: fileURL.path, fileName: fileName, fileType: "office")
            }
        }
        
        // Attempt to extract text content using system tools
        let fileExtension = fileURL.pathExtension.lowercased()
        if fileExtension == "docx" || fileExtension == "pptx" || fileExtension == "xlsx" {
            await extractContentFromZippedOfficeFile(fileURL: fileURL, fileName: fileName)
        }
    }
    
    /// Extract content from Apple iWork files for AI analysis
    private func extractAppleOfficeContent(fileURL: URL) async {
        let fileName = fileURL.lastPathComponent
        print("WebViewModel: Extracting content from Apple iWork file: \(fileName)")
        
        // Store file information for AI access
        await MainActor.run {
            if let assistantVM = assistantViewModel {
                assistantVM.addFileContext(filePath: fileURL.path, fileName: fileName, fileType: "iwork")
            }
        }
    }
    
    /// Extract content from OpenDocument files for AI analysis
    private func extractOpenDocumentContent(fileURL: URL) async {
        let fileName = fileURL.lastPathComponent
        print("WebViewModel: Extracting content from OpenDocument file: \(fileName)")
        
        // Store file information for AI access
        await MainActor.run {
            if let assistantVM = assistantViewModel {
                assistantVM.addFileContext(filePath: fileURL.path, fileName: fileName, fileType: "opendocument")
            }
        }
    }
    
    /// Extract content from Rich Text files for AI analysis
    private func extractRichTextContent(fileURL: URL) async {
        let fileName = fileURL.lastPathComponent
        print("WebViewModel: Extracting content from Rich Text file: \(fileName)")
        
        do {
            // Try to read as attributed string first, then fall back to plain text
            let attributedString = try NSAttributedString(url: fileURL, options: [:], documentAttributes: nil)
            let plainText = attributedString.string
            
            await MainActor.run {
                if let assistantVM = assistantViewModel {
                    assistantVM.addFileContext(filePath: fileURL.path, fileName: fileName, fileType: "richtext", content: plainText)
                }
            }
        } catch {
            print("WebViewModel: Error reading RTF file: \(error)")
            
            // Fallback: try to read as plain text
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                await MainActor.run {
                    if let assistantVM = assistantViewModel {
                        assistantVM.addFileContext(filePath: fileURL.path, fileName: fileName, fileType: "richtext", content: content)
                    }
                }
            } catch {
                print("WebViewModel: Failed to read RTF file as plain text: \(error)")
            }
        }
    }
    
    /// Extract content from modern Office files (.docx, .pptx, .xlsx) which are ZIP archives
    private func extractContentFromZippedOfficeFile(fileURL: URL, fileName: String) async {
        do {
            // Create temporary directory for extraction
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            
            defer {
                // Clean up temp directory
                try? FileManager.default.removeItem(at: tempDir)
            }
            
            // Use system unzip command to extract the file
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-q", fileURL.path, "-d", tempDir.path]
            
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                // Successfully extracted, now look for content files
                let fileExtension = fileURL.pathExtension.lowercased()
                var contentText = ""
                
                switch fileExtension {
                case "docx":
                    contentText = await extractDocxContent(from: tempDir)
                case "pptx":
                    contentText = await extractPptxContent(from: tempDir)
                case "xlsx":
                    contentText = await extractXlsxContent(from: tempDir)
                default:
                    break
                }
                
                if !contentText.isEmpty {
                    await MainActor.run {
                        if let assistantVM = assistantViewModel {
                            assistantVM.addFileContext(filePath: fileURL.path, fileName: fileName, fileType: "office", content: contentText)
                        }
                    }
                }
            }
        } catch {
            print("WebViewModel: Error extracting Office file content: \(error)")
        }
    }
    
    /// Extract text content from Word document XML
    private func extractDocxContent(from extractedDir: URL) async -> String {
        let documentPath = extractedDir.appendingPathComponent("word/document.xml")
        
        guard FileManager.default.fileExists(atPath: documentPath.path) else {
            return ""
        }
        
        do {
            let xmlContent = try String(contentsOf: documentPath)
            
            // Parse XML and extract text content
            if let xmlData = xmlContent.data(using: .utf8) {
                let parser = XMLParser(data: xmlData)
                let delegate = OfficeXMLParserDelegate()
                parser.delegate = delegate
                parser.parse()
                return delegate.extractedText
            }
        } catch {
            print("WebViewModel: Error reading document.xml: \(error)")
        }
        
        return ""
    }
    
    /// Extract text content from PowerPoint presentation XML
    private func extractPptxContent(from extractedDir: URL) async -> String {
        var allText = ""
        
        // PowerPoint slides are in ppt/slides/ folder
        let slidesDir = extractedDir.appendingPathComponent("ppt/slides")
        
        guard FileManager.default.fileExists(atPath: slidesDir.path) else {
            return ""
        }
        
        do {
            let slideFiles = try FileManager.default.contentsOfDirectory(at: slidesDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "xml" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            
            for slideFile in slideFiles {
                let xmlContent = try String(contentsOf: slideFile)
                
                if let xmlData = xmlContent.data(using: .utf8) {
                    let parser = XMLParser(data: xmlData)
                    let delegate = OfficeXMLParserDelegate()
                    parser.delegate = delegate
                    parser.parse()
                    
                    if !delegate.extractedText.isEmpty {
                        allText += "Slide: \(delegate.extractedText)\n\n"
                    }
                }
            }
        } catch {
            print("WebViewModel: Error reading PowerPoint slides: \(error)")
        }
        
        return allText
    }
    
    /// Extract text content from Excel workbook XML
    private func extractXlsxContent(from extractedDir: URL) async -> String {
        var allText = ""
        
        // Excel data is in xl/worksheets/ and strings in xl/sharedStrings.xml
        let sharedStringsPath = extractedDir.appendingPathComponent("xl/sharedStrings.xml")
        let worksheetsDir = extractedDir.appendingPathComponent("xl/worksheets")
        
        // First, extract shared strings
        var sharedStrings: [String] = []
        if FileManager.default.fileExists(atPath: sharedStringsPath.path) {
            do {
                let xmlContent = try String(contentsOf: sharedStringsPath)
                if let xmlData = xmlContent.data(using: .utf8) {
                    let parser = XMLParser(data: xmlData)
                    let delegate = ExcelSharedStringsParser()
                    parser.delegate = delegate
                    parser.parse()
                    sharedStrings = delegate.sharedStrings
                }
            } catch {
                print("WebViewModel: Error reading shared strings: \(error)")
            }
        }
        
        // Then extract worksheet data
        if FileManager.default.fileExists(atPath: worksheetsDir.path) {
            do {
                let worksheetFiles = try FileManager.default.contentsOfDirectory(at: worksheetsDir, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "xml" }
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }
                
                for worksheetFile in worksheetFiles {
                    let xmlContent = try String(contentsOf: worksheetFile)
                    
                    if let xmlData = xmlContent.data(using: .utf8) {
                        let parser = XMLParser(data: xmlData)
                        let delegate = ExcelWorksheetParser(sharedStrings: sharedStrings)
                        parser.delegate = delegate
                        parser.parse()
                        
                        if !delegate.extractedText.isEmpty {
                            allText += "Worksheet \(worksheetFile.deletingPathExtension().lastPathComponent): \(delegate.extractedText)\n\n"
                        }
                    }
                }
            } catch {
                print("WebViewModel: Error reading Excel worksheets: \(error)")
            }
        }
        
        return allText
    }
    
    // Debug logging helper for WebViewModel
    private func webViewLog(_ message: String, function: String = #function, line: Int = #line) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("🌐 [\(timestamp)] WebViewModel [\(function):\(line)] \(message)")
    }

}

// MARK: - XML Parser Delegates for Office File Content Extraction

class OfficeXMLParserDelegate: NSObject, XMLParserDelegate {
    var extractedText = ""
    private var currentText = ""
    private var isInTextElement = false
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "t" || elementName.contains("text") {
            isInTextElement = true
            currentText = ""
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInTextElement {
            currentText += string
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "t" || elementName.contains("text") {
            isInTextElement = false
            if !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                extractedText += currentText + " "
            }
        }
    }
}

class ExcelSharedStringsParser: NSObject, XMLParserDelegate {
    var sharedStrings: [String] = []
    private var currentString = ""
    private var isInStringValue = false
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "t" {
            isInStringValue = true
            currentString = ""
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInStringValue {
            currentString += string
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "t" {
            isInStringValue = false
            sharedStrings.append(currentString)
        }
    }
}

class ExcelWorksheetParser: NSObject, XMLParserDelegate {
    let sharedStrings: [String]
    var extractedText = ""
    private var currentCellValue = ""
    private var isInCellValue = false
    private var cellType = ""
    
    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "c" {
            cellType = attributeDict["t"] ?? ""
        } else if elementName == "v" {
            isInCellValue = true
            currentCellValue = ""
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInCellValue {
            currentCellValue += string
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "v" {
            isInCellValue = false
            
            if !currentCellValue.isEmpty {
                var cellText = currentCellValue
                
                // If it's a shared string reference, look it up
                if cellType == "s", let index = Int(currentCellValue), index < sharedStrings.count {
                    cellText = sharedStrings[index]
                }
                
                if !cellText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    extractedText += cellText + " "
                }
            }
        }
    }
}
