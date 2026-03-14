# Legal and Asset Hygiene

This repository does not distribute Nintendo ROMs or proprietary extracted assets.

## Never Commit

- ROM files (`*.nds`, `*.gba`, etc.)
- Save files (`*.sav`, `*.dsv`, etc.)
- Proprietary extracted assets (textures, scripts, binaries, archives)
- Reverse-engineering intermediate dumps from commercial content
- External private/local clones used for reference extraction

## Allowed to Commit

- Source code
- Documentation
- Tiny synthetic fixtures in `DevContent/Stub`
- Small text fixtures that exercise parser shape without shipping ROMs, binaries, or full extracted asset dumps

## Local-Only Paths

- `Content/Local/`
- `External/`

These are ignored by git and intended for per-developer local work.

## Review Checklist

Before merge confirm:

- No prohibited file types or asset dumps in diff
- `.gitignore` still protects local content paths
- PR proof-of-work includes extraction/tooling behavior without attaching proprietary data
