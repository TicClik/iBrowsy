import Foundation

struct VideoElementInfo: Identifiable, Codable, Hashable {
    let id: UUID
    let src: String
    let title: String?
    let currentTime: Double
    let duration: Double
    let width: Double
    let height: Double
    let isPlaying: Bool
    let elementType: VideoElementType
    
    init(src: String, title: String? = nil, currentTime: Double = 0, duration: Double = 0, width: Double = 640, height: Double = 360, isPlaying: Bool = false, elementType: VideoElementType = .video) {
        // Create deterministic ID based on cleaned src and normalized title
        var cleanedSrc = src
        
        // Special handling for YouTube URLs to ensure consistent IDs
        if src.contains("youtube.com") || src.contains("youtu.be") {
            // Extract video ID from YouTube URL
            if let url = URL(string: src),
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                if let videoId = components.queryItems?.first(where: { $0.name == "v" })?.value {
                    cleanedSrc = "https://youtube.com/watch?v=\(videoId)"
                } else if src.contains("youtu.be/") {
                    let videoId = url.lastPathComponent
                    cleanedSrc = "https://youtube.com/watch?v=\(videoId)"
                }
            }
        }
        
        // Normalize title (remove common YouTube suffixes)
        var normalizedTitle = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedTitle.contains(" - YouTube") {
            normalizedTitle = String(normalizedTitle.prefix(while: { $0 != "-" })).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        let srcHash = abs(cleanedSrc.hashValue)
        let titleHash = abs(normalizedTitle.hashValue)
        let typeHash = abs(elementType.rawValue.hashValue)
        let combinedHash = srcHash ^ titleHash ^ typeHash
        
        // Convert to UUID format
        let uuidString = String(format: "%08X-%04X-%04X-%04X-%012X", 
                              combinedHash & 0xFFFFFFFF,
                              (combinedHash >> 32) & 0xFFFF,
                              4000 | ((combinedHash >> 48) & 0x0FFF), // Version 4 UUID
                              0x8000 | ((combinedHash >> 60) & 0x3FFF),
                              combinedHash & 0xFFFFFFFFFFFF)
        
        self.id = UUID(uuidString: uuidString) ?? UUID()
        self.src = src
        self.title = title
        self.currentTime = currentTime
        self.duration = duration
        self.width = width
        self.height = height
        self.isPlaying = isPlaying
        self.elementType = elementType
    }
    
    // Implement Hashable for Set operations
    func hash(into hasher: inout Hasher) {
        hasher.combine(cleanedSource())
        hasher.combine(normalizedTitle())
        hasher.combine(elementType)
    }
    
    static func == (lhs: VideoElementInfo, rhs: VideoElementInfo) -> Bool {
        return lhs.cleanedSource() == rhs.cleanedSource() && 
               lhs.normalizedTitle() == rhs.normalizedTitle() && 
               lhs.elementType == rhs.elementType
    }
    
    // Helper methods for consistent cleaning
    private func cleanedSource() -> String {
        var cleaned = src
        
        // Special handling for YouTube URLs
        if src.contains("youtube.com") || src.contains("youtu.be") {
            if let url = URL(string: src),
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                if let videoId = components.queryItems?.first(where: { $0.name == "v" })?.value {
                    cleaned = "https://youtube.com/watch?v=\(videoId)"
                } else if src.contains("youtu.be/") {
                    let videoId = url.lastPathComponent
                    cleaned = "https://youtube.com/watch?v=\(videoId)"
                }
            }
        }
        
        return cleaned
    }
    
    private func normalizedTitle() -> String {
        var normalized = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.contains(" - YouTube") {
            normalized = String(normalized.prefix(while: { $0 != "-" })).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return normalized
    }
}

enum VideoElementType: String, Codable, CaseIterable {
    case video = "video"
    case iframe = "iframe"
    
    var displayName: String {
        switch self {
        case .video:
            return "Video"
        case .iframe:
            return "Embedded Video"
        }
    }
} 