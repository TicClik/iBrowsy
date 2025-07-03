import Foundation

/// Represents a saved citation
struct Citation: Identifiable, Codable {
    let id: UUID
    let title: String
    let url: String
    let authors: [String]
    let publicationDate: Date?
    let websiteTitle: String
    let accessDate: Date
    let selectedText: String?
    let citationStyles: [CitationStyle]
    
    /// Formatted display date for the UI
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        if let pubDate = publicationDate {
            return formatter.string(from: pubDate)
        } else {
            return "No date"
        }
    }
    
    init(id: UUID = UUID(),
         title: String,
         url: String,
         authors: [String] = [],
         publicationDate: Date? = nil,
         websiteTitle: String = "",
         accessDate: Date = Date(),
         selectedText: String? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.authors = authors
        self.publicationDate = publicationDate
        self.websiteTitle = websiteTitle
        self.accessDate = accessDate
        self.selectedText = selectedText
        
        // Generate citation styles when creating a new citation
        self.citationStyles = CitationStyle.generateAllStyles(
            title: title,
            url: url,
            authors: authors,
            publicationDate: publicationDate,
            websiteTitle: websiteTitle,
            accessDate: accessDate
        )
    }
}

/// Citation formatting style
struct CitationStyle: Identifiable, Codable {
    let id: UUID
    let name: String
    let formattedCitation: String
    
    init(id: UUID = UUID(), name: String, formattedCitation: String) {
        self.id = id
        self.name = name
        self.formattedCitation = formattedCitation
    }
    
    /// Generate citations in all supported styles
    static func generateAllStyles(
        title: String,
        url: String,
        authors: [String],
        publicationDate: Date?,
        websiteTitle: String,
        accessDate: Date
    ) -> [CitationStyle] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        let accessDateStr = dateFormatter.string(from: accessDate)
        
        // Date formatting for publication date (if available)
        let pubDateStr = publicationDate != nil ? dateFormatter.string(from: publicationDate!) : "n.d."
        
        // Format author string
        let authorStr = formatAuthors(authors)
        
        // Generate APA style citation
        let apaCitation = generateAPA(
            title: title,
            url: url,
            authorStr: authorStr,
            pubDateStr: pubDateStr,
            websiteTitle: websiteTitle,
            accessDateStr: accessDateStr
        )
        
        // Generate MLA style citation
        let mlaCitation = generateMLA(
            title: title,
            url: url,
            authorStr: authorStr,
            pubDateStr: pubDateStr,
            websiteTitle: websiteTitle,
            accessDateStr: accessDateStr
        )
        
        // Generate Chicago style citation
        let chicagoCitation = generateChicago(
            title: title,
            url: url,
            authorStr: authorStr,
            pubDateStr: pubDateStr,
            websiteTitle: websiteTitle,
            accessDateStr: accessDateStr
        )
        
        return [
            CitationStyle(name: "APA", formattedCitation: apaCitation),
            CitationStyle(name: "MLA", formattedCitation: mlaCitation),
            CitationStyle(name: "Chicago", formattedCitation: chicagoCitation)
        ]
    }
    
    private static func formatAuthors(_ authors: [String]) -> String {
        if authors.isEmpty {
            return ""
        } else if authors.count == 1 {
            return authors[0]
        } else {
            // Multiple authors formatting
            let lastAuthor = authors.last!
            let otherAuthors = authors.dropLast().joined(separator: ", ")
            return "\(otherAuthors), & \(lastAuthor)"
        }
    }
    
    private static func generateAPA(
        title: String,
        url: String,
        authorStr: String,
        pubDateStr: String,
        websiteTitle: String,
        accessDateStr: String
    ) -> String {
        let authorPart = authorStr.isEmpty ? "" : "\(authorStr). "
        let datePart = "(\(pubDateStr)). "
        let titlePart = "\(title). "
        let websitePart = websiteTitle.isEmpty ? "" : "\(websiteTitle). "
        let urlPart = "Retrieved \(accessDateStr), from \(url)"
        
        return authorPart + datePart + titlePart + websitePart + urlPart
    }
    
    private static func generateMLA(
        title: String,
        url: String,
        authorStr: String,
        pubDateStr: String,
        websiteTitle: String,
        accessDateStr: String
    ) -> String {
        let authorPart = authorStr.isEmpty ? "" : "\(authorStr). "
        let titlePart = "\"\(title).\" "
        let websitePart = websiteTitle.isEmpty ? "" : "\(websiteTitle), "
        let datePart = "\(pubDateStr), "
        let urlPart = "\(url). Accessed \(accessDateStr)."
        
        return authorPart + titlePart + websitePart + datePart + urlPart
    }
    
    private static func generateChicago(
        title: String,
        url: String,
        authorStr: String,
        pubDateStr: String,
        websiteTitle: String,
        accessDateStr: String
    ) -> String {
        let authorPart = authorStr.isEmpty ? "" : "\(authorStr). "
        let titlePart = "\"\(title).\" "
        let websitePart = websiteTitle.isEmpty ? "" : "\(websiteTitle). "
        let datePart = "\(pubDateStr). "
        let urlPart = "\(url). Accessed \(accessDateStr)."
        
        return authorPart + titlePart + websitePart + datePart + urlPart
    }
}

// Supported export formats
enum CitationExportFormat {
    case plainText
    case bibtex
    case ris
} 