import AVFoundation
import SwiftUI

@MainActor
class TextToSpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let speechSynthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking: Bool = false

    override init() {
        super.init()
        speechSynthesizer.delegate = self
    }

    func speak(text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("TextToSpeechService: Attempted to speak empty text.")
            return
        }
        
        // Stop any ongoing speech before starting new one
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        let speechUtterance = AVSpeechUtterance(string: text)
        // Configure utterance properties if needed (e.g., voice, rate, pitch)
        // For now, use defaults
        // Example: Find a suitable voice
        // speechUtterance.voice = AVSpeechSynthesisVoice(language: "en-US") // Or use system's current language

        // Ensure audio session is configured to allow playback - REMOVED FOR MACOS
        // This might be necessary in some app configurations
        // do {
        //     try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        //     try AVAudioSession.sharedInstance().setActive(true)
        // } catch {
        //     print("TextToSpeechService: Failed to set up audio session: \(error.localizedDescription)")
        //     // Optionally, handle this error more gracefully, e.g., by not attempting to speak
        //     // or by informing the user. For now, we'll proceed and let it potentially fail.
        // }
        
        speechSynthesizer.speak(speechUtterance)
        isSpeaking = true
    }

    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    // MARK: - AVSpeechSynthesizerDelegate Methods

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = true
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            // Deactivate audio session if it's appropriate for your app's audio handling - REMOVED FOR MACOS
            // do {
            //     try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            // } catch {
            //     print("TextToSpeechService: Failed to deactivate audio session: \(error.localizedDescription)")
            // }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        // Optional: Handle pause if you add pause functionality
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        // Optional: Handle continue if you add pause functionality
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
} 