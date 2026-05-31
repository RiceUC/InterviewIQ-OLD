import Foundation
import FirebaseFirestore

// Business logic for UC-04: candidate locking, score validation,
// total-score calculation, and rubric/candidate fetching.
final class InterviewConductorService {
    private let db = Firestore.firestore()
    private let lockDuration: TimeInterval = 2 * 60 * 60  // 2 hours

    // MARK: - Data Fetching

    // Rubric questions are written by Clarice (UC-03) at sessions/{id}/rubricQuestions
    func fetchRubricQuestions(sessionId: String) async throws -> [RubricQuestion] {
        let snapshot = try await db
            .collection("sessions")
            .document(sessionId)
            .collection("rubricQuestions")
            .order(by: "order")
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: RubricQuestion.self) }
    }

    // MARK: - Candidate Lock (1:1 rule per UC-04)

    // Returns true if the lock was acquired, false if another interviewer holds it.
    func lockCandidate(candidateId: String, interviewerId: String, sessionId: String) async throws -> Bool {
        let lockRef = db
            .collection("sessions")
            .document(sessionId)
            .collection("candidateLocks")
            .document(candidateId)

        let doc = try await lockRef.getDocument()

        // Deny if an active lock exists for a different interviewer
        if doc.exists,
           let data = doc.data(),
           let isLocked = data["isLocked"] as? Bool, isLocked,
           let existingId = data["interviewerId"] as? String, existingId != interviewerId,
           let expires = (data["expiresAt"] as? Timestamp)?.dateValue(), expires > Date() {
            return false
        }

        let now = Date()
        try await lockRef.setData([
            "candidateId": candidateId,
            "interviewerId": interviewerId,
            "sessionId": sessionId,
            "lockedAt": Timestamp(date: now),
            "expiresAt": Timestamp(date: now.addingTimeInterval(lockDuration)),
            "isLocked": true
        ])
        return true
    }

    func releaseLock(candidateId: String, sessionId: String) async throws {
        try await db
            .collection("sessions")
            .document(sessionId)
            .collection("candidateLocks")
            .document(candidateId)
            .updateData(["isLocked": false])
    }

    // MARK: - Validation & Calculation

    // Returns questions that have no score (score == 0) yet.
    func unansweredQuestions(in questions: [RubricQuestion], scores: [String: QuestionScore]) -> [RubricQuestion] {
        questions.filter { q in
            guard let s = scores[q.id] else { return true }
            return !s.isAnswered
        }
    }

    // Weighted percentage (0–100) across all questions.
    func calculateTotalScore(questions: [RubricQuestion], scores: [String: QuestionScore]) -> Int {
        var weightedSum = 0.0
        var maxPossible = 0.0

        for q in questions {
            maxPossible += Double(q.maxScore) * q.weight
            if let s = scores[q.id], s.isAnswered {
                weightedSum += Double(s.score) * q.weight
            }
        }

        guard maxPossible > 0 else { return 0 }
        return Int((weightedSum / maxPossible) * 100)
    }
}
