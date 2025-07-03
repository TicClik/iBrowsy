import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: WebViewModel
    @State private var searchText = ""
    
    private var filteredHistory: [HistoryItem] {
        if searchText.isEmpty {
            return viewModel.historyItems
        } else {
            return viewModel.historyItems.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
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
                        
                        Text("Browsing History")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        GlassButton(style: .accent, action: {
                            viewModel.clearHistory()
                        }) {
                            Text("Clear All")
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding()
                
                // Search field
                VStack {
                    GlassTextField("Search History", text: $searchText, style: .primary)
                        .padding(.horizontal)
                }
                .padding(.bottom)
                
                if filteredHistory.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "clock")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        if searchText.isEmpty {
                            Text("No browsing history")
                                .font(.headline)
                            
                            Text("Your browsing history will appear here")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("No matching results")
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
                        ForEach(filteredHistory) { item in
                            HistoryItemView(item: item, viewModel: viewModel)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let item = filteredHistory[index]
                                viewModel.removeHistoryItem(id: item.id)
                            }
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

struct HistoryItemView: View {
    let item: HistoryItem
    let viewModel: WebViewModel
    
    // Date formatter for the relative time
    private let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
    var body: some View {
        GlassCard(style: .primary) {
            Button {
                viewModel.loadURL(from: item.urlString)
            } label: {
                HStack(spacing: 12) {
                    // Favicon placeholder
                    Image(systemName: "globe")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(item.urlString)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Text(relativeDateFormatter.localizedString(for: item.date, relativeTo: Date()))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}

#Preview {
    HistoryView(viewModel: WebViewModel.previewInstance)
        .frame(width: 600, height: 400)
} 