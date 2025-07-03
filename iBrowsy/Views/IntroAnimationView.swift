import SwiftUI

struct IntroAnimationView: View {
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.8
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var subtitleOpacity: Double = 0
    @State private var subtitleOffset: CGFloat = 20
    @State private var backgroundOpacity: Double = 0
    
    let onComplete: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Clean gradient background
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.1),
                        Color.purple.opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    // Simple logo/icon
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(logoOpacity)
                        .scaleEffect(logoScale)
                    
                    // App title
                    Text("iBrowsy")
                        .font(.system(size: 48, weight: .light, design: .rounded))
                        .foregroundColor(.primary)
                        .opacity(titleOpacity)
                        .offset(y: titleOffset)
                    
                    // Subtitle
                    Text("Intelligent Browsing")
                        .font(.system(size: 18, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .opacity(subtitleOpacity)
                        .offset(y: subtitleOffset)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            startElegantSequence()
        }
    }
    
    private func startElegantSequence() {
        // Background fade in
        withAnimation(.easeOut(duration: 0.8)) {
            backgroundOpacity = 1.0
        }
        
        // Logo animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                logoOpacity = 1.0
                logoScale = 1.0
            }
        }
        
        // Title animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.6)) {
                titleOpacity = 1.0
                titleOffset = 0
            }
        }
        
        // Subtitle animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.6)) {
                subtitleOpacity = 1.0
                subtitleOffset = 0
            }
        }
        
        // Complete the intro
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            onComplete()
        }
    }
}

#Preview {
    IntroAnimationView {
        print("Epic intro animation completed")
    }
}