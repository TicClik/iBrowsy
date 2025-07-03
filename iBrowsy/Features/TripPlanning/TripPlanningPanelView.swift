import SwiftUI

struct TripPlanningPanelView: View {
    @EnvironmentObject var webViewModel: WebViewModel
    let tripInfo: TripPlanningInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Trip Planning Assistant")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 5)

            HStack {
                Image(systemName: getIconName(for: tripInfo.task))
                    .font(.title3)
                    .foregroundColor(.blue)
                Text(getTaskTitle(for: tripInfo.task))
                    .font(.headline)
            }

            if let destination = tripInfo.destination {
                Text("Destination: \(destination)")
            }
            if let origin = tripInfo.origin {
                Text("Origin: \(origin)")
            }
            if let dates = tripInfo.dates {
                Text("Dates: \(dates)")
            }
            if let duration = tripInfo.duration {
                Text("Duration: \(duration)")
            }

            if let additionalParams = tripInfo.additionalParameters, !additionalParams.isEmpty {
                Text("Other Details:")
                ForEach(additionalParams.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    Text("\(key.capitalized): \(value)")
                }
            }

            Spacer()

            actionButton
        }
        .padding()
        .frame(minWidth: 300, idealWidth: 400, maxWidth: 500, minHeight: 200, idealHeight: 300, maxHeight: 400)
    }

    private func getIconName(for task: String) -> String {
        switch task {
        case "find_flights":
            return "airplane.circle.fill"
        case "suggest_attractions":
            return "mappin.and.ellipse.circle.fill"
        case "outline_itinerary":
            return "list.bullet.clipboard.fill"
        default:
            return "questionmark.circle.fill"
        }
    }

    private func getTaskTitle(for task: String) -> String {
        switch task {
        case "find_flights":
            return "Find Flights"
        case "suggest_attractions":
            return "Suggest Attractions"
        case "outline_itinerary":
            return "Outline Itinerary"
        default:
            return "Trip Task"
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        // Generate search URLs based on the task
        // For simplicity, we'll use Google for these examples.
        // These would ideally be configurable or use specialized travel APIs.
        Group {
            switch tripInfo.task {
            case "find_flights":
                if let destination = tripInfo.destination, let origin = tripInfo.origin {
                    let query = "flights from \(origin) to \(destination) \(tripInfo.dates ?? "")"
                    if let url = generateSearchURL(provider: "Google Flights", query: query) {
                        Link("Search on Google Flights", destination: url)
                            .buttonStyle(.borderedProminent)
                    }
                } else if let destination = tripInfo.destination {
                     let query = "flights to \(destination) \(tripInfo.dates ?? "")"
                    if let url = generateSearchURL(provider: "Google Flights", query: query) {
                        Link("Search on Google Flights", destination: url)
                            .buttonStyle(.borderedProminent)
                    }
                }
            case "suggest_attractions":
                if let destination = tripInfo.destination {
                    let query = "top attractions in \(destination)"
                    if let url = generateSearchURL(provider: "Google Maps", query: query) {
                        Link("Search Attractions on Google Maps", destination: url)
                            .buttonStyle(.borderedProminent)
                    }
                     if let url = generateSearchURL(provider: "TripAdvisor", query: query) {
                        Link("Search Attractions on TripAdvisor", destination: url)
                            .buttonStyle(.bordered)
                    }
                }
            case "outline_itinerary":
                if let destination = tripInfo.destination {
                    let query = "\(tripInfo.duration ?? "") itinerary for \(destination)"
                    if let url = generateSearchURL(provider: "Google Search", query: query) {
                        Link("Search for Itinerary Ideas", destination: url)
                            .buttonStyle(.borderedProminent)
                    }
                }
            default:
                Text("No specific action available for this task.")
            }
        }
    }

    private func generateSearchURL(provider: String, query: String) -> URL? {
        var components = URLComponents()
        switch provider {
        case "Google Flights":
            components.scheme = "https"
            components.host = "www.google.com"
            components.path = "/flights"
            components.queryItems = [URLQueryItem(name: "q", value: query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))]
        case "Google Maps":
            components.scheme = "https"
            components.host = "www.google.com"
            components.path = "/maps/search/"
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
            // Google Maps uses the query directly in the path for searches
            // So, we append the encoded query to the path.
            // Example: https://www.google.com/maps/search/top+attractions+in+Paris
            // This might need adjustment based on exact Google Maps URL structure.
            // For a more robust solution, consider using specific parameters if available.
             if !encodedQuery.isEmpty {
                components.path += encodedQuery
            } else {
                return nil
            }
        case "TripAdvisor":
            components.scheme = "https"
            components.host = "www.tripadvisor.com"
            components.path = "/Search"
            components.queryItems = [URLQueryItem(name: "q", value: query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))]
        case "Google Search":
            components.scheme = "https"
            components.host = "www.google.com"
            components.path = "/search"
            components.queryItems = [URLQueryItem(name: "q", value: query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))]
        default:
            return nil
        }
        return components.url
    }
}

struct TripPlanningPanelView_Previews: PreviewProvider {
    static var previews: some View {
        // Sample data for preview
        let sampleFlights = TripPlanningInfo(task: "find_flights", destination: "Paris", origin: "NYC", dates: "next week")
        let sampleAttractions = TripPlanningInfo(task: "suggest_attractions", destination: "Rome")
        let sampleItinerary = TripPlanningInfo(task: "outline_itinerary", destination: "Tokyo", duration: "3-day")

        Group {
            TripPlanningPanelView(tripInfo: sampleFlights)
                .environmentObject(WebViewModel())
                .previewLayout(.sizeThatFits)
                .padding()
                .previewDisplayName("Flights Example")

            TripPlanningPanelView(tripInfo: sampleAttractions)
                .environmentObject(WebViewModel())
                .previewLayout(.sizeThatFits)
                .padding()
                .previewDisplayName("Attractions Example")

            TripPlanningPanelView(tripInfo: sampleItinerary)
                .environmentObject(WebViewModel())
                .previewLayout(.sizeThatFits)
                .padding()
                .previewDisplayName("Itinerary Example")
        }
    }
} 