import SwiftUI
import Foundation

// MARK: - Feature Coordinator
/// Central coordinator that manages communication between features without creating direct dependencies
class FeatureCoordinator: ObservableObject {
    // MARK: - Feature Services
    private var webBrowsingService: (any WebBrowsingServiceProtocol)?
    private var aiAssistantService: (any AIAssistantServiceProtocol)?
    private var bookmarkSystemService: (any BookmarkSystemServiceProtocol)?
    
    // MARK: - Registration Methods
    func registerWebBrowsingService<T: WebBrowsingServiceProtocol>(_ service: T) {
        self.webBrowsingService = service
    }
    
    func registerAIAssistantService<T: AIAssistantServiceProtocol>(_ service: T) {
        self.aiAssistantService = service
    }
    
    func registerBookmarkSystemService<T: BookmarkSystemServiceProtocol>(_ service: T) {
        self.bookmarkSystemService = service
    }
    
    // MARK: - Cross-Feature Actions
    
    /// Handle bookmark creation request from AI Assistant
    func createBookmarkFromAssistant() {
        guard let webService = webBrowsingService,
              let bookmarkService = bookmarkSystemService else { return }
        
        let currentURL = webService.currentURL
        let currentTitle = webService.currentTitle
        
        if !currentURL.isEmpty && currentURL != "about:blank" {
            bookmarkService.addBookmark(
                name: currentTitle.isEmpty ? "Untitled" : currentTitle,
                urlString: currentURL,
                parentFolderId: nil
            )
        }
    }
    
    /// Handle navigation request from AI Assistant
    func navigateFromAssistant(to urlString: String) {
        webBrowsingService?.loadURL(from: urlString)
    }
    
    /// Handle bookmark selection for navigation
    func navigateToBookmark(urlString: String) {
        webBrowsingService?.loadURL(from: urlString)
    }
    
    /// Handle AI command processing based on current web state
    func processAICommand(_ command: String) -> Bool {
        guard let aiService = aiAssistantService else { return false }
        return aiService.processCommand(command)
    }
    
    // MARK: - Feature State Access (Read-only)
    
    var currentWebURL: String {
        webBrowsingService?.currentURL ?? ""
    }
    
    var currentWebTitle: String {
        webBrowsingService?.currentTitle ?? ""
    }
    
    var isWebLoading: Bool {
        webBrowsingService?.isLoading ?? false
    }
    
    var bookmarkCount: Int {
        bookmarkSystemService?.rootItems.count ?? 0
    }
    
    var isAIProcessing: Bool {
        aiAssistantService?.isProcessing ?? false
    }
} 