import SwiftUI
import AppKit

class PrivacyWindow: NSWindow {
    
    init(privacyManager: AIPrivacyManager) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        // Configure window properties
        self.title = "AI Privacy & Security"
        self.isReleasedWhenClosed = false
        self.level = .floating
        self.isMovableByWindowBackground = true
        
        // Set minimum and maximum sizes
        self.minSize = NSSize(width: 600, height: 500)
        self.maxSize = NSSize(width: 1400, height: 1000)
        
        // Apply gorgeous liquid glass styling to the window
        if #available(macOS 11.0, *) {
            // Set the title bar to use gorgeous light liquid glass background
            self.titlebarAppearsTransparent = true
            self.backgroundColor = NSColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 0.25)
            
            // Make the title bar height smaller for cleaner look
            self.toolbar?.sizeMode = .small
            
            // Enhance window buttons visibility on light background
            self.standardWindowButton(.closeButton)?.contentTintColor = .darkGray
            self.standardWindowButton(.miniaturizeButton)?.contentTintColor = .darkGray
            self.standardWindowButton(.zoomButton)?.contentTintColor = .darkGray
        }
        
        // Create the SwiftUI content view
        let contentView = PrivacySettingsView()
            .environmentObject(privacyManager)
        
        // Set up the hosting view
        self.contentView = NSHostingView(rootView: contentView)
        
        // Center the window
        self.center()
    }
    
    func show() {
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
    }
    
    func hide() {
        orderOut(nil)
    }
}

// MARK: - Privacy Window Manager
@MainActor
class PrivacyWindowManager: ObservableObject {
    private var window: PrivacyWindow?
    
    func showPrivacyWindow(with privacyManager: AIPrivacyManager) {
        if window == nil {
            window = PrivacyWindow(privacyManager: privacyManager)
        }
        window?.show()
    }
    
    func hidePrivacyWindow() {
        window?.hide()
    }
}

// MARK: - Privacy Stats Window
class PrivacyStatsWindow: NSWindow {
    
    init(privacyManager: AIPrivacyManager) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        // Configure window properties
        self.title = "Privacy Statistics"
        self.isReleasedWhenClosed = false
        self.level = .floating
        self.isMovableByWindowBackground = true
        
        // Set minimum and maximum sizes
        self.minSize = NSSize(width: 600, height: 500)
        self.maxSize = NSSize(width: 1400, height: 1000)
        
        // Apply gorgeous liquid glass styling to the stats window
        if #available(macOS 11.0, *) {
            // Set the title bar to use gorgeous light liquid glass background
            self.titlebarAppearsTransparent = true
            self.backgroundColor = NSColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 0.25)
            
            // Make the title bar height smaller for cleaner look
            self.toolbar?.sizeMode = .small
            
            // Enhance window buttons visibility on light background
            self.standardWindowButton(.closeButton)?.contentTintColor = .darkGray
            self.standardWindowButton(.miniaturizeButton)?.contentTintColor = .darkGray
            self.standardWindowButton(.zoomButton)?.contentTintColor = .darkGray
        }
        
        // Create the SwiftUI content view
        let contentView = PrivacyStatsView(manager: privacyManager)
        
        // Set up the hosting view
        self.contentView = NSHostingView(rootView: contentView)
        
        // Center the window
        self.center()
    }
    
    func show() {
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
    }
    
    func hide() {
        orderOut(nil)
    }
}

@MainActor
class PrivacyStatsWindowManager: ObservableObject {
    static let shared = PrivacyStatsWindowManager()
    private var window: PrivacyStatsWindow?
    
    private init() {}
    
    func showStatsWindow(with privacyManager: AIPrivacyManager) {
        if window == nil {
            window = PrivacyStatsWindow(privacyManager: privacyManager)
        }
        window?.show()
    }
    
    func hideStatsWindow() {
        window?.hide()
    }
}

// MARK: - Advanced Privacy Settings Window
class AdvancedPrivacyWindow: NSWindow {
    
    init(privacyManager: AIPrivacyManager) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        // Configure window properties
        self.title = "Advanced Privacy Settings"
        self.isReleasedWhenClosed = false
        self.level = .floating
        self.isMovableByWindowBackground = true
        
        // Set minimum and maximum sizes
        self.minSize = NSSize(width: 600, height: 500)
        self.maxSize = NSSize(width: 1400, height: 1000)
        
        // Apply gorgeous liquid glass styling to the advanced window
        if #available(macOS 11.0, *) {
            // Set the title bar to use gorgeous light liquid glass background
            self.titlebarAppearsTransparent = true
            self.backgroundColor = NSColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 0.25)
            
            // Make the title bar height smaller for cleaner look
            self.toolbar?.sizeMode = .small
            
            // Enhance window buttons visibility on light background
            self.standardWindowButton(.closeButton)?.contentTintColor = .darkGray
            self.standardWindowButton(.miniaturizeButton)?.contentTintColor = .darkGray
            self.standardWindowButton(.zoomButton)?.contentTintColor = .darkGray
        }
        
        // Create the SwiftUI content view
        let contentView = AdvancedPrivacySettingsView(manager: privacyManager)
        
        // Set up the hosting view
        self.contentView = NSHostingView(rootView: contentView)
        
        // Center the window
        self.center()
    }
    
    func show() {
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
    }
    
    func hide() {
        orderOut(nil)
    }
}

@MainActor
class AdvancedPrivacyWindowManager: ObservableObject {
    static let shared = AdvancedPrivacyWindowManager()
    private var window: AdvancedPrivacyWindow?
    
    private init() {}
    
    func showAdvancedWindow(with privacyManager: AIPrivacyManager) {
        if window == nil {
            window = AdvancedPrivacyWindow(privacyManager: privacyManager)
        }
        window?.show()
    }
    
    func hideAdvancedWindow() {
        window?.hide()
    }
} 