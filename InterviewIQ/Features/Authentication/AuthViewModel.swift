// Location: InterviewApp/Features/Authentication/AuthViewModel.swift

import Foundation
import FirebaseAuth
import Combine

class AuthViewModel: ObservableObject {
    // MARK: - Published Properties (UI Binding States)
    @Published var emailAddress = ""
    @Published var userPassword = ""
    @Published var fullName = ""
    @Published var selectedRole: UserRole = .interviewer

    @Published var isLoading = false
    @Published var hasAuthenticationError = false
    @Published var errorMessage = ""
    @Published var isAccountLocked = false
    @Published var hasSuccessfullyRegistered = false

    // MARK: - Core Security Storage (Per-Account Lock Tracking)
    // Key-Value data structures store values independently per normalized email string
    private var accountFailedAttempts: [String: Int] = [:]
    private var accountLockExpirations: [String: Date] = [:]

    // MARK: - Profile Persistence
    // Writes the user profile (name + role) to users/{uid} after sign-up so the
    // app can route by role. Without this, registration created a Firebase Auth
    // user but no profile record, leaving role/name unknown.
    private let userRepository = UserRepository()

    // MARK: - Audit Logging (FR-11)
    // Records authentication events (registration + login attempts).
    private let auditLogger = AuditLogger()

    // MARK: - Authentication Pipelines
    
    /// Handles targeted conditional user logins matching requirement 3a.1
    func performLogin() async {
        let normalizedEmail = emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // 1. Pre-Auth Security Gatekeeper: Check lock status for this specific email identifier
        if let lockExpiry = accountLockExpirations[normalizedEmail] {
            if Date() < lockExpiry {
                let remainingSeconds = lockExpiry.timeIntervalSince(Date())
                let remainingMinutes = Int(ceil(remainingSeconds / 60.0))
                
                await MainActor.run {
                    self.isAccountLocked = true
                    self.hasAuthenticationError = true
                    self.errorMessage = "Account temporarily locked for 15 minutes. Try again in \(remainingMinutes) min(s)."
                }
                return
            } else {
                // Lock has naturally expired out of the 15-minute window; reset account access
                accountLockExpirations.removeValue(forKey: normalizedEmail)
                accountFailedAttempts[normalizedEmail] = 0
                await MainActor.run { self.isAccountLocked = false }
            }
        }
        
        // 2. Initialize processing UI state
        await MainActor.run {
            self.isLoading = true
            self.hasAuthenticationError = false
            self.errorMessage = ""
            self.isAccountLocked = false
        }
        
        do {
            // 3. Dispatch auth credentials payload request to Firebase
            let result = try await Auth.auth().signIn(withEmail: emailAddress, password: userPassword)

            // On Authentication Success: Flush failed records for this email
            accountFailedAttempts[normalizedEmail] = 0
            accountLockExpirations.removeValue(forKey: normalizedEmail)

            await auditLogger.log(
                .loginSucceeded,
                actorId: result.user.uid,
                targetType: "user",
                targetId: result.user.uid,
                details: normalizedEmail
            )
            
            await MainActor.run {
                self.isLoading = false
                // Success actions (e.g., transition application dashboard root state)
            }
            
        } catch {
            let authError = error as NSError

            await auditLogger.log(
                .loginFailed,
                actorId: normalizedEmail,
                targetType: "user",
                targetId: normalizedEmail,
                details: "code=\(authError.code)"
            )

            await MainActor.run {
                self.isLoading = false
                self.hasAuthenticationError = true

                // 4. Intercept errors to apply contextual security logic
                switch authError.code {
                    
                case AuthErrorCode.userNotFound.rawValue:
                    // Scenario A: Nonexistent email. Fail immediately with NO lockout modification.
                    self.errorMessage = "Invalid credentials. Please check your email and password."
                    
                case AuthErrorCode.wrongPassword.rawValue:
                    // Scenario B: Valid email, wrong password. Increment this email's tracking footprint.
                    let currentAttempts = (accountFailedAttempts[normalizedEmail] ?? 0) + 1
                    accountFailedAttempts[normalizedEmail] = currentAttempts
                    
                    if currentAttempts >= 5 {
                        // Exactly on the 5th attempt: Lock this specific key for 15 minutes
                        let unlockTimestamp = Date().addingTimeInterval(15 * 60) // 15 mins = 900 seconds
                        accountLockExpirations[normalizedEmail] = unlockTimestamp
                        self.isAccountLocked = true
                        self.errorMessage = "Account locked after 5 failed attempts. Please try again in 15 minutes."
                    } else {
                        self.errorMessage = "Invalid credentials. Please check your email and password."
                    }
                    
                case AuthErrorCode.invalidCredential.rawValue:
                    // Guard fallback if User Enumeration Protection remains enabled on Firebase Console
                    let currentAttempts = (accountFailedAttempts[normalizedEmail] ?? 0) + 1
                    accountFailedAttempts[normalizedEmail] = currentAttempts
                    
                    if currentAttempts >= 5 {
                        let unlockTimestamp = Date().addingTimeInterval(15 * 60)
                        accountLockExpirations[normalizedEmail] = unlockTimestamp
                        self.isAccountLocked = true
                        self.errorMessage = "Account locked after 5 failed attempts. Please try again in 15 minutes."
                    } else {
                        self.errorMessage = "Invalid credentials. Please check your email and password."
                    }
                    
                default:
                    // Catch-all general system/network level faults
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Handles registration constraints validation with isolated rule logic processing
    func performRegistration() async {
        // Clear screen error records prior to triggering pipeline
        await MainActor.run {
            self.hasAuthenticationError = false
            self.errorMessage = ""
            self.isLoading = true
        }
        
        // Isolate Rule Check 1: Client-side String Character Length Validation
        if userPassword.count < 6 {
            await MainActor.run {
                self.isLoading = false
                self.hasAuthenticationError = true
                self.errorMessage = "Password must be at least 6 characters long."
            }
            return
        }
        
        // Isolate Rule Check 2: Server-side Database Duplicate Verification
        do {
            let result = try await Auth.auth().createUser(withEmail: emailAddress, password: userPassword)

            // Persist the profile so role + name survive beyond the Auth record.
            let profile = UserProfile(
                userId: result.user.uid,
                fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                emailAddress: emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                role: selectedRole,
                isActive: true
            )
            try await userRepository.saveProfile(profile)

            await auditLogger.log(
                .userRegistered,
                actorId: profile.userId,
                actorRole: profile.role.rawValue,
                targetType: "user",
                targetId: profile.userId,
                details: profile.emailAddress
            )

            // All registration rules passed flawlessly
            await MainActor.run {
                self.isLoading = false
                self.hasSuccessfullyRegistered = true
            }
        } catch {
            let registrationError = error as NSError
            
            await MainActor.run {
                self.isLoading = false
                self.hasAuthenticationError = true
                
                if registrationError.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                    self.errorMessage = "This email address is already registered."
                } else {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
