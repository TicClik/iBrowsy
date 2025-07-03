import SwiftUI

struct PriceComparisonResult: Identifiable {
    let id = UUID()
    let siteName: String
    let price: String
    let logoName: String // SF Symbol name or custom image asset name
    let url: String? // Optional URL to the product page
}

struct PriceComparisonData: Codable, Hashable, Equatable {
    let productName: String
    let dealCount: Int
    let bestPrice: String
    let bestDealer: String
    let freeShipping: Bool
    let results: [PriceResult]
}

struct PriceResult: Codable, Identifiable, Hashable, Equatable {
    let id: UUID
    let retailer: String
    let price: String
    let url: String?
    
    enum CodingKeys: String, CodingKey {
        case retailer, price, url
    }
    
    // Custom init from decoder to handle UUID generation
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.retailer = try container.decode(String.self, forKey: .retailer)
        self.price = try container.decode(String.self, forKey: .price)
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        self.id = UUID()
    }
    
    // Custom encode to not include UUID
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(retailer, forKey: .retailer)
        try container.encode(price, forKey: .price)
        try container.encode(url, forKey: .url)
    }
    
    // Direct init for manual creation
    init(retailer: String, price: String, url: String? = nil) {
        self.id = UUID()
        self.retailer = retailer
        self.price = price
        self.url = url
    }
    
    // Custom Equatable implementation since we have UUID
    static func == (lhs: PriceResult, rhs: PriceResult) -> Bool {
        return lhs.retailer == rhs.retailer && lhs.price == rhs.price && lhs.url == rhs.url
    }
    
    // Custom Hashable implementation since we have UUID
    func hash(into hasher: inout Hasher) {
        hasher.combine(retailer)
        hasher.combine(price)
        hasher.combine(url)
    }
} 