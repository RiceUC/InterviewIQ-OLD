import SwiftUI

struct SessionDashboardView: View {
    @Bindable var viewModel: SessionDashboardViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Loading sessions…")
                } else if viewModel.sessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions",
                        systemImage: "calendar.badge.plus",
                        description: Text("Tap + to create your first interview session.")
                    )
                } else {
                    sessionList
                }
            }
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showCreateSheet) {
                CreateEditSessionView(
                    viewModel: CreateEditSessionViewModel(adminId: viewModel.adminId)
                )
                .onDisappear {
                    Task { await viewModel.loadSessions() }
                }
            }
            .sheet(item: $viewModel.sessionToEdit) { session in
                CreateEditSessionView(
                    viewModel: CreateEditSessionViewModel(
                        adminId: viewModel.adminId,
                        existingSession: session
                    )
                )
                .onDisappear {
                    Task { await viewModel.loadSessions() }
                }
            }
            .confirmationDialog(
                "Delete Session?",
                isPresented: $viewModel.showDeleteConfirmation
            ) {
                Button("Delete", role: .destructive) {
                    Task { await viewModel.confirmDelete() }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.cancelDelete()
                }
            } message: {
                if let title = viewModel.sessionToDelete?.title {
                    Text("\"\(title)\" will be permanently removed.")
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
        .task { await viewModel.loadSessions() }
    }

    // MARK: - Session list

    private var sessionList: some View {
        List(viewModel.sessions) { session in
            SessionRowView(session: session)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.requestDelete(session)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        viewModel.sessionToEdit = session
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.loadSessions()
        }
    }
}

// MARK: - Session row

private struct SessionRowView: View {
    let session: Session

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "calendar")
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

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
