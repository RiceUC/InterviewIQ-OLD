import Foundation
import SwiftUI

// Stable identity wrapper so ForEach doesn't lose focus when two names are equal.
struct CandidateEntry: Identifiable {
    let id: UUID = UUID()
    var name: String
}

// Editable rubric question row (UC-03). Keeps the question's stable id so edits
// to an existing question update in place rather than create a duplicate.
struct RubricQuestionEntry: Identifiable {
    let id: String
    var prompt: String
    var maxScore: Int

    init(id: String = UUID().uuidString, prompt: String = "", maxScore: Int = 10) {
        self.id = id
        self.prompt = prompt
        self.maxScore = maxScore
    }
}

@Observable
final class CreateEditSessionViewModel {
    let adminId: String
    let existingSession: Session?

    var existingCandidates: [Candidate] = []
    var existingQuestions: [RubricQuestion] = []

    var title: String = ""
    var date: Date = Date()
    var candidateEntries: [CandidateEntry] = [CandidateEntry(name: "")]
    var questionEntries: [RubricQuestionEntry] = [RubricQuestionEntry()]

    var isLoading: Bool = false
    var isSaving: Bool = false
    var errorMessage: String = ""
    var showError: Bool = false
    var didSave: Bool = false

    var isEditMode: Bool { existingSession != nil }

    private let service: SessionManagementService
    private let candidateRepo: CandidateRepository
    private let rubricRepo: RubricRepository

    init(
        adminId: String,
        existingSession: Session? = nil,
        service: SessionManagementService = SessionManagementService(),
        candidateRepo: CandidateRepository = CandidateRepository(),
        rubricRepo: RubricRepository = RubricRepository()
    ) {
        self.adminId = adminId
        self.existingSession = existingSession
        self.service = service
        self.candidateRepo = candidateRepo
        self.rubricRepo = rubricRepo
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

            existingQuestions = try await rubricRepo.fetchQuestions(sessionId: session.id)
            questionEntries = existingQuestions.isEmpty
                ? [RubricQuestionEntry()]
                : existingQuestions.map {
                    RubricQuestionEntry(id: $0.id, prompt: $0.prompt, maxScore: $0.maxScore)
                }
        } catch {
            displayError("Failed to load session details: \(error.localizedDescription)")
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

    func addQuestionRow() {
        questionEntries.append(RubricQuestionEntry())
    }

    func removeQuestion(at offsets: IndexSet) {
        questionEntries.remove(atOffsets: offsets)
        if questionEntries.isEmpty {
            questionEntries.append(RubricQuestionEntry())
        }
    }

    // Builds domain RubricQuestions from the editable rows, dropping blank
    // prompts and assigning display order from position.
    private func buildQuestions() -> [RubricQuestion] {
        questionEntries
            .filter { !$0.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .enumerated()
            .map { index, entry in
                RubricQuestion(
                    id: entry.id,
                    prompt: entry.prompt.trimmingCharacters(in: .whitespacesAndNewlines),
                    maxScore: entry.maxScore,
                    weight: 1.0,
                    order: index,
                    isRequired: true
                )
            }
    }

    func save() async {
        isSaving = true
        defer { isSaving = false }

        let names = candidateEntries.map { $0.name }
        let questions = buildQuestions()

        do {
            if let session = existingSession {
                var updated = session
                updated.title = title
                updated.date = date
                try await service.updateSession(
                    session: updated,
                    candidateNames: names,
                    existingCandidates: existingCandidates,
                    questions: questions,
                    existingQuestions: existingQuestions
                )
            } else {
                try await service.createSession(
                    title: title,
                    date: date,
                    adminId: adminId,
                    candidateNames: names,
                    questions: questions
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
