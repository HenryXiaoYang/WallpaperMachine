import XCTest

@testable import WallpaperMachine

/// Settings the panel keeps itself rather than handing to the engine.
@MainActor
final class WebPanelGeneralSettingsTests: XCTestCase {
  func testHidingAfterApplyingIsOffUntilTurnedOnAndPersists() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "panel-general-\(UUID().uuidString)")
    let defaults = try XCTUnwrap(UserDefaults(suiteName: root.lastPathComponent))
    defer {
      defaults.removePersistentDomain(forName: root.lastPathComponent)
      try? FileManager.default.removeItem(at: root)
    }
    let workshop = WorkshopStore(
      downloader: WorkshopDownloadManager(sessionDirectory: root), supportDirectory: root,
      defaults: defaults)
    func makeController() -> WebPanelController {
      WebPanelController(
        store: BridgeStore(bridge: WallpaperBridge(noPointer: .init())),
        navigation: ControlPanelNavigation(), workshop: workshop, defaults: defaults,
        appLanguage: .english())
    }
    let controller = makeController()
    defer { controller.stop() }

    XCTAssertFalse(controller.hidesAfterActivating, "The panel stays open after applying unless the user opts in")
    try await controller.perform("setting", body: ["key": "hideAfterActivating", "value": true])
    XCTAssertTrue(controller.hidesAfterActivating)

    let reopened = makeController()
    defer { reopened.stop() }
    XCTAssertTrue(reopened.hidesAfterActivating, "The choice must survive a relaunch")
  }
}
