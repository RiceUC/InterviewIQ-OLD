// Location: InterviewApp/Features/Authentication/LoginView.swift

import SwiftUI

struct LoginView: View {
    // MARK: - Properties
    
    @StateObject private var viewModel = AuthViewModel()
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 20) {
            Text("InterviewIQ")
                .font(.largeTitle)
                .bold()
            
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
                    await viewModel.performLogin()
                }
            }) {
                Text(viewModel.isLoading ? "Logging in..." : "Login")
            }
            .disabled(viewModel.isLoading || viewModel.isAccountLocked)
            
            NavigationLink(destination: RegisterView()) {
                Text("Don't have an account? Register here")
            }
        }
        .padding()
    }
}