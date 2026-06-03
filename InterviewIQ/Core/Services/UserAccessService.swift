import Foundation

enum UserAccessError: LocalizedError {
    case notSessionOwner
    case userNotFound
    case alreadyAssigned
    case notAssigned

    var errorDescription: String? {
        switch self {
        case .notSessionOwner:  return "Only the session owner can manage panelists."
        case .userNotFound:     return "No active user found with that email address."
        case .alreadyAssigned:  return "This user is already assigned to the session."
        case .notAssigned:      return "This user is not assigned to the session."
        }
    }
}

// UserAccessService: guards per-session panelist assignment (AGENTS.md Section 2).
// verifyAdminRights checks session ownership (not a system-wide role).
// attachPanelist / removePanelist mutate the session's interviewerIds list.
final class UserAccessService {
    private let sessionRepo: SessionRepository
    private let userRepo: UserRepository

    init(
        sessionRepo: SessionRepository = SessionRepository(),
        userRepo: UserRepository = UserRepository()
    ) {
        self.sessionRepo = sessionRepo
        self.userRepo = userRepo
    }

    // Throws UserAccessError.notSessionOwner if userId is not the session's adminId.
    func verifyAdminRights(userId: String, session: Session) throws {
        guard session.adminId == userId else {
            throw UserAccessError.notSessionOwner
        }
    }

    // Assigns a user as panelist on the session. Idempotency-safe: throws if already assigned.
    func attachPanelist(userId: String, to session: Session) async throws {
        guard !session.interviewerIds.contains(userId) else {
            throw UserAccessError.alreadyAssigned
        }
        var updated = session
        updated.interviewerIds.append(userId)
        try await sessionRepo.updateSession(updated)
    }

    // Removes a panelist from the session.
    func removePanelist(userId: String, from session: Session) async throws {
        guard session.interviewerIds.contains(userId) else {
            throw UserAccessError.notAssigned
        }
        var updated = session
        updated.interviewerIds.removeAll { $0 == userId }
        try await sessionRepo.updateSession(updated)
    }

    // Returns full UserProfile for each assigned panelist (best-effort; skips unresolvable ids).
    func fetchPanelists(for session: Session) async throws -> [UserProfile] {
        var profiles: [UserProfile] = []
        for uid in session.interviewerIds {
            if let profile = try? await userRepo.fetchProfile(userId: uid) {
                profiles.append(profile)
            }
        }
        return profiles
    }

    // Resolves an email to an active user for assignment lookup.
    func findUserByEmail(_ email: String) async throws -> UserProfile? {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        let all = try await userRepo.fetchAllUsers()
        return all.first { $0.emailAddress.lowercased() == normalized && $0.isActive }
    }
}
