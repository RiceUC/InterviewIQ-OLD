import SwiftUI

// Unified home screen (AGENTS.md Q1-B). Shows sessions the user owns and
// sessions they have been assigned to as a panelist. Both roles are accessible
// from the same screen; ownership is session-scoped, not a global role.
struct SessionDashboardView: View {
    @Bindable var viewModel: SessionDashboardVM
    @State private var showingProfile = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.ownedSessions.isEmpty && viewModel.assignedSessions.isEmpty {
                    ProgressView("Loading sessions…")
                } else if viewModel.ownedSessions.isEmpty && viewModel.assignedSessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { viewModel.showCreateSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingProfile = true } label: {
                        Image(systemName: "person.crop.circle")
                    }
                }
            }
            // Profile sheet
            .sheet(isPresented: $showingProfile) {
                ProfileView(userId: viewModel.userId)
            }
            // Create session sheet
            .sheet(isPresented: $viewModel.showCreateSheet) {
                CreateEditSessionView(
                    viewModel: CreateEditSessionVM(adminId: viewModel.userId)
                )
                .onDisappear { Task { await viewModel.loadSessions() } }
            }
            // Edit session sheet
            .sheet(item: $viewModel.sessionToEdit) { session in
                CreateEditSessionView(
                    viewModel: CreateEditSessionVM(adminId: viewModel.userId, existingSession: session)
                )
                .onDisappear { Task { await viewModel.loadSessions() } }
            }
            // Per-session team management sheet
            .sheet(item: $viewModel.sessionForTeam) { session in
                UserManagementView(
                    viewModel: UserManagementVM(session: session, currentUserId: viewModel.userId)
                )
            }
            // Per-session rubric editing sheet
            .sheet(item: $viewModel.sessionForRubric) { session in
                CreateEditRubricView(
                    viewModel: CreateEditRubricVM(session: session)
                )
                .onDisappear { Task { await viewModel.loadSessions() } }
            }
            // Delete confirmation
            .confirmationDialog("Delete Session?", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task { await viewModel.confirmDelete() }
                }
                Button("Cancel", role: .cancel) { viewModel.cancelDelete() }
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

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView(
            "No Sessions",
            systemImage: "calendar.badge.plus",
            description: Text("Tap + to create your first interview session, or wait to be assigned as a panelist.")
        )
    }

    // MARK: - Session list

    private var sessionList: some View {
        List {
            if !viewModel.ownedSessions.isEmpty {
                Section("My Sessions") {
                    ForEach(viewModel.ownedSessions) { session in
                        OwnedSessionRow(
                            session: session,
                            ownerId:      viewModel.userId,
                            onEdit:       { viewModel.sessionToEdit    = session },
                            onManageTeam: { viewModel.sessionForTeam   = session },
                            onEditRubric: { viewModel.sessionForRubric = session },
                            onDelete:     { viewModel.requestDelete(session) }
                        )
                    }
                }
            }

            if !viewModel.assignedSessions.isEmpty {
                Section("Assigned to Me") {
                    ForEach(viewModel.assignedSessions) { session in
                        AssignedSessionRow(session: session, interviewerId: viewModel.userId)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.loadSessions() }
    }
}

// MARK: - Owned session row

// Full action surface for a session the current user created.
// Primary tap → Dashboard. Context menu exposes Rate, Edit, Manage Team, Edit Rubric, Delete.
private struct OwnedSessionRow: View {
    let session: Session
    let ownerId: String
    let onEdit: () -> Void
    let onManageTeam: () -> Void
    let onEditRubric: () -> Void
    let onDelete: () -> Void

    var body: some View {
        NavigationLink {
            DashboardComparisonView(sessionId: session.id, sessionTitle: session.title)
        } label: {
            rowContent
        }
        .foregroundStyle(.primary)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.orange)
        }
        .contextMenu {
            NavigationLink {
                LiveRatingScreen(sessionId: session.id, interviewerId: ownerId)
            } label: {
                Label("Rate Candidates", systemImage: "checklist")
            }
            Button(action: onManageTeam) {
                Label("Manage Team", systemImage: "person.2.badge.gearshape")
            }
            Button(action: onEditRubric) {
                Label("Edit Rubric", systemImage: "list.bullet.clipboard")
            }
            Divider()
            Button(action: onEdit) {
                Label("Edit Session", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var rowContent: some View {
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
                Text(session.title).font(.headline)
                Text(session.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label("Owner", systemImage: "crown.fill")
                .font(.caption2)
                .foregroundStyle(Color.brandPurple.opacity(0.8))
                .labelStyle(.iconOnly)
                .padding(6)
                .background(Color.brandPurple.opacity(0.1))
                .clipShape(Circle())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Assigned session row

// Panelist view: primary tap → rating screen, chart button → dashboard.
private struct AssignedSessionRow: View {
    let session: Session
    let interviewerId: String

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink {
                LiveRatingScreen(sessionId: session.id, interviewerId: interviewerId)
            } label: {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "checklist")
                                .font(.headline)
                                .foregroundStyle(Color.green)
                        }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.title).font(.headline)
                        Text(session.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .foregroundStyle(.primary)

            Spacer(minLength: 0)

            NavigationLink {
                DashboardComparisonView(sessionId: session.id, sessionTitle: session.title)
            } label: {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(Color.brandPurple)
                    .padding(8)
                    .background(Color.brandPurple.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}
