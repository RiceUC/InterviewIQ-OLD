import Foundation

enum SyncStatus: String, Codable {
    case synced = "SYNCED"
    case pending = "PENDING"
    case failed = "FAILED"
}
