# Content Schema

`DevContent/Stub/manifest.json` is a bootstrap fixture for content loading.

## Manifest Shape (v1)

```json
{
  "schemaVersion": 1,
  "title": "HGSS Stub Content",
  "build": "0.1.0-stub",
  "maps": [{ "id": "new-bark-town", "displayName": "New Bark Town (Stub)" }],
  "pokemon": [{ "species": "Chikorita", "nationalDex": 152 }],
  "notes": "Checked-in fake data"
}
```

## Purpose

- Validate loader and core boot wiring
- Provide deterministic smoke-test input
- Avoid legal/IP risk by using synthetic data

## Evolution Policy

- Increment `schemaVersion` for breaking changes
- Keep decoders backward-compatible when practical
- Document changes in PR proof-of-work and architecture docs
