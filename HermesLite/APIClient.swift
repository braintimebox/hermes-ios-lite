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

    func createSession() async throws -> SessionInfo {
        try await loginIfNeeded()
        let (data, resp) = try await URLSession.shared.data(for: try request("/api/session/new", method: "POST", body: [:]))
        try validate(resp)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let session = json?["session"] as? [String: Any]
        let sid = (session?["sessionId"] as? String) ?? (session?["session_id"] as? String) ?? UUID().uuidString
        let title = (session?["title"] as? String) ?? "New chat"
        return SessionInfo(sessionId: sid, title: title)
    }

    func startChat(sessionId: String, text: String) async throws {
        try await loginIfNeeded()
        let body = ["session_id": sessionId, "message": text]
        let (_, resp) = try await URLSession.shared.data(for: try request("/api/chat/start", method: "POST", body: body))
        try validate(resp)
    }

    func fetchMessages(sessionId: String, limit: Int = 80) async throws -> [ChatMessage] {
        try await loginIfNeeded()
        let path = "/api/session?session_id=\(sessionId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? sessionId)&messages=1&msg_limit=\(limit)"
        let (data, resp) = try await URLSession.shared.data(for: try request(path))
        try validate(resp)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let raw = (json["messages"] as? [[String: Any]]) ?? ((json["session"] as? [String: Any])?["messages"] as? [[String: Any]]) ?? []
        return raw.enumerated().compactMap { idx, item in
            let role = item["role"] as? String ?? "assistant"
            let content = item["content"] as? String ?? item["text"] as? String ?? ""
            if content.isEmpty { return nil }
            let rawID = item["id"].map { "\($0)" } ?? item["message_id"].map { "\($0)" }
            let id = rawID ?? "\(sessionId)-\(idx)-\(content.hashValue)"
            return ChatMessage(id: id, role: role, content: content, timestamp: Date())
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
            "scheduleKey": "ios-lite|\(Int(date.timeIntervalSince1970))|\(UUID().uuidString)",
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
