import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var client = APIClient()

    // Multi-session (Law: stable, owned)
    @Published var sessions: [SessionInfo] = []
    @Published var session: SessionInfo? { didSet { persistSession() } }
    @Published var messages: [ChatMessage] = []

    @Published var pins: [PinItem] = [] { didSet { persistPins() } }
    @Published var scheduled: [ScheduledItem] = []

    // Reading-first composer (Hermex)
    @Published var composerVisible: Bool = false
    @Published var draft = ""
    @Published var isSending = false
    @Published var isRefreshing = false
    @Published var error: String?

    // Live streaming state (Hermex): single growing String per stream — O(1) append,
    // no whole-array invalidation, no per-token markdown re-parse (Law 3 + Law 7).
    @Published var streamingText: String = ""
    @Published var streamingReasoning: String = ""
    @Published var isStreaming: Bool = false
    @Published var streamID: String? = nil

    var activePins: [PinItem] {
        guard let session else { return pins }
        return pins.filter { $0.sessionId == session.sessionId }
    }

    init() { loadSession(); loadPins() }

    func bootstrap() async {
        await loadSessions()
        if session == nil { session = sessions.first }
        await refreshMessages()
        await loadScheduled()
    }

    func loadSessions() async {
        do { sessions = try await client.listSessions() }
        catch { self.error = error.localizedDescription }
    }

    func select(_ s: SessionInfo) async {
        session = s
        messages = []
        composerVisible = false
        await refreshMessages()
    }

    func newSession() async {
        do {
            let created = try await client.createSession()
            session = created
            messages = []
            composerVisible = false
            if !sessions.contains(where: { $0.sessionId == created.sessionId }) { sessions.insert(created, at: 0) }
        } catch { self.error = error.localizedDescription }
    }

    func ensureSession() async throws -> SessionInfo {
        if let session { return session }
        let s = try await client.createSession()
        session = s
        if !sessions.contains(where: { $0.sessionId == s.sessionId }) { sessions.insert(s, at: 0) }
        return s
    }

    func sendNow() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        isSending = true
        error = nil
        do {
            let s = try await ensureSession()
            messages.append(ChatMessage(id: "local-\(UUID().uuidString)", role: "user",
                                        content: text, timestamp: Date(), reasoning: nil, isStreaming: false))
            try await client.startChat(sessionId: s.sessionId, text: text)
            await refreshMessages(repeatCount: 8)
            await loadSessions()
        } catch {
            self.error = error.localizedDescription
            draft = text
        }
        isSending = false
    }

    /// Streaming send: live token output via SSE (fast path, Hermex-style).
    func sendStreaming() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        isSending = true
        error = nil
        streamingText = ""
        streamingReasoning = ""
        isStreaming = true
        do {
            let s = try await ensureSession()
            messages.append(ChatMessage(id: "local-\(UUID().uuidString)", role: "user",
                                        content: text, timestamp: Date(), reasoning: nil, isStreaming: false))
            let streamID = try await client.startChatStreaming(sessionId: s.sessionId, text: text)
            self.streamID = streamID
            let url = try client.streamURL(streamId: streamID)
            let cookie = client.currentCookie
            for try await frame in SSEClient.stream(url: url, cookie: cookie) {
                switch frame {
                case .event(let name, let data):
                    handleStreamEvent(name: name, data: data)
                }
            }
            // Stream finished normally — settle what we have into a real message.
            settleStreamingMessage()
        } catch {
            self.error = error.localizedDescription
            draft = text
        }
        isStreaming = false
        isSending = false
        streamID = nil
        await loadSessions()
    }

    private func handleStreamEvent(name: String, data: String) {
        switch name {
        case "token":
            if let text = parseText(data) { streamingText += text }
        case "reasoning":
            if let text = parseText(data) { streamingReasoning += text }
        case "message":
            if let text = parseText(data) { streamingText += text }
        case "title":
            if let title = parseTitle(data), let session {
                self.session = SessionInfo(sessionId: session.sessionId, title: title, updatedAt: session.updatedAt)
            }
        case "error", "apperror":
            if let msg = parseText(data) { self.error = msg }
        default:
            break
        }
        // `done`/`stream_end`/`cancel` do NOT flip isStreaming here: the bubble must
        // stay until after the loop exits and settleStreamingMessage() appends the
        // settled row, otherwise it flashes off for a frame (net → visual flicker).
    }

    private func parseText(_ data: String) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: Data(data.utf8)) as? [String: Any] else { return nil }
        return obj["text"] as? String
    }

    private func parseTitle(_ data: String) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: Data(data.utf8)) as? [String: Any] else { return nil }
        return (obj["title"] as? String) ?? (obj["title_new"] as? String)
    }

    private func settleStreamingMessage() {
        let content = streamingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !content.isEmpty {
            messages.append(ChatMessage(id: "srv-\(UUID().uuidString)", role: "assistant",
                                        content: content, timestamp: Date(),
                                        reasoning: streamingReasoning.isEmpty ? nil : streamingReasoning,
                                        isStreaming: false))
        } else if !streamingReasoning.isEmpty {
            messages.append(ChatMessage(id: "srv-\(UUID().uuidString)", role: "assistant",
                                        content: "(no text)", timestamp: Date(),
                                        reasoning: streamingReasoning, isStreaming: false))
        }
        streamingText = ""
        streamingReasoning = ""
    }

    func refreshMessages(repeatCount: Int = 1) async {
        guard let session else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        for i in 0..<repeatCount {
            do {
                let fetched = try await client.fetchMessages(sessionId: session.sessionId)
                if !fetched.isEmpty { messages = mergeStable(old: messages, new: fetched) }
            } catch { self.error = error.localizedDescription }
            if i + 1 < repeatCount { try? await Task.sleep(nanoseconds: 1_250_000_000) }
        }
    }

    // Law 5: stable identity — keep existing row object if content unchanged
    private func mergeStable(old: [ChatMessage], new: [ChatMessage]) -> [ChatMessage] {
        let oldById = Dictionary(uniqueKeysWithValues: old.map { ($0.id, $0) })
        return new.map { incoming in
            if let existing = oldById[incoming.id], existing.content == incoming.content { return existing }
            return incoming
        }
    }

    func togglePin(_ message: ChatMessage) {
        guard let session else { return }
        if let idx = pins.firstIndex(where: { $0.sessionId == session.sessionId && $0.messageID == message.id }) {
            pins.remove(at: idx)
        } else {
            pins.insert(PinItem(id: UUID().uuidString, sessionId: session.sessionId,
                                messageID: message.id, text: message.content, timestamp: Date()), at: 0)
        }
    }

    func isPinned(_ message: ChatMessage) -> Bool {
        guard let session else { return false }
        return pins.contains { $0.sessionId == session.sessionId && $0.messageID == message.id }
    }

    func loadScheduled() async {
        do { scheduled = try await client.listScheduled() }
        catch { self.error = error.localizedDescription }
    }

    func scheduleDraft(at date: Date) async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            let s = try await ensureSession()
            try await client.schedule(text: text, sessionId: s.sessionId, title: s.title, at: date)
            draft = ""
            await loadScheduled()
        } catch { self.error = error.localizedDescription }
    }

    func deleteScheduled(_ item: ScheduledItem) async {
        do {
            try await client.deleteScheduled(item)
            scheduled.removeAll { $0.id == item.id }
        } catch { self.error = error.localizedDescription }
    }

    private func loadSession() {
        guard let data = UserDefaults.standard.data(forKey: "session"),
              let d = try? JSONDecoder().decode(SessionInfo.self, from: data) else { return }
        session = d
    }
    private func persistSession() {
        if let session, let d = try? JSONEncoder().encode(session) { UserDefaults.standard.set(d, forKey: "session") }
    }
    private func loadPins() {
        guard let data = UserDefaults.standard.data(forKey: "pins"),
              let d = try? JSONDecoder().decode([PinItem].self, from: data) else { return }
        pins = d
    }
    private func persistPins() {
        if let d = try? JSONEncoder().encode(pins) { UserDefaults.standard.set(d, forKey: "pins") }
    }
}
