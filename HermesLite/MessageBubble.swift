import SwiftUI
import UIKit

// MARK: - MessageBubble (Hermex-like)
struct MessageBubble: View {
    @EnvironmentObject private var store: AppStore
    let message: ChatMessage
    @State private var reasoningExpanded = false

    var body: some View {
        HStack(alignment: .bottom) {
            if message.isUser { Spacer(minLength: 44) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 5) {
                // Reasoning fold (assistant only)
                if let reasoning = message.reasoning, !reasoning.isEmpty {
                    ReasoningFold(text: reasoning, expanded: $reasoningExpanded)
                }

                BubbleText(message: message)

                metaRow
            }

            if !message.isUser { Spacer(minLength: 44) }
        }
        .padding(.horizontal, 8)
    }

    private var metaRow: some View {
        HStack(spacing: 5) {
            if store.isPinned(message) { Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(.yellow) }
            Text(message.isUser ? "You" : "Hermes")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}

struct BubbleText: View {
    let message: ChatMessage

    var body: some View {
        Group {
            if MarkdownLite.shouldRenderMarkdown(for: message) {
                Text(MarkdownLite.cachedAttributed(for: message.content))
                    .textSelection(.enabled)
            } else {
                Text(message.content)
                    .textSelection(.enabled)
            }
        }
        .font(.body)
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background { bubbleBackground }
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Color.white.opacity(message.isUser ? 0.08 : 0.10), lineWidth: 1))
        .contentShape(Rectangle())
        .contextMenu { BubbleMenu(message: message) }
    }

    private var bubbleBackground: some View {
        Group {
            if message.isUser {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(HermesTheme.userBubble)
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(HermesTheme.assistantBubble)
            }
        }
    }
}

struct BubbleMenu: View {
    @EnvironmentObject private var store: AppStore
    let message: ChatMessage

    var body: some View {
        Button(store.isPinned(message) ? "Unpin" : "Pin", systemImage: "pin") { store.togglePin(message) }
        Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = message.content }
    }
}

// MARK: - Reasoning fold
struct ReasoningFold: View {
    let text: String
    @Binding var expanded: Bool

    var body: some View {
        Button { withAnimation(.easeOut(duration: 0.15)) { expanded.toggle() } } label: {
            HStack(spacing: 5) {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                Text(expanded ? "Thinking (collapsed)" : "Thinking")
                    .font(.caption2.weight(.medium))
                Spacer()
            }
            .foregroundStyle(.white.opacity(0.5))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.04), in: Capsule())
        }
        .buttonStyle(.plain)

        if expanded {
            Text(text)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
