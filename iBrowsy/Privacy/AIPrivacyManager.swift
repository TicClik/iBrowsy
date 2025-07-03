import Foundation
import WebKit
import SwiftUI
import Combine

@MainActor
class AIPrivacyManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isEnabled: Bool = true
    @Published var blockedCount: Int = 0
    @Published var enhancedYouTubeBlocking: Bool = true
    @Published var aiContentAnalysis: Bool = true
    @Published var performanceMode: PerformanceMode = .balanced
    @Published var lastBlockedDomains: [String] = []
    
    // MARK: - New Real-time Statistics
    @Published var todayBlockedCount: Int = 0
    @Published var weekBlockedCount: Int = 0
    @Published var recentBlocks: [BlockedItem] = []
    
    // MARK: - Types
    enum PerformanceMode: String, CaseIterable {
        case aggressive = "Aggressive"
        case balanced = "Balanced"
        case minimal = "Minimal"
        
        var description: String {
            switch self {
            case .aggressive: return "Maximum blocking, may break some sites"
            case .balanced: return "Smart blocking with compatibility"
            case .minimal: return "Basic blocking, maximum compatibility"
            }
        }
    }
    
    enum BlockReason: String, Codable {
        case advertisement = "Advertisement"
        case tracker = "Tracker"
        case analytics = "Analytics"
        case social = "Social Media Widget"
        case popup = "Popup/Modal"
        case autoplay = "Autoplay Media"
        case aiDetected = "AI-Detected Unwanted Content"
        case contentRule = "Content Rule Block"
        case youtubeAd = "YouTube Ad"
    }
    
    struct BlockedItem: Identifiable, Codable {
        let id = UUID()
        let url: String
        let domain: String
        let reason: BlockReason
        let timestamp: Date
    }
    
    // MARK: - Private Properties
    private var contentRuleList: WKContentRuleList?
    private var aiAnalysisEngine = AIContentAnalysisEngine()
    private var youtubeAdBlocker = YouTubeAdBlocker()
    private var performanceOptimizer = PerformanceOptimizer()
    private var statisticsTimer: Timer?
    
    // Storage for statistics
    private let userDefaults = UserDefaults.standard
    private let blockedItemsKey = "AIPrivacy_BlockedItems"
    private let totalBlockedKey = "AIPrivacy_TotalBlocked"
    
    // Advanced blocking rules - More specific selectors to avoid blocking legitimate content
    private let advancedSelectors = [
        // Generic ad selectors with high confidence
        ".advertisement", ".ad-container", ".adsystem",
        "#google_ads", ".google-ad", "[data-ad-slot]",
        ".sponsored", ".promotion", ".native-ad",
        
        // Social media tracking widgets
        ".fb-like", ".twitter-tweet", ".linkedin-widget", ".pinterest-widget",
        ".social-share", ".addthis", ".sharethis",
        
        // Pop-ups and modals (more specific)
        ".popup-ad", ".modal-ad", ".overlay-ad",
        ".newsletter-popup", ".exit-intent", ".subscription-modal",
        
        // Specific YouTube ad containers (avoid main player)
        ".ytp-ad-module", ".ytp-ad-overlay-container", ".ytp-ad-text-overlay",
        ".masthead-ad-control", "#player-ads", ".ad-banner",
        ".companion-ad", ".display-ad"
    ]
    
    private let trackerDomains = [
        // Analytics and tracking
        "google-analytics.com", "googletagmanager.com", "doubleclick.net",
        "facebook.com/tr", "connect.facebook.net", "analytics.twitter.com",
        "scorecardresearch.com", "quantserve.com", "chartbeat.com",
        
        // Ad networks
        "googlesyndication.com", "googleadservices.com", "adsystem.amazon.com",
        "adsystem.amazon.co.uk", "amazon-adsystem.com", "media.amazon.com",
        "bing.com/fd/ls/GLinkPing.aspx", "bat.bing.com",
        
        // YouTube ad domains  
        "googleads.g.doubleclick.net", "googleads4.g.doubleclick.net",
        "static.doubleclick.net", "stats.g.doubleclick.net",
        "youtube.com/api/stats/ads", "youtube.com/ptracking",
        "youtube.com/youtubei/v1/log_event", "youtube.com/api/stats/qoe",
        
        // Social media tracking
        "facebook.com/plugins", "platform.twitter.com", "apis.google.com/js/platform.js",
        "connect.facebook.net", "platform.linkedin.com", "assets.pinterest.com",
        
        // Other tracking services
        "hotjar.com", "fullstory.com", "loggly.com", "bugsnag.com",
        "mixpanel.com", "amplitude.com", "segment.com", "heap.analytics.io"
    ]
    
    // MARK: - Initialization
    init() {
        loadStoredStatistics()
        setupContentRules()
        startPerformanceMonitoring()
        startStatisticsTracking()
    }
    
    // MARK: - Public Methods
    func configureWebView(_ webView: WKWebView) {
        // Apply content rule list
        if let ruleList = contentRuleList {
            webView.configuration.userContentController.add(ruleList)
        }
        
        // Inject AI-powered blocking scripts
        injectAdvancedBlockingScript(into: webView)
        
        // Configure YouTube-specific blocking
        if enhancedYouTubeBlocking {
            youtubeAdBlocker.configure(webView: webView)
        }
        
        // Set up navigation delegate for tracking
        setupNavigationTracking(for: webView)
        
        print("AIPrivacyManager: Configured WebView with blocking rules")
    }
    
    func updateBlockingLevel(_ mode: PerformanceMode) {
        performanceMode = mode
        updateContentRules()
    }
    
    func getBlockingStats() -> (total: Int, today: Int, thisWeek: Int) {
        return (
            total: blockedCount,
            today: todayBlockedCount,
            thisWeek: weekBlockedCount
        )
    }
    
    // MARK: - Statistics Management
    private func loadStoredStatistics() {
        // RESET statistics due to previous over-counting issue
        print("AIPrivacyManager: Resetting statistics due to over-aggressive blocking fix")
        
        // Clear inflated statistics
        userDefaults.removeObject(forKey: totalBlockedKey)
        userDefaults.removeObject(forKey: blockedItemsKey)
        
        // Start fresh
        blockedCount = 0
        todayBlockedCount = 0
        weekBlockedCount = 0
        recentBlocks = []
        
        print("AIPrivacyManager: Statistics reset - Starting fresh with conservative blocking")
    }
    
    private func saveStatistics() {
        userDefaults.set(blockedCount, forKey: totalBlockedKey)
        
        if let data = try? JSONEncoder().encode(recentBlocks) {
            userDefaults.set(data, forKey: blockedItemsKey)
        }
    }
    
    private func startStatisticsTracking() {
        // Update statistics every 30 seconds
        statisticsTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.updateStatistics()
        }
    }
    
    private func updateStatistics() {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfDay
        
        // Clean up old entries (keep only last 30 days)
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        recentBlocks = recentBlocks.filter { $0.timestamp >= thirtyDaysAgo }
        
        // Recalculate counts
        todayBlockedCount = recentBlocks.filter { $0.timestamp >= startOfDay }.count
        weekBlockedCount = recentBlocks.filter { $0.timestamp >= startOfWeek }.count
        
        saveStatistics()
    }
    
    // MARK: - Private Methods
    private func setupContentRules() {
        let ruleList = generateContentRules()
        
        // First remove any existing rules to avoid conflicts
        WKContentRuleListStore.default().removeContentRuleList(forIdentifier: "AIPrivacyRules") { [weak self] _ in
            // Proceed with compilation regardless of removal result
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "AIPrivacyRules",
                encodedContentRuleList: ruleList
            ) { [weak self] compiledRuleList, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("AIPrivacyManager: Error compiling rules: \(error)")
                        print("AIPrivacyManager: Rule list content: \(ruleList)")
                        // Fall back to basic rules if compilation fails
                        self?.setupBasicContentRules()
                    } else {
                        self?.contentRuleList = compiledRuleList
                        print("AIPrivacyManager: Content rules compiled successfully")
                    }
                }
            }
        }
    }
    
    private func setupBasicContentRules() {
        // Fallback to basic rules if advanced compilation fails
        let basicRules = [
            [
                "trigger": [
                    "url-filter": "doubleclick\\.net",
                    "resource-type": ["script", "raw"]
                ],
                "action": [
                    "type": "block"
                ]
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: basicRules, options: .prettyPrinted)
            let basicRuleList = String(data: jsonData, encoding: .utf8) ?? "[]"
            
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "AIPrivacyBasicRules",
                encodedContentRuleList: basicRuleList
            ) { [weak self] compiledRuleList, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("AIPrivacyManager: Even basic rules failed: \(error)")
                    } else {
                        self?.contentRuleList = compiledRuleList
                        print("AIPrivacyManager: Basic rules compiled successfully")
                    }
                }
            }
        } catch {
            print("AIPrivacyManager: Failed to create basic rules: \(error)")
        }
    }
    
    private func generateContentRules() -> String {
        var rules: [[String: Any]] = []
        
        // Domain blocking rules - with tracking
        for domain in trackerDomains {
            let rule: [String: Any] = [
                "trigger": [
                    "url-filter": domain.replacingOccurrences(of: ".", with: "\\."),
                    "resource-type": ["document", "image", "script", "raw"]
                ],
                "action": [
                    "type": "block"
                ]
            ]
            rules.append(rule)
        }
        
        // CSS selector rules for ad elements
        let selectorRule: [String: Any] = [
            "trigger": [
                "url-filter": ".*"
            ],
            "action": [
                "type": "css-display-none",
                "selector": advancedSelectors.joined(separator: ", ")
            ]
        ]
        rules.append(selectorRule)
        
        // YouTube specific rules
        if enhancedYouTubeBlocking {
            rules.append(contentsOf: youtubeAdBlocker.generateRules())
        }
        
        // Content Rule Lists expect a direct array, not wrapped in a "rules" object
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: rules, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "[]"
        } catch {
            print("AIPrivacyManager: Error generating rules JSON: \(error)")
            return "[]"
        }
    }
    
    private func injectAdvancedBlockingScript(into webView: WKWebView) {
        let script = """
        // AI-Powered Content Blocker - ENHANCED YOUTUBE AD BLOCKING
        (function() {
            let blockedItemsCount = 0;
            let lastBlockTime = 0;
            let debounceDelay = 500; // Reduced to 500ms for faster blocking
            
            console.log('🛡️ AIPrivacy: Enhanced ad blocker initialized on', window.location.hostname);
            
            // Report blocked content to native app with debouncing
            function reportBlock(element, reason, url = '') {
                const now = Date.now();
                
                // Debounce to prevent spam blocking
                if (now - lastBlockTime < debounceDelay) {
                    return; // Skip if blocking too frequently
                }
                
                lastBlockTime = now;
                blockedItemsCount++;
                
                try {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.adBlocker) {
                        window.webkit.messageHandlers.adBlocker.postMessage({
                            type: 'blocked',
                            reason: reason,
                            url: url || window.location.href,
                            element: element.tagName || 'unknown',
                            className: element.className || '',
                            timestamp: now
                        });
                        console.log('🛡️ AIPrivacy: Successfully blocked', reason, 'on', window.location.hostname);
                    } else {
                        console.log('🚨 AIPrivacy: Message handler not available for reporting block');
                    }
                } catch (e) {
                    console.log('🚨 AIPrivacy: Error reporting block:', e);
                }
            }
            
            // Test message handler on load
            function testMessageHandler() {
                try {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.adBlocker) {
                        window.webkit.messageHandlers.adBlocker.postMessage({
                            type: 'test',
                            message: 'Ad blocker script loaded successfully',
                            url: window.location.href,
                            timestamp: Date.now()
                        });
                        console.log('✅ AIPrivacy: Message handler test sent');
                    } else {
                        console.log('❌ AIPrivacy: Message handler not found during test');
                    }
                } catch (e) {
                    console.log('❌ AIPrivacy: Message handler test failed:', e);
                }
            }
            
            // ENHANCED YouTube Ad Blocking - PRECISION TARGETING
            function blockYouTubeAds() {
                let blockedCount = 0;
                
                // PROTECTED ZONES - NEVER touch these elements
                const isProtectedElement = (element) => {
                    if (!element) return true;
                    
                    // NEVER block the main video player or essential UI
                    const protectedSelectors = [
                        'input', 'textarea', 'form', 'button',
                        '#masthead', '#search', '.search-container', 
                        '#masthead-search', '[role="search"]',
                        '.ytd-searchbox', '#search-form',
                        '.navigation', '.sidebar', '.menu',
                        '#voice-search-button', '.ytd-topbar-menu-button-renderer',
                        // CRITICAL: Protect main video player and controls
                        '.html5-video-player', '.video-stream', '.ytp-chrome-bottom',
                        '.ytp-progress-bar', '.ytp-play-button', '.ytp-volume-area',
                        '.ytp-time-display', '.ytp-chrome-controls', '.ytp-gradient-bottom'
                    ];
                    
                    return element.closest(protectedSelectors.join(',')) !== null;
                };
                
                // Check if element is actually the main video player
                const isMainVideoPlayer = (element) => {
                    return element.classList.contains('html5-video-player') ||
                           element.tagName === 'VIDEO' ||
                           element.id === 'player' ||
                           element.classList.contains('video-stream');
                };
                
                try {
                    console.log('🔍 Starting YouTube ad detection cycle...');
                    
                    // 1. ULTRA-AGGRESSIVE VIDEO AD DETECTION - Multiple strategies
                    const videoElement = document.querySelector('video.html5-main-video, video.video-stream, video');
                    const player = document.querySelector('.html5-video-player, .ytp-player-container, #player-container, #movie_player');
                    
                    console.log('📹 Video element found:', !!videoElement);
                    console.log('🎮 Player element found:', !!player);
                    
                    if (videoElement && player) {
                        // CRITICAL: Check if this is actually an ad video playing
                        const videoSrc = videoElement.src || videoElement.currentSrc || '';
                        const isAdVideo = videoSrc.includes('googleadservices') || 
                                         videoSrc.includes('doubleclick') ||
                                         videoSrc.includes('/ad_status');
                                         
                        if (isAdVideo) {
                            console.log('🚨 CRITICAL AD DETECTED: Ad video source found!', videoSrc);
                            
                            // IMMEDIATELY skip to end
                            try {
                                if (videoElement.duration && !isNaN(videoElement.duration)) {
                                    videoElement.currentTime = videoElement.duration - 0.1;
                                    console.log('⚡ INSTANT SKIP: Jumped ad to end');
                                    reportBlock(videoElement, 'youtube-ad-video-skip');
                                    blockedCount++;
                                }
                                
                                // Also mute and hide
                                videoElement.muted = true;
                                videoElement.volume = 0;
                                videoElement.style.setProperty('opacity', '0.1', 'important');
                                
                            } catch (e) {
                                console.log('Error instant-skipping ad video:', e);
                            }
                        }
                        
                        // Strategy 1: Check for ad-showing class
                        if (player.classList.contains('ad-showing')) {
                            console.log('🎯 AD DETECTED: ad-showing class found!');
                            reportBlock(player, 'youtube-ad-detected-class');
                            blockedCount++;
                            
                            // ENHANCED timing manipulation
                            try {
                                if (videoElement.duration && videoElement.currentTime !== undefined) {
                                    const currentTime = videoElement.currentTime;
                                    const duration = videoElement.duration;
                                    console.log(`⏰ Ad timing: ${currentTime}/${duration}`);
                                    
                                    // More aggressive skipping for any ad duration
                                    if (duration > 1) {
                                        videoElement.currentTime = Math.max(duration - 0.5, duration * 0.99);
                                        console.log('⏩ Advanced ad playback to trigger skip');
                                        
                                        // Also speed up
                                        videoElement.playbackRate = 16;
                                        
                                        reportBlock(player, 'youtube-ad-time-skip');
                                        blockedCount++;
                                    }
                                }
                            } catch (e) {
                                console.log('Error manipulating ad time:', e);
                            }
                        }
                        
                        // Strategy 2: Check for ANY ad-related classes
                        const adClasses = ['ad-interrupting', 'ad-playing', 'ad-created', 'ad-started', 'playing-ad', 'has-ad'];
                        for (const adClass of adClasses) {
                            if (player.classList.contains(adClass)) {
                                console.log(`🎯 AD DETECTED: ${adClass} class found!`);
                                
                                // Immediate aggressive action
                                try {
                                    if (videoElement.duration > 1) {
                                        videoElement.currentTime = videoElement.duration - 0.1;
                                        videoElement.playbackRate = 16;
                                        videoElement.muted = true;
                                    }
                                } catch (e) {
                                    console.log('Error skipping ad:', e);
                                }
                                
                                reportBlock(player, 'youtube-ad-' + adClass);
                                blockedCount++;
                            }
                        }
                        
                        // Strategy 3: Enhanced ad text detection with ULTRA-AGGRESSIVE video manipulation
                        const adIndicators = document.querySelectorAll('.ytp-ad-text, .ytp-ad-duration-remaining, .ytp-ad-preview-text, .ytp-ad-simple-ad-badge, [class*="ad-text"], [class*="ad-badge"]');
                        if (adIndicators.length > 0) {
                            console.log(`🎯 AD DETECTED: ${adIndicators.length} ad text indicators found!`);
                            adIndicators.forEach(indicator => {
                                console.log('📝 Ad text:', indicator.textContent);
                                
                                // IMMEDIATE ULTRA-AGGRESSIVE ACTION when ad text is detected
                                const text = indicator.textContent?.toLowerCase() || '';
                                if (text.includes('ad')) {
                                    console.log('🚨 ULTRA-AGGRESSIVE MODE: Ad text detected, taking immediate action');
                                    
                                    try {
                                        // INSTANTLY skip any video with ANY duration
                                        if (videoElement && videoElement.duration > 0) {
                                            videoElement.currentTime = Math.max(videoElement.duration - 0.5, videoElement.duration * 0.98);
                                            videoElement.playbackRate = 16;
                                            videoElement.muted = true;
                                            videoElement.volume = 0;
                                            console.log('⚡ INSTANT SKIP: Video time manipulated');
                                        }
                                        
                                        // IMMEDIATELY click any skip buttons visible
                                        const skipBtns = document.querySelectorAll('.ytp-ad-skip-button, .ytp-skip-ad-button, [class*="skip"]');
                                        skipBtns.forEach(btn => {
                                            if (btn && btn.offsetParent && !btn.disabled) {
                                                btn.click();
                                                console.log('🚀 INSTANT SKIP: Clicked skip button');
                                            }
                                        });
                                        
                                        // HIDE ad overlays immediately
                                        const adOverlays = document.querySelectorAll('.ytp-ad-overlay-container, .ytp-ad-text-overlay, [class*="ad-overlay"]');
                                        adOverlays.forEach(overlay => {
                                            overlay.style.setProperty('display', 'none', 'important');
                                            overlay.style.setProperty('visibility', 'hidden', 'important');
                                            overlay.style.setProperty('opacity', '0', 'important');
                                        });
                                        
                                    } catch (e) {
                                        console.log('Error in ultra-aggressive blocking:', e);
                                    }
                                }
                                
                                reportBlock(indicator, 'youtube-ad-text-indicator');
                                blockedCount++;
                            });
                        }
                        
                        // Strategy 4: Check for YouTube's internal ad state
                        try {
                            const ytPlayer = window.yt?.player?.getPlayerByElement?.(player);
                            if (ytPlayer && ytPlayer.getPlayerState && ytPlayer.getPlayerState() !== undefined) {
                                const state = ytPlayer.getPlayerState();
                                console.log('🎮 YouTube player state:', state);
                                
                                // If playing and duration is short (typical ad), skip
                                if (state === 1 && videoElement.duration > 0 && videoElement.duration <= 120) { // Playing state and short duration
                                    console.log('🚨 POTENTIAL AD: Short duration video playing');
                                    try {
                                        videoElement.currentTime = videoElement.duration - 0.1;
                                        reportBlock(player, 'youtube-ad-short-duration');
                                        blockedCount++;
                                    } catch (e) {
                                        console.log('Error skipping short video:', e);
                                    }
                                }
                            }
                        } catch (e) {
                            console.log('Error accessing YouTube player API:', e);
                        }
                        
                    } else {
                        console.log('❌ No video/player elements found for ad detection');
                    }
                    
                    // 2. SPECIFIC AD OVERLAY BLOCKING - Only overlays, never the player
                    const specificAdOverlays = [
                        '.ytp-ad-overlay-container',     // Video overlay ads
                        '.ytp-ad-text-overlay',          // Text overlays on video  
                        '.ytp-ad-image-overlay',         // Image overlays on video
                        '.ytp-ad-player-overlay-instream-info', // Specific ad info overlays
                        '.ytp-ad-overlay-close-button',  // Ad overlay close buttons
                        '.ytp-ad-persistent-progress-bar-container', // Ad progress bars
                        '.ytp-ad-action-interstitial',   // Ad action overlays
                        '.ytp-ad-text',                  // Ad text elements
                        '.ytp-ad-preview-image',         // Ad preview images
                        '.ytp-ad-visit-advertiser-button' // Visit advertiser buttons
                    ];
                    
                    specificAdOverlays.forEach(selector => {
                        try {
                            document.querySelectorAll(selector).forEach(overlay => {
                                if (overlay && 
                                    overlay.offsetParent !== null && 
                                    !isProtectedElement(overlay) &&
                                    !isMainVideoPlayer(overlay)) {
                                    
                                    overlay.style.setProperty('display', 'none', 'important');
                                    overlay.style.setProperty('visibility', 'hidden', 'important');
                                    overlay.style.setProperty('opacity', '0', 'important');
                                    reportBlock(overlay, 'youtube-video-ad-overlay');
                                    blockedCount++;
                                    console.log('🎯 Blocked ad overlay:', selector);
                                }
                            });
                        } catch (e) {
                            console.log('Error with overlay selector', selector, e);
                        }
                    });
                
                    // 3. ULTRA-AGGRESSIVE SKIP BUTTON DETECTION & CLICKING
                    console.log('🔍 Searching for skip buttons...');
                    
                    // All possible skip button selectors
                    const skipSelectors = [
                        '.ytp-ad-skip-button',
                        '.ytp-skip-ad-button',
                        '.ytp-ad-skip-button-container button',
                        '.ytp-ad-skip-button-modern',
                        '.ytp-ad-skip-button-slot',
                        'button[class*="skip"]',
                        'button[id*="skip"]',
                        '[aria-label*="Skip"]',
                        '[aria-label*="skip"]',
                        'button[aria-label*="Skip"]',
                        'button[aria-label*="skip"]',
                        '.skip-button',
                        '.skipButton',
                        '#skip-button',
                        'button.ytp-button',
                        '.ytp-button[aria-label*="skip"]'
                    ];
                    
                    let skipButtonsFound = 0;
                    
                    skipSelectors.forEach(selector => {
                        try {
                            const elements = document.querySelectorAll(selector);
                            console.log(`🔍 Found ${elements.length} elements with selector: ${selector}`);
                            
                            elements.forEach(element => {
                                if (!element || !element.offsetParent || isProtectedElement(element)) return;
                                
                                const text = element.textContent?.toLowerCase() || '';
                                const ariaLabel = element.getAttribute('aria-label')?.toLowerCase() || '';
                                const className = element.className || '';
                                
                                // Check if it's actually a skip button
                                const isSkipButton = 
                                    text.includes('skip') || 
                                    ariaLabel.includes('skip') ||
                                    className.includes('skip') ||
                                    selector.includes('skip');
                                
                                if (isSkipButton && !element.disabled) {
                                    skipButtonsFound++;
                                    console.log(`⏭️ SKIP BUTTON FOUND: ${selector}`, {
                                        text: text,
                                        ariaLabel: ariaLabel,
                                        className: className
                                    });
                                    
                                    // Click immediately
                                    try {
                                        element.click();
                                        reportBlock(element, 'youtube-ad-skipped');
                                        blockedCount++;
                                        console.log('✅ Successfully clicked skip button!');
                                    } catch (clickError) {
                                        console.log('❌ Error clicking skip button:', clickError);
                                    }
                                }
                            });
                        } catch (e) {
                            console.log('Error with skip selector', selector, e);
                        }
                    });
                    
                    console.log(`🎯 Total skip buttons found and processed: ${skipButtonsFound}`);
                    
                    // 4. FEED AD BLOCKING - Safe feed-level ads only
                    const safeFeedAdSelectors = [
                        'ytd-promoted-sparkles-web-renderer',
                        'ytd-display-ad-renderer',
                        'ytd-promoted-video-renderer:not(.ytd-rich-item-renderer)', // Avoid blocking regular videos
                        'ytd-compact-promoted-video-renderer',
                        'ytd-in-feed-ad-layout-renderer',
                        'ytd-ad-slot-renderer',
                        '.masthead-ad:not(#masthead)', // Avoid header itself
                        '[data-ad-slot-id]:not(.html5-video-player)', // Avoid player
                        '.ytd-banner-promo-renderer-background'
                    ];
                    
                    safeFeedAdSelectors.forEach(selector => {
                        try {
                            document.querySelectorAll(selector).forEach(feedAd => {
                                if (feedAd && 
                                    feedAd.offsetParent !== null && 
                                    !isProtectedElement(feedAd) &&
                                    !isMainVideoPlayer(feedAd)) {
                                    
                                    feedAd.style.setProperty('display', 'none', 'important');
                                    feedAd.style.setProperty('visibility', 'hidden', 'important');
                                    reportBlock(feedAd, 'youtube-feed-ad');
                                    blockedCount++;
                                    console.log('📰 Blocked feed ad:', selector);
                                }
                            });
                        } catch (e) {
                            console.log('Error with feed ad selector', selector, e);
                        }
                    });
                    
                    // 5. IFRAME AD BLOCKING - External ad iframes only
                    const adIframes = document.querySelectorAll(`
                        iframe[src*="doubleclick"]:not([src*="youtube.com"]),
                        iframe[src*="googlesyndication"]:not([src*="youtube.com"]),
                        iframe[src*="googleads"]:not([src*="youtube.com"])
                    `);
                    adIframes.forEach(iframe => {
                        if (!isProtectedElement(iframe) && !isMainVideoPlayer(iframe)) {
                            iframe.style.setProperty('display', 'none', 'important');
                            reportBlock(iframe, 'youtube-iframe-ad');
                            blockedCount++;
                            console.log('🖼️ Blocked external ad iframe');
                        }
                    });
                    
                    // 6. COMPANION/BANNER ADS - Very specific targeting
                    const companionAdSelectors = [
                        '.companion-ad:not(.html5-video-player)', // Avoid player
                        '.display-ad-container:not(#player)',     // Avoid player container
                        '#watch-sidebar-ads .promoted-sparkles', // Sidebar only
                        '.ytd-rich-shelf-renderer[is-ad]',       // Ad shelves
                        '.ytd-statement-banner-renderer'         // Statement banners
                    ];
                    
                    companionAdSelectors.forEach(selector => {
                        try {
                            document.querySelectorAll(selector).forEach(companionAd => {
                                if (companionAd && 
                                    companionAd.offsetParent !== null && 
                                    !isProtectedElement(companionAd) &&
                                    !isMainVideoPlayer(companionAd)) {
                                    
                                    companionAd.style.setProperty('display', 'none', 'important');
                                    reportBlock(companionAd, 'youtube-companion-ad');
                                    blockedCount++;
                                    console.log('📊 Blocked companion ad:', selector);
                                }
                            });
                        } catch (e) {
                            console.log('Error with companion ad selector', selector, e);
                        }
                    });
                    
                    // 7. AD PROGRESS INDICATORS - Remove visual ad progress only
                    const adProgressSelectors = [
                        '.ytp-ad-duration-remaining',
                        '.ytp-ad-preview-text',
                        '.ytp-ad-simple-ad-badge'
                    ];
                    
                    adProgressSelectors.forEach(selector => {
                        try {
                            document.querySelectorAll(selector).forEach(indicator => {
                                if (indicator && !isProtectedElement(indicator)) {
                                    indicator.style.setProperty('opacity', '0', 'important');
                                    // Don't hide completely to avoid breaking functionality
                                    console.log('🔇 Hidden ad indicator:', selector);
                                }
                            });
                        } catch (e) {
                            console.log('Error with ad indicator', selector, e);
                        }
                    });
                    
                } catch (e) {
                    console.log('🚨 AIPrivacy: Error in YouTube ad blocking:', e);
                }
                
                if (blockedCount > 0) {
                    console.log(`🎯 YouTube: Blocked ${blockedCount} ads/elements this cycle`);
                }
                
                return blockedCount;
            }
            
            // ENHANCED general ad blocker - More comprehensive
            function blockGeneralAds() {
                let blockedCount = 0;
                
                // Comprehensive ad selectors
                const adSelectors = [
                    '.adsbygoogle',
                    '.ad-container',
                    '.advertisement',
                    '.ads-container',
                    '[data-ad-slot]',
                    '.google-ad',
                    '.sponsored-content',
                    '.native-ad',
                    '#google_ads_iframe',
                    '.ad-banner',
                    '.display-ad'
                ];
                
                adSelectors.forEach(selector => {
                    try {
                        document.querySelectorAll(selector).forEach(el => {
                            // Only if it's clearly an ad and not in any interactive area
                            if (el && el.offsetParent !== null && 
                                !el.closest('input, textarea, form, button, [role="search"], #search, #masthead, .navigation, .search-container')) {
                                el.style.setProperty('display', 'none', 'important');
                                reportBlock(el, 'general-ad');
                                blockedCount++;
                                console.log('🚫 Blocked general ad:', selector);
                            }
                        });
                    } catch (e) {
                        console.log('AIPrivacy: Error with selector', selector, e);
                    }
                });
                
                return blockedCount;
            }
            
            // Enhanced tracker blocker
            function blockTrackers() {
                let blockedCount = 0;
                
                // Block tracking pixels, beacons, and analytics
                const trackingSelectors = [
                    'img[src*="analytics"]',
                    'img[src*="tracking"]', 
                    'img[width="1"][height="1"]',
                    'img[src*="doubleclick"]',
                    'img[src*="google-analytics"]',
                    'img[src*="facebook.com/tr"]',
                    'img[src*="scorecardresearch"]'
                ];
                
                trackingSelectors.forEach(selector => {
                    try {
                        document.querySelectorAll(selector).forEach(img => {
                            img.style.setProperty('display', 'none', 'important');
                            reportBlock(img, 'tracking-pixel');
                            blockedCount++;
                            console.log('👁️ Blocked tracker:', selector);
                        });
                    } catch (e) {
                        console.log('Error blocking tracker', selector, e);
                    }
                });
                
                // Block social widgets and trackers
                const socialSelectors = [
                    '.fb-like', '.twitter-tweet', '.linkedin-widget', 
                    '.social-share', '.addthis', '.sharethis'
                ];
                
                socialSelectors.forEach(selector => {
                    try {
                        document.querySelectorAll(selector).forEach(widget => {
                            if (widget.offsetParent !== null) {
                                widget.style.setProperty('display', 'none', 'important');
                                reportBlock(widget, 'social-widget');
                                blockedCount++;
                                console.log('📱 Blocked social widget:', selector);
                            }
                        });
                    } catch (e) {
                        console.log('Error blocking social widget', selector, e);
                    }
                });
                
                return blockedCount;
            }
            
            // Main blocking function
            function runAIBlocker() {
                try {
                    let totalBlocked = 0;
                    
                    console.log('🔍 AIPrivacy: Running ad blocker on', window.location.hostname);
                    
                    if (window.location.hostname.includes('youtube.com')) {
                        const ytBlocked = blockYouTubeAds();
                        totalBlocked += ytBlocked;
                        if (ytBlocked > 0) {
                            console.log(`🎯 YouTube: Blocked ${ytBlocked} ads this cycle`);
                        }
                    }
                    
                    const generalBlocked = blockGeneralAds();
                    const trackersBlocked = blockTrackers();
                    totalBlocked += generalBlocked + trackersBlocked;
                    
                    if (totalBlocked > 0) {
                        console.log(`🛡️ AIPrivacy: Total blocked ${totalBlocked} items on ${window.location.hostname}`);
                        
                        // Send analytics update
                        try {
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.adBlocker) {
                                window.webkit.messageHandlers.adBlocker.postMessage({
                                    type: 'analytics-update',
                                    totalBlocked: blockedItemsCount,
                                    thisRun: totalBlocked,
                                    url: window.location.href,
                                    timestamp: Date.now()
                                });
                            }
                        } catch (e) {
                            console.log('Error sending analytics update:', e);
                        }
                    }
                } catch (e) {
                    console.log('🚨 AIPrivacy: Error in runAIBlocker:', e);
                }
            }
            
            // Initialize blocking and test message handler
            testMessageHandler();
            
            // IMMEDIATE YouTube ad blocking - run instantly
            if (window.location.hostname.includes('youtube.com')) {
                console.log('🚀 IMMEDIATE YouTube ad blocking started');
                runAIBlocker();
                
                // Run again very quickly for early ads
                setTimeout(() => {
                    console.log('🚀 Early YouTube follow-up blocking');
                    runAIBlocker();
                }, 100);
                
                setTimeout(() => {
                    console.log('🚀 Quick YouTube follow-up blocking');
                    runAIBlocker();
                }, 500);
            }
            
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', () => {
                    console.log('📄 DOMContentLoaded - initializing blocker');
                    runAIBlocker();
                    
                    // Extra YouTube runs after DOM loaded
                    if (window.location.hostname.includes('youtube.com')) {
                        setTimeout(runAIBlocker, 200);
                        setTimeout(runAIBlocker, 800);
                    }
                });
            } else {
                console.log('📄 Document ready - initializing blocker immediately');
                runAIBlocker();
                
                // Extra immediate runs for YouTube
                if (window.location.hostname.includes('youtube.com')) {
                    setTimeout(runAIBlocker, 50);
                    setTimeout(runAIBlocker, 300);
                }
            }
            
            // ENHANCED mutation observer - Watch for new ads
            const observer = new MutationObserver(function(mutations) {
                let shouldCheckAds = false;
                
                mutations.forEach(mutation => {
                    if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
                        for (let node of mutation.addedNodes) {
                            if (node.nodeType === 1) {
                                const className = node.className || '';
                                const tagName = node.tagName || '';
                                
                                // Check for ad-related classes or elements
                                if (className.includes('ad') || 
                                    className.includes('promoted') ||
                                    className.includes('sponsor') ||
                                    tagName === 'IFRAME' ||
                                    node.querySelector && (
                                        node.querySelector('.ad') ||
                                        node.querySelector('[data-ad-slot]') ||
                                        node.querySelector('.ytp-ad-overlay')
                                    )) {
                                    shouldCheckAds = true;
                                    console.log('🔄 Detected new ad element, triggering check');
                                    break;
                                }
                            }
                        }
                    }
                });
                
                // Run blocker if new ads detected
                if (shouldCheckAds) {
                    setTimeout(runAIBlocker, 200); // Quick response to new ads
                }
            });
            
            // Observe the entire document for ad insertions
            try {
                observer.observe(document.body || document.documentElement, {
                childList: true,
                    subtree: true,
                    attributes: false
            });
                console.log('👀 Mutation observer started');
            } catch (e) {
                console.log('Error starting mutation observer:', e);
            }
            
            // ULTRA-AGGRESSIVE YouTube monitoring - Maximum frequency
            if (window.location.hostname.includes('youtube.com')) {
                console.log('🎬 YouTube detected - starting ULTRA-AGGRESSIVE monitoring');
                
                                    // ULTRA-AGGRESSIVE blocking - check every 50ms on video pages for maximum responsiveness
                const blockingInterval = window.location.pathname.includes('/watch') ? 50 : 500;
                const youtubeInterval = setInterval(() => {
                    const blocked = blockYouTubeAds();
                    if (blocked > 0) {
                        console.log(`🎯 Ultra-aggressive check result: ${blocked} ads processed`);
                    }
                    
                    // Additional immediate skip attempt with enhanced detection
                    if (window.location.pathname.includes('/watch')) {
                        // ENHANCED skip button search with more patterns
                        const skipButtons = document.querySelectorAll(`
                            .ytp-ad-skip-button, .ytp-skip-ad-button, 
                            button[aria-label*="Skip"], button[aria-label*="skip"],
                            .skip-button, .skipButton, #skip-button,
                            button[class*="skip"], button[id*="skip"],
                            .ytp-ad-skip-button-container button,
                            [class*="skip-ad"], [aria-label*="Skip ad"],
                            button:contains("Skip"), button:contains("Skip ad")
                        `);
                        
                        skipButtons.forEach(btn => {
                            if (btn && btn.offsetParent && !btn.disabled) {
                                try {
                                    btn.click();
                                    console.log('🚀 ULTRA-AGGRESSIVE: Clicked skip button');
                                } catch (e) {}
                            }
                        });
                        
                        // ENHANCED video element checking with multiple ad indicators
                        const videoElements = document.querySelectorAll('video');
                        videoElements.forEach(video => {
                            if (video.duration > 0 && video.currentTime < video.duration) {
                                const src = video.src || video.currentSrc || '';
                                
                                // Multiple ad detection strategies
                                const isAdVideo = src.includes('googleadservices') || 
                                                src.includes('doubleclick') ||
                                                src.includes('googlesyndication') ||
                                                src.includes('/ads/') ||
                                                (video.duration <= 90 && document.querySelector('.ytp-ad-text')) ||
                                                document.querySelector('.ad-showing') ||
                                                document.querySelector('[class*="ad-text"]');
                                
                                if (isAdVideo) {
                                    try {
                                        video.currentTime = Math.max(video.duration - 0.3, video.duration * 0.99);
                                        video.playbackRate = 16;
                                        video.muted = true;
                                        video.volume = 0;
                                        console.log('⚡ ENHANCED AD SKIP: Multiple indicators detected');
                                    } catch (e) {}
                                }
                            }
                        });
                        
                        // AGGRESSIVE ad overlay hiding
                        const adElements = document.querySelectorAll(`
                            .ytp-ad-overlay-container,
                            .ytp-ad-text-overlay,
                            .ytp-ad-image-overlay,
                            [class*="ad-overlay"],
                            [class*="ad-banner"],
                            .ytp-ad-text,
                            .ytp-ad-duration-remaining
                        `);
                        
                        adElements.forEach(el => {
                            if (el && el.offsetParent) {
                                el.style.setProperty('display', 'none', 'important');
                                el.style.setProperty('visibility', 'hidden', 'important');
                                el.style.setProperty('opacity', '0', 'important');
                            }
                        });
                    }
                }, blockingInterval);
                
                // IMMEDIATE video event monitoring - Listen for all video changes
                console.log('🎥 Setting up IMMEDIATE video event listeners...');
                const setupVideoListeners = () => {
                    const videos = document.querySelectorAll('video');
                    videos.forEach(video => {
                        if (!video.adBlockerListenerAdded) {
                            console.log('📹 Adding aggressive listeners to video element');
                            
                            // Monitor every video event that could indicate an ad
                            ['loadstart', 'canplay', 'playing', 'play', 'loadeddata', 'loadedmetadata'].forEach(eventType => {
                                video.addEventListener(eventType, () => {
                                    console.log(`🚨 Video ${eventType} - immediate ad check`);
                                    
                                    // Immediate ad detection and skipping
                                    setTimeout(() => {
                                        const blocked = blockYouTubeAds();
                                        
                                        // Additional check for ad-like video
                                        const src = video.src || video.currentSrc || '';
                                        if ((src.includes('googleadservices') || src.includes('doubleclick') || 
                                             video.duration <= 90) && video.duration > 1) {
                                            try {
                                                video.currentTime = video.duration - 0.1;
                                                video.playbackRate = 16;
                                                video.muted = true;
                                                console.log('⚡ INSTANT SKIP on video event');
                                            } catch (e) {}
                                        }
                                    }, 10); // Very fast response
                                });
                            });
                            
                            // Monitor time updates for ongoing ad detection
                            video.addEventListener('timeupdate', () => {
                                // Fast ad detection during playback
                                if (video.duration > 0 && video.duration <= 90) {
                                    const src = video.src || video.currentSrc || '';
                                    if (src.includes('googleadservices') || src.includes('doubleclick')) {
                                        try {
                                            video.currentTime = video.duration - 0.1;
                                            video.playbackRate = 16;
                                        } catch (e) {}
                                    }
                                }
                            });
                            
                            video.adBlockerListenerAdded = true;
                        }
                    });
                };
                
                // Initial setup and ongoing monitoring for new videos
                setupVideoListeners();
                setInterval(setupVideoListeners, 1000); // Check for new videos every second
                
                // Monitor navigation to video pages
                let lastURL = window.location.href;
                const urlCheckInterval = setInterval(() => {
                    if (window.location.href !== lastURL) {
                        lastURL = window.location.href;
                        console.log('🔄 YouTube navigation detected:', window.location.pathname);
                        // Immediate blocking on navigation
                        setTimeout(() => {
                            console.log('🚀 Running immediate blocker after navigation');
                            runAIBlocker();
                        }, 500);
                        // Follow-up blocking
                        setTimeout(() => {
                            console.log('🚀 Running follow-up blocker after navigation');
                            runAIBlocker();
                        }, 2000);
            }
                }, 1000); // Check navigation every second
            }
            
            // Regular analytics reporting
            setInterval(() => {
                try {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.adBlocker) {
                        window.webkit.messageHandlers.adBlocker.postMessage({
                            type: 'heartbeat',
                            totalBlocked: blockedItemsCount,
                            url: window.location.href,
                            timestamp: Date.now()
                        });
                    }
                } catch (e) {
                    console.log('Error sending heartbeat:', e);
                }
            }, 15000); // Every 15 seconds
            
            // Periodic cleanup - less frequent for non-YouTube
            setInterval(() => {
                if (!window.location.hostname.includes('youtube.com')) {
                    const blocked = blockGeneralAds() + blockTrackers();
                    if (blocked > 0) {
                        console.log(`🧹 Periodic cleanup: blocked ${blocked} items`);
                    }
                }
            }, 20000); // Every 20 seconds for general sites
            
            console.log('✅ AIPrivacy: Enhanced ad blocker fully initialized');
            
        })();
        """
        
        let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(userScript)
        
        print("AIPrivacyManager: Injected enhanced blocking script with comprehensive YouTube ad blocking")
    }
    
    private func updateContentRules() {
        // Remove existing rules
        WKContentRuleListStore.default().removeContentRuleList(forIdentifier: "AIPrivacyRules") { [weak self] error in
            if let error = error {
                print("AIPrivacyManager: Error removing old rules: \(error)")
            }
            // Setup new rules
            self?.setupContentRules()
        }
    }
    
    private func setupNavigationTracking(for webView: WKWebView) {
        // Check if message handler already exists to prevent crash
        let userContentController = webView.configuration.userContentController
        
        // Remove existing handler if it exists (safe operation)
        userContentController.removeScriptMessageHandler(forName: "adBlocker")
        
        // Add fresh message handler for blocked content reporting
        userContentController.add(BlockedContentHandler(manager: self), name: "adBlocker")
        
        print("AIPrivacyManager: Navigation tracking configured with message handler")
    }
    
    private func startPerformanceMonitoring() {
        performanceOptimizer.startMonitoring { [weak self] metrics in
            DispatchQueue.main.async {
                self?.updatePerformanceMetrics(metrics)
            }
        }
    }
    
    private func updatePerformanceMetrics(_ metrics: PerformanceMetrics) {
        // Update UI with performance improvements from blocking
    }
    
    // MARK: - Content Blocking
    func reportBlockedContent(url: String, reason: BlockReason) {
        DispatchQueue.main.async {
            // Extract domain from URL
            let domain = URL(string: url)?.host ?? "unknown"
            
            // Create blocked item
            let blockedItem = BlockedItem(
                url: url,
                domain: domain,
                reason: reason,
                timestamp: Date()
            )
            
            // Update counts
            self.blockedCount += 1
            
            // Add to recent blocks (keep last 1000)
            self.recentBlocks.insert(blockedItem, at: 0)
            if self.recentBlocks.count > 1000 {
                self.recentBlocks.removeLast()
            }
            
            // Update last blocked domains
                if !self.lastBlockedDomains.contains(domain) {
                    self.lastBlockedDomains.insert(domain, at: 0)
                    if self.lastBlockedDomains.count > 10 {
                        self.lastBlockedDomains.removeLast()
                    }
                }
            
            // Immediately recalculate today/week counts
            let calendar = Calendar.current
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now)
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfDay
            
            self.todayBlockedCount = self.recentBlocks.filter { $0.timestamp >= startOfDay }.count
            self.weekBlockedCount = self.recentBlocks.filter { $0.timestamp >= startOfWeek }.count
            
            // Save statistics immediately for persistence
            self.saveStatistics()
            
            // Enhanced logging with detailed analytics
            let timestamp = DateFormatter().string(from: now)
            print("🛡️ AIPrivacyManager LIVE BLOCK: [\(timestamp)] \(reason.rawValue) from \(domain)")
            print("📊 Live Stats - Total: \(self.blockedCount) | Today: \(self.todayBlockedCount) | Week: \(self.weekBlockedCount)")
            
            // Track YouTube ad blocking specifically for monitoring
            if reason == .youtubeAd {
                let youtubeBlocks = self.recentBlocks.filter { $0.reason == .youtubeAd && $0.timestamp >= startOfDay }.count
                print("🎯 YouTube Ads Blocked Today: \(youtubeBlocks)")
            }
            
            // Real-time notification to UI (trigger refresh)
            self.objectWillChange.send()
        }
    }
    
    deinit {
        statisticsTimer?.invalidate()
    }
}

// MARK: - Supporting Classes

class BlockedContentHandler: NSObject, WKScriptMessageHandler {
    weak var manager: AIPrivacyManager?
    
    init(manager: AIPrivacyManager) {
        self.manager = manager
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { 
            print("❌ AIPrivacy MessageHandler: Invalid message format")
            return 
        }
        
        let timestamp = DateFormatter().string(from: Date())
        
        switch type {
        case "test":
            print("✅ AIPrivacy MessageHandler [\(timestamp)]: Test message received successfully")
            if let testMessage = body["message"] as? String {
                print("📝 Test message: \(testMessage)")
            }
            return
            
        case "heartbeat":
            if let totalBlocked = body["totalBlocked"] as? Int {
                print("💓 AIPrivacy Heartbeat [\(timestamp)]: Total blocked so far: \(totalBlocked)")
            }
            return
            
        case "analytics-update":
            if let totalBlocked = body["totalBlocked"] as? Int,
               let thisRun = body["thisRun"] as? Int {
                print("📊 AIPrivacy Analytics [\(timestamp)]: This run: \(thisRun), Total: \(totalBlocked)")
            }
            return
            
        case "blocked":
            break // Continue to handle blocked content below
            
        default:
            print("❓ AIPrivacy MessageHandler: Unknown message type: \(type)")
            return
        }
        
        // Handle blocked content
        let reasonString = body["reason"] as? String ?? "unknown"
        let url = body["url"] as? String ?? ""
        let elementClass = body["className"] as? String ?? ""
        
        let reason: AIPrivacyManager.BlockReason
        switch reasonString {
        // Enhanced YouTube ad blocking categories
        case "youtube-ad-container", "youtube-ad", "youtube-ad-skipped", "youtube-video-ad", 
             "youtube-video-ad-skip", "youtube-overlay-ad", "youtube-promoted", "youtube-promoted-removed",
             "youtube-ad-seeked", "youtube-ad-time-skipped", "youtube-ad-overlay-hidden",
             "youtube-ad-source-blocked", "youtube-ad-preload-blocked", "youtube-ad-animation-blocked",
             "youtube-iframe-ad", "youtube-companion-ad":
            reason = .youtubeAd
        case "general-ad":
            reason = .advertisement
        case "tracking-pixel":
            reason = .tracker
        case "social-widget":
            reason = .social
        default:
            reason = .aiDetected
        }
        
        // Enhanced logging for blocked content
        print("🔥 LIVE BLOCK [\(timestamp)]: \(reason.rawValue)")
        print("   📍 URL: \(url)")
        print("   🎯 Reason: \(reasonString)")
        if !elementClass.isEmpty {
            print("   🏷️ Element class: \(elementClass)")
        }
        
        manager?.reportBlockedContent(url: url, reason: reason)
    }
}

struct PerformanceMetrics {
    let pageLoadTime: Double
    let blockedRequests: Int
    let savedBandwidth: Int
}

class PerformanceOptimizer {
    func startMonitoring(callback: @escaping (PerformanceMetrics) -> Void) {
        // Implementation for performance monitoring
    }
}

class AIContentAnalysisEngine {
    func analyzeContent(_ content: String) -> [String] {
        // Implementation for AI content analysis
        return []
    }
}

class YouTubeAdBlocker {
    func configure(webView: WKWebView) {
        // YouTube-specific configuration
    }
    
    func generateRules() -> [[String: Any]] {
        return [
            // Block YouTube ad tracking and analytics
            [
                "trigger": [
                    "url-filter": "youtube\\.com/api/stats/ads",
                    "resource-type": ["raw"]
                ],
                "action": [
                    "type": "block"
                ]
            ],
            [
                "trigger": [
                    "url-filter": "youtube\\.com/ptracking",
                    "resource-type": ["raw"]
                ],
                "action": [
                    "type": "block"
                ]
            ],
            [
                "trigger": [
                    "url-filter": "youtube\\.com/youtubei/v1/log_event",
                    "resource-type": ["raw"]
                ],
                "action": [
                    "type": "block"
                ]
            ],
            // Block specific ad domains
            [
                "trigger": [
                    "url-filter": "doubleclick\\.net",
                    "resource-type": ["script", "raw", "image", "document"]
                ],
                "action": [
                    "type": "block"
                ]
            ],
            [
                "trigger": [
                    "url-filter": "googleads.*\\.doubleclick\\.net",
                    "resource-type": ["script", "raw", "image", "document"]
                ],
                "action": [
                    "type": "block"
                ]
            ],
            [
                "trigger": [
                    "url-filter": "googlesyndication\\.com",
                    "resource-type": ["script", "raw", "image"]
                ],
                "action": [
                    "type": "block"
                ]
            ],
            // Hide comprehensive ad containers with CSS - ULTRA-AGGRESSIVE
            [
                "trigger": [
                    "url-filter": "youtube\\.com"
                ],
                "action": [
                    "type": "css-display-none",
                    "selector": ".video-ads, .ytp-ad-module, .ytp-ad-overlay-container, .ytp-ad-text-overlay, .masthead-ad-control, #player-ads, ytd-display-ad-renderer, ytd-promoted-sparkles-web-renderer, .ytd-promoted-video-renderer, .ytd-compact-promoted-video-renderer, ytd-in-feed-ad-layout-renderer, ytd-ad-slot-renderer, .ytp-ad-player-overlay, .ytp-ad-player-overlay-instream, .ytp-ad-overlay, .ytp-ad-skip-button-container, .ytp-ad-button-container, .ytp-ad-overlay-close-button, .ytp-ad-overlay-image, .ytp-ad-display-container, .ytp-ad-visit-advertiser-button, .ytp-ad-clickthrough, div[class*=\"ytp-ad\"], div[id*=\"player_ads\"], .ad-container, .video-ads-overlay, ytd-rich-item-renderer[is-ad], ytd-compact-video-renderer[is-ad], ytd-video-renderer[is-ad], [overlay-style=\"DEFAULT\"][is-ad], .ytd-promoted-sparkles-text-search-renderer, div[data-ad-slot-id], .GoogleActiveViewElement, iframe[src*=\"doubleclick\"], iframe[src*=\"googleads\"]"
                ]
            ]
        ]
    }
} 