import Foundation
import SwiftUI
import WebKit
import AppKit

class PiPWindow: NSObject, Identifiable {
    let id = UUID()
    let videoInfo: VideoElementInfo
    weak var sourceWebView: WKWebView?
    private var window: NSWindow?
    var onClose: ((PiPWindow) -> Void)?
    
    init(videoInfo: VideoElementInfo, sourceWebView: WKWebView) {
        self.videoInfo = videoInfo
        self.sourceWebView = sourceWebView
        super.init()
    }
    
    func show() {
        // Calculate initial window size based on video dimensions
        let initialWidth = max(min(videoInfo.width, 800), 320)
        let initialHeight = max(min(videoInfo.height, 600), 240)
        
        // Create the PiP content view
        let pipContentView = PiPContentView(
            videoInfo: videoInfo,
            sourceWebView: sourceWebView,
            onClose: { [weak self] in
                Task { @MainActor in
                    self?.close()
                }
            }
        )
        
        // Create hosting view
        let hostingView = NSHostingView(rootView: pipContentView)
        
        // Create the window
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: initialWidth, height: initialHeight),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        guard let window = window else { return }
        
        // Configure window properties
        window.title = videoInfo.title ?? "Picture in Picture"
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.level = .floating // Always on top
        window.delegate = self
        
        // Set minimum size
        window.minSize = NSSize(width: 240, height: 180)
        
        // Position window in top-right corner of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame
            let x = screenFrame.maxX - windowFrame.width - 20
            let y = screenFrame.maxY - windowFrame.height - 20
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // Show the window
        window.makeKeyAndOrderFront(nil)
    }
    
    @MainActor
    func close() {
        // Get current playback time from PiP before closing
        getCurrentPiPTime { [weak self] currentTime in
            guard let self = self else { return }
            
            // Resume the original video when PiP closes with sync time
            if let sourceWebView = self.sourceWebView {
                PiPManager.shared.resumeOriginalVideo(in: sourceWebView, videoInfo: self.videoInfo, pipCurrentTime: currentTime)
            }
            
            self.window?.close()
            self.window = nil
            self.onClose?(self)
        }
    }
}

// MARK: - NSWindowDelegate
extension PiPWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Resume the original video when PiP window is closed via window controls
        getCurrentPiPTime { [weak self] currentTime in
            guard let self = self else { return }
            
            if let sourceWebView = self.sourceWebView {
                Task { @MainActor in
                    PiPManager.shared.resumeOriginalVideo(in: sourceWebView, videoInfo: self.videoInfo, pipCurrentTime: currentTime)
                }
            }
            self.onClose?(self)
        }
    }
    
    // Get current playback time from the PiP WebView
    func getCurrentPiPTime(completion: @escaping (Double?) -> Void) {
        // Find the WebView more reliably through NSHostingView
        guard let hostingView = window?.contentView as? NSHostingView<PiPContentView> else {
            print("PiPWindow: Could not find NSHostingView")
            completion(nil)
            return
        }
        
        // Try to find the WebView in the view hierarchy
        var pipWebView: WKWebView?
        
        func findWebView(in view: NSView) -> WKWebView? {
            if let webView = view as? WKWebView {
                return webView
            }
            for subview in view.subviews {
                if let found = findWebView(in: subview) {
                    return found
                }
            }
            return nil
        }
        
        pipWebView = findWebView(in: hostingView)
        
        guard let webView = pipWebView else {
            print("PiPWindow: Could not find WKWebView in PiP window")
            completion(nil)
            return
        }
        
        let script = """
        (function() {
            try {
                // For HTML5 video elements
                var videos = document.querySelectorAll('video');
                if (videos.length > 0) {
                    var video = videos[0];
                    if (video.currentTime && video.currentTime > 0) {
                        console.log('PiP: Got video time:', video.currentTime);
                        return video.currentTime;
                    }
                }
                
                // For YouTube embeds, try multiple approaches
                if (window.location.href.includes('youtube.com/embed')) {
                    // Try YouTube postMessage API
                    var iframe = document.querySelector('iframe');
                    if (iframe) {
                        // Request current time from YouTube iframe
                        iframe.contentWindow.postMessage('{"event":"listening","id":"ytplayer"}', '*');
                        iframe.contentWindow.postMessage('{"event":"command","func":"getCurrentTime","args":""}', '*');
                    }
                    
                    // Also try direct access if iframe content is accessible
                    try {
                        var ytVideo = iframe && iframe.contentDocument ? iframe.contentDocument.querySelector('video') : null;
                        if (ytVideo && ytVideo.currentTime > 0) {
                            console.log('PiP: Got YouTube iframe video time:', ytVideo.currentTime);
                            return ytVideo.currentTime;
                        }
                    } catch (e) {
                        console.log('PiP: Cannot access iframe content due to CORS');
                    }
                }
                
                console.log('PiP: Could not get current time, returning 0');
                return 0;
            } catch (error) {
                console.log('PiP: Error getting current time:', error);
                return 0;
            }
        })();
        """
        
        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("PiPWindow: Error getting current time: \(error)")
                completion(nil)
                return
            }
            
            let currentTime = result as? Double ?? 0
            print("PiPWindow: Retrieved current time: \(currentTime)")
            completion(currentTime > 0 ? currentTime : nil)
        }
    }
    
    func windowDidResize(_ notification: Notification) {
        // Maintain aspect ratio if needed
        guard let window = notification.object as? NSWindow else { return }
        let frame = window.frame
        
        // Optional: Maintain aspect ratio
        let aspectRatio = videoInfo.width / videoInfo.height
        if aspectRatio > 0 {
            let newHeight = frame.width / aspectRatio
            if abs(newHeight - frame.height) > 5 { // Small tolerance to prevent infinite loops
                let newFrame = NSRect(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: newHeight)
                window.setFrame(newFrame, display: true)
            }
        }
    }
}