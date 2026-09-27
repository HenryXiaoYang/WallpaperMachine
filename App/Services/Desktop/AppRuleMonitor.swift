import AppKit

/// Reports the app-rule actions currently in force. Workspace notifications are
/// observed only while at least one rule exists.
@MainActor
final class AppRuleMonitor {
    var onChange: (@MainActor () -> Void)?
    private(set) var actions: Set<AppRuleAction> = []

    private let preferences: PlaybackPreferences
    private let workspaceCenter: NotificationCenter
    private let preferencesCenter: NotificationCenter
    private let runningBundleIDs: @MainActor () -> Set<String>
    private let frontmostBundleID: @MainActor () -> String?

    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var started = false

    init(
        preferences: PlaybackPreferences,
        workspaceCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        preferencesCenter: NotificationCenter = .default,
        runningBundleIDs: (@MainActor () -> Set<String>)? = nil,
        frontmostBundleID: (@MainActor () -> String?)? = nil
    ) {
        self.preferences = preferences
        self.workspaceCenter = workspaceCenter
        self.preferencesCenter = preferencesCenter
        self.runningBundleIDs = runningBundleIDs ?? {
            Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        }
        self.frontmostBundleID = frontmostBundleID ?? {
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        }
    }

    func start() {
        guard !started else {
            refreshWorkspaceObservation()
            recompute()
            return
        }
        started = true
        observers.append((preferencesCenter, preferencesCenter.addObserver(
            forName: PlaybackPreferences.didChangeNotification, object: preferences, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshWorkspaceObservation()
                self?.recompute()
            }
        }))
        refreshWorkspaceObservation()
        recompute()
    }

    func stop() {
        started = false
        for (center, token) in observers { center.removeObserver(token) }
        observers.removeAll()
        publish([])
    }

    private func refreshWorkspaceObservation() {
        let watching = observers.contains { $0.0 === workspaceCenter }
        guard started, !preferences.appRules.isEmpty else {
            removeWorkspaceObservers()
            return
        }
        guard !watching else { return }
        for name in [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
        ] {
            observers.append((workspaceCenter, workspaceCenter.addObserver(
                forName: name, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.recompute() }
            }))
        }
    }

    private func removeWorkspaceObservers() {
        observers.removeAll { center, token in
            guard center === workspaceCenter else { return false }
            center.removeObserver(token)
            return true
        }
    }

    private func recompute() {
        guard started, !preferences.appRules.isEmpty else {
            publish([])
            return
        }
        let running = runningBundleIDs()
        let frontmost = frontmostBundleID()
        var next = Set<AppRuleAction>()
        for rule in preferences.appRules {
            let matches = switch rule.condition {
            case .running: running.contains(rule.bundleIdentifier)
            case .frontmost: frontmost == rule.bundleIdentifier
            }
            if matches { next.insert(rule.action) }
        }
        publish(next)
    }

    private func publish(_ next: Set<AppRuleAction>) {
        guard next != actions else { return }
        actions = next
        onChange?()
    }
}
