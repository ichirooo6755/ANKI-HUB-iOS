import Foundation

final class SupabaseMistakeReportService {
    static let shared = SupabaseMistakeReportService()

    private let http = SupabaseHTTPClient()

    private init() {}

    func submit(
        userId: String,
        subject: String,
        wordId: String,
        questionText: String,
        correctAnswer: String,
        chosenAnswer: String?,
        note: String?,
        accessToken: String
    ) async throws {
        var payload: [String: Any] = [
            "user_id": userId,
            "subject": subject,
            "word_id": wordId,
            "question_text": questionText,
            "correct_answer": correctAnswer,
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]

        if let chosenAnswer {
            payload["chosen_answer"] = chosenAnswer
        }
        if let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["note"] = note
        }

        let body = try JSONSerialization.data(withJSONObject: [payload], options: [])

        _ = try await http.request(
            "POST",
            path: "rest/v1/mistake_reports",
            accessToken: accessToken,
            additionalHeaders: [
                "Content-Type": "application/json",
                "Prefer": "return=minimal"
            ],
            body: body
        )
    }
}
