import Foundation
import SwiftUI
import WebKit
import AppKit

@MainActor
class PiPManager: ObservableObject {
    static let shared = PiPManager()
    
    @Published var activePiPWindows: [PiPWindow] = []
    
    // Track recently created PiP windows to prevent rapid re-creation
    private var recentlyCreatedVideos: Set<VideoElementInfo> = []
    private var lastPiPCreationTime: [String: Date] = [:]
    private let pipCooldownDuration: TimeInterval = 2.0 // 2.0 seconds cooldown to prevent rapid duplicates
    
    // Global flag to temporarily suspend PiP creation during focus transitions
    private var isPiPSuspended = false
    private var pipSuspensionEndTime: Date?
    
    private init() {}
    
    func createPiPWindow(for videoElement: VideoElementInfo, from sourceWebView: WKWebView) {
        let videoKey = "\(videoElement.src)_\(videoElement.title ?? "")"
        
        print("PiPManager: Attempting to create PiP for video:")
        print("  - ID: \(videoElement.id)")
        print("  - Title: \(videoElement.title ?? "nil")")
        print("  - Src: \(videoElement.src)")
        print("  - Element Type: \(videoElement.elementType)")
        print("  - Current active windows: \(activePiPWindows.count)")
        
        // Check if PiP is temporarily suspended
        if isPiPSuspended {
            if let endTime = pipSuspensionEndTime, Date() > endTime {
                // Suspension period ended, resume PiP
                isPiPSuspended = false
                pipSuspensionEndTime = nil
                print("PiPManager: PiP suspension period ended, resuming normal operation")
            } else {
                print("PiPManager: Skipping PiP creation - PiP is temporarily suspended")
                return
            }
        }
        
        // Check if we already have a PiP window for this exact video
        let existingWindow = activePiPWindows.first { window in
            window.videoInfo.src == videoElement.src && 
            window.videoInfo.title == videoElement.title
        }
        
        if let existing = existingWindow {
            print("PiPManager: Skipping PiP creation - identical window already exists for this video")
            print("  - Existing window ID: \(existing.id)")
            return
        }
        
        // Enforce maximum window limit to prevent overwhelming system
        let maxPiPWindows = 3
        if activePiPWindows.count >= maxPiPWindows {
            print("PiPManager: Skipping PiP creation - maximum windows limit reached (\(maxPiPWindows))")
            return
        }
        
        // Check cooldown period to prevent rapid duplicates
        if let lastCreation = lastPiPCreationTime[videoKey] {
            let timeSinceLastCreation = Date().timeIntervalSince(lastCreation)
            if timeSinceLastCreation < pipCooldownDuration {
                print("PiPManager: Skipping PiP creation - cooldown active (\(timeSinceLastCreation)s < \(pipCooldownDuration)s)")
                return
            }
        }
        
        // More comprehensive duplicate checking
        if let existingWindow = findExistingWindow(for: videoElement) {
            print("PiPManager: Skipping PiP creation - window already exists for this video (found: \(existingWindow.videoInfo.title ?? "unknown"))")
            print("  - Existing ID: \(existingWindow.videoInfo.id)")
            print("  - New ID: \(videoElement.id)")
            return
        }
        
        // Check if we've recently created this video
        if recentlyCreatedVideos.contains(videoElement) {
            print("PiPManager: Skipping PiP creation - recently created")
            print("  - Recently created videos count: \(recentlyCreatedVideos.count)")
            return
        }
        
        print("PiPManager: Creating new PiP window for video: \(videoElement.title ?? videoElement.src)")
        
        // Pause the original video to prevent dual playback
        pauseOriginalVideo(in: sourceWebView, videoInfo: videoElement)
        
        // Cleanup excessive windows before creating a new one
        cleanupExcessivePiPWindows()
        
        let pipWindow = PiPWindow(videoInfo: videoElement, sourceWebView: sourceWebView)
        activePiPWindows.append(pipWindow)
        
        // Track this video as recently created
        recentlyCreatedVideos.insert(videoElement)
        lastPiPCreationTime[videoKey] = Date()
        
        pipWindow.show()
        
        // Listen for window close events
        pipWindow.onClose = { [weak self] (closedWindow: PiPWindow) in
            self?.activePiPWindows.removeAll { $0.id == closedWindow.id }
            self?.recentlyCreatedVideos.remove(closedWindow.videoInfo)
            self?.lastPiPCreationTime.removeValue(forKey: videoKey)
        }
        
        // Clean up recent tracking after cooldown period
        DispatchQueue.main.asyncAfter(deadline: .now() + pipCooldownDuration) {
            self.recentlyCreatedVideos.remove(videoElement)
        }
    }
    
    func closePiPWindow(id: UUID) {
        if let index = activePiPWindows.firstIndex(where: { $0.id == id }) {
            activePiPWindows[index].close()
            activePiPWindows.remove(at: index)
        }
    }
    
    func closeAllPiPWindows() {
        print("PiPManager: Closing all \(activePiPWindows.count) PiP windows")
        for window in activePiPWindows {
            window.close()
        }
        activePiPWindows.removeAll()
        recentlyCreatedVideos.removeAll()
        lastPiPCreationTime.removeAll()
        print("PiPManager: All PiP windows closed and tracking data cleared")
    }
    
    // Close all PiP windows and sync timeline back to main video
    func closeAllPiPWindowsAndSyncTimeline(to webView: WKWebView) {
        print("PiPManager: Closing all PiP windows and syncing timeline back to main video")
        
        // Temporarily suspend new PiP creation during focus transitions
        suspendPiPCreation(for: 1.0) // Suspend for 1 second
        
        // Get current time from any active PiP window before closing
        var lastKnownTime: Double = 0
        
        for pipWindow in activePiPWindows {
            // Get current time from PiP window if possible
            pipWindow.getCurrentPiPTime { currentTime in
                print("PiPManager: PiP window current time: \(currentTime)")
                // Use this time for synchronization if needed
            }
            pipWindow.close()
        }
        activePiPWindows.removeAll()
        recentlyCreatedVideos.removeAll()
        lastPiPCreationTime.removeAll()
        
        // Sync the main video to continue from where PiP left off
        let syncScript = """
            (function() {
                var ytPlayer = document.querySelector('#movie_player, .html5-video-player');
                if (ytPlayer) {
                    var video = ytPlayer.querySelector('video');
                    if (video) {
                        // Resume playback if it was paused
                        if (video.paused) {
                            video.play().catch(function(e) {
                                console.log('Could not resume playback:', e);
                            });
                        }
                        return {
                            resumed: true,
                            currentTime: video.currentTime
                        };
                    }
                }
                return { resumed: false };
            })();
        """
        
        webView.evaluateJavaScript(syncScript) { result, error in
            if let error = error {
                print("PiPManager: Error syncing timeline back to main video: \(error)")
            } else if let result = result as? [String: Any] {
                print("PiPManager: Timeline sync result: \(result)")
            }
        }
    }
    
    // Emergency cleanup method to close excessive PiP windows
    func cleanupExcessivePiPWindows(maxAllowed: Int = 5) {
        if activePiPWindows.count > maxAllowed {
            print("PiPManager: Cleaning up \(activePiPWindows.count - maxAllowed) excessive PiP windows")
            
            // Close oldest windows first (keep most recent ones)
            let windowsToClose = Array(activePiPWindows.prefix(activePiPWindows.count - maxAllowed))
            for window in windowsToClose {
                window.close()
                activePiPWindows.removeAll { $0.id == window.id }
            }
            
            // Also cleanup tracking data
            recentlyCreatedVideos.removeAll()
            lastPiPCreationTime.removeAll()
        }
    }
    
    // Temporarily suspend new PiP creation during focus transitions
    func suspendPiPCreation(for duration: TimeInterval) {
        isPiPSuspended = true
        pipSuspensionEndTime = Date().addingTimeInterval(duration)
        print("PiPManager: PiP creation suspended for \(duration) seconds")
        
        // Automatically resume after the suspension period
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.isPiPSuspended = false
            self.pipSuspensionEndTime = nil
            print("PiPManager: PiP suspension ended automatically")
        }
    }
    
    // Pause the original video when PiP is created
    private func pauseOriginalVideo(in webView: WKWebView, videoInfo: VideoElementInfo) {
        let script = """
        (function() {
            try {
                var pausedTime = 0;
                
                // For YouTube videos
                if (window.location.hostname.includes('youtube.com') || window.location.hostname.includes('youtu.be')) {
                    var ytPlayer = document.querySelector('#movie_player, .html5-video-player');
                    if (ytPlayer) {
                        var video = ytPlayer.querySelector('video');
                        if (video && !video.paused) {
                            pausedTime = video.currentTime;
                            video.pause();
                            video.setAttribute('data-pip-paused', 'true');
                            video.setAttribute('data-pip-time', pausedTime.toString());
                            console.log('YouTube video paused for PiP at time:', pausedTime);
                        }
                    }
                    // Also try YouTube player API if available
                    if (typeof ytPlayer !== 'undefined' && ytPlayer.pauseVideo) {
                        ytPlayer.pauseVideo();
                    }
                }
                
                // For other HTML5 videos
                var videos = document.querySelectorAll('video');
                videos.forEach(function(video) {
                    if (!video.paused) {
                        pausedTime = video.currentTime;
                        video.pause();
                        video.setAttribute('data-pip-paused', 'true');
                        video.setAttribute('data-pip-time', pausedTime.toString());
                        console.log('HTML5 video paused for PiP at time:', pausedTime);
                    }
                });
                
                return pausedTime;
            } catch (error) {
                console.log('Error pausing original video:', error);
                return 0;
            }
        })();
        """
        
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("Error pausing original video: \(error)")
            }
        }
    }
    
    // Resume the original video when PiP is closed and sync to PiP time
    func resumeOriginalVideo(in webView: WKWebView, videoInfo: VideoElementInfo, pipCurrentTime: Double? = nil) {
        let currentTime = pipCurrentTime ?? videoInfo.currentTime
        let script = """
        (function() {
            try {
                var resumeTime = \(currentTime);
                
                // For YouTube videos
                if (window.location.hostname.includes('youtube.com') || window.location.hostname.includes('youtu.be')) {
                    var ytPlayer = document.querySelector('#movie_player, .html5-video-player');
                    if (ytPlayer) {
                        var video = ytPlayer.querySelector('video');
                        if (video && video.hasAttribute('data-pip-paused')) {
                            // Sync to PiP time if provided, otherwise use stored time
                            var storedTime = parseFloat(video.getAttribute('data-pip-time') || '0');
                            var syncTime = resumeTime > 0 ? resumeTime : storedTime;
                            
                            if (syncTime > 0) {
                                video.currentTime = syncTime;
                            }
                            
                            video.removeAttribute('data-pip-paused');
                            video.removeAttribute('data-pip-time');
                            video.play();
                            console.log('YouTube video resumed from PiP at time:', syncTime);
                        }
                    }
                    // Also try YouTube player API if available
                    if (typeof ytPlayer !== 'undefined' && ytPlayer.seekTo && ytPlayer.playVideo) {
                        if (resumeTime > 0) {
                            ytPlayer.seekTo(resumeTime, true);
                        }
                        ytPlayer.playVideo();
                    }
                }
                
                // For other HTML5 videos
                var videos = document.querySelectorAll('video[data-pip-paused]');
                videos.forEach(function(video) {
                    // Sync to PiP time if provided, otherwise use stored time
                    var storedTime = parseFloat(video.getAttribute('data-pip-time') || '0');
                    var syncTime = resumeTime > 0 ? resumeTime : storedTime;
                    
                    if (syncTime > 0) {
                        video.currentTime = syncTime;
                    }
                    
                    video.removeAttribute('data-pip-paused');
                    video.removeAttribute('data-pip-time');
                    video.play();
                    console.log('HTML5 video resumed from PiP at time:', syncTime);
                });
            } catch (error) {
                console.log('Error resuming original video:', error);
            }
        })();
        """
        
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("Error resuming original video: \(error)")
            }
        }
    }
    
    // Helper method to find existing windows with comprehensive matching
    private func findExistingWindow(for videoElement: VideoElementInfo) -> PiPWindow? {
        // First check by exact ID match
        if let window = activePiPWindows.first(where: { $0.videoInfo.id == videoElement.id }) {
            return window
        }
        
        // Then check by src and title
        for window in activePiPWindows {
            if window.videoInfo.src == videoElement.src && window.videoInfo.title == videoElement.title {
                return window
            }
        }
        
        // For YouTube videos, check by cleaned URL (remove parameters)
        if videoElement.elementType.rawValue == "iframe" && isYouTubeURL(videoElement.src) {
            let cleanSrc = cleanYouTubeURL(videoElement.src)
            for window in activePiPWindows {
                if isYouTubeURL(window.videoInfo.src) && cleanYouTubeURL(window.videoInfo.src) == cleanSrc {
                    return window
                }
            }
        }
        
        return nil
    }
    
    // Helper to check if URL is YouTube
    private func isYouTubeURL(_ url: String) -> Bool {
        return url.contains("youtube.com") || url.contains("youtu.be")
    }
    
    // Helper to clean YouTube URLs for comparison
    private func cleanYouTubeURL(_ url: String) -> String {
        guard let urlComponents = URLComponents(string: url) else { return url }
        
        // Keep only the essential parts
        var cleanComponents = URLComponents()
        cleanComponents.scheme = urlComponents.scheme
        cleanComponents.host = urlComponents.host
        cleanComponents.path = urlComponents.path
        
        // Keep only the video ID parameter
        if let videoID = urlComponents.queryItems?.first(where: { $0.name == "v" })?.value {
            cleanComponents.queryItems = [URLQueryItem(name: "v", value: videoID)]
        }
        
        return cleanComponents.url?.absoluteString ?? url
    }
}