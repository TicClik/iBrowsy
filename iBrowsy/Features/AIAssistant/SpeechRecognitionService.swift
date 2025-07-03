import Speech
import AVFoundation
import Combine

enum SpeechRecognitionError: Error, LocalizedError {
    case notAuthorizedToRecognize
    case recognizerUnavailable
    case audioEngineError(String)
    case recognitionTaskError(String)
    case permissionDenied(String)
    case genericError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorizedToRecognize:
            return "Speech recognition authorization was denied or not determined."
        case .recognizerUnavailable:
            return "The speech recognizer is not available for the current locale."
        case .audioEngineError(let message):
            return "Audio engine error: \(message)"
        case .recognitionTaskError(let message):
            return "Recognition task error: \(message)"
        case .permissionDenied(let type):
            return "Permission for \(type) was denied. Please check System Settings."
        case .genericError(let message):
            return message
        }
    }
}

@MainActor
class SpeechRecognitionService: NSObject, SFSpeechRecognizerDelegate, ObservableObject {

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @Published var isListening = false
    @Published var transcribedText: String = ""
    @Published var lastError: SpeechRecognitionError? = nil

    private var speechPermissionContinuation: CheckedContinuation<Bool, Never>?

    override init() {
        super.init()
        speechRecognizer?.delegate = self
    }

    var isAvailable: Bool {
        return speechRecognizer?.isAvailable ?? false && SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    func requestPermissions() async -> Bool {
        return await withCheckedContinuation { continuation in
            self.speechPermissionContinuation = continuation
            SFSpeechRecognizer.requestAuthorization { authStatus in
                DispatchQueue.main.async {
                    switch authStatus {
                    case .authorized:
                        self.speechPermissionContinuation?.resume(returning: true)
                    case .denied, .restricted, .notDetermined:
                        self.lastError = .permissionDenied("Speech Recognition")
                        self.speechPermissionContinuation?.resume(returning: false)
                    @unknown default:
                        self.lastError = .genericError("Unknown speech recognition authorization status.")
                        self.speechPermissionContinuation?.resume(returning: false)
                    }
                    self.speechPermissionContinuation = nil
                }
            }
        }
    }

    func startListening() async {
        guard await requestPermissions() else {
            isListening = false
            return
        }

        if speechRecognizer?.isAvailable == false {
            lastError = .recognizerUnavailable
            isListening = false
            return
        }
        
        if SFSpeechRecognizer.authorizationStatus() != .authorized {
            lastError = .notAuthorizedToRecognize
            isListening = false
            return
        }

        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            lastError = .genericError("Unable to create SFSpeechAudioBufferRecognitionRequest")
            isListening = false
            return
        }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        
        guard inputNode.inputFormat(forBus: 0).channelCount > 0 else {
            lastError = .audioEngineError("No audio input device found or input device has no channels. Please check microphone settings.")
            isListening = false
            if audioEngine.isRunning { audioEngine.stop() }
            return
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            var isFinal = false

            if let result = result {
                self.transcribedText = result.bestTranscription.formattedString
                isFinal = result.isFinal
                if isFinal {
                     print("Final transcription: \(self.transcribedText)")
                }
            }

            if error != nil || isFinal {
                self.stopListening()
            }
            
            if let error = error {
                 self.lastError = .recognitionTaskError("Recognition task failed: \(error.localizedDescription)")
                 print("Recognition task error: \(error.localizedDescription)")
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
            transcribedText = ""
            lastError = nil
            print("SpeechRecognitionService: Listening started.")
        } catch {
            lastError = .audioEngineError("Audio engine failed to start: \(error.localizedDescription). Check microphone permissions in System Settings.")
            self.recognitionRequest = nil
            recognitionTask = nil
            isListening = false
            print("Audio engine start error: \(error.localizedDescription)")
        }
    }

    func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.finish()

        recognitionRequest = nil
        recognitionTask = nil
        
        isListening = false
        print("SpeechRecognitionService: Listening stopped.")
    }

    nonisolated public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available {
                self.lastError = .recognizerUnavailable
                self.stopListening()
                 print("Speech recognizer became unavailable.")
            } else {
                 print("Speech recognizer became available.")
            }
        }
    }
} 