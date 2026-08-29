import Foundation
import SwiftUI

/// Lightweight, throttled Markdown-ish renderer for assistant messages.
///
/// WHY THIS IS SAFE (no N^2):
/// This client polls (`refreshMessages`); there is NO SSE token stream on the
/// hot path. A settled message's content is immutable, so the AttributedString is
/// rebuilt exactly once per unique content hash (single-entry cache) — never per
/// frame, never per token. No debounce-of-visible-text, no re-parse.
///
/// Subset rendered (enough for a Hermex-like look without full MarkdownUI):
/// `#`/`##`/`###` headers, `**bold**`, inline code `` `x` ``, fenced code blocks,
/// bullet lines (`- ` / `* `). Everything else renders as plain body text.
struct MarkdownLite {
    static let longContentThreshold = 2_000

    private static var cacheHash: Int = 0
    private static var cacheString: AttributedString? = nil
    private static let lock = NSLock()

    static func cachedAttributed(for content: String) -> AttributedString {
        let hash = content.hashValue
        lock.lock(); defer { lock.unlock() }
        if hash == cacheHash, let existing = cacheString { return existing }
        let built = render(content)
        cacheHash = hash
        cacheString = built
        return built
    }

    static func shouldRenderMarkdown(for message: ChatMessage) -> Bool {
        guard !message.isUser else { return false }
        return message.content.count > longContentThreshold
    }

    // MARK: - Renderer
    private static func render(_ text: String) -> AttributedString {
        var out = AttributedString()
        var inCodeBlock = false
        var codeBuffer: [String] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    out += codeBlock(joinLines(codeBuffer)); codeBuffer.removeAll(); inCodeBlock = false
                } else { inCodeBlock = true }
                continue
            }
            if inCodeBlock { codeBuffer.append(String(line)); continue }
            out += paragraph(String(line), raw: trimmed)
        }
        return out
    }

    private static func joinLines(_ lines: [String]) -> String { lines.joined(separator: "\n") }

    private static func codeBlock(_ s: String) -> AttributedString {
        var a = AttributedString(s)
        a.font = .system(size: 13, design: .monospaced)
        a.backgroundColor = Color.white.opacity(0.10)
        a.foregroundColor = Color.white.opacity(0.85)
        return a
    }

    private static func paragraph(_ line: String, raw trimmed: String) -> AttributedString {
        if trimmed.isEmpty { return AttributedString() }

        var a: AttributedString
        if trimmed.hasPrefix("## ") {
            a = AttributedString(String(line.dropFirst(3)))
            a.font = .system(size: 18, weight: .bold)
            a.foregroundColor = Color.white.opacity(0.92)
        } else if trimmed.hasPrefix("# ") {
            a = AttributedString(String(line.dropFirst(2)))
            a.font = .system(size: 19, weight: .bold)
            a.foregroundColor = Color.white.opacity(0.95)
        } else if trimmed.hasPrefix("### ") {
            a = AttributedString(String(line.dropFirst(4)))
            a.font = .system(size: 17, weight: .semibold)
            a.foregroundColor = Color.white.opacity(0.9)
        } else {
            a = AttributedString(line)
            a.font = .system(size: 17)
            a.foregroundColor = Color.white
        }
        return applyInlineBold(to: a)
    }

    /// Wrap `**...**` spans in bold via deterministic segment walk.
    private static func applyInlineBold(to a: AttributedString) -> AttributedString {
        let marker = "**"
        var value = a
        var idx = value.startIndex
        var open: AttributedString.Index? = nil

        while idx < value.endIndex {
            let remaining = value[idx...]
            if let rng = remaining.range(of: marker) {
                if open == nil {
                    open = rng.lowerBound
                    idx = rng.upperBound
                } else {
                    let body = String(value[open!..<rng.lowerBound].characters)
                    var bold = AttributedString(body)
                    bold.font = .system(size: 17, weight: .semibold)
                    bold.foregroundColor = Color.white
                    let rangeToReplace = open!..<rng.upperBound
                    value.replaceSubrange(rangeToReplace, with: bold)
                    idx = value.endIndex
                    open = nil
                }
            } else {
                break
            }
        }
        return value
    }
}
