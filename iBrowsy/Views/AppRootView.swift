import SwiftUI

struct AppRootView: View {
    @State private var showIntro: Bool = true  // Enable intro animation
    @State private var introComplete: Bool = false  // Start with intro
    
    // Access to shared view models (using the refactored structure)
    @EnvironmentObject private var webViewModel: WebViewModel
    @EnvironmentObject private var assistantViewModel: AssistantViewModel
    @EnvironmentObject private var bookmarkManager: BookmarkManager
    @EnvironmentObject private var citationManager: CitationManager
    
    var body: some View {
        ZStack {
            if showIntro && !introComplete {
                // Show the intro animation
                IntroAnimationView {
                    handleIntroComplete()
                }
                .zIndex(1)
                .transition(.asymmetric(
                    insertion: .identity,
                    removal: .opacity.combined(with: .scale(scale: 1.1))
                ))
            }
            
            if introComplete || !showIntro {
                // Show the main app content
                ContentView()
                    .zIndex(0)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .identity
                    ))
            }
        }
        .animation(.easeInOut(duration: 1.2), value: showIntro)
        .animation(.easeInOut(duration: 1.2), value: introComplete)
        .onAppear {
            checkIntroRequirement()
        }
    }
    
    private func handleIntroComplete() {
        withAnimation(.easeInOut(duration: 1.2)) {
            introComplete = true
            showIntro = false
        }
        
        // Set up the main app after intro
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            setupMainApp()
        }
    }
    
    private func checkIntroRequirement() {
        // Check if this is the first time running the app (you can modify this logic)
        let hasSeenIntro = UserDefaults.standard.bool(forKey: "hasSeenIntroAnimation")
        
        if !hasSeenIntro {
            // First time - show intro
            showIntro = true
            introComplete = false
            // Mark that we've shown the intro
            UserDefaults.standard.set(true, forKey: "hasSeenIntroAnimation")
        } else {
            // Already seen intro - skip to main content
            showIntro = false
            introComplete = true
            setupMainApp()
        }
    }
    
    private func setupMainApp() {
        // Setup main app immediately - no intro delay
        DispatchQueue.main.async {
            webViewModel.isShowingHomepage = true
        }
    }
}

#Preview {
    let webVM = WebViewModel()
    let bookmarkMgr = BookmarkManager()
    let assistantVM = AssistantViewModel(webViewModel: webVM, bookmarkManager: bookmarkMgr)
    
    AppRootView()
        .environmentObject(webVM)
        .environmentObject(assistantVM)
        .environmentObject(bookmarkMgr)
        .environmentObject(CitationManager())
} 