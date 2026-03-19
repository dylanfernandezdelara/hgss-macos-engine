# Tooling Optimizations

## Goal

Shorten the native opening/menu parity development loop by removing avoidable rebuilds, extractor reruns, and fixture-maintenance overhead.

## Todo List

- [ ] `T1` Remove the external `swift-testing` package dependency and use the toolchain `Testing` module directly.
  Current blocker: this SwiftPM/Xcode 26.2 setup still does not expose `Testing` to the package without the dependency, even after moving the manifests to Swift 6 tools mode.
- [x] `T2` Separate SwiftPM scratch paths for extractor, test/parity, and app-shell commands so long-running tasks stop contending on the same `.build` state.
- [x] `T3` Add extracted-content freshness detection so `run_extractor_stub.sh` skips work when the opening content fingerprint is unchanged.
- [x] `T4` Add explicit `--refresh-content` and `--skip-extract` flags to the app/parity scripts so refresh behavior is controllable instead of implicit.
- [x] `T5` Collapse the opening/menu parity harness into a single `swift test` invocation instead of four sequential filtered launches.
- [x] `T6` Add a dedicated parity-fixture recorder so IR digests and opening parity snapshots can be refreshed intentionally in one command.
- [x] `T7` Split fast parity checks from the full proof path with a dedicated full-proof script.
- [x] `T8` Add extractor progress and timing output so long offline passes are observable instead of appearing hung.
- [x] `T9` Add a native screenshot helper for `HGSSMac` so visual regressions can be inspected without manual screen grabs.

## Commands

- Fast parity check: `./scripts/run_opening_menu_parity_harness.sh`
- Full parity check with refresh: `./scripts/run_opening_menu_parity_harness.sh --refresh-content`
- Record parity fixtures: `./scripts/record_opening_menu_parity_fixtures.sh --refresh-content`
- Full proof path: `./scripts/run_opening_menu_full_proof.sh`
- Capture a native app screenshot: `./scripts/capture_hgssmac_screenshot.sh --skip-extract`
- Launch the app fullscreen: `./scripts/run_app.sh --skip-extract --fullscreen`
