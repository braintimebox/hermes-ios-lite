import Foundation

@MainActor
final class APIClient: ObservableObject {
    @Published var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: "baseURL") }
    }
    @Published var password: String {
        didSet { UserDefaults.standard.set(password, forKey: "password") }
    }
    @Published var lastError: String?

    private var cookie: String? {
        get { UserDefaults.standard.string(forKey: "cookie") }
        set { UserDefaults.standard.set(newValue, forKey: "cookie") }
    }

    init() {
        self.baseURL = UserDefaults.standard.string(forKey: "baseURL") ?? "https://hermes00.duckdns.org:1118"
        self.password = UserDefaults.standard.string(forKey: "password") ?? ""
    }

    private func url(_ path: String) throws -> URL {
        guard var components = URLComponents(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw APIError.invalidURL
        }
        let pieces = path.split(separator: "?", maxSplits: 1).map(String.init)
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let requestPath = pieces[0].trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + ([basePath, requestPath].filter { !$0.isEmpty }.joined(separator: "/"))
        if pieces.count > 1 { components.percentEncodedQuery = pieces[1] }
        guard let built = components.url else { throw APIError.invalidURL }
        return built
    }

    private func request(_ path: String, method: String = "GET", body: [String: Any]? = nil) throws -> URLRequest {
        var req = URLRequest(url: try url(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let cookie { req.setValue(cookie, forHTTPHeaderField: "Cookie") }
        if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body) }
        return req
    }

    func loginIfNeeded() async throws {
        if cookie != nil { return }
        guard !password.isEmpty else { return }
        var req = try request("/api/auth/login", method: "POST", body: ["password": password])
        req.setValue(nil, forHTTPHeaderField: "Cookie")
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.http((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        if let setCookie = http.value(forHTTPHeaderField: "Set-Cookie")?.split(separator: ";").first {
            cookie = String(setCookie)
        }
    }

    func listSessions() async throws -> [SessionInfo] {
        try await loginIfNeeded()
        let (data, resp) = try await URLSession.shared.data(for: try request("/api/sessions?include_archived=0"))
        try validate(resp)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let raw = (json["sessions"] as? [[String: Any]]) ?? []
        return raw.compactMap { item in
            let sid = (item["sessionId"] as? String) ?? (item["session_id"] as? String) ?? (item["id"] as? String)
            guard let sid, !sid.isEmpty else { return nil }
            let title = (item["title"] as? String) ?? (item["name"] as? String) ?? "Untitled"
            return SessionInfo(sessionId: sid, title: title, updatedAt: nil)
        }
    }

    func createSession() async throws -> SessionInfo {
        try await loginIfNeeded()
        let (data, resp) = try await URLSession.shared.data(for: try request("/api/session/new", method: "POST", body: [:]))
        try validate(resp)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let session = json?["session"] as? [String: Any]
        let sid = (session?["sessionId"] as? String) ?? (session?["session_id"] as? String) ?? UUID().uuidString
        let title = (session?["title"] as? String) ?? "New chat"
        return SessionInfo(sessionId: sid, title: title, updatedAt: nil)
    }

    func startChat(sessionId: String, text: String) async throws {
        try await loginIfNeeded()
        let body = ["session_id": sessionId, "message": text]
        let (_, resp) = try await URLSession.shared.data(for: try request("/api/chat/start", method: "POST", body: body))
        try validate(resp)
    }

    /// POST /api/chat/start → returns `stream_id` for the SSE feed.
    func startChatStreaming(sessionId: String, text: String) async throws -> String {
        try await loginIfNeeded()
        let body = ["session_id": sessionId, "message": text]
        let (data, resp) = try await URLSession.shared.data(for: try request("/api/chat/start", method: "POST", body: body))
        try validate(resp)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.http(200)
        }
        if let err = json["error"] as? String, !err.isEmpty { throw APIError.http(400) }
        let sid = (json["stream_id"] as? String) ?? (json["streamId"] as? String) ?? ""
        return sid
    }

    func streamURL(streamId: String) throws -> URL {
        let sid = streamId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? streamId
        return try url("/api/chat/stream?stream_id=\(sid)&replay=1&after_seq=0")
    }

    func fetchMessages(sessionId: String, limit: Int = 120) async throws -> [ChatMessage] {
        try await loginIfNeeded()
        let sid = sessionId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? sessionId
        let path = "/api/session?session_id=\(sid)&messages=1&msg_limit=\(limit)"
        let (data, resp) = try await URLSession.shared.data(for: try request(path))
        try validate(resp)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let raw = (json["messages"] as? [[String: Any]]) ?? ((json["session"] as? [String: Any])?["messages"] as? [[String: Any]]) ?? []
        return raw.enumerated().compactMap { idx, item in
            let role = item["role"] as? String ?? "assistant"
            let content = item["content"] as? String ?? item["text"] as? String ?? ""
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
            let reasoning = item["reasoning"] as? String
            let serverID = item["id"].map { "srv-\($0)" }
            let messageID = item["message_id"].map { "mid-\($0)" }
            let id = serverID ?? messageID ?? "fx-\(sessionId)-\(idx)-\(content.hashValue)"
            return ChatMessage(id: id, role: role, content: content, timestamp: Date(),
                              reasoning: (reasoning?.isEmpty ?? true) ? nil : reasoning, isStreaming: false)
        }
    }

    func listScheduled() async throws -> [ScheduledItem] {
        let (data, resp) = try await URLSession.shared.data(for: try request("/webhook/scheduled-messages"))
        try validate(resp)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = json["messages"] as? [[String: Any]] else { return [] }
        return raw.compactMap { m in
            guard let key = m["scheduleKey"] as? String,
                  let text = m["text"] as? String,
                  let ts = m["scheduledAt"] as? TimeInterval else { return nil }
            return ScheduledItem(scheduleKey: key,
                                 sessionId: m["sessionId"] as? String ?? "",
                                 sessionTitle: m["sessionTitle"] as? String,
                                 text: text,
                                 scheduledAt: Date(timeIntervalSince1970: ts))
        }.sorted { $0.scheduledAt < $1.scheduledAt }
    }

    func schedule(text: String, sessionId: String, title: String?, at date: Date) async throws {
        let body: [String: Any] = [
            "scheduleKey": "ios-bullet|\(Int(date.timeIntervalSince1970))|\(UUID().uuidString)",
            "text": text,
            "sessionId": sessionId,
            "sessionTitle": title ?? "",
            "scheduledAt": date.timeIntervalSince1970
        ]
        let (_, resp) = try await URLSession.shared.data(for: try request("/webhook/scheduled-messages", method: "POST", body: body))
        try validate(resp)
    }

    func deleteScheduled(_ item: ScheduledItem) async throws {
        let (_, resp) = try await URLSession.shared.data(for: try request("/webhook/scheduled-messages", method: "DELETE", body: ["scheduleKey": item.scheduleKey]))
        try validate(resp)
    }

    func clearAuth() { cookie = nil }

    /// Exposed for the SSE reader (streaming path).
    var currentCookie: String? { cookie }

    private func validate(_ resp: URLResponse) throws {
        guard let http = resp as? HTTPURLResponse else { return }
        if http.statusCode == 401 { cookie = nil }
        guard (200..<300).contains(http.statusCode) else { throw APIError.http(http.statusCode) }
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case http(Int)
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .http(let code): return "HTTP \(code)"
        }
    }
}
