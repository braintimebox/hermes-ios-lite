import SwiftUI

// MARK: - ChatSurface (transcript + scroll-to-bottom + FAB cluster)
struct ChatSurface: View {
    @EnvironmentObject private var store: AppStore
    @State private var scrolledUp = false
    @State private var showComposer = false

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if store.messages.isEmpty { EmptySurface() }
                        else {
                            ForEach(store.messages) { m in
                                MessageBubble(message: m)
                                    .id(m.id)
                            }
                        }
                        if store.isStreaming {
                            StreamingBubble(text: store.streamingText, reasoning: store.streamingReasoning)
                                .id("streaming")
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: ScrollOffsetKey.self,
                            value: geo.frame(in: .named("chat")).minY)
                    })
                }
                .coordinateSpace(name: "chat")
                .scrollDismissesKeyboard(.interactively)
                .background(Color.black.opacity(0.10), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 1))
                .onPreferenceChange(ScrollOffsetKey.self) { offset in
                    // Content minY in scroll space: bottom = large negative,
                    // reading-up-from-bottom = near/above 0. Show ↓ when NOT pinned to bottom.
                    scrolledUp = offset > -250
                }
                .onChange(of: store.messages.count) { _, _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                    scrolledUp = false
                }
                .onChange(of: store.streamingText) { _, _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }

                HStack(spacing: 10) {
                    if scrolledUp {
                        CircleButton("arrow.down", 44) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                            scrolledUp = false
                        }
                    }
                    CircleButton(showComposer ? "keyboard.chevron.compact.down" : "plus", 48) {
                        withAnimation(.easeOut(duration: 0.2)) { showComposer.toggle() }
                        store.composerVisible = showComposer
                    }
                }
                .padding(.trailing, 14)
                .padding(.bottom, 10)
            }
        }
    }
}

struct CircleButton: View {
    let systemName: String
    let size: CGFloat
    let action: () -> Void

    init(_ systemName: String, _ size: CGFloat, action: @escaping () -> Void) {
        self.systemName = systemName
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: size, height: size)
                .background(Color.cyan.opacity(0.75), in: Circle())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}

// MARK: - StreamingBubble (live growing assistant bubble, separate from messages array)
struct StreamingBubble: View {
    let text: String
    let reasoning: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                if !reasoning.isEmpty {
                    Text(reasoning)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(3)
                }
                HStack(alignment: .bottom, spacing: 6) {
                    Text(text.isEmpty ? "…" : text)
                        .font(.body)
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                    TypingDots()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(HermesTheme.assistantBubble, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))

            Spacer(minLength: 44)
        }
        .padding(.horizontal, 8)
    }
}

struct TypingDots: View {
    var body: some View {
        HStack(spacing: 3) {
            Circle().fill(Color.white.opacity(0.7)).frame(width: 5, height: 5)
            Circle().fill(Color.white.opacity(0.7)).frame(width: 5, height: 5)
            Circle().fill(Color.white.opacity(0.7)).frame(width: 5, height: 5)
        }
    }
}

// MARK: - Scroll offset preference
struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Empty state
struct EmptySurface: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 42))
                .foregroundStyle(.cyan)
            Text("Hermes")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("Fast chat, Hermex-style. Tap + to write.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 80)
        .padding(.horizontal, 28)
    }
}
