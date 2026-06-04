import Foundation
import Network

// Monitors network connectivity and syncs pending ScoreRecords to Firestore
// when connectivity is restored (NFR-07, SRS extension 7b).
@Observable
final class OfflineSyncManager {
    var isOnline: Bool = false

    private let monitor = NWPathMonitor()
    private let scoreRepo = ScoreRepository()

    init() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                let wasOffline = !self.isOnline
                self.isOnline = path.status == .satisfied
                if wasOffline && self.isOnline {
                    Task { await self.syncPending() }
                }
            }
        }
        monitor.start(queue: .global(qos: .background))
    }

    deinit { monitor.cancel() }

    // Saves locally immediately; syncs to Firestore if online.
    func enqueue(_ record: ScoreRecord) {
        scoreRepo.saveLocally(record)
        if isOnline {
            Task { await syncRecord(record) }
        }
    }

    func syncPending() async {
        for record in scoreRepo.loadAllPending() {
            await syncRecord(record)
        }
    }

    private func syncRecord(_ record: ScoreRecord) async {
        do {
            var synced = record
            synced.syncStatus = .synced
            try await scoreRepo.submit(synced)
            scoreRepo.saveLocally(synced)
        } catch {
            // Stays queued in UserDefaults; will retry on next connectivity event.
        }
    }
}
