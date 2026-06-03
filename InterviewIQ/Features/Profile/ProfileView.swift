import SwiftUI
import FirebaseAuth

// Account screen shown from either home (admin or interviewer). Displays the
// signed-in user's profile and provides Log Out. Fetches its own profile by uid
// so it stays decoupled from the home screens that present it.
struct ProfileView: View {
    let userId: String

    @State private var profile: UserProfile?
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    private let repo = UserRepository()

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else if let profile {
                        LabeledContent("Name", value: profile.fullName)
                        LabeledContent("Email", value: profile.emailAddress)
                    } else {
                        Text("Couldn't load your profile.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        logout()
                    } label: {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            profile = try? await repo.fetchProfile(userId: userId)
            isLoading = false
        }
    }

    private func logout() {
        // Signing out flips Firebase's auth state; AppAuthState's listener then
        // routes the whole app back to LoginView, tearing down this sheet.
        try? Auth.auth().signOut()
    }
}
