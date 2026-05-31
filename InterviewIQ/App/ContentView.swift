import SwiftUI
import FirebaseAuth

@Observable
private final class AppAuthState {
    var isLoggedIn: Bool
    var currentUserId: String

    private var listenerHandle: AuthStateDidChangeListenerHandle?

    init() {
        let currentUser = Auth.auth().currentUser
        isLoggedIn = currentUser != nil
        currentUserId = currentUser?.uid ?? ""

        listenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.isLoggedIn = user != nil
                self?.currentUserId = user?.uid ?? ""
            }
        }
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
        if authState.isLoggedIn {
            SessionDashboardView(
                viewModel: SessionDashboardViewModel(adminId: authState.currentUserId)
            )
        } else {
            NavigationView {
                LoginView()
            }
        }
    }
}
