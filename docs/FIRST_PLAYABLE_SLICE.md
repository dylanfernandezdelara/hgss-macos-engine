# First Playable Slice (Planning)

This document scopes the first meaningful runtime milestone after bootstrap.

## Proposed Slice

- Boot to a minimal map scene placeholder
- One controllable player entity
- Deterministic movement and collision on a tiny test map
- Basic telemetry around frame/update loop and input events

## Out of Scope

- Battle system
- Audio pipeline
- Scripting engine parity
- Asset-complete rendering

## Ticket Breakdown (Example)

1. Core loop timing and deterministic tick policy
2. Content schema extension for map collision grid
3. App shell input bridge to core commands
4. Minimal renderer placeholder in app shell
5. Smoke tests for movement/collision invariants

## Exit Criteria

- Contributor can run app and move player in stub environment
- CI covers core logic with deterministic tests
- No prohibited assets committed
