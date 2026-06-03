import Foundation

@Observable
final class SessionDashboardVM {
    let userId: String

    // Sessions this user created (owner view).
    var ownedSessions: [Session] = []
    // Sessions this user is assigned to as a panelist.
    var assignedSessions: [Session] = []

    var isLoading: Bool = false
    var errorMessage: String = ""
    var showError: Bool = false

    // Create / edit sheet
    var showCreateSheet: Bool = false
    var sessionToEdit: Session?

    // Delete confirmation
    var showDeleteConfirmation: Bool = false
    var sessionToDelete: Session?

    // Per-session team management sheet
    var sessionForTeam: Session?

    // Per-session rubric editing sheet
    var sessionForRubric: Session?

    private let service: SessionManagementService
    private let repo: SessionRepository

    init(
        userId: String,
        service: SessionManagementService = SessionManagementService(),
        repo: SessionRepository = SessionRepository()
    ) {
        self.userId = userId
        self.service = service
        self.repo = repo
    }

    func loadSessions() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let owned    = service.loadSessions(adminId: userId)
            async let assigned = repo.fetchAssignedSessions(interviewerId: userId)
            (ownedSessions, assignedSessions) = try await (owned, assigned)
        } catch {
            displayError("Failed to load sessions: \(error.localizedDescription)")
        }
    }

    func requestDelete(_ session: Session) {
        sessionToDelete = session
        showDeleteConfirmation = true
    }

    func confirmDelete() async {
        guard let session = sessionToDelete else { return }
        do {
            try await service.deleteSession(sessionId: session.id, actorId: userId)
            ownedSessions.removeAll { $0.id == session.id }
        } catch {
            displayError("Failed to delete session: \(error.localizedDescription)")
        }
        sessionToDelete = nil
    }

    func cancelDelete() {
        sessionToDelete = nil
        showDeleteConfirmation = false
    }

    private func displayError(_ message: String) {
        errorMessage = message
        showError = true
    }
}
