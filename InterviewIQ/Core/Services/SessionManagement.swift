import Foundation

enum SessionValidationError: LocalizedError {
    case emptyTitle
    case dateInPast
    case noCandidates

    var errorDescription: String? {
        switch self {
        case .emptyTitle:   return "Session title cannot be empty."
        case .dateInPast:   return "Session date must be today or in the future."
        case .noCandidates: return "Add at least one candidate before saving."
        }
    }
}

final class SessionManagementService {
    private let repo: SessionRepository

    init(repo: SessionRepository = SessionRepository()) {
        self.repo = repo
    }

    func validateSession(title: String, date: Date, candidateNames: [String]) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SessionValidationError.emptyTitle
        }
        let today = Calendar.current.startOfDay(for: Date())
        guard date >= today else {
            throw SessionValidationError.dateInPast
        }
        let nonEmpty = candidateNames.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !nonEmpty.isEmpty else {
            throw SessionValidationError.noCandidates
        }
    }

    func loadSessions(adminId: String) async throws -> [Session] {
        try await repo.fetchSessions(adminId: adminId)
    }

    @discardableResult
    func createSession(
        title: String,
        date: Date,
        adminId: String,
        candidateNames: [String]
    ) async throws -> Session {
        try validateSession(title: title, date: date, candidateNames: candidateNames)

        let session = Session(title: title, date: date, adminId: adminId)
        try await repo.saveSession(session)

        let nonEmpty = candidateNames.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        for name in nonEmpty {
            let candidate = Candidate(name: name, sessionId: session.id)
            try await repo.saveCandidate(candidate, sessionId: session.id)
        }

        return session
    }

    func updateSession(
        session: Session,
        candidateNames: [String],
        existingCandidates: [Candidate]
    ) async throws {
        try validateSession(title: session.title, date: session.date, candidateNames: candidateNames)

        try await repo.updateSession(session)

        let newNames = candidateNames.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        // Delete candidates whose names are no longer in the new list
        for existing in existingCandidates {
            if !newNames.contains(existing.name) {
                try await repo.deleteCandidate(candidateId: existing.id, sessionId: session.id)
            }
        }

        // Add candidates whose names have no existing match
        let existingNames = existingCandidates.map { $0.name }
        for name in newNames where !existingNames.contains(name) {
            let candidate = Candidate(name: name, sessionId: session.id)
            try await repo.saveCandidate(candidate, sessionId: session.id)
        }
    }

    func deleteSession(sessionId: String) async throws {
        try await repo.deleteSession(sessionId: sessionId)
    }
}
