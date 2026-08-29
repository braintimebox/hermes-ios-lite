import Foundation

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: String
    let role: String
    var content: String
    var timestamp: Date
    var reasoning: String?
    var isStreaming: Bool

    var isUser: Bool { role == "user" }
}

struct ToolCard: Identifiable, Equatable {
    let id: String
    let name: String
    var preview: String?
    var duration: Double?
    var isError: Bool
}

struct PinItem: Identifiable, Codable, Equatable {
    let id: String
    let sessionId: String
    let messageID: String
    let text: String
    let timestamp: Date
}

struct ScheduledItem: Identifiable, Codable, Equatable {
    var id: String { scheduleKey }
    let scheduleKey: String
    var sessionId: String
    var sessionTitle: String?
    var text: String
    var scheduledAt: Date
}

struct SessionInfo: Identifiable, Codable, Equatable {
    var id: String { sessionId }
    var sessionId: String
    var title: String
    var updatedAt: Date?
}
