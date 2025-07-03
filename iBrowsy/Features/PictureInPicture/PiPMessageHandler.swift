import Foundation
import WebKit

class PiPMessageHandler: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "pipRequest",
              let videoData = message.body as? [String: Any] else {
            return
        }
        
        // Parse video data from JavaScript
        let src = videoData["src"] as? String ?? ""
        let title = videoData["title"] as? String ?? "Video"
        let currentTime = videoData["currentTime"] as? Double ?? 0
        let duration = videoData["duration"] as? Double ?? 0
        let width = videoData["width"] as? Double ?? 640
        let height = videoData["height"] as? Double ?? 360
        let isPlaying = videoData["isPlaying"] as? Bool ?? false
        let elementTypeString = videoData["elementType"] as? String ?? "video"
        
        let elementType: VideoElementType = VideoElementType(rawValue: elementTypeString) ?? .video
        
        let videoInfo = VideoElementInfo(
            src: src,
            title: title,
            currentTime: currentTime,
            duration: duration,
            width: width,
            height: height,
            isPlaying: isPlaying,
            elementType: elementType
        )
        
        // Create PiP window on main thread
        DispatchQueue.main.async {
            if let webView = message.webView {
                PiPManager.shared.createPiPWindow(for: videoInfo, from: webView)
            }
        }
    }
} 