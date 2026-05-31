import Foundation

struct Candidate: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var sessionId: String

    init(id: String = UUID().uuidString, name: String, sessionId: String) {
        self.id = id
        self.name = name
        self.sessionId = sessionId
    }
}
