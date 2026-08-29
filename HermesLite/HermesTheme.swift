import SwiftUI

enum HermesTheme {
    static let background = LinearGradient(
        colors: [Color(red: 0.030, green: 0.040, blue: 0.065),
                 Color(red: 0.070, green: 0.082, blue: 0.120)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let assistantBubble = Color.white.opacity(0.075)
    static let userBubble = LinearGradient(
        colors: [Color.cyan.opacity(0.72), Color.blue.opacity(0.60)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct Gal: ViewModifier {
    var radius: CGFloat = 20
    var interactive = false
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial.opacity(interactive ? 0.9 : 0.72),
                        in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1))
    }
}

// chatTactile-style: pressed scale + soft shadow
struct Tactile: ViewModifier {
    var size: CGFloat
    func body(content: Content) -> some View {
        content
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }
}

extension View {
    func gal(radius: CGFloat = 20, interactive: Bool = false) -> some View { modifier(Gal(radius: radius, interactive: interactive)) }
    func tactile(_ size: CGFloat) -> some View { modifier(Tactile(size: size)) }
}
