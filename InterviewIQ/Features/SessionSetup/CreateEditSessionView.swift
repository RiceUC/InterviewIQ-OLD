import SwiftUI

struct CreateEditSessionView: View {
    @Bindable var viewModel: CreateEditSessionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                candidatesSection
                interviewersSection
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

    private var interviewersSection: some View {
        Section("Interviewers") {
            NavigationLink("Manage Interviewers") {
                UserManagementView()
            }
        }
    }
}
