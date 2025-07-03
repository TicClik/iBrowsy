import SwiftUI
import UniformTypeIdentifiers

struct CitationsView: View {
    @ObservedObject var viewModel: WebViewModel
    @EnvironmentObject var citationManager: CitationManager
    @State private var searchText = ""
    @State private var selectedCitation: Citation? = nil
    @State private var exportFormat: CitationExportFormat = .plainText
    @State private var showingExportSheet = false
    @State private var exportedText = ""
    
    private var filteredCitations: [Citation] {
        if searchText.isEmpty {
            return citationManager.citations
        } else {
            return citationManager.citations.filter { citation in
                citation.title.localizedCaseInsensitiveContains(searchText) ||
                citation.url.localizedCaseInsensitiveContains(searchText) ||
                citation.authors.joined(separator: " ").localizedCaseInsensitiveContains(searchText) ||
                citation.websiteTitle.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        GlassPanel(style: .main) {
            VStack(spacing: 0) {
                // Header
                GlassCard(style: .secondary) {
                    HStack {
                        GlassButton(style: .secondary, action: {
                            viewModel.goHome()
                        }) {
                            Image(systemName: "arrow.left")
                                .foregroundColor(.white)
                        }
                        
                        Text("Citations")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Menu {
                            GlassButton(style: .primary, action: {
                                exportFormat = .plainText
                                exportAll()
                            }) {
                                Label("Export All as Text", systemImage: "doc.text")
                                    .foregroundColor(.primary)
                            }
                            
                            GlassButton(style: .primary, action: {
                                exportFormat = .bibtex
                                exportAll()
                            }) {
                                Label("Export All as BibTeX", systemImage: "doc.badge.gearshape")
                                    .foregroundColor(.primary)
                            }
                            
                            GlassButton(style: .primary, action: {
                                exportFormat = .ris
                                exportAll()
                            }) {
                                Label("Export All as RIS", systemImage: "doc.badge.gearshape")
                                    .foregroundColor(.primary)
                            }
                        } label: {
                            GlassButton(style: .accent, action: {}) {
                                Label("Export", systemImage: "square.and.arrow.up")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                .padding()
                
                // Search field
                VStack {
                    GlassTextField("Search Citations", text: $searchText, style: .primary)
                        .padding(.horizontal)
                }
                .padding(.bottom)
                
                if filteredCitations.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No citations yet")
                            .font(.headline)
                        
                        Text("Citations you create from web pages will appear here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredCitations, id: \.id) { citation in
                            CitationRowView(citation: citation, viewModel: viewModel, citationManager: citationManager, selectedCitation: $selectedCitation, exportFormat: $exportFormat, exportedText: $exportedText, showingExportSheet: $showingExportSheet)
                                .onTapGesture {
                                    selectedCitation = citation
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            CitationExportView(exportedText: $exportedText, isShowing: $showingExportSheet)
        }
    }
    
    // Export the selected citation
    private func exportSelected() {
        guard let citation = selectedCitation else { return }
        
        exportedText = citationManager.exportCitation(citation, format: exportFormat)
        showingExportSheet = true
    }
    
    // Export all citations
    private func exportAll() {
        let citations = filteredCitations
        
        if citations.isEmpty {
            return
        }
        
        exportedText = citationManager.exportCitations(citations, format: exportFormat)
        showingExportSheet = true
    }
}

struct CitationRowView: View {
    let citation: Citation
    let viewModel: WebViewModel
    let citationManager: CitationManager
    @Binding var selectedCitation: Citation?
    @Binding var exportFormat: CitationExportFormat
    @Binding var exportedText: String
    @Binding var showingExportSheet: Bool
    
    var body: some View {
        GlassCard(style: .primary) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(citation.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        if !citation.authors.isEmpty {
                            Text(citation.authors.joined(separator: ", "))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Text(citation.websiteTitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Text(citation.formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        GlassButton(style: .secondary, action: {
                            selectedCitation = citation
                            exportFormat = .plainText
                            exportSelected()
                        }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.white)
                        }
                        
                        GlassButton(style: .accent, action: {
                            if let url = URL(string: citation.url) {
                                viewModel.loadURL(from: url.absoluteString)
                            }
                        }) {
                            Image(systemName: "globe")
                                .foregroundColor(.white)
                        }
                    }
                }
                
                // URL preview
                Text(citation.url)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .contextMenu {
            Button(action: {
                selectedCitation = citation
                exportFormat = .plainText
                exportSelected()
            }) {
                Label("Copy APA Citation", systemImage: "doc.on.doc")
            }
            
            Menu("Export As") {
                Button(action: {
                    selectedCitation = citation
                    exportFormat = .plainText
                    exportSelected()
                }) {
                    Text("Plain Text")
                }
                
                Button(action: {
                    selectedCitation = citation
                    exportFormat = .bibtex
                    exportSelected()
                }) {
                    Text("BibTeX")
                }
                
                Button(action: {
                    selectedCitation = citation
                    exportFormat = .ris
                    exportSelected()
                }) {
                    Text("RIS")
                }
            }
            
            Divider()
            
            Button(action: {
                if let url = URL(string: citation.url) {
                    viewModel.loadURL(from: url.absoluteString)
                }
            }) {
                Label("Open Source", systemImage: "globe")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                citationManager.removeCitation(withID: citation.id)
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func exportSelected() {
        guard let citation = selectedCitation else { return }
        
        exportedText = citationManager.exportCitation(citation, format: exportFormat)
        showingExportSheet = true
    }
}

// Sheet for displaying exported citation
struct CitationExportView: View {
    @Binding var exportedText: String
    @Binding var isShowing: Bool
    @State private var isCopied = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Export Citation")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    isShowing = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            ScrollView {
                Text(exportedText)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            
            HStack {
                Button(action: {
                    // Copy to clipboard
                    #if os(macOS)
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(exportedText, forType: .string)
                    isCopied = true
                    
                    // Reset the "Copied" indicator after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isCopied = false
                    }
                    #endif
                }) {
                    Label(isCopied ? "Copied!" : "Copy to Clipboard", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: {
                    // Save to file
                    #if os(macOS)
                    let savePanel = NSSavePanel()
                    savePanel.nameFieldStringValue = "citations"
                    
                    // Set appropriate extension based on current format
                    if exportedText.contains("@misc{") {
                        savePanel.allowedContentTypes = [UTType.init(filenameExtension: "bib", conformingTo: .text)!]
                    } else if exportedText.contains("TY  - ELEC") {
                        savePanel.allowedContentTypes = [UTType.init(filenameExtension: "ris", conformingTo: .text)!]
                    } else {
                        savePanel.allowedContentTypes = [UTType.text]
                    }
                    
                    savePanel.begin { result in
                        if result == .OK, let url = savePanel.url {
                            do {
                                try exportedText.write(to: url, atomically: true, encoding: .utf8)
                            } catch {
                                print("Error saving file: \(error)")
                            }
                        }
                    }
                    #endif
                }) {
                    Label("Save to File", systemImage: "arrow.down.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .frame(width: 600, height: 450)
    }
} 