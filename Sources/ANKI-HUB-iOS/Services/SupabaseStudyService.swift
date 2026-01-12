import Foundation

final class SupabaseStudyService {
    static let shared = SupabaseStudyService()

    private let http = SupabaseHTTPClient()

    private init() {}

    struct StudyRow: Codable {
        let userId: String
        let appId: String
        let data: AnyCodable

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case appId = "app_id"
            case data
        }
    }

    func upsert(userId: String, appId: String, data: Any, accessToken: String) async throws {
        let payload: [[String: Any]] = [
            [
                "user_id": userId,
                "app_id": appId,
                "data": data
            ]
        ]

        let body = try JSONSerialization.data(withJSONObject: payload, options: [])

        _ = try await http.request(
            "POST",
            path: "rest/v1/study",
            queryItems: [
                URLQueryItem(name: "on_conflict", value: "user_id,app_id")
            ],
            accessToken: accessToken,
            additionalHeaders: [
                "Content-Type": "application/json",
                "Prefer": "resolution=merge-duplicates"
            ],
            body: body
        )
    }

    func fetch(userId: String, appId: String, accessToken: String) async throws -> Any? {
        let (data, _) = try await http.request(
            "GET",
            path: "rest/v1/study",
            queryItems: [
                URLQueryItem(name: "select", value: "data"),
                URLQueryItem(name: "user_id", value: "eq.\(userId)"),
                URLQueryItem(name: "app_id", value: "eq.\(appId)"),
                URLQueryItem(name: "limit", value: "1")
            ],
            accessToken: accessToken,
            additionalHeaders: [
                "Accept": "application/json"
            ]
        )

        let rows = try JSONDecoder().decode([[String: AnyCodable]].self, from: data)
        return rows.first?["data"]?.value
    }
}

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else if let arr = try? container.decode([AnyCodable].self) {
            self.value = arr.map { $0.value }
        } else if let str = try? container.decode(String.self) {
            self.value = str
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let dbl = try? container.decode(Double.self) {
            self.value = dbl
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if container.decodeNil() {
            self.value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        case let arr as [Any]:
            try container.encode(arr.map { AnyCodable($0) })
        case let str as String:
            try container.encode(str)
        case let int as Int:
            try container.encode(int)
        case let dbl as Double:
            try container.encode(dbl)
        case let bool as Bool:
            try container.encode(bool)
        case _ as NSNull:
            try container.encodeNil()
        default:
            let ctx = EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported JSON")
            throw EncodingError.invalidValue(value, ctx)
        }
    }
}
