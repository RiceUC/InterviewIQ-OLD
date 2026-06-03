import SwiftUI

// Root view for UC-04. Routes between the candidate list and the active rating form.
struct LiveRatingScreen: View {
    let sessionId: String
    let interviewerId: String

    @State private var viewModel = LiveRatingVM()

    var body: some View {
        // No NavigationStack here: this view is always pushed inside the
        // interviewer home's stack. Nesting stacks broke navigation (candidate
        // list wasn't reachable). It swaps candidate-list <-> rating in place.
        Group {
            if viewModel.isInRatingPhase {
                ratingScreen
            } else {
                CandidateListView(viewModel: viewModel)
            }
        }
        .task {
            viewModel.sessionId = sessionId
            viewModel.interviewerId = interviewerId
            await viewModel.loadCandidates()
        }
        // MARK: Alerts
        .alert("Something went wrong", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("Submit Scores", isPresented: $viewModel.showSubmitConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Submit", role: .destructive) {
                Task { await viewModel.confirmSubmit() }
            }
        } message: {
            Text("Scores are final and cannot be edited after submission. Are you sure?")
        }
        // MARK: Banners
        .overlay(alignment: .top) {
            if viewModel.showSuccessBanner {
                StatusBannerView(message: "Scores submitted successfully!", color: .green) {
                    viewModel.showSuccessBanner = false
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            } else if viewModel.showOfflineBanner {
                StatusBannerView(message: "Saved offline — will sync when you're back online.", color: .orange) {
                    viewModel.showOfflineBanner = false
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: viewModel.showSuccessBanner)
        .animation(.easeInOut, value: viewModel.showOfflineBanner)
    }

    // MARK: - Rating screen

    private var ratingScreen: some View {
        VStack(spacing: 0) {
            progressHeader

            ScrollView {
                if let question = viewModel.currentQuestion {
                    QuestionScoringView(
                        question: question,
                        questionNumber: viewModel.currentQuestionIndex + 1,
                        totalQuestions: viewModel.questions.count,
                        score: Binding(
                            get: { viewModel.currentScore?.score ?? 0 },
                            set: { newScore in
                                viewModel.updateScore(
                                    score: newScore,
                                    notes: viewModel.currentScore?.notes ?? ""
                                )
                            }
                        ),
                        notes: Binding(
                            get: { viewModel.currentScore?.notes ?? "" },
                            set: { newNotes in
                                viewModel.updateScore(
                                    score: viewModel.currentScore?.score ?? 0,
                                    notes: newNotes
                                )
                            }
                        )
                    )
                    .padding()

                    questionDots
                        .padding(.bottom, 8)
                }
            }

            navigationBar
        }
        .navigationTitle(viewModel.currentCandidate?.name ?? "Interview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    Task { await viewModel.cancelInterview() }
                }
                .disabled(viewModel.isSubmitting)
            }
        }
    }

    // MARK: - Progress header

    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Question \(viewModel.currentQuestionIndex + 1) of \(viewModel.questions.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.answeredCount) / \(viewModel.questions.count) scored")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(viewModel.allAnswered ? .green : .secondary)
            }

            ProgressView(
                value: Double(viewModel.answeredCount),
                total: Double(max(viewModel.questions.count, 1))
            )
            .tint(viewModel.allAnswered ? .green : Color.accentColor)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    // MARK: - Question dot indicators

    private var questionDots: some View {
        HStack(spacing: 6) {
            ForEach(viewModel.questions.indices, id: \.self) { index in
                let answered = viewModel.scores[viewModel.questions[index].id]?.isAnswered == true
                let isCurrent = index == viewModel.currentQuestionIndex
                Circle()
                    .fill(isCurrent ? Color.accentColor : (answered ? Color.green : Color.secondary.opacity(0.3)))
                    .frame(width: isCurrent ? 10 : 7, height: isCurrent ? 10 : 7)
                    .onTapGesture { viewModel.jumpToQuestion(at: index) }
                    .animation(.easeInOut(duration: 0.2), value: viewModel.currentQuestionIndex)
            }
        }
    }

    // MARK: - Navigation bar

    private var navigationBar: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.goToPreviousQuestion()
            } label: {
                Label("Previous", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isFirstQuestion || viewModel.isSubmitting)

            if viewModel.isLastQuestion {
                Button {
                    viewModel.requestSubmit()
                } label: {
                    if viewModel.isSubmitting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Submit", systemImage: "checkmark.seal.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.allAnswered ? .green : Color.accentColor)
                .disabled(!viewModel.allAnswered || viewModel.isSubmitting)
            } else {
                Button {
                    viewModel.goToNextQuestion()
                } label: {
                    Label("Next", systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSubmitting)
            }
        }
        .padding()
        .background(.regularMaterial)
    }
}

// MARK: - Status banner

private struct StatusBannerView: View {
    let message: String
    let color: Color
    let onDismiss: () -> Void

    var body: some View {
        Text(message)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(color.gradient)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    onDismiss()
                }
            }
    }
}
