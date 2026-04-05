import Foundation
import AuthenticationServices
import Security

// MARK: - Keychain Helper

private enum Keychain {
    static func save(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
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

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - AuthManager

@MainActor
final class AuthManager: NSObject, ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var currentAccount: Account?
    @Published var instanceURL: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let redirectURI = "mastodonwidget://oauth"
    private let scopes = "read write push"

    private var clientId: String?
    private var clientSecret: String?
    private var authSession: ASWebAuthenticationSession?

    private override init() {
        super.init()
        loadStoredCredentials()
    }

    // MARK: - Stored Credentials

    private func loadStoredCredentials() {
        if Keychain.load(key: "access_token") != nil,
           let instance = Keychain.load(key: "instance_url") {
            instanceURL = instance
            isAuthenticated = true
        }
    }

    var accessToken: String? {
        Keychain.load(key: "access_token")
    }

    // MARK: - OAuth Flow

    func login(instance: String) async {
        isLoading = true
        errorMessage = nil

        let cleanInstance = instance
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard !cleanInstance.isEmpty else {
            errorMessage = "Please enter a valid instance URL"
            isLoading = false
            return
        }

        instanceURL = cleanInstance

        do {
            // Step 1: Register the app
            let registration = try await registerApp(instance: cleanInstance)
            clientId = registration.clientId
            clientSecret = registration.clientSecret

            // Step 2: Build authorization URL
            var components = URLComponents()
            components.scheme = "https"
            components.host = cleanInstance
            components.path = "/oauth/authorize"
            components.queryItems = [
                URLQueryItem(name: "client_id", value: registration.clientId),
                URLQueryItem(name: "redirect_uri", value: redirectURI),
                URLQueryItem(name: "scope", value: scopes),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "force_login", value: "true")
            ]

            guard let authURL = components.url else {
                throw AuthError.invalidURL
            }

            // Step 3: Open auth session
            let code: String = try await withCheckedThrowingContinuation { continuation in
                let session = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: "mastodonwidget"
                ) { callbackURL, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let callbackURL,
                          let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                            .queryItems?.first(where: { $0.name == "code" })?.value
                    else {
                        continuation.resume(throwing: AuthError.noCode)
                        return
                    }
                    continuation.resume(returning: code)
                }
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false
                self.authSession = session
                session.start()
            }

            // Step 4: Exchange code for token
            let tokenResponse = try await exchangeCode(
                code: code,
                instance: cleanInstance,
                clientId: registration.clientId,
                clientSecret: registration.clientSecret
            )

            Keychain.save(key: "access_token", value: tokenResponse.accessToken)
            Keychain.save(key: "instance_url", value: cleanInstance)

            // Step 5: Fetch account info
            let account = try await fetchCurrentAccount(
                instance: cleanInstance,
                token: tokenResponse.accessToken
            )
            currentAccount = account
            isAuthenticated = true

        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            // User cancelled — silent
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func logout() {
        Keychain.delete(key: "access_token")
        Keychain.delete(key: "instance_url")
        isAuthenticated = false
        currentAccount = nil
        instanceURL = ""
        clientId = nil
        clientSecret = nil
    }

    // MARK: - API Calls

    private func registerApp(instance: String) async throws -> AppRegistration {
        let url = URL(string: "https://\(instance)/api/v1/apps")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "client_name": "MastodonWidget",
            "redirect_uris": redirectURI,
            "scopes": scopes,
            "website": "https://github.com/mastodonwidget"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(AppRegistration.self, from: data)
    }

    private func exchangeCode(
        code: String,
        instance: String,
        clientId: String,
        clientSecret: String
    ) async throws -> TokenResponse {
        let url = URL(string: "https://\(instance)/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code": code,
            "scope": scopes
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func fetchCurrentAccount(instance: String, token: String) async throws -> Account {
        let url = URL(string: "https://\(instance)/api/v1/accounts/verify_credentials")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Account.self, from: data)
    }

    // MARK: - Errors

    enum AuthError: LocalizedError {
        case invalidURL, noCode

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Could not build authorization URL."
            case .noCode: return "No authorization code received."
            }
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    // ASWebAuthenticationSession always calls this on the main thread.
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            NSApp.keyWindow ?? NSWindow()
        }
    }
}
