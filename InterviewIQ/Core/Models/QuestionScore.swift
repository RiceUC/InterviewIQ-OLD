import Foundation

// Score and optional notes for one rubric question during an interview.
struct QuestionScore: Identifiable, Codable, Hashable {
    let id: String
    let questionId: String
    var score: Int        // 1...maxScore; 0 means not yet answered
    var notes: String

    init(
        id: String = UUID().uuidString,
        questionId: String,
        score: Int = 0,
        notes: String = ""
    ) {
        self.id = id
        self.questionId = questionId
        self.score = score
        self.notes = notes
    }

    var isAnswered: Bool { score > 0 }
}
