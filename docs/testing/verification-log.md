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

## 2026-09-28 — Rebase of the power change set onto origin/main f383bbd

Conflicts only in verification logs (entries unioned verbatim, oldest six archived) and provenance.json (sceneEngine.equalQualityPerformanceChanges keeps upstream's 2026-09-24 note followed by ours; upstream deferredSurfaceLifetimeChanges kept). Upstream 36359b3 SceneWallpaperBindings.mm and 2d1322a panel.js/WebControlPanel.swift touch disjoint hunks; no bridge API change upstream.

- `python3 scripts/build.py --renderer-only` — exit 0; regenerated App/Bridge/Generated unchanged
- `cargo test --release -p wallpaper-bridge --lib` (build.py cargo environment) — 349 passed; `-p wallpaper-core --lib` — 220 passed
- `python3 scripts/check_renderer.py` — exit 0; 10/10 generated cases pixel-equal pooled vs isolated, 0 diagnostics, reload cycles 0 (artifacts/renderer/adaptive-20260928-001427)
- `python3 scripts/test.py` — 650 passed, 0 failed, 11 skipped of 661; Python script suites OK
- Not run: desktop, visual or power verification; no Release build.

## 2026-09-28 — Power set pre-commit finish: R25 revert, R3/R16/R1-R4 evidence

R25 PowerWatcher restored to its original 5 s run_in_mode loop and its drop test and notes removed. New: ParticleHiddenGeometry.LayerShownByTickAfterEmittDrawsWhatAlwaysGeneratingDraws (fails with RebuildMesh stubbed out, passes as shipped); UnchangedPresent.TheSkipPresentsTheSameVideoFramesInTheSameOrder (75 distinct generations/PTS identical with the skip on and off) and OutputChangesOnAHeldVideoFramePresentOnceEach (crop, render scale, resize, fill mode), via the new observation-only RenderInitInfo::video_frame_presented. R3 late-flag bridge test already existed.

- `python3 scripts/build.py --renderer-only` — exit 0
- `python3 scripts/test.py --only RuntimeDiagnosticsReportTests --only ControlPanelDiscoverTests --only WebWallpaperRecoveryTests --only LockScreenWallpaperServiceTests` — 39 passed, 0 failed
- `cargo test --release -p wallpaper-bridge --lib` — 349 passed; `-p wallpaper-core --lib` — 220 passed (first run failed in CMake configure after the environment change, as documented; unchanged retry passed)
- `python3 scripts/check_renderer.py` — all cases pixels_equal, 0 diagnostics, reload cycles 0
- By hand: audio_tests 45, scene_schema_tests 91, mouse_input_test 12, playback_gpu_test 50, unchanged_present_test 5, particle_rope_geometry_test 27, particle_mouse_controlpoint_test 39 passed; script_runtime_compat_test 78 passed, 1 failed (HostVectorUpdatesDoNotCallMutableGlobalVectorConstructors, also fails alone and at HEAD)

## 2026-09-27 — Installed: hold-and-drag multi-select with in-context tip

- python3 scripts/test.py --only ControlPanelLibraryTests: 9 passed (new testHoldAndDragSelectsARunOfTilesWithoutWindow: stray drag ignored, hold checks, range sweep + sweep-back, ending click swallowed, sweep from checked tile clears, dragSelectLearned stored in defaults + snapshot).
- python3 scripts/test.py: 649 passed, 0 failed, 11 skipped; panel localization tests pass with the new zh-Hans strings.
- Not exercised: real mouse sweep on a desktop, edge auto-scroll (rAF does not run in the offscreen test web view), hold animation visuals, reduced-motion appearance. No Release build.

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

## 2026-09-27 — Renderer and app power work: batch 1, sibling renderer items, app side, Rust gate

- Batch 1: R1+R4 with Scene render optimisation on, a frame that would repeat the picture on the surface is not drawn, submitted or presented; unchanged_present_test 3/3 (plain video submissions track video_frames_selected, other ticks count presents_skipped_unchanged; a static scene submits 0 once every pass is reused, and its poster matches the reuse-off baseline).
- Batch 1: R2 sound output starts only while mounted, playing and unmuted; R3 system-audio tap only for scenes that read audio (or a subscribed web page); R5/R6 pointer sampling is event-armed and a paused scene is not a consumer.
- Batch 1: R21 sound worker wakes and per-chunk allocations reduced; R23 global resume never un-pauses a still-covered display; R24 no frame clock without a loaded scene.
- Other worker's renderer items: R12 decode-thread notify gating + AVDISCARD_ALL on unused streams; R13 ThreadTimer::WakeOnce latch at the ceiling; R17 audio demuxer AVDISCARD + reused convert buffer; R27 software-decode import failure logged once per failure run; R28 transparent map find, three-bucket rope sort, per-subsystem overflow log latches.
- Other worker's R16: hidden particle layers skip geometry and RebuildVisibleMeshes runs after Tick, before drawFrame; particle dumps (spritetrail/ropetrail/rope, shown and hidden) byte-identical to HEAD. R25: power watcher stops through a signalled run-loop source.
- App side: panel WKWebView uses inactiveSchedulingPolicy .suspend and keeps a pending snapshot for reveal; Discover luminance sampler runs only while visible; web-wallpaper pointer monitor only while a page is live; lock-screen unchanged path skips the compatibility check.
- Cargo, default target dir: cargo test --release -p wallpaper-core --lib 220 passed; cargo test --release -p wallpaper-bridge 351 passed (lib incl. api_smoke, playback, display_presentation, power_settings), 0 failed in either.
- Not changed: R11 (frame-clock drift), R19, R20, N1-N6.
- No desktop, visual or power verification; no Release build. Evidence is workload only; no energy saving is claimed.

## 2026-09-27 — Renderer power: R15/R22 revert, R26/R28 fixes, final gate

- R22 reverted to HEAD (generation-keyed audio array rewrite, recorded before the script runs); R15 script-property skip reverted (primitive-only skip is not less work); R15 FillDynamicValueFromJS kept (allocation-neutral refactor). resolve_auto_setting broadening, fprintf and 'false &&' removed; three tests with non-HEAD expectations removed.
- R26: rebaseline after any uncounted update and seed the selection tracker; TurningCountersOnDoesNotReportWorkAlreadyDone extended to off-then-on (mutation without the stale mark fails: 40 decodes, 8 skipped reported). Unneeded MetalVideoTextures baseline change reverted.
- R28: index overflow latch re-arms only when the unclamped count fits (the landed clamped comparison re-armed every frame).
- Targeted: playback_gpu_test 50/50, audio_tests 45/45, particle_rope_geometry_test 26/26, particle_mouse_controlpoint_test 39/39, scene_schema_tests 91/91, timer_tests 29/29, video_source_input_test 12/12, metal_video_texture_test 14/14; script_runtime_compat_test 78/79 (known HEAD failure HostVectorUpdatesDoNotCallMutableGlobalVectorConstructors).
- python3 scripts/check_renderer.py: exit 0, 24 binaries exit 0, 10/10 cases pixel-equal, reload cycles 0 (artifacts/renderer/adaptive-20260927-232229).
- python3 scripts/test.py first run: 644 passed, 1 failed, 11 skipped. ControlPanelDiscoverTests...AnimatedPreviewOnlyWhileItIsBrightWithoutWindow failed deterministically: the app-side panel sampler now runs only while !document.hidden and a windowless WKWebView reports hidden.
- Test now asserts no sampling while hidden, then simulates visibility (hidden getter + visibilitychange) before the brightness checks; removing the hidden gate fails the new assertion.
- python3 scripts/test.py rerun: 645 passed, 0 failed, 11 skipped of 656 (9 NativeVideoPlayerMediaTests + 2 WorkshopTests live, opt-in); Python script tests 187 OK. Cargo tests not run this pass.
- Not run: desktop runtime, visual and power verification.
