import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct iBrowsyApp: App {
    // Access the AppStorage value to pass to the commands
    @AppStorage("appColorScheme") private var selectedScheme: AppColorScheme = .light
    
    // Create ViewModels and Managers at the App level
    @StateObject private var webViewModel: WebViewModel
    @StateObject private var assistantViewModel: AssistantViewModel
    @StateObject private var bookmarkManager: BookmarkManager
    @StateObject private var citationManager: CitationManager


    // Environment to manage window presentation
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    


    init() {
        let webVM = WebViewModel()
        let bookmarkMgr = BookmarkManager() // Create BookmarkManager first
        // Pass WebViewModel and BookmarkManager to AssistantViewModel initializer
        let assistantVM = AssistantViewModel(webViewModel: webVM, bookmarkManager: bookmarkMgr)
        webVM.assistantViewModel = assistantVM // Link them

        _webViewModel = StateObject(wrappedValue: webVM)
        _assistantViewModel = StateObject(wrappedValue: assistantVM)
        _bookmarkManager = StateObject(wrappedValue: bookmarkMgr) // Use the created instance
        _citationManager = StateObject(wrappedValue: CitationManager())

        // Initialize the split-view analyzer for AI analysis
        webVM.initializeSplitViewAnalyzer(assistantViewModel: assistantVM)

        #if os(macOS)
        // Set up window focus change monitoring for auto-PiP
        setupWindowFocusMonitoring(webViewModel: webVM)
        #endif
    }

    #if os(macOS)
    private func setupWindowFocusMonitoring(webViewModel: WebViewModel) {
        // Clean up any problematic saved application state from previous crashes
        cleanupSavedApplicationState()
        
        // Monitor app losing focus for immediate PiP trigger
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Trigger immediately for instant PiP response
            Task { @MainActor in
                webViewModel.triggerAutoPiPOnFocusLoss()
            }
        }
        
        // Monitor app gaining focus to stop PiP and return to browser
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                webViewModel.handleBrowserReturnFocus()
            }
        }
        
        // Monitor window focus changes for more granular control
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let window = notification.object as? NSWindow,
               window.contentViewController?.view.subviews.contains(where: { $0 is NSHostingView<AppRootView> }) == true {
                Task { @MainActor in
                    webViewModel.handleBrowserReturnFocus()
                }
            }
        }
    }
    
    private func cleanupSavedApplicationState() {
        // Clear saved application state to prevent window restoration errors
        let bundleId = Bundle.main.bundleIdentifier ?? "com.dayanfernandez.iBrowsy"
        let savedStateURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Saved Application State")
            .appendingPathComponent("\(bundleId).savedState")
        
        if FileManager.default.fileExists(atPath: savedStateURL.path) {
            do {
                try FileManager.default.removeItem(at: savedStateURL)
            } catch {
                // Failed to clean up saved application state
            }
        }
    }
    #endif

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .background(
                    // EXACT same gorgeous liquid glass as Privacy window!
                                            Rectangle()
                            .fill(Color(red: 0.98, green: 0.98, blue: 1.0, opacity: 0.2))
                            .ignoresSafeArea()
                            .background(
                                VisualEffectView(material: .underPageBackground, blendingMode: .withinWindow)
                                    .ignoresSafeArea()
                            )
                )
                .onAppear {
                    setupTitlebarAppearance()
                }
                .onChange(of: selectedScheme) { _ in
                    setupTitlebarAppearance()
                }

                .environmentObject(webViewModel)
                .environmentObject(assistantViewModel)
                .environmentObject(bookmarkManager)
                .environmentObject(citationManager)

        }
        // Use the standard titled window style 
        .windowStyle(.hiddenTitleBar)
        // Add default window size and position
        .defaultSize(width: 1200, height: 800)
        .defaultPosition(.center)
        .windowResizability(.contentSize)
        // Add the commands modifier
        .commands { 
            AppearanceCommands(selectedScheme: $selectedScheme)
            
            // Add Analysis menu for split view analysis
            AnalysisCommands()
            
            // Add Options menu for settings
            CommandMenu("Options") {
                Button("Settings") {
                    openWindow(id: "settings")
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            // Add custom sidebar commands to replace the system menu item
            SidebarCommands()
        }
        
        // Create settings window
        Window("Settings", id: "settings") {
            SettingsView(assistantViewModel: assistantViewModel)
                .environmentObject(assistantViewModel) // Still provide as environment for consistency if SettingsView children use it
                // If SettingsView or its children need other managers, provide them here too
                // .environmentObject(bookmarkManager)
                // .environmentObject(citationManager)

        }
        .keyboardShortcut(",", modifiers: .command)
        .defaultPosition(.center)
        .defaultSize(width: 500, height: 500)
        .windowResizability(.contentSize)
    }
    
    // Function to configure the titlebar appearance
    private func setupTitlebarAppearance() {
        #if os(macOS)
        DispatchQueue.main.async {
            for window in NSApp.windows {
                // Apply titlebar appearance for light mode
                if let titlebar = window.standardWindowButton(.closeButton)?.superview?.superview {
                    // Use gorgeous liquid glass background for light mode
                    if let cgColor = Color(red: 0.95, green: 0.97, blue: 1.0, opacity: 0.25).cgColor, let nsColor = NSColor(cgColor: cgColor) {
                        titlebar.layer?.backgroundColor = nsColor.cgColor
                    }
                    
                    // Set window button colors for light background
                    window.standardWindowButton(.closeButton)?.contentTintColor = .darkGray
                    window.standardWindowButton(.miniaturizeButton)?.contentTintColor = .darkGray
                    window.standardWindowButton(.zoomButton)?.contentTintColor = .darkGray
                    
                    // Make the title bar height smaller 
                    window.toolbar?.sizeMode = .small
                    
                    // Attempt to reduce padding in the toolbar
                    if let toolbar = window.toolbar {
                        toolbar.displayMode = .iconOnly
                    }
                }
            }
        }
        #endif
    }
}

// MARK: - Visual Effect View for titlebar
#if os(macOS)
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// Extension to calculate color brightness
extension Color {
    var brightness: CGFloat {
        guard let components = NSColor(self).usingColorSpace(.sRGB)?.cgColor.components,
              components.count >= 3 else { return 0 }
        // Using standard luminance calculation
        return 0.299 * components[0] + 0.587 * components[1] + 0.114 * components[2]
    }
}
#endif

// MARK: - Appearance Commands

struct AppearanceCommands: Commands {
    @Binding var selectedScheme: AppColorScheme

    var body: some Commands {
        CommandMenu("Appearance") {
            Picker("Appearance", selection: $selectedScheme) {
                ForEach(AppColorScheme.allCases) { scheme in
                    Text(scheme.description).tag(scheme)
                }
            }
            .pickerStyle(.inline) // Use inline style for menu appearance
        }
    }
}

// MARK: - Analysis Commands

struct AnalysisCommands: Commands {
    var body: some Commands {
        CommandMenu("Analysis") {
            Button("Toggle Split View Analysis") {
                NotificationCenter.default.post(name: NSNotification.Name("ToggleSplitViewAnalysis"), object: nil)
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])
        }
    }
}

// MARK: - Sidebar Commands

struct SidebarCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .sidebar) {
            // Empty implementation to override system sidebar commands
            // The ContentView toolbar button already has a ⌘B shortcut assigned
        }
    }
}