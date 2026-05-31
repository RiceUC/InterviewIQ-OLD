import Foundation

// Consolidated evaluation outcome for one candidate in a session.
// Firestore path: sessions/{sessionId}/scoreRecords/{candidateId}
struct ScoreRecord: Identifiable, Codable {
    let id: String
    let candidateId: String
    let interviewerId: String
    let sessionId: String
    var questionScores: [QuestionScore]
    var totalScore: Int          // 0–100 weighted percentage
    var notes: String
    var status: String           // "in_progress" | "submitted"
    var syncStatus: SyncStatus
    var isImmutable: Bool
    var submittedAt: Date?
    var lockedAt: Date?          // when the record became final

    init(
        id: String = UUID().uuidString,
        candidateId: String,
        interviewerId: String,
        sessionId: String
    ) {
        self.id = id
        self.candidateId = candidateId
        self.interviewerId = interviewerId
        self.sessionId = sessionId
        self.questionScores = []
        self.totalScore = 0
        self.notes = ""
        self.status = "in_progress"
        self.syncStatus = .pending
        self.isImmutable = false
    }
}
