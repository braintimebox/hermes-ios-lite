import SwiftUI

enum HermesTheme {
    static let background = LinearGradient(
        colors: [Color(red: 0.035, green: 0.045, blue: 0.070), Color(red: 0.075, green: 0.085, blue: 0.125)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let card = Color.white.opacity(0.075)
    static let cardStrong = Color.white.opacity(0.12)
    static let stroke = Color.white.opacity(0.12)
    static let assistantBubble = Color.white.opacity(0.09)
    static let userBubble = LinearGradient(
        colors: [Color.cyan.opacity(0.78), Color.blue.opacity(0.64)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct GlassCard: ViewModifier {
    var radius: CGFloat = 18
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial.opacity(0.72), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(HermesTheme.stroke, lineWidth: 1))
    }
}

extension View {
    func hermesCard(radius: CGFloat = 18) -> some View { modifier(GlassCard(radius: radius)) }
}
