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

## 2026-09-28 — Release the closed control panel to reduce memory

- Panel lifecycle follow-up: CPython 3.12.14 scripts/test.py --only ControlPanelWindowSizingTests --only ControlPanelShellTests --only ControlPanelSyncTests passed 30/30. Earlier full gate is recorded separately; not repeated.
- scripts/build.py --swift-only --configuration Release passed; installed signed result into /Applications/WallpaperMachine.app with the previous bundle backed up.
- Codex computer use confirmed original scene playback, close/reopen, Settings navigation and restoration of the last native section. No quality, audio, power or renderer settings changed.
- Old installed build retained 121.6 MiB across WebKit GPU/WebContent/Networking after closing. Updated build released WebContent/Networking immediately and GPU after its idle timeout.
- Same updated main PID 88547: total app coalition plus separate installed extension 904.6 MiB with panel open, 790.0 MiB after close and helper exit; main 734.8 to 734.7 MiB. This isolates panel residency, not a build-to-build benchmark.
- Fresh startup remained above 1 GiB before freed decode allocations were reclaimed; closing the panel does not solve the remaining scene texture/renderer memory.
- Existing native Metal local-scene harness drew 120 frames at 3840x2160; no demonstrated memory win and no live backend switch. Raw-mip copy experiment did not apply to this scene’s embedded PNGs and was removed.
- Local imports retain the hidden page until the next close to avoid cancellation. This exception was reviewed but not exercised with a real file picker; real lock/unlock remains pending user operation.

## 2026-09-28 — Reduce active-scene reservations and release unlocked lock-screen renderer

- Memory follow-up to the active-wallpaper report, not an idle-panel result. User approved unloading the unlocked lock-screen renderer and cold reloading on the next lock; original texture resolution, render scale, frame-rate ceiling and playback settings remain unchanged.
- `scripts/test.py` with CPython 3.12.14 — exit 0; 190 Python passed, 663 native passed, 11 skipped. Final `python3 scripts/test.py --only WallpaperPresentationAuthorityTests` — 14 passed; covers retained-poster eligibility, paused/sleeping/host-suspended reload refusal, and failed-reload retry boundaries.
- `python3 scripts/check_renderer.py` — exit 0; 23 test binaries, ten generated pixel comparisons, eight synthetic projects reloaded twice. Three asset-dependent cases skipped. Allocator regression fails under the prior policy (about 160 MiB unused retained allocation) and passes with the 32 MiB Apple block policy.
- Current local scene, three-frame offscreen comparison: allocator reservation 632,029,696 → 514,261,760 bytes (−112.3 MiB); live allocation 479,332,096 bytes unchanged; all three output frames byte-identical. Probe now reports image extents/allocation requirements, retired-upload allocator totals and process footprint/peak separately.
- `scripts/build.py --renderer-only` and `scripts/build.py --swift-only --configuration Release` — passed. Installed into `/Applications/WallpaperMachine.app`, signature checked, backups retained. Desktop-control actions used Codex computer use.
- Live unlocked-session observation on the same selected scene: earlier vmmap main 820.4 MiB and extension 624.8 MiB; final main 745.9–749.9 MiB and extension 38.7 MiB. Final app coalition plus separately measured extension: 915.5–923.9 MiB over three samples ten seconds apart. No claim that the remaining roughly 0.9 GiB is a solved low-memory target.
- Extension log confirms first-frame readiness followed by renderer unload while retaining its poster. Actual lock/unlock reload verification is pending user participation. No texture downsampling was applied; two 7680×4320 input images each require about 173 MiB on this scene.
- Corrected test-bundle extension registration pollution: unregistered non-installed copies, renamed the two task-owned benchmark apps to non-launchable backup bundles, and verified the single registered/running extension is under `/Applications`. Config comparison confirmed playback, quality, power and monitor assignments unchanged.
- Heap-pressure and prefetch/upload-overlap experiments were removed: no reliable useful gain on this scene (heap call reported zero; peak probe change about 6 MiB). Their measurements are not credited to the final change. Private wallpaper pixels, app copies and traces stay out of Git.

## 2026-09-28 — Release before-after resource measurements with Codex computer use

- Built baseline and modified Release bundles with `python3 scripts/build.py --configuration Release`; both exit 0. Baseline restores the four changed production files from `31fb981`; modified code is `075e85e` (subsequent commits are docs). Current source and normal Release build restored; benchmark bundles use isolated homes and identical signing treatment.
- Used Codex built-in computer use for the final A/B UI sequence. Same 1054×659 panel, Chinese locale, same 30 displayed Discover titles, six page-scrolls down and six up, then Command-W. No active wallpaper or quality/default changes. Both sessions seeded with the same 120 thumbnail-cache files, verified byte-identical; live adjacent-page prefetch differed by one unused animated preview/still pair.
- Collected three approximately 22-second closed-panel windows per build, 21 samples each. Every sample verified no on-screen test panel, exactly one WallpaperMachine instance, and a stable resource-coalition process set. These are repeated windows within one app session per build, not independent launches. Interrupted foreground attempts excluded.
- App plus helper CPU: baseline median 0.64%, range 0.25–1.02%; modified median 0.60%, range 0.45–3.94%. Ranges overlap and the first modified window was higher: no demonstrated idle-CPU improvement. Mach-absolute rusage times converted with the local 125/3 timebase, checked against ps cumulative CPU time.
- Physical footprint: baseline median 248.6 MiB, range 248.6–248.7; modified median 186.0 MiB, range 185.7–199.9. Observed difference −62.6 MiB (25.2%) in this browsing/closed-panel comparison, not a general playback or system-RAM claim.
- Summed process RSS: baseline median 551.4 MiB, range 551.0–551.5; modified median 426.5 MiB, range 426.3–432.2. Observed difference −125.0 MiB (22.7%). RSS may double-count shared pages; physical footprint is reported separately.
- Both benchmark apps quit through Codex computer use and their exit was verified. App preferences restored to the pre-run snapshot; no wallpaper was applied during this comparison. Existing app-code gates remain applicable; only documentation changed afterward.
- Limits: foreground/active-playback CPU and RAM still unmeasured under controlled conditions; the public Workshop page and neighboring-page prefetch are not a frozen network fixture. No broad CPU-saving or all-wallpapers RAM-saving percentage is claimed.

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
