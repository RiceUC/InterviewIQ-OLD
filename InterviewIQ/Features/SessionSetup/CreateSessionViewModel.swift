import Foundation

@Observable
final class SessionDashboardViewModel {
    let adminId: String

    var sessions: [Session] = []
    var isLoading: Bool = false
    var errorMessage: String = ""
    var showError: Bool = false

    var showDeleteConfirmation: Bool = false
    var sessionToDelete: Session?

    var showCreateSheet: Bool = false
    var sessionToEdit: Session?

    private let service: SessionManagementService

    init(adminId: String, service: SessionManagementService = SessionManagementService()) {
        self.adminId = adminId
        self.service = service
    }

    func loadSessions() async {
        isLoading = true
        defer { isLoading = false }
        do {
            sessions = try await service.loadSessions(adminId: adminId)
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
            try await service.deleteSession(sessionId: session.id, actorId: adminId)
            sessions.removeAll { $0.id == session.id }
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
