import Foundation
import SwiftUI
import WebKit
import Combine

@MainActor
class SplitViewAnalyzer: ObservableObject {
    @Published var primaryViewSummary: String = ""
    @Published var secondaryViewSummary: String = ""
    @Published var combinedContext: String = ""
    @Published var isAnalyzing: Bool = false
    @Published var lastAnalysisTime: Date?
    
    private var analysisTimer: Timer?
    private var webViewObservers: Set<AnyCancellable> = []
    private let assistantViewModel: AssistantViewModel
    private let debounceDelay: TimeInterval = 2.0 // Wait 2 seconds after content changes
    
    init(assistantViewModel: AssistantViewModel) {
        self.assistantViewModel = assistantViewModel
    }
    
    // MARK: - Public Interface
    
    func startMonitoring(primaryWebView: WKWebView?, secondaryWebView: WKWebView?) {
        print("SplitViewAnalyzer: Starting monitoring of split view content")
        stopMonitoring()
        
        guard let primary = primaryWebView else {
            print("SplitViewAnalyzer: No primary web view to monitor")
            return
        }
        
        // Set up content change monitoring
        setupContentMonitoring(primary: primary, secondary: secondaryWebView)
        
        // Perform initial analysis
        performAnalysis(primary: primary, secondary: secondaryWebView)
    }
    
    func stopMonitoring() {
        print("SplitViewAnalyzer: Stopping split view monitoring")
        analysisTimer?.invalidate()
        analysisTimer = nil
        webViewObservers.removeAll()
    }
    
    func requestManualAnalysis(primaryWebView: WKWebView?, secondaryWebView: WKWebView?) {
        guard let primary = primaryWebView else { return }
        performAnalysis(primary: primary, secondary: secondaryWebView)
    }
    
    // MARK: - Content Monitoring
    
    private func setupContentMonitoring(primary: WKWebView, secondary: WKWebView?) {
        // Monitor URL changes in primary view
        primary.publisher(for: \.url)
            .debounce(for: .seconds(debounceDelay), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleAnalysis(primary: primary, secondary: secondary)
            }
            .store(in: &webViewObservers)
        
        // Monitor loading state changes
        primary.publisher(for: \.isLoading)
            .filter { !$0 } // Only when loading finishes
            .debounce(for: .seconds(debounceDelay), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleAnalysis(primary: primary, secondary: secondary)
            }
            .store(in: &webViewObservers)
        
        if let secondary = secondary {
            // Monitor secondary view as well
            secondary.publisher(for: \.url)
                .debounce(for: .seconds(debounceDelay), scheduler: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.scheduleAnalysis(primary: primary, secondary: secondary)
                }
                .store(in: &webViewObservers)
            
            secondary.publisher(for: \.isLoading)
                .filter { !$0 }
                .debounce(for: .seconds(debounceDelay), scheduler: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.scheduleAnalysis(primary: primary, secondary: secondary)
                }
                .store(in: &webViewObservers)
        }
    }
    
    private func scheduleAnalysis(primary: WKWebView, secondary: WKWebView?) {
        // Cancel existing timer
        analysisTimer?.invalidate()
        
        // Schedule new analysis
        analysisTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.performAnalysis(primary: primary, secondary: secondary)
            }
        }
    }
    
    // MARK: - Content Analysis
    
    private func performAnalysis(primary: WKWebView, secondary: WKWebView?) {
        guard !isAnalyzing else {
            print("SplitViewAnalyzer: Analysis already in progress, skipping")
            return
        }
        
        isAnalyzing = true
        
        Task {
            // Extract content from both views
            let primaryContent = await extractContent(from: primary, viewType: "primary")
            let secondaryContent = secondary != nil ? await extractContent(from: secondary!, viewType: "secondary") : nil
            
            // Generate summaries and combined context
            await generateAnalysis(
                primaryContent: primaryContent,
                secondaryContent: secondaryContent,
                primaryURL: primary.url?.absoluteString ?? "",
                secondaryURL: secondary?.url?.absoluteString
            )
            
            await MainActor.run {
                self.isAnalyzing = false
                self.lastAnalysisTime = Date()
            }
        }
    }
    
    private func extractContent(from webView: WKWebView, viewType: String) async -> String {
        return await withCheckedContinuation { continuation in
            // First, try to get file content if this is a file view
            let url = webView.url?.absoluteString ?? ""
            let isFileURL = url.hasPrefix("file://")
            
            if isFileURL {
                // Extract file-specific content
                extractFileContent(from: webView, url: url, viewType: viewType) { content in
                    continuation.resume(returning: content)
                }
                return
            }
            
            // Standard web content extraction
            let script = """
            (function() {
                try {
                    // Extract main content, avoiding navigation and ads
                    var content = '';
                    
                    // Try to get main content areas
                    var mainSelectors = [
                        'main', 'article', '[role="main"]', 
                        '.content', '#content', '.main-content',
                        '.post-content', '.entry-content',
                        'h1, h2, h3, h4, h5, h6', 'p'
                    ];
                    
                    var contentElements = [];
                    mainSelectors.forEach(function(selector) {
                        var elements = document.querySelectorAll(selector);
                        elements.forEach(function(el) {
                            if (el.offsetHeight > 0 && el.offsetWidth > 0) { // Visible elements only
                                contentElements.push(el);
                            }
                        });
                    });
                    
                    // Extract text content
                    var textContent = [];
                    contentElements.forEach(function(el) {
                        var text = el.textContent.trim();
                        if (text.length > 20 && !textContent.includes(text)) {
                            textContent.push(text);
                        }
                    });
                    
                    // Also check for video content
                    var videos = document.querySelectorAll('video');
                    if (videos.length > 0) {
                        textContent.unshift('[VIDEO CONTENT DETECTED]');
                        videos.forEach(function(video, index) {
                            var title = video.title || video.getAttribute('aria-label') || 'Video ' + (index + 1);
                            textContent.push('Video: ' + title);
                        });
                    }
                    
                    // Check for PDF content
                    if (document.contentType && document.contentType.includes('pdf')) {
                        textContent.unshift('[PDF DOCUMENT DETECTED]');
                    }
                    
                    // Add page title and URL context
                    textContent.unshift('Page: ' + (document.title || 'Untitled'));
                    textContent.unshift('URL: ' + window.location.href);
                    
                    return textContent.join('\\n\\n').substring(0, 4000); // Limit content size
                } catch (error) {
                    return 'Error extracting content: ' + error.message;
                }
            })();
            """
            
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("SplitViewAnalyzer: Error extracting content from \(viewType) view - \(error)")
                    continuation.resume(returning: "Could not extract content from \(viewType) view")
                } else if let content = result as? String, !content.isEmpty {
                    continuation.resume(returning: content)
                } else {
                    continuation.resume(returning: "No content found in \(viewType) view")
                }
            }
        }
    }
    
    private func extractFileContent(from webView: WKWebView, url: String, viewType: String, completion: @escaping (String) -> Void) {
        // Extract filename and type from URL
        guard let fileURL = URL(string: url) else {
            completion("Unable to parse file URL from \(viewType) view")
            return
        }
        
        let fileName = fileURL.lastPathComponent
        let fileExtension = fileURL.pathExtension.lowercased()
        
        // Check if we have file context from AssistantViewModel
        if let fileContext = assistantViewModel.getFileContext(for: fileName) {
            
            var content = "[\(fileExtension.uppercased()) FILE: \(fileName)]\n"
            content += "URL: \(url)\n"
            
            if let extractedContent = fileContext.content, !extractedContent.isEmpty {
                content += "File Content:\n\(extractedContent.prefix(3000))" // Limit content size
            } else {
                content += "File Type: \(fileExtension.capitalized) document\n"
                content += "Status: File loaded but content extraction pending"
            }
            
            completion(content)
            return
        }
        
        // Fallback: Try to extract content directly from WebView
        let script = """
        (function() {
            try {
                var content = '';
                
                // For PDF files, try to get visible text
                if (window.location.href.toLowerCase().includes('.pdf')) {
                    content = '[PDF DOCUMENT: \(fileName)]\\n';
                    content += 'URL: ' + window.location.href + '\\n';
                    
                    // Try to extract any visible text from PDF viewer
                    var textElements = document.querySelectorAll('div, span, p');
                    var extractedText = [];
                    for (var i = 0; i < Math.min(textElements.length, 50); i++) {
                        var text = textElements[i].textContent.trim();
                        if (text.length > 10 && !extractedText.includes(text)) {
                            extractedText.push(text);
                        }
                    }
                    if (extractedText.length > 0) {
                        content += 'Visible Text: ' + extractedText.slice(0, 10).join(' ');
                    }
                    return content;
                }
                
                // For other file types, get basic info
                content = '[\(fileExtension.uppercased()) FILE: \(fileName)]\\n';
                content += 'URL: ' + window.location.href + '\\n';
                content += 'File Type: \(fileExtension.capitalized) document\\n';
                
                // Try to get any visible content
                var bodyText = document.body.textContent.trim();
                if (bodyText.length > 0) {
                    content += 'Content: ' + bodyText.substring(0, 1000);
                }
                
                return content;
            } catch (error) {
                return '[\(fileExtension.uppercased()) FILE: \(fileName)]\\nError extracting file content: ' + error.message;
            }
        })();
        """
        
        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("SplitViewAnalyzer: Error extracting file content from \(viewType) view - \(error)")
                completion("[\(fileExtension.uppercased()) FILE: \(fileName)] - Error extracting content")
            } else if let content = result as? String, !content.isEmpty {
                completion(content)
            } else {
                completion("[\(fileExtension.uppercased()) FILE: \(fileName)] - No content extracted")
            }
        }
    }
    
    private func generateAnalysis(
        primaryContent: String,
        secondaryContent: String?,
        primaryURL: String,
        secondaryURL: String?
    ) async {
        let prompt = buildAnalysisPrompt(
            primaryContent: primaryContent,
            secondaryContent: secondaryContent,
            primaryURL: primaryURL,
            secondaryURL: secondaryURL
        )
        
        do {
            // Create a chat message for the analysis
            let chatMessage = ChatMessage(text: prompt, isUser: true)
            let openAIService = OpenAIService()
            let response = try await openAIService.sendChatRequest(messages: [chatMessage])
            await parseAndUpdateAnalysis(response)
        } catch {
            print("SplitViewAnalyzer: Error generating AI analysis - \(error)")
            await MainActor.run {
                self.combinedContext = "Analysis temporarily unavailable. Please try again."
            }
        }
    }
    
    private func buildAnalysisPrompt(
        primaryContent: String,
        secondaryContent: String?,
        primaryURL: String,
        secondaryURL: String?
    ) -> String {
        var prompt = """
        Analyze the following content from a split-view browser and provide real-time summaries and context.
        
        PRIMARY VIEW (\(primaryURL)):
        \(primaryContent)
        """
        
        if let secondaryContent = secondaryContent, let secondaryURL = secondaryURL {
            prompt += """
            
            SECONDARY VIEW (\(secondaryURL)):
            \(secondaryContent)
            """
        }
        
        prompt += """
        
        Please provide your analysis in the following JSON format:
        {
            "primarySummary": "Brief 2-3 sentence summary of the primary view content",
            "secondarySummary": "Brief 2-3 sentence summary of the secondary view content (or null if no secondary view)",
            "combinedContext": "How these two pieces of content relate to each other, potential connections, complementary information, or insights that emerge from viewing them together. Focus on actionable insights and cross-references."
        }
        
        Focus on:
        - Key points and main ideas from each view
        - Connections and relationships between the content
        - Complementary information that enhances understanding
        - Actionable insights for the user
        - Any contradictions or differing perspectives
        
        Respond only with valid JSON.
        """
        
        return prompt
    }
    
    private func parseAndUpdateAnalysis(_ response: String) async {
        await MainActor.run {
            self.isAnalyzing = false
            self.lastAnalysisTime = Date()
        }
        
        do {
            // Strip markdown code blocks if present
            let cleanedResponse = response
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json\n", with: "")
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "\n```", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("SplitViewAnalyzer: Cleaned response for parsing: \(cleanedResponse)")
            
            let data = Data(cleanedResponse.utf8)
            let analysisResult = try JSONDecoder().decode(AnalysisResult.self, from: data)
            
            await MainActor.run {
                self.primaryViewSummary = analysisResult.primarySummary
                self.secondaryViewSummary = analysisResult.secondarySummary ?? "No secondary content available"
                self.combinedContext = analysisResult.combinedContext
                print("SplitViewAnalyzer: Successfully updated analysis")
            }
        } catch {
            print("SplitViewAnalyzer: Error parsing analysis response - \(error)")
            await MainActor.run {
                self.combinedContext = "Error parsing analysis response. Please try again."
                self.primaryViewSummary = "Analysis temporarily unavailable."
                self.secondaryViewSummary = "Analysis temporarily unavailable."
            }
        }
    }
}

// MARK: - Supporting Types

struct SplitViewAnalysis {
    let primarySummary: String
    let secondarySummary: String?
    let combinedContext: String
    let timestamp: Date
    let primaryURL: String
    let secondaryURL: String?
}

// MARK: - Analysis Response Model

private struct AnalysisResult: Codable {
    let primarySummary: String
    let secondarySummary: String?
    let combinedContext: String
} 