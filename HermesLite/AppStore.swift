import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var client = APIClient()
    @Published var session: SessionInfo? {
        didSet { persistSession() }
    }
    @Published var messages: [ChatMessage] = []
    @Published var pins: [PinItem] = [] {
        didSet { persistPins() }
    }
    @Published var scheduled: [ScheduledItem] = []
    @Published var draft = ""
    @Published var isSending = false
    @Published var isRefreshing = false
    @Published var error: String?

    init() {
        loadSession()
        loadPins()
    }

    func ensureSession() async throws -> SessionInfo {
        if let session { return session }
        let created = try await client.createSession()
        session = created
        return created
    }

    func sendNow() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        isSending = true
        error = nil
        do {
            let s = try await ensureSession()
            messages.append(ChatMessage(id: UUID().uuidString, role: "user", content: text, timestamp: Date()))
            try await client.startChat(sessionId: s.sessionId, text: text)
            await refreshMessages(repeatCount: 6)
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
                if !fetched.isEmpty { messages = fetched }
            } catch {
                self.error = error.localizedDescription
            }
            if i + 1 < repeatCount { try? await Task.sleep(nanoseconds: 1_500_000_000) }
        }
    }

    func togglePin(_ message: ChatMessage) {
        if let idx = pins.firstIndex(where: { $0.messageID == message.id }) {
            pins.remove(at: idx)
        } else {
            pins.insert(PinItem(id: UUID().uuidString, messageID: message.id, text: message.content, timestamp: Date()), at: 0)
        }
    }

    func isPinned(_ message: ChatMessage) -> Bool {
        pins.contains { $0.messageID == message.id }
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
              let decoded = try? JSONDecoder().decode(SessionInfo.self, from: data) else { return }
        session = decoded
    }

    private func persistSession() {
        if let session, let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: "session")
        }
    }

    private func loadPins() {
        guard let data = UserDefaults.standard.data(forKey: "pins"),
              let decoded = try? JSONDecoder().decode([PinItem].self, from: data) else { return }
        pins = decoded
    }

    private func persistPins() {
        if let data = try? JSONEncoder().encode(pins) {
            UserDefaults.standard.set(data, forKey: "pins")
        }
    }
}
