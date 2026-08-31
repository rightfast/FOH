# FOH product brief

## Promise

FOH keeps an everyday Mac user's microphone and listening device reliably
configured as hardware connects, disconnects, and workplace apps launch.

## First user

An office worker with a desk microphone and multiple listening devices, such as
AirPods, wired headphones, a display, and the Mac's built-in speakers.

## MVP

- Native menu-bar and main-window experiences
- Current input and output visibility
- One-click default-device switching
- Stable memory of connected and disconnected devices
- Separate input and output priority lists
- Automatic fallback and restoration
- Simple scenes
- Zoom-aware automation
- Output volume and mute when hardware supports them
- Input gain and mute when hardware supports them
- Temporary manual overrides
- Explainable activity history
- Launch at login
- Local-only storage

## Explicitly out of scope for 1.0

- Audio capture or recording
- Virtual audio devices
- Per-application audio interception or mixing
- DSP, EQ, compression, or noise reduction
- Cloud accounts or sync
- iPhone or iPad control

## Product principles

1. Never fight the user. A manual selection pauses or supersedes automation.
2. Explain every change. Users can see what changed and why.
3. Degrade honestly. Controls appear only when hardware supports them.
4. Keep simple behavior simple. Advanced rules use the same underlying model.
5. Keep audio local. FOH manages device metadata and does not capture audio.
