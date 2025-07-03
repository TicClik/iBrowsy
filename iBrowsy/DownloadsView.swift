import SwiftUI

struct DownloadsView: View {
    @ObservedObject var viewModel: WebViewModel
    @State private var searchText = ""
    
    private var filteredDownloads: [DownloadItem] {
        if searchText.isEmpty {
            return viewModel.downloadItems
        } else {
            return viewModel.downloadItems.filter { item in
                item.filename.localizedCaseInsensitiveContains(searchText) ||
                item.urlString.localizedCaseInsensitiveContains(searchText)
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
                        
                        Text("Downloads")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        GlassButton(style: .accent, action: {
                            viewModel.clearDownloadHistory()
                        }) {
                            Text("Clear Completed")
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding()
                
                // Search field
                VStack {
                    GlassTextField("Search Downloads", text: $searchText, style: .primary)
                        .padding(.horizontal)
                }
                .padding(.bottom)
                
                if filteredDownloads.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        if searchText.isEmpty {
                            Text("No downloads")
                                .font(.headline)
                            
                            Text("Your downloads will appear here")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("No matching downloads")
                                .font(.headline)
                            
                            Text("Try a different search term")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)
                } else {
                    List {
                        ForEach(filteredDownloads) { item in
                            DownloadItemView(item: item, viewModel: viewModel)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
            }
        }
    }
}

struct DownloadItemView: View {
    let item: DownloadItem
    let viewModel: WebViewModel
    
    // Date formatter for the relative time
    private let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
    // Format file size
    private var formattedFileSize: String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useKB, .useMB, .useGB]
        byteCountFormatter.countStyle = .file
        return byteCountFormatter.string(fromByteCount: item.fileSize)
    }
    
    var body: some View {
        GlassCard(style: .primary) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    // Icon based on state
                    Group {
                        switch item.state {
                        case .inProgress:
                            Image(systemName: "arrow.down.circle")
                                .foregroundColor(.blue)
                        case .completed:
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                        case .failed:
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.red)
                        }
                    }
                    .font(.system(size: 16))
                    .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.filename)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(item.urlString)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Action buttons based on state
                    Group {
                        switch item.state {
                        case .inProgress:
                            GlassButton(style: .accent, action: {
                                viewModel.cancelDownload(id: item.id)
                            }) {
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.white)
                            }
                        case .completed:
                            if item.localURL != nil {
                                GlassButton(style: .secondary, action: {
                                    viewModel.openDownloadedFile(id: item.id)
                                }) {
                                    Image(systemName: "folder")
                                        .foregroundColor(.white)
                                }
                            }
                        case .failed:
                            Text("Failed")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // Show progress bar for in-progress downloads
                if item.state == .inProgress {
                    ProgressView(value: item.progress)
                        .progressViewStyle(.linear)
                        .frame(height: 4)
                }
                
                // Show metadata
                HStack {
                    Text(relativeDateFormatter.localizedString(for: item.date, relativeTo: Date()))
                    
                    Text("•")
                    
                    Text(formattedFileSize)
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}

#Preview {
    DownloadsView(viewModel: WebViewModel.previewInstance)
        .frame(width: 600, height: 400)
} 