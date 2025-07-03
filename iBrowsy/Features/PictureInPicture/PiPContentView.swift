import SwiftUI
import WebKit
import AppKit

struct PiPContentView: View {
    let videoInfo: VideoElementInfo
    weak var sourceWebView: WKWebView?
    let onClose: () -> Void
    
    @State private var pipWebView: WKWebView?
    @State private var isLoading = true
    @State private var showControls = false
    
    var body: some View {
        ZStack {
            // Video content
            if let webView = pipWebView {
                PiPWebViewRepresentable(webView: webView)
                    .onAppear {
                        loadVideoContent()
                    }
            } else {
                ProgressView("Loading video...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Overlay controls (shown on hover)
            if showControls {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                    }
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                showControls = hovering
            }
        }
        .onAppear {
            setupPiPWebView()
        }
    }
    
    @State private var navigationDelegate = PiPWebViewDelegate()
    
    private func setupPiPWebView() {
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // Enable autoplay for better YouTube compatibility
        config.preferences.isElementFullscreenEnabled = true
        if #available(macOS 11.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        } else {
            config.preferences.javaScriptEnabled = true
        }
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = navigationDelegate
        
        pipWebView = webView
    }
    
    private func loadVideoContent() {
        guard let webView = pipWebView else { return }
        
        // Create HTML content that displays just the video
        let htmlContent = createVideoHTML()
        
        webView.loadHTMLString(htmlContent, baseURL: sourceWebView?.url)
    }
    
    private func createVideoHTML() -> String {
        let videoHTML: String
        
        switch videoInfo.elementType {
        case .video:
            videoHTML = """
            <video
                src="\(videoInfo.src)"
                width="100%"
                height="100%"
                controls
                autoplay
                style="object-fit: contain; background: black;"
                \(videoInfo.currentTime > 0 ? "currentTime=\"\(videoInfo.currentTime)\"" : "")>
                Your browser does not support the video tag.
            </video>
            """
        case .iframe:
            let embedURL = createEmbedURL(from: videoInfo.src)
            videoHTML = """
            <iframe
                src="\(embedURL)"
                width="100%"
                height="100%"
                frameborder="0"
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
                allowfullscreen
                style="border: none;">
            </iframe>
            """
        }
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Picture in Picture</title>
            <style>
                body {
                    margin: 0;
                    padding: 0;
                    background: black;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    width: 100vw;
                    height: 100vh;
                    overflow: hidden;
                }
                video, iframe {
                    max-width: 100%;
                    max-height: 100%;
                }
            </style>
        </head>
        <body>
            \(videoHTML)
            <script>
                // Sync playback with source if possible
                window.addEventListener('load', function() {
                    const video = document.querySelector('video');
                    if (video && \(videoInfo.currentTime) > 0) {
                        video.currentTime = \(videoInfo.currentTime);
                        \(videoInfo.isPlaying ? "video.play();" : "")
                    }
                });
            </script>
        </body>
        </html>
        """
    }
    
    private func createEmbedURL(from originalURL: String) -> String {
        // Handle YouTube URLs
        if originalURL.contains("youtube.com") || originalURL.contains("youtu.be") {
            return convertToYouTubeEmbed(originalURL)
        }
        
        // Handle Vimeo URLs
        if originalURL.contains("vimeo.com") {
            return convertToVimeoEmbed(originalURL)
        }
        
        // If already an embed URL, use as-is
        if originalURL.contains("/embed/") || originalURL.contains("player.") {
            return originalURL
        }
        
        // For other cases, return the original URL
        return originalURL
    }
    
    private func convertToYouTubeEmbed(_ url: String) -> String {
        // Extract video ID from various YouTube URL formats
        let videoID = extractYouTubeVideoID(from: url)
        guard !videoID.isEmpty else { return url }
        
        // Create embed URL with enhanced parameters for PiP
        var embedURL = "https://www.youtube.com/embed/\(videoID)?autoplay=1&mute=1&controls=1&modestbranding=1&rel=0&iv_load_policy=3&disablekb=0&enablejsapi=1&origin=\(Bundle.main.bundleIdentifier ?? "com.dayanfernandez.iBrowsy")"
        
        // Add start time if available
        if videoInfo.currentTime > 0 {
            let startTime = Int(videoInfo.currentTime)
            embedURL += "&start=\(startTime)"
        }
        
        return embedURL
    }
    
    private func convertToVimeoEmbed(_ url: String) -> String {
        // Extract video ID for Vimeo
        let components = url.components(separatedBy: "/")
        guard let videoID = components.last, !videoID.isEmpty else { return url }
        
        return "https://player.vimeo.com/video/\(videoID)?autoplay=1"
    }
    
    private func extractYouTubeVideoID(from url: String) -> String {
        // Handle various YouTube URL formats:
        // https://www.youtube.com/watch?v=VIDEO_ID
        // https://youtu.be/VIDEO_ID
        // https://www.youtube.com/embed/VIDEO_ID
        // https://www.youtube.com/v/VIDEO_ID
        
        if url.contains("youtu.be/") {
            let components = url.components(separatedBy: "youtu.be/")
            if components.count > 1 {
                let videoID = components[1].components(separatedBy: "?").first ?? ""
                return videoID.components(separatedBy: "&").first ?? ""
            }
        }
        
        if url.contains("watch?v=") {
            let components = url.components(separatedBy: "watch?v=")
            if components.count > 1 {
                let videoID = components[1].components(separatedBy: "&").first ?? ""
                return videoID
            }
        }
        
        if url.contains("/embed/") {
            let components = url.components(separatedBy: "/embed/")
            if components.count > 1 {
                let videoID = components[1].components(separatedBy: "?").first ?? ""
                return videoID
            }
        }
        
        if url.contains("/v/") {
            let components = url.components(separatedBy: "/v/")
            if components.count > 1 {
                let videoID = components[1].components(separatedBy: "?").first ?? ""
                return videoID
            }
        }
        
        return ""
    }
}

struct PiPWebViewRepresentable: NSViewRepresentable {
    let webView: WKWebView
    
    func makeNSView(context: Context) -> WKWebView {
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // No updates needed
    }
}

class PiPWebViewDelegate: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("PiP WebView: Successfully loaded content")
        
        // Inject JavaScript to help with YouTube autoplay
        let autoplayScript = """
        (function() {
            // Try to unmute and play any video elements
            var videos = document.querySelectorAll('video');
            videos.forEach(function(video) {
                if (video.muted !== undefined) {
                    video.muted = false;
                }
                if (video.play && typeof video.play === 'function') {
                    video.play().catch(function(error) {
                        console.log('PiP: Video play failed:', error);
                        // If unmuted play fails, try muted play
                        video.muted = true;
                        video.play().catch(function(mutedError) {
                            console.log('PiP: Muted video play also failed:', mutedError);
                        });
                    });
                }
            });
        })();
        """
        
        webView.evaluateJavaScript(autoplayScript) { _, error in
            if let error = error {
                print("PiP WebView: Error executing autoplay script: \(error.localizedDescription)")
            } else {
                print("PiP WebView: Autoplay script executed successfully")
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("PiP WebView failed to load: \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("PiP WebView provisional navigation failed: \(error.localizedDescription)")
    }
}