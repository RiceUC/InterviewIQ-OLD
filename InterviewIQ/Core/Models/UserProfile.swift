import Foundation

// MARK: - Models

struct UserProfile: Codable {
    // MARK: - Properties
    
    let userId: String
    let fullName: String
    let emailAddress: String
}