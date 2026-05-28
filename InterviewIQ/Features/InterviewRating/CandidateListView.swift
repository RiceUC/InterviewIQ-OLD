import SwiftUI

// Shows the interviewer's list of candidates for a session.
// Tapping "Start Interview" acquires a candidate lock and enters the rating phase.
struct CandidateListView: View {
    @Bindable var viewModel: InterviewRatingViewModel

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView("Loading candidates…")
            } else if viewModel.candidates.isEmpty {
                emptyState
            } else {
                candidateList
            }
        }
        .navigationTitle("Candidates")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                connectivityBadge
            }
        }
        .refreshable {
            await viewModel.loadCandidates()
        }
    }

    // MARK: - Candidate list

    private var candidateList: some View {
        List(viewModel.candidates) { candidate in
            CandidateRowView(
                candidate: candidate,
                status: viewModel.candidateStatus(for: candidate),
                isLoading: viewModel.isLoading
            ) {
                Task { await viewModel.startInterview(with: candidate) }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView(
            "No Candidates",
            systemImage: "person.3",
            description: Text("The session admin hasn't added any candidates yet.")
        )
    }

    // MARK: - Connectivity badge

    private var connectivityBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(viewModel.syncManager.isOnline ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(viewModel.syncManager.isOnline ? "Online" : "Offline")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Candidate row

private struct CandidateRowView: View {
    let candidate: Candidate
    let status: String
    let isLoading: Bool
    let onStart: () -> Void

    private var statusColor: Color {
        switch status {
        case "Completed": return .green
        case "In Progress": return .orange
        default: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(candidate.name.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(.accentColor)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.name)
                    .font(.headline)

                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }
            }

            Spacer()

            if status != "Completed" {
                Button(status == "In Progress" ? "Resume" : "Start") {
                    onStart()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isLoading)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            }
        }
        .padding(.vertical, 4)
    }
}
