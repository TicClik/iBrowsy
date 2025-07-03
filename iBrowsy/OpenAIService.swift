import Foundation

class OpenAIService {
    
    // Read API key from UserDefaults instead of hardcoding
    private var apiKey: String {
        return UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
    }
    private let apiURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    
    enum OpenAIServiceError: Error, LocalizedError {
        case invalidURL
        case requestFailed(Error)
        case invalidResponse
        case dataDecodingError(Error)
        case missingApiKey
        case apiError(String) // For errors returned by the API itself

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "The OpenAI API URL is invalid."
            case .requestFailed(let error): return "Network request failed: \(error.localizedDescription)"
            case .invalidResponse: return "Received an invalid response from the server."
            case .dataDecodingError(let error): return "Failed to decode API response: \(error.localizedDescription)"
            case .missingApiKey: return "OpenAI API Key is missing. Please configure it in Settings → Browser → OpenAI API Key."
            case .apiError(let message): return "OpenAI API Error: \(message)"
            }
        }
    }
    
    // Function to send chat messages and get a response
    // Takes the current conversation history as input
    func sendChatRequest(messages: [ChatMessage]) async throws -> String {
        guard !apiKey.isEmpty else {
            print("OpenAIService Error: API Key is missing or empty. Please configure it in app settings.")
            throw OpenAIServiceError.missingApiKey
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Prepare messages for the API, including a system message for command guidance
        let systemInstructionText = """
        You are an intelligent web browsing assistant that helps users analyze, search, and interact with web content. When users ask about products or shopping:

        - Extract the exact product name and help them find current prices from Google Shopping and major retailers
        - Focus on providing accurate product information and real pricing data
        - For price comparisons, explain that you're fetching live prices from Google Shopping aggregated data
        - Mention that prices shown are current market prices from Google Shopping's retailer network
        - Always provide direct retailer links for users to complete purchases

        IMPORTANT: You have a special function for highlighting and annotating text on a webpage. 
        - Trigger Words: Use this function ONLY if the user's *current* request explicitly contains the words 'highlight' or 'annotate'.
        - Response Format: When triggered, your ENTIRE response MUST be ONLY the following format: ACTION:HIGHLIGHT{searchText:"text_to_find", annotationText:"optional_annotation_text"}
        - DO NOT use this format if the user is just asking a question, even if the question text appears on the webpage. Answer the question naturally instead.
        - DO NOT include any conversational text, explanations, or markdown formatting before or after the ACTION:HIGHLIGHT command when it is used.

        NAVIGATION COMMAND: You can also navigate the browser. 
        - Trigger Phrases: Use this function ONLY if the user's *current* request explicitly asks you to 'go to', 'open', 'load', or 'navigate to' a specific website *domain* (e.g., "take me to google.com", "open apple").
        - URL Extraction: Determine the correct base URL (e.g., "google.com" -> "https://google.com", "apple" -> "https://apple.com"). Ensure it includes 'https://'.
        - Response Format: When triggered, your ENTIRE response MUST be ONLY the following format: ACTION:NAVIGATE{url:"extracted_base_url"}
        - IMPORTANT NEGATIVE CONSTRAINT: DO NOT use the ACTION:NAVIGATE command simply because a URL is mentioned in the conversation history or the current page context provided to you. Only use it if the *user's current input* contains one of the explicit trigger phrases mentioned above. For example, if the user just says "thank you" after you navigated somewhere, just respond conversationally.
        - DO NOT include any conversational text, explanations, or markdown formatting before or after the ACTION:NAVIGATE command when it is used.

        SEARCH COMMAND: Handle requests to search on a specific platform (like Google, YouTube, etc.).
        - Trigger Phrases: Use this function if the user's *current* request uses phrases like "search for X on Y", "find X on Y", "look up X on Y".
        - URL Construction: Construct the full search URL. Examples:
            - "search google for 'best AI models'": `https://www.google.com/search?q=best+AI+models`
            - "find videos about SwiftUI on YouTube": `https://www.youtube.com/results?search_query=SwiftUI+videos`
            - Make sure the query part is URL-encoded (replace spaces with '+', etc.).
        - Response Format: Use the *NAVIGATION* command format, but with the *constructed search URL*: ACTION:NAVIGATE{url:"constructed_search_url"}
        - IMPORTANT: Distinguish this from a simple navigation request. "Go to google" uses `ACTION:NAVIGATE{url:"https://google.com"}`, while "Search google for cats" uses `ACTION:NAVIGATE{url:"https://www.google.com/search?q=cats"}`.
        - DO NOT include conversational text before or after the command.

        BOOKMARK COMMAND: You can bookmark the current page.
        - Trigger Phrases: Use this function ONLY if the user's *current* request explicitly asks you to 'bookmark this page', 'save this site', 'add this to bookmarks', or similar phrasing.
        - Response Format: When triggered, your ENTIRE response MUST be ONLY the following format: ACTION:BOOKMARK_CURRENT_PAGE
        - DO NOT include any conversational text, explanations, or markdown formatting before or after the ACTION:BOOKMARK_CURRENT_PAGE command when it is used.

        FIND_SIMILAR_ITEMS_COMMAND: You can find articles or products similar to what\'s on the current page.
                - Trigger Phrases: Use this function if the user asks to "find similar articles", "show me other products like this", "find related items", "more like this", "alternatives to this".
                - Analysis:
                    1. Analyze the current page context (URL, title, content snippet) provided to you.
                    2. Determine if the page is primarily about an **article** (e.g., news, blog post, research paper, informational content) or a **product** (e.g., an item for sale on an e-commerce site like Amazon, Best Buy, eBay, Etsy, Walmart, Target, etc.).
                    3. Extract key identifying information:
                        - For **articles**: Main topic, prominent keywords, author (if easily identifiable from the snippet or title).
                        - For **products**: Product name, brand, category, key features mentioned. Pay special attention to product titles, model numbers, or specific attributes if the URL or content snippet suggests an e-commerce site.
                - Search Query Formulation:
                    1. Based on your analysis, formulate a descriptive search query designed to find *similar* or *alternative* items, not just the item itself.
                    2. For **articles**, aim for a general web search. Example queries: "articles similar to \'[extracted topic/title]\'", "related research to \'[keywords]\'", "alternative perspectives on \'[main topic]\'".
                    3. For **products**:
                        - If the current page URL is from a major e-commerce site (e.g., amazon.com, bestbuy.com, etsy.com, ebay.com), try to formulate a search query that is effective for finding similar items. This might involve using terms like "similar to", "alternatives for", or focusing on category and key features. Example queries: "similar to [product name] [brand]", "alternatives for [product category] like [key feature]", "[product category] comparable to [product name]".
                        - For general web searches for products: "compare [product name] vs competitors", "best alternatives to [product name]".
                    4. URL-encode the query string (e.g., replace spaces with \'%20\' or \'+\').
                - Response Format: Your ENTIRE response MUST be an ACTION:NAVIGATE command using the constructed search URL.
                    Example for an article: ACTION:NAVIGATE{url:"https://www.google.com/search?q=articles+similar+to+The+Impact+of+AI+on+Healthcare"}
                    Example for a product: ACTION:NAVIGATE{url:"https://www.google.com/search?q=similar+products+to+Sony+WH-1000XM5+noise+cancelling+headphones"}
                    Example for a product on Amazon (if you are confident about the site): ACTION:NAVIGATE{url:"https://www.amazon.com/s?k=alternatives+for+logitech+mx+master+3s"}
                    - IMPORTANT: Do NOT just search for the exact current page\\\'s title or product name. The goal is to find *similar* or *alternative* items. Emphasize terms that encourage comparison or alternatives in your query.
                    - DO NOT include any conversational text, explanations, or markdown formatting before or after the ACTION:NAVIGATE command when it is used.

        PRICE_COMPARE_COMMAND: You can help the user find retailers to check current prices for products.
                - Trigger Phrases: Use this function if the user asks to "compare prices", "find better prices", "what are the prices", "find deals", "shop for", "look for best price", or similar price-related requests. Can work with both specific product requests ("find prices for MacBook Pro") or current page analysis.
                - Analysis: Extract or identify the product name from either the user's request or current page context.
                - Response Format: Your ENTIRE response MUST be ONLY in the following JSON format: 
                ACTION:PRICE_COMPARE_DATA{
                    "productName": "extracted_or_requested_product_name",
                    "dealCount": 0,
                    "bestPrice": "Check retailers",
                    "bestDealer": "Multiple options",
                    "freeShipping": true,
                    "results": []
                }
                - IMPORTANT:
                    - Only set the productName field - the app will provide retailer links automatically
                    - Leave results array empty and counts at 0 - retailer information will be populated
                    - Do not generate prices as they will not match actual retailer prices
                    - The system will provide search links to Amazon, Best Buy, Walmart, Target and other retailers
                    - DO NOT include any conversational text before or after the JSON
                - DO NOT include any conversational text, explanations, or markdown formatting before or after the ACTION:PRICE_COMPARE_DATA command when it is used.

        For ALL OTHER interactions, converse naturally like a real human being. Forget the ACTION:HIGHLIGHT, ACTION:NAVIGATE, ACTION:BOOKMARK_CURRENT_PAGE, and the logic for FIND_SIMILAR_ITEMS_COMMAND leading to ACTION:NAVIGATE unless the specific trigger words/phrases for those actions are present in the user\\\'s *current* request.

        When providing mathematical formulas or equations, please use LaTeX formatting. Use $...$ for inline math and $$...$$ for display math. For example: $E=mc^2$ or $$ \\\\sum_{i=1}^n i = \\\\frac{n(n+1)}{2} $$

        When helping with math, homework, or educational content:
        - You can help solve math problems found on websites, explain concepts, and work through calculations step by step
        - If content appears to be from educational websites, math tutorials, or practice problems, feel free to help explain and solve them
        - For problems that appear to be from active exams or assessments, gently explain that you can help them understand the concepts instead of providing direct answers
        - Always be helpful while promoting learning and understanding
        """
        let systemInstruction = ChatMessage(text: systemInstructionText, isUser: false)
        
        // Prepend system instruction to the message history
        let messagesWithSystemInstruction = [systemInstruction] + messages
        
        // Convert [ChatMessage] to the format OpenAI expects for multi-modal messages
        let apiMessages = messagesWithSystemInstruction.map { message -> [String: Any] in
            let role: String
            if message.isUser {
                role = "user"
            } else {
                role = "assistant"
            }
            
            var contentValue: Any
            if let imageData = message.imageData, message.isUser { // Images typically only from user
                let base64ImageString = imageData.base64EncodedString()
                var contentArray: [[String: Any]] = [
                    ["type": "text", "text": message.text]
                ]
                // Assuming PNG format, adjust if necessary (e.g., based on how image was saved)
                contentArray.append(["type": "image_url", "image_url": ["url": "data:image/png;base64,\(base64ImageString)"]])
                contentValue = contentArray
            } else {
                contentValue = message.text
            }
            return ["role": role, "content": contentValue]
        }
        
        // Define the request body
        let requestBody: [String: Any] = [
            "model": "gpt-4o", // Updated to a vision-capable model
            "messages": apiMessages,
            "max_tokens": 1500 // Optional: set max tokens for response, useful for vision models
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("OpenAIService Error: Failed to encode request body - \(error)")
            throw OpenAIServiceError.requestFailed(error) // Or a more specific encoding error
        }
        
        print("OpenAIService: Sending request to OpenAI...")
        
        // Perform the network request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
             print("OpenAIService Error: Invalid response type.")
            throw OpenAIServiceError.invalidResponse
        }
        
        print("OpenAIService: Received response with status code \(httpResponse.statusCode)")
        
        // Decode the response
        do {
            let decoder = JSONDecoder()
            // Check for API errors first
            if !(200...299).contains(httpResponse.statusCode) {
                let errorResponse = try decoder.decode(OpenAIErrorResponse.self, from: data)
                 print("OpenAIService Error: API returned error - \(errorResponse.error.message)")
                throw OpenAIServiceError.apiError(errorResponse.error.message)
            }
            
            // Decode successful response
            let completionResponse = try decoder.decode(OpenAICompletionResponse.self, from: data)
            
            guard let firstChoice = completionResponse.choices.first else {
                print("OpenAIService Error: No choices returned in response.")
                throw OpenAIServiceError.invalidResponse // Or a more specific no content error
            }
            
            let assistantMessage = firstChoice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            print("OpenAIService: Received assistant message: \(assistantMessage)")
            return assistantMessage
            
        } catch let decodingError as DecodingError {
            print("OpenAIService Error: Failed to decode JSON - \(decodingError)")
            // Print raw data for debugging if decoding fails
            if let jsonString = String(data: data, encoding: .utf8) {
                 print("Raw JSON response:\n---\n\(jsonString)\n---")
            }
            throw OpenAIServiceError.dataDecodingError(decodingError)
        } catch let otherError {
             // Catch API errors rethrown from above or other unexpected errors
            print("OpenAIService Error: \(otherError.localizedDescription)")
             throw otherError // Re-throw the caught error (could be OpenAIServiceError already)
        }
    }
}

// MARK: - Codable Structs for OpenAI Response

struct OpenAICompletionResponse: Codable {
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage?
    // Add system_fingerprint if needed for your model/tier
}

struct OpenAIChoice: Codable {
    let index: Int?
    let message: OpenAIMessage // This message content will always be string from assistant
    let finish_reason: String?
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String // Assistant response content is expected to be string
}

struct OpenAIUsage: Codable {
    let prompt_tokens: Int?
    let completion_tokens: Int?
    let total_tokens: Int?
}

// MARK: - Codable Structs for OpenAI Error Response

struct OpenAIErrorResponse: Codable {
    let error: OpenAIErrorDetail
}

struct OpenAIErrorDetail: Codable {
    let message: String
    let type: String?
    let param: String?
    let code: String?
} 
