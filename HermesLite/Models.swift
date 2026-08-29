import Foundation

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: String
    let role: String
    var content: String
    var timestamp: Date

    var isUser: Bool { role == "user" }
}

struct PinItem: Identifiable, Codable, Equatable {
    let id: String
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

struct SessionInfo: Codable, Equatable {
    var sessionId: String
    var title: String
}
