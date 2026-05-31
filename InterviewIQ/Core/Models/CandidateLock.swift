import Foundation

// Enforces the 1:1 rule: only one interviewer may rate a candidate at a time.
// Firestore path: sessions/{sessionId}/candidateLocks/{candidateId}
struct CandidateLock: Codable {
    let candidateId: String
    let interviewerId: String
    let sessionId: String
    let lockedAt: Date
    let expiresAt: Date
    var isLocked: Bool
}
