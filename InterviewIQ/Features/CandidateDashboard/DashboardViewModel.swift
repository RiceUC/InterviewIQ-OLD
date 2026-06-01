//
//  DashboardViewModel.swift
//  InterviewIQ
//
//  Created by Clarice Harijanto
//

import Foundation

// DashboardViewModel (C-10): drives DashboardView for UC-05.
// Fetches ranked candidates from CandidateRankingService and exposes
// export helpers consumed by the export sheet.
@Observable
final class DashboardViewModel {

    // MARK: - Input (set by parent before task runs)
    var sessionId: String = ""
    var sessionTitle: String = ""

    // MARK: - State
    var rankedCandidates: [RankedCandidate] = []
    var rubricQuestions: [RubricQuestion] = []
    var isLoading: Bool = false
    var errorMessage: String = ""
    var showError: Bool = false

    // Export sheet
    var showExportSheet: Bool = false
    var isExporting: Bool = false
    var exportErrorMessage: String = ""
    var showExportError: Bool = false

    // MARK: - Services
    private let rankingService = CandidateRankingService()
    private let exportService = ReportExportService()

    // MARK: - Data Loading

    func loadDashboard() async {
        guard !sessionId.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            rankedCandidates = try await rankingService.fetchRankedCandidates(sessionId: sessionId)
        } catch {
            displayError("Failed to load dashboard: \(error.localizedDescription)")
        }
    }

    // MARK: - Export

    func exportCSV() async -> URL? {
        isExporting = true
        defer { isExporting = false }
        do {
            let url = try exportService.generateCSV(
                sessionTitle: sessionTitle,
                candidates: rankedCandidates
            )
            return url
        } catch {
            exportErrorMessage = "CSV export failed: \(error.localizedDescription)"
            showExportError = true
            return nil
        }
    }

    func exportPDF() async -> URL? {
        isExporting = true
        defer { isExporting = false }
        do {
            let url = try exportService.generatePDF(
                sessionTitle: sessionTitle,
                sessionId: sessionId,
                candidates: rankedCandidates
            )
            return url
        } catch {
            exportErrorMessage = "PDF export failed: \(error.localizedDescription)"
            showExportError = true
            return nil
        }
    }

    // MARK: - Computed Helpers

    var hasData: Bool { !rankedCandidates.isEmpty }

    var topCandidate: RankedCandidate? { rankedCandidates.first }

    var averageScore: Int {
        guard !rankedCandidates.isEmpty else { return 0 }
        let total = rankedCandidates.reduce(0) { $0 + $1.totalScore }
        return total / rankedCandidates.count
    }

    // MARK: - Private

    private func displayError(_ message: String) {
        errorMessage = message
        showError = true
    }
}
