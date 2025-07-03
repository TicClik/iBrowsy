import SwiftUI

struct InlinePriceComparisonView: View {
    let priceData: PriceComparisonData
    let webViewModel: WebViewModel?
    
    var body: some View {
        GlassCard(style: .primary) {
            VStack(alignment: .leading, spacing: 16) {
                // Main response text with enhanced styling
                Text(generateResponseText())
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                
                // Price comparison cards with glass styling
                VStack(spacing: 12) {
                    ForEach(priceData.results.prefix(4)) { result in
                        PriceCardView(result: result, webViewModel: webViewModel)
                    }
                }
                
                // Price accuracy disclaimer with subtle styling
                GlassCard(style: .secondary) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text(disclaimerText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private func generateResponseText() -> String {
        let realPrices = priceData.results.filter { result in
            result.price.hasPrefix("$") && 
            !result.price.contains("Check Current Price") &&
            !result.price.contains("Price Check Required") &&
            result.price != "$0.00"
        }
        
        let totalRetailers = priceData.results.count
        let realPriceCount = realPrices.count
        
        // Check if these are estimated prices from known retailers
        let knownRetailers = ["Amazon", "Best Buy", "Walmart", "Target"]
        let hasKnownRetailers = priceData.results.allSatisfy { result in
            knownRetailers.contains(result.retailer)
        }
        
        if realPriceCount == 0 {
            return "I found \(totalRetailers) retailers for **\(priceData.productName)** but couldn't fetch live prices. Click each card to check current pricing directly."
        } else if realPriceCount >= 2 {
            let priceRange = getPriceRange(from: realPrices)
            
            if hasKnownRetailers {
                return "I found **current market prices** for **\(priceData.productName)** from major retailers. Price range: **\(priceRange)**. Click cards to visit retailer pages."
            } else {
                return "I found **current market prices** for **\(priceData.productName)** from multiple sources. Price range: **\(priceRange)**. Click cards for retailer details."
            }
        } else {
            return "I found \(realPriceCount) price for **\(priceData.productName)**, plus \(totalRetailers - realPriceCount) other retailers to check."
        }
    }
    
    private func getPriceRange(from prices: [PriceResult]) -> String {
        let numericPrices = prices.compactMap { result -> Double? in
            let cleanPrice = result.price.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
            return Double(cleanPrice)
        }
        
        guard !numericPrices.isEmpty else { return "Various prices" }
        
        let minPrice = numericPrices.min() ?? 0
        let maxPrice = numericPrices.max() ?? 0
        
        if minPrice == maxPrice {
            return String(format: "$%.2f", minPrice)
        } else {
            return String(format: "$%.2f - $%.2f", minPrice, maxPrice)
        }
    }
    
    private var disclaimerText: String {
        let knownRetailers = ["Amazon", "Best Buy", "Walmart", "Target"]
        let hasKnownRetailers = priceData.results.allSatisfy { result in
            knownRetailers.contains(result.retailer)
        }
        
        if hasKnownRetailers {
            return "Prices are current market data from major retailers. Click cards to visit retailer pages for purchase options."
        } else {
            return "Prices are current market data from various sources. Click cards for retailer details and purchase options."
        }
    }
}

struct PriceCardView: View {
    let result: PriceResult
    let webViewModel: WebViewModel?
    @State private var isLoading = false
    @State private var isHovered = false
    
    private var logoName: String {
        switch result.retailer.lowercased() {
        case "best buy":
            return "bolt.fill"
        case "amazon":
            return "cart.fill"
        case "apple":
            return "applelogo"
        case "walmart":
            return "building.2.fill"
        case "target":
            return "target"
        case "ebay":
            return "tag.fill"
        default:
            return "bag.fill"
        }
    }
    
    private var hasRealPrice: Bool {
        result.price.hasPrefix("$") && 
        !result.price.contains("Price Check Required") &&
        !result.price.contains("Check Price")
    }
    
    private var priceDisplayText: String {
        if hasRealPrice {
            return result.price
        } else {
            return "Price Check Required"
        }
    }
    
    private var cardStyle: GlassCard<AnyView>.GlassCardStyle {
        if hasRealPrice {
            return isHovered ? .accent : .secondary
        } else {
            return .secondary
        }
    }
    
    var body: some View {
        GlassButton(
            style: hasRealPrice ? (isHovered ? .accent : .primary) : .secondary,
            action: {
                if let urlString = result.url {
                    isLoading = true
                    print("PriceCardView: Opening URL: \(urlString)")
                    
                    if let webViewModel = webViewModel {
                        webViewModel.loadURL(from: urlString)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            isLoading = false
                        }
                    } else {
                        if let url = URL(string: urlString) {
                            NSWorkspace.shared.open(url)
                        }
                        isLoading = false
                    }
                }
            }
        ) {
            HStack(spacing: 16) {
                // Retailer logo with glass background
                GlassCard(style: .floating) {
                    Image(systemName: logoName)
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                }
                .frame(width: 50, height: 50)
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(result.retailer)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 20, height: 20)
                        } else {
                            // Price display with enhanced styling
                            if hasRealPrice {
                                GlassCard(style: .accent) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                        Text(priceDisplayText)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                    }
                                }
                            } else {
                                GlassCard(style: .secondary) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                        Text("Check Required")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Additional info or action hint
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("Click to visit store")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .opacity(isHovered ? 1.0 : 0.7)
                }
                .layoutPriority(1)
            }
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
    }
}

struct InlinePriceComparisonView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleData = PriceComparisonData(
            productName: "MacBook Pro",
            dealCount: 4,
            bestPrice: "$1,899",
            bestDealer: "Best Buy",
            freeShipping: true,
            results: [
                PriceResult(retailer: "Best Buy", price: "$1,899", url: "https://www.bestbuy.com/site/macbook-pro"),
                PriceResult(retailer: "Apple", price: "$1,999", url: "https://www.apple.com/macbook-pro"),
                PriceResult(retailer: "Amazon", price: "$1,949", url: "https://www.amazon.com/dp/B08N5WRWNW"),
                PriceResult(retailer: "Walmart", price: "$1,929", url: "https://www.walmart.com/ip/macbook-pro")
            ]
        )
        
        VStack {
            InlinePriceComparisonView(priceData: sampleData, webViewModel: nil)
                .padding()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
} 