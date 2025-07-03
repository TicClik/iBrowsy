import Foundation
import Combine
import WebKit
import SwiftUI

class CitationManager: ObservableObject {
    /// All citations stored by the user
    @Published var citations: [Citation] = []
    
    /// File URL where citations are stored
    private let citationsFileURL: URL
    
    /// Cancellables for managing publisher subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Get the application support directory
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        // Create a subdirectory for iBrowsy if it doesn't exist
        let appDir = appSupportDir.appendingPathComponent("iBrowsy", isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        } catch {
            print("CitationManager: Error creating directory: \(error)")
        }
        
        // Define the file URL for citations
        self.citationsFileURL = appDir.appendingPathComponent("citations.json")
        
        // Load citations from disk when initialized
        loadCitations()
        
        // Save citations whenever the citations array changes
        $citations
            .debounce(for: 1.0, scheduler: RunLoop.main) // Debounce to avoid excessive writes
            .sink { [weak self] _ in
                self?.saveCitations()
            }
            .store(in: &cancellables)
    }
    
    /// Load citations from disk
    private func loadCitations() {
        do {
            if FileManager.default.fileExists(atPath: citationsFileURL.path) {
                let data = try Data(contentsOf: citationsFileURL)
                citations = try JSONDecoder().decode([Citation].self, from: data)
                print("CitationManager: Loaded \(citations.count) citations")
            } else {
                print("CitationManager: No citations file found, starting with empty list")
            }
        } catch {
            print("CitationManager: Error loading citations: \(error)")
        }
    }
    
    /// Save citations to disk
    private func saveCitations() {
        do {
            let data = try JSONEncoder().encode(citations)
            try data.write(to: citationsFileURL)
            print("CitationManager: Saved \(citations.count) citations")
        } catch {
            print("CitationManager: Error saving citations: \(error)")
        }
    }
    
    /// Add a citation
    func addCitation(_ citation: Citation) {
        // Check if we already have a citation for this URL
        if let existingIndex = citations.firstIndex(where: { $0.url == citation.url }) {
            // Replace the existing citation
            citations[existingIndex] = citation
        } else {
            // Add new citation
            citations.append(citation)
        }
    }
    
    /// Remove a citation
    func removeCitation(withID id: UUID) {
        citations.removeAll { $0.id == id }
    }
    
    /// Generate a citation for the current page
    func generateCitationForWebPage(_ webView: WKWebView, selectedText: String? = nil, completion: @escaping (Citation?) -> Void) {
        // Step 1: Get the current URL
        guard let urlString = webView.url?.absoluteString else {
            completion(nil)
            return
        }
        
        // Step 2: Use JavaScript to extract metadata from the page
        webView.evaluateJavaScript(metadataExtractionScript) { [weak self] result, error in
            guard let self = self, error == nil, let resultDict = result as? [String: Any] else {
                print("CitationManager: Error extracting metadata: \(error?.localizedDescription ?? "Unknown error")")
                
                // Create basic citation with just the URL and title
                let basicCitation = Citation(
                    title: webView.title ?? "Untitled",
                    url: urlString,
                    selectedText: selectedText
                )
                completion(basicCitation)
                return
            }
            
            // Step 3: Process extracted metadata
            let title = (resultDict["title"] as? String) ?? webView.title ?? "Untitled"
            let websiteTitle = (resultDict["siteName"] as? String) ?? ""
            
            // Handle authors
            var authors: [String] = []
            if let authorString = resultDict["author"] as? String {
                // Try to split by common separators
                if authorString.contains(",") {
                    authors = authorString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                } else if authorString.contains(";") {
                    authors = authorString.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                } else if authorString.contains("&") {
                    authors = authorString.components(separatedBy: "&").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                } else {
                    // Just use as single author
                    authors = [authorString]
                }
            } else if let authorsArray = resultDict["authors"] as? [String] {
                authors = authorsArray
            }
            
            // Handle publication date
            var pubDate: Date? = nil
            if let dateString = resultDict["publicationDate"] as? String {
                let dateFormatter = DateFormatter()
                // Try various date formats
                for dateFormat in ["yyyy-MM-dd", "yyyy/MM/dd", "MM/dd/yyyy", "dd/MM/yyyy", "yyyy-MM-dd'T'HH:mm:ssZ"] {
                    dateFormatter.dateFormat = dateFormat
                    if let date = dateFormatter.date(from: dateString) {
                        pubDate = date
                        break
                    }
                }
            }
            
            // Create the citation with all available metadata
            let citation = Citation(
                title: title,
                url: urlString,
                authors: authors,
                publicationDate: pubDate,
                websiteTitle: websiteTitle,
                selectedText: selectedText
            )
            
            completion(citation)
        }
    }
    
    /// Export a citation in the specified format
    func exportCitation(_ citation: Citation, format: CitationExportFormat) -> String {
        switch format {
        case .plainText:
            // Default to APA format for plain text
            return citation.citationStyles.first(where: { $0.name == "APA" })?.formattedCitation ?? ""
            
        case .bibtex:
            // Create BibTeX format
            let sanitizedTitle = citation.title.replacingOccurrences(of: "\"", with: "\\\"")
            let sanitizedUrl = citation.url
            
            // Create a bibtex key from first author's last name (or "Anonymous") and year
            let yearFormatter = DateFormatter()
            yearFormatter.dateFormat = "yyyy"
            let year = citation.publicationDate != nil ? yearFormatter.string(from: citation.publicationDate!) : "nd"
            
            let authorKey: String
            if let firstAuthor = citation.authors.first, !firstAuthor.isEmpty {
                // Try to extract last name from first author
                let nameParts = firstAuthor.components(separatedBy: " ")
                authorKey = nameParts.last?.lowercased() ?? "anonymous"
            } else {
                authorKey = "anonymous"
            }
            
            let bibKey = "\(authorKey)\(year)"
            
            var bibtex = "@misc{\(bibKey),\n"
            bibtex += "  title = {\"\(sanitizedTitle)\"},\n"
            
            // Add authors if available
            if !citation.authors.isEmpty {
                let authorsString = citation.authors.joined(separator: " and ")
                bibtex += "  author = {\(authorsString)},\n"
            }
            
            // Add year if available
            if let pubDate = citation.publicationDate {
                bibtex += "  year = {\(yearFormatter.string(from: pubDate))},\n"
            }
            
            // Add website title if available
            if !citation.websiteTitle.isEmpty {
                bibtex += "  publisher = {\(citation.websiteTitle)},\n"
            }
            
            // Add URL and access date
            bibtex += "  url = {\(sanitizedUrl)},\n"
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            bibtex += "  note = {Accessed: \(dateFormatter.string(from: citation.accessDate))}\n"
            bibtex += "}"
            
            return bibtex
            
        case .ris:
            // Create RIS format (for reference managers like EndNote, Mendeley, etc.)
            var ris = "TY  - ELEC\n" // Type: Electronic Source
            ris += "TI  - \(citation.title)\n" // Title
            
            // Add authors
            for author in citation.authors {
                ris += "AU  - \(author)\n"
            }
            
            // Add publication date if available
            if let pubDate = citation.publicationDate {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy/MM/dd"
                ris += "PY  - \(dateFormatter.string(from: pubDate))\n"
            }
            
            // Add website title if available
            if !citation.websiteTitle.isEmpty {
                ris += "T2  - \(citation.websiteTitle)\n"
            }
            
            // Add URL
            ris += "UR  - \(citation.url)\n"
            
            // Add access date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy/MM/dd"
            ris += "Y2  - \(dateFormatter.string(from: citation.accessDate))\n"
            
            ris += "ER  - " // End of Reference
            
            return ris
        }
    }
    
    /// Export multiple citations in the specified format
    func exportCitations(_ citations: [Citation], format: CitationExportFormat) -> String {
        return citations.map { exportCitation($0, format: format) }.joined(separator: "\n\n")
    }
    
    /// JavaScript for extracting metadata from web pages
    private let metadataExtractionScript = """
    (function() {
        var metadata = {};
        
        // Extract title
        metadata.title = document.title || '';
        
        // Try various methods to get author information
        var authorMeta = document.querySelector('meta[name="author"], meta[property="article:author"]');
        if (authorMeta) {
            metadata.author = authorMeta.getAttribute('content');
        } else {
            // Try to find schema.org author markup
            var schemaAuthor = document.querySelector('[itemprop="author"]');
            if (schemaAuthor) {
                var authorName = schemaAuthor.querySelector('[itemprop="name"]');
                if (authorName) {
                    metadata.author = authorName.textContent.trim();
                } else {
                    metadata.author = schemaAuthor.textContent.trim();
                }
            }
        }
        
        // Try to get multiple authors
        var authors = [];
        var authorElements = document.querySelectorAll('[itemprop="author"] [itemprop="name"]');
        if (authorElements.length > 0) {
            for (var i = 0; i < authorElements.length; i++) {
                authors.push(authorElements[i].textContent.trim());
            }
            metadata.authors = authors;
        }
        
        // Try to get publication date
        var dateMeta = document.querySelector('meta[name="date"], meta[property="article:published_time"]');
        if (dateMeta) {
            metadata.publicationDate = dateMeta.getAttribute('content');
        } else {
            // Try schema.org date
            var dateElement = document.querySelector('[itemprop="datePublished"]');
            if (dateElement) {
                metadata.publicationDate = dateElement.getAttribute('content') || dateElement.textContent.trim();
            }
        }
        
        // Try to get site name/publisher
        var siteMeta = document.querySelector('meta[property="og:site_name"]');
        if (siteMeta) {
            metadata.siteName = siteMeta.getAttribute('content');
        } else {
            var publisherElement = document.querySelector('[itemprop="publisher"] [itemprop="name"]');
            if (publisherElement) {
                metadata.siteName = publisherElement.textContent.trim();
            }
        }
        
        return metadata;
    })();
    """
} 