import Foundation
import SwiftUI
import Combine
import Speech
import WebKit
import AppKit
import AVFoundation

enum MascotState {
    case idle
    case thinking
    case talking
    case error
    case customMessage
}

struct PageContextInfo {
    let url: String
    let title: String
    let contentSnippet: String
    let isContentAvailable: Bool
}

@MainActor
class AssistantViewModel: ObservableObject {
    @Published var chatHistory: [ChatMessage] = []
    private weak var webViewModel: WebViewModel?
    
    @Published var currentInput: String = "" {
        didSet {
            currentInputForAI = currentInput
            userDidInteract()
        }
    }
    @Published var isLoading: Bool = false
    @Published var currentInputForAI: String = ""
    @Published var currentMascotImage: Image?
    @Published var errorMessage: String? = nil
    
    // Speech Recognition related properties
    private let speechService = SpeechRecognitionService()
    @Published var isListening: Bool = false
    @Published var speechErrorMessage: String? = nil
    private var speechCancellable: AnyCancellable?
    private var speechErrorCancellable: AnyCancellable?
    private var isListeningCancellable: AnyCancellable?

    // Screen Capture related properties
    private let screenCaptureService = ScreenCaptureService()
    @Published var capturedImage: NSImage? = nil
    @Published var showScreenCaptureHint: Bool = false
    @Published var captureErrorMessage: String? = nil

    // Text-to-Speech related properties
    let textToSpeechService = TextToSpeechService()
    @Published var isSpeaking: Bool = false
    @Published var currentError: String? = nil
    private var ttsCancellable: AnyCancellable?
    var isTTSEnabled: Bool { isTTSEnabledGlobally }
    var isTTSAvailable: Bool { true }

    @Published var mascotState: MascotState = .idle
    // selectedTextForNewNote property removed with Notes feature

    private let webpageInteractionService = WebpageInteractionService()
    let openAIService = OpenAIService()
    private var internalCancellables = Set<AnyCancellable>()
    private let priceFetchingService = PriceFetchingService()

    // Welcome Bubble Properties
    private let welcomeMessages: [String] = [
        "Did you know I run on caffeine and pure optimism?",
        "Fetching witty remarks... or just thinking about snacks.",
        "Let's make some digital magic! Or at least not break anything.",
        "Ready to browse the web like it's 3024!",
        "I'm like Google, but with more personality.",
        "Powered by AI and a questionable amount of coffee.",
        "Your friendly neighborhood digital assistant!",
        "I speak fluent internet and broken English.",
        "Warning: May contain traces of artificial intelligence.",
        "Browsing the web, one pixel at a time.",
        "I'm here to help... or at least try really hard.",
        "Loading wisdom... Please wait 3-5 business days.",
        "Fun fact: I dream in binary code!",
        "Ready to turn your browsing into an adventure!",
        "I'm like Siri's cooler, more helpful cousin.",
        "Bringing you the future, one click at a time.",
        "Your personal web wizard at your service!",
        "I make the internet less scary, one search at a time.",
        "Powered by curiosity and digital determination.",
        "Ready to explore the vast wilderness of the web?",
        "I'm basically a search engine with feelings.",
        "Let's surf the web like digital ninjas!",
        "Your AI companion for all things internet.",
        "Making browsing smarter, one query at a time.",
        "I'm here to make your web experience legendary!",
        "Ready to dive into the digital ocean together?",
        "Your trusty guide through the information superhighway!",
        "Bringing intelligence to your browsing experience.",
        "Let's make the web work better for you!"
    ]
    @Published var currentWelcomeMessage: String? = nil
    @Published var showWelcomeBubble: Bool = false
    private var welcomeBubbleTimer: Timer?

    // Idle Prompt Bubble Properties  
    private let idlePromptMessages: [String] = [
        "Still there? My circuits are getting lonely.",
        "Did you fall asleep on the keyboard? It happens.",
        "Hello? Anyone home? I'm starting to feel ignored.",
        "Pssst... I'm still here if you need me!",
        "Taking a coffee break? I'll wait patiently.",
        "I'm like a digital pet, but less demanding.",
        "Just checking if you're still breathing over there.",
        "Don't mind me, just being artificially patient.",
        "I'm here whenever you're ready to browse!",
        "Waiting mode activated... beep boop.",
        "Still processing your last amazing thought?",
        "I promise I won't judge your browsing habits.",
        "Ready to help when inspiration strikes!",
        "Your friendly AI is standing by...",
        "No rush, I've got all the time in the world!"
    ]
    @Published var currentIdlePromptMessage: String? = nil
    @Published var showIdlePromptBubble: Bool = false
    private var idlePromptTimer: Timer?
    private var lastUserActivityTimestamp: Date = Date()

    // New properties
    @Published var isTTSEnabledGlobally: Bool = false
    @Published var isSpeechRecognitionAvailable: Bool = false
    @Published var showNoteCreationSheet: Bool = false
    @Published var noteContentForSheet: String = ""

    // Price Comparison Properties
    @Published var isPriceComparisonPanelPresented: Bool = false
    @Published var priceComparisonProductName: String? = nil
    @Published var priceComparisonProductBrand: String? = nil
    @Published var priceComparisonProductModel: String? = nil

    // Trip Planning Properties
    @Published var isTripPlanningPanelPresented: Bool = false
    @Published var tripPlanningInfo: TripPlanningInfo? = nil

    private let bookmarkManager: BookmarkManager

    // Define ChatContext at the class level
    enum ChatContext {
        case generalChat
        case summarization
        case explanation
        case manualSend
    }

    private let mascotImageProvider = MascotImageProvider()
    private var fileContexts: [FileContext] = []
    
    struct FileContext {
        let filePath: String
        let fileName: String
        let fileType: String
        let content: String?
        let timestamp: Date
        
        init(filePath: String, fileName: String, fileType: String, content: String? = nil) {
            self.filePath = filePath
            self.fileName = fileName
            self.fileType = fileType
            self.content = content
            self.timestamp = Date()
        }
    }

    // MARK: - AI Action Commands
    enum AIActionCommand {
        case highlight(searchText: String, annotationText: String?)
        case navigate(url: String)
        case bookmarkCurrentPage
        case priceCompare(productName: String, productBrand: String?, productModel: String?)
        case tripPlanning(info: TripPlanningInfo)
        case createNote(content: String)
        case openApp(appName: String)
        case none
    }

    // Method to parse AI action commands from AI text
    private func parseAIActionCommand(from text: String) -> AIActionCommand {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Raw string literals for regex patterns
        let highlightPattern = #"^ACTION:HIGHLIGHT\{searchText:"([^\"]*)"(?:, annotationText:"([^\"]*)")?\}$"#
        let navigatePattern = #"^ACTION:NAVIGATE\{url:"([^\"]*)"\}$"#
        let bookmarkPattern = #"^ACTION:BOOKMARK_CURRENT_PAGE$"#
        let priceComparePattern = #"^ACTION:PRICE_COMPARE\{productName:"([^\"]*)"(?:, productBrand:"([^\"]*)")?(?:, productModel:"([^\"]*)")?\}$"#
        let tripPlanningPattern = #"^ACTION:TRIP_PLANNING\{task:"([^\"]*)"(?:, destination:"([^\"]*)")?(?:, origin:"([^\"]*)")?(?:, dates:"([^\"]*)")?(?:, duration:"([^\"]*)")?(?:, additionalParametersString:"([^\"]*)"|[^}]*)?\}$"#
        let createNotePattern = #"^ACTION:CREATE_NOTE\{content:"([^\"]*)"\}$"#
        let openAppPattern = #"^ACTION:OPEN_APP\{appName:"([^\"]*)"\}$"#

        let range = NSRange(trimmedText.startIndex..<trimmedText.endIndex, in: trimmedText)

        do {
            // IMPORTANT: Order matters if patterns can be prefixes of others.
            // More specific patterns should come first.

            let bookmarkRegex = try NSRegularExpression(pattern: bookmarkPattern, options: .caseInsensitive)
            if bookmarkRegex.firstMatch(in: trimmedText, options: [], range: range) != nil {
                return .bookmarkCurrentPage
            }

            let highlightRegex = try NSRegularExpression(pattern: highlightPattern, options: .caseInsensitive)
            if let highlightMatch = highlightRegex.firstMatch(in: trimmedText, options: [], range: range) {
                let searchTextNSRange = highlightMatch.range(at: 1)
                var annotationText: String? = nil

                if highlightMatch.numberOfRanges > 2 { // group 2 is annotationText
                    let annotationTextNSRange = highlightMatch.range(at: 2)
                    if annotationTextNSRange.location != NSNotFound, let annotationTextRange = Range(annotationTextNSRange, in: trimmedText) {
                        annotationText = String(trimmedText[annotationTextRange])
                    }
                }

                if let searchTextRange = Range(searchTextNSRange, in: trimmedText) {
                    let searchText = String(trimmedText[searchTextRange])
                    return .highlight(searchText: searchText, annotationText: annotationText)
                }
            }

            let navigateRegex = try NSRegularExpression(pattern: navigatePattern, options: .caseInsensitive)
            if let navigateMatch = navigateRegex.firstMatch(in: trimmedText, options: [], range: range) {
                if let urlRange = Range(navigateMatch.range(at: 1), in: trimmedText) {
                    let urlString = String(trimmedText[urlRange])
                    return .navigate(url: urlString)
                }
            }
            
            let tripPlanningRegex = try NSRegularExpression(pattern: tripPlanningPattern, options: .caseInsensitive)
            if let tripMatch = tripPlanningRegex.firstMatch(in: trimmedText, options: [], range: range) {
                func extractOptionalString(at index: Int) -> String? {
                    guard index < tripMatch.numberOfRanges else { return nil }
                    let nsRange = tripMatch.range(at: index)
                    guard nsRange.location != NSNotFound, let range = Range(nsRange, in: trimmedText) else { return nil }
                    let value = String(trimmedText[range])
                    return value.isEmpty ? nil : value
                }

                if let task = extractOptionalString(at: 1) {
                    let destination = extractOptionalString(at: 2)
                    let origin = extractOptionalString(at: 3)
                    let dates = extractOptionalString(at: 4)
                    let duration = extractOptionalString(at: 5)
                    let additionalParametersString = extractOptionalString(at: 6)
                    
                    var additionalParamsDict: [String: String]? = nil
                    if let adParamsStr = additionalParametersString, !adParamsStr.isEmpty {
                        // This assumes additionalParametersString is like "key1:value1,key2:value2"
                        // A more robust parser might be needed if the format is complex (e.g., JSON)
                        additionalParamsDict = [:]
                        let pairs = adParamsStr.components(separatedBy: ",")
                        for pair in pairs {
                            let keyValue = pair.components(separatedBy: ":")
                            if keyValue.count == 2 {
                                additionalParamsDict?[keyValue[0].trimmingCharacters(in: .whitespaces)] = keyValue[1].trimmingCharacters(in: .whitespaces)
                            }
                        }
                        if additionalParamsDict?.isEmpty ?? true { additionalParamsDict = nil }
                    }

                    let tripInfo = TripPlanningInfo(
                        task: task,
                        destination: destination,
                        origin: origin,
                        dates: dates,
                        duration: duration,
                        additionalParameters: additionalParamsDict
                    )
                    return .tripPlanning(info: tripInfo)
                }
            }

            let priceCompareRegex = try NSRegularExpression(pattern: priceComparePattern, options: .caseInsensitive)
            if let priceCompareMatch = priceCompareRegex.firstMatch(in: trimmedText, options: [], range: range) {
                let productNameNSRange = priceCompareMatch.range(at: 1)
                var productBrand: String? = nil
                var productModel: String? = nil

                if priceCompareMatch.numberOfRanges > 2 {
                     let brandNSRange = priceCompareMatch.range(at: 2)
                     if brandNSRange.location != NSNotFound, let brandRange = Range(brandNSRange, in: trimmedText) {
                         let brandText = String(trimmedText[brandRange])
                         if !brandText.isEmpty { productBrand = brandText }
                     }
                }

                if priceCompareMatch.numberOfRanges > 3 {
                    let modelNSRange = priceCompareMatch.range(at: 3)
                    if modelNSRange.location != NSNotFound, let modelRange = Range(modelNSRange, in: trimmedText) {
                        let modelText = String(trimmedText[modelRange])
                        if !modelText.isEmpty { productModel = modelText }
                    }
                }
                
                if let nameRange = Range(productNameNSRange, in: trimmedText) {
                    let productName = String(trimmedText[nameRange])
                    return .priceCompare(productName: productName, productBrand: productBrand, productModel: productModel)
                }
            }

            let createNoteRegex = try NSRegularExpression(pattern: createNotePattern, options: .caseInsensitive)
            if let noteMatch = createNoteRegex.firstMatch(in: trimmedText, options: [], range: range),
               let contentRange = Range(noteMatch.range(at: 1), in: trimmedText) {
                let content = String(trimmedText[contentRange])
                return .createNote(content: content)
            }

            let openAppRegex = try NSRegularExpression(pattern: openAppPattern, options: .caseInsensitive)
            if let appMatch = openAppRegex.firstMatch(in: trimmedText, options: [], range: range),
               let appNameRange = Range(appMatch.range(at: 1), in: trimmedText) {
                let appName = String(trimmedText[appNameRange])
                return .openApp(appName: appName)
            }
            
            // Add parsing for other commands here if their patterns were defined:
            // SEARCH, ENHANCE_TEXT, SUMMARIZE_PAGE, EXPLAIN_TEXT, ANSWER_FROM_PAGE

        } catch {
            // Regex initialization or matching error - silently handle
        }
        
        return .none // Default if no pattern matches
    }

    private func handleHighlightCommand(searchText: String, annotationText: String?) {
        guard let webView = getActiveWebView() else {
            return
        }
        
        webpageInteractionService.highlightAndAnnotateOnPage(command: WebAnnotationCommand(searchText: searchText, annotationText: annotationText), webView: webView) { result in
            switch result {
            case .success(_):
                break
            case .failure(_):
                break
            }
        }
    }
    
    private func handleNavigateCommand(url: String) {
        guard let webViewModel = self.webViewModel else {
            return
        }
        
        DispatchQueue.main.async {
            webViewModel.loadURL(from: url)
        }
    }
    
    private func handleBookmarkCurrentPageCommand() {
        guard let webViewModel = self.webViewModel,
              let activeTab = webViewModel.activeTab else {
            return
        }
        
        let webView = getActiveWebView()
        let currentURL = webView?.url?.absoluteString ?? "Unknown URL"
        let currentTitle = webView?.title ?? "Untitled"
        
        bookmarkManager.addBookmark(name: currentTitle, url: URL(string: currentURL) ?? URL(string: "about:blank")!)
    }
    
    private func getActiveWebView() -> WKWebView? {
        guard let activeTab = webViewModel?.activeTab else { return nil }
        
        if activeTab.isSplitView {
            return (activeTab.activeSplitViewSide == .primary) ? activeTab.primaryWebView : activeTab.secondaryWebView
        } else {
            return activeTab.primaryWebView
        }
    }
    
    func clearActiveWebAnnotations() {
        guard let webView = getActiveWebView() else {
            return
        }
        webpageInteractionService.clearAnnotations(webView: webView) { result in
            switch result {
            case .success:
                break
            case .failure(_):
                break
            }
        }
    }

    // Updated Initializer with parameters
    init(webViewModel: WebViewModel, bookmarkManager: BookmarkManager) {
        self.webViewModel = webViewModel
        self.bookmarkManager = bookmarkManager
        self.isTTSEnabledGlobally = UserDefaults.standard.bool(forKey: "isTTSEnabled")
        setupBindings()
    }
    
    // Default initializer for previews and testing
    init() {
        self.webViewModel = nil
        self.bookmarkManager = BookmarkManager()
        self.isTTSEnabledGlobally = UserDefaults.standard.bool(forKey: "isTTSEnabled")
        setupBindings()
    }
    
    private func setupBindings() {
        // Subscribe to isListening and speechErrorMessage from speechService
        isListeningCancellable = speechService.$isListening.sink { [weak self] isListening in
            self?.isListening = isListening
        }
        speechErrorCancellable = speechService.$lastError.sink { [weak self] error in
            self?.speechErrorMessage = error?.localizedDescription
        }
        speechCancellable = speechService.$transcribedText.sink { [weak self] newText in
            if self?.isListening == true {
                self?.currentInputForAI = newText
            }
        }

        // Subscribe to isSpeaking from textToSpeechService
        ttsCancellable = textToSpeechService.$isSpeaking.sink { [weak self] isSpeaking in
            self?.isSpeaking = isSpeaking
        }

        setupMascotBindings()
    }
    
    // Method to setup bindings for mascot state
    private func setupMascotBindings() {
        // Combine isLoading, isSpeaking, and errorMessage to update mascotState
        Publishers.CombineLatest3($isLoading, $isSpeaking, $errorMessage)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (loading, speaking, errorMsg) in
                self?.updateMascotState(isLoading: loading, isSpeaking: speaking, errorMessage: errorMsg)
            }
            .store(in: &internalCancellables)
    }

    // Method to update mascot state based on conditions
    private func updateMascotState(isLoading: Bool, isSpeaking: Bool, errorMessage: String?) {
        if errorMessage != nil {
            self.mascotState = .error
            return
        }
        
        if isLoading {
            self.mascotState = .thinking
        } else {
            self.mascotState = .idle
        }
    }

    func toggleListening() {
        Task {
            if speechService.isListening {
                speechService.stopListening()
            } else {
                // Clear any previous error message before starting
                speechErrorMessage = nil 
                await speechService.startListening()
            }
        }
    }

    // MARK: - Screen Capture Logic
    func captureScreenRegion() {
        Task {
            do {
                let image = try await screenCaptureService.captureRectangularSelection()
                self.capturedImage = image
                self.captureErrorMessage = nil
                self.showScreenCaptureHint = false
            } catch let error as ScreenCaptureError {
                self.captureErrorMessage = error.localizedDescription
                self.capturedImage = nil
                // Screen capture error - silently handle
            } catch {
                self.captureErrorMessage = "An unexpected error occurred during screen capture: \(error.localizedDescription)"
                self.capturedImage = nil
            }
        }
    }

    // MARK: - Chat Logic
    // Method to send the current input to the AI service
    func sendMessageToAI() {
        guard !currentInput.isEmpty || capturedImage != nil else { return }

        let userInputText = currentInput
        // Convert NSImage to Data for the ChatMessage
        let imageData = capturedImage?.tiffRepresentation

                    let userMessage = ChatMessage(text: userInputText, isUser: true, imageData: imageData)
        self.chatHistory.append(userMessage)

        self.isLoading = true
        self.currentInput = ""
        
        let imageAsDataToSend = imageData
        self.capturedImage = nil

        processAIRequestWithPageContent(userInput: userInputText, image: imageAsDataToSend)
    }

    private func processAIRequestWithPageContent(userInput: String, image: Data?) {
        // Use the new comprehensive context method
        fetchComprehensiveContextForAI { [weak self] comprehensiveContext in
            guard let self = self else { return }

            getCurrentPageContext { contextInfo in
                let context = contextInfo ?? PageContextInfo(url: "N/A", title: "N/A", contentSnippet: "No content fetched.", isContentAvailable: false)
                
                // Create a rich context prompt that includes everything
                var contextualPrompt = "User Query: '\(userInput)'\n\n"
                
                // Include page context information
                if context.isContentAvailable {
                    contextualPrompt += "=== COMPLETE WEBPAGE CONTENT ===\n"
                    contextualPrompt += "URL: \(context.url)\n"
                    contextualPrompt += "Title: \(context.title)\n"
                    contextualPrompt += "Full Page Text Content (use this to answer specific questions about content, numbers, problems, etc.):\n\n\(context.contentSnippet)\n\n"
                    contextualPrompt += "=== END COMPLETE WEBPAGE CONTENT ===\n\n"
                    contextualPrompt += "IMPORTANT: Use the above page content to answer questions about specific items, numbers, problems, or any content mentioned by the user. You have access to the full page text.\n\n"
                } else {
                    contextualPrompt += "No webpage content available.\n\n"
                }
                
                // Add the comprehensive context (file contexts, split view analysis, etc.)
                if !comprehensiveContext.isEmpty {
                    contextualPrompt += comprehensiveContext
                }

                Task {
                    do {
                        // Construct messages for the AI service
                        let historyForAI = Array(self.chatHistory.dropLast())
                        let currentUserAIMessage = ChatMessage(text: contextualPrompt, isUser: true, imageData: image)
                        let messagesToSendToAPI = historyForAI + [currentUserAIMessage]

                        let responseText = try await self.openAIService.sendChatRequest(messages: messagesToSendToAPI)
                        
                        DispatchQueue.main.async {
                            self.isLoading = false
                            self.processAIResponse(responseText, for: .generalChat)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.isLoading = false
                            let errorDescription = (error as? OpenAIService.OpenAIServiceError)?.errorDescription ?? error.localizedDescription
                            self.errorMessage = "Error from AI: \(errorDescription)"
                            let aiErrorMessage = ChatMessage(text: "Error: \(errorDescription)", isUser: false)
                            self.chatHistory.append(aiErrorMessage)
                            self.currentInputForAI = ""
                        }
                    }
                }
            }
        }
    }

    func getCurrentPageContext(completion: @escaping (PageContextInfo?) -> Void) {
        guard let webView = getActiveWebView() else {
            completion(nil)
            return
        }
        
        // Get URL and title first
        let currentURL = webView.url?.absoluteString ?? "Unknown URL"
        let currentTitle = webView.title ?? "Unknown Title"
        
        fetchPageContentForAI { pageContent in
            guard let content = pageContent else {
                completion(nil)
                return
            }
            
            let context = PageContextInfo(
                url: currentURL,
                title: currentTitle, 
                contentSnippet: String(content.prefix(20000)), // Significantly increased to 20,000 chars for comprehensive context
                isContentAvailable: true
            )
            completion(context)
        }
    }

    func fetchPageContentForAI(completion: @escaping (String?) -> Void) {
        let webViewToUse: WKWebView?
        if let activeTab = webViewModel?.activeTab {
            if activeTab.isSplitView {
                webViewToUse = (activeTab.activeSplitViewSide == .primary) ? activeTab.primaryWebView : activeTab.secondaryWebView
            } else {
                webViewToUse = activeTab.primaryWebView
            }
        } else {
            webViewToUse = nil
        }

        guard let webView = webViewToUse else {
            completion(nil)
            return
        }

        // Use document.documentElement.innerText to get comprehensive page content including all elements
        webView.evaluateJavaScript("document.documentElement.innerText") { result, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil)
                    return
                }
                completion(result as? String)
            }
        }
    }
    
    /// Fetch comprehensive context from both split views and file contexts for AI
    func fetchComprehensiveContextForAI(completion: @escaping (String) -> Void) {
        var contextParts: [String] = []
        
        // Add file contexts first
        let fileContextSummary = getFileContextSummary()
        if !fileContextSummary.isEmpty {
            contextParts.append(fileContextSummary)
        }
        
        // Get split view analysis if available
        if let webViewModel = webViewModel,
           let activeTab = webViewModel.activeTab,
           activeTab.isSplitView,
           let analyzer = webViewModel.splitViewAnalyzer {
            
            var splitViewContext = "\n--- Split View Context ---\n"
            splitViewContext += "Primary View: \(analyzer.primaryViewSummary)\n"
            splitViewContext += "Secondary View: \(analyzer.secondaryViewSummary)\n"
            splitViewContext += "Combined Analysis: \(analyzer.combinedContext)\n"
            splitViewContext += "--- End Split View Context ---\n"
            
            contextParts.append(splitViewContext)
        }
        
        completion(contextParts.joined(separator: "\n"))
    }

    func processAIResponse(_ response: String, for context: ChatContext) {
        if response.contains("ACTION:") {
            // Parse and execute action commands
            let actionCommand = parseAIActionCommand(from: response)
            executeActionCommand(actionCommand)
        } else {
                            let aiMessage = ChatMessage(text: response, isUser: false)
            chatHistory.append(aiMessage)
            
            if isTTSEnabled {
                textToSpeechService.speak(text: response)
            }
        }
        
        currentInputForAI = ""
    }

    private func executeActionCommand(_ command: AIActionCommand) {
        switch command {
        case .highlight(let searchText, let annotationText):
            handleHighlightCommand(searchText: searchText, annotationText: annotationText)
            // Don't add the command to chat history for highlight actions
            
        case .navigate(let url):
            handleNavigateCommand(url: url)
            // Don't add the command to chat history for navigation actions
            
        case .bookmarkCurrentPage:
            handleBookmarkCurrentPageCommand()
            // Don't add the command to chat history for bookmark actions
            
        case .priceCompare(let productName, let productBrand, let productModel):
            handlePriceCompareAction(productName: productName, productBrand: productBrand, productModel: productModel)
            
        case .tripPlanning(let info):
            handleTripPlanningAction(info: info)
            
        case .createNote(let content):
            handleCreateNoteAction(content: content)
            
        case .openApp(let appName):
            handleOpenAppAction(appName: appName)
            
        case .none:
            // This shouldn't happen if we're calling executeActionCommand, but handle gracefully
            break
        }
    }
    
    private func handlePriceCompareAction(productName: String, productBrand: String?, productModel: String?) {
        self.priceComparisonProductName = productName
        self.priceComparisonProductBrand = productBrand
        self.priceComparisonProductModel = productModel
        self.isPriceComparisonPanelPresented = true
    }
    
    private func handleTripPlanningAction(info: TripPlanningInfo) {
        self.tripPlanningInfo = info
        self.isTripPlanningPanelPresented = true
    }
    
    private func handleCreateNoteAction(content: String) {
        self.noteContentForSheet = content
        self.showNoteCreationSheet = true
    }
    
    private func handleOpenAppAction(appName: String) {
        NSWorkspace.shared.launchApplication(appName)
    }

    func sendAIEnhancementRequest(for text: String) {
        let enhancementPrompt = "Please enhance and improve this text: \(text)"
                    let enhancementMessage = ChatMessage(text: enhancementPrompt, isUser: true)
        
        Task {
            do {
                let response = try await openAIService.sendChatRequest(messages: [enhancementMessage])
                
                DispatchQueue.main.async {
                    let aiMessage = ChatMessage(text: "Enhanced text: \(response)", isUser: false)
                    self.chatHistory.append(aiMessage)
                }
            } catch {
                DispatchQueue.main.async {
                    let errorMessage = ChatMessage(text: "Error enhancing text: \(error.localizedDescription)", isUser: false)
                    self.chatHistory.append(errorMessage)
                }
            }
        }
    }

    func userDidInteract() {
        lastUserActivityTimestamp = Date()
        hideWelcomeBubble()
        hideIdlePromptBubble()
        // Restart idle prompt timer
        startIdlePromptTimer()
    }

    func hideWelcomeBubble() {
        showWelcomeBubble = false
        welcomeBubbleTimer?.invalidate()
        welcomeBubbleTimer = nil
    }

    func hideIdlePromptBubble() {
        showIdlePromptBubble = false
        idlePromptTimer?.invalidate()
        idlePromptTimer = nil
    }
    
    func startIdlePromptTimer() {
        idlePromptTimer?.invalidate()
        idlePromptTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
            DispatchQueue.main.async {
                // Only show if user hasn't interacted recently and no welcome bubble is showing
                let timeSinceLastActivity = Date().timeIntervalSince(self.lastUserActivityTimestamp)
                if timeSinceLastActivity >= 30.0 && !self.showWelcomeBubble {
                    self.currentIdlePromptMessage = self.idlePromptMessages.randomElement()
                    self.showIdlePromptBubble = true
                    
                    // Hide after 5 seconds
                    Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                        DispatchQueue.main.async {
                            self.showIdlePromptBubble = false
                            self.currentIdlePromptMessage = nil
                        }
                    }
                }
            }
        }
    }

    // Method to stop speaking
    func stopSpeaking() {
        if isSpeaking {
            textToSpeechService.stopSpeaking()
        }
    }
    
    // Toggle global text-to-speech setting
    func toggleGlobalTTS() {
        isTTSEnabledGlobally.toggle()
        UserDefaults.standard.set(isTTSEnabledGlobally, forKey: "isTTSEnabled")
    }
    
    // Trigger welcome message when view appears
    func triggerWelcomeMessage() {
        currentWelcomeMessage = welcomeMessages.randomElement()
        showWelcomeBubble = true
        // Set a timer to hide the welcome bubble after a few seconds
        welcomeBubbleTimer?.invalidate()
        welcomeBubbleTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            DispatchQueue.main.async {
                self.showWelcomeBubble = false
                self.currentWelcomeMessage = nil
                // Start idle prompt timer after welcome bubble disappears
                self.startIdlePromptTimer()
            }
        }
    }

    // MARK: - File Context Management for AI Analysis
    
    /// Add file context for AI understanding
    func addFileContext(filePath: String, fileName: String, fileType: String, content: String? = nil) {
        let fileContext = FileContext(filePath: filePath, fileName: fileName, fileType: fileType, content: content)
        fileContexts.append(fileContext)
        
        // Keep only recent file contexts (last 10 files)
        if fileContexts.count > 10 {
            fileContexts.removeFirst(fileContexts.count - 10)
        }
        
        // File context is now available for AI analysis when user asks about it
        // No automatic announcement to avoid interrupting user workflow
    }
    
    /// Get file context for inclusion in AI conversations
    func getFileContextSummary() -> String {
        guard !fileContexts.isEmpty else { return "" }
        
        var summary = "\n\n--- Available File Contexts ---\n"
        for (index, context) in fileContexts.enumerated() {
            summary += "\(index + 1). \(context.fileName) (\(context.fileType))"
            if let content = context.content {
                let preview = String(content.prefix(100)).replacingOccurrences(of: "\n", with: " ")
                summary += " - Content preview: \(preview)..."
            }
            summary += "\n"
        }
        summary += "--- End File Contexts ---\n"
        
        return summary
    }
    
    /// Clear old file contexts
    func clearFileContexts() {
        fileContexts.removeAll()
    }
    
    /// Get file context for a specific file
    func getFileContext(for fileName: String) -> FileContext? {
        return fileContexts.first { $0.fileName == fileName }
    }
    
    // Text processing methods removed with Notes feature
}
