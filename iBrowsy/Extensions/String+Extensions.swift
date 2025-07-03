import Foundation

extension String {
    var htmlDecoded: String {
        guard let data = self.data(using: .utf8) else { 
            print("Warning: Could not convert string to data for HTML decoding")
            return self
        }
        do {
            let attributedString = try NSAttributedString(
                data: data, 
                options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], 
                documentAttributes: nil
            )
            return attributedString.string
        } catch {
            print("Warning: HTML decoding failed - \(error.localizedDescription). Returning original string.")
            return self
        }
    }
} 