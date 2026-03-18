# HeartGold Opening Menu Parity

## Goal

Ship a native macOS HeartGold boot flow that:

1. plays the opening movie with source-backed timing and transitions
2. runs the title screen with source-backed prompt flashing, fades, camera motion, and exit behavior
3. hands off into `gApplication_CheckSave`
4. reaches `gApp_MainMenu`

The target is parity with the official source-backed behavior, not a handcrafted approximation.

## Completed Baseline

- [x] `HGSSExtractCLI` emits `opening_bundle.json` and `opening_program_ir.json`.
- [x] `HGSSRender` loads `opening_program_ir.json`.
- [x] The playback controller no longer stops at the first `title_handoff` frame when IR is available.
- [x] The runtime advances through the initial title-screen state machine, including prompt flash timing and title fade sequencing.
- [x] The parser and IR include `application/check_savedata.c` and `application/main_menu/main_menu.c`.
- [x] The runtime routes from title fadeout into source-backed `CheckSave` and `MainMenu` scenes using default post-title flags.
- [ ] The post-title visuals are still semantic SwiftUI stand-ins, not exact DS-rendered output.

## Parity Checklist

### Phase 1: Finish Source-Backed Opening IR

- [ ] Lower `intro_movie_scene_1.c` through `intro_movie_scene_5.c` into concrete IR commands for fades, windows, scrolls, viewport masks, and scene-local timing.
- [ ] Replace the remaining regex-only title extraction with AST-backed lowering for `TitleScreen_Main`, `TitleScreen_Exit`, and `TitleScreenAnim_Run`.
- [x] Add byte-stable snapshot coverage for parser-derived `opening_program_ir.json` built from real parsed upstream inputs.
- [x] Expand title-screen IR to cover all exit modes explicitly: `TITLESCREEN_EXIT_MENU`, `TITLESCREEN_EXIT_TIMEOUT`, `TITLESCREEN_EXIT_CLEARSAVE`, and `TITLESCREEN_EXIT_MIC_TEST`.
- [ ] Expand `CheckSave` IR from the current default route into full save-status routing for clean save, corrupted save, erased save, and battle hall/video error variants.
- [ ] Expand `MainMenu` IR from the current core button subset into full source-backed availability routing for continue, new game, pokewalker, mystery gift, ranger, migrate AGB, connect to Wii, WFC, and Wii settings.

### Phase 2: Finish Native Title Runtime

- [ ] Replace the remaining title-screen duplicated behavior in `HGSSRender` with IR-driven sequencing and overlays.
- [ ] Extract and render the title prompt window with source-backed text layout and exact DS-style text output.
- [ ] Reproduce title-screen palette fades, glow behavior, and screen-plane toggles without relying on ad hoc view logic.
- [ ] Replace the current title SceneKit dependency with a source-backed native playback path or deterministic baked frames for the title subset.
- [x] Add input handling for all title exit paths, not just the menu request path.

### Phase 3: Add Menu Handoff Runtime

- [ ] Replace the current semantic `CheckSave` stand-in with extracted BG/window/text assets and exact timing.
- [ ] Add runtime flag plumbing from real save-status data into the `CheckSave` scene router.
- [ ] Replace the current semantic `MainMenu` stand-in with extracted graphics, button borders, arrow sprites, and source-backed scroll behavior.
- [ ] Add runtime flag plumbing from real save data and feature availability into the `MainMenu` router.
- [ ] Reach the first stable interactive menu state without relying on synthetic defaults.
- [ ] Add native handling for menu navigation, confirmation, and overlay dispatch from the first interactive menu state.

### Phase 4: Exact Subsystem Parity

- [ ] Add a native 2D compositor for DS BG, OBJ, window, blend, and text rules used by title, `CheckSave`, and `MainMenu`.
- [ ] Replace SwiftUI prompt/message/menu text drawing with DS-style glyph rendering sourced from the extracted font path.
- [ ] Add a native audio core for the opening/title cue subset so BGM fades, stop timing, and cry timing are source-accurate.
- [ ] Replace parity-critical SceneKit usage with a native 3D subset or deterministic frame baker for the opening/title assets.
- [ ] Finish the scene 4 particle path so the full opening remains exact while the menu work lands.

### Phase 5: Proof Of Parity

- [ ] Add per-frame visual diffing for opening scenes, title states, `CheckSave`, and `MainMenu`.
- [ ] Add audio waveform and trace diffs for title/opening cue playback.
- [ ] Add extracted trace comparisons for title exit mode, `CheckSave` routing, and menu setup state.
- [x] Add snapshot tests for the committed IR surface: scene order, state order, title prompt metadata, `CheckSave` message routing, and `MainMenu` option routing.
- [ ] Do not call the milestone complete until the native app reaches `MainMenu` with no known visual, timing, or audio regressions against the extracted references.

## Definition Of Done

This milestone is done when the native macOS app can be launched from the repo and:

1. [ ] Run the HeartGold opening from scene 1 through scene 5.
2. [ ] Enter the title screen and accept title input.
3. [ ] Transition through `CheckSave`.
4. [ ] Display the interactive `MainMenu`.
5. [ ] Pass the parity harness for timing, visuals, and audio across that full path.
