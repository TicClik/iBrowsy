import SwiftUI

struct PrivacySettingsView: View {
    @StateObject private var privacyManager = AIPrivacyManager()
    @State private var showingStats = false
    @State private var showingAdvancedSettings = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            mainContentView
        }
        .background(liquidGlassBackground)
        .onChange(of: showingStats) { newValue in
            if newValue {
                PrivacyStatsWindowManager.shared.showStatsWindow(with: privacyManager)
                showingStats = false // Reset the state
            }
        }
        .onChange(of: showingAdvancedSettings) { newValue in
            if newValue {
                AdvancedPrivacyWindowManager.shared.showAdvancedWindow(with: privacyManager)
                showingAdvancedSettings = false // Reset the state
            }
        }
    }
    
    private var mainContentView: some View {
        LazyVStack(spacing: 28) {
            topSections
            middleSections
            bottomSections
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
    
    private var topSections: some View {
        Group {
            privacyHeaderSection
            privacyControlsSection
        }
    }
    
    private var middleSections: some View {
        Group {
            performanceModeSection
            youTubeSection
        }
    }
    
    private var bottomSections: some View {
        Group {
            advancedOptionsSection
            recentlyBlockedSection
            Spacer(minLength: 20)
        }
    }
    
    private var liquidGlassBackground: some View {
        Rectangle()
            .fill(LiquidGlassStyle.backgroundGlass)
            .ignoresSafeArea()
    }
    
    // MARK: - Header Section
    private var privacyHeaderSection: some View {
        VStack(spacing: 20) {
            headerTitleRow
            protectionStatusRow
        }
        .padding(30)
        .background(headerBackground)
        .shadow(color: LiquidGlassStyle.lightShadow, radius: 20, x: 0, y: 10)
    }
    
    private var headerTitleRow: some View {
            HStack {
            headerTitleContent
            Spacer()
            statsButton
        }
    }
    
    private var headerTitleContent: some View {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.title)
                            .foregroundStyle(
                                LinearGradient(
                            colors: [Color.cyan.opacity(0.9), Color.white.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("AI-Powered Protection")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    Text("Advanced ad & tracker blocking with machine learning")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .padding(.leading, 44)
        }
                }
                
    private var statsButton: some View {
                Button(action: { showingStats = true }) {
                    VStack(spacing: 8) {
                        Text("\(privacyManager.blockedCount)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                            colors: [Color.cyan.opacity(0.9), Color.white.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        Text("Blocked Today")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 30)
            .background(statsButtonBackground)
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: privacyManager.blockedCount)
            }
            
    private var statsButtonBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(LiquidGlassStyle.accentGlass)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(LiquidGlassStyle.primaryBorder, lineWidth: 1.5)
            )
    }
    
    private var protectionStatusRow: some View {
            HStack(spacing: 16) {
            protectionStatusIndicator
            Spacer()
            performanceIndicator
        }
    }
    
    private var protectionStatusIndicator: some View {
                HStack(spacing: 12) {
                    Circle()
                .fill(privacyManager.isEnabled ? Color.cyan.opacity(0.8) : Color.white.opacity(0.6))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                        .stroke(Color.white.opacity(0.6), lineWidth: 2)
                        )
                    
                    Text(privacyManager.isEnabled ? "Protection Active" : "Protection Disabled")
                        .font(.title3)
                        .fontWeight(.semibold)
                .foregroundColor(privacyManager.isEnabled ? .cyan : .primary)
        }
                }
                
    private var performanceIndicator: some View {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                .foregroundColor(.cyan)
                    Text("Performance: \(privacyManager.performanceMode.rawValue)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
    
    private var headerBackground: some View {
            RoundedRectangle(cornerRadius: 24)
            .fill(LiquidGlassStyle.primaryGlass)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(LiquidGlassStyle.primaryBorder, lineWidth: 1.5)
        )
    }
    
    // MARK: - Privacy Controls Section
    private var privacyControlsSection: some View {
        VStack(spacing: 20) {
            SectionHeader(title: "Privacy Controls", systemImage: "shield.fill", color: .cyan)
            
            VStack(spacing: 16) {
                ToggleRow(
                    title: "AI Privacy Protection",
                    subtitle: "Block ads and trackers using machine learning",
                    isOn: $privacyManager.isEnabled,
                    color: .cyan
                )
                
                Divider()
                    .background(Color.white.opacity(0.3))
                
                ToggleRow(
                    title: "Enhanced YouTube Blocking",
                    subtitle: "Advanced ad blocking specifically for YouTube",
                    isOn: $privacyManager.enhancedYouTubeBlocking,
                    color: .cyan
                )
                
                Divider()
                    .background(Color.white.opacity(0.3))
                
                ToggleRow(
                    title: "AI Content Analysis",
                    subtitle: "Analyze page content to detect unwanted elements",
                    isOn: $privacyManager.aiContentAnalysis,
                    color: .cyan
                )
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LiquidGlassStyle.secondaryGlass)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(LiquidGlassStyle.secondaryBorder, lineWidth: 1)
                )
        )
        .shadow(color: LiquidGlassStyle.lightShadow, radius: 15, x: 0, y: 5)
    }
    
    // MARK: - Performance Mode Section
    private var performanceModeSection: some View {
        VStack(spacing: 20) {
            SectionHeader(title: "Performance Mode", systemImage: "speedometer", color: .cyan)
            
            VStack(spacing: 12) {
                ForEach(AIPrivacyManager.PerformanceMode.allCases, id: \.rawValue) { mode in
                    PerformanceModeRow(
                        mode: mode,
                        isSelected: privacyManager.performanceMode == mode
                    ) {
                        privacyManager.updateBlockingLevel(mode)
                    }
                }
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LiquidGlassStyle.secondaryGlass)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(LiquidGlassStyle.secondaryBorder, lineWidth: 1)
                )
        )
        .shadow(color: LiquidGlassStyle.lightShadow, radius: 15, x: 0, y: 5)
    }
    
    // MARK: - YouTube Section
    private var youTubeSection: some View {
        VStack(spacing: 20) {
            SectionHeader(title: "YouTube Protection", systemImage: "play.rectangle.fill", color: .cyan)
            
            VStack(alignment: .leading, spacing: 16) {
                FeatureCheckmark(text: "Pre-roll ad blocking", isActive: true)
                FeatureCheckmark(text: "Mid-roll ad blocking", isActive: true)
                FeatureCheckmark(text: "Overlay ad removal", isActive: true)
                FeatureCheckmark(text: "Automatic skip button clicking", isActive: true)
                FeatureCheckmark(text: "Sponsored content filtering", isActive: privacyManager.aiContentAnalysis)
                FeatureCheckmark(text: "Real-time ad pattern learning", isActive: privacyManager.aiContentAnalysis)
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LiquidGlassStyle.secondaryGlass)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(LiquidGlassStyle.secondaryBorder, lineWidth: 1)
                )
        )
        .shadow(color: LiquidGlassStyle.lightShadow, radius: 15, x: 0, y: 5)
    }
    
    // MARK: - Advanced Options Section
    private var advancedOptionsSection: some View {
        VStack(spacing: 20) {
            SectionHeader(title: "Advanced Options", systemImage: "gearshape.fill", color: .cyan)
            
            VStack(spacing: 16) {
                Button(action: { showingStats = true }) {
                    SettingsRow(
                        title: "View Detailed Statistics",
                        subtitle: "See blocking performance and metrics",
                        systemImage: "chart.bar.fill",
                        color: .cyan
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .background(Color.white.opacity(0.3))
                
                Button(action: { showingAdvancedSettings = true }) {
                    SettingsRow(
                        title: "Advanced Settings",
                        subtitle: "Custom rules and expert options",
                        systemImage: "wrench.and.screwdriver.fill",
                        color: .cyan
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .background(Color.white.opacity(0.3))
                
                Button(action: clearBlockingData) {
                    SettingsRow(
                        title: "Clear Blocking Data",
                        subtitle: "Reset statistics and cache",
                        systemImage: "trash.fill",
                        color: .cyan
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LiquidGlassStyle.secondaryGlass)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(LiquidGlassStyle.secondaryBorder, lineWidth: 1)
                )
        )
        .shadow(color: LiquidGlassStyle.lightShadow, radius: 15, x: 0, y: 5)
    }
    
    // MARK: - Recently Blocked Section
    private var recentlyBlockedSection: some View {
        VStack(spacing: 20) {
            SectionHeader(title: "Recently Blocked", systemImage: "clock.fill", color: .cyan)
            
            if privacyManager.lastBlockedDomains.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("No blocked domains yet")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text("Start browsing to see blocked content")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 12) {
                    ForEach(privacyManager.lastBlockedDomains.prefix(8), id: \.self) { domain in
                        HStack(spacing: 16) {
                            Image(systemName: "shield.slash.fill")
                                .foregroundColor(.cyan)
                                .font(.title3)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(domain)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("Blocked \(timeAgo())")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("BLOCKED")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.cyan.opacity(0.15))
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(Color.cyan.opacity(0.4), lineWidth: 1)
                                        )
                                )
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.08))
                        )
                    }
                }
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LiquidGlassStyle.secondaryGlass)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(LiquidGlassStyle.secondaryBorder, lineWidth: 1)
                )
        )
        .shadow(color: LiquidGlassStyle.lightShadow, radius: 15, x: 0, y: 5)
    }
    
    // MARK: - Actions
    private func clearBlockingData() {
        withAnimation(.spring()) {
            privacyManager.blockedCount = 0
            privacyManager.lastBlockedDomains.removeAll()
        }
    }
    
    private func timeAgo() -> String {
        let times = ["just now", "1m ago", "3m ago", "5m ago", "10m ago"]
        return times.randomElement() ?? "just now"
    }
}

// MARK: - Supporting Views

struct FeatureCheckmark: View {
    let text: String
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isActive ? .cyan : .secondary.opacity(0.5))
                .font(.title3)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(isActive ? .primary : .secondary)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isActive ? Color.cyan.opacity(0.08) : Color.secondary.opacity(0.05))
        )
    }
}

#Preview {
    PrivacySettingsView()
} 