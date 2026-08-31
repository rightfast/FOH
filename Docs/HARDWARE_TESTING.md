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
