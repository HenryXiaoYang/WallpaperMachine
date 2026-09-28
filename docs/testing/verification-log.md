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

## 2026-09-28 — Authorized Release live check for preview and snapshot optimizations

- Explicit follow-up authorization: live desktop run on source `075e85e`. `python3 scripts/build.py --swift-only --configuration Release` — exit 0; the Release app contains the modified panel asset (SHA-256 matched the source).
- Release app launched with an isolated `WALLPAPER_MACHINE_HOME`; initial user desktop image URLs and app preferences were saved locally. Apple M5 Pro, macOS 27.0, built-in 3024×1964 display at 120 Hz; default Compatibility video, native render scale.
- Live functional checks: real Discover results and animated-preview cache loaded; Settings/Installed navigation and hide/reopen remained responsive. Aurora Drift applied through the UI and the renderer logged first-frame readiness. Pause and resume controls changed state correctly; timer stop/start and occlusion suspension/resume appeared in the runtime log. No Release-process crash.
- CPU/RSS sampled for the Release resource coalition, including its WebKit services. Discarded active-playback comparison: foreground changed repeatedly, and a separate Debug instance began running with the same bundle ID. No matched pre-change baseline or reliable whole-app CPU/RAM saving is claimed.
- UI targeting switched to the exact Release PID after detecting the second instance. Scrolling was attempted but its viewport movement and animation pixels were not independently verified; source-release behavior remains covered by the passing headless regression.
- Restoration: requested graceful termination of the Release PID only; it exited and logged renderer teardown. Desktop image URLs match the pre-run records. Other Debug instance left running. Only the shared window-frame preference differed; it was not overwritten while another instance owned it.
- No screenshots, screen/audio capture, live Steam login, installation, lock-screen/sleep-wake tests, or quality/default changes. Previous passing headless gates remain applicable; this follow-up changed documentation only.

## 2026-09-28 — Reduce invisible preview retention and repeated storage scans

- `scripts/test.py` with installed CPython 3.12.14 — exit 0; 190 Python tests passed; 660 native passed, 11 skipped, 0 failed. Initial Python 3.9 attempt stopped in unchanged brand tests (`zip(strict=True)`); the interpreter requirement is now in the testing guide.
- `python3 scripts/test.py --only ControlPanelDiscoverTests` — exit 0; 6 passed. Extended regression covers hidden loading, offscreen source release, scrolling/visibility resume, Settings retirement, still fallback and one download per URL.
- New Discover regression against unmodified upstream `panel.js` — failed as expected because hidden animations retained sources; modified code passes in the full gate.
- `cargo test --release -p wallpaper-bridge --lib` with the build environment — exit 0; 360 passed. A burst of 1,001 size requests performs one walk; expiry and explicit invalidation remeasure. Actor test covers immediate cache growth and clearing.
- `python3 scripts/build.py --renderer-only` — exit 0; rebuilt the bridge and regenerated bindings; no interface changes.
- `python3 scripts/check_renderer.py` — exit 0; 23 test binaries, 10 generated scenes with matching pooled/isolated pixels and no diagnostics, and 8 synthetic projects reloaded twice. Three asset-dependent cases skipped (two text scenes and native local-project coverage).
- Synthetic Rust 2024 optimized probe using production directory-size/cache methods: 1,000 queries over 256 files of 1 KiB, five runs per variant. Median elapsed 239.714 ms before vs 0.449 ms cached; ranges 237.600–251.058 ms vs 0.418–0.523 ms. Workload timing only; tiny RSS differences and rounded CPU-time samples do not establish app memory/CPU savings.
- Reviewed frame scheduling, bounded video queues, shared-decoder ownership, native-video teardown, web-audio subscription loops and extension surface release; no additional renderer/quality/default changes were justified.
- Headless only: desktop CPU/RAM, visual behavior, live Steam and opt-in media tests unverified. No wallpaper changes, desktop capture, app launch/restart or Release app delivery build.

## 2026-09-28 — Reconcile keeps unchanged scenes; launch-at-login read once per burst

Follow-up to 4ee91e5: full reconciles (Apply, display edits, backend switch, repair) now hand the engine live descriptors (frame-rate ceiling and transient mute applied), and the launch-at-login status is read from SMAppService at most every two seconds.

- `cargo test --release -p wallpaper-bridge` (build env) — before the fix `a_reconcile_does_not_reload_a_scene_held_to_the_frame_rate_cap` and `::…_muted_for_other_audio` failed (handed fps 120 / unmuted vs running 60 / muted); after: 359 passed, 0 failed, including the four `a_display_refresh_does_not_reload_*` tests from 4ee91e5
- `python3 scripts/build.py --renderer-only` — exit 0; regenerated bindings identical
- `python3 scripts/test.py` — exit 0; Python modules all OK; native 671: 660 passed, 11 skipped (opt-in layers)
- `python3 scripts/check_renderer.py` — exit 0; 10 generated scenes pooled and isolated exit 0, pixels equal, 0 diagnostics; reload cycles (8 projects x2): 0
- Not verified: a Release build or the live desktop; no manual unlock/Apply run against a real display

## 2026-09-28 — Update check via release manifest instead of GitHub API

- python3 scripts/test.py: 660 passed, 0 failed, 11 skipped; AppUpdateTests 41/41 incl. 4 manifest tests; test_update_manifest.py 3/3
- Mutation: dropping GitHubRedirectGuard fails testManifestRedirectOffGitHubIsNotFollowed (/elsewhere requested)
- actionlint .github/workflows/build.yml: clean
- CI publish steps simulated locally with a stub gh: manifest written beside the image, digest equals the .sha256 sidecar, uploaded with image and sidecar
- Throwaway Swift binary (real AppUpdateModels + GitHubReleaseClient) over local HTTP: Python-written manifest decoded, arm64 dmg selected, digest parsed, API URL never requested; missing manifest fell back to the API
- Live github.com: real releases/latest/download redirect chain followed to release-assets (0 API requests used); redirect to raw.githubusercontent.com refused as a network error; default client read v1.0.2 via API fallback at exactly 1 API request per check
- Not run: a real release carrying the manifest (first one is the next Build run); no Release app build

## 2026-09-28 — Lock-screen exchange directory (no App Data prompt)

- Cause: tccd log showed kTCCServiceSystemPolicyAppData AUTHREQ_PROMPTING on every launch; app wrote/read ~/Library/Containers/app.wallpapermachine.wallpaper-extension (ad-hoc signed, grant not persisted).
- Fix: app and extension exchange via ~/Library/Application Support/WallpaperMachine/LockScreenExchange; extension gets home-relative read-write exception; extension removes legacy container files.
- python3 scripts/test.py --only LockScreenWallpaperServiceTests --only DiagnosticsBundleTests: 20 passed.
- python3 scripts/test.py: 651 passed, 0 failed, 11 skipped.
- Sandbox smoke: ad-hoc CLI signed with Extension entitlements resolved real home, read/wrote exchange, denied writes outside and reads of app-private LockScreen/.
- Not run: live lock-screen activation on desktop (no desktop authorization); Release not rebuilt.

## 2026-09-28 — Display refresh no longer reloads an unchanged scene; lock screen ignores the covered desktop

User report on 1.0.2 (Workshop 3521337568, Lucy): lock screen held a still frame, and after unlocking the desktop flashed white and restarted the opening animation. App logs showed 107-425 scene loads per session, one per queued display refresh; the extension log showed the lock-screen scene exported as paused (reasons=1) right after the desktop display was suspended by occlusion.

- Bridge tests written first and failing on HEAD: settings_intents::a_display_refresh_does_not_reload_a_scene_{whose_audio_response_has_nothing_to_read,held_to_the_battery_frame_rate,muted_for_other_audio,paused_by_a_lock_or_a_covered_display} and apply_options::lock_screen_export_ignores_the_desktop_display_being_covered (5 failed before the fix).
- `cargo test --release -p wallpaper-bridge --lib` (build.py cargo environment) — exit 0; 354 passed, 0 failed.
- `python3 scripts/test.py --only DisplayRefreshCoalescerTests` — 2 passed (first attempt stopped at the known CodeSign xattr detritus; cleared with xattr -cr on the Debug app).
- `python3 scripts/test.py` — exit 0; 652 passed, 0 failed, 11 skipped of 663.
- `python3 scripts/check_renderer.py` — exit 0; 23 test binaries passed, 10 generated fixtures pixel-equal pooled vs isolated, reload cycles 0 failures.
- Not verified: the lock/unlock and display-wake behaviour on the desktop (no desktop run authorised), and no Release build was made. Apply, display edits and repair reconciles still compare saved values, so they can still reopen a scene held to a frame-rate ceiling or transient mute, as in 1.0.1.

## 2026-09-28 — Panel stays open after applying; Command-W closes it

Settings → General → Hide window after applying a wallpaper now defaults to off (a stored choice is kept). The main menu gains File → Close (Command-W), which goes through the panel's windowShouldClose like the close button.

- `python3 scripts/test.py --only WebPanelGeneralSettingsTests` — exit 0; 1 passed (first attempt stopped at CodeSign on Finder/file-provider xattrs on the Debug bundle; cleared with `xattr -cr`)
- `python3 scripts/test.py` — exit 0; Python suites OK; native 661: 650 passed, 11 skipped, 0 failed
- `xcodebuild build-for-testing -scheme WallpaperMachineUI` — TEST BUILD SUCCEEDED; the new `testCommandWClosesLikeTheCloseButton` compiles but was not run
- Not exercised: Command-W and the panel staying open after Apply on the desktop (no desktop run requested); no Release build

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
