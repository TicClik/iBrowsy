import SwiftUI

struct WelcomeBubbleView: View {
    let message: String
    private let bubbleBackgroundColor: Color = .white
    private let bubbleStrokeColor: Color = .black
    private let textColor: Color = .black
    private let lineWidth: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(message)
                .font(.caption)
                .padding(10)
                .foregroundColor(textColor)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(bubbleBackgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(bubbleStrokeColor, lineWidth: lineWidth)
                        )
                )
            
            // Bubble Tail
            Path { path in
                path.move(to: CGPoint(x: 20, y: -lineWidth)) // Adjust y to connect smoothly with stroke
                path.addLine(to: CGPoint(x: 30, y: -lineWidth))
                path.addLine(to: CGPoint(x: 25, y: 10))
                path.closeSubpath()
            }
            .fill(bubbleBackgroundColor)
            .overlay(
                Path { path in
                    path.move(to: CGPoint(x: 20, y: -lineWidth))
                    path.addLine(to: CGPoint(x: 30, y: -lineWidth))
                    path.addLine(to: CGPoint(x: 25, y: 10))
                    path.closeSubpath()
                }
                .stroke(bubbleStrokeColor, lineWidth: lineWidth)
            )
            .frame(width: 10 + (lineWidth * 2), height: 10 + lineWidth) // Adjust frame for stroke
            .offset(x: 20, y: -lineWidth) // Adjust y to account for stroke and better connection
        }
        .shadow(color: Color.black.opacity(0.15), radius: 2, x: 1, y: 1) // Soften shadow for white bubble
    }
}

struct WelcomeBubbleView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeBubbleView(message: "Hello there! I am a friendly mascot with a very important message to share with you today.")
            .padding(50)
            .background(Color.blue.opacity(0.3))
        
        WelcomeBubbleView(message: "Short.")
            .padding(50)
            .background(Color.green.opacity(0.3))
    }
} 