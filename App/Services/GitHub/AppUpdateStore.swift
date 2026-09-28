import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppUpdateStore {
    private(set) var state: AppUpdateState
    /// What the newest published release says it changed, for the About card. Present
    /// whether or not that release is newer than the running build.
    private(set) var releaseNotes: ReleaseNotes?
    /// When the last check was refused by GitHub's anonymous rate limit, the time it lifts.
    /// Checks before then fail locally, so retries can't keep the shared quota exhausted.
    private(set) var rateLimitedUntil: Date?
    @ObservationIgnored private let currentVersion: String
    @ObservationIgnored private let client: any AppUpdateClient
    @ObservationIgnored private let installer: any AppUpdateInstalling
    @ObservationIgnored private let workspace: AppUpdateWorkspace
    @ObservationIgnored private let scheduleInstall: (@escaping () -> Void) -> Void
    @ObservationIgnored private let terminate: () -> Void
    @ObservationIgnored private let installTimeout: Duration
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var checkTask: Task<AppUpdateState, Never>?
    @ObservationIgnored private var downloadTask: Task<AppUpdateState, Never>?
    @ObservationIgnored private var available: GitHubRelease?
    @ObservationIgnored private var downloadedArchive: URL?
    @ObservationIgnored private var extractedApp: URL?
    @ObservationIgnored private var activeOperation: AppUpdateOperation?
    @ObservationIgnored private var installScheduled = false
    @ObservationIgnored private var installWatchdog: Task<Void, Never>?

    init(currentVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
         client: any AppUpdateClient = GitHubReleaseClient(),
         installer: any AppUpdateInstalling = AppUpdateInstaller(),
         workspace: AppUpdateWorkspace = .live,
         scheduleInstall: ((@escaping () -> Void) -> Void)? = nil,
         terminate: (() -> Void)? = nil,
         installTimeout: Duration = .seconds(45),
         now: @escaping () -> Date = Date.init) {
        self.currentVersion = currentVersion
        self.client = client
        self.installer = installer
        self.workspace = workspace
        self.scheduleInstall = scheduleInstall ?? Self.performOnMainRunLoop
        self.terminate = terminate ?? { NSApp.terminate(nil) }
        self.installTimeout = installTimeout
        self.now = now
        state = .idle(currentVersion: currentVersion)
    }

    /// Runs `work` from the main run loop rather than as a main-queue job. AppKit waits out
    /// `.terminateLater` and `NSAlert.runModal()` in a nested run loop, and a nested run loop
    /// entered from inside a main-queue job (`DispatchQueue.main.async` or any `@MainActor`
    /// task) never drains the main queue: quitting would hang because the shutdown task never
    /// runs, and every main-actor task would stall while an alert is open.
    nonisolated static func performOnMainRunLoop(_ work: @escaping () -> Void) {
        RunLoop.main.perform(work)
    }

    func checkForUpdates() async -> AppUpdateState {
        if case .downloading = state { return state }
        if case .ready = state { return state }
        if let checkTask { return await checkTask.value }
        let task = Task { await performCheck() }
        checkTask = task
        return await task.value
    }

    /// The unattended path the app runs at launch and on a schedule. When the new version
    /// can replace this copy in place it is downloaded too, so the prompt that follows is a
    /// one-click restart. A copy outside Applications stops at `.available`: downloading
    /// there opens the disk image in Finder, which only a user who asked should see.
    func checkAndDownloadInBackground() async -> AppUpdateState {
        let checked = await checkForUpdates()
        guard case .available = checked, installer.canInstallInPlace else { return checked }
        return await downloadUpdate()
    }

    func downloadUpdate() async -> AppUpdateState {
        if let downloadTask { return await downloadTask.value }
        guard case .available(_, let version) = state, let release = available, release.version.display == version else {
            fail(.download, AppUpdateIssue(code: .configuration, detail: String(localized: "No update is available to download.")))
            return state
        }
        let task = Task { await performDownload(release) }
        downloadTask = task
        return await task.value
    }

    func installUpdate() async {
        let canRetryInstall: Bool = {
            if case .error(_, let operation, _, let version) = state {
                return operation == .install && version != nil
            }
            return false
        }()
        let isReady: Bool
        if case .ready = state { isReady = true } else { isReady = false }
        guard isReady || canRetryInstall else {
            fail(.install, AppUpdateIssue(code: .configuration, detail: String(localized: "No downloaded update is ready to install.")))
            return
        }
        guard installer.canInstallInPlace else {
            fail(.install, AppUpdateIssue(code: .permission, detail: String(localized: "The updater doesn't have permission to install this update.")))
            return
        }
        guard !installScheduled else { return }
        installScheduled = true
        do {
            let archive = try resolvedArchive()
            let extracted = try extractedApp ?? installer.prepareInstallation(archive: archive)
            extractedApp = extracted
            scheduleInstall { [weak self] in
                guard let self else { return }
                do {
                    try self.installer.install(extractedApp: extracted, replacing: Bundle.main.bundleURL)
                    self.armInstallWatchdog()
                    self.terminate()
                } catch {
                    self.installScheduled = false
                    self.fail(.install, error)
                }
            }
        } catch {
            installScheduled = false
            fail(.install, error)
        }
    }

    func revealDownloadedUpdate() {
        guard let downloadedArchive else { return }
        workspace.reveal(downloadedArchive)
    }

    func openReleases() {
        workspace.open(available?.htmlURL ?? AppUpdateConfiguration.releasesURL)
    }

    func cancel() {
        checkTask?.cancel()
        downloadTask?.cancel()
    }

    private func performCheck() async -> AppUpdateState {
        defer { checkTask = nil }
        if let rateLimitedUntil, rateLimitedUntil > now() {
            return fail(.check, AppUpdateIssue(code: .rateLimited, detail: "", retryAfter: rateLimitedUntil))
        }
        rateLimitedUntil = nil
        available = nil
        releaseNotes = nil
        activeOperation = .check
        state = .checking(currentVersion: currentVersion)
        defer {
            if activeOperation == .check { activeOperation = nil }
        }
        do {
            let release = try await client.fetchLatestRelease()
            if Task.isCancelled { return state }
            guard let current = SemanticVersion(currentVersion) else {
                return fail(.check, AppUpdateIssue(code: .configuration, detail: String(localized: "The GitHub Release update metadata is unavailable.")))
            }
            guard let release else {
                state = .noRelease(currentVersion: currentVersion)
                return state
            }
            releaseNotes = ReleaseNotes(version: release.version.display, body: release.notes)
            if release.version <= current {
                state = .upToDate(currentVersion: currentVersion)
                return state
            }
            available = release
            if GitHubReleaseParser.selectAsset(from: release) == nil {
                state = .manual(currentVersion: currentVersion, availableVersion: release.version.display)
            } else {
                state = .available(currentVersion: currentVersion, availableVersion: release.version.display)
            }
            return state
        } catch {
            return fail(.check, error)
        }
    }

    private func performDownload(_ release: GitHubRelease) async -> AppUpdateState {
        guard let asset = GitHubReleaseParser.selectAsset(from: release) else {
            state = .manual(currentVersion: currentVersion, availableVersion: release.version.display)
            downloadTask = nil
            return state
        }
        activeOperation = .download
        state = .downloading(currentVersion: currentVersion, availableVersion: release.version.display,
                             percent: 0, transferred: 0, total: max(0, asset.size), bytesPerSecond: 0)
        defer {
            if activeOperation == .download { activeOperation = nil }
            downloadTask = nil
        }
        let destination = workspace.archiveURL(release.version.display, asset.name)
        do {
            try await client.download(asset, to: destination) { [weak self] transferred, total, rate in
                guard let self else { return }
                let version = release.version.display
                let apply = {
                    MainActor.assumeIsolated {
                        self.markProgress(version: version, transferred: transferred, total: total, rate: rate)
                    }
                }
                if Thread.isMainThread {
                    apply()
                } else {
                    DispatchQueue.main.sync(execute: apply)
                }
            }
            if Task.isCancelled { return state }
            downloadedArchive = destination
            if !installer.canInstallInPlace {
                // Finder mounts the disk image and shows its drag-to-Applications window.
                workspace.open(destination)
            }
            state = .ready(currentVersion: currentVersion, availableVersion: release.version.display)
            return state
        } catch is CancellationError {
            if case .downloading = state {
                state = .available(currentVersion: currentVersion, availableVersion: release.version.display)
            }
            return state
        } catch {
            return fail(.download, error)
        }
    }

    private func markProgress(version: String, transferred: Int64, total: Int64, rate: Int64) {
        guard case .downloading(_, let current, let existing, _, _, _) = state, current == version else { return }
        let progress = AppUpdateProgress.clamped(transferred: transferred, total: total, rate: rate)
        if floor(existing) == floor(progress.percent), progress.percent < 100 {
            return
        }
        state = .downloading(currentVersion: currentVersion, availableVersion: version, percent: progress.percent,
                             transferred: progress.transferred, total: progress.total, bytesPerSecond: progress.rate)
    }

    @discardableResult
    private func fail(_ operation: AppUpdateOperation, _ error: Error) -> AppUpdateState {
        if error is CancellationError { return state }
        let code = AppUpdateErrorClassifier.classify(error)
        if code == .rateLimited { rateLimitedUntil = (error as? AppUpdateIssue)?.retryAfter }
        if case .error(_, let existingOperation, let existingCode, _) = state,
           existingOperation == operation, existingCode == code {
            return state
        }
        let version = available?.version.display
        state = .error(currentVersion: currentVersion, operation: operation, code: code,
                       availableVersion: operation == .install ? version : nil)
        return state
    }

    private func resolvedArchive() throws -> URL {
        if let downloadedArchive, FileManager.default.fileExists(atPath: downloadedArchive.path) {
            return downloadedArchive
        }
        throw AppUpdateIssue(code: .configuration, detail: String(localized: "No downloaded update is ready to install."))
    }

    private func armInstallWatchdog() {
        installWatchdog?.cancel()
        let timeout = installTimeout
        installWatchdog = Task { [weak self] in
            try? await Task.sleep(for: timeout)
            guard let self, !Task.isCancelled, self.installScheduled else { return }
            self.installScheduled = false
            self.fail(.install, AppUpdateIssue(code: .unknown, detail: String(localized: "Install timed out: the app did not quit and relaunch.")))
        }
    }
}

struct AppUpdateWorkspace: Sendable {
    let archiveURL: @Sendable (String, String) -> URL
    let reveal: @Sendable (URL) -> Void
    let open: @Sendable (URL) -> Void

    static var live: AppUpdateWorkspace {
        AppUpdateWorkspace(
            archiveURL: { version, name in
                let folder = ClientPaths.supportURL.appendingPathComponent("Updates", isDirectory: true)
                let sanitized = name.isEmpty ? "WallpaperMachine-\(version).dmg" : name
                return folder.appendingPathComponent(sanitized)
            },
            reveal: { url in
                NSWorkspace.shared.activateFileViewerSelecting([url])
            },
            open: { url in
                NSWorkspace.shared.open(url)
            }
        )
    }
}
