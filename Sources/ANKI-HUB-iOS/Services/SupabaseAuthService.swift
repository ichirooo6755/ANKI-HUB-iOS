import AuthenticationServices
import CryptoKit
import Foundation

#if os(iOS)
    import UIKit

    @MainActor
    final class SupabaseAuthService: NSObject, ObservableObject,
        ASWebAuthenticationPresentationContextProviding
    {
        static let shared = SupabaseAuthService()

        @Published private(set) var session: SupabaseSession?

        private var webAuthSession: ASWebAuthenticationSession?

        enum AuthError: Error {
            case unableToStart
        }

        private let http = SupabaseHTTPClient()
        private let keychainService = "sugwranki.supabase"
        private let sessionAccount = "session"

        private override init() {
            super.init()
            loadSessionFromKeychain()
        }

        func loadSessionFromKeychain() {
            do {
                let data = try KeychainService.get(
                    service: keychainService, account: sessionAccount)
                let decoded = try JSONDecoder().decode(SupabaseSession.self, from: data)
                session = decoded
            } catch {
                session = nil
            }
        }

        func signOut() async {
            if let token = session?.accessToken {
                _ = try? await http.request(
                    "POST",
                    path: "auth/v1/logout",
                    accessToken: token,
                    additionalHeaders: [
                        "Content-Type": "application/json"
                    ],
                    body: Data("{}".utf8)
                )
            }

            session = nil
            try? KeychainService.delete(service: keychainService, account: sessionAccount)
        }

        func signInWithGoogle() async throws -> SupabaseSession {
            let verifier = Self.generateCodeVerifier()
            let challenge = Self.codeChallenge(for: verifier)

            let redirectTo = "\(SupabaseConfig.redirectScheme)://login-callback"
            print("[SupabaseAuth] Starting Google sign-in with redirect: \(redirectTo)")

            var components = URLComponents(
                url: SupabaseConfig.url.appendingPathComponent("auth/v1/authorize"),
                resolvingAgainstBaseURL: false)
            components?.queryItems = [
                URLQueryItem(name: "provider", value: "google"),
                URLQueryItem(name: "redirect_to", value: redirectTo),
                URLQueryItem(name: "code_challenge", value: challenge),
                URLQueryItem(name: "code_challenge_method", value: "S256"),
            ]
            guard let authURL = components?.url else {
                print("[SupabaseAuth] ERROR: Failed to build auth URL")
                throw SupabaseHTTPClient.HTTPError.invalidURL
            }

            print("[SupabaseAuth] Auth URL: \(authURL)")

            let callbackURL: URL
            do {
                callbackURL = try await startWebAuth(
                    url: authURL, callbackScheme: SupabaseConfig.redirectScheme)
                print("[SupabaseAuth] Callback received: \(callbackURL)")
            } catch {
                print("[SupabaseAuth] Web auth error: \(error)")
                throw error
            }

            let callbackComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
            var code = callbackComponents?.queryItems?.first(where: { $0.name == "code" })?.value

            if code == nil, let fragment = callbackComponents?.fragment {
                // Some providers return query-like values in fragment (e.g. #code=...)
                let fragmentComponents = URLComponents(string: "?" + fragment)
                code = fragmentComponents?.queryItems?.first(where: { $0.name == "code" })?.value
            }

            guard let code else {
                print("[SupabaseAuth] ERROR: No code in callback URL: \(callbackURL)")
                throw SupabaseHTTPClient.HTTPError.invalidResponse
            }

            print("[SupabaseAuth] Exchanging code for token...")

            let body: [String: String] = [
                "auth_code": code,
                "code_verifier": verifier,
            ]
            let payload = try JSONEncoder().encode(body)

            let (data, _) = try await http.request(
                "POST",
                path: "auth/v1/token",
                queryItems: [URLQueryItem(name: "grant_type", value: "pkce")],
                additionalHeaders: [
                    "Content-Type": "application/json"
                ],
                body: payload
            )

            let decoded = try JSONDecoder().decode(SupabaseSession.self, from: data)
            session = decoded
            print("[SupabaseAuth] Sign-in successful, user: \(decoded.user.email ?? "unknown")")

            let encoded = try JSONEncoder().encode(decoded)
            try KeychainService.set(encoded, service: keychainService, account: sessionAccount)

            return decoded
        }

        func refreshIfNeeded() async {
            guard let current = session else { return }
            let body: [String: String] = [
                "refresh_token": current.refreshToken
            ]

            do {
                let payload = try JSONEncoder().encode(body)
                let (data, _) = try await http.request(
                    "POST",
                    path: "auth/v1/token",
                    queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")],
                    additionalHeaders: [
                        "Content-Type": "application/json"
                    ],
                    body: payload
                )

                let decoded = try JSONDecoder().decode(SupabaseSession.self, from: data)
                session = decoded
                let encoded = try JSONEncoder().encode(decoded)
                try KeychainService.set(encoded, service: keychainService, account: sessionAccount)
            } catch {
                print("[SupabaseAuth] refreshIfNeeded failed: \(error)")
            }
        }

        private func startWebAuth(url: URL, callbackScheme: String) async throws -> URL {
            try await withCheckedThrowingContinuation { continuation in
                let session = ASWebAuthenticationSession(
                    url: url, callbackURLScheme: callbackScheme
                ) { [weak self] callbackURL, error in
                    if let error {
                        self?.webAuthSession = nil
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let callbackURL else {
                        self?.webAuthSession = nil
                        continuation.resume(throwing: SupabaseHTTPClient.HTTPError.invalidResponse)
                        return
                    }
                    self?.webAuthSession = nil
                    continuation.resume(returning: callbackURL)
                }
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = true
                self.webAuthSession = session
                let started = session.start()
                if !started {
                    self.webAuthSession = nil
                    continuation.resume(throwing: AuthError.unableToStart)
                }
            }
        }

        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            guard
                let scene = UIApplication.shared.connectedScenes.first(where: {
                    $0.activationState == .foregroundActive
                }) as? UIWindowScene,
                let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
            else {
                return ASPresentationAnchor()
            }
            return window
        }

        private static func generateCodeVerifier() -> String {
            let data = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
            return base64URLEncode(data)
        }

        private static func codeChallenge(for verifier: String) -> String {
            let data = Data(verifier.utf8)
            let hash = SHA256.hash(data: data)
            return base64URLEncode(Data(hash))
        }

        private static func base64URLEncode(_ data: Data) -> String {
            data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
    }

#else

    @MainActor
    final class SupabaseAuthService: NSObject, ObservableObject {
        static let shared = SupabaseAuthService()

        @Published private(set) var session: SupabaseSession?

        private override init() {
            super.init()
        }

        func loadSessionFromKeychain() {
            session = nil
        }

        func signOut() async {
            session = nil
        }

        func signInWithGoogle() async throws -> SupabaseSession {
            throw SupabaseHTTPClient.HTTPError.invalidResponse
        }

        func refreshIfNeeded() async {
            // no-op
        }
    }

#endif
