import Foundation
import SwiftUI

// MARK: - ViewModel

// Admin-only user management (FR-10): list users, change roles, activate/
// deactivate. Maps to UserManagementVM (C-32). Role/active mutations are audited.
@Observable
final class UserManagementVM {
    let adminId: String

    var users: [UserProfile] = []
    var isLoading: Bool = false
    var errorMessage: String = ""
    var showError: Bool = false

    private let repo: UserRepository
    private let auditLogger: AuditLogger

    init(
        adminId: String,
        repo: UserRepository = UserRepository(),
        auditLogger: AuditLogger = AuditLogger()
    ) {
        self.adminId = adminId
        self.repo = repo
        self.auditLogger = auditLogger
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            users = try await repo.fetchAllUsers()
        } catch {
            displayError("Failed to load users: \(error.localizedDescription)")
        }
    }

    // An admin can't change their own role or deactivate themselves — prevents
    // accidentally locking the last admin out of the system.
    func canModify(_ user: UserProfile) -> Bool {
        user.userId != adminId
    }

    func setRole(_ user: UserProfile, to role: UserRole) async {
        guard canModify(user), user.role != role else { return }
        do {
            try await repo.updateRole(userId: user.userId, role: role)
            await auditLogger.log(
                .roleChanged,
                actorId: adminId,
                actorRole: UserRole.admin.rawValue,
                targetType: "user",
                targetId: user.userId,
                details: "\(user.role.rawValue) -> \(role.rawValue)"
            )
            await load()
        } catch {
            displayError("Failed to update role: \(error.localizedDescription)")
        }
    }

    func setActive(_ user: UserProfile, isActive: Bool) async {
        guard canModify(user), user.isActive != isActive else { return }
        do {
            try await repo.setActive(userId: user.userId, isActive: isActive)
            await auditLogger.log(
                isActive ? .userActivated : .userDeactivated,
                actorId: adminId,
                actorRole: UserRole.admin.rawValue,
                targetType: "user",
                targetId: user.userId,
                details: user.emailAddress
            )
            await load()
        } catch {
            displayError("Failed to update status: \(error.localizedDescription)")
        }
    }

    private func displayError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - View

struct UserManagementView: View {
    @State var viewModel: UserManagementVM

    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.users.isEmpty {
                ProgressView("Loading users…")
            } else if viewModel.users.isEmpty {
                ContentUnavailableView(
                    "No Users",
                    systemImage: "person.2.slash",
                    description: Text("No registered accounts found.")
                )
            } else {
                userList
            }
        }
        .navigationTitle("User Management")
        .navigationBarTitleDisplayMode(.large)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .task { await viewModel.load() }
    }

    private var userList: some View {
        List(viewModel.users, id: \.userId) { user in
            UserRow(
                user: user,
                isSelf: user.userId == viewModel.adminId,
                onSetRole: { role in Task { await viewModel.setRole(user, to: role) } },
                onSetActive: { active in Task { await viewModel.setActive(user, isActive: active) } }
            )
        }
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.load() }
    }
}

// MARK: - Row

private struct UserRow: View {
    let user: UserProfile
    let isSelf: Bool
    let onSetRole: (UserRole) -> Void
    let onSetActive: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(user.fullName).font(.headline)
                    if isSelf {
                        Text("You")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(user.emailAddress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    badge(user.role.displayName, color: user.role == .admin ? .purple : .blue)
                    if !user.isActive {
                        badge("Inactive", color: .red)
                    }
                }
            }

            Spacer()

            if !isSelf {
                Menu {
                    Picker("Role", selection: Binding(
                        get: { user.role },
                        set: { onSetRole($0) }
                    )) {
                        ForEach(UserRole.allCases) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                    Divider()
                    if user.isActive {
                        Button(role: .destructive) { onSetActive(false) } label: {
                            Label("Deactivate", systemImage: "person.crop.circle.badge.xmark")
                        }
                    } else {
                        Button { onSetActive(true) } label: {
                            Label("Activate", systemImage: "person.crop.circle.badge.checkmark")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
