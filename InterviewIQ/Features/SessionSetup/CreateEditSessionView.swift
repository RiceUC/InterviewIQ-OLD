import SwiftUI

struct CreateEditSessionView: View {
    @Bindable var viewModel: CreateEditSessionVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                candidatesSection
                rubricSection
            }
            .navigationTitle(viewModel.isEditMode ? "Edit Session" : "New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await viewModel.save() }
                        }
                    }
                }
            }
            .alert("Cannot Save", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .onChange(of: viewModel.didSave) { _, saved in
                if saved { dismiss() }
            }
            .task { await viewModel.onAppear() }
            .disabled(viewModel.isSaving || viewModel.isLoading)
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Loading…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Sections

    private var detailsSection: some View {
        Section("Session Details") {
            TextField("Title", text: $viewModel.title)
            DatePicker(
                "Date",
                selection: $viewModel.date,
                in: Calendar.current.startOfDay(for: Date())...,
                displayedComponents: .date
            )
        }
    }

    private var candidatesSection: some View {
        Section("Candidates") {
            ForEach($viewModel.candidateEntries) { $entry in
                HStack {
                    TextField("Candidate name", text: $entry.name)
                    if viewModel.candidateEntries.count > 1 {
                        Button {
                            if let index = viewModel.candidateEntries.firstIndex(where: { $0.id == entry.id }) {
                                viewModel.removeCandidate(at: IndexSet(integer: index))
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                viewModel.addCandidateRow()
            } label: {
                Label("Add Candidate", systemImage: "plus.circle")
            }
        }
    }

    private var rubricSection: some View {
        Section {
            ForEach($viewModel.questionEntries) { $entry in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Question prompt", text: $entry.prompt, axis: .vertical)
                        if viewModel.questionEntries.count > 1 {
                            Button {
                                if let index = viewModel.questionEntries.firstIndex(where: { $0.id == entry.id }) {
                                    viewModel.removeQuestion(at: IndexSet(integer: index))
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Stepper(value: $entry.maxScore, in: 1...100) {
                        Text("Max score: \(entry.maxScore)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }

            Button {
                viewModel.addQuestionRow()
            } label: {
                Label("Add Question", systemImage: "plus.circle")
            }
        } header: {
            Text("Scoring Rubric")
        } footer: {
            Text("Interviewers score each question from 1 to its max. Add at least one question.")
        }
    }

}
