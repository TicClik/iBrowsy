import SwiftUI

struct PrivacyStatsView: View {
    @ObservedObject var manager: AIPrivacyManager
    @State private var selectedTimeframe: TimeFrame = .today
    
    enum TimeFrame: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Overall stats header
                overallStatsSection
                
                // Time-based stats
                timeBasedStatsSection
                
                // Blocking categories
                blockingCategoriesSection
                
                // Performance metrics
                performanceSection
                
                // Top blocked domains
                topBlockedDomainsSection
                
                // Recent blocking activity
                recentBlockingSection
            }
            .padding()
        }
        .background(
            // Gorgeous liquid glass background
            Rectangle()
                .fill(LiquidGlassStyle.backgroundGlass)
                .ignoresSafeArea()
        )
    }
    
    // MARK: - Computed Properties for Real Data
    private var categoryStats: [String: Int] {
        var stats: [String: Int] = [:]
        
        let filteredBlocks = filteredBlocksForTimeframe()
        
        for block in filteredBlocks {
            let categoryKey = block.reason.rawValue
            stats[categoryKey, default: 0] += 1
        }
        
        return stats
    }
    
    private var domainStats: [String: Int] {
        var stats: [String: Int] = [:]
        
        let filteredBlocks = filteredBlocksForTimeframe()
        
        for block in filteredBlocks {
            stats[block.domain, default: 0] += 1
        }
        
        return stats
    }
    
    private func filteredBlocksForTimeframe() -> [AIPrivacyManager.BlockedItem] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeframe {
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            return manager.recentBlocks.filter { $0.timestamp >= startOfDay }
            
        case .week:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
            return manager.recentBlocks.filter { $0.timestamp >= startOfWeek }
            
        case .month:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now)
            return manager.recentBlocks.filter { $0.timestamp >= startOfMonth }
            
        case .all:
            return manager.recentBlocks
        }
    }
    
    private func getCountForTimeframe() -> Int {
        switch selectedTimeframe {
        case .today:
            return manager.todayBlockedCount
        case .week:
            return manager.weekBlockedCount
        case .month:
            let calendar = Calendar.current
            let now = Date()
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now)
            return manager.recentBlocks.filter { $0.timestamp >= startOfMonth }.count
        case .all:
            return manager.blockedCount
        }
    }
    
    // MARK: - Overall Stats Section
    private var overallStatsSection: some View {
        VStack(spacing: 20) {
            Text("Protection Overview")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                StatCard(
                    title: "Total Blocked",
                    value: "\(manager.blockedCount)",
                    subtitle: "All time",
                    color: .cyan,
                    icon: "shield.fill"
                )
                
                StatCard(
                    title: "Today",
                    value: "\(manager.todayBlockedCount)",
                    subtitle: "This session",
                    color: .cyan,
                    icon: "clock.fill"
                )
                
                StatCard(
                    title: "This Week",
                    value: "\(manager.weekBlockedCount)",
                    subtitle: "7 days",
                    color: .cyan,
                    icon: "calendar"
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LiquidGlassStyle.primaryGlass)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(LiquidGlassStyle.primaryBorder, lineWidth: 1)
                )
        )
        .shadow(color: LiquidGlassStyle.lightShadow, radius: 15, x: 0, y: 5)
    }
    
    // MARK: - Time-based Stats Section
    private var timeBasedStatsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Blocking Trends")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Picker("Timeframe", selection: $selectedTimeframe) {
                    ForEach(TimeFrame.allCases, id: \.rawValue) { timeframe in
                        Text(timeframe.rawValue)
                            .tag(timeframe)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            
            // Chart showing actual blocking activity
            ChartPlaceholder(timeframe: selectedTimeframe, blockedCount: getCountForTimeframe())
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LiquidGlassStyle.secondaryGlass)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(LiquidGlassStyle.secondaryBorder, lineWidth: 1)
                )
        )
        .shadow(color: LiquidGlassStyle.lightShadow, radius: 15, x: 0, y: 5)
    }
    
    // MARK: - Blocking Categories Section
    private var blockingCategoriesSection: some View {
        VStack(spacing: 16) {
            categoryHeader
            categoryRows
        }
        .padding(20)
        .background(categoryBackground)
        .shadow(color: LiquidGlassStyle.lightShadow, radius: 15, x: 0, y: 5)
    }
    
    private var categoryHeader: some View {
            HStack {
                Text("Blocked Content Types - \(selectedTimeframe.rawValue)")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
        }
            }
            
    private var categoryRows: some View {
            VStack(spacing: 12) {
                let totalForTimeframe = getCountForTimeframe()
                
            if totalForTimeframe == 0 {
                Text("No blocked content for \(selectedTimeframe.rawValue.lowercased())")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                youTubeAdsRow(total: totalForTimeframe)
                advertisementsRow(total: totalForTimeframe)
                trackersRow(total: totalForTimeframe)
                analyticsRow(total: totalForTimeframe)
                socialWidgetsRow(total: totalForTimeframe)
                aiDetectedRow(total: totalForTimeframe)
            }
        }
    }
    
    private func youTubeAdsRow(total: Int) -> some View {
                CategoryRow(
                    category: "YouTube Ads",
                    count: categoryStats["YouTube Ad"] ?? 0,
            percentage: total > 0 ? Int(Double(categoryStats["YouTube Ad"] ?? 0) / Double(total) * 100) : 0,
            color: .cyan,
                    icon: "play.slash"
                )
    }
                
    private func advertisementsRow(total: Int) -> some View {
                CategoryRow(
                    category: "Advertisements",
                    count: categoryStats["Advertisement"] ?? 0,
            percentage: total > 0 ? Int(Double(categoryStats["Advertisement"] ?? 0) / Double(total) * 100) : 0,
            color: .cyan,
                    icon: "rectangle.badge.xmark"
                )
    }
                
    private func trackersRow(total: Int) -> some View {
                CategoryRow(
                    category: "Trackers",
                    count: categoryStats["Tracker"] ?? 0,
            percentage: total > 0 ? Int(Double(categoryStats["Tracker"] ?? 0) / Double(total) * 100) : 0,
            color: .cyan,
                    icon: "eye.slash"
                )
    }
                
    private func analyticsRow(total: Int) -> some View {
                CategoryRow(
                    category: "Analytics",
                    count: categoryStats["Analytics"] ?? 0,
            percentage: total > 0 ? Int(Double(categoryStats["Analytics"] ?? 0) / Double(total) * 100) : 0,
            color: .cyan,
                    icon: "chart.bar.xaxis"
                )
    }
                
    private func socialWidgetsRow(total: Int) -> some View {
                CategoryRow(
                    category: "Social Widgets",
                    count: categoryStats["Social Media Widget"] ?? 0,
            percentage: total > 0 ? Int(Double(categoryStats["Social Media Widget"] ?? 0) / Double(total) * 100) : 0,
            color: .cyan,
                    icon: "person.2.slash"
                )
    }
                
    private func aiDetectedRow(total: Int) -> some View {
                CategoryRow(
                    category: "AI-Detected",
                    count: categoryStats["AI-Detected Unwanted Content"] ?? 0,
            percentage: total > 0 ? Int(Double(categoryStats["AI-Detected Unwanted Content"] ?? 0) / Double(total) * 100) : 0,
            color: .cyan,
                    icon: "brain"
                )
    }
    
    private var categoryBackground: some View {
            RoundedRectangle(cornerRadius: 16)
            .fill(LiquidGlassStyle.secondaryGlass)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(LiquidGlassStyle.secondaryBorder, lineWidth: 1)
        )
    }
    
    // MARK: - Performance Section
    private var performanceSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Performance Impact")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            let blockedToday = manager.todayBlockedCount
            let estimatedDataSaved = Double(blockedToday) * 0.05 // ~50KB per blocked item
            let estimatedSpeedImprovement = min(Int(Double(blockedToday) * 0.5), 80) // Max 80%
            
            VStack(spacing: 12) {
                PerformanceRow(
                    title: "Page Load Speed",
                    improvement: "+\(estimatedSpeedImprovement)%",
                    description: "Faster loading due to blocked content",
                    color: .cyan,
                    icon: "speedometer"
                )
                
                PerformanceRow(
                    title: "Data Savings",
                    improvement: String(format: "%.1f MB", estimatedDataSaved),
                    description: "Bandwidth saved today",
                    color: .cyan,
                    icon: "arrow.down.circle"
                )
                
                PerformanceRow(
                    title: "CPU Usage",
                    improvement: "-\(min(Int(Double(blockedToday) * 0.3), 50))%",
                    description: "Reduced processing overhead",
                    color: .cyan,
                    icon: "cpu"
                )
                
                PerformanceRow(
                    title: "Blocked Requests",
                    improvement: "\(blockedToday)",
                    description: "Requests prevented today",
                    color: .cyan,
                    icon: "shield.checkered"
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LiquidGlassStyle.secondaryGlass)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(LiquidGlassStyle.secondaryBorder, lineWidth: 1)
                )
        )
        .shadow(color: LiquidGlassStyle.lightShadow, radius: 15, x: 0, y: 5)
    }
    
    // MARK: - Top Blocked Domains Section
    private var topBlockedDomainsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Most Blocked Domains - \(selectedTimeframe.rawValue)")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(spacing: 8) {
                let sortedDomains = domainStats.sorted { $0.value > $1.value }
                
                if sortedDomains.isEmpty {
                    Text("No blocked domains for \(selectedTimeframe.rawValue.lowercased())")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(Array(sortedDomains.prefix(10).enumerated()), id: \.offset) { index, domainData in
                        DomainRow(
                            rank: index + 1,
                            domain: domainData.key,
                            blockCount: domainData.value,
                            isTopDomain: index < 3
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.2), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    // MARK: - Recent Blocking Activity Section
    private var recentBlockingSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recent Blocking Activity")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(spacing: 8) {
                let recentItems = manager.recentBlocks.prefix(20)
                
                if recentItems.isEmpty {
                    Text("No recent blocking activity")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(Array(recentItems), id: \.id) { item in
                        RecentBlockRow(item: item)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LiquidGlassStyle.secondaryGlass)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(LiquidGlassStyle.secondaryBorder, lineWidth: 1)
                )
        )
        .shadow(color: LiquidGlassStyle.lightShadow, radius: 15, x: 0, y: 5)
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

struct ChartPlaceholder: View {
    let timeframe: PrivacyStatsView.TimeFrame
    let blockedCount: Int
    
    var body: some View {
        VStack {
            Text("Blocking Activity - \(timeframe.rawValue)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text("\(blockedCount)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.cyan)
                
                Text("items blocked")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Simple visual representation
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [.cyan.opacity(0.3), .cyan.opacity(0.1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 60)
                .overlay(
                    HStack {
                        Text("Visual chart representation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                )
        }
        .padding()
    }
}

struct CategoryRow: View {
    let category: String
    let count: Int
    let percentage: Int
    let color: Color
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(count) blocked")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(percentage)%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: geometry.size.width * CGFloat(percentage) / 100, height: 4)
                    }
                }
                .frame(width: 60, height: 4)
            }
        }
        .padding(.vertical, 8)
    }
}

struct PerformanceRow: View {
    let title: String
    let improvement: String
    let description: String
    let color: Color
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(improvement)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.vertical, 8)
    }
}

struct DomainRow: View {
    let rank: Int
    let domain: String
    let blockCount: Int
    let isTopDomain: Bool
    
    var body: some View {
        HStack {
            // Rank indicator
            Text("#\(rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(isTopDomain ? .white : .secondary)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(isTopDomain ? rankColor : Color.gray.opacity(0.2))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(domain)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("Blocked \(blockCount) times")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "shield.slash.fill")
                .foregroundColor(.cyan)
                .font(.caption)
        }
        .padding(.vertical, 6)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
}

struct RecentBlockRow: View {
    let item: AIPrivacyManager.BlockedItem
    
    var body: some View {
        HStack {
            // Icon based on block reason
            Image(systemName: iconForReason(item.reason))
                .font(.caption)
                .foregroundColor(colorForReason(item.reason))
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(colorForReason(item.reason).opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.domain)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(item.reason.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatTime(item.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.08))
        )
    }
    
    private func iconForReason(_ reason: AIPrivacyManager.BlockReason) -> String {
        switch reason {
        case .advertisement: return "rectangle.badge.xmark"
        case .tracker: return "eye.slash"
        case .analytics: return "chart.bar.xaxis"
        case .social: return "person.2.slash"
        case .popup: return "macwindow.badge.plus"
        case .autoplay: return "play.slash"
        case .aiDetected: return "brain"
        case .contentRule: return "shield"
        case .youtubeAd: return "play.slash"
        }
    }
    
    private func colorForReason(_ reason: AIPrivacyManager.BlockReason) -> Color {
        switch reason {
        case .advertisement: return .red
        case .tracker: return .orange
        case .analytics: return .blue
        case .social: return .green
        case .popup: return .purple
        case .autoplay: return .pink
        case .aiDetected: return .mint
        case .contentRule: return .gray
        case .youtubeAd: return .red
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Advanced Privacy Settings View
struct AdvancedPrivacySettingsView: View {
    @ObservedObject var manager: AIPrivacyManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Advanced privacy settings would go here")
                    .font(.headline)
                    .padding()
                
                // Placeholder for advanced settings
                Text("Custom filtering rules, whitelist management, and expert options")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .background(
            // Gorgeous liquid glass background
            Rectangle()
                .fill(LiquidGlassStyle.backgroundGlass)
                .ignoresSafeArea()
        )
    }
}

#Preview {
    PrivacyStatsView(manager: AIPrivacyManager())
} 