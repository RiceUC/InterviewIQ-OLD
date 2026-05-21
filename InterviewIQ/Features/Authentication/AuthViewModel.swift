// Location: InterviewApp/Features/Authentication/AuthViewModel.swift

import Foundation
import Combine
@MainActor
class AuthViewModel: ObservableObject {
    // MARK: - Properties
    
    @Published var fullName = ""
    @Published var emailAddress = ""
    @Published var userPassword = ""
    
    @Published var isLoading = false
    @Published var hasAuthenticationError = false
    @Published var isAccountLocked = false
    @Published var errorMessage = ""
    
    @Published var authenticatedUser: UserProfile?
    
    private var failedLoginAttempts = 0
    private let authService: AuthServiceProtocol
    
    // MARK: - Initialization
    
    init(authService: AuthServiceProtocol = AuthService()) {
        self.authService = authService
    }
    
    // MARK: - Public Actions
    
    func performLogin() async {
        guard !isAccountLocked else { return }
        
        isLoading = true
        hasAuthenticationError = false
        
        do {
            let profile = try await authService.login(withEmail: emailAddress, andPassword: userPassword)
            authenticatedUser = profile
            failedLoginAttempts = 0
            isLoading = false
        } catch {
            failedLoginAttempts += 1
            isLoading = false
            hasAuthenticationError = true
            
            // Security threshold control verification from the project requirements
            if failedLoginAttempts >= 5 {
                isAccountLocked = true
                errorMessage = "Account temporarily locked due to 5 failed attempts."
            } else {
                errorMessage = "Invalid email or password credentials. Attempt \(failedLoginAttempts) of 5."
            }
        }
    }
    
    func performRegistration() async {
        isLoading = true
        hasAuthenticationError = false
        
        do {
            let profile = try await authService.register(
                withName: fullName,
                email: emailAddress,
                andPassword: userPassword
            )
            authenticatedUser = profile
            isLoading = false
        } catch {
            isLoading = false
            hasAuthenticationError = true
            errorMessage = "Registration sequence failed. Please verify fields and network connectivity."
        }
    }
}
