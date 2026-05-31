import Foundation
import FirebaseFirestore

final class SessionRepository {
    private let db = Firestore.firestore()

    func fetchSessions(adminId: String) async throws -> [Session] {
        let snapshot = try await db
            .collection("sessions")
            .whereField("adminId", isEqualTo: adminId)
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: Session.self) }
    }

    func saveSession(_ session: Session) async throws {
        let data = try Firestore.Encoder().encode(session)
        try await db.collection("sessions").document(session.id).setData(data)
    }

    func updateSession(_ session: Session) async throws {
        let data = try Firestore.Encoder().encode(session)
        try await db.collection("sessions").document(session.id).setData(data)
    }

    func deleteSession(sessionId: String) async throws {
        try await db.collection("sessions").document(sessionId).delete()
    }

    func saveCandidate(_ candidate: Candidate, sessionId: String) async throws {
        let data = try Firestore.Encoder().encode(candidate)
        try await db
            .collection("sessions").document(sessionId)
            .collection("candidates").document(candidate.id)
            .setData(data)
    }

    func deleteCandidate(candidateId: String, sessionId: String) async throws {
        try await db
            .collection("sessions").document(sessionId)
            .collection("candidates").document(candidateId)
            .delete()
    }
}
