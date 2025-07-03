import SwiftUI

class MascotViewModel: ObservableObject {
    @Published var currentIdleImage: NSImage?
    @Published var currentThinkingImage: NSImage?
    // For .talking and .error, we'll initially rely on SF Symbols in the View.
    // You can add properties for custom images for these states if needed:
    // @Published var currentTalkingImage: NSImage?
    // @Published var currentErrorImage: NSImage?

    @Published var mascotState: MascotState = .idle
    @Published var customMessage: String? = nil
    @Published var debugMessage: String = ""

    private var idleImages: [NSImage] = []
    private var thinkingImages: [NSImage] = []
    // private var talkingImages: [NSImage] = [] // If .talking gets custom animation
    // private var errorImages: [NSImage] = []   // If .error gets custom animation

    private var idleAnimationTimer: Timer?
    private var thinkingAnimationTimer: Timer?
    // private var talkingAnimationTimer: Timer?

    private var idleFrameIndex = 0
    private var thinkingFrameIndex = 0
    // private var talkingFrameIndex = 0

    // Configuration for animation frames (can be adjusted)
    private let idleAnimationFrameCount = 10
    private let thinkingAnimationFrameCount = 10
    // private let talkingAnimationFrameCount = 10 // Example if .talking is animated

    private let animationFrameRate = 1.0 / 15.0 // Approx 15 FPS

    init() {
        loadImages()
        // Set initial state and trigger animation if needed (e.g., if state starts as .idle)
        // The view's onAppear will call changeState to ensure initial animation setup.
    }

    private func loadImages() {
        guard let resourcePath = Bundle.main.resourcePath else {
            self.debugMessage = "Error: Unable to find resource path for mascot images."
            print(self.debugMessage)
            return
        }

        // Primary path for idle images (preferred subdirectory structure)
        let primaryIdlePath = "\(resourcePath)/MascotImage/idle"
        idleImages = loadFrames(from: primaryIdlePath, baseName: "mascot_idle", frameCount: idleAnimationFrameCount)

        if !idleImages.isEmpty {
            currentIdleImage = idleImages[0]
        } else {
            self.debugMessage += "Error: No idle images loaded from primary path: \(primaryIdlePath).\n"
            print("Error: No idle images loaded from primary path: \(primaryIdlePath).")
            
            // First fallback for idle (previously implemented)
            let fallbackIdlePath = "\(resourcePath)/Images/Mascot/idle"
            print("Attempting to load idle images from fallback path: \(fallbackIdlePath)")
            idleImages = loadFrames(from: fallbackIdlePath, baseName: "mascot_idle", frameCount: idleAnimationFrameCount)
            
            if !idleImages.isEmpty {
                currentIdleImage = idleImages[0]
                let warningMsg = "Warning: Loaded idle images from fallback: \(fallbackIdlePath). Bundle to 'MascotImage/idle/'.\n"
                self.debugMessage += warningMsg
                print(warningMsg)
            } else {
                // New fallback: Try the root Resources directory
                print("Attempting to load idle images from Resources root path: \(resourcePath)")
                idleImages = loadFrames(from: resourcePath, baseName: "mascot_idle", frameCount: idleAnimationFrameCount)
                
                if !idleImages.isEmpty {
                    currentIdleImage = idleImages[0]
                    let warningMsg = "Warning: Loaded idle images from Resources root. Consider updating build to use subdirectories.\n"
                    self.debugMessage += warningMsg
                    print(warningMsg)
                } else {
                    let errorMsg = "Error: Failed to load idle images from any path.\n"
                    self.debugMessage += errorMsg
                    print(errorMsg)
                }
            }
        }
        
        // Primary path for thinking images
        let primaryThinkingPath = "\(resourcePath)/MascotImage/thinking"
        thinkingImages = loadFrames(from: primaryThinkingPath, baseName: "mascot_thinking", frameCount: thinkingAnimationFrameCount)

        if !thinkingImages.isEmpty {
            currentThinkingImage = thinkingImages[0]
        } else {
            self.debugMessage += "Error: No thinking images loaded from primary path: \(primaryThinkingPath).\n"
            print("Error: No thinking images loaded from primary path: \(primaryThinkingPath).")
            
            // First fallback for thinking
            let fallbackThinkingPath = "\(resourcePath)/Images/Mascot/thinking"
            print("Attempting to load thinking images from fallback path: \(fallbackThinkingPath)")
            thinkingImages = loadFrames(from: fallbackThinkingPath, baseName: "mascot_thinking", frameCount: thinkingAnimationFrameCount)
            
            if !thinkingImages.isEmpty {
                currentThinkingImage = thinkingImages[0]
                let warningMsg = "Warning: Loaded thinking images from fallback: \(fallbackThinkingPath). Bundle to 'MascotImage/thinking/'.\n"
                self.debugMessage += warningMsg
                print(warningMsg)
            } else {
                // New fallback: Try the root Resources directory
                print("Attempting to load thinking images from Resources root path: \(resourcePath)")
                thinkingImages = loadFrames(from: resourcePath, baseName: "mascot_thinking", frameCount: thinkingAnimationFrameCount)
                
                if !thinkingImages.isEmpty {
                    currentThinkingImage = thinkingImages[0]
                    let warningMsg = "Warning: Loaded thinking images from Resources root. Consider updating build to use subdirectories.\n"
                    self.debugMessage += warningMsg
                    print(warningMsg)
                } else {
                    let errorMsg = "Error: Failed to load thinking images from any path.\n"
                    self.debugMessage += errorMsg
                    print(errorMsg)
                }
            }
        }
        
        if idleImages.isEmpty && thinkingImages.isEmpty {
             self.debugMessage = "Critical: No mascot images (idle or thinking) could be loaded."
        } else if self.debugMessage.isEmpty {
            self.debugMessage = "Mascot images loaded. Idle: \(idleImages.count)/\(idleAnimationFrameCount), Thinking: \(thinkingImages.count)/\(thinkingAnimationFrameCount)."
        }
    }

    private func loadFrames(from path: String, baseName: String, frameCount: Int) -> [NSImage] {
        var frames: [NSImage] = []
        if frameCount == 0 { return frames } // No frames to load
        for i in 0..<frameCount {
            let imagePath = "\(path)/\(baseName)_\(i).png"
            if let image = NSImage(contentsOfFile: imagePath) {
                frames.append(image)
            }
        }
        if frames.isEmpty && frameCount > 0 {
             print("Debug: No frames loaded from path \(path) for baseName \(baseName). Checked for \(frameCount) frames.")
        }
        return frames
    }

    private func stopAllAnimations() {
        idleAnimationTimer?.invalidate()
        thinkingAnimationTimer?.invalidate()
        // talkingAnimationTimer?.invalidate() // If .talking gets animated
        currentIdleImage = idleImages.first // Reset to first frame
        currentThinkingImage = thinkingImages.first // Reset to first frame
    }

    func changeState(to newState: MascotState) {
        stopAllAnimations()
        self.mascotState = newState
        self.customMessage = nil // Clear custom message when changing to a standard state

        switch newState {
        case .idle:
            if !idleImages.isEmpty {
                currentIdleImage = idleImages[0]
                startIdleAnimationLoop()
            } else {
                // View will use SF Symbol
            }
        case .thinking:
            if !thinkingImages.isEmpty {
                currentThinkingImage = thinkingImages[0]
                startThinkingAnimationLoop()
            } else {
                // View will use SF Symbol
            }
        case .talking:
            // Currently relies on SF Symbol in View.
            // Add logic here if .talking state gets custom images/animations.
            // E.g., loadTalkingImages(), startTalkingAnimationLoop()
            break 
        case .error:
            // Currently relies on SF Symbol in View.
            break
        case .customMessage:
            // This state is typically set via showCustomMessage().
            // If set directly, ensure customMessage is not nil or provide default.
            if self.customMessage == nil { self.customMessage = "..." }
            break
        }
    }
    
    private func startIdleAnimationLoop() {
        guard !idleImages.isEmpty else { return }
        idleFrameIndex = 0
        currentIdleImage = idleImages[idleFrameIndex]
        idleAnimationTimer = Timer.scheduledTimer(withTimeInterval: animationFrameRate, repeats: true) { [weak self] _ in
            self?.updateIdleFrame()
        }
    }

    private func updateIdleFrame() {
        guard !idleImages.isEmpty else {
            idleAnimationTimer?.invalidate()
            return
        }
        idleFrameIndex = (idleFrameIndex + 1) % idleImages.count
        currentIdleImage = idleImages[idleFrameIndex]
    }

    private func startThinkingAnimationLoop() {
        guard !thinkingImages.isEmpty else { return }
        thinkingFrameIndex = 0
        currentThinkingImage = thinkingImages[thinkingFrameIndex]
        thinkingAnimationTimer = Timer.scheduledTimer(withTimeInterval: animationFrameRate, repeats: true) { [weak self] _ in
            self?.updateThinkingFrame()
        }
    }

    private func updateThinkingFrame() {
        guard !thinkingImages.isEmpty else {
            thinkingAnimationTimer?.invalidate()
            return
        }
        thinkingFrameIndex = (thinkingFrameIndex + 1) % thinkingImages.count
        currentThinkingImage = thinkingImages[thinkingFrameIndex]
    }
    
    func showCustomMessage(_ message: String, duration: TimeInterval = 3.0) {
        stopAllAnimations()
        self.customMessage = message
        self.mascotState = .customMessage
        
        // Optional: revert to idle after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            // Only revert if still in custom message state with the same message
            if self.mascotState == .customMessage && self.customMessage == message {
                self.changeState(to: .idle)
            }
        }
    }
}

struct MascotView: View {
    @StateObject var viewModel = MascotViewModel()
    var mascotSize: CGFloat = 50 // Configurable size
    
    // SF Symbol helpers
    private func symbolNameForState(_ state: MascotState) -> String {
        switch state {
        case .idle: return "figure.stand"
        case .thinking: return "brain.head.profile"
        case .talking: return "bubble.left.and.bubble.right.fill" // Using fill for talking
        case .error: return "exclamationmark.triangle.fill"
        case .customMessage: return "info.circle.fill" // Symbol for when showing custom message text
        }
    }
    
    private func colorForState(_ state: MascotState) -> Color {
        switch state {
        case .error: return .red
        case .talking: return .blue // Example color for talking
        default: return .secondary // Standard color for other symbols
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Group {
                if viewModel.mascotState == .idle, let image = viewModel.currentIdleImage {
                    Image(nsImage: image)
                        .resizable().aspectRatio(contentMode: .fit)
                } else if viewModel.mascotState == .thinking, let image = viewModel.currentThinkingImage {
                    Image(nsImage: image)
                        .resizable().aspectRatio(contentMode: .fit)
                } else if viewModel.mascotState == .customMessage, let message = viewModel.customMessage {
                    Text(message)
                        .font(.system(size: mascotSize * 0.25, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding(mascotSize * 0.1)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(mascotSize * 0.1)
                        .foregroundColor(.primary)
                    // Ensure text display fits well with mascotSize
                        .frame(minWidth: mascotSize, idealWidth: mascotSize * 2, maxWidth: mascotSize * 2.5, minHeight: mascotSize)
                        .fixedSize(horizontal: false, vertical: true)
                } else { // Fallback to SF Symbol for other states (error, talking) or if images are nil
                    Image(systemName: symbolNameForState(viewModel.mascotState))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(colorForState(viewModel.mascotState))
                        .symbolRenderingMode(.hierarchical) // Improves SF Symbol appearance
                }
            }
            .frame(width: mascotSize, height: mascotSize)
            .padding(2) // Small padding around the mascot image/symbol
                
#if DEBUG
            if !viewModel.debugMessage.isEmpty {
                Text(viewModel.debugMessage)
                    .font(.system(size: 10)) // Slightly larger debug text
                    .foregroundColor(.red)
                    .frame(maxWidth: mascotSize * 3) // Wider debug area
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true) // Allows text to wrap
                    .padding(.horizontal, 4)
            }
#endif
        }
        .onAppear {
            // Ensure the initial state's animation (e.g., idle) is correctly started.
            // The ViewModel's init loads images. changeState will handle animation.
            viewModel.changeState(to: viewModel.mascotState)
        }
    }
    
    // Preview (optional, but helpful for UI development)
#if DEBUG
    struct MascotView_Previews: PreviewProvider {
        static var previews: some View {
            VStack(spacing: 20) {
                MascotView(mascotSize: 60) // Default state (idle)
                
                MascotView(viewModel: {
                    let vm = MascotViewModel()
                    vm.changeState(to: .thinking)
                    return vm
                }(), mascotSize: 60)
                
                MascotView(viewModel: {
                    let vm = MascotViewModel()
                    vm.changeState(to: .talking)
                    return vm
                }(), mascotSize: 60)
                
                MascotView(viewModel: {
                    let vm = MascotViewModel()
                    vm.changeState(to: .error)
                    return vm
                }(), mascotSize: 60)
                
                MascotView(viewModel: {
                    let vm = MascotViewModel()
                    vm.showCustomMessage("This is a test message that might be quite long and should wrap nicely.")
                    return vm
                }(), mascotSize: 70)
                
                MascotView(viewModel: {
                    let vm = MascotViewModel()
                    vm.debugMessage = "This is a debug message visible for testing layout and content. It can be multiple lines."
                    // Simulate no images loaded for idle to test SF symbol
                    // To properly test, you'd prevent images from loading in MascotViewModel
                    // or pass a viewmodel where currentIdleImage is nil.
                    return vm
                }(), mascotSize: 60)
            }
            .padding()
            .previewLayout(.sizeThatFits)
        }
    }
#endif
}
