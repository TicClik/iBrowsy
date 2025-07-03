import SwiftUI
#if os(macOS)
import AppKit
#endif

struct SettingsView: View {
    // Access app user defaults through AppStorage
    @AppStorage("appColorScheme") private var selectedScheme: AppColorScheme = .light

    @AppStorage("defaultSearchProvider") private var defaultSearchProvider: SearchProvider = .duckDuckGo
    @AppStorage("defaultHomepageURL") private var defaultHomepageURL: String = ""
    @AppStorage("showBookmarksOnHomepage") private var showBookmarksOnHomepage: Bool = true
    @AppStorage("openai_api_key") private var openAIApiKey: String = ""
    
    // UI state for text fields
    @State private var homepageURLInput: String = ""
    @State private var apiKeyInput: String = ""
    @State private var showingApiKey: Bool = false
    
    // Tab selection
    @State private var selectedTab = 0
    
    // Reference to AssistantViewModel
    @ObservedObject var assistantViewModel: AssistantViewModel
    
    // Privacy Manager for AI Privacy settings
    @StateObject private var privacyManager = AIPrivacyManager()
    
    init(assistantViewModel: AssistantViewModel) {
        self.assistantViewModel = assistantViewModel
        homepageURLInput = defaultHomepageURL
    }
    
    var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                headerTabsView
                contentScrollView
            }
        }
        .onAppear {
            homepageURLInput = defaultHomepageURL
            apiKeyInput = openAIApiKey
        }
        .frame(minWidth: 500, minHeight: 500)
    }
    
    private var backgroundView: some View {
        Rectangle()
            .fill(LiquidGlassStyle.backgroundGlass)
            .ignoresSafeArea()
            .overlay(
                LinearGradient(
                    colors: [
                        Color.cyan.opacity(0.12),
                        Color.blue.opacity(0.08),
                        Color.purple.opacity(0.05),
                        Color.clear,
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
    }
    
    private var headerTabsView: some View {
        HStack(spacing: 8) {
            tabButton(text: "Appearance", index: 0)
            tabButton(text: "Browser", index: 1)
            tabButton(text: "Privacy", index: 2)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(LiquidGlassStyle.primaryGlass)
                .overlay(
                    Rectangle()
                        .fill(LiquidGlassStyle.subtleBorder)
                        .frame(height: 1)
                        .opacity(0.3), 
                    alignment: .bottom
                )
        )
    }
    
    private func tabButton(text: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                selectedTab = index
            }
        }) {
            Text(text)
                .font(.system(size: 14, weight: selectedTab == index ? .semibold : .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .foregroundColor(selectedTab == index ? .primary : .secondary)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selectedTab == index ? 
                      AnyShapeStyle(LiquidGlassStyle.accentGlass) : 
                      AnyShapeStyle(Color.clear))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(selectedTab == index ? 
                                    AnyShapeStyle(LiquidGlassStyle.primaryBorder) : 
                                    AnyShapeStyle(Color.clear), 
                                    lineWidth: 1)
                )
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTab)
    }
    
    private var contentScrollView: some View {
        ScrollView {
            VStack(spacing: 30) {
                switch selectedTab {
                case 0: // Appearance tab
                    appearanceSettings
                case 1: // Browser tab
                    browserSettings
                case 2: // Privacy tab
                    privacySettings
                default:
                    EmptyView()
                }
            }
            .padding(30)
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Settings Sections
    
    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 30) {
            // Section header with liquid glass styling
            HStack(spacing: 12) {
                Image(systemName: "paintbrush.fill")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan.opacity(0.9), .blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .font(.title2)
                
                Text("Theme Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.bottom, 10)
            
            // Glass card for theme settings
            VStack(alignment: .leading, spacing: 20) {
                Text("Color Scheme")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Scheme selection cards
                HStack(spacing: 15) {
                    ForEach(AppColorScheme.allCases) { scheme in
                        themeCard(for: scheme)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(LiquidGlassStyle.primaryGlass)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(LiquidGlassStyle.primaryBorder, lineWidth: 1)
                    )
            )
            .shadow(color: LiquidGlassStyle.lightShadow, radius: 15, x: 0, y: 5)
        }
    }
    
    private var browserSettings: some View {
        VStack(alignment: .leading, spacing: 30) {
            // Section header with liquid glass styling
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan.opacity(0.9), .blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .font(.title2)
                
                Text("Browser Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.bottom, 10)
            
            // Search section with liquid glass
            VStack(alignment: .leading, spacing: 20) {
                Text("Search Engine")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(spacing: 12) {
                    ForEach(SearchProvider.allCases) { provider in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                defaultSearchProvider = provider
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: defaultSearchProvider == provider ? "circle.fill" : "circle")
                                    .foregroundColor(defaultSearchProvider == provider ? .cyan : .secondary)
                                    .font(.title3)
                                
                                Text(provider.displayName)
                                    .foregroundColor(.primary)
                                    .font(.system(size: 15, weight: .medium))
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(defaultSearchProvider == provider ? 
                                          AnyShapeStyle(LiquidGlassStyle.accentGlass) : 
                                          AnyShapeStyle(LiquidGlassStyle.secondaryGlass))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(defaultSearchProvider == provider ? 
                                                        AnyShapeStyle(LiquidGlassStyle.primaryBorder) : 
                                                        AnyShapeStyle(LiquidGlassStyle.subtleBorder), 
                                                        lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(LiquidGlassStyle.primaryGlass)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(LiquidGlassStyle.primaryBorder, lineWidth: 1)
                    )
            )
            .shadow(color: LiquidGlassStyle.lightShadow, radius: 15, x: 0, y: 5)
            
            // AI Assistant Settings section with liquid glass
            VStack(alignment: .leading, spacing: 20) {
                Text("AI Assistant")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.wave.2")
                                .foregroundColor(.cyan)
                            Text("Text-to-Speech for AI Responses")
                                .foregroundColor(.primary)
                                .font(.system(size: 15, weight: .medium))
                        }
                        
                        Text("When enabled, the AI assistant will read its responses aloud.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 24)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $assistantViewModel.isTTSEnabledGlobally)
                        .tint(.cyan)
                        .scaleEffect(1.1)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(LiquidGlassStyle.primaryGlass)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(LiquidGlassStyle.primaryBorder, lineWidth: 1)
                    )
            )
            .shadow(color: LiquidGlassStyle.lightShadow, radius: 15, x: 0, y: 5)
            
            // Homepage section with liquid glass
            VStack(alignment: .leading, spacing: 20) {
                Text("Homepage")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "bookmark.fill")
                                .foregroundColor(.cyan)
                            Text("Show Bookmarks on Homepage")
                                .foregroundColor(.primary)
                                .font(.system(size: 15, weight: .medium))
                        }
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $showBookmarksOnHomepage)
                        .tint(.cyan)
                        .scaleEffect(1.1)
                }
                
                Divider()
                    .background(LiquidGlassStyle.subtleBorder)
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .foregroundColor(.cyan)
                        Text("Custom Homepage URL")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    HStack(spacing: 12) {
                        TextField("Enter homepage URL", text: $homepageURLInput)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(LiquidGlassStyle.secondaryGlass)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(LiquidGlassStyle.subtleBorder, lineWidth: 1)
                                    )
                            )
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                defaultHomepageURL = homepageURLInput
                            }
                        }) {
                            Text("Save")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            LinearGradient(
                                                colors: [.cyan.opacity(0.9), .blue.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(homepageURLInput == defaultHomepageURL)
                        .opacity(homepageURLInput == defaultHomepageURL ? 0.6 : 1.0)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(LiquidGlassStyle.primaryGlass)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(LiquidGlassStyle.primaryBorder, lineWidth: 1)
                    )
            )
            .shadow(color: LiquidGlassStyle.lightShadow, radius: 15, x: 0, y: 5)
            
            // OpenAI API Key section with liquid glass
            VStack(alignment: .leading, spacing: 20) {
                Text("OpenAI API Key")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "key.fill")
                                .foregroundColor(.cyan)
                            Text("Enter OpenAI API Key")
                                .foregroundColor(.primary)
                                .font(.system(size: 15, weight: .medium))
                        }
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $showingApiKey)
                        .tint(.cyan)
                        .scaleEffect(1.1)
                }
                
                Divider()
                    .background(LiquidGlassStyle.subtleBorder)
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("API Key (starts with 'sk-')")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Group {
                            if showingApiKey {
                                TextField("Enter OpenAI API Key", text: $apiKeyInput)
                            } else {
                                SecureField("Enter OpenAI API Key", text: $apiKeyInput)
                            }
                        }
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(LiquidGlassStyle.secondaryGlass)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(LiquidGlassStyle.subtleBorder, lineWidth: 1)
                                )
                        )
                        
                        Button(action: {
                            showingApiKey.toggle()
                        }) {
                            Image(systemName: showingApiKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                openAIApiKey = apiKeyInput
                            }
                        }) {
                            Text("Save")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            LinearGradient(
                                                colors: [.cyan.opacity(0.9), .blue.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(apiKeyInput == openAIApiKey)
                        .opacity(apiKeyInput == openAIApiKey ? 0.6 : 1.0)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(LiquidGlassStyle.primaryGlass)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(LiquidGlassStyle.primaryBorder, lineWidth: 1)
                    )
            )
            .shadow(color: LiquidGlassStyle.lightShadow, radius: 15, x: 0, y: 5)
        }
    }
    
    private var privacySettings: some View {
        VStack(alignment: .leading, spacing: 28) {
            // Privacy header with liquid glass styling
            VStack(spacing: 20) {
                HStack {
                    HStack(spacing: 12) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.title)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.9), Color.blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AI Privacy & Security")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("Advanced ad & tracker blocking with machine learning")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Stats display
                    Button(action: { }) {
                        VStack(spacing: 6) {
                            Text("\(privacyManager.blockedCount)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.cyan.opacity(0.9), Color.blue.opacity(0.8)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            
                            Text("Blocked Today")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(LiquidGlassStyle.accentGlass)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(LiquidGlassStyle.primaryBorder, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Status indicators
                HStack(spacing: 20) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(privacyManager.isEnabled ? Color.cyan.opacity(0.8) : Color.secondary.opacity(0.6))
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.6), lineWidth: 2)
                            )
                        
                        Text(privacyManager.isEnabled ? "Protection Active" : "Protection Disabled")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(privacyManager.isEnabled ? .cyan : .primary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.cyan)
                        Text("Performance: \(privacyManager.performanceMode.rawValue)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(LiquidGlassStyle.primaryGlass)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(LiquidGlassStyle.primaryBorder, lineWidth: 1)
                    )
            )
            .shadow(color: LiquidGlassStyle.lightShadow, radius: 15, x: 0, y: 8)
            
            // Privacy Controls
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(title: "Privacy Controls", systemImage: "shield.fill", color: .cyan)
                
                VStack(spacing: 16) {
                    ToggleRow(
                        title: "AI Privacy Protection",
                        subtitle: "Block ads and trackers using machine learning",
                        isOn: $privacyManager.isEnabled,
                        color: .cyan
                    )
                    
                    ToggleRow(
                        title: "Enhanced YouTube Blocking",
                        subtitle: "Block YouTube ads and sponsored content",
                        isOn: $privacyManager.enhancedYouTubeBlocking,
                        color: .cyan
                    )
                    
                    ToggleRow(
                        title: "AI Content Analysis",
                        subtitle: "Use AI to detect and block unwanted content",
                        isOn: $privacyManager.aiContentAnalysis,
                        color: .cyan
                    )
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(LiquidGlassStyle.primaryGlass)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(LiquidGlassStyle.primaryBorder, lineWidth: 1)
                    )
            )
            .shadow(color: LiquidGlassStyle.lightShadow, radius: 15, x: 0, y: 5)
            
            // Performance Mode
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(title: "Performance Mode", systemImage: "speedometer", color: .cyan)
                
                VStack(spacing: 12) {
                    ForEach(AIPrivacyManager.PerformanceMode.allCases, id: \.self) { mode in
                        PerformanceModeRow(
                            mode: mode,
                            isSelected: privacyManager.performanceMode == mode,
                            action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    privacyManager.performanceMode = mode
                                }
                            }
                        )
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(LiquidGlassStyle.primaryGlass)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(LiquidGlassStyle.primaryBorder, lineWidth: 1)
                    )
            )
            .shadow(color: LiquidGlassStyle.lightShadow, radius: 15, x: 0, y: 5)
            
            // Advanced Options
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(title: "Advanced Options", systemImage: "gearshape.fill", color: .cyan)
                
                VStack(spacing: 12) {
                    Button(action: { }) {
                        SettingsRow(
                            title: "Advanced Settings",
                            subtitle: "Configure detailed privacy and security options",
                            systemImage: "slider.horizontal.3",
                            color: .cyan
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider()
                        .background(LiquidGlassStyle.subtleBorder)
                    
                    Button(action: clearBlockingData) {
                        SettingsRow(
                            title: "Clear Blocking Data",
                            subtitle: "Reset all blocking statistics and cached data",
                            systemImage: "trash",
                            color: .red
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(LiquidGlassStyle.primaryGlass)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(LiquidGlassStyle.primaryBorder, lineWidth: 1)
                    )
            )
            .shadow(color: LiquidGlassStyle.lightShadow, radius: 15, x: 0, y: 5)
        }
    }
    
    // MARK: - Helper Views
    
    private func themeCard(for scheme: AppColorScheme) -> some View {
        let isSelected = selectedScheme == scheme
        
        return Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                selectedScheme = scheme
            }
        }) {
            HStack(spacing: 12) {
                // Compact theme preview
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected ? 
                        LiquidGlassStyle.accentGlass :
                        LiquidGlassStyle.secondaryGlass
                    )
                    .frame(width: 32, height: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isSelected ? 
                                LinearGradient(colors: [.cyan.opacity(0.8), .blue.opacity(0.6)], 
                                             startPoint: .topLeading, endPoint: .bottomTrailing) : 
                                LiquidGlassStyle.subtleBorder, 
                                lineWidth: isSelected ? 1.5 : 0.5
                            )
                    )
                
                Text(scheme.description)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                Spacer()
                
                // Selection checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan.opacity(0.9), .blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? LiquidGlassStyle.accentGlass.opacity(0.3) : LiquidGlassStyle.primaryGlass.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isSelected ? LiquidGlassStyle.primaryBorder : LiquidGlassStyle.subtleBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
    
    // MARK: - Actions
    private func clearBlockingData() {
        withAnimation(.spring()) {
            privacyManager.blockedCount = 0
            privacyManager.lastBlockedDomains.removeAll()
        }
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let systemImage: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.9), Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .font(.title2)
                .frame(width: 28)
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(.cyan)
                .scaleEffect(1.1)
        }
        .padding(.vertical, 4)
    }
}

struct PerformanceModeRow: View {
    let mode: AIPrivacyManager.PerformanceMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(mode.rawValue)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(mode.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.9), Color.blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .font(.title2)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? LiquidGlassStyle.accentGlass : LiquidGlassStyle.secondaryGlass)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isSelected ? LiquidGlassStyle.primaryBorder : LiquidGlassStyle.subtleBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}

struct SettingsRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .foregroundColor(.cyan)
                .font(.title2)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.subheadline)
        }
        .padding(.vertical, 8)
    }
}

// Define the search provider enum (used by settings and WebViewModel)
enum SearchProvider: Int, Identifiable, CaseIterable {
    case google = 0
    case bing = 1
    case duckDuckGo = 2
    case yahoo = 3
    
    var id: Int { self.rawValue }
    
    var displayName: String {
        switch self {
        case .google: return "Google"
        case .bing: return "Bing"
        case .duckDuckGo: return "DuckDuckGo"
        case .yahoo: return "Yahoo"
        }
    }
    
    var searchURL: String {
        switch self {
        case .google: return "https://www.google.com/search?q="
        case .bing: return "https://www.bing.com/search?q="
        case .duckDuckGo: return "https://duckduckgo.com/?q="
        case .yahoo: return "https://search.yahoo.com/search?p="
        }
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a dummy WebViewModel for the preview
        let webViewModel = WebViewModel()
        // Create a dummy BookmarkManager for the preview
        let bookmarkManager = BookmarkManager.preview // Or BookmarkManager() if .preview is not suitable
        // Create AssistantViewModel with both dependencies
        let assistantViewModel = AssistantViewModel(webViewModel: webViewModel, bookmarkManager: bookmarkManager)
        
        SettingsView(assistantViewModel: assistantViewModel)
            .environmentObject(webViewModel) // Provide WebViewModel to environment if SettingsView or children need it
            .environmentObject(bookmarkManager) // Provide BookmarkManager to environment
            .environmentObject(assistantViewModel) // Provide AssistantViewModel itself to environment
            .frame(width: 500, height: 500)
    }
}
#endif 