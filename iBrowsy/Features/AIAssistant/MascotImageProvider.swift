import SwiftUI

class MascotImageProvider {
    func idleImage() -> Image {
        // Return a default image or placeholder
        return Image(systemName: "person.fill")
    }
    
    func thinkingImage() -> Image {
        // Return a thinking state image
        return Image(systemName: "person.fill.questionmark")
    }
    
    func errorImage() -> Image {
        // Return an error state image
        return Image(systemName: "exclamationmark.triangle.fill")
    }
} 