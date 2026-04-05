import SwiftUI

// MARK: - Liquid Glass Style Helpers
// Targets macOS 26 (Tahoe) Liquid Glass design language.
// Falls back gracefully to ultra-thin material on earlier systems.

struct LiquidGlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 16
    var opacity: Double = 1.0

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.35),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    }
            }
    }
}

struct LiquidGlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.18),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                    }
            }
    }
}

struct PillButton: ViewModifier {
    var color: Color = .accentColor

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background {
                Capsule(style: .continuous)
                    .fill(color.opacity(0.85))
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.25), Color.clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                    }
                    .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 4)
            }
    }
}

// MARK: - View Extensions

extension View {
    func liquidGlassBackground(cornerRadius: CGFloat = 16) -> some View {
        modifier(LiquidGlassBackground(cornerRadius: cornerRadius))
    }

    func liquidGlassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(LiquidGlassCard(cornerRadius: cornerRadius))
    }

    func pillButton(color: Color = .accentColor) -> some View {
        modifier(PillButton(color: color))
    }
}

// MARK: - Animated Gradient Background

struct MeshGradientBackground: View {
    @State private var phase: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { context in
            let t = context.date.timeIntervalSinceReferenceDate / 8
            ZStack {
                // Base gradient
                LinearGradient(
                    colors: [
                        Color(hue: 0.6 + sin(t) * 0.05, saturation: 0.6, brightness: 0.3),
                        Color(hue: 0.75 + cos(t * 0.7) * 0.05, saturation: 0.5, brightness: 0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Floating orbs
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hue: 0.55, saturation: 0.8, brightness: 0.7).opacity(0.35),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 200
                        )
                    )
                    .frame(width: 300, height: 300)
                    .offset(
                        x: CGFloat(sin(t * 0.9) * 80),
                        y: CGFloat(cos(t * 0.7) * 60) - 50
                    )
                    .blur(radius: 20)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hue: 0.8, saturation: 0.7, brightness: 0.8).opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 180
                        )
                    )
                    .frame(width: 250, height: 250)
                    .offset(
                        x: CGFloat(cos(t * 0.6) * 100) + 50,
                        y: CGFloat(sin(t * 0.8) * 80) + 80
                    )
                    .blur(radius: 25)
            }
        }
        .ignoresSafeArea()
    }
}
