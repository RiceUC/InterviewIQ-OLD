import SwiftUI

// Dev entry point on this branch.
// After branches are merged, the root view will be replaced by Cello's auth flow
// which then routes to the correct screen per role (Admin vs Interviewer).
struct ContentView: View {
    // TODO (merge): replace with AuthViewModel.currentUser from Cello's branch
    // For now, hard-code a mock session so the rating flow can be tested standalone.
    private let mockSessionId = "dev-session-001"
    private let mockInterviewerId = "dev-interviewer-001"

    var body: some View {
        InterviewRatingView(
            sessionId: mockSessionId,
            interviewerId: mockInterviewerId
        )
    }
}
