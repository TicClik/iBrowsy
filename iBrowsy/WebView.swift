import SwiftUI
import WebKit
import AppKit

struct WebView: NSViewRepresentable {
    // Inject the ViewModel (needed for delegate assignment)
    @ObservedObject var viewModel: WebViewModel
    // --- Pass the specific WKWebView instance --- 
    let webViewInstance: WKWebView

    class Coordinator: NSObject {
        var parent: WebView
        var mouseMonitor: Any?
        var eventMonitor: Any?
        var lastFocusRequestTime = Date()
        
        init(parent: WebView) {
            self.parent = parent
            super.init()
            setupMonitoring()
        }
        
        func setupMonitoring() {
            // Monitor mouse events to detect clicks
            mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
                guard let self = self else { return event }
                
                // Ensure we have the active tab
                guard let activeTab = self.parent.viewModel.activeTab else { return event }
                
                // Find which WKWebView was clicked by converting coordinates
                let isPrimary = self.isEventInWebView(event, webView: self.parent.webViewInstance)
                
                if isPrimary {
                    // Check if this webView is primary or secondary in the current tab
                    let isInPrimary = activeTab.primaryWebView === self.parent.webViewInstance
                    let isInSecondary = activeTab.secondaryWebView === self.parent.webViewInstance
                    
                    if isInPrimary && activeTab.activeSplitViewSide != .primary {
                        print("WebView Monitor: Click detected on primary view, switching focus")
                        DispatchQueue.main.async {
                            self.parent.viewModel.setActiveSplitSide(for: activeTab.id, side: .primary)
                            // Force focus on the WebView after a short delay to ensure state is updated
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                self.forceFocusOnWebView()
                            }
                        }
                    } else if isInSecondary && activeTab.activeSplitViewSide != .secondary {
                        print("WebView Monitor: Click detected on secondary view, switching focus")
                        DispatchQueue.main.async {
                            self.parent.viewModel.setActiveSplitSide(for: activeTab.id, side: .secondary)
                            // Force focus on the WebView after a short delay to ensure state is updated
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                self.forceFocusOnWebView()
                            }
                        }
                    } else {
                        // Even if the side is already active, ensure it has keyboard focus
                        DispatchQueue.main.async {
                            self.forceFocusOnWebView()
                        }
                    }
                }
                
                // Always pass the event through to normal processing
                return event
            }
        }
        
        // Helper method to check if an event occurred within a specific WebView
        func isEventInWebView(_ event: NSEvent, webView: WKWebView) -> Bool {
            guard let window = event.window, 
                  let webViewWindow = webView.window,
                  window == webViewWindow else {
                return false
            }
            
            // Get the event position in window coordinates
            let locationInWindow = event.locationInWindow
            
            // Convert to view coordinates
            if let nsView = webView.superview {
                let locationInView = nsView.convert(locationInWindow, from: nil)
                
                // Check if the point is within the WebView's frame
                return nsView.bounds.contains(locationInView)
            }
            
            return false
        }
        
        func forceFocusOnWebView() {
            // Make the WebView the first responder to enable keyboard input
            guard let window = self.parent.webViewInstance.window else { return }

            // Check if the current first responder is a text view and not part of this webview
            if let currentFirstResponder = window.firstResponder as? NSTextView {
                var isSubviewOfWebView = false
                var view = currentFirstResponder.superview
                while view != nil {
                    if view == self.parent.webViewInstance {
                        isSubviewOfWebView = true
                        break
                    }
                    view = view?.superview
                }
                
                if !isSubviewOfWebView {
                    // Check if the first responder is the AI Assistant's text field
                    let responderClassName = String(describing: type(of: currentFirstResponder))
                    let responderAccessibilityLabel = currentFirstResponder.accessibilityLabel() ?? ""
                    
                    // If in the Assistant text field, don't steal focus
                    if responderClassName.contains("NSTextField") || 
                       responderClassName.contains("TextField") ||
                       responderAccessibilityLabel.contains("Ask about this page") {
                        // If current first responder is the Assistant's text field, don't steal focus
                        print("WebView: Current first responder is the Assistant text field. Deferring focus.")
                        return
                    }
                    
                    // If current first responder is any text view outside this webview, don't steal focus
                    print("WebView: Current first responder is an external NSTextView. Deferring focus.")
                    return
                }
            }

            print("WebView: Forcing focus on WebView")
            
            // First make the WebView first responder
            window.makeFirstResponder(self.parent.webViewInstance)
            
            // Then focus the content view specifically
            if let contentView = self.findWKContentView(in: self.parent.webViewInstance) {
                // Use a tiny delay to ensure the view hierarchy is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    window.makeFirstResponder(contentView)
                }
            }
        }
        
        func findWKContentView(in view: NSView) -> NSView? {
            // Find the WKContentView within the WKWebView hierarchy
            // WKContentView is the actual view that handles keyboard input
            for subview in view.subviews {
                if String(describing: type(of: subview)).contains("WKContentView") {
                    return subview
                }
                
                // Recursively search in subviews
                if let contentView = findWKContentView(in: subview) {
                    return contentView
                }
            }
            return nil
        }
        
        func stopMonitoring() {
            if let monitor = mouseMonitor {
                NSEvent.removeMonitor(monitor)
                mouseMonitor = nil
            }
        }
        
        deinit {
            stopMonitoring()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> WKWebView {
        // --- Assign delegates to the ViewModel --- 
        // Ensure navigationDelegate is set (important)
        if webViewInstance.navigationDelegate == nil {
            webViewInstance.navigationDelegate = viewModel 
        }
        // Ensure uiDelegate is set (important)
        if webViewInstance.uiDelegate == nil {
             webViewInstance.uiDelegate = viewModel
        }
        // Let's log to confirm delegates ARE being set here
        print("WebView.makeNSView: Setting navigationDelegate and uiDelegate to ViewModel.")
        
        // Configure WKWebView for proper sizing
        webViewInstance.translatesAutoresizingMaskIntoConstraints = true
        webViewInstance.autoresizingMask = [.width, .height]
        
        // Apply rounded corners directly to the WKWebView itself
        webViewInstance.wantsLayer = true
        webViewInstance.layer?.cornerRadius = 16
        webViewInstance.layer?.masksToBounds = true
        
        // Set up PiP message handler
        setupPiPMessageHandler()
        
        // Start monitoring for mouse events
        context.coordinator.setupMonitoring()
        
        // --- Return the passed-in instance --- 
        return webViewInstance
    }
    
    private func setupPiPMessageHandler() {
        // Remove any existing message handler with the same name to prevent duplicates
        webViewInstance.configuration.userContentController.removeScriptMessageHandler(forName: "pipRequest")
        
        // Add message handler for PiP requests
        let messageHandler = PiPMessageHandler()
        webViewInstance.configuration.userContentController.add(messageHandler, name: "pipRequest")
        
        // Set up navigation delegate to enable automatic PiP on page loads
        if let currentNavigationDelegate = webViewInstance.navigationDelegate as? WebViewModel {
            // The ViewModel will handle the navigation events and enable PiP automatically
            currentNavigationDelegate.pipEnabledWebViews.insert(ObjectIdentifier(webViewInstance))
        }
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // If the instance passed in changes, updateNSView will be called.
        // Usually, we manage state *within* the WKWebView via the delegate,
        // so updates here might be minimal unless we need to explicitly 
        // sync something based on external state changes.
        
        // --- Re-enabled check for delegate changes --- 
        if nsView.uiDelegate !== viewModel {
             print("WebView.updateNSView: WARNING - uiDelegate is NOT the ViewModel!")
             // Optionally force-reset it? Let's just log for now.
             // nsView.uiDelegate = viewModel
        }
        
        // When the active side changes, ensure focus is set appropriately
        if let activeTab = viewModel.activeTab {
            let isThisWebViewActive = (activeTab.activeSplitViewSide == .primary && nsView === activeTab.primaryWebView) || 
                                     (activeTab.activeSplitViewSide == .secondary && nsView === activeTab.secondaryWebView)
            
            if isThisWebViewActive {
                // We need to be careful about excessive UI updates here
                // Use a timer to throttle focus changes
                context.coordinator.lastFocusRequestTime = Date()
                
                // Debounce focus requests to avoid layout constraint issues
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Context is a non-optional value type, no need to unwrap
                    // Only force focus if this was the last request in the last 100ms
                    let elapsed = Date().timeIntervalSince(context.coordinator.lastFocusRequestTime)
                    if elapsed >= 0.1 {
                        context.coordinator.forceFocusOnWebView()
                    }
                }
            }
        }
    }
    
    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        // Clean up event monitoring
        coordinator.stopMonitoring()
        
        // Clean up script message handlers to prevent memory leaks
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "pipRequest")
    }
} 