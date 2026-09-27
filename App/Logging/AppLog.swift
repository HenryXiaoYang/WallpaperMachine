import Foundation

/// The app's log, written through the bridge into the same session files as
/// the renderer's.
///
/// Callable from any thread and never hops to the main actor, so a stalled
/// main thread does not also silence the lines that would explain it. Lines
/// logged before the bridge exists are held with the time they were logged and
/// written when it attaches; if it never does they go to stderr.
enum AppLog {
    static let router = AppLogRouter()

    static func trace(_ message: @autoclosure () -> String, load: UInt64? = nil, file: StaticString = #fileID, line: UInt = #line) {
        emit(level: .trace, message: message(), load: load, file: file, line: line)
    }

    static func debug(_ message: @autoclosure () -> String, load: UInt64? = nil, file: StaticString = #fileID, line: UInt = #line) {
        emit(level: .debug, message: message(), load: load, file: file, line: line)
    }

    static func info(_ message: @autoclosure () -> String, load: UInt64? = nil, file: StaticString = #fileID, line: UInt = #line) {
        emit(level: .info, message: message(), load: load, file: file, line: line)
    }

    static func warn(_ message: @autoclosure () -> String, load: UInt64? = nil, file: StaticString = #fileID, line: UInt = #line) {
        emit(level: .warn, message: message(), load: load, file: file, line: line)
    }

    static func error(_ message: @autoclosure () -> String, load: UInt64? = nil, file: StaticString = #fileID, line: UInt = #line) {
        emit(level: .error, message: message(), load: load, file: file, line: line)
    }

    static func attach(_ sink: any AppLogSink) { router.attach(sink) }

    static func detachToStandardError() { router.detachToStandardError() }

    /// Starts the log of a wallpaper load the app performs itself (a web page,
    /// a native video): writes a header naming the project and `detail`, and
    /// returns the `load#N` to pass as `load:` on the load's later lines. Nil
    /// before the log is open.
    static func beginLoad(_ kind: String, project: String, detail: String) -> UInt64? {
        router.beginLoad(kind, project: project, detail: detail)
    }

    private static func emit(level: BridgeLogLevel, message: String, load: UInt64?, file: StaticString, line: UInt) {
        router.emit(AppLogRouter.Entry(level: level, file: "\(file)", line: UInt32(clamping: line),
                                       message: message, load: load, unixMillis: AppLogRouter.now()))
    }
}
