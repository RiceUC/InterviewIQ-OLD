import Foundation
import FirebaseAuth
import FirebaseDatabase

// ⚠️ SUPERSEDED / UNUSED.
// The live auth flow uses AuthViewModel for sign-in/registration and
// UserRepository for profile read/write at users/{uid}. This class was never
// wired into any view and now duplicates UserRepository. Kept only so existing
// references compile — safe to delete once the team confirms nothing depends on it.

// MARK: - Errors

enum AuthenticationError: Error {
    case invalidCredentials
    case profileFetchFailed
    case registrationFailed
}

// MARK: - Protocols

protocol AuthServiceProtocol {
    func login(withEmail email: String, andPassword password: String) async throws -> UserProfile
    func register(withName name: String, email: String, andPassword password: String) async throws -> UserProfile
}

// MARK: - Service Implementation

class AuthService: AuthServiceProtocol {
    // MARK: - Properties
    
    private let databaseReference = Database.database().reference()
    
    // MARK: - Public Methods
    
    func login(withEmail email: String, andPassword password: String) async throws -> UserProfile {
        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            return try await fetchUserProfile(forUid: authResult.user.uid)
        } catch {
            throw AuthenticationError.invalidCredentials
        }
    }
    
    func register(withName name: String, email: String, andPassword password: String) async throws -> UserProfile {
        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            let uid = authResult.user.uid
            
            let newProfile = UserProfile(
                userId: uid,
                fullName: name,
                emailAddress: email
            )
            
            try await saveUserProfileToDatabase(profile: newProfile)
            return newProfile
        } catch {
            throw AuthenticationError.registrationFailed
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func fetchUserProfile(forUid uid: String) async throws -> UserProfile {
        let snapshot = try await databaseReference.child("users").child(uid).getData()
        
        guard let value = snapshot.value as? [String: Any],
                let name = value["fullName"] as? String,
                let email = value["emailAddress"] as? String else {
            throw AuthenticationError.profileFetchFailed
        }
        
        return UserProfile(userId: uid, fullName: name, emailAddress: email)
    }
    
    private func saveUserProfileToDatabase(profile: UserProfile) async throws {
        let dictionaryRepresentation: [String: Any] = [
            "userId": profile.userId,
            "fullName": profile.fullName,
            "emailAddress": profile.emailAddress
        ]
        
        try await databaseReference.child("users").child(profile.userId).setValue(dictionaryRepresentation)
    }
}