// Location: InterviewApp/Features/Authentication/RegisterView.swift

import SwiftUI

struct RegisterView: View {
    // MARK: - Properties
    
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create Account")
                .font(.largeTitle)
                .bold()
            
            TextField("Full Name", text: $viewModel.fullName)
                .disableAutocorrection(true)
            
            TextField("Email Address", text: $viewModel.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            SecureField("Password", text: $viewModel.userPassword)
            
            if viewModel.hasAuthenticationError {
                Text(viewModel.errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Button(action: {
                Task {
                    await viewModel.performRegistration()
                    if viewModel.authenticatedUser != nil {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }) {
                Text(viewModel.isLoading ? "Creating Account..." : "Register")
            }
            .disabled(viewModel.isLoading)
        }
        .padding()
    }
}