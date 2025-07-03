import SwiftUI

struct SplitViewAnalysisPanel: View {
    @ObservedObject var analyzer: SplitViewAnalyzer
    @State private var isExpanded: Bool = false
    @State private var selectedTab: AnalysisTab = .combined
    @State private var dragOffset: CGSize = .zero
    @State private var position: CGSize = CGSize(width: 20, height: -100) // Start near bottom left
    @State private var panelSize: CGSize = CGSize(width: 350, height: 280)
    @State private var isResizing: Bool = false
    
    // Minimum and maximum sizes
    private let minSize = CGSize(width: 300, height: 200)
    private let maxSize = CGSize(width: 800, height: 600)
    private let minimizedHeight: CGFloat = 40
    
    enum AnalysisTab: String, CaseIterable {
        case combined = "Combined Context"
        case primary = "Primary View"
        case secondary = "Secondary View"
        
        var icon: String {
            switch self {
            case .combined: return "brain.head.profile"
            case .primary: return "rectangle.lefthalf.filled"
            case .secondary: return "rectangle.righthalf.filled"
            }
        }
        
        var shortName: String {
            switch self {
            case .combined: return "Combined"
            case .primary: return "Primary"
            case .secondary: return "Secondary"
            }
        }
    }
    
    var body: some View {
        GlassCard(style: .floating) {
            VStack(spacing: 0) {
                // Header - always visible
                headerView
                    .padding(.bottom, isExpanded ? 8 : 0)
                
                if isExpanded {
                    // Tab selector
                    tabSelectorView
                        .padding(.bottom, 8)
                    
                    // Content area with dynamic height
                    contentView
                        .frame(height: max(120, panelSize.height - 120)) // Account for header and tabs
                }
            }
        }
        .frame(width: isExpanded ? panelSize.width : 200, height: isExpanded ? panelSize.height : minimizedHeight)
        .overlay(
            // Resize indicator border when active
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(isResizing ? 0.4 : 0.0),
                            Color.cyan.opacity(isResizing ? 0.3 : 0.0),
                            Color.blue.opacity(isResizing ? 0.4 : 0.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .animation(.easeInOut(duration: 0.3), value: isResizing)
        )
        .offset(x: position.width + dragOffset.width, y: position.height + dragOffset.height)
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    if !isResizing {
                        self.dragOffset = gesture.translation
                    }
                }
                .onEnded { gesture in
                    if !isResizing {
                        self.position.width += gesture.translation.width
                        self.position.height += gesture.translation.height
                        self.dragOffset = .zero
                    }
                }
        )
        .overlay(
            // WORKING resize handles in corners
            Group {
                if isExpanded {
                    ZStack {
                        // Bottom-right corner resize handle - VISIBLE AND WORKING
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Rectangle()
                                    .fill(Color.blue.opacity(0.6))
                                    .frame(width: 20, height: 20)
                                    .cornerRadius(4)
                                    .cursor(.crosshair)
                                    .gesture(
                                        DragGesture()
                                            .onChanged { gesture in
                                                isResizing = true
                                                let newWidth = max(minSize.width, min(maxSize.width, panelSize.width + gesture.translation.width))
                                                let newHeight = max(minSize.height, min(maxSize.height, panelSize.height + gesture.translation.height))
                                                panelSize = CGSize(width: newWidth, height: newHeight)
                                            }
                                            .onEnded { _ in
                                                isResizing = false
                                            }
                                    )
                                    .padding(4)
                            }
                        }
                    }
                }
            }
        )
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
    }
    
    private var headerView: some View {
        HStack(spacing: 8) {
            // Main icon and title
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                    .font(.system(size: 14, weight: .medium))
                
                if isExpanded {
                    Text("Split-View Analysis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                } else {
                    Text("Split View")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            
            // Show "Split View Analysis" when minimized
            if !isExpanded {
                Text("•")
                    .foregroundColor(.secondary)
                    .font(.system(size: 10))
                
                Text("Split View Analysis")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.blue)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Status indicators
            HStack(spacing: 4) {
                if analyzer.isAnalyzing {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                }
                
                if !isExpanded, let lastAnalysis = analyzer.lastAnalysisTime {
                    Text(timeAgoString(from: lastAnalysis))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                // Expand/collapse button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle()) // Make entire header draggable
    }
    
    private var tabSelectorView: some View {
        HStack(spacing: 4) {
            ForEach(AnalysisTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
            Spacer()
            
            if let lastAnalysis = analyzer.lastAnalysisTime {
                Text(timeAgoString(from: lastAnalysis))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
    
    private func tabButton(for tab: AnalysisTab) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = tab
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11, weight: .medium))
                
                Text(tab.shortName)
                    .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        selectedTab == tab ? 
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.2),
                                Color.cyan.opacity(0.15),
                                Color.blue.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                selectedTab == tab ? Color.white.opacity(0.3) : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
            .foregroundColor(selectedTab == tab ? .primary : .secondary)
        }
        .buttonStyle(.plain)
    }
    
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                switch selectedTab {
                case .combined:
                    combinedContextView
                case .primary:
                    primarySummaryView
                case .secondary:
                    secondarySummaryView
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.blue.opacity(0.02),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
    
    private var combinedContextView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if analyzer.combinedContext.isEmpty {
                emptyStateView(message: "Enable split-view to see cross-content analysis", icon: "brain.head.profile")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)
                            .font(.system(size: 14, weight: .medium))
                        Text("Combined Analysis")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    
                    Text(analyzer.combinedContext)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.primary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.12),
                                    Color.cyan.opacity(0.08),
                                    Color.blue.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
    
        private var primarySummaryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if analyzer.primaryViewSummary.isEmpty {
                emptyStateView(message: "Analyzing primary view content...", icon: "rectangle.lefthalf.filled")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "rectangle.lefthalf.filled")
                            .foregroundColor(.green)
                            .font(.system(size: 14, weight: .medium))
                        Text("Primary View")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    
                    Text(analyzer.primaryViewSummary)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.primary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.green.opacity(0.12),
                                    Color.mint.opacity(0.08),
                                    Color.green.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }

    private var secondarySummaryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if analyzer.secondaryViewSummary.isEmpty {
                emptyStateView(message: "Analyzing secondary view content...", icon: "rectangle.righthalf.filled")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "rectangle.righthalf.filled")
                            .foregroundColor(.orange)
                            .font(.system(size: 14, weight: .medium))
                        Text("Secondary View")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    
                    Text(analyzer.secondaryViewSummary)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.primary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.orange.opacity(0.12),
                                    Color.yellow.opacity(0.08),
                                    Color.orange.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private func emptyStateView(message: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.secondary.opacity(0.6))
            
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.blue.opacity(0.03),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "\(Int(interval))s"
        } else if interval < 3600 {
            return "\(Int(interval/60))m"
        } else {
            return "\(Int(interval/3600))h"
        }
    }
}



// Helper extension for custom corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RectCorner: OptionSet {
    let rawValue: Int
    
    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let w = rect.size.width
        let h = rect.size.height
        
        // Top-left corner
        if corners.contains(.topLeft) {
            path.move(to: CGPoint(x: 0, y: radius))
            path.addQuadCurve(to: CGPoint(x: radius, y: 0), control: CGPoint(x: 0, y: 0))
        } else {
            path.move(to: CGPoint(x: 0, y: 0))
        }
        
        // Top-right corner
        if corners.contains(.topRight) {
            path.addLine(to: CGPoint(x: w - radius, y: 0))
            path.addQuadCurve(to: CGPoint(x: w, y: radius), control: CGPoint(x: w, y: 0))
        } else {
            path.addLine(to: CGPoint(x: w, y: 0))
        }
        
        // Bottom-right corner
        if corners.contains(.bottomRight) {
            path.addLine(to: CGPoint(x: w, y: h - radius))
            path.addQuadCurve(to: CGPoint(x: w - radius, y: h), control: CGPoint(x: w, y: h))
        } else {
            path.addLine(to: CGPoint(x: w, y: h))
        }
        
        // Bottom-left corner
        if corners.contains(.bottomLeft) {
            path.addLine(to: CGPoint(x: radius, y: h))
            path.addQuadCurve(to: CGPoint(x: 0, y: h - radius), control: CGPoint(x: 0, y: h))
        } else {
            path.addLine(to: CGPoint(x: 0, y: h))
        }
        
        path.closeSubpath()
        return path
    }
}

// Cursor modifier for resize handle
extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { isHovering in
            if isHovering {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

#Preview {
    @Previewable @StateObject var mockAnalyzer = SplitViewAnalyzer(assistantViewModel: AssistantViewModel())
    
    SplitViewAnalysisPanel(analyzer: mockAnalyzer)
        .frame(width: 400, height: 300)
        .padding()
        .onAppear {
            // Mock data for preview
            mockAnalyzer.primaryViewSummary = "This article discusses the latest developments in AI technology, focusing on new language models and their applications in various industries."
            mockAnalyzer.secondaryViewSummary = "A research paper detailing the technical architecture behind modern transformer models and their training methodologies."
            mockAnalyzer.combinedContext = "Both sources complement each other well - the article provides practical applications while the research paper offers technical depth. Key connection: the transformer architecture mentioned in the paper is the foundation for the AI applications described in the article."
            mockAnalyzer.lastAnalysisTime = Date().addingTimeInterval(-120) // 2 minutes ago
        }
} 