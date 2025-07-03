import SwiftUI
import PDFKit
import AppKit
import Quartz

// A unified file viewer that can handle different file types
struct FileViewer: View {
    let filePath: String
    let fileName: String
    let fileType: String
    
    @State private var isPreviewAvailable = false
    @State private var previewItem: URL? = nil
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack {
            if let errorMessage = errorMessage {
                ContentUnavailableView("Error Opening File", 
                                      systemImage: "exclamationmark.triangle",
                                      description: Text(errorMessage))
            } else if fileType.lowercased() == "pdf" {
                PDFViewer(url: URL(fileURLWithPath: filePath))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isPreviewable() {
                QuickLookPreview(url: URL(fileURLWithPath: filePath))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("File cannot be previewed", 
                                      systemImage: "doc.viewfinder",
                                      description: Text("Open the file in an external application instead."))
            }
        }
        .navigationTitle(fileName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: openInDefaultApp) {
                    Label("Open in Default App", systemImage: "square.and.arrow.up")
                }
            }
        }
        .onAppear {
            checkFileAccess()
        }
    }
    
    private func checkFileAccess() {
        let fileURL = URL(fileURLWithPath: filePath)
        
        if !FileManager.default.fileExists(atPath: filePath) {
            errorMessage = "File does not exist at the specified location."
            return
        }
        
        if !FileManager.default.isReadableFile(atPath: filePath) {
            errorMessage = "File exists but cannot be accessed. Check permissions."
            return
        }
        
        // Set the preview item URL if file is accessible
        previewItem = fileURL
    }
    
    private func isPreviewable() -> Bool {
        // Check if the file type is supported by QuickLook
        let previewableTypes = ["jpg", "jpeg", "png", "gif", "tiff", "bmp", "heic", 
                               "doc", "docx", "xls", "xlsx", "ppt", "pptx", 
                               "txt", "rtf", "html", "csv", "md", "swift"]
        
        return previewableTypes.contains(fileType.lowercased())
    }
    
    private func openInDefaultApp() {
        NSWorkspace.shared.open(URL(fileURLWithPath: filePath))
    }
}

// PDF Viewer using PDFKit
struct PDFViewer: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> PDFKit.PDFView {
        let pdfView = PDFKit.PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFKit.PDFView, context: Context) {
        // Updates if needed
    }
}

// QuickLook Preview wrapper for other file types
struct QuickLookPreview: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // When the view updates, refresh the preview
        context.coordinator.updatePreview(view: nsView, url: url)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }
    
    class Coordinator: NSObject, QLPreviewPanelDataSource {
        var url: URL
        var isShowingPreview: Bool = false
        
        init(url: URL) {
            self.url = url
            super.init()
        }
        
        func updatePreview(view: NSView, url: URL) {
            self.url = url
            
            // Show the preview panel if it's not already showing
            if !isShowingPreview {
                showPreviewPanel()
            }
        }
        
        func showPreviewPanel() {
            // Get the shared preview panel
            guard let panel = QLPreviewPanel.shared() else { return }
            
            // Configure the panel
            panel.dataSource = self
            
            // Show the panel if it's not already visible
            if !panel.isVisible {
                panel.makeKeyAndOrderFront(nil)
                isShowingPreview = true
            }
        }
        
        // MARK: - QLPreviewPanelDataSource
        
        func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
            return 1
        }
        
        func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
            return url as NSURL
        }
    }
} 