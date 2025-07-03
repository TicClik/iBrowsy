import SwiftUI

// MARK: - Liquid Glass Design System

struct LiquidGlassStyle {
    
    // MARK: - Color Palette
    
    /// Primary glass tint - Balanced liquid glass appearance
    static let primaryGlass = LinearGradient(
        colors: [
            Color.white.opacity(0.18),    // Comfortable white base
            Color.blue.opacity(0.04),     // Subtle light blue
            Color.white.opacity(0.15)     // Gentle white highlight
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Secondary glass for cards and surfaces - Balanced sidebar transparency
    static let secondaryGlass = LinearGradient(
        colors: [
            Color.white.opacity(0.15),    // Comfortable white for sidebar
            Color.blue.opacity(0.03),     // Gentle light blue
            Color.white.opacity(0.12)     // Visible highlight
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Accent glass for highlights and active states - Light floating transparency
    static let accentGlass = LinearGradient(
        colors: [
            Color.white.opacity(0.15),    // Brighter white for floating elements
            Color.blue.opacity(0.03),     // Light blue accent (no cyan)
            Color.white.opacity(0.12)     // Clean highlight
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Background glass for main surfaces - Pure liquid glass
    static let backgroundGlass = LinearGradient(
        colors: [
            Color.white.opacity(0.10),    // Clean white base
            Color.blue.opacity(0.02),     // Pure light blue (no cyan)
            Color.white.opacity(0.08)     // Clean highlight
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Opaque background for analysis panels - More readable
    static let analysisGlass = LinearGradient(
        colors: [
            Color.white.opacity(0.92),    // Much more opaque white base
            Color.blue.opacity(0.15),     // Enhanced blue tint
            Color.white.opacity(0.95)     // Very opaque highlight
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Shadow System - Much more subtle for liquid glass
    
    static let softShadow = Shadow(
        color: Color.blue.opacity(0.08),   // Pure light blue shadow
        radius: 8,
        x: 0,
        y: 2
    )
    
    static let floatingShadow = Shadow(
        color: Color.blue.opacity(0.12),   // Clean blue shadow for floating glass
        radius: 12,
        x: 0,
        y: 4
    )
    
    static let innerShadow = Shadow(
        color: Color.white.opacity(0.3),   // Further reduced from 0.6
        radius: 1,
        x: 0,
        y: 1
    )
    
    // MARK: - Border System - Nearly invisible for liquid glass
    
    static let glassBorder = LinearGradient(
        colors: [
            Color.white.opacity(0.15),    // Clean glass border
            Color.blue.opacity(0.03),     // Light blue edge (no cyan)
            Color.white.opacity(0.12)     // Clean outline
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let subtleBorder = LinearGradient(
        colors: [
            Color.white.opacity(0.08),    // Ultra light glass edge
            Color.blue.opacity(0.04),     // Barely visible blue
            Color.white.opacity(0.06)     // Subtle highlight
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Completely transparent border for maximum transparency
    static let transparentBorder = LinearGradient(
        colors: [
            Color.clear,                   // Completely transparent
            Color.clear,                   // Completely transparent
            Color.clear                    // Completely transparent
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Additional Border Styles for Privacy Views
    
    /// Primary border for cards and sections
    static let primaryBorder = LinearGradient(
        colors: [
            Color.white.opacity(0.15),    // Clean glass border
            Color.blue.opacity(0.03),     // Light blue edge (no cyan)
            Color.white.opacity(0.12)     // Clean outline
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Secondary border for cards and sections
    static let secondaryBorder = LinearGradient(
        colors: [
            Color.white.opacity(0.08),    // Ultra light glass edge
            Color.blue.opacity(0.04),     // Barely visible blue
            Color.white.opacity(0.06)     // Subtle highlight
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Light Shadow Colors
    
    /// Light shadow for gorgeous glass depth
    static let lightShadow = Color.blue.opacity(0.10)
}

// MARK: - Glass Material Components

struct GlassCard<Content: View>: View {
    let content: Content
    let style: GlassCardStyle
    
    enum GlassCardStyle {
        case primary, secondary, accent, floating
    }
    
    init(style: GlassCardStyle = .primary, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(
                ZStack {
                    // Base glass background - Ultra thin for liquid glass effect
                    RoundedRectangle(cornerRadius: 20)
                        .fill(backgroundGradient)
                        .background(
                            // Only add material background for accent cards, others use clear for maximum transparency
                            RoundedRectangle(cornerRadius: 20)
                                .fill(style == .accent ? AnyShapeStyle(Color.white.opacity(0.20)) : AnyShapeStyle(Color.clear))
                        )
                    
                    // Subtle border highlight - Invisible for crystal glass
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(borderGradient, lineWidth: 0)
                }
            )
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowOffset)
    }
    
    private var backgroundGradient: LinearGradient {
        switch style {
        case .primary:
            return LiquidGlassStyle.primaryGlass
        case .secondary:
            return LiquidGlassStyle.secondaryGlass
        case .accent:
            return LiquidGlassStyle.accentGlass
        case .floating:
            return LiquidGlassStyle.analysisGlass
        }
    }
    
    private var borderGradient: LinearGradient {
        switch style {
        case .accent:
            return LiquidGlassStyle.glassBorder
        default:
            return LiquidGlassStyle.subtleBorder
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .floating:
            return Color.clear  // Completely invisible for crystal glass
        default:
            return Color.clear  // Completely invisible for crystal glass
        }
    }
    
    private var shadowRadius: CGFloat {
        switch style {
        case .floating:
            return 30
        default:
            return 20
        }
    }
    
    private var shadowOffset: CGFloat {
        switch style {
        case .floating:
            return 15
        default:
            return 8
        }
    }
}

struct GlassButton<Content: View>: View {
    let action: () -> Void
    let content: Content
    let style: ButtonStyle
    
    enum ButtonStyle {
        case primary, secondary, accent, floating
    }
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    init(style: ButtonStyle = .primary, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.style = style
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        Button(action: action) {
            content
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        // Animated glass background - Ultra thin for liquid glass effect
                        RoundedRectangle(cornerRadius: 15)
                            .fill(backgroundGradient)
                            .background(
                                // Remove background material for maximum transparency
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.clear)
                            )
                            .scaleEffect(isPressed ? 0.98 : (isHovered ? 1.02 : 1.0))
                        
                        // Border highlight - Invisible for crystal glass
                        RoundedRectangle(cornerRadius: 15)
                            .strokeBorder(
                                LiquidGlassStyle.glassBorder.opacity(0),
                                lineWidth: 0
                            )
                    }
                )
                .shadow(
                    color: Color.clear,  // Completely invisible for crystal glass
                    radius: 0,
                    x: 0,
                    y: 0
                )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .pressEvents(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }
    
    private var backgroundGradient: LinearGradient {
        switch style {
        case .primary:
            return LiquidGlassStyle.primaryGlass
        case .secondary:
            return LiquidGlassStyle.secondaryGlass
        case .accent:
            return LiquidGlassStyle.accentGlass
        case .floating:
            return LiquidGlassStyle.backgroundGlass
        }
    }
}

struct GlassTextField: View {
    @Binding var text: String
    let placeholder: String
    let style: TextFieldStyle
    
    enum TextFieldStyle {
        case primary, secondary, floating
    }
    
    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    
    init(_ placeholder: String, text: Binding<String>, style: TextFieldStyle = .primary) {
        self.placeholder = placeholder
        self._text = text
        self.style = style
    }
    
    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(PlainTextFieldStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    // Glass background - Clear background for maximum transparency
                    RoundedRectangle(cornerRadius: 12)
                        .fill(backgroundGradient)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.clear)
                        )
                    
                    // Animated border
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            borderGradient.opacity(isFocused ? 1.0 : (isHovered ? 0.8 : 0.5)),
                            lineWidth: isFocused ? 2 : 1
                        )
                }
            )
            .shadow(
                color: Color.clear,  // Completely invisible for crystal glass
                radius: 0,
                x: 0,
                y: 0
            )
            .scaleEffect(isFocused ? 1.02 : (isHovered ? 1.01 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isHovered)
            .focused($isFocused)
            .onHover { hovering in
                isHovered = hovering
            }
    }
    
    private var backgroundGradient: LinearGradient {
        switch style {
        case .primary:
            return LiquidGlassStyle.primaryGlass
        case .secondary:
            return LiquidGlassStyle.secondaryGlass
        case .floating:
            return LiquidGlassStyle.backgroundGlass
        }
    }
    
    private var borderGradient: LinearGradient {
        isFocused ? LiquidGlassStyle.accentGlass : LiquidGlassStyle.subtleBorder
    }
}

struct GlassPanel<Content: View>: View {
    let content: Content
    let style: PanelStyle
    
    enum PanelStyle {
        case sidebar, main, floating, overlay
    }
    
    init(style: PanelStyle = .main, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                ZStack {
                    // Gorgeous liquid glass base - same as Privacy window
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(backgroundMaterial)
                        .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(glassOverlay)
                        )
                    
                    // Border highlight - Vibrant glass edges
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(borderGradient, lineWidth: borderWidth)
                }
            )
            .shadow(
                color: shadowColor, 
                radius: shadowRadius, 
                x: 0, 
                y: shadowOffset
            )
    }
    
    private var cornerRadius: CGFloat {
        switch style {
        case .sidebar:
            return 0
        case .main:
            return 16
        case .floating:
            return 20
        case .overlay:
            return 24
        }
    }
    
    private var backgroundMaterial: LinearGradient {
        switch style {
        case .sidebar:
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.06),    // Ultra light sidebar transparency
                    Color.blue.opacity(0.03),     // Barely visible blue tint
                    Color.white.opacity(0.04)     // Subtle highlight
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .main:
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.08),    // EXACT same as Privacy window
                    Color.blue.opacity(0.04),     // Pure light blue instead of cyan
                    Color.white.opacity(0.06)     // Same subtle white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .floating:
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.12),    // Slightly more visible for floating elements
                    Color.blue.opacity(0.06),     // Pure light blue instead of cyan
                    Color.white.opacity(0.08)     // Gentle highlight
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .overlay:
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.08),    // Same transparency as Privacy window
                    Color.blue.opacity(0.04),     // Pure light blue instead of cyan
                    Color.white.opacity(0.06)     // Subtle white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var glassOverlay: Material {
        switch style {
        case .sidebar:
            return .thin                             // Lighter material for bright glass effect
        case .main:
            return .thin                             // Lighter material for bright glass effect
        case .floating:
            return .thin                             // Lighter material for floating elements
        case .overlay:
            return .thin                             // Lighter material for overlay depth
        }
    }
    
    private var borderGradient: LinearGradient {
        switch style {
        case .overlay:
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.15),    // Ultra light border
                    Color.blue.opacity(0.08),     // Pure light blue instead of cyan
                    Color.white.opacity(0.12)     // Subtle highlight
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sidebar:
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.08),    // Ultra light sidebar border
                    Color.blue.opacity(0.04),     // Barely visible blue
                    Color.white.opacity(0.06)     // Gentle highlight
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .main:
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.12),    // EXACT same light approach as Privacy window
                    Color.blue.opacity(0.06),     // Pure light blue instead of cyan
                    Color.white.opacity(0.09)     // Subtle white edge
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.10),    // Light default border
                    Color.blue.opacity(0.05),     // Pure light blue instead of cyan
                    Color.white.opacity(0.08)     // Gentle highlight
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .overlay:
            return 0.8                    // Ultra subtle overlay borders
        case .sidebar:
            return 0.5                    // Barely visible sidebar borders
        case .main:
            return 0.6                    // Ultra light main panel borders - same as Privacy window
        default:
            return 0.6
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .floating, .overlay:
            return LiquidGlassStyle.lightShadow       // Gorgeous light shadow for floating elements
        case .sidebar:
            return Color.blue.opacity(0.15)           // Pure light blue shadow for sidebar
        case .main:
            return LiquidGlassStyle.lightShadow       // Light shadow for main panels - same as Privacy window
        default:
            return LiquidGlassStyle.lightShadow       // Beautiful light shadows everywhere
        }
    }
    
    private var shadowRadius: CGFloat {
        switch style {
        case .floating:
            return 25
        case .overlay:
            return 35
        default:
            return 15
        }
    }
    
    private var shadowOffset: CGFloat {
        switch style {
        case .floating:
            return 12
        case .overlay:
            return 18
        default:
            return 6
        }
    }
}

// MARK: - Supporting Extensions

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.modifier(PressEventModifier(onPress: onPress, onRelease: onRelease))
    }
}

struct PressEventModifier: ViewModifier {
    let onPress: () -> Void
    let onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                if pressing {
                    onPress()
                } else {
                    onRelease()
                }
            }, perform: {})
    }
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Preview Helpers

#Preview("Glass Components") {
    VStack(spacing: 20) {
        GlassCard(style: .primary) {
            VStack {
                Text("Primary Glass Card")
                    .font(.headline)
                Text("Beautiful liquid glass effect")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        
        GlassTextField("Enter text...", text: .constant(""))
        
        GlassButton(style: .accent, action: {}) {
            Text("Glass Button")
                .foregroundColor(.white)
        }
    }
    .padding()
    .background(
        LinearGradient(
            colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
} 