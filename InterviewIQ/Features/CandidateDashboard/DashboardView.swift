//
//  DashboardView.swift
//  InterviewIQ
//
//  Created by Clarice Harijanto on 01/06/26.
//

import SwiftUI

// DashboardView (C-09): UC-05 read-only ranked candidate dashboard for Admin.
// Triggered from the SessionDashboard when an Admin taps "View Dashboard" on a session row.
struct DashboardView: View {
    let sessionId: String
    let sessionTitle: String

    @State private var viewModel = DashboardViewModel()

    // Export state
    @State private var exportedURL: URL?
    @State private var showShareSheet: Bool = false
    @State private var showExportFormatSheet: Bool = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading rankings…")
            } else if !viewModel.hasData {
                emptyState
            } else {
                dashboardContent
            }
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showExportFormatSheet = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(!viewModel.hasData || viewModel.isExporting)
            }
        }
        // Format picker
        .confirmationDialog("Export Report", isPresented: $showExportFormatSheet, titleVisibility: .visible) {
            Button("Export as PDF") {
                Task { await handleExport(format: .pdf) }
            }
            Button("Export as CSV") {
                Task { await handleExport(format: .csv) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose a format for the \"\(sessionTitle)\" report.")
        }
        // Share sheet
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedURL {
                ShareSheet(url: url)
            }
        }
        // Error
        .alert("Export Failed", isPresented: $viewModel.showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.exportErrorMessage)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .task {
            viewModel.sessionId = sessionId
            viewModel.sessionTitle = sessionTitle
            await viewModel.loadDashboard()
        }
        .refreshable {
            await viewModel.loadDashboard()
        }
    }

    // MARK: - Dashboard Content

    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                summaryCard
                rankingList
            }
            .padding()
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(sessionTitle)
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                statCell(label: "Candidates", value: "\(viewModel.rankedCandidates.count)")
                Divider().frame(height: 36)
                statCell(label: "Avg Score", value: "\(viewModel.averageScore)%")
                Divider().frame(height: 36)
                statCell(label: "Top Score", value: "\(viewModel.topCandidate?.totalScore ?? 0)%")
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.brandPurple)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Ranking List

    private var rankingList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rankings")
                .font(.title3)
                .fontWeight(.semibold)

            ForEach(viewModel.rankedCandidates) { candidate in
                CandidateRankRow(candidate: candidate)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Results Yet",
            systemImage: "chart.bar.xaxis",
            description: Text("Rankings will appear here once interviewers have submitted scores.")
        )
    }

    // MARK: - Export Handler

    private enum ExportFormat { case pdf, csv }

    private func handleExport(format: ExportFormat) async {
        let url: URL?
        switch format {
        case .pdf: url = await viewModel.exportPDF()
        case .csv: url = await viewModel.exportCSV()
        }
        if let url {
            exportedURL = url
            showShareSheet = true
        }
    }
}

// MARK: - Candidate Rank Row

private struct CandidateRankRow: View {
    let candidate: RankedCandidate

    private var rankColor: Color {
        switch candidate.rank {
        case 1: return .yellow
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)    // silver
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)        // bronze
        default: return .secondary.opacity(0.4)
        }
    }

    private var scoreColor: Color {
        switch candidate.totalScore {
        case 80...100: return .green
        case 60..<80:  return .orange
        default:       return .red
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor.opacity(candidate.rank <= 3 ? 0.2 : 0.08))
                    .frame(width: 44, height: 44)
                Text("#\(candidate.rank)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(candidate.rank <= 3 ? rankColor : .secondary)
            }

            // Name + submitted timestamp
            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.name)
                    .font(.headline)

                if let submitted = candidate.submittedAt {
                    Text("Submitted \(submitted, style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Score gauge
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(candidate.totalScore)%")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(scoreColor)

                // Mini progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.15))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(scoreColor)
                            .frame(width: geo.size.width * CGFloat(candidate.totalScore) / 100)
                    }
                }
                .frame(width: 60, height: 6)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
