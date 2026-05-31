import SwiftUI

// Dev entry point on this branch.
// TODO (merge): replace with Cello's auth flow, which routes to the correct screen per role.
struct ContentView: View {
    // Mocked until Cello's auth branch is merged.
    private let mockAdminId = "dev-admin-001"

    var body: some View {
        SessionDashboardView(
            viewModel: SessionDashboardViewModel(adminId: mockAdminId)
        )
    }
}
