import Foundation
import FirebaseDatabase

final class SessionRepository {
    private let db = Database.database().reference()

    func fetchSessions(adminId: String) async throws -> [Session] {
        let snapshot = try await db.child("sessions").getData()

        guard let dict = snapshot.value as? [String: Any] else { return [] }

        return dict.values.compactMap { value in
            guard let entry = value as? [String: Any],
                  let id = entry["id"] as? String,
                  let title = entry["title"] as? String,
                  let dateTimestamp = entry["date"] as? TimeInterval,
                  let entryAdminId = entry["adminId"] as? String,
                  entryAdminId == adminId
            else { return nil }

            let date = Date(timeIntervalSince1970: dateTimestamp)
            let interviewerIds = entry["interviewerIds"] as? [String] ?? []
            return Session(id: id, title: title, date: date, adminId: entryAdminId, interviewerIds: interviewerIds)
        }
    }

    // Sessions an interviewer is assigned to (interviewerIds contains their uid).
    // Mirrors fetchSessions(adminId:) but filters on assignment instead of ownership.
    func fetchAssignedSessions(interviewerId: String) async throws -> [Session] {
        let snapshot = try await db.child("sessions").getData()

        guard let dict = snapshot.value as? [String: Any] else { return [] }

        return dict.values.compactMap { value in
            guard let entry = value as? [String: Any],
                  let id = entry["id"] as? String,
                  let title = entry["title"] as? String,
                  let dateTimestamp = entry["date"] as? TimeInterval,
                  let entryAdminId = entry["adminId"] as? String,
                  let interviewerIds = entry["interviewerIds"] as? [String],
                  interviewerIds.contains(interviewerId)
            else { return nil }

            let date = Date(timeIntervalSince1970: dateTimestamp)
            return Session(id: id, title: title, date: date, adminId: entryAdminId, interviewerIds: interviewerIds)
        }
    }

    func saveSession(_ session: Session) async throws {
        let data = encodeSession(session)
        try await db.child("sessions").child(session.id).setValue(data)
    }

    func updateSession(_ session: Session) async throws {
        let data = encodeSession(session)
        try await db.child("sessions").child(session.id).setValue(data)
    }

    func deleteSession(sessionId: String) async throws {
        try await db.child("sessions").child(sessionId).removeValue()
    }

    func saveCandidate(_ candidate: Candidate, sessionId: String) async throws {
        let data: [String: Any] = [
            "id": candidate.id,
            "name": candidate.name,
            "sessionId": candidate.sessionId
        ]
        try await db
            .child("sessions").child(sessionId)
            .child("candidates").child(candidate.id)
            .setValue(data)
    }

    func deleteCandidate(candidateId: String, sessionId: String) async throws {
        try await db
            .child("sessions").child(sessionId)
            .child("candidates").child(candidateId)
            .removeValue()
    }

    // MARK: - Private

    private func encodeSession(_ session: Session) -> [String: Any] {
        return [
            "id": session.id,
            "title": session.title,
            "date": session.date.timeIntervalSince1970,
            "adminId": session.adminId,
            "interviewerIds": session.interviewerIds
        ]
    }
}
