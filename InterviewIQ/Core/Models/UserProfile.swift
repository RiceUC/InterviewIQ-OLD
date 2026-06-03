import Foundation

// MARK: - Models

// Stored at users/{uid} in Realtime Database.
// role and isActive carry default values so older call sites that build a
// profile with only id/name/email still compile; new registrations set them
// explicitly.
struct UserProfile: Codable {
    // MARK: - Properties

    let userId: String
    let fullName: String
    let emailAddress: String
    var role: UserRole = .interviewer
    var isActive: Bool = true
}
