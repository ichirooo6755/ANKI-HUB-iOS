import Foundation

final class SupabaseHTTPClient {
    enum HTTPError: Error {
        case invalidURL
        case invalidResponse
        case httpError(statusCode: Int, body: String)
    }

    let baseURL: URL
    let anonKey: String

    init(baseURL: URL = SupabaseConfig.url, anonKey: String = SupabaseConfig.anonKey) {
        self.baseURL = baseURL
        self.anonKey = anonKey
    }

    func request(
        _ method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        accessToken: String? = nil,
        additionalHeaders: [String: String] = [:],
        body: Data? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw HTTPError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else { throw HTTPError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpBody = body

        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        if let accessToken {
            req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        for (k, v) in additionalHeaders {
            req.setValue(v, forHTTPHeaderField: k)
        }

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }

        if !(200...299).contains(http.statusCode) {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw HTTPError.httpError(statusCode: http.statusCode, body: bodyStr)
        }

        return (data, http)
    }
}
