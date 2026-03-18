# Native Subsystem Tooling For Exact HGSS Parity

## Goal

Build the native tooling and harness needed to make the macOS implementation visually and sonically indistinguishable from the Nintendo DS version of Pokemon HeartGold during the opening and title flow.

This is not a ROM emulator plan.
This is a native implementation plan with exact source-backed extraction, exact subsystem behavior, and deterministic validation.

## Why The Current Approach Is Not Enough

`pret/pokeheartgold` gives the exact game-side logic, asset references, timings, and state transitions.

It does not by itself provide a drop-in native macOS implementation of:

- the DS 2D compositor
- the DS 3D presentation path
- the Nitro/NNS sound engine
- the exact opening/title scene runtime behavior as reusable Swift code

The current repo can extract and approximate those systems, but exact parity requires stronger native subsystem tooling.

## Required Tooling

### 1. Source Extraction Parser

Purpose: convert upstream C scene logic into a deterministic native intermediate representation without hand-authored timing or guessed offsets.

Current repo state:

- `HGSSExtractCLI` now has a working `clang-c` parser path backed by Homebrew LLVM headers and `libclang`
- the extractor now validates the upstream opening/title sources through that parser before continuing with the existing extraction flow
- the extractor now emits a first `opening_program_ir.json` artifact with source-backed opening scene order plus the initial title-screen state machine and prompt-flash timing
- `HGSSRender` now loads `opening_program_ir.json` and uses it to advance the native title-screen state machine instead of freezing at the first `title_handoff` frame
- local parser-only support headers are generated under `Content/Local/Tooling/pokeheartgold_parse_support/`
- remaining work is expanding that IR from high-level sequencing into per-scene directives, replacing the remaining regex-derived metadata, and extending the path beyond title-screen handoff into `CheckSave` and `MainMenu`

Required tools:

- `clang-c` / `libclang` for C AST parsing
- Homebrew LLVM or another LLVM install that provides `clang-c/Index.h`
- optional `LLVM_PREFIX` override if LLVM is not installed in a standard local prefix
- a repo-local extraction layer that parses:
  - `src/intro_movie.c`
  - `src/intro_movie_scene_1.c` through `src/intro_movie_scene_5.c`
  - `src/title_screen.c`

Required outputs:

- exact scene/state graph
- exact frame timings
- exact BG/window/scroll/fade directives
- exact screen-flip state
- exact title-screen play-state behavior, including the flashing start prompt
- emitted local artifact, currently `opening_program_ir.json`

Why it is needed:

- regex extraction is too fragile
- hand-authored scene metadata is not acceptable for exact parity

### 2. Native 2D Compositor

Purpose: reproduce DS 2D visual behavior exactly in native code.

Required capabilities:

- BG layer priority and visibility
- tilemap composition with correct scroll and wrapping
- OBJ/sprite priority rules
- palette loads and palette fades
- brightness and blend state
- window and viewport masks
- screen flipping behavior
- title prompt flashing behavior

Recommended implementation:

- native Swift or Swift plus a small C helper if fixed-function behavior is easier to express in C
- no SceneKit dependency for 2D composition

Why it is needed:

- exact parity depends on DS compositing rules, not just decoded PNG assets

### 3. Native 3D Playback Or Deterministic 3D Baker

Purpose: reproduce NSBMD/NSBCA/NSBTA/NSBTP/NSBMA-driven title and intro 3D content exactly.

Required capabilities:

- exact model transform playback
- exact animation timing
- exact camera behavior
- exact light state
- exact material and texture animation behavior

Recommended paths:

1. Preferred for parity:
   native 3D playback layer for the exact subset used by the opening and title
2. Acceptable fallback:
   deterministic offline baker that produces exact per-frame native image assets from source-backed model state

Why it is needed:

- SceneKit is useful for iteration but it is not an exact DS renderer
- title handoff parity cannot rely on approximate SceneKit camera/clip/light behavior

### 4. Native SSEQ/SDAT Audio Core

Purpose: reproduce DS sequence playback exactly instead of approximating it in a Python renderer.

Required capabilities:

- exact SSEQ event semantics
- exact tempo and tick progression
- exact channel allocation and priority stealing
- exact tie and portamento behavior
- exact envelope stepping
- exact pitch and timer math
- exact pan and volume behavior
- exact modulation and vibrato behavior
- exact wave playback for the opening/title cue set

Recommended implementation:

- small native C core called from Swift
- extractor may still emit offline WAVs for fast testing, but the core behavior must be exact

Why it is needed:

- the current Python audio path is still an approximation
- exact parity depends on Nitro sound-engine behavior, not just on knowing which cue name to play

### 5. SPL Particle Path

Purpose: reproduce scene 4 particle visuals exactly.

Required capabilities:

- exact emitter lifetime behavior
- exact particle spawn/update semantics for the opening subset
- exact particle transforms and timing

Recommended implementation:

1. preferred:
   native exact subset runtime for the opening particle resources
2. fallback:
   deterministic offline frame baker using exact source-backed particle rules

Why it is needed:

- scene 4 parity depends on more than static timing or placeholder particle sprites

### 6. Validation Harness

Purpose: prove exact parity instead of relying on subjective inspection.

Required outputs:

- per-frame top-screen render output
- per-frame bottom-screen render output
- synchronized audio output for opening/title cues
- frame-by-frame visual diff reports
- waveform and trace diff reports
- extracted scene-state traces

Required comparisons:

- source-extracted expected scene timings vs native runtime timings
- expected visual state vs native rendered frame state
- expected audio sequence state vs native audio state

Recommended local-only storage:

- `Content/Local/Reference/`

Why it is needed:

- exact parity needs measurable proof, not only manual review

## Concrete Tools To Add

### Parser / Extraction

- `libclang`
- `clang-c/Index.h`
- local parser-support generation for:
  - `nitro/fx/fx_const.h`
  - `demo/opening/gs_opening.naix`
  - `demo/title/titledemo.naix`
  - `msgdata/msg.naix`
  - `msgdata/msg/msg_0719.h`
- helper scripts or a small native parser binary for extracting scene logic IR

### Asset Decoding

- `nitrogfx`
- `apicula`
- `ndspy`

These remain useful, but they are not sufficient by themselves for exact parity.

### Native Runtime Support

- small C or C++ helper targets inside the workspace for parity-critical fixed-point behavior
- Swift wrappers around those helpers for app/runtime integration

### Validation

- image diff tool for frame-by-frame comparison
- waveform diff tool for PCM comparison
- trace diff tool for sequence/channel/controller comparison

## Recommended Repository Outputs

### New docs

- `docs/PARITY_HARNESS.md`
- `docs/OPENING_RUNTIME_IR.md`
- `docs/OPENING_MENU_PARITY.md`

### Source modules or targets

- `Sources/HGSSOpeningIR` (now present as the source-backed opening/title translation boundary)
- `Sources/HGSSNative2D`
- `Sources/HGSSNative3D`
- `Sources/HGSSNativeAudio`
- `Sources/HGSSParityHarness`

### New local-only outputs

- `Content/Local/Reference/frames/...`
- `Content/Local/Reference/audio/...`
- `Content/Local/Reference/traces/...`

## Recommended Order

1. Expand AST-to-IR lowering from scene sequencing into per-scene BG/window/scroll/fade directives for `intro_movie_scene_1.c` through `intro_movie_scene_5.c`, replacing the remaining regex-derived metadata.
2. Lower the post-title path into native contracts by modeling `TITLESCREEN_EXIT_MENU`, `gApplication_CheckSave`, and `gApp_MainMenu`.
3. Extract and render the `CheckSave` and `MainMenu` assets so the native app reaches the real opening menu instead of stopping at the title fadeout boundary.
4. Build the native audio core for the opening/title cue set.
5. Replace parity-critical SceneKit usage with native 3D playback or deterministic baked frames.
6. Finish the exact particle path for scene 4.
7. Run the parity harness until visual and audio diffs are eliminated across opening, title, `CheckSave`, and `MainMenu`.

## Immediate Todos

1. Lower `intro_movie_scene_1.c` through `intro_movie_scene_5.c` into concrete IR commands for fades, window masks, scrolls, and scene-local timings.
2. Expand the parser-backed title lowering so `TitleScreen_Exit` and all exit modes are explicit IR rather than partially regex-derived control flow.
3. Replace the semantic `CheckSave` and `MainMenu` stand-ins with extracted assets, real save-flag plumbing, and native menu runtime behavior.
4. Replace the remaining title-screen approximations, especially text glyph rendering and SceneKit-backed title 3D, with exact native outputs.

## Non-Goals

- shipping an emulator inside the app
- depending on emulator runtime for the product
- pretending that DS C code can be mechanically translated into Swift line-by-line

## Summary

To get an exact visual and audio match, the repo needs better native subsystem tooling, not more game-source access.

`pret/pokeheartgold` already provides the game logic and content truth.
The missing work is implementing the DS subsystem behavior natively and validating it with a stronger parity harness.
