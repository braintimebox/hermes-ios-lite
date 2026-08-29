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
