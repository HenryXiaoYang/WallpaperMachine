import XCTest

@testable import WallpaperMachine

final class AppLogRouterTests: XCTestCase {
    private final class RecordingSink: AppLogSink {
        struct Line: Equatable {
            let message: String
            let load: UInt64?
            let unixMillis: Int64?
        }

        private let lock = NSLock()
        private var recorded: [Line] = []
        var lines: [Line] { lock.withLock { recorded } }

        func emitGuiLog(level: BridgeLogLevel, file: String, line: UInt32, message: String, load: UInt64?, unixMillis: Int64?) throws {
            lock.withLock { recorded.append(Line(message: message, load: load, unixMillis: unixMillis)) }
        }

        func beginHostLoadLog(kind: String, projectPath: String, detail: String) -> UInt64 { 42 }
    }

    private func entry(_ message: String, at millis: Int64, load: UInt64? = nil) -> AppLogRouter.Entry {
        AppLogRouter.Entry(level: .info, file: "Test.swift", line: 1, message: message, load: load, unixMillis: millis)
    }

    func testLinesLoggedBeforeTheBridgeKeepTheirTimeAndOrder() {
        let router = AppLogRouter()
        router.emit(entry("first", at: 1_000))
        router.emit(entry("second", at: 1_005))
        let sink = RecordingSink()

        router.attach(sink)
        router.emit(entry("after", at: 2_000, load: 7))

        XCTAssertEqual(sink.lines, [
            .init(message: "first", load: nil, unixMillis: 1_000),
            .init(message: "second", load: nil, unixMillis: 1_005),
            .init(message: "after", load: 7, unixMillis: 2_000),
        ])
    }

    func testOverflowBeforeTheBridgeIsReportedNotSilent() {
        let router = AppLogRouter(pendingLimit: 2)
        for index in 0..<5 { router.emit(entry("line \(index)", at: Int64(index))) }
        let sink = RecordingSink()

        router.attach(sink)

        XCTAssertEqual(sink.lines.map(\.message), [
            "3 startup log lines were dropped before the log opened", "line 0", "line 1",
        ])
    }

    func testLoadsStartOnlyOnceTheLogIsOpen() {
        let router = AppLogRouter()
        XCTAssertNil(router.beginLoad("web", project: "/tmp/p", detail: ""))

        router.attach(RecordingSink())

        XCTAssertEqual(router.beginLoad("web", project: "/tmp/p", detail: ""), 42)
    }

    func testLinesFromManyThreadsAllArrive() {
        let router = AppLogRouter()
        let sink = RecordingSink()
        router.attach(sink)

        DispatchQueue.concurrentPerform(iterations: 200) { index in
            router.emit(entry("line \(index)", at: Int64(index)))
        }

        XCTAssertEqual(Set(sink.lines.map(\.message)), Set((0..<200).map { "line \($0)" }))
    }
}
