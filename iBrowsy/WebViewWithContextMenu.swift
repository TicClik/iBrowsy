import SwiftUI
import WebKit

struct WebViewWithContextMenu: View {
    @ObservedObject var viewModel: WebViewModel
    let webViewInstance: WKWebView
    
    // State to track context menu position
    @State private var contextMenuPoint: CGPoint = .zero
    @State private var contextMenuURL: URL? = nil
    @State private var showContextMenu: Bool = false
    @State private var selectedText: String = ""
    @State private var videoAtCursor: VideoElementInfo? = nil
    
    var body: some View {
        ZStack {
            // Regular WebView
            WebView(viewModel: viewModel, webViewInstance: webViewInstance)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle()) // Ensure the entire area is tappable
                // REMOVE the onTapGesture as it's interfering with actual WebView interactions
                // Instead, we'll rely on the NSEvent monitoring in WebView.Coordinator
                // That approach properly detects clicks without preventing WebView interaction
                .simultaneousGesture(
                    // Detect right click/control click for context menu
                    TapGesture(count: 1)
                        .modifiers(.control)
                        .onEnded { _ in
                            // Get URL at clicked position
                            detectLinkAtPosition()
                            // Get selected text
                            getSelectedText()
                            // Check for video at position
                            detectVideoAtPosition()
                        }
                )
        }
        .dropDestination(for: URL.self) { items, location in
            guard let droppedURL = items.first else { return false }
            guard let tab = viewModel.activeTab else { return false }

            let targetSide: SplitViewSide
            if webViewInstance === tab.primaryWebView {
                targetSide = .primary
            } else if webViewInstance === tab.secondaryWebView {
                targetSide = .secondary
            } else {
                // Should not happen if webViewInstance is correctly passed
                print("Error: Could not determine target side for drop.")
                return false
            }

            print("Dropped URL: \(droppedURL) onto \(targetSide) view of tab \(tab.id)")
            
            // Handle different types of dropped URLs
            if droppedURL.isFileURL {
                // Handle local file drops
                return viewModel.handleFileDropForSplit(fileURL: droppedURL, for: tab.id, targetSide: targetSide)
            } else {
                // Handle regular URL drops
                viewModel.loadURLInSplit(url: droppedURL, for: tab.id, targetSide: targetSide)
            }

            // Attempt to make the dropped-on view the first responder
            DispatchQueue.main.async {
                if let window = webViewInstance.window {
                    let success = window.makeFirstResponder(webViewInstance)
                    print("Attempted to make drop target (\(targetSide)) first responder. Success: \(success)")
                }
            }
            return true
        }
        // Add SwiftUI context menu when URL is detected
        .contextMenu {
            if let video = videoAtCursor {
                Button("Picture in Picture") {
                    PiPManager.shared.createPiPWindow(for: video, from: webViewInstance)
                }
                
                Divider()
            }
            
            if let url = contextMenuURL {
                if viewModel.activeTab?.isSplitView == true {
                    let otherSide: SplitViewSide = viewModel.activeTab?.activeSplitViewSide == .primary ? .secondary : .primary
                    Button("Open in Other Split") {
                        if let tabId = viewModel.activeTab?.id {
                            viewModel.loadURLInSplit(url: url, for: tabId, targetSide: otherSide)
                        }
                    }
                } else {
                    Button("Open in New Split View") {
                        if let tabId = viewModel.activeTab?.id {
                            viewModel.toggleSplitView(for: tabId)
                            DispatchQueue.main.async {
                                viewModel.loadURLInSplit(url: url, for: tabId, targetSide: .secondary)
                            }
                        }
                    }
                }
                
                Button("Open in New Tab") {
                    viewModel.addNewTab(urlToLoad: url.absoluteString)
                }
                
                Button("Copy Link") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                }
            } else if !selectedText.isEmpty {
                // Context menu when text is selected
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(selectedText, forType: .string)
                }
                
                Button("Ask AI Assistant") {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowAssistantRequest"),
                        object: nil
                    )
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if let currentInput = viewModel.assistantViewModel?.currentInput, currentInput.isEmpty {
                            viewModel.assistantViewModel?.currentInput = "Help me understand this: \"\(selectedText)\""
                        }
                    }
                }
            } else {
                // General context menu items when no link is detected
                Button("Back") {
                    viewModel.goBack()
                }
                .disabled(!viewModel.canGoBack)
                
                Button("Forward") {
                    viewModel.goForward()
                }
                .disabled(!viewModel.canGoForward)
                
                Button("Reload") {
                    viewModel.reload()
                }
            }
        }
    }
    
    // Function to detect link URL at cursor position
    private func detectLinkAtPosition() {
        // Get the current mouse position in window coordinates
        if let mouseEvent = NSApplication.shared.currentEvent,
           let window = NSApplication.shared.keyWindow {
            
            // Convert window position to screen position
            let windowPoint = mouseEvent.locationInWindow
            let screenPoint = window.convertPoint(toScreen: windowPoint)
            
            // Get webView's frame in screen coordinates
            if let _ = webViewInstance.window?.contentViewController,
               let webViewNSView = webViewInstance.superview {
                // Convert to webView coordinates
                let webViewScreenFrame = webViewNSView.window?.convertToScreen(webViewNSView.convert(webViewNSView.bounds, to: nil))
                
                if let webViewFrame = webViewScreenFrame {
                    // Calculate click position relative to webView
                    let relativeX = screenPoint.x - webViewFrame.minX
                    let relativeY = screenPoint.y - webViewFrame.minY
                    
                    // Adjust Y coordinate to account for inverted coordinate system
                    let adjustedY = webViewFrame.height - relativeY
                    
                    print("Context menu detected at webView position: (\(relativeX), \(adjustedY))")
                    
                    // Execute improved JavaScript to find link at position
                    let script = """
                    (function() {
                        const clickX = \(relativeX);
                        const clickY = \(adjustedY);
                        
                        // Function to check if a point is inside a rect
                        function isPointInRect(x, y, rect) {
                            return (x >= rect.left && x <= rect.right && 
                                    y >= rect.top && y <= rect.bottom);
                        }
                        
                        // Get all links and check if click is within any
                        const links = document.links;
                        let foundLink = null;
                        
                        // Check each link
                        for (let i = 0; i < links.length; i++) {
                            const rect = links[i].getBoundingClientRect();
                            
                            if (isPointInRect(clickX, clickY, rect)) {
                                foundLink = {
                                    url: links[i].href,
                                    text: links[i].textContent.trim(),
                                    rect: {
                                        left: rect.left,
                                        top: rect.top,
                                        right: rect.right,
                                        bottom: rect.bottom
                                    }
                                };
                                break;
                            }
                        }
                        
                        // If no link found by direct hit, try finding nearest link within 10px
                        if (!foundLink) {
                            let closestDistance = 15; // Max 15px distance to consider
                            
                            for (let i = 0; i < links.length; i++) {
                                const rect = links[i].getBoundingClientRect();
                                
                                // Find closest point on rectangle to click point
                                const closestX = Math.max(rect.left, Math.min(clickX, rect.right));
                                const closestY = Math.max(rect.top, Math.min(clickY, rect.bottom));
                                
                                // Calculate distance
                                const distance = Math.sqrt(
                                    Math.pow(clickX - closestX, 2) + 
                                    Math.pow(clickY - closestY, 2)
                                );
                                
                                if (distance < closestDistance) {
                                    closestDistance = distance;
                                    foundLink = {
                                        url: links[i].href,
                                        text: links[i].textContent.trim(),
                                        distance: distance
                                    };
                                }
                            }
                        }
                        
                        return JSON.stringify(foundLink);
                    })();
                    """
                    
                    webViewInstance.evaluateJavaScript(script) { result, error in
                        if let error = error {
                            print("Error detecting links: \(error)")
                            self.contextMenuURL = nil
                            return
                        }
                        
                        // Reset context menu URL
                        self.contextMenuURL = nil
                        
                        if let jsonString = result as? String,
                           let data = jsonString.data(using: .utf8) {
                            do {
                                // Parse the JSON object for the found link
                                if let linkData = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                                   let urlString = linkData["url"] as? String,
                                   let url = URL(string: urlString) {
                                    
                                    self.contextMenuURL = url
                                    
                                    if let linkText = linkData["text"] as? String {
                                        print("Found link at context menu position: \(urlString) with text: \(linkText)")
                                    } else {
                                        print("Found link at context menu position: \(urlString)")
                                    }
                                }
                            } catch {
                                print("Error parsing link data: \(error)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Function to get selected text from the web page
    private func getSelectedText() {
        webViewInstance.evaluateJavaScript("document.getSelection().toString()") { result, error in
            if let error = error {
                print("Error getting selected text: \(error)")
                return
            }
            
            if let text = result as? String, !text.isEmpty {
                self.selectedText = text
                print("Selected text: \(text)")
            } else {
                self.selectedText = ""
            }
        }
    }
    
    // Notes feature removed - text selection only notifies for AI assistance
    private func notifyTextSelected(_ text: String) {
        NotificationCenter.default.post(
            name: NSNotification.Name("TextSelected"),
            object: nil,
            userInfo: ["selectedText": text]
        )
    }
    
    // Function to detect video at cursor position
    private func detectVideoAtPosition() {
        // Get the current mouse position
        if let mouseEvent = NSApplication.shared.currentEvent,
           let window = NSApplication.shared.keyWindow {
            
            let windowPoint = mouseEvent.locationInWindow
            let screenPoint = window.convertPoint(toScreen: windowPoint)
            
                         if let _ = webViewInstance.window?.contentViewController,
                let webViewNSView = webViewInstance.superview {
                let webViewScreenFrame = webViewNSView.window?.convertToScreen(webViewNSView.convert(webViewNSView.bounds, to: nil))
                
                if let webViewFrame = webViewScreenFrame {
                    let relativeX = screenPoint.x - webViewFrame.minX
                    let relativeY = screenPoint.y - webViewFrame.minY
                    let adjustedY = webViewFrame.height - relativeY
                    
                    VideoDetectionService.shared.findVideoAtPosition(webViewInstance, x: relativeX, y: adjustedY) { videoInfo in
                        DispatchQueue.main.async {
                            self.videoAtCursor = videoInfo
                        }
                    }
                }
            }
        }
    }
} 