import Foundation
import SwiftUI
import CoreGraphics

// MARK: - Drawing Tools
enum DrawingTool: String, CaseIterable {
    case pen = "pen"
    case highlighter = "highlighter"
    case arrow = "arrow"
    case rectangle = "rectangle"
    case circle = "circle"
    case eraser = "eraser"
    
    var displayName: String {
        switch self {
        case .pen: return "Pen"
        case .highlighter: return "Highlighter"
        case .arrow: return "Arrow"
        case .rectangle: return "Rectangle"
        case .circle: return "Circle"
        case .eraser: return "Eraser"
        }
    }
    
    var systemImage: String {
        switch self {
        case .pen: return "pencil"
        case .highlighter: return "highlighter"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .circle: return "circle"
        case .eraser: return "eraser"
        }
    }
}

// MARK: - Drawing Path
struct DrawingPath: Identifiable, Equatable {
    let id = UUID()
    var points: [CGPoint] = []
    var tool: DrawingTool = .pen
    var color: Color = .red
    var lineWidth: CGFloat = 3.0
    var opacity: Double = 1.0
    var isComplete: Bool = false
    
    // For shapes like rectangles and circles
    var startPoint: CGPoint?
    var endPoint: CGPoint?
    
    // Convenience initializer
    init(tool: DrawingTool = .pen, color: Color = .red, lineWidth: CGFloat = 3.0, opacity: Double = 1.0) {
        self.tool = tool
        self.color = color
        self.lineWidth = lineWidth
        self.opacity = opacity
    }
    
    static func == (lhs: DrawingPath, rhs: DrawingPath) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Annotation Session
class AnnotationSession: Identifiable, ObservableObject {
    let id = UUID()
    let createdAt = Date()
    @Published var paths: [DrawingPath] = []
    @Published var isRecording = false
    @Published var recordingStartTime: Date?
    @Published var recordingURL: URL?
    
    var hasContent: Bool {
        !paths.isEmpty
    }
    
    init() {}
    
    // Copy constructor for undo system
    init(copying other: AnnotationSession) {
        self.paths = other.paths
        self.isRecording = other.isRecording
        self.recordingStartTime = other.recordingStartTime
        self.recordingURL = other.recordingURL
    }
}

// MARK: - Drawing Settings
class DrawingSettings: ObservableObject {
    @Published var currentTool: DrawingTool = .pen
    @Published var currentColor: Color = .red
    @Published var currentLineWidth: CGFloat = 3.0
    @Published var currentOpacity: Double = 1.0
    @Published var showToolbar: Bool = true
    
    // Predefined colors
    let availableColors: [Color] = [
        .red, .blue, .green, .yellow, .orange, .purple, .pink, 
        .black, .white, .gray, .cyan, .mint, .indigo
    ]
    
    // Predefined line widths
    let availableLineWidths: [CGFloat] = [1.0, 2.0, 3.0, 5.0, 8.0, 12.0]
} 