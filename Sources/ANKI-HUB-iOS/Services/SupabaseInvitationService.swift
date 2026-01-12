import Foundation

final class SupabaseInvitationService {
    static let shared = SupabaseInvitationService()

    private let http = SupabaseHTTPClient()

    private init() {}

    struct InvitationRow: Codable {
        let code: String?
        let isUsed: Bool?
        let usedBy: String?

        enum CodingKeys: String, CodingKey {
            case code
            case isUsed = "is_used"
            case usedBy = "used_by"
        }
    }

    func checkInvitation(userId: String, accessToken: String) async throws -> Bool {
        let (data, _) = try await http.request(
            "GET",
            path: "rest/v1/invitations",
            queryItems: [
                URLQueryItem(name: "select", value: "code"),
                URLQueryItem(name: "used_by", value: "eq.\(userId)"),
                URLQueryItem(name: "limit", value: "1")
            ],
            accessToken: accessToken,
            additionalHeaders: [
                "Accept": "application/json"
            ]
        )

        let rows = try JSONDecoder().decode([InvitationRow].self, from: data)
        return !rows.isEmpty
    }

    func verifyInviteCode(code: String, userId: String, accessToken: String) async throws -> Bool {
        let payload: [String: Any] = [
            "is_used": true,
            "used_by": userId,
            "used_at": ISO8601DateFormatter().string(from: Date())
        ]

        let body = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, _) = try await http.request(
            "PATCH",
            path: "rest/v1/invitations",
            queryItems: [
                URLQueryItem(name: "code", value: "eq.\(code)"),
                URLQueryItem(name: "is_used", value: "eq.false")
            ],
            accessToken: accessToken,
            additionalHeaders: [
                "Accept": "application/json",
                "Content-Type": "application/json",
                "Prefer": "return=representation"
            ],
            body: body
        )

        let rows = try JSONDecoder().decode([InvitationRow].self, from: data)
        return !rows.isEmpty
    }
}
