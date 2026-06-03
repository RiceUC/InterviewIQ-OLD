import Foundation

enum SessionValidationError: LocalizedError {
    case emptyTitle
    case dateInPast
    case noCandidates
    case noQuestions
    case invalidMaxScore

    var errorDescription: String? {
        switch self {
        case .emptyTitle:      return "Session title cannot be empty."
        case .dateInPast:      return "Session date must be today or in the future."
        case .noCandidates:    return "Add at least one candidate before saving."
        case .noQuestions:     return "Add at least one rubric question before saving."
        case .invalidMaxScore: return "Each question's max score must be at least 1."
        }
    }
}

final class SessionManagementService {
    private let repo: SessionRepository
    private let rubricRepo: RubricRepository

    init(
        repo: SessionRepository = SessionRepository(),
        rubricRepo: RubricRepository = RubricRepository()
    ) {
        self.repo = repo
        self.rubricRepo = rubricRepo
    }

    // Validates session, candidates, and rubric together — a session is only
    // valid as a complete unit (UC-02 + UC-03 bounded service).
    func validateSession(
        title: String,
        date: Date,
        candidateNames: [String],
        questions: [RubricQuestion]
    ) throws {
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
        guard !questions.isEmpty else {
            throw SessionValidationError.noQuestions
        }
        guard questions.allSatisfy({ $0.maxScore >= 1 }) else {
            throw SessionValidationError.invalidMaxScore
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
        candidateNames: [String],
        questions: [RubricQuestion]
    ) async throws -> Session {
        try validateSession(title: title, date: date, candidateNames: candidateNames, questions: questions)

        let session = Session(title: title, date: date, adminId: adminId)
        try await repo.saveSession(session)

        let nonEmpty = candidateNames.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        for name in nonEmpty {
            let candidate = Candidate(name: name, sessionId: session.id)
            try await repo.saveCandidate(candidate, sessionId: session.id)
        }

        for question in questions {
            try await rubricRepo.saveQuestion(question, sessionId: session.id)
        }

        return session
    }

    func updateSession(
        session: Session,
        candidateNames: [String],
        existingCandidates: [Candidate],
        questions: [RubricQuestion],
        existingQuestions: [RubricQuestion]
    ) async throws {
        try validateSession(title: session.title, date: session.date, candidateNames: candidateNames, questions: questions)

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

        // Reconcile rubric questions: delete removed, write current set
        let newIds = Set(questions.map { $0.id })
        for existing in existingQuestions where !newIds.contains(existing.id) {
            try await rubricRepo.deleteQuestion(questionId: existing.id, sessionId: session.id)
        }
        for question in questions {
            try await rubricRepo.saveQuestion(question, sessionId: session.id)
        }
    }

    func deleteSession(sessionId: String) async throws {
        try await repo.deleteSession(sessionId: sessionId)
    }
}
