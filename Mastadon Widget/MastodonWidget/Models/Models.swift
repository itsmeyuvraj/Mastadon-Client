import Foundation

// MARK: - Account

struct Account: Codable, Identifiable {
    let id: String
    let username: String
    let acct: String
    let displayName: String
    let note: String
    let avatar: String
    let header: String
    let followersCount: Int
    let followingCount: Int
    let statusesCount: Int

    enum CodingKeys: String, CodingKey {
        case id, username, acct, note, avatar, header
        case displayName = "display_name"
        case followersCount = "followers_count"
        case followingCount = "following_count"
        case statusesCount = "statuses_count"
    }
}

// MARK: - MediaAttachment

struct MediaAttachment: Codable, Identifiable {
    let id: String
    let type: MediaType
    let url: String?
    let previewUrl: String?
    let description: String?

    enum MediaType: String, Codable {
        case image, gifv, video, audio, unknown
    }

    enum CodingKeys: String, CodingKey {
        case id, type, url, description
        case previewUrl = "preview_url"
    }
}

// MARK: - Status

struct Status: Codable, Identifiable {
    let id: String
    let createdAt: String
    let content: String
    let url: String?
    let repliesCount: Int
    let reblogsCount: Int
    let favouritesCount: Int
    let account: Account
    let mediaAttachments: [MediaAttachment]
    let reblog: Box<Status>?
    let sensitive: Bool
    let spoilerText: String
    let visibility: Visibility
    var favourited: Bool?
    var reblogged: Bool?

    enum Visibility: String, Codable {
        case `public`, unlisted, `private`, direct
    }

    enum CodingKeys: String, CodingKey {
        case id, content, url, account, sensitive, visibility, reblog
        case createdAt = "created_at"
        case repliesCount = "replies_count"
        case reblogsCount = "reblogs_count"
        case favouritesCount = "favourites_count"
        case mediaAttachments = "media_attachments"
        case spoilerText = "spoiler_text"
        case favourited, reblogged
    }

    // Strip HTML tags from content for display
    var plainText: String {
        content
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<p>", with: "")
            .replacingOccurrences(of: "</p>", with: "\n\n")
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: createdAt) else { return createdAt }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .short
        return rel.localizedString(for: date, relativeTo: .now)
    }
}

// Wrapper to avoid recursive Codable issues
final class Box<T: Codable>: Codable {
    let value: T
    init(_ value: T) { self.value = value }
    required init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(T.self)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - App Registration Response

struct AppRegistration: Codable {
    let id: String
    let clientId: String
    let clientSecret: String

    enum CodingKeys: String, CodingKey {
        case id
        case clientId = "client_id"
        case clientSecret = "client_secret"
    }
}

// MARK: - Token Response

struct TokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let scope: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
    }
}

// MARK: - Streaming Event

struct StreamingEvent {
    enum EventType: String {
        case update, delete, notification, filters_changed, announcement
    }
    let type: EventType
    let payload: String
}

// MARK: - Media Upload Response

struct MediaUploadResponse: Codable {
    let id: String
    let type: String
    let url: String?
    let previewUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, type, url
        case previewUrl = "preview_url"
    }
}
