import Foundation

final class SupabaseUserService {
    static let shared = SupabaseUserService()

    private let http = SupabaseHTTPClient()

    private init() {}

    func upsertUser(id: String, email: String, accessToken: String) async throws {
        let payload: [[String: Any]] = [
            [
                "id": id,
                "email": email,
                "last_login": ISO8601DateFormatter().string(from: Date())
            ]
        ]

        let body = try JSONSerialization.data(withJSONObject: payload, options: [])

        _ = try await http.request(
            "POST",
            path: "rest/v1/users",
            queryItems: [
                URLQueryItem(name: "on_conflict", value: "id")
            ],
            accessToken: accessToken,
            additionalHeaders: [
                "Content-Type": "application/json",
                "Prefer": "resolution=merge-duplicates"
            ],
            body: body
        )
    }
}
