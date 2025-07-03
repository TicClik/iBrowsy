import AppKit
import Combine

enum ScreenCaptureError: Error, LocalizedError {
    case captureFailed(String)
    case pasteboardError(String)
    case userCancelled
    case processError(String)

    var errorDescription: String? {
        switch self {
        case .captureFailed(let reason):
            return "Screen capture failed: \(reason)"
        case .pasteboardError(let reason):
            return "Could not retrieve image from pasteboard: \(reason)"
        case .userCancelled:
            return "Screen capture was cancelled by the user."
        case .processError(let reason):
            return "Screen capture process error: \(reason)"
        }
    }
}

@MainActor
class ScreenCaptureService: ObservableObject {

    func captureRectangularSelection() async throws -> NSImage {
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        // -i: interactive mode (user selects area)
        // -c: copy to clipboard
        // -x: do not play sound
        task.arguments = ["-i", "-c", "-x"]

        return try await withCheckedThrowingContinuation { continuation in
            task.terminationHandler = { process in
                DispatchQueue.main.async {
                    if process.terminationStatus == 0 {
                        // Check pasteboard for an image
                        if let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
                            continuation.resume(returning: image)
                        } else {
                            continuation.resume(throwing: ScreenCaptureError.pasteboardError("No image found on pasteboard."))
                        }
                    } else {
                        // screencapture utility exits with non-zero status if user presses Esc (cancels)
                        // Other non-zero statuses could indicate other errors.
                        // For simplicity, we'll treat any non-zero as cancellation or failure.
                        // A more robust solution might inspect error output from the process.
                        continuation.resume(throwing: ScreenCaptureError.userCancelled)
                    }
                }
            }

            do {
                try task.run()
            } catch {
                continuation.resume(throwing: ScreenCaptureError.processError("Failed to run screencapture process: \(error.localizedDescription)"))
            }
        }
    }
} 