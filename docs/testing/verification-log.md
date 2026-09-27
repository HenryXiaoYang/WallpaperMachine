# Verification log

Append-only history of what was actually verified, when, and with what result.
The newest entry goes on top; never rewrite an older entry to match today's
tree. Every entry is evidence about the tree it was taken on, not about the
current one — re-run the relevant checks after integration and add a new entry
instead of reusing an old result. Durable guidance belongs in the sibling docs:
test layers and policy in [README.md](README.md), renderer commands and
regression areas in [renderer.md](renderer.md), manual checks in
[manual-smoke.md](manual-smoke.md). Result bundles and probe output are local
and disposable, so entries state counts and commands rather than artifact
paths.

Entry format, so the log stays skimmable: a one-line summary heading, one short
paragraph of context only when the result needs it, then a bullet per command
with its exit status, counts and any skip. Keep an entry around ten lines. A
fact that will still matter next week is not an entry — promote it to the doc
that owns it (renderer behaviour and known-failing tests to
[renderer.md](renderer.md), build and signing traps to
[../build.md](../build.md)) and cite it from there.

Retention: this file keeps the ten newest entries. When it grows past that,
move the oldest entries verbatim into
[archive/verification-log-2026-09.md](archive/verification-log-2026-09.md)
(or a new dated archive file) first, and promote anything durable before it
goes. Trimming is allowed; editing an entry's recorded result is not.

## 2026-09-27 — Updater: staged restart-install, writability gate, release certificate signing

- Fix 1: AppUpdateInstaller.canReplace requires a writable bundle and folder; startReplacement stages the new app beside the old, swaps by rename, restores and reopens the previous app on any failure.
- Repro before: old script (rm -rf then ditto) with a missing source left Applications empty and never reopened.
- python3 scripts/test.py --only AppUpdateTests: 33 passed (new: canReplace permission, successful swap, failed swap keeps and reopens old app).
- Fix 2: package.py --sign-identity; build.yml imports SIGNING_CERTIFICATE_P12/PASSWORD (set on repo) into a temp keychain and fails without them.
- Local CI-step replay on a copy of the Release app: import ok, codesign --verify --deep --strict ok, DR = identifier app.wallpapermachine and certificate root = H"2bdf...fa82" (was cdhash); extension keeps app-sandbox; missing-secret path exits 1.
- python3 scripts/test.py: 648 passed, 0 failed, 11 skipped.
- Not exercised: a real CI release run, launching a certificate-signed app, lock-screen extension loading under the new signature, TCC persistence across an actual update (no desktop run authorized); no Release build.
- 1.0.1 -> 1.0.2 still uses 1.0.1's installer and ad-hoc grants; fixes apply from 1.0.2 onward.

## 2026-09-27 — Release build

- python3 scripts/test.py: 648 passed, 0 failed, 11 skipped
- python3 scripts/build.py --configuration Release: OK; bundled WebUI matches WebUI/

## 2026-09-27 — Deferred Metal layer lifetime on upstream 1.0.1

- Based on upstream main 5286e70 (1.0.1). Kept a97e1e1 CopyPass teardown and its regression unchanged; this patch only retains the layer during deferred backend selection and adds ownership coverage.
- uv run --no-project --python 3.12 python scripts/build.py --renderer-only: exit 0; renderer/bridge rebuilt and Swift bindings regenerated with no generated-source diff.
- uv run --no-project --python 3.12 python scripts/test.py: exit 0; Python phase passed (187 tests reported), native phase 645 passed, 0 failed, 11 skipped.
- uv run --no-project --python 3.12 python scripts/check_renderer.py: exit 0; 466 passed, 3 skipped; all 10 generated scenes passed pooled/isolated and expected-pixel checks; 8 projects reloaded twice.
- The new SceneSurface.DeferredBackendRetainsTheLayerUntilTheSceneIsDeleted regression passes; Core Animation transactions and temporary weak-reference reads are drained before ownership assertions.
- Skipped: 9 opt-in native-video tests, 2 live Workshop tests, 2 private text-scene checks and the optional local Metal scene corpus.
- Earlier build 46efd59 with the same lifetime fix was packaged, installed and opened in the explicitly requested desktop check: saved scenes reached first frame and the panel opened; no new crash report was observed. Shader-compilation and desktop-poster diagnostics remained. This rebased tree was verified headlessly only, not installed or live-tested.
- git diff --check passed. Crash reports, screenshots, local logs and wallpaper assets remain uncommitted.

## 2026-09-27 — Release CI: app icon compiled on macOS 26; 1.0.1 re-cut

- Cause of the failed v1.0.1 build: on macos-15, Xcode 26.0.1-26.3 actool compiled AppIcon.icon in 6 of 30 probe attempts (exit 255); 30 of 30 on macos-26; Assets.xcassets alone 8 of 8 on macos-15.
- Fix: build.yml app-icon job (macos-26) runs build.py --compile-app-icon; build (macos-15) uses --app-icon; test job moved to macos-26; cache keys carry the runner macOS; warm-caches runs both.
- Branch validation runs (ci-probe-actool, deleted): app-icon OK; test on macos-26 643/1 failed -> EnergyUsageMonitorTests live-counter check now skipped in VMs; build failed on Xcode 26.3 type-check timeout in WebPanelSnapshot -> literal split.
- Local: --app-icon Debug build carries the compiled Assets.car/AppIcon.icns, CFBundleIconName/File, codesign verify OK; Release type-check with 100 ms warning threshold clean; python3 scripts/test.py 645 passed, 0 failed, 11 skipped.
- Bump f8c439b reverted and remote tag v1.0.1 deleted (no release existed); 1.0.1 re-released by the Version workflow from this push. Final proof is that run.

## 2026-09-27 — Automatic update check, background download and prompt

- Live smoke (shipped 1.0.0 client code): GitHub API via bobbyhuang-dev rename redirect -> v1.0.0, asset WallpaperMachine-1.0.0-arm64.dmg downloaded (33426526 B, sha256 verified), hdiutil attach + ditto extract + validate passed.
- Live smoke: new repository constant WallpaperMachine/WallpaperMachine resolves latest release and selects the arm64 dmg.
- python3 scripts/test.py --only AppUpdateTests: 30 passed (new testBackgroundUpdateDownloadsOnlyWhatItCanInstallInPlace).
- python3 scripts/test.py: 645 passed, 0 failed, 11 skipped.
- Not exercised: the NSAlert prompt, status-menu item and 6-hour schedule in the running app (no desktop run authorized); no Release build.

## 2026-09-27 — Launch crash: CopyPass left prepared across render-scale rebuild

- Cause: crash reports 2026-09-27 13:45-13:48 SIGSEGV in MVKCmdCopyImage::validate from CopyPass::execute after 'render scale applied: 0.750'; CopyPass::destory was a no-op, so applyRenderScale re-prepared every pass except the copy, which kept freed image handles.
- Fix: CopyPass::destory resets prepared, release list and vk_src/vk_dst; provenance.json and docs/testing/renderer.md updated.
- Regression: PlaybackGPU.CopyPreparesAgainAfterRenderTargetsAreDroppedAndResized failed before the fix (copy.prepared() stayed true), passes after; playback_gpu_test 41/41.
- python3 scripts/check_renderer.py: all binaries exit 0, generated cases pixel-equal, reload cycles 0 failures.
- python3 scripts/test.py: 644 passed, 0 failed, 11 skipped.
- python3 scripts/build.py --configuration Release: OK; built binary's CopyPass::destory disassembly clears the prepared flag and image parameters.
- Not run: app launch on the desktop (not authorized); the user's config (render_scale 0.75, cs2 scene 3373259209) was not exercised live.

## 2026-09-27 — Release build 1.0.1 (929b3c1 + scripts/lib/xcode.py log patterns)

- python3 scripts/test.py: 644 passed, 0 failed, 11 skipped of 655.
- python3 scripts/build.py --configuration Release: OK (full build incl. renderer and bindings).
- Bundle WebUI matches WebUI/ (diff -rq); CFBundleShortVersionString 1.0.1; codesign --verify --deep --strict OK.
- Delivered: build/Build/Products/Release/WallpaperMachine.app. Not packaged, not launched.

## 2026-09-27 — Release CI: parallel build/test jobs and build caches

- Build workflow split into build + test (parallel macos-15) and publish (ubuntu, needs both); shared setup in .github/actions/prepare-build; warm-caches.yml keeps entries alive.
- actionlint 1.7.12 on .github/workflows/*.yml: clean. Composite action YAML parsed.
- ccache probe (throwaway, fresh CARGO_TARGET_DIR, CMAKE_*_COMPILER_LAUNCHER=ccache): cold 67 s with 105 misses; second fresh build 48 s with 104 direct hits, so the cmake crate's CMake honors the env launcher.
- Homebrew probe: with no tap providing mwe-ffmpeg, brew list --versions and brew --prefix still resolve the keg, so a restored Cellar keg needs only its opt link; install_ffmpeg.py unchanged.
- python3 scripts/test.py: script modules now run concurrently (phase ~9 s, bounded by test_dmg); 644 passed, 0 failed, 11 skipped.
- Not verified: the workflows themselves. Build runs only from Version or a tag push; first real run is the next release. Check both jobs' ccache --show-stats and the three cache restores there.

## 2026-09-27 — Rebase onto origin/main (macOS 15, hide-after-apply) before 1.0.1

- Conflicts resolved: settings.js keeps 'Hide window after applying a wallpaper' and drops General 'Pause on battery' (now Performance battery mode); pbxproj regenerated with xcodegen; verification logs merged, oldest entries archived.
- python3 scripts/test.py: 644 passed, 0 failed, 11 skipped of 655; Python script suites OK.
- Not run: Release build, check_renderer.py (no renderer change in the merge), desktop checks.

## 2026-09-27 — Hide-after-apply setting; Next Wallpaper and Lock Screen menu items

- Settings > General gains 'Hide window after applying a wallpaper' (default on, UserDefaults WallpaperMachine.hideAfterActivating); activate only calls NSApp.hide when it is on.
- Status menu: Next Wallpaper (BridgeStore.nextWallpaperID: next supported library wallpaper on the target display, wrapping) and Lock Screen (SACLockScreenImmediate via dlsym, omitted if missing).
- New tests: NextWallpaperTests (order, skip unsupported, wrap, single wallpaper), WebPanelGeneralSettingsTests (default on, persists off).
- python3 scripts/test.py: 585 passed, 0 failed, 11 skipped.
- Checked only that the lock symbol resolves (dlsym); the lock itself, the menu and the settings row were not exercised on the desktop. No Release build.

