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
- the parser and IR now include `application/check_savedata.c` and `application/main_menu/main_menu.c`
- the runtime can route from title fadeout into source-backed `CheckSave` and `MainMenu` scenes using default post-title flags
- the post-title visuals are still semantic SwiftUI stand-ins, not exact DS-rendered output

## Todo Ladder

### Phase 1: Finish Source-Backed Opening IR

1. Lower `intro_movie_scene_1.c` through `intro_movie_scene_5.c` into concrete IR commands for fades, windows, scrolls, viewport masks, and scene-local timing.
2. Replace the remaining regex-only title extraction with AST-backed lowering for:
   - `TitleScreen_Main`
   - `TitleScreen_Exit`
   - `TitleScreenAnim_Run`
3. Add byte-stable snapshot coverage for `opening_program_ir.json` built from real parsed upstream inputs.
4. Expand title-screen IR to cover all exit modes explicitly:
   - `TITLESCREEN_EXIT_MENU`
   - `TITLESCREEN_EXIT_TIMEOUT`
   - `TITLESCREEN_EXIT_CLEARSAVE`
   - `TITLESCREEN_EXIT_MIC_TEST`
5. Expand `CheckSave` IR from the current default route into full save-status routing:
   - clean save
   - corrupted save
   - erased save
   - battle hall/video error variants
6. Expand `MainMenu` IR from the current core button subset into full source-backed availability routing:
   - continue
   - new game
   - pokewalker
   - mystery gift
   - ranger
   - migrate AGB
   - connect to Wii
   - WFC
   - Wii settings

### Phase 2: Finish Native Title Runtime

1. Replace the remaining title-screen duplicated behavior in `HGSSRender` with IR-driven sequencing and overlays.
2. Extract and render the title prompt window with source-backed text layout and exact DS-style text output.
3. Reproduce title-screen palette fades, glow behavior, and screen-plane toggles without relying on ad hoc view logic.
4. Replace the current title SceneKit dependency with a source-backed native playback path or deterministic baked frames for the title subset.
5. Add input handling for all title exit paths, not just the menu request path.

### Phase 3: Add Menu Handoff Runtime

1. Replace the current semantic `CheckSave` stand-in with extracted BG/window/text assets and exact timing.
2. Add runtime flag plumbing from real save-status data into the `CheckSave` scene router.
3. Replace the current semantic `MainMenu` stand-in with extracted graphics, button borders, arrow sprites, and source-backed scroll behavior.
4. Add runtime flag plumbing from real save data and feature availability into the `MainMenu` router.
5. Reach the first stable interactive menu state without relying on synthetic defaults.
6. Add native handling for menu navigation, confirmation, and overlay dispatch from the first interactive menu state.

### Phase 4: Exact Subsystem Parity

1. Add a native 2D compositor for DS BG, OBJ, window, blend, and text rules used by title, `CheckSave`, and `MainMenu`.
2. Replace SwiftUI prompt/message/menu text drawing with DS-style glyph rendering sourced from the extracted font path.
3. Add a native audio core for the opening/title cue subset so BGM fades, stop timing, and cry timing are source-accurate.
4. Replace parity-critical SceneKit usage with a native 3D subset or deterministic frame baker for the opening/title assets.
5. Finish the scene 4 particle path so the full opening remains exact while the menu work lands.

### Phase 5: Proof Of Parity

1. Add per-frame visual diffing for opening scenes, title states, `CheckSave`, and `MainMenu`.
2. Add audio waveform and trace diffs for title/opening cue playback.
3. Add extracted trace comparisons for title exit mode, `CheckSave` routing, and menu setup state.
4. Add snapshot tests for the committed IR surface:
   - scene order
   - state order
   - title prompt metadata
   - `CheckSave` message routing
   - `MainMenu` option routing
5. Do not call the milestone complete until the native app reaches `MainMenu` with no known visual, timing, or audio regressions against the extracted references.

## Definition Of Done

This milestone is done when the native macOS app can be launched from the repo and:

1. run the HeartGold opening from scene 1 through scene 5
2. enter the title screen and accept title input
3. transition through `CheckSave`
4. display the interactive `MainMenu`
5. pass the parity harness for timing, visuals, and audio across that full path
