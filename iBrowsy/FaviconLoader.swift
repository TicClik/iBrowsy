import SwiftUI
import Combine
import AppKit // Needed for NSImage

// Class responsible for fetching and caching favicons
@MainActor // Ensure published changes happen on the main thread
class FaviconLoader: ObservableObject {
    // Cache for storing fetched favicons (using NSImage for macOS)
    private var cache = NSCache<NSString, NSImage>()
    // Keep track of hosts currently being fetched to avoid redundant requests
    private var currentlyFetching = Set<String>()
    // Store ongoing fetch tasks to allow waiting for Data
    private var fetchTasks = [String: Task<Data?, Never>]()

    // Shared instance for easy access
    static let shared = FaviconLoader()

    // Private init for singleton pattern
    private init() {}

    // --- NEW Async function --- 
    /// Asynchronously fetches and returns a favicon `Image` for a given URL string.
    /// Returns `nil` if the URL is invalid or the favicon cannot be fetched.
    public func getFavicon(for urlString: String) async -> Image? {
        guard let url = URL(string: urlString), let host = url.host else {
            return nil
        }

        let cacheKey = host as NSString

        // 1. Check cache first
        if let cachedImage = cache.object(forKey: cacheKey) {
            return Image(nsImage: cachedImage)
        }

        // 2. Check if already fetching this host
        if let existingTask = fetchTasks[host] {
            // Wait for the existing task to complete
            if let imageData = await existingTask.value {
                if let nsImage = NSImage(data: imageData) {
                    cache.setObject(nsImage, forKey: cacheKey) // Cache if successfully created
                    return Image(nsImage: nsImage)
                }
            }
            // If task existed but resulted in nil data or failed NSImage creation
            return nil
        }

        // 3. Not cached, not currently fetching -> Start a new fetch task for Data
        let newTask = Task<Data?, Never> {
             // Note: currentlyFetching is accessed from @MainActor context before task creation
             // and modified inside the task. This is okay as Set<String> is Sendable.
             // However, for clarity and strictness, mutations to currentlyFetching
             // could also be wrapped in Task { @MainActor in ... } if needed,
             // but it's likely fine here as the task captures 'host'.

            var fetchedData: Data? = nil

            // Strategy 1: Try default /favicon.ico path
            if let defaultFaviconURL = URL(string: "https://\(host)/favicon.ico") {
                 fetchedData = await fetchImageData(from: defaultFaviconURL)
            }

            // Strategy 2: Try Google S2 service if default failed
            if fetchedData == nil,
               let googleFaviconURL = URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64") {
                fetchedData = await fetchImageData(from: googleFaviconURL)
            }
            
            // This part of the task (after await) runs on the task's thread.
            // It's okay to remove from currentlyFetching here.
            // Removal from fetchTasks and caching NSImage will be done on MainActor.

             // Return the fetched data
             return fetchedData
        }

        // Store the new task
        fetchTasks[host] = newTask
        
        // Wait for the new task to complete and get Data
        if let imageData = await newTask.value {
            // Now on MainActor, create NSImage and cache
            if let nsImage = NSImage(data: imageData) {
                self.cache.setObject(nsImage, forKey: cacheKey)
                self.currentlyFetching.remove(host) // Clean up on main actor
                self.fetchTasks[host] = nil         // Clean up on main actor
                return Image(nsImage: nsImage)
            } else {
                // Failed to create NSImage from fetched data
            }
        } else {
            // Data fetch task failed
        }
        
        // Common cleanup point on MainActor if any step above failed before returning nil
        self.currentlyFetching.remove(host)
        self.fetchTasks[host] = nil
        return nil
    }

    /// Helper function to fetch image data from a URL asynchronously.
    private func fetchImageData(from url: URL) async -> Data? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }

    // --- Deprecated/Removed Combine-based functions --- 
    /*
    func favicon(for urlString: String) -> Image? { ... }
    private func fetchFavicon(for host: String) { ... }
    private func fetchFaviconFromGoogleS2(for host: String) { ... }
    */
} 