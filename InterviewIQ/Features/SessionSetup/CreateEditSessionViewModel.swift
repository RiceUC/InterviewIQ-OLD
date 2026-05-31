import Foundation
import SwiftUI

// Stable identity wrapper so ForEach doesn't lose focus when two names are equal.
struct CandidateEntry: Identifiable {
    let id: UUID = UUID()
    var name: String
}

@Observable
final class CreateEditSessionViewModel {
    let adminId: String
    let existingSession: Session?

    var existingCandidates: [Candidate] = []

    var title: String = ""
    var date: Date = Date()
    var candidateEntries: [CandidateEntry] = [CandidateEntry(name: "")]

    var isLoading: Bool = false
    var isSaving: Bool = false
    var errorMessage: String = ""
    var showError: Bool = false
    var didSave: Bool = false

    var isEditMode: Bool { existingSession != nil }

    private let service: SessionManagementService
    private let candidateRepo: CandidateRepository

    init(
        adminId: String,
        existingSession: Session? = nil,
        service: SessionManagementService = SessionManagementService(),
        candidateRepo: CandidateRepository = CandidateRepository()
    ) {
        self.adminId = adminId
        self.existingSession = existingSession
        self.service = service
        self.candidateRepo = candidateRepo
    }

    func onAppear() async {
        guard let session = existingSession else { return }
        isLoading = true
        defer { isLoading = false }

        title = session.title
        date = session.date

        do {
            existingCandidates = try await candidateRepo.fetchCandidates(sessionId: session.id)
            let names = existingCandidates.map { $0.name }
            candidateEntries = names.isEmpty
                ? [CandidateEntry(name: "")]
                : names.map { CandidateEntry(name: $0) }
        } catch {
            displayError("Failed to load candidates: \(error.localizedDescription)")
        }
    }

    func addCandidateRow() {
        candidateEntries.append(CandidateEntry(name: ""))
    }

    func removeCandidate(at offsets: IndexSet) {
        candidateEntries.remove(atOffsets: offsets)
        if candidateEntries.isEmpty {
            candidateEntries.append(CandidateEntry(name: ""))
        }
    }

    func save() async {
        isSaving = true
        defer { isSaving = false }

        let names = candidateEntries.map { $0.name }

        do {
            if let session = existingSession {
                var updated = session
                updated.title = title
                updated.date = date
                try await service.updateSession(
                    session: updated,
                    candidateNames: names,
                    existingCandidates: existingCandidates
                )
            } else {
                try await service.createSession(
                    title: title,
                    date: date,
                    adminId: adminId,
                    candidateNames: names
                )
            }
            didSave = true
        } catch {
            displayError(error.localizedDescription)
        }
    }

    private func displayError(_ message: String) {
        errorMessage = message
        showError = true
    }
}
