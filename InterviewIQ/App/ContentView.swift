import SwiftUI
import FirebaseAuth

@Observable
private final class AppAuthState {
    var isLoggedIn: Bool
    var currentUserId: String

    // Profile drives RBAC routing. nil while loading or if the lookup failed.
    var profile: UserProfile?
    var isLoadingProfile: Bool = false
    var profileLoadFailed: Bool = false

    private let userRepository = UserRepository()
    private var listenerHandle: AuthStateDidChangeListenerHandle?

    init() {
        let currentUser = Auth.auth().currentUser
        isLoggedIn = currentUser != nil
        currentUserId = currentUser?.uid ?? ""

        listenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoggedIn = user != nil
                self.currentUserId = user?.uid ?? ""
                if let uid = user?.uid {
                    Task { await self.loadProfile(uid: uid) }
                } else {
                    self.profile = nil
                    self.profileLoadFailed = false
                }
            }
        }

        if let uid = currentUser?.uid {
            Task { await loadProfile(uid: uid) }
        }
    }

    @MainActor
    func loadProfile(uid: String) async {
        isLoadingProfile = true
        profileLoadFailed = false
        defer { isLoadingProfile = false }
        do {
            profile = try await userRepository.fetchProfile(userId: uid)
            // A logged-in user with no profile record is treated as a failure so
            // we don't silently grant a default role to an unknown account.
            profileLoadFailed = (profile == nil)
        } catch {
            profile = nil
            profileLoadFailed = true
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
    }

    deinit {
        if let handle = listenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}

struct ContentView: View {
    @State private var authState = AppAuthState()

    var body: some View {
        if !authState.isLoggedIn {
            NavigationView {
                LoginView()
            }
        } else if authState.isLoadingProfile {
            ProgressView("Loading your account…")
        } else if let profile = authState.profile, profile.isActive {
            roleHome(for: profile)
        } else if authState.profile?.isActive == false {
            accountIssue(
                title: "Account Deactivated",
                message: "Your account has been deactivated. Please contact your administrator."
            )
        } else {
            // profileLoadFailed or nil profile
            accountIssue(
                title: "Couldn't Load Account",
                message: "We couldn't load your profile. Check your connection and try again."
            )
        }
    }

    // Routes to the correct home screen for the user's role (FR-02).
    @ViewBuilder
    private func roleHome(for profile: UserProfile) -> some View {
        switch profile.role {
        case .admin:
            SessionDashboardView(
                viewModel: SessionDashboardViewModel(adminId: profile.userId)
            )
        case .interviewer:
            InterviewerHomeView(
                viewModel: InterviewerHomeViewModel(interviewerId: profile.userId)
            )
        }
    }

    private func accountIssue(title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Sign Out") { authState.signOut() }
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }
}
