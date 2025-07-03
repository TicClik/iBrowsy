import SwiftUI
import Foundation

// MARK: - Web Browsing Feature Protocol
protocol WebBrowsingServiceProtocol: ObservableObject {
    // Core web navigation
    var currentURL: String { get }
    var currentTitle: String { get }
    var isLoading: Bool { get }
    var canGoBack: Bool { get }
    var canGoForward: Bool { get }
    var isShowingHomepage: Bool { get set }
    
    // Navigation methods
    func loadURL(from urlString: String)
    func goBack()
    func goForward()
    func reload()
    func showHomepage()
    
    // Tab management
    var tabs: [WebTab] { get }
    var currentTabIndex: Int { get set }
    func addNewTab(with url: String?)
    func closeTab(at index: Int)
    func switchToTab(at index: Int)
}

// MARK: - Web Tab Model
struct WebTab: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var url: String
    var isLoading: Bool = false
    
    init(title: String = "New Tab", url: String = "about:blank") {
        self.title = title
        self.url = url
    }
}

// MARK: - Web Browsing Events Protocol
protocol WebBrowsingEventsProtocol {
    func onPageLoaded(url: String, title: String)
    func onNavigationStarted()
    func onNavigationFailed(error: Error)
} 