import SwiftUI

struct AssistantView: View {
    // Use @ObservedObject for the ViewModel passed from ContentView
    @ObservedObject var viewModel: AssistantViewModel
    let webViewModel: WebViewModel?
    @State private var showingSettings = false
    @FocusState private var isInputFocused: Bool
    @StateObject private var mascotViewModel = MascotViewModel() // Hold MascotViewModel as a StateObject
    
    init(viewModel: AssistantViewModel, webViewModel: WebViewModel? = nil) {
        self.viewModel = viewModel
        self.webViewModel = webViewModel
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Clean chat area
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.chatHistory) { message in
                            ChatMessageView(message: message, webViewModel: webViewModel)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .onChange(of: viewModel.chatHistory) { newMessages in
                    if let lastMessage = newMessages.last {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            scrollViewProxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Streamlined input section
            inputSection
        }
        .background(liquidGlassBackground)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.showWelcomeBubble)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.showIdlePromptBubble)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.isSpeaking)
        .onChange(of: viewModel.mascotState) { newState in
            mascotViewModel.changeState(to: newState)
        }
        .onChange(of: viewModel.isLoading) { isLoading in
            mascotViewModel.changeState(to: isLoading ? .thinking : .idle)
        }
        .onAppear {
            viewModel.triggerWelcomeMessage()
            mascotViewModel.changeState(to: viewModel.mascotState)
        }
    }
    
    // MARK: - Privacy Window Style Components
    
    private var liquidGlassBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(LiquidGlassStyle.backgroundGlass)
            .ignoresSafeArea()
    }
    
    private var inputSection: some View {
        VStack(spacing: 14) {
            // Professional error messages
            if let speechError = viewModel.speechErrorMessage {
                professionalErrorMessageView(message: speechError, icon: "exclamationmark.triangle.fill", color: .red)
            }
            
            if let captureError = viewModel.captureErrorMessage {
                professionalErrorMessageView(message: captureError, icon: "camera.badge.exclamationmark", color: .orange)
            }
            
            // Professional input controls
            inputControlsSection
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
    }
    
    private func professionalErrorMessageView(message: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.subheadline)
            Text(message)
                .font(.caption)
                .foregroundColor(color)
        }
        .padding(12)
        .background(professionalErrorBackground(color: color))
        .transition(.scale.combined(with: .opacity))
    }
    
    private func professionalErrorBackground(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(color.opacity(0.4), lineWidth: 0.6)
            )
    }
    
    private var inputControlsSection: some View {
        HStack(alignment: .bottom, spacing: 20) {
            // Professional mascot section
            professionalMascotSection
            
            // Professional input controls
            professionalInputSection
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }
    

    
    private var professionalMascotSection: some View {
        ZStack(alignment: .topTrailing) {
            // Larger, more prominent mascot
            VStack {
                MascotView(viewModel: mascotViewModel, mascotSize: 110)
            }
            .frame(width: 130, height: 130)
            
            // Professional speech bubbles
            if viewModel.showWelcomeBubble, let message = viewModel.currentWelcomeMessage {
                professionalBubbleView(message: message, isAccent: true)
                    .offset(x: 20, y: -70)
                    .zIndex(1)
            } else if viewModel.showIdlePromptBubble, let message = viewModel.currentIdlePromptMessage {
                professionalBubbleView(message: message, isAccent: false)
                    .offset(x: 20, y: -70)
                    .zIndex(1)
            }
        }
    }
    

    
    private func professionalBubbleView(message: String, isAccent: Bool) -> some View {
        Text(message)
            .font(.caption)
            .foregroundColor(.primary)
            .multilineTextAlignment(.center)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(isAccent ? 0.25 : 0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8)
                    )
            )
            .frame(maxWidth: 160)
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .opacity
            ))
    }
    
    private var professionalInputSection: some View {
        VStack(alignment: .trailing, spacing: 14) {
            // Professional control buttons on top
            professionalControlButtonsRow
            
            // Longer, more professional text input
            TextField("Ask your AI assistant anything...", text: $viewModel.currentInput)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(professionalTextFieldBackground)
                .disabled(viewModel.isListening)
                .focused($isInputFocused)
        }
        .layoutPriority(1)
    }
    
    private var professionalTextFieldBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.8)
            )
    }
    
    private var mascotSection: some View {
        ZStack(alignment: .topTrailing) {
            // Mascot with Privacy window glass styling
            VStack {
                MascotView(viewModel: mascotViewModel, mascotSize: 120)
            }
            .frame(width: 140, height: 140)
            .background(mascotBackground)
            
            // Welcome/Idle Bubbles with Privacy window styling
            if viewModel.showWelcomeBubble, let message = viewModel.currentWelcomeMessage {
                bubbleView(message: message, isAccent: true)
                    .offset(x: 20, y: -80)
                    .zIndex(1)
            } else if viewModel.showIdlePromptBubble, let message = viewModel.currentIdlePromptMessage {
                bubbleView(message: message, isAccent: false)
                    .offset(x: 20, y: -80)
                    .zIndex(1)
            }
        }
    }
    
    private var mascotBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(LiquidGlassStyle.accentGlass)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(LiquidGlassStyle.primaryBorder, lineWidth: 1.5)
            )
    }
    
    private func bubbleView(message: String, isAccent: Bool) -> some View {
        Text(message)
            .font(.caption)
            .foregroundColor(.primary)
            .multilineTextAlignment(.center)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isAccent ? LiquidGlassStyle.accentGlass : LiquidGlassStyle.secondaryGlass)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(LiquidGlassStyle.primaryBorder, lineWidth: 1)
                    )
            )
            .frame(maxWidth: 160)
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .opacity
            ))
    }
    
    private var inputFieldSection: some View {
        VStack(alignment: .trailing, spacing: 16) {
            // Text input with Privacy window styling
            TextField("Ask AI...", text: $viewModel.currentInput)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .padding(16)
                .background(textFieldBackground)
                .disabled(viewModel.isListening)
                .focused($isInputFocused)
            
            // Professional control buttons
            professionalControlButtonsRow
        }
        .layoutPriority(1)
    }
    
    private var textFieldBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(LiquidGlassStyle.secondaryGlass)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(LiquidGlassStyle.primaryBorder, lineWidth: 1)
            )
    }
    
    private var professionalControlButtonsRow: some View {
        HStack(spacing: 10) {
            // Microphone Button
            professionalControlButton(
                icon: viewModel.isListening ? "mic.fill" : "mic.slash.fill",
                color: viewModel.isListening ? .red : .primary,
                isActive: viewModel.isListening,
                action: { viewModel.toggleListening() },
                help: viewModel.isListening ? "Stop Listening" : "Start Listening"
            )
            
            // Screen Capture Button
            professionalControlButton(
                icon: viewModel.capturedImage == nil ? "camera" : "camera.fill",
                color: .primary,
                isActive: viewModel.capturedImage != nil,
                action: { viewModel.captureScreenRegion() },
                help: "Capture Screen Region"
            )
            
            // Send Button
            professionalControlButton(
                icon: "paperplane.fill",
                color: canSendMessage ? .white : .gray,
                isActive: canSendMessage,
                action: { viewModel.sendMessageToAI() },
                help: "Send Message"
            )
            .disabled(!canSendMessage || viewModel.isListening)
            .keyboardShortcut(.return, modifiers: [])
            
            // Speaker Toggle Button
            professionalControlButton(
                icon: viewModel.isTTSEnabledGlobally ? "speaker.wave.2.fill" : "speaker.slash.fill",
                color: viewModel.isTTSEnabledGlobally ? .white : .gray,
                isActive: viewModel.isTTSEnabledGlobally,
                action: { viewModel.toggleGlobalTTS() },
                help: viewModel.isTTSEnabledGlobally ? "Disable Text-to-Speech" : "Enable Text-to-Speech"
            )
            
            // Stop Speaking Button (when active)
            if viewModel.isSpeaking {
                professionalControlButton(
                    icon: "stop.circle.fill",
                    color: .red,
                    isActive: true,
                    action: { viewModel.textToSpeechService.stopSpeaking() },
                    help: "Stop Speaking"
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
    }
    
    private var canSendMessage: Bool {
        !viewModel.isLoading && !viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func professionalControlButton(icon: String, color: Color, isActive: Bool, action: @escaping () -> Void, help: String) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(color)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 32, height: 32)
        .background(professionalControlButtonBackground(isActive: isActive))
        .help(help)
    }
    
    private func professionalControlButtonBackground(isActive: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.white.opacity(isActive ? 0.25 : 0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.6)
            )
    }
}

// MARK: - Clean Chat Message View
struct ChatMessageView: View {
    let message: ChatMessage
    let webViewModel: WebViewModel?
    @State private var webViewHeight: CGFloat = 30
    
    // Simple check for common LaTeX delimiters
    private var containsLaTeX: Bool {
        message.text.contains("$$") || message.text.contains("$")
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.isUser {
                Spacer(minLength: 60)
                userMessageView
            } else {
                assistantMessageView
                Spacer(minLength: 60)
            }
        }
    }
    
    private var userMessageView: some View {
        Text(message.text)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(userMessageBackground)
            .contextMenu {
                Button("Copy") { 
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(message.text, forType: .string)
                }
            }
    }
    
    private var userMessageBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.blue.opacity(0.85))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
            )
    }
    
    private var assistantMessageView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let priceData = message.priceComparisonData {
                InlinePriceComparisonView(priceData: priceData, webViewModel: webViewModel)
                    .padding(12)
                    .background(assistantMessageBackground)
            } else if containsLaTeX {
                MathJaxWebView(latexString: message.text, dynamicHeight: $webViewHeight)
                    .frame(height: webViewHeight)
                    .padding(12)
                    .background(assistantMessageBackground)
                    .contextMenu {
                        Button("Copy Raw Text") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.text, forType: .string)
                        }
                    }
            } else if !message.text.isEmpty {
                Text(message.text)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(assistantMessageBackground)
                    .contextMenu {
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.text, forType: .string)
                        }
                    }
            }
        }
    }
    
    private var assistantMessageBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
            )
    }
}

// MARK: - Welcome Bubble View - REMOVE THIS DUPLICATE
// struct WelcomeBubbleView: View { // This is defined in its own file: WelcomeBubbleView.swift
//     let message: String
//     
//     var body: some View {
//         Text(message)
//             .padding(10)
//             .background(Material.regularMaterial)
//             .cornerRadius(10)
//     }
// } 