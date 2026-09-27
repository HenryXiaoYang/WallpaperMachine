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

## 2026-09-27 — Deployment target lowered to macOS 15

- Change: project.yml/build.py target 26.0 -> 15.0; release runner macos-26 -> macos-15 with Xcode 26 selected; lock screen off below macOS 26 (app skips the service, extension rejects the host).
- Probe: xcodebuild with MACOSX_DEPLOYMENT_TARGET=14.0 built with 0 errors; 13.0 fails on @Observable and WKWebView.inactiveSchedulingPolicy.
- package.py now compares bundled dylib minos with LSMinimumSystemVersion; raises it locally, --require-deployment-target (CI) fails instead. scripts/tests/test_package.py covers the floor.
- python3 scripts/test.py: 581 passed, 0 failed, 11 skipped. Debug app and extension binaries report minos 15.0.
- Not run: Release build, package.py, CI on macos-15. Local Homebrew dylibs are minos 26/27, so a local package still requires this host's release.
- Gap: nothing was launched on macOS 15; WebUI on Safari 18 WebKit, MediaRemote adapter and the Liquid Glass fallback are unchecked there.

## 2026-09-27 — Release build for energy readout verification

- python3 scripts/build.py --configuration Release: OK (full build; renderer sources have uncommitted changes in the tree).
- Bundle check: WebUI settings.js, panel.js, settings.css, panel.css, locales/zh-Hans.js identical to WebUI/; binary contains EnergyRatings.json and AppleSmartBattery strings.
- Delivered: build/Build/Products/Release/WallpaperMachine.app. Not launched; user verifies after quitting and reopening.

## 2026-09-27 — Energy readout: grade, battery share, before/after, per-wallpaper rating

- python3 scripts/test.py: 640 passed, 0 failed, 11 skipped (Python script tests all OK).
- Targeted: EnergyUsageMonitorTests, WallpaperEnergyRatingsTests, WebPanelEnergyUsageTests, WebPanelPerformanceSettingsTests passed (31).
- WebUI smoke in headless Chromium (throwaway harness, removed): Performance order energy→quality→playback; readout states measuring/ready/pending/after/contended in en and zh-Hans; inspector energy line rated/unrated.
- BatteryCapacity.fullChargeWattHours on this MacBook Pro: 98.5 Wh (8,532 mAh × 3 × 3.85 V).
- Not run: live app (no desktop authorization); background recorder and settingChanged wiring unobserved in the running app. Not rebuilt (no Release build).
- Gap: WKWebView rendering not checked; Chromium only.

## 2026-09-27 — Native refresh default fps; welcome guide Performance step

- cargo test -p wallpaper-bridge --release: 343 passed, 0 failed (new: native-refresh default per descriptor, legacy fps/target_fps migration, top-of-range stored as follow-native).
- python3 scripts/build.py --renderer-only: OK; bindings regenerated, API unchanged.
- python3 scripts/check_renderer.py: all generated cases pooled/isolated exit 0, pixels equal, 0 reload-cycle failures.
- python3 scripts/test.py: 630 passed, 0 failed, 11 skipped (641). First attempt failed to compile on a concurrent AppDelegate edit (startWallpaperEnergyRecorder) by another author; rerun after it landed.
- ControlPanelShellTests welcome walkthrough: 6 steps; Performance page defaults to High with Native refresh rate readout; Low + 24 fps slider stays draft, Continue sends renderScale 0.5 and frameRateCap 24.
- Not checked: visual layout of the welcome Performance page on a real display; no desktop run or Release build.
