import AuthenticationServices
import Combine
import CryptoKit
import Foundation

/// A signed-in Supabase session. Stored in the Keychain, never in UserDefaults.
nonisolated struct AuthSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var userID: String
    var email: String?
    var provider: String        // "email", "apple" or "google"
}

/// Supabase Auth over its REST API (no SDK): email + password, Sign in with Apple
/// (native, token exchanged with Supabase) and Google (Supabase-hosted OAuth in an
/// ASWebAuthenticationSession). Accounts live in Supabase; medicines still stay on
/// the phone.
@MainActor
final class AuthStore: NSObject, ObservableObject {
    static let shared = AuthStore()

    @Published private(set) var session: AuthSession?
    var isSignedIn: Bool { session != nil }

    enum AuthError: LocalizedError {
        case notConfigured, cancelled, server(String), badResponse
        var errorDescription: String? {
            switch self {
            case .notConfigured: "Accounts aren't switched on in this build yet. You can keep using PharmEye without one."
            case .cancelled: nil
            case .server(let message): message
            case .badResponse: "The sign-in server sent something unexpected. Please try again."
            }
        }
    }

    enum SignUpResult { case signedIn, checkEmail }

    private static let keychainAccount = "auth.session"
    private var currentNonce: String?
    private var webSession: ASWebAuthenticationSession?

    override init() {
        super.init()
        if let json = Keychain.get(account: Self.keychainAccount),
           let data = json.data(using: .utf8),
           let saved = try? JSONDecoder().decode(AuthSession.self, from: data) {
            session = saved
        }
    }

    // MARK: Email

    func signUp(email: String, password: String) async throws -> SignUpResult {
        let json = try await post("/auth/v1/signup", body: ["email": email, "password": password])
        // With "Confirm email" on, Supabase returns the user but no session yet.
        if json["access_token"] == nil { return .checkEmail }
        try store(json, provider: "email")
        return .signedIn
    }

    func signIn(email: String, password: String) async throws {
        let json = try await post("/auth/v1/token?grant_type=password", body: ["email": email, "password": password])
        try store(json, provider: "email")
    }

    func sendPasswordReset(email: String) async throws {
        _ = try await post("/auth/v1/recover", body: ["email": email])
    }

    // MARK: Apple

    /// Call from SignInWithAppleButton's onRequest. Apple gets the SHA-256 of a random
    /// nonce; Supabase later gets the raw nonce to check the identity token wasn't replayed.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    /// Call from SignInWithAppleButton's onCompletion. Returns the name Apple shared (only
    /// given on the very first sign-in) so onboarding can prefill it.
    func completeApple(_ result: Result<ASAuthorization, Error>) async throws -> String? {
        let authorization: ASAuthorization
        switch result {
        case .success(let a): authorization = a
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { throw AuthError.cancelled }
            throw error
        }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              let nonce = currentNonce else { throw AuthError.badResponse }
        let json = try await post("/auth/v1/token?grant_type=id_token",
                                  body: ["provider": "apple", "id_token": idToken, "nonce": nonce])
        try store(json, provider: "apple")
        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }.joined(separator: " ")
        return name.isEmpty ? nil : name
    }

    // MARK: Google

    func signInWithGoogle() async throws {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        var components = URLComponents(string: SupabaseConfig.url + "/auth/v1/authorize")!
        components.queryItems = [
            .init(name: "provider", value: "google"),
            .init(name: "redirect_to", value: SupabaseConfig.redirectURL)
        ]
        let callback: URL = try await withCheckedThrowingContinuation { continuation in
            let web = ASWebAuthenticationSession(url: components.url!, callback: .customScheme(SupabaseConfig.redirectScheme)) { url, error in
                if let url { continuation.resume(returning: url); return }
                if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                    continuation.resume(throwing: AuthError.cancelled)
                } else {
                    continuation.resume(throwing: error ?? AuthError.badResponse)
                }
            }
            web.presentationContextProvider = self
            web.prefersEphemeralWebBrowserSession = false
            webSession = web
            web.start()
        }
        // Supabase returns the session in the URL fragment: #access_token=…&refresh_token=…
        var params: [String: String] = [:]
        for pair in (callback.fragment ?? "").split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if kv.count == 2 { params[kv[0]] = kv[1].removingPercentEncoding ?? kv[1] }
        }
        if let message = params["error_description"] { throw AuthError.server(message.replacingOccurrences(of: "+", with: " ")) }
        guard let access = params["access_token"], let refresh = params["refresh_token"] else { throw AuthError.badResponse }
        let user = try await get("/auth/v1/user", token: access)
        var json: [String: Any] = ["access_token": access, "refresh_token": refresh, "user": user]
        if let expires = params["expires_in"].flatMap(Double.init) { json["expires_in"] = expires }
        try store(json, provider: "google")
    }

    // MARK: Session upkeep

    /// Refreshes the access token if it's within a minute of expiring. Signs out if the
    /// refresh token has been revoked.
    func refreshIfNeeded() async {
        guard let session, session.expiresAt.timeIntervalSinceNow < 60 else { return }
        do {
            let json = try await post("/auth/v1/token?grant_type=refresh_token", body: ["refresh_token": session.refreshToken])
            try store(json, provider: session.provider)
        } catch AuthError.server {
            signOut()
        } catch {
            // Offline — keep the old session and try again next time.
        }
    }

    func signOut() {
        if let token = session?.accessToken, SupabaseConfig.isConfigured {
            Task { _ = try? await post("/auth/v1/logout", body: [:], token: token) }
        }
        session = nil
        Keychain.delete(account: Self.keychainAccount)
    }

    // MARK: Plumbing

    private func store(_ json: [String: Any], provider: String) throws {
        guard let access = json["access_token"] as? String,
              let refresh = json["refresh_token"] as? String,
              let user = json["user"] as? [String: Any],
              let id = user["id"] as? String else { throw AuthError.badResponse }
        let expiresIn = (json["expires_in"] as? Double) ?? 3600
        let new = AuthSession(accessToken: access, refreshToken: refresh,
                              expiresAt: Date().addingTimeInterval(expiresIn),
                              userID: id, email: user["email"] as? String, provider: provider)
        session = new
        if let data = try? JSONEncoder().encode(new), let text = String(data: data, encoding: .utf8) {
            Keychain.set(text, account: Self.keychainAccount)
        }
    }

    private func post(_ path: String, body: [String: Any], token: String? = nil) async throws -> [String: Any] {
        try await send(path, method: "POST", body: body, token: token)
    }

    private func get(_ path: String, token: String) async throws -> [String: Any] {
        try await send(path, method: "GET", body: nil, token: token)
    }

    private func send(_ path: String, method: String, body: [String: Any]?, token: String?) async throws -> [String: Any] {
        guard SupabaseConfig.isConfigured, let url = URL(string: SupabaseConfig.url + path) else { throw AuthError.notConfigured }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        // Only a signed-in user's token goes in Authorization. The project key travels in
        // `apikey`, which works for both legacy anon keys and newer sb_publishable_ keys.
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(status) else {
            let message = (json["error_description"] ?? json["msg"] ?? json["message"] ?? json["error"]) as? String
            throw AuthError.server(Self.friendly(message) ?? "Something went wrong (\(status)). Please try again.")
        }
        return json
    }

    /// Supabase's messages, reworded where they'd confuse a patient.
    private static func friendly(_ message: String?) -> String? {
        guard let message else { return nil }
        switch message {
        case "Invalid login credentials": return "That email and password don't match. Check them, or reset your password."
        case "User already registered": return "There's already an account with that email. Try signing in instead."
        case "Email not confirmed": return "Please confirm your email first. We sent you a link."
        default: return message
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in chars.randomElement(using: &generator)! })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

extension AuthStore: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            if let key = scenes.compactMap(\.keyWindow).first { return key }
            return ASPresentationAnchor(windowScene: scenes[0])
        }
    }
}
