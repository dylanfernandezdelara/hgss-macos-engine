# HeartGold Opening Menu Parity

## Goal

Ship a native macOS HeartGold boot flow that:

1. plays the opening movie with source-backed timing and transitions
2. runs the title screen with source-backed prompt flashing, fades, camera motion, and exit behavior
3. hands off into `gApplication_CheckSave`
4. reaches `gApp_MainMenu`

The target is parity with the official source-backed behavior, not a handcrafted approximation.

## Current State

- `HGSSExtractCLI` emits `opening_bundle.json` and `opening_program_ir.json`
- `HGSSRender` now loads `opening_program_ir.json`
- the playback controller no longer stops at the first `title_handoff` frame when IR is available
- the runtime advances through the initial title-screen state machine, including prompt flash timing and title fade sequencing
- the app still stops at the title-to-menu handoff boundary; it does not yet render `CheckSave` or `MainMenu`

## Todo Ladder

### Phase 1: Finish Source-Backed Opening IR

1. Lower `intro_movie_scene_1.c` through `intro_movie_scene_5.c` into concrete IR commands for fades, windows, scrolls, viewport masks, and scene-local timing.
2. Remove the remaining regex-derived opening/title timing and transition metadata once IR coverage is complete.
3. Add byte-stable snapshot coverage for `opening_program_ir.json` built from real parsed upstream inputs.
4. Expand title-screen IR to cover exit modes explicitly: `TITLESCREEN_EXIT_MENU`, `TITLESCREEN_EXIT_TIMEOUT`, `TITLESCREEN_EXIT_CLEARSAVE`, and `TITLESCREEN_EXIT_MIC_TEST`.

### Phase 2: Finish Native Title Runtime

1. Replace the remaining title-screen duplicated behavior in `HGSSRender` with IR-driven sequencing and overlays.
2. Extract and render the title prompt window with source-backed text layout and exact DS-style text output.
3. Reproduce title-screen palette fades, glow behavior, and screen-plane toggles without relying on ad hoc view logic.
4. Replace the current title SceneKit dependency with a source-backed native playback path or deterministic baked frames for the title subset.

### Phase 3: Add Menu Handoff Runtime

1. Parse and model `application/check_savedata.c` as the first post-title overlay boundary.
2. Extract the visual and message assets required for the `CheckSave` screen.
3. Add a native `CheckSave` runtime path that matches the upstream overlay state flow and save-status handling.
4. Parse and model `application/main_menu/main_menu.c` for the menu setup, fade-in, button layout, scroll behavior, and selection state.
5. Extract the graphics, sprites, text, and message assets required by `MainMenu`.
6. Add a native `MainMenu` runtime path that reaches the first stable interactive menu state.

### Phase 4: Exact Subsystem Parity

1. Add a native 2D compositor for DS BG, OBJ, window, blend, and text rules used by title, `CheckSave`, and `MainMenu`.
2. Add a native audio core for the opening/title cue subset so BGM fades, stop timing, and cry timing are source-accurate.
3. Replace parity-critical SceneKit usage with a native 3D subset or deterministic frame baker for the opening/title assets.
4. Finish the scene 4 particle path so the full opening remains exact while the menu work lands.

### Phase 5: Proof Of Parity

1. Add per-frame visual diffing for opening scenes, title states, `CheckSave`, and `MainMenu`.
2. Add audio waveform and trace diffs for title/opening cue playback.
3. Add extracted trace comparisons for title exit mode and menu setup state.
4. Do not call the milestone complete until the native app reaches `MainMenu` with no known visual, timing, or audio regressions against the extracted references.

## Definition Of Done

This milestone is done when the native macOS app can be launched from the repo and:

1. run the HeartGold opening from scene 1 through scene 5
2. enter the title screen and accept title input
3. transition through `CheckSave`
4. display the interactive `MainMenu`
5. pass the parity harness for timing, visuals, and audio across that full path
