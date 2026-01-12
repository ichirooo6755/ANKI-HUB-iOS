import Foundation

// MARK: - Supabase Client (Placeholder)
// Note: To enable Supabase functionality, add the Supabase Swift SDK package:
// https://github.com/supabase-community/supabase-swift

@MainActor
class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    @Published var isConnected = false
    @Published var lastSyncDate: Date?
    
    private init() {
        isConnected = SupabaseAuthService.shared.session?.accessToken != nil
    }

    enum UnsupportedAuthError: Error {
        case emailPasswordNotSupported
    }
    
    // MARK: - Authentication (Placeholder)
    
    func signInWithEmail(email: String, password: String) async throws {
        throw UnsupportedAuthError.emailPasswordNotSupported
    }
    
    func signUp(email: String, password: String) async throws {
        throw UnsupportedAuthError.emailPasswordNotSupported
    }

    func signInWithGoogle() async throws {
        _ = try await SupabaseAuthService.shared.signInWithGoogle()
        isConnected = true
    }
    
    func signOut() async throws {
        await SupabaseAuthService.shared.signOut()
        isConnected = false
    }
    
    // MARK: - Data Sync (Placeholder)
    
    func syncLearningStats(_ stats: LearningStatsData) async throws {
        await SyncManager.shared.syncAllDebounced()
        lastSyncDate = Date()
    }
    
    func fetchLearningStats() async throws -> LearningStatsData? {
        return nil
    }
    
    func syncMasteryData(_ data: [MasteryRecord]) async throws {
        await SyncManager.shared.syncAllDebounced()
        lastSyncDate = Date()
    }
    
    func fetchMasteryData() async throws -> [MasteryRecord] {
        return []
    }
    
    // MARK: - Invite Code Verification (Placeholder)
    
    func verifyInviteCode(_ code: String) async throws -> Bool {
        guard let user = AuthManager.shared.currentUser,
              let token = SupabaseAuthService.shared.session?.accessToken else {
            return false
        }

        let ok = try await SupabaseInvitationService.shared.verifyInviteCode(code: code, userId: user.id, accessToken: token)
        if ok {
            AuthManager.shared.isInvited = true
            await SyncManager.shared.loadAll(force: true)
        }
        return ok
    }
}

// MARK: - Data Models for Supabase

struct LearningStatsData: Codable {
    let userId: String
    var streak: Int
    var todayMinutes: Int
    var masteredCount: Int
    var learningCount: Int
    var masteryRate: Int
    var dailyHistory: String // JSON encoded
    var updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case streak
        case todayMinutes = "today_minutes"
        case masteredCount = "mastered_count"
        case learningCount = "learning_count"
        case masteryRate = "mastery_rate"
        case dailyHistory = "daily_history"
        case updatedAt = "updated_at"
    }
}

struct MasteryRecord: Codable {
    let id: String?
    let userId: String
    let wordId: String
    let subject: String
    let level: Int
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case wordId = "word_id"
        case subject
        case level
        case updatedAt = "updated_at"
    }
}

struct InviteCode: Codable {
    let id: String
    let code: String
    let isUsed: Bool
    let usedBy: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case code
        case isUsed = "is_used"
        case usedBy = "used_by"
    }
}
