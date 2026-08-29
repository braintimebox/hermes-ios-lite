import Foundation

/// Lightweight SSE reader built on `URLSession.bytes(for:)` (iOS 16+, async).
/// No external dependency — plain lines, `event:`/`data:` frames.
///
/// While the agent is streaming, THIS is the hot path. The design keeps it O(1)
/// per token on the UI side: the caller only appends to a single `String`
/// (`streamingText += delta`), never re-parses markdown, never touches the
/// whole message array.
struct SSEClient {
    enum Frame {
        case event(name: String, data: String)
    }

    static func stream(url: URL, cookie: String?) -> AsyncThrowingStream<Frame, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 600
                    if let cookie { request.setValue(cookie, forHTTPHeaderField: "Cookie") }
                    let (bytes, _) = try await URLSession.shared.bytes(for: request)

                    var eventName = ""
                    var dataLines: [String] = []

                    func emitIfReady() {
                        if !eventName.isEmpty {
                            let body = dataLines.joined(separator: "\n")
                            continuation.yield(.event(name: eventName, data: body))
                        }
                        eventName = ""
                        dataLines = []
                    }

                    for try await line in bytes.lines {
                        if line.isEmpty {
                            emitIfReady()
                        } else if line.hasPrefix(":") {
                            // heartbeat / comment — ignore
                            continue
                        } else if line.hasPrefix("event:") {
                            eventName = String(line.dropFirst("event:".count)).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            dataLines.append(String(line.dropFirst("data:".count)).trimmingCharacters(in: .whitespaces))
                        } else if line.hasPrefix("id:") {
                            // Last-Event-ID seen by client; not needed for our simple consumer
                            continue
                        }
                    }
                    emitIfReady()
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
