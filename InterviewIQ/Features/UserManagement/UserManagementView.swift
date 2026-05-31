import SwiftUI

struct UserManagementView: View {
    var body: some View {
        ContentUnavailableView(
            "User Management",
            systemImage: "person.2.badge.gearshape",
            description: Text("Interviewer assignment is coming in a future update.")
        )
        .navigationTitle("User Management")
        .navigationBarTitleDisplayMode(.large)
    }
}
