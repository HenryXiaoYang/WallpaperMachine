import XCTest

@testable import WallpaperMachine

/// The menu bar's Next Wallpaper walks the library in order, skipping what cannot play.
@MainActor
final class NextWallpaperTests: XCTestCase {
  func testNextFollowsLibraryOrderSkipsUnsupportedAndWraps() {
    let store = makeStore(
      wallpapers: [("a", true), ("broken", false), ("b", true), ("c", true)], showing: "b")

    XCTAssertEqual(store.nextWallpaperID(displayId: "primary"), "c")
    store.monitorInformationSnapshot.rows[0].wallpaperId = "c"
    XCTAssertEqual(store.nextWallpaperID(displayId: "primary"), "a", "The last wallpaper wraps to the first")
    store.monitorInformationSnapshot.rows[0].wallpaperId = "a"
    XCTAssertEqual(store.nextWallpaperID(displayId: "primary"), "b", "An unsupported wallpaper is skipped")
  }

  func testDisplayWithoutAWallpaperStartsAtTheFirst() {
    let store = makeStore(wallpapers: [("a", true), ("b", true)], showing: "")

    XCTAssertEqual(store.nextWallpaperID(displayId: "primary"), "a")
    XCTAssertEqual(store.nextWallpaperID(displayId: "unknown"), "a")
  }

  func testNothingToSwitchToWithOnePlayableWallpaper() {
    XCTAssertNil(makeStore(wallpapers: [("a", true), ("broken", false)], showing: "a")
      .nextWallpaperID(displayId: "primary"))
    XCTAssertNil(makeStore(wallpapers: [], showing: "").nextWallpaperID(displayId: "primary"))
  }

  private func makeStore(wallpapers: [(String, Bool)], showing: String) -> BridgeStore {
    let store = BridgeStore(bridge: WallpaperBridge(noPointer: .init()))
    store.librarySnapshot.wallpapers = wallpapers.map { id, supported in
      BridgeWallpaperEntry(
        id: id, title: id, kind: .video, supported: supported, active: id == showing,
        selected: false, previewPath: nil)
    }
    store.monitorInformationSnapshot.rows = [
      BridgeMonitorInfoRow(
        displayId: "primary", title: "Primary", wallpaperId: showing, wallpaperTitle: showing,
        mirrorTargetDisplayId: nil, mirrorTargetTitle: nil, scalingMode: "fill",
        targetFps: "30", audioResponse: false)
    ]
    return store
  }
}
