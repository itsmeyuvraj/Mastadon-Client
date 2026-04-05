import Foundation

// MARK: - API Error

enum APIError: LocalizedError {
    case notAuthenticated
    case invalidResponse(Int)
    case decodingError(Error)
    case networkError(Error)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not authenticated. Please log in."
        case .invalidResponse(let code): return "Server responded with status \(code)."
        case .decodingError(let e): return "Failed to parse response: \(e.localizedDescription)"
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .serverError(let msg): return msg
        }
    }
}

// MARK: - Mastodon API Service

final class MastodonAPI {
    static let shared = MastodonAPI()
    private init() {}

    private var decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .useDefaultKeys
        return d
    }()

    private func baseURL() throws -> String {
        guard let instance = Keychain_load(key: "instance_url"), !instance.isEmpty else {
            throw APIError.notAuthenticated
        }
        return "https://\(instance)"
    }

    private func authHeader() throws -> String {
        guard let token = Keychain_load(key: "access_token") else {
            throw APIError.notAuthenticated
        }
        return "Bearer \(token)"
    }

    private func request(_ path: String, method: String = "GET") throws -> URLRequest {
        let base = try baseURL()
        guard let url = URL(string: "\(base)\(path)") else {
            throw APIError.notAuthenticated
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(try authHeader(), forHTTPHeaderField: "Authorization")
        return req
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(0)
        }
        guard (200..<300).contains(http.statusCode) else {
            // Try to parse error message
            if let errorBody = try? JSONDecoder().decode([String: String].self, from: data),
               let msg = errorBody["error"] {
                throw APIError.serverError(msg)
            }
            throw APIError.invalidResponse(http.statusCode)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Timeline

    func homeTimeline(maxId: String? = nil, limit: Int = 20) async throws -> [Status] {
        var path = "/api/v1/timelines/home?limit=\(limit)"
        if let maxId { path += "&max_id=\(maxId)" }
        let req = try request(path)
        return try await perform(req)
    }

    func publicTimeline(maxId: String? = nil, limit: Int = 20) async throws -> [Status] {
        var path = "/api/v1/timelines/public?limit=\(limit)"
        if let maxId { path += "&max_id=\(maxId)" }
        let req = try request(path)
        return try await perform(req)
    }

    // MARK: - Posting

    func postStatus(
        text: String,
        mediaIds: [String] = [],
        visibility: Status.Visibility = .public,
        sensitive: Bool = false,
        spoilerText: String = "",
        replyToId: String? = nil
    ) async throws -> Status {
        var req = try request("/api/v1/statuses", method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "status": text,
            "visibility": visibility.rawValue,
            "sensitive": sensitive
        ]
        if !mediaIds.isEmpty { body["media_ids"] = mediaIds }
        if !spoilerText.isEmpty { body["spoiler_text"] = spoilerText }
        if let replyId = replyToId { body["in_reply_to_id"] = replyId }

        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await perform(req)
    }

    // MARK: - Media Upload

    func uploadMedia(imageData: Data, mimeType: String = "image/jpeg") async throws -> MediaUploadResponse {
        let base = try baseURL()
        guard let url = URL(string: "\(base)/api/v2/media") else {
            throw APIError.notAuthenticated
        }

        let boundary = UUID().uuidString
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(try authHeader(), forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        return try await perform(req)
    }

    // MARK: - Interactions

    func favourite(id: String) async throws -> Status {
        let req = try request("/api/v1/statuses/\(id)/favourite", method: "POST")
        return try await perform(req)
    }

    func unfavourite(id: String) async throws -> Status {
        let req = try request("/api/v1/statuses/\(id)/unfavourite", method: "POST")
        return try await perform(req)
    }

    func reblog(id: String) async throws -> Status {
        let req = try request("/api/v1/statuses/\(id)/reblog", method: "POST")
        return try await perform(req)
    }

    func unreblog(id: String) async throws -> Status {
        let req = try request("/api/v1/statuses/\(id)/unreblog", method: "POST")
        return try await perform(req)
    }

    // MARK: - Account

    func verifyCredentials() async throws -> Account {
        let req = try request("/api/v1/accounts/verify_credentials")
        return try await perform(req)
    }

    // MARK: - Streaming URL

    func streamingURL() throws -> URL? {
        let instance = try baseURL().replacingOccurrences(of: "https://", with: "")
        guard let token = Keychain_load(key: "access_token") else { return nil }
        return URL(string: "wss://\(instance)/api/v1/streaming?access_token=\(token)&stream=user")
    }
}

// Non-isolated keychain access for use in non-actor contexts
private func Keychain_load(key: String) -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]
    var result: AnyObject?
    SecItemCopyMatching(query as CFDictionary, &result)
    guard let data = result as? Data else { return nil }
    return String(data: data, encoding: .utf8)
}
