import Foundation
import WebKit

struct WebAnnotationCommand {
    let searchText: String
    let annotationText: String?
}

class WebpageInteractionService {

    private func getJavaScriptFunctions() -> String {
        // Restoring original JavaScript implementation
        return #"""
        var iBrowsyPageInteractor = {
            currentHighlights: [],
            currentAnnotations: [],

            clearAnnotations: function() {
                this.currentHighlights.forEach(span => {
                    if (span.parentNode) {
                        const parent = span.parentNode;
                        while (span.firstChild) {
                            parent.insertBefore(span.firstChild, span);
                        }
                        parent.removeChild(span);
                        parent.normalize();
                    }
                });
                this.currentHighlights = [];

                this.currentAnnotations.forEach(anno => {
                    if (anno.parentNode) {
                        anno.parentNode.removeChild(anno);
                    }
                });
                this.currentAnnotations = [];
            },

            highlightAndAnnotate: function(searchText, annotationText) {
                console.log(`[iBrowsy JS] highlightAndAnnotate CALLED. Original SearchText: "${searchText}", AnnotationText: "${annotationText}"`);
                try {
                    this.clearAnnotations();
                    if (!searchText || searchText.trim() === '') {
                        console.log("[iBrowsy JS] Search text is empty or whitespace.");
                        return "Search text is empty.";
                    }

                    // Normalize and prepare the search text
                    let preparedSearchText = searchText.trim();
                    preparedSearchText = preparedSearchText.replace(/\\u00A0/g, ' '); // Normalize non-breaking spaces
                    
                    // Split into individual words for potential partial matching
                    const searchWords = preparedSearchText.split(/\\s+/).filter(word => word.length > 0);
                    if (searchWords.length === 0) {
                        console.log("[iBrowsy JS] Search text resulted in no usable words after processing.");
                        return "Search text is effectively empty.";
                    }
                    console.log(`[iBrowsy JS] Search terms parsed into ${searchWords.length} words.`);
                    
                    // Create a map of visible elements and their text content
                    const visibleElements = [];
                    const hiddenTags = ['SCRIPT', 'STYLE', 'NOSCRIPT', 'TEMPLATE', 'META', 'LINK'];
                    
                    // Function to check if an element is visible
                    function isVisible(element) {
                        if (!element) return false;
                        if (!element.offsetWidth && !element.offsetHeight) return false;
                        
                        const style = window.getComputedStyle(element);
                        if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') return false;
                        
                        return true;
                    }
                    
                    // Find all visible text nodes and create a map of them
                    const walker = document.createTreeWalker(
                        document.body,
                        NodeFilter.SHOW_TEXT,
                        {
                            acceptNode: function(node) {
                                // Skip hidden nodes
                                if (!node.textContent.trim()) return NodeFilter.FILTER_SKIP;
                                if (!node.parentElement) return NodeFilter.FILTER_SKIP;
                                if (hiddenTags.includes(node.parentElement.tagName)) return NodeFilter.FILTER_REJECT;
                                if (node.parentElement.closest('.ibrowsy-highlight, .ibrowsy-annotation')) return NodeFilter.FILTER_REJECT;
                                if (!isVisible(node.parentElement)) return NodeFilter.FILTER_SKIP;
                                
                                return NodeFilter.FILTER_ACCEPT;
                            }
                        }
                    );
                    
                    // Collect text nodes with their position info
                    let currentNode;
                    let textNodesWithPositions = [];
                    while (currentNode = walker.nextNode()) {
                        // Store the node and its text
                        textNodesWithPositions.push({
                            node: currentNode,
                            text: currentNode.textContent
                        });
                    }
                    
                    console.log(`[iBrowsy JS] Found ${textNodesWithPositions.length} visible text nodes to process.`);
                    
                    // Phase 1: For each significant word in the search, find nodes containing it
                    let highlightedNodes = new Set();
                    let firstHighlightedElement = null;
                    let significantWords = searchWords.filter(word => word.length > 3);
                    if (significantWords.length === 0) significantWords = searchWords; // If all words are short, use all
                    
                    significantWords.forEach(word => {
                        const wordRegex = new RegExp(word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'ui');
                        
                        textNodesWithPositions.forEach(item => {
                            if (wordRegex.test(item.text)) {
                                highlightedNodes.add(item.node);
                            }
                        });
                    });
                    
                    if (highlightedNodes.size === 0) {
                        console.warn(`[iBrowsy JS] No text nodes found containing any significant words from the search text. Significant words: ${significantWords.join(', ')}`);
                        return `Text not found: '${searchText}'. No nodes contained any of the search terms.`;
                    }
                    
                    // Phase 2: Highlight each node that contains any of the significant words
                    highlightedNodes.forEach(textNode => {
                        let nodeContent = textNode.textContent;
                        let parent = textNode.parentNode;
                        if (!parent) return;
                        
                        // Create a new span to replace this text node
                        const highlightSpan = document.createElement('span');
                        highlightSpan.className = 'ibrowsy-highlight';
                        highlightSpan.style.backgroundColor = 'yellow';
                        highlightSpan.style.color = 'black';
                        highlightSpan.style.border = '1px solid orange';
                        highlightSpan.style.borderRadius = '2px';
                        highlightSpan.style.padding = '0 2px';
                        highlightSpan.textContent = nodeContent;
                        
                        // Record the first element for scrolling
                        if (!firstHighlightedElement) {
                            firstHighlightedElement = highlightSpan;
                        }
                        
                        // Replace the original text node with the highlight span
                        parent.replaceChild(highlightSpan, textNode);
                        this.currentHighlights.push(highlightSpan);
                    });
                    
                    // Add annotation near the first highlight if provided
                    if (firstHighlightedElement && annotationText && annotationText.trim() !== '') {
                        const annotationDiv = document.createElement('div');
                        annotationDiv.className = 'ibrowsy-annotation';
                        annotationDiv.textContent = annotationText;
                        // Styling for annotation
                        Object.assign(annotationDiv.style, {
                            position: 'absolute',
                            backgroundColor: 'lightyellow',
                            border: '1px solid orange',
                            padding: '5px',
                            borderRadius: '3px',
                            zIndex: '10000',
                            boxShadow: '2px 2px 5px rgba(0,0,0,0.2)',
                            fontSize: '12px',
                            maxWidth: '200px',
                            wordWrap: 'break-word'
                        });
                        
                        const rect = firstHighlightedElement.getBoundingClientRect();
                        annotationDiv.style.left = (rect.left + window.scrollX) + 'px';
                        annotationDiv.style.top = (rect.bottom + window.scrollY + 5) + 'px'; // 5px below the highlight
                        document.body.appendChild(annotationDiv);
                        this.currentAnnotations.push(annotationDiv);
                    }
                    
                    // Scroll to the first highlight if one was created
                    if (firstHighlightedElement) {
                        // Scroll with smooth behavior
                        firstHighlightedElement.scrollIntoView({
                            behavior: 'smooth',
                            block: 'center',  // Center vertically
                            inline: 'nearest'  // Scroll horizontally only if needed
                        });
                    }
                    
                    const successMsg = `Highlighted: '${searchText}' (matched ${highlightedNodes.size} text nodes)`;
                    console.log("[iBrowsy JS] " + successMsg);
                    return successMsg;
                } catch (e) {
                    console.error("[iBrowsy JS] EXCEPTION in highlightAndAnnotate: ", e);
                    let errorMessage = "JS Exception: " + e.name + ": " + e.message;
                    if (e.stack) {
                        errorMessage += " | Stack: " + String(e.stack).replace(/\n/g, "\\n"); // Ensure stack is string and escape newlines
                    }
                    return errorMessage; // Return the detailed error message
                }
            }
        };
        """#
    }

    func highlightAndAnnotateOnPage(command: WebAnnotationCommand, webView: WKWebView, completion: @escaping (Result<String, Error>) -> Void) {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .withoutEscapingSlashes // To avoid escaping '/' to '\\/'

        let searchTextJSString: String
        do {
            let searchTextData = try jsonEncoder.encode(command.searchText)
            searchTextJSString = String(data: searchTextData, encoding: .utf8) ?? "\"\""
        } catch {
            print("[WebpageInteractionService] Error JSON encoding searchText: \\(error)")
            searchTextJSString = "\"\"" // Fallback to empty JS string
        }

        let annotationTextJSString: String
        if let annotationText = command.annotationText {
            do {
                let annotationTextData = try jsonEncoder.encode(annotationText)
                annotationTextJSString = String(data: annotationTextData, encoding: .utf8) ?? "null"
            } catch {
                print("[WebpageInteractionService] Error JSON encoding annotationText: \\(error)")
                annotationTextJSString = "null" // Fallback to null JS literal
            }
        } else {
            annotationTextJSString = "null" // JS null literal
        }

        print("[WebpageInteractionService] JSON-encoded searchText for JS: \\(searchTextJSString)")
        print("[WebpageInteractionService] JSON-encoded annotationText for JS: \\(annotationTextJSString)")

        // Construct the JavaScript call using the dynamic values.
        let defineInteractorScript = getJavaScriptFunctions()
        let callHighlightScript = "iBrowsyPageInteractor.highlightAndAnnotate(\(searchTextJSString), \(annotationTextJSString));"
        
        print("[WebpageInteractionService] DEFINING: defineInteractorScript (see getJavaScriptFunctions)")
        print("[WebpageInteractionService] INTENDING TO CALL: \(callHighlightScript)")

        // Combine definition and call into a single script
        let combinedScript = defineInteractorScript + "\n" + callHighlightScript
        print("[WebpageInteractionService] EXACT combinedScript to be evaluated:\n--BEGIN JS--\n\(combinedScript)\n--END JS--")

        // Evaluate the combined script
        webView.evaluateJavaScript(combinedScript) { result, error in
            if let error = error as NSError? { // Cast to NSError
                print("WebpageInteractionService: JavaScript error evaluating combined script: \(error.localizedDescription)")
                print("WebpageInteractionService: Error Domain: \(error.domain), Code: \(error.code)")
                if !error.userInfo.isEmpty {
                    print("WebpageInteractionService: Error UserInfo:")
                    for (key, value) in error.userInfo {
                        print("  \(key): \(value)")
                    }
                }
                if let resultValue = result {
                    print("WebpageInteractionService: ... JS result accompanying error: \(resultValue)")
                }
                completion(.failure(error))
            } else if let resultString = result as? String {
                print("WebpageInteractionService: JavaScript execution result: \(resultString)")
                completion(.success(resultString))
            } else {
                print("WebpageInteractionService: JavaScript executed, no specific string result, or result was not a string (result: \(String(describing: result))).")
                completion(.success("JavaScript executed, no specific string result."))
            }
        }
    }

    func clearAnnotations(webView: WKWebView, completion: ((Result<Void, Error>) -> Void)? = nil) {
        // Ensure the core interactor object and its clear function are defined before calling
        let script = """
        \(getJavaScriptFunctions()) // Ensure the object is defined
        if (typeof iBrowsyPageInteractor !== 'undefined' && typeof iBrowsyPageInteractor.clearAnnotations === 'function') {
            iBrowsyPageInteractor.clearAnnotations();
            "Cleared";
        } else {
            "iBrowsyPageInteractor not found or clearAnnotations not a function";
        }
        """
        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("WebpageInteractionService: JavaScript error on clear: \(error.localizedDescription)")
                completion?(.failure(error))
            } else {
                completion?(.success(()))
            }
        }
    }
}

// Helper for escaping strings for JavaScript literals to be injected into JS code
extension String {
    func escapedForJavaScript() -> String {
        return self
            .replacingOccurrences(of: "\\\\", with: "\\\\\\\\")      // Must be first
            .replacingOccurrences(of: "\"", with: "\\\\\"")       // Escape double quotes
            .replacingOccurrences(of: "'", with: "\\\\'")        // Escape single quotes
            .replacingOccurrences(of: "\n", with: "\\\\n")       // Escape newlines
            .replacingOccurrences(of: "\r", with: "\\\\r")       // Escape carriage returns
            .replacingOccurrences(of: "\t", with: "\\\\t")       // Escape tabs
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028") // Line separator
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029") // Paragraph separator
    }
} 