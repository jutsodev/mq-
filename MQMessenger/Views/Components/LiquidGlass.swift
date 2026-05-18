import SwiftUI

struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    var opacity: Double
    var blur: CGFloat
    var intensity: Double

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .opacity(0.85)

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.35 * intensity),
                                    Color.white.opacity(0.12 * intensity),
                                    Color.white.opacity(0.03 * intensity),
                                    Color.clear,
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.12 * intensity),
                                    Color.clear,
                                ],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.7 * intensity),
                                    Color.white.opacity(0.2 * intensity),
                                    Color.white.opacity(0.05 * intensity),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .inset(by: 0.5)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4 * intensity),
                                    Color.clear,
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                }
            )
            .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 6)
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

struct LiquidGlassCard: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .modifier(LiquidGlassModifier(cornerRadius: 20, opacity: 0.1, blur: 20, intensity: 1.0))
    }
}

struct LiquidGlassButtonStyle: ButtonStyle {
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            isDestructive
                                ? Color.red.opacity(configuration.isPressed ? 0.3 : 0.15)
                                : Color.blue.opacity(configuration.isPressed ? 0.3 : 0.15)
                        )

                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.05),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0.1),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct LiquidGlassNavBar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .ignoresSafeArea()
                }
            )
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

struct LiquidGlassTabBar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .ignoresSafeArea()

                    VStack {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color.clear,
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 0.5)
                        Spacer()
                    }
                    .ignoresSafeArea()
                }
            )
    }
}

struct LiquidGlassTextField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))

                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.1),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
            )
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}

struct LiquidGlassToggle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                }
            )
    }
}

struct GlassShimmer: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.white.opacity(0),
                Color.white.opacity(0.2),
                Color.white.opacity(0),
            ]),
            startPoint: .init(x: phase - 0.5, y: 0),
            endPoint: .init(x: phase + 0.5, y: 1)
        )
        .onAppear {
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                phase = 1.5
            }
        }
    }
}

struct LiquidGlassInputBar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.92)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.03),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    VStack {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.2),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 0.33)
                        Spacer()
                    }
                }
            )
    }
}

struct LiquidGlassInputField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .opacity(0.9)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.15),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
            )
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}

struct AttachMenuItemStyle: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(.system(size: 22))
            .foregroundColor(.white)
            .frame(width: 52, height: 52)
            .background(
                ZStack {
                    Circle().fill(color.gradient)
                    Circle().fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.25), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
            )
            .shadow(color: color.opacity(0.3), radius: 6, y: 3)
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat = 20, opacity: Double = 0.1, blur: CGFloat = 20, intensity: Double = 1.0) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius, opacity: opacity, blur: blur, intensity: intensity))
    }

    func glassCard(padding: CGFloat = 16) -> some View {
        modifier(LiquidGlassCard(padding: padding))
    }

    func glassNavBar() -> some View {
        modifier(LiquidGlassNavBar())
    }

    func glassTabBar() -> some View {
        modifier(LiquidGlassTabBar())
    }

    func glassTextField() -> some View {
        modifier(LiquidGlassTextField())
    }

    func glassToggle() -> some View {
        modifier(LiquidGlassToggle())
    }

    func glassInputBar() -> some View {
        modifier(LiquidGlassInputBar())
    }

    func glassInputField() -> some View {
        modifier(LiquidGlassInputField())
    }

    func attachMenuItem(color: Color) -> some View {
        modifier(AttachMenuItemStyle(color: color))
    }
}
