import SwiftUI
import Foundation

// MARK: - AI Assistant Feature Protocol
protocol AIAssistantServiceProtocol: ObservableObject {
    // Chat interface
    var messages: [ChatMessage] { get }
    var currentInput: String { get set }
    var isProcessing: Bool { get }
    var isListening: Bool { get }
    
    // Core AI methods
    func sendMessage(_ text: String)
    func clearConversation()
    func startVoiceInput()
    func stopVoiceInput()
    
    // Assistant states
    var welcomeMessage: String { get }
    var idlePrompts: [String] { get }
    
    // Command processing
    func processCommand(_ command: String) -> Bool
}

// MARK: - Chat Message Model
struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let imageData: Data?
    let timestamp: Date
    let priceComparisonData: PriceComparisonData?
    
    init(text: String, isUser: Bool, imageData: Data? = nil, priceComparisonData: PriceComparisonData? = nil) {
        self.text = text
        self.isUser = isUser
        self.imageData = imageData
        self.timestamp = Date()
        self.priceComparisonData = priceComparisonData
    }
}



// MARK: - AI Assistant Events Protocol
protocol AIAssistantEventsProtocol {
    func onCommandRecognized(_ command: AssistantCommand)
    func onResponseGenerated(_ response: String)
    func onVoiceInputDetected(_ text: String)
}

// MARK: - Assistant Commands
enum AssistantCommand: String, CaseIterable {
    case bookmark = "bookmark"
    case navigate = "navigate"
    case search = "search"
    case newTab = "new tab"
    case closeTab = "close tab"
    case reload = "reload"
    case back = "back"
    case forward = "forward"
    case help = "help"
} 