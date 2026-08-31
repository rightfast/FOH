# Hardware testing

FOH's hardware layer should be verified with real connection sequences rather
than device mocks alone. Diagnostic exports intentionally omit raw names, UIDs,
Core Audio object IDs, and event messages.

## Device matrix

- Built-in microphone and speakers
- USB microphone
- XLR audio interface
- Wired headphones
- Bluetooth headphones or earbuds
- HDMI or DisplayPort audio
- Virtual and aggregate devices

## Connection sequences

1. Launch FOH with the device already connected.
2. Connect the device while FOH is running.
3. Disconnect the active default device.
4. Reconnect a previously disconnected device.
5. Change the default through macOS Sound settings.
6. Sleep and wake the Mac with the device connected.
7. Dock and undock the Mac.
8. Connect and disconnect Bluetooth during an active call.
9. Launch and quit Zoom while it is configured to use the system default.

## What to verify

- Stable UID across reconnection
- Correct input/output direction and channel count
- Transport classification
- Nominal sample rate
- Default input and output tracking
- Writable versus read-only volume, gain, and mute
- Event ordering and duplicate suppression
- Failures are visible without interrupting unrelated audio
- Export contains capability data but no raw device identity

## Verified baseline

### 2026-08-30 — Apple Silicon, macOS 26.5.2

- Switched the default output from the built-in endpoint to an HDMI endpoint
  through FOH.
- Independently confirmed the HDMI endpoint through macOS `system_profiler`.
- Restored the built-in endpoint through FOH and independently confirmed it.
- FOH recorded one selection and one observed-default-change event in each
  direction, with no duplicate or error events.
- The input endpoint remained unchanged throughout the output round trip.

## Deferred device validation

USB microphones, XLR interfaces, and Bluetooth/AirPods call-profile behavior
will be tested on the second Mac once FOH has a signed, one-step install build.
Until then, live input activity is intentionally opt-in and only runs while an
FOH window or menu is visible, so opening FOH cannot silently hold a Bluetooth
microphone stream in the background.
