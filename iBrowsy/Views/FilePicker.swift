import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Foundation

struct FilePicker: NSViewRepresentable {
    var onFileSelected: (URL?) -> Void
    var allowedContentTypes: [UTType] = []
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Nothing to update
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: FilePicker
        
        init(_ parent: FilePicker) {
            self.parent = parent
            super.init()
            
            // Present the panel when created
            presentOpenPanel()
        }
        
        func presentOpenPanel() {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            
            // Set allowed file types if specified
            if !parent.allowedContentTypes.isEmpty {
                panel.allowedContentTypes = parent.allowedContentTypes
            }
            
            panel.begin { [weak self] response in
                guard let self = self else { return }
                
                if response == .OK {
                    if let url = panel.url {
                        self.parent.onFileSelected(url)
                    } else {
                        self.parent.onFileSelected(nil)
                    }
                } else {
                    self.parent.onFileSelected(nil)
                }
            }
        }
    }
} 