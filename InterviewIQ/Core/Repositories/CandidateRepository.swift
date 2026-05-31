import Foundation
import FirebaseFirestore

// Reads candidate records for a given session from Firestore.
// Felix (Session Management) is responsible for writing candidates to
// sessions/{sessionId}/candidates/{candidateId} when creating a session.
final class CandidateRepository {
    private let db = Firestore.firestore()

    func fetchCandidates(sessionId: String) async throws -> [Candidate] {
        let snapshot = try await db
            .collection("sessions")
            .document(sessionId)
            .collection("candidates")
            .getDocuments()

        return try snapshot.documents.compactMap { doc in
            try doc.data(as: Candidate.self)
        }
    }
}
