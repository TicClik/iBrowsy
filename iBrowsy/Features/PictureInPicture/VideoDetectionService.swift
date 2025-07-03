import Foundation
import WebKit

class VideoDetectionService {
    static let shared = VideoDetectionService()
    
    // Track ongoing video checks to prevent duplicates
    private var ongoingChecks = Set<ObjectIdentifier>()
    
    private init() {}
    
    // Auto-inject PiP functionality into videos on page load
    func enableAutomaticPiP(for webView: WKWebView) {
        let script = """
        (function() {
            // Function to add PiP button to video
            function addPiPButton(video) {
                if (video.hasAttribute('data-pip-enabled')) return;
                video.setAttribute('data-pip-enabled', 'true');
                
                // Create PiP button
                const pipButton = document.createElement('div');
                pipButton.innerHTML = '⧉';
                pipButton.style.cssText = `
                    position: absolute;
                    top: 10px;
                    right: 10px;
                    width: 32px;
                    height: 32px;
                    background: rgba(0,0,0,0.7);
                    color: white;
                    border: none;
                    border-radius: 4px;
                    cursor: pointer;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    font-size: 16px;
                    z-index: 9999;
                    transition: opacity 0.3s;
                    opacity: 0;
                    pointer-events: none;
                `;
                
                // Create container for positioning
                const container = document.createElement('div');
                container.style.cssText = `
                    position: relative;
                    display: inline-block;
                `;
                
                // Wrap video with container
                video.parentNode.insertBefore(container, video);
                container.appendChild(video);
                container.appendChild(pipButton);
                
                // Show/hide button on hover
                container.addEventListener('mouseenter', () => {
                    pipButton.style.opacity = '1';
                    pipButton.style.pointerEvents = 'auto';
                });
                
                container.addEventListener('mouseleave', () => {
                    pipButton.style.opacity = '0';
                    pipButton.style.pointerEvents = 'none';
                });
                
                // Handle PiP button click
                pipButton.addEventListener('click', (e) => {
                    e.stopPropagation();
                    e.preventDefault();
                    
                    const rect = video.getBoundingClientRect();
                    const videoData = {
                        src: video.src || video.currentSrc || '',
                        title: video.title || document.title || 'Video',
                        currentTime: video.currentTime || 0,
                        duration: video.duration || 0,
                        width: rect.width,
                        height: rect.height,
                        isPlaying: !video.paused,
                        elementType: 'video'
                    };
                    
                    // Send message to Swift with safety check
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.pipRequest) {
                        window.webkit.messageHandlers.pipRequest.postMessage(videoData);
                        console.log('PiP Detection: Successfully sent PiP request to Swift');
                    } else {
                        console.log('PiP Detection: Error - pipRequest message handler not available');
                    }
                });
            }
            
            // Function to handle YouTube videos
            function handleYouTubeVideos() {
                const ytPlayer = document.querySelector('#movie_player, .html5-video-player');
                if (ytPlayer) {
                    const video = ytPlayer.querySelector('video');
                    if (video) {
                        // Mark as processed to avoid duplicates
                        if (video.hasAttribute('data-pip-enabled')) return;
                        video.setAttribute('data-pip-enabled', 'true');
                        
                        // Create PiP button for YouTube
                        const pipButton = document.createElement('button');
                        pipButton.innerHTML = '⧉';
                        pipButton.style.cssText = `
                            position: absolute;
                            top: 10px;
                            right: 10px;
                            z-index: 99999;
                            background: rgba(0,0,0,0.7);
                            color: white;
                            border: none;
                            border-radius: 4px;
                            width: 32px;
                            height: 32px;
                            font-size: 16px;
                            cursor: pointer;
                            opacity: 0;
                            transition: opacity 0.3s;
                            pointer-events: none;
                        `;
                        
                        // Add button to player
                        ytPlayer.style.position = 'relative';
                        ytPlayer.appendChild(pipButton);
                        
                        // Show/hide on hover
                        ytPlayer.addEventListener('mouseenter', () => {
                            pipButton.style.opacity = '1';
                            pipButton.style.pointerEvents = 'auto';
                        });
                        
                        ytPlayer.addEventListener('mouseleave', () => {
                            pipButton.style.opacity = '0';
                            pipButton.style.pointerEvents = 'none';
                        });
                        
                        // Handle PiP button click
                        pipButton.addEventListener('click', (e) => {
                            e.stopPropagation();
                            e.preventDefault();
                            
                            const rect = video.getBoundingClientRect();
                            const videoData = {
                                src: video.src || video.currentSrc || window.location.href,
                                title: document.title || 'YouTube Video',
                                currentTime: video.currentTime || 0,
                                duration: video.duration || 0,
                                width: rect.width,
                                height: rect.height,
                                isPlaying: !video.paused,
                                elementType: 'iframe',
                                x: rect.left,
                                y: rect.top
                            };
                            
                            // Send message to Swift with safety check
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.pipRequest) {
                                window.webkit.messageHandlers.pipRequest.postMessage(videoData);
                                console.log('PiP Detection: Successfully sent PiP request to Swift');
                            } else {
                                console.log('PiP Detection: Error - pipRequest message handler not available');
                            }
                        });
                    }
                }
            }
            
            // Function to process all videos
            function processVideos() {
                // Handle regular HTML5 videos
                const videos = document.querySelectorAll('video:not([data-pip-enabled])');
                videos.forEach(video => {
                    const rect = video.getBoundingClientRect();
                    if (rect.width >= 200 && rect.height >= 150) {
                        addPiPButton(video);
                    }
                });
                
                // Handle YouTube videos
                if (window.location.hostname.includes('youtube.com') || window.location.hostname.includes('youtu.be')) {
                    handleYouTubeVideos();
                }
            }
            
            // Initial processing
            processVideos();
            
            // Monitor for new videos (dynamic content)
            const observer = new MutationObserver(() => {
                processVideos();
            });
            
            observer.observe(document.body, {
                childList: true,
                subtree: true
            });
            
            // Also check periodically for YouTube's dynamic loading
            setInterval(processVideos, 2000);
        })();
        """
        
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("Error enabling automatic PiP: \(error)")
            }
        }
    }
    
    func detectVideosOnPage(_ webView: WKWebView, completion: @escaping ([VideoElementInfo]) -> Void) {
        let script = """
        (function() {
            var videos = [];
            
            // Find HTML5 video elements
            var videoElements = document.querySelectorAll('video');
            for (var i = 0; i < videoElements.length; i++) {
                var video = videoElements[i];
                
                // Skip if video is not visible or too small
                var rect = video.getBoundingClientRect();
                if (rect.width < 100 || rect.height < 100) continue;
                
                var src = video.src || (video.currentSrc) || '';
                if (video.children.length > 0) {
                    // Check for source elements
                    var sources = video.querySelectorAll('source');
                    if (sources.length > 0) {
                        src = sources[0].src || src;
                    }
                }
                
                if (src) {
                    videos.push({
                        src: src,
                        title: video.title || video.getAttribute('aria-label') || document.title || 'Video',
                        currentTime: video.currentTime || 0,
                        duration: video.duration || 0,
                        width: rect.width,
                        height: rect.height,
                        isPlaying: !video.paused,
                        elementType: 'video',
                        x: rect.left,
                        y: rect.top
                    });
                }
            }
            
            // Find iframe video embeds (YouTube, Vimeo, etc.)
            var iframes = document.querySelectorAll('iframe');
            for (var i = 0; i < iframes.length; i++) {
                var iframe = iframes[i];
                var src = iframe.src;
                
                // Check if it's a video iframe
                if (src && (src.includes('youtube.com') || 
                           src.includes('vimeo.com') || 
                           src.includes('dailymotion.com') ||
                           src.includes('twitch.tv') ||
                           src.includes('facebook.com/plugins/video') ||
                           src.includes('player.') ||
                           src.includes('embed'))) {
                    
                    var rect = iframe.getBoundingClientRect();
                    if (rect.width < 100 || rect.height < 100) continue;
                    
                    videos.push({
                        src: src,
                        title: iframe.title || document.title || 'Embedded Video',
                        currentTime: 0,
                        duration: 0,
                        width: rect.width,
                        height: rect.height,
                        isPlaying: false,
                        elementType: 'iframe',
                        x: rect.left,
                        y: rect.top
                    });
                }
            }
            
            return JSON.stringify(videos);
        })();
        """
        
        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("Error detecting videos: \(error)")
                completion([])
                return
            }
            
            guard let jsonString = result as? String,
                  let data = jsonString.data(using: .utf8) else {
                completion([])
                return
            }
            
            do {
                let videoData = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
                let videoInfos = videoData.compactMap { dict -> VideoElementInfo? in
                    guard let src = dict["src"] as? String,
                          let title = dict["title"] as? String,
                          let elementTypeString = dict["elementType"] as? String,
                          let elementType = VideoElementType(rawValue: elementTypeString) else {
                        return nil
                    }
                    
                    let currentTime = dict["currentTime"] as? Double ?? 0
                    let duration = dict["duration"] as? Double ?? 0
                    let width = dict["width"] as? Double ?? 640
                    let height = dict["height"] as? Double ?? 360
                    let isPlaying = dict["isPlaying"] as? Bool ?? false
                    
                    return VideoElementInfo(
                        src: src,
                        title: title.isEmpty ? "Video" : title,
                        currentTime: currentTime,
                        duration: duration,
                        width: width,
                        height: height,
                        isPlaying: isPlaying,
                        elementType: elementType
                    )
                }
                
                completion(videoInfos)
            } catch {
                print("Error parsing video data: \(error)")
                completion([])
            }
        }
    }
    
    func findVideoAtPosition(_ webView: WKWebView, x: Double, y: Double, completion: @escaping (VideoElementInfo?) -> Void) {
        let script = """
        (function() {
            var clickX = \(x);
            var clickY = \(y);
            
            function isPointInRect(x, y, rect) {
                return (x >= rect.left && x <= rect.right && 
                        y >= rect.top && y <= rect.bottom);
            }
            
            // Check video elements
            var videoElements = document.querySelectorAll('video');
            for (var i = 0; i < videoElements.length; i++) {
                var video = videoElements[i];
                var rect = video.getBoundingClientRect();
                
                if (isPointInRect(clickX, clickY, rect)) {
                    var src = video.src || video.currentSrc || '';
                    if (video.children.length > 0) {
                        var sources = video.querySelectorAll('source');
                        if (sources.length > 0) {
                            src = sources[0].src || src;
                        }
                    }
                    
                    if (src) {
                        return JSON.stringify({
                            src: src,
                            title: video.title || video.getAttribute('aria-label') || document.title || 'Video',
                            currentTime: video.currentTime || 0,
                            duration: video.duration || 0,
                            width: rect.width,
                            height: rect.height,
                            isPlaying: !video.paused,
                            elementType: 'video'
                        });
                    }
                }
            }
            
            // Check iframe elements
            var iframes = document.querySelectorAll('iframe');
            for (var i = 0; i < iframes.length; i++) {
                var iframe = iframes[i];
                var rect = iframe.getBoundingClientRect();
                
                if (isPointInRect(clickX, clickY, rect)) {
                    var src = iframe.src;
                    if (src && (src.includes('youtube.com') || 
                               src.includes('vimeo.com') || 
                               src.includes('dailymotion.com') ||
                               src.includes('twitch.tv') ||
                               src.includes('facebook.com/plugins/video') ||
                               src.includes('player.') ||
                               src.includes('embed'))) {
                        
                        return JSON.stringify({
                            src: src,
                            title: iframe.title || document.title || 'Embedded Video',
                            currentTime: 0,
                            duration: 0,
                            width: rect.width,
                            height: rect.height,
                            isPlaying: false,
                            elementType: 'iframe'
                        });
                    }
                }
            }
            
            return null;
        })();
        """
        
        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("Error finding video at position: \(error)")
                completion(nil)
                return
            }
            
            guard let jsonString = result as? String,
                  let data = jsonString.data(using: .utf8) else {
                completion(nil)
                return
            }
            
            do {
                if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let src = dict["src"] as? String,
                   let title = dict["title"] as? String,
                   let elementTypeString = dict["elementType"] as? String,
                   let elementType = VideoElementType(rawValue: elementTypeString) {
                    
                    let currentTime = dict["currentTime"] as? Double ?? 0
                    let duration = dict["duration"] as? Double ?? 0
                    let width = dict["width"] as? Double ?? 640
                    let height = dict["height"] as? Double ?? 360
                    let isPlaying = dict["isPlaying"] as? Bool ?? false
                    
                    let videoInfo = VideoElementInfo(
                        src: src,
                        title: title.isEmpty ? "Video" : title,
                        currentTime: currentTime,
                        duration: duration,
                        width: width,
                        height: height,
                        isPlaying: isPlaying,
                        elementType: elementType
                    )
                    
                    completion(videoInfo)
                } else {
                    completion(nil)
                }
            } catch {
                print("Error parsing video data: \(error)")
                completion(nil)
            }
        }
    }
    
    // Check for currently playing videos (for auto-PiP when switching tabs)
    func checkForPlayingVideos(_ webView: WKWebView, completion: @escaping ([VideoElementInfo]) -> Void) {
        let webViewID = ObjectIdentifier(webView)
        
        // Prevent duplicate checks on the same WebView
        guard !ongoingChecks.contains(webViewID) else {
            print("VideoDetectionService: Skipping duplicate check for WebView")
            completion([])
            return
        }
        
        ongoingChecks.insert(webViewID)
        
        print("VideoDetectionService: Checking for playing videos...")
        let script = """
        (function() {
            var playingVideos = [];
            var isYouTube = window.location.hostname.includes('youtube.com') || window.location.hostname.includes('youtu.be');
            
            // Special handling for YouTube videos - more aggressive detection
            if (isYouTube) {
                console.log('PiP Detection: YouTube page detected, looking for videos');
                
                // Find all video elements
                var videos = Array.from(document.querySelectorAll('video'));
                console.log('PiP Detection: Found', videos.length, 'video elements');
                
                if (videos.length > 0) {
                    // Score and find the best video
                    var bestVideo = null;
                    var bestScore = -1;
                    
                    videos.forEach(function(video) {
                        var score = 0;
                        var rect = video.getBoundingClientRect();
                        
                        // Score based on size and visibility
                        if (rect.width > 0 && rect.height > 0) score += 10;
                        if (rect.width >= 300 && rect.height >= 200) score += 20;
                        
                        // Score based on playback state - more permissive
                        if (!video.paused) score += 30;
                        if (video.currentTime > 0) score += 15;
                        if (video.duration > 0) score += 10;
                        if (video.readyState >= 1) score += 5;
                        
                        // YouTube-specific scoring
                        if (video.closest('#movie_player, .html5-video-player')) score += 25;
                        
                        console.log('PiP Detection: Video score:', score, 'paused:', video.paused, 'time:', video.currentTime, 'duration:', video.duration);
                        
                        if (score > bestScore) {
                            bestScore = score;
                            bestVideo = video;
                        }
                    });
                    
                    // Accept any video with some content
                    if (bestVideo && (bestVideo.duration > 0 || bestVideo.currentTime > 0 || bestVideo.readyState >= 1)) {
                        var rect = bestVideo.getBoundingClientRect();
                        var width = rect.width > 0 ? rect.width : 640;
                        var height = rect.height > 0 ? rect.height : 360;
                        
                        // Clean URL
                        var videoSource = window.location.href;
                        try {
                            var url = new URL(videoSource);
                            var cleanURL = url.protocol + '//' + url.host + url.pathname;
                            if (url.searchParams.get('v')) {
                                cleanURL += '?v=' + url.searchParams.get('v');
                            }
                            videoSource = cleanURL;
                        } catch (e) {
                            // Keep original URL if parsing fails
                        }
                        
                        var currentTime = bestVideo.currentTime || 0;
                        var duration = bestVideo.duration || 0;
                        var isPlaying = !bestVideo.paused && !bestVideo.ended;
                        
                        // Try YouTube API for better timing
                        try {
                            var ytPlayer = document.querySelector('#movie_player');
                            if (ytPlayer && typeof ytPlayer.getCurrentTime === 'function') {
                                var apiTime = ytPlayer.getCurrentTime();
                                var apiDuration = ytPlayer.getDuration();
                                if (apiTime >= 0) currentTime = apiTime;
                                if (apiDuration > 0) duration = apiDuration;
                            }
                        } catch (e) {
                            console.log('PiP Detection: YouTube API error:', e.message);
                        }
                        
                        console.log('PiP Detection: Selected YouTube video - playing:', isPlaying, 'time:', currentTime, 'duration:', duration);
                        
                        playingVideos.push({
                            src: videoSource,
                            title: document.title || 'YouTube Video',
                            currentTime: currentTime,
                            duration: duration,
                            width: width,
                            height: height,
                            isPlaying: isPlaying,
                            elementType: 'iframe',
                            x: rect.left,
                            y: rect.top
                        });
                    } else {
                        console.log('PiP Detection: No suitable YouTube video found');
                    }
                } else {
                    console.log('PiP Detection: No video elements found on YouTube page');
                }
            } else {
                // For non-YouTube sites, check HTML5 video elements that are currently playing
                var videoElements = document.querySelectorAll('video');
                for (var i = 0; i < videoElements.length; i++) {
                    var video = videoElements[i];
                    
                    // Only include videos that are playing and visible
                    if (!video.paused && !video.ended) {
                        var rect = video.getBoundingClientRect();
                        if (rect.width >= 200 && rect.height >= 150) {
                            var src = video.src || video.currentSrc || '';
                            if (video.children.length > 0) {
                                var sources = video.querySelectorAll('source');
                                if (sources.length > 0) {
                                    src = sources[0].src || src;
                                }
                            }
                            
                            if (src) {
                                playingVideos.push({
                                    src: src,
                                    title: video.title || video.getAttribute('aria-label') || document.title || 'Video',
                                    currentTime: video.currentTime || 0,
                                    duration: video.duration || 0,
                                    width: rect.width,
                                    height: rect.height,
                                    isPlaying: true,
                                    elementType: 'video',
                                    x: rect.left,
                                    y: rect.top
                                });
                            }
                        }
                    }
                }
            }
            
            return JSON.stringify(playingVideos);
        })();
        """
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            // Always clean up the ongoing check
            self?.ongoingChecks.remove(webViewID)
            
            if let error = error {
                print("Error checking for playing videos: \(error)")
                completion([])
                return
            }
            
            guard let jsonString = result as? String,
                  let data = jsonString.data(using: .utf8) else {
                completion([])
                return
            }
            
            do {
                let videoData = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
                let videoInfos = videoData.compactMap { dict -> VideoElementInfo? in
                    guard let src = dict["src"] as? String,
                          let title = dict["title"] as? String,
                          let elementTypeString = dict["elementType"] as? String,
                          let elementType = VideoElementType(rawValue: elementTypeString) else {
                        return nil
                    }
                    
                    let currentTime = dict["currentTime"] as? Double ?? 0
                    let duration = dict["duration"] as? Double ?? 0
                    let width = dict["width"] as? Double ?? 640
                    let height = dict["height"] as? Double ?? 360
                    let isPlaying = dict["isPlaying"] as? Bool ?? false
                    
                    return VideoElementInfo(
                        src: src,
                        title: title.isEmpty ? "Video" : title,
                        currentTime: currentTime,
                        duration: duration,
                        width: width,
                        height: height,
                        isPlaying: isPlaying,
                        elementType: elementType
                    )
                }
                
                completion(videoInfos)
            } catch {
                print("Error parsing playing video data: \(error)")
                completion([])
            }
        }
    }
    
    // Enhanced method for more accurate timeline synchronization
    func checkForPlayingVideosWithAccurateTime(_ webView: WKWebView, completion: @escaping ([VideoElementInfo]) -> Void) {
        print("VideoDetectionService: Checking for playing videos with accurate timeline...")
        
        // For YouTube, use the page URL as the source and clean it
        if let url = webView.url?.absoluteString,
           (url.contains("youtube.com") || url.contains("youtu.be")) {
            let cleanedURL = cleanYouTubeURL(url)
            print("VideoDetectionService: Detected YouTube page for accurate sync: \(cleanedURL)")
            
            // Enhanced script with more aggressive video detection for YouTube
            let script = """
                (function() {
                    console.log('PiP Detection: Starting enhanced video detection process');
                    
                    // First, try to find any video element on the page
                    var videos = Array.from(document.querySelectorAll('video'));
                    console.log('PiP Detection: Found', videos.length, 'video elements');
                    
                    if (videos.length === 0) {
                        console.log('PiP Detection: No video elements found');
                        return null;
                    }
                    
                    // Find the best candidate video
                    var targetVideo = null;
                    var bestScore = -1;
                    
                    videos.forEach(function(video, index) {
                        var score = 0;
                        console.log('PiP Detection: Evaluating video', index);
                        
                        // Score based on visibility and size
                        var rect = video.getBoundingClientRect();
                        var isVisible = rect.width > 0 && rect.height > 0;
                        var isLargeEnough = rect.width >= 300 && rect.height >= 200;
                        
                        if (isVisible) score += 10;
                        if (isLargeEnough) score += 20;
                        
                        // Score based on playback state
                        if (!video.paused) score += 30;
                        if (video.currentTime > 0) score += 15;
                        if (video.duration > 0) score += 10;
                        if (video.readyState >= 1) score += 5;
                        
                        // Score based on video source
                        if (video.src || video.currentSrc) score += 5;
                        
                        // YouTube specific scoring
                        var isYouTubeVideo = video.closest('#movie_player, .html5-video-player') !== null;
                        if (isYouTubeVideo) score += 25;
                        
                        console.log('PiP Detection: Video', index, 'score:', score, 
                                   'paused:', video.paused, 
                                   'currentTime:', video.currentTime,
                                   'duration:', video.duration,
                                   'readyState:', video.readyState,
                                   'dimensions:', rect.width + 'x' + rect.height);
                        
                        if (score > bestScore) {
                            bestScore = score;
                            targetVideo = video;
                        }
                    });
                    
                    if (!targetVideo) {
                        console.log('PiP Detection: No suitable video found');
                        return null;
                    }
                    
                    console.log('PiP Detection: Selected video with score:', bestScore);
                    
                    // For YouTube, we always want to detect the video if it has any content
                    // This is more permissive than before
                    var rect = targetVideo.getBoundingClientRect();
                    var hasContent = targetVideo.duration > 0 || 
                                   targetVideo.currentTime > 0 || 
                                   targetVideo.readyState >= 1 ||
                                   (targetVideo.src || targetVideo.currentSrc);
                    
                    if (!hasContent) {
                        console.log('PiP Detection: Video has no content');
                        return null;
                    }
                    
                    // Use fallback dimensions if needed
                    var width = rect.width > 0 ? rect.width : 640;
                    var height = rect.height > 0 ? rect.height : 360;
                    var currentTime = targetVideo.currentTime || 0;
                    var duration = targetVideo.duration || 0;
                    var isPlaying = !targetVideo.paused && !targetVideo.ended;
                    
                    // Try to get YouTube player API data for better accuracy
                    var ytPlayer = document.querySelector('#movie_player');
                    if (ytPlayer) {
                        try {
                            if (typeof ytPlayer.getCurrentTime === 'function') {
                                var apiTime = ytPlayer.getCurrentTime();
                                var apiDuration = ytPlayer.getDuration();
                                if (apiTime >= 0) currentTime = apiTime;
                                if (apiDuration > 0) duration = apiDuration;
                                console.log('PiP Detection: Got YouTube API data - time:', apiTime, 'duration:', apiDuration);
                            }
                        } catch (e) {
                            console.log('PiP Detection: YouTube API not available:', e.message);
                        }
                    }
                    
                    console.log('PiP Detection: Creating video result with currentTime:', currentTime, 'duration:', duration, 'isPlaying:', isPlaying);
                    
                    return {
                        src: '\(cleanedURL)',
                        title: document.title || 'YouTube Video',
                        currentTime: currentTime,
                        duration: duration,
                        width: width,
                        height: height,
                        isPlaying: isPlaying,
                        elementType: 'iframe',
                        x: rect.left,
                        y: rect.top
                    };
                })();
            """
            
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("VideoDetectionService: Error checking video with accurate time: \(error)")
                    completion([])
                    return
                }
                
                if let videoData = result as? [String: Any],
                   let src = videoData["src"] as? String,
                   let title = videoData["title"] as? String,
                   let elementTypeString = videoData["elementType"] as? String,
                   let elementType = VideoElementType(rawValue: elementTypeString) {
                    
                    let currentTime = videoData["currentTime"] as? Double ?? 0
                    let duration = videoData["duration"] as? Double ?? 0
                    let width = videoData["width"] as? Double ?? 640
                    let height = videoData["height"] as? Double ?? 360
                    let isPlaying = videoData["isPlaying"] as? Bool ?? false
                    
                    let videoInfo = VideoElementInfo(
                        src: src,
                        title: title.isEmpty ? "YouTube Video" : title,
                        currentTime: currentTime,
                        duration: duration,
                        width: width,
                        height: height,
                        isPlaying: isPlaying,
                        elementType: elementType
                    )
                    
                    print("VideoDetectionService: Found playing video with accurate time: \(title) at \(currentTime)s")
                    completion([videoInfo])
                } else {
                    print("VideoDetectionService: No playing video found for accurate sync")
                    completion([])
                }
            }
        } else {
            print("VideoDetectionService: Not a YouTube page for accurate sync")
            completion([])
        }
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