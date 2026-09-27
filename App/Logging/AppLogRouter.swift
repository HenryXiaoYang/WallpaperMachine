import Foundation
import os

/// Where `AppLog` lines go once the bridge exists. `WallpaperBridge` is the
/// real one; its methods are synchronous and callable from any thread.
protocol AppLogSink: AnyObject {
    func emitGuiLog(level: BridgeLogLevel, file: String, line: UInt32, message: String, load: UInt64?, unixMillis: Int64?) throws
    func beginHostLoadLog(kind: String, projectPath: String, detail: String) -> UInt64
}

extension WallpaperBridge: AppLogSink {}

/// Routes log lines to the bridge, holding the ones logged before it exists.
///
/// Thread-safe and never hops actors. Lines are written under one lock, so
/// lines from different threads keep the order they were logged in, and held
/// lines keep the time they were logged rather than the time they were written.
final class AppLogRouter: @unchecked Sendable {
    struct Entry {
        let level: BridgeLogLevel
        let file: String
        let line: UInt32
        let message: String
        let load: UInt64?
        let unixMillis: Int64
    }

    private enum Destination {
        case pending([Entry], dropped: Int)
        case sink(any AppLogSink)
        case standardError
    }

    /// Held lines before the bridge attaches. Startup logs a few dozen; the
    /// cap only stops a failed start from growing without bound.
    let pendingLimit: Int
    private let destination = OSAllocatedUnfairLock<Destination>(
        uncheckedState: .pending([], dropped: 0))

    init(pendingLimit: Int = 1000) {
        self.pendingLimit = pendingLimit
    }

    func emit(_ entry: Entry) {
        destination.withLockUnchecked { destination in
            switch destination {
            case let .sink(sink):
                Self.write(entry, to: sink)
            case .standardError:
                Self.writeToStandardError(entry)
            case .pending(var entries, var dropped):
                if entries.count < pendingLimit {
                    entries.append(entry)
                } else {
                    dropped += 1
                }
                destination = .pending(entries, dropped: dropped)
            }
        }
    }

    /// Writes held lines to `sink`, oldest first, then sends every later line
    /// straight to it.
    func attach(_ sink: any AppLogSink) {
        destination.withLockUnchecked { destination in
            if case let .pending(entries, dropped) = destination {
                if dropped > 0 {
                    Self.write(Entry(level: .warn, file: "AppLogRouter.swift", line: 0,
                                     message: "\(dropped) startup log lines were dropped before the log opened",
                                     load: nil, unixMillis: entries.last?.unixMillis ?? Self.now()), to: sink)
                }
                for entry in entries { Self.write(entry, to: sink) }
            }
            destination = .sink(sink)
        }
    }

    /// For a start whose bridge failed: held lines and every later one go to
    /// stderr, since there is no log file to hold them.
    func detachToStandardError() {
        destination.withLockUnchecked { destination in
            if case let .pending(entries, _) = destination {
                for entry in entries { Self.writeToStandardError(entry) }
            }
            destination = .standardError
        }
    }

    /// Nil until a sink is attached: a load header must not be held, because
    /// the number it returns is what the load's later lines are tagged with.
    func beginLoad(_ kind: String, project: String, detail: String) -> UInt64? {
        destination.withLockUnchecked { destination in
            guard case let .sink(sink) = destination else { return nil }
            return sink.beginHostLoadLog(kind: kind, projectPath: project, detail: detail)
        }
    }

    static func now() -> Int64 {
        Int64((Date().timeIntervalSince1970 * 1000).rounded())
    }

    private static func write(_ entry: Entry, to sink: any AppLogSink) {
        do {
            try sink.emitGuiLog(level: entry.level, file: entry.file, line: entry.line,
                                message: entry.message, load: entry.load, unixMillis: entry.unixMillis)
        } catch {
            fputs("ERROR AppLogRouter.swift:0 failed to emit log: \(error)\n", stderr)
            writeToStandardError(entry)
        }
    }

    private static func writeToStandardError(_ entry: Entry) {
        let load = entry.load.map { "[load#\($0)] " } ?? ""
        fputs("\(entry.level) \(load)\(entry.file):\(entry.line) \(entry.message)\n", stderr)
    }
}
