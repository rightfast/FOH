# Architecture

FOH is a SwiftUI macOS application backed by public Core Audio hardware APIs.

## Current layers

- `Models`: stable, UI-independent descriptions of hardware and capabilities
- `Services`: Core Audio discovery, observation, property access, and mutation
- `App`: main-actor application state and event debouncing
- `Views`: menu-bar, Stage window, device rows, and settings

Core Audio object IDs are transient runtime handles. Persistent features must
key devices by Core Audio UID plus direction.

## Next layers

- `Persistence`: remembered devices, preferences, scenes, and schema migrations
- `Automation`: triggers, conditions, conflict resolution, actions, and overrides
- `Diagnostics`: decisions, Core Audio errors, and privacy-safe support exports

The automation engine must remain independent of Core Audio so recorded event
sequences can be evaluated deterministically in tests.
