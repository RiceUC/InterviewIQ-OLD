import Foundation

// Individual evaluation criterion within a session's rubric.
// Firestore path: sessions/{sessionId}/rubricQuestions/{id}
struct RubricQuestion: Identifiable, Codable, Hashable {
    let id: String
    var prompt: String
    var maxScore: Int
    var weight: Double
    var order: Int
    var isRequired: Bool

    init(
        id: String = UUID().uuidString,
        prompt: String,
        maxScore: Int,
        weight: Double = 1.0,
        order: Int = 0,
        isRequired: Bool = true
    ) {
        self.id = id
        self.prompt = prompt
        self.maxScore = maxScore
        self.weight = weight
        self.order = order
        self.isRequired = isRequired
    }
}
