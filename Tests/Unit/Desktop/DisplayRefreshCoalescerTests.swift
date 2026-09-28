import XCTest
@testable import WallpaperMachine

@MainActor
final class DisplayRefreshCoalescerTests: XCTestCase {
    /// A display waking can post dozens of screen changes in a second. Each
    /// refresh used to queue behind the last in the bridge, and the resume
    /// after an unlock waited behind all of them.
    func testABurstDuringARefreshIsAnsweredByOneMoreRefresh() async throws {
        var runs = 0
        var held: [CheckedContinuation<Void, Never>] = []
        let coalescer = DisplayRefreshCoalescer {
            runs += 1
            await withCheckedContinuation { held.append($0) }
        }

        coalescer.request()
        try await waitUntil { held.count == 1 }
        for _ in 0..<50 { coalescer.request() }
        XCTAssertEqual(runs, 1, "a change during a refresh must not start another one alongside it")

        held.removeFirst().resume()
        try await waitUntil { held.count == 1 }
        XCTAssertEqual(runs, 2, "the burst is answered by exactly one more refresh")

        held.removeFirst().resume()
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(runs, 2, "nothing arrived during the second refresh, so there is no third")
    }

    func testAChangeAfterTheLastRefreshFinishedRefreshesAgain() async throws {
        var runs = 0
        let coalescer = DisplayRefreshCoalescer { runs += 1 }

        coalescer.request()
        try await waitUntil { runs == 1 }
        coalescer.request()
        try await waitUntil { runs == 2 }
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !condition() {
            guard ContinuousClock.now < deadline else { throw TestFailure.timeout }
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    private enum TestFailure: Error { case timeout }
}
