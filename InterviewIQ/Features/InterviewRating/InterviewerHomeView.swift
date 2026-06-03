import Foundation
import SwiftUI

// MARK: - ViewModel

// Loads the sessions an interviewer has been assigned to (UC-04 entry point).
@Observable
final class InterviewerHomeViewModel {
    let interviewerId: String

    var sessions: [Session] = []
    var isLoading: Bool = false
    var errorMessage: String = ""
    var showError: Bool = false

    private let repo: SessionRepository

    init(interviewerId: String, repo: SessionRepository = SessionRepository()) {
        self.interviewerId = interviewerId
        self.repo = repo
    }

    func loadSessions() async {
        isLoading = true
        defer { isLoading = false }
        do {
            sessions = try await repo.fetchAssignedSessions(interviewerId: interviewerId)
        } catch {
            errorMessage = "Failed to load your sessions: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - View

// Interviewer landing screen. Lists assigned sessions; tapping one opens the
// live rating flow (CandidateListView → rating) for that session.
struct InterviewerHomeView: View {
    @State var viewModel: InterviewerHomeViewModel
    @State private var showingProfile = false

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Loading your sessions…")
                } else if viewModel.sessions.isEmpty {
                    ContentUnavailableView(
                        "No Assigned Sessions",
                        systemImage: "person.crop.circle.badge.clock",
                        description: Text("An admin hasn't assigned you to any interview sessions yet.")
                    )
                } else {
                    sessionList
                }
            }
            .navigationTitle("My Interviews")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingProfile = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                }
            }
            .navigationDestination(for: Session.self) { session in
                InterviewRatingView(
                    sessionId: session.id,
                    interviewerId: viewModel.interviewerId
                )
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .sheet(isPresented: $showingProfile) {
                ProfileView(userId: viewModel.interviewerId)
            }
        }
        .task { await viewModel.loadSessions() }
    }

    private var sessionList: some View {
        List(viewModel.sessions) { session in
            NavigationLink(value: session) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "checklist")
                                .font(.headline)
                                .foregroundStyle(Color.accentColor)
                        }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.title)
                            .font(.headline)
                        Text(session.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.loadSessions()
        }
    }
}
