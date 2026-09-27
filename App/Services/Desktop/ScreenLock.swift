import Darwin

/// Locks the screen the way the system's Lock Screen command (⌃⌘Q) does, through
/// the private `SACLockScreenImmediate` in login.framework. Nil-safe: when a macOS
/// release drops the symbol, the menu leaves the command out.
enum ScreenLock {
    private typealias LockNow = @convention(c) () -> Int32

    private static let lockNow: LockNow? = {
        guard let framework = dlopen(
            "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY),
            let symbol = dlsym(framework, "SACLockScreenImmediate")
        else { return nil }
        return unsafeBitCast(symbol, to: LockNow.self)
    }()

    static var isAvailable: Bool { lockNow != nil }

    static func lock() {
        _ = lockNow?()
    }
}
