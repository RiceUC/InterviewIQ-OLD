import Foundation

// Role-Based Access Control (RBAC) levels for the system.
// Maps to UserRole (C-34) in the class diagram and FR-02 (role-based access).
// Stored as a String under users/{uid}/role in Realtime Database.
enum UserRole: String, Codable, CaseIterable, Identifiable {
    case admin
    case interviewer

    var id: String { rawValue }

    // Human-readable label for pickers and headers.
    var displayName: String {
        switch self {
        case .admin: return "Admin"
        case .interviewer: return "Interviewer"
        }
    }
}
