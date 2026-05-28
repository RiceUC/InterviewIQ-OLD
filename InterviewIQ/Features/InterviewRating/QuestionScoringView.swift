import SwiftUI

// Single-question scoring card shown during UC-04 rating.
struct QuestionScoringView: View {
    let question: RubricQuestion
    let questionNumber: Int
    let totalQuestions: Int
    @Binding var score: Int
    @Binding var notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            questionHeader
            scorePicker
            notesField
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Question header

    private var questionHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Q\(questionNumber) of \(totalQuestions)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())

                Spacer()

                Text("Max \(question.maxScore) pts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(question.prompt)
                .font(.title3)
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Score input (number buttons for quick "one-click" scoring)

    private var scorePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Score")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if score > 0 {
                    Text("\(score) / \(question.maxScore)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.accentColor)
                } else {
                    Text("Not scored")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ScoreButtonRow(score: $score, maxScore: question.maxScore)
        }
    }

    // MARK: - Notes

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes (optional)")
                .font(.subheadline)
                .fontWeight(.medium)

            TextField("Add a comment about this answer…", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .padding(12)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Score button row

// One-click score buttons (1…maxScore). Scrollable when maxScore > 7.
struct ScoreButtonRow: View {
    @Binding var score: Int
    let maxScore: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(1...maxScore, id: \.self) { value in
                    Button {
                        score = value
                    } label: {
                        Text("\(value)")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .frame(width: 44, height: 44)
                            .background(score == value ? Color.accentColor : Color(.tertiarySystemFill))
                            .foregroundStyle(score == value ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .animation(.easeInOut(duration: 0.15), value: score)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
