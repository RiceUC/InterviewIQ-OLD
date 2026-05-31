import Foundation
import FirebaseFirestore

// Handles local persistence (UserDefaults) and remote Firestore writes for ScoreRecords.
// Offline-first: scores are always saved locally before any network operation (NFR-07).
final class ScoreRepository {
    private let db = Firestore.firestore()
    private let localKey = "pending_score_records"

    // MARK: - Local (offline-first)

    func saveLocally(_ record: ScoreRecord) {
        var pending = loadAllPendingLocal()
        pending[record.candidateId] = record
        persist(pending)
    }

    func loadLocalScore(candidateId: String) -> ScoreRecord? {
        loadAllPendingLocal()[candidateId]
    }

    func loadAllPending() -> [ScoreRecord] {
        Array(loadAllPendingLocal().values)
    }

    func removeLocalRecord(candidateId: String) {
        var pending = loadAllPendingLocal()
        pending.removeValue(forKey: candidateId)
        persist(pending)
    }

    // MARK: - Remote (Firestore)

    func submit(_ record: ScoreRecord) async throws {
        let ref = db
            .collection("sessions")
            .document(record.sessionId)
            .collection("scoreRecords")
            .document(record.candidateId)
        // Firestore's Codable setData(from:) is synchronous; encode to [String:Any]
        // first so we can use the proper async setData overload.
        let data = try Firestore.Encoder().encode(record)
        try await ref.setData(data)
    }

    func markAsImmutable(candidateId: String, sessionId: String) async throws {
        let ref = db
            .collection("sessions")
            .document(sessionId)
            .collection("scoreRecords")
            .document(candidateId)
        try await ref.updateData([
            "isImmutable": true,
            "lockedAt": Timestamp(date: Date()),
            "status": "submitted"
        ])
    }

    func markAsSynced(candidateId: String, sessionId: String) async throws {
        let ref = db
            .collection("sessions")
            .document(sessionId)
            .collection("scoreRecords")
            .document(candidateId)
        try await ref.updateData(["syncStatus": SyncStatus.synced.rawValue])
    }

    // MARK: - Private

    private func loadAllPendingLocal() -> [String: ScoreRecord] {
        guard
            let data = UserDefaults.standard.data(forKey: localKey),
            let records = try? JSONDecoder().decode([String: ScoreRecord].self, from: data)
        else { return [:] }
        return records
    }

    private func persist(_ records: [String: ScoreRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: localKey)
        }
    }
}
