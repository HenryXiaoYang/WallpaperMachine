import Foundation

/// Runs one display refresh at a time. macOS can post screen-parameter changes
/// in bursts, for example while a display wakes, and each refresh is a full
/// round trip through the bridge, so the changes that arrive while one runs are
/// answered by a single refresh after it.
@MainActor
final class DisplayRefreshCoalescer {
    private let refresh: @MainActor () async -> Void
    private var running = false
    private var pending = false
    private var coalesced = 0

    init(refresh: @escaping @MainActor () async -> Void) {
        self.refresh = refresh
    }

    func request() {
        guard !running else {
            pending = true
            coalesced += 1
            return
        }
        running = true
        Task { await drain() }
    }

    private func drain() async {
        repeat {
            pending = false
            await refresh()
        } while pending
        running = false
        if coalesced > 0 {
            AppLog.info("display refresh: \(coalesced) screen changes arrived during a refresh and were merged")
            coalesced = 0
        }
    }
}
