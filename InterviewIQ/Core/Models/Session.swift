import Foundation

// Top-level interview session created by an Admin.
// Firestore path: sessions/{sessionId}
struct Session: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var date: Date
    var adminId: String
    var interviewerIds: [String]

    init(
        id: String = UUID().uuidString,
        title: String,
        date: Date,
        adminId: String,
        interviewerIds: [String] = []
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.adminId = adminId
        self.interviewerIds = interviewerIds
    }
}
