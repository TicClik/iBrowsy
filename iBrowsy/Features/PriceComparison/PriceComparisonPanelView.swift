import SwiftUI

struct PriceComparisonPanelView: View {
    @ObservedObject var assistantViewModel: AssistantViewModel
    @ObservedObject var webViewModel: WebViewModel // To open URLs

    private var productName: String {
        assistantViewModel.priceComparisonProductName ?? "Product"
    }

    private var productDisplayName: String {
        var name = assistantViewModel.priceComparisonProductName ?? "Selected Product"
        if let brand = assistantViewModel.priceComparisonProductBrand, !brand.isEmpty {
            name = "\(brand) \(name)"
        }
        if let model = assistantViewModel.priceComparisonProductModel, !model.isEmpty {
            name = "\(name) (\(model))"
        }
        return name
    }

    private func generateSearchURL(for site: String, baseQuery: String) -> URL? {
        var components = URLComponents()
        var queryItems = [URLQueryItem]()
        let encodedQuery = baseQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        switch site.lowercased() {
        case "google shopping":
            components.scheme = "https"
            components.host = "shopping.google.com"
            components.path = "/search"
            queryItems.append(URLQueryItem(name: "q", value: encodedQuery))
        case "amazon":
            components.scheme = "https"
            components.host = "www.amazon.com"
            components.path = "/s"
            queryItems.append(URLQueryItem(name: "k", value: encodedQuery))
        case "best buy":
            components.scheme = "https"
            components.host = "www.bestbuy.com"
            components.path = "/site/searchpage.jsp"
            queryItems.append(URLQueryItem(name: "st", value: encodedQuery))
        case "ebay":
            components.scheme = "https"
            components.host = "www.ebay.com"
            components.path = "/sch/i.html"
            queryItems.append(URLQueryItem(name: "_nkw", value: encodedQuery))
        default:
            return nil
        }
        components.queryItems = queryItems
        return components.url
    }

    private var comparisonSites: [PriceComparisonResult] {
        let baseQuery = assistantViewModel.priceComparisonProductName ?? "product"
        var sites: [PriceComparisonResult] = []

        if let url = generateSearchURL(for: "Google Shopping", baseQuery: baseQuery) {
            sites.append(PriceComparisonResult(siteName: "Google Shopping", price: "Search", logoName: "magnifyingglass", url: url.absoluteString)) // Placeholder logo
        }
        if let url = generateSearchURL(for: "Amazon", baseQuery: baseQuery) {
            sites.append(PriceComparisonResult(siteName: "Amazon", price: "Search", logoName: "cart", url: url.absoluteString)) // Placeholder logo
        }
        if let url = generateSearchURL(for: "Best Buy", baseQuery: baseQuery) {
            sites.append(PriceComparisonResult(siteName: "Best Buy", price: "Search", logoName: "bolt.fill", url: url.absoluteString)) // Placeholder logo
        }
        if let url = generateSearchURL(for: "eBay", baseQuery: baseQuery) {
            sites.append(PriceComparisonResult(siteName: "eBay", price: "Search", logoName: "tag", url: url.absoluteString)) // Placeholder logo
        }
        return sites
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack { // Use HStack for title and Done button
                VStack(alignment: .leading, spacing: 4) {
                    Text("Price Comparison")
                        .font(.title2) // Adjusted font size for sheet context
                        .fontWeight(.bold)
                    
                    Text("Searching for: \(productDisplayName)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                Spacer() // Push Done button to the right
                Button("Done") {
                    assistantViewModel.isPriceComparisonPanelPresented = false
                }
                .padding(.trailing) // Add padding to the Done button
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.windowBackgroundColor).opacity(0.5)) // Subtle background

            Divider()

            // Results List
            if comparisonSites.isEmpty {
                Spacer()
                Text("Could not generate search links for \"\(productName)\".")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else {
                List {
                    ForEach(comparisonSites) { site in
                        Button(action: {
                            if let urlString = site.url {
                                webViewModel.loadURL(from: urlString)
                            }
                            assistantViewModel.isPriceComparisonPanelPresented = false // Dismiss panel
                        }) {
                            HStack {
                                Image(systemName: site.logoName)
                                    .font(.title2)
                                    .frame(width: 30)
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading) {
                                    Text(site.siteName)
                                        .font(.headline)
                                    Text("Search for \"\(productName)\" on \(site.siteName)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain) // Use plain button style for list items
                    }
                }
                .listStyle(.inset)
            }
            
            Spacer()
        }
        .frame(minWidth: 400, idealWidth: 500, maxWidth: 600, minHeight: 300, idealHeight: 400, maxHeight: 500)
    }
}

struct PriceComparisonPanelView_Previews: PreviewProvider {
    static var previews: some View {
        // Create mock ViewModels for previewing
        let webVM = WebViewModel() 
        let bookmarkMgr = BookmarkManager()
        let assistantVM = AssistantViewModel(webViewModel: webVM, bookmarkManager: bookmarkMgr)
        
        // Establish the link from WebViewModel back to AssistantViewModel
        webVM.assistantViewModel = assistantVM

        assistantVM.priceComparisonProductName = "Example Laptop Pro"
        assistantVM.priceComparisonProductBrand = "TechBrand"
        assistantVM.priceComparisonProductModel = "X1000"
        assistantVM.isPriceComparisonPanelPresented = true // To make the panel visible in preview

        return PriceComparisonPanelView(assistantViewModel: assistantVM, webViewModel: webVM)
    }
} 