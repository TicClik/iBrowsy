import Foundation

struct TripPlanningInfo: Identifiable, Equatable {
    let id = UUID()
    var task: String // e.g., "find_flights", "suggest_attractions", "outline_itinerary"
    var destination: String?
    var origin: String?
    var dates: String?
    var duration: String?
    var additionalParameters: [String: String]? // For any other dynamic parameters

    // Equatable conformance for testing and state management
    static func == (lhs: TripPlanningInfo, rhs: TripPlanningInfo) -> Bool {
        lhs.id == rhs.id &&
        lhs.task == rhs.task &&
        lhs.destination == rhs.destination &&
        lhs.origin == rhs.origin &&
        lhs.dates == rhs.dates &&
        lhs.duration == rhs.duration &&
        lhs.additionalParameters == rhs.additionalParameters
    }
} 