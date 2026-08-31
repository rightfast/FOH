# Hardware testing

FOH's automation policy is covered by deterministic tests and a smaller live
hardware matrix. Built-in devices should always be restored before finishing a
test session.

## Automated topology coverage

`FOHTests/AppStateAutomationTests.swift` verifies:

- Disconnecting the active device selects FOH's highest-priority available
  fallback, even when macOS has already assigned a different fallback.
- Reconnecting a higher-priority device restores it when restoration is on.
- Reconnecting a higher-priority device leaves the current device alone when
  restoration is off.
- A manual selection is not overridden when connection topology has not
  changed.
- An input disconnect does not change the selected output.

Run the full suite with:

```sh
xcodegen generate
xcodebuild -project FOH.xcodeproj -scheme FOH -destination 'platform=macOS' test
```

## Live matrix

| Scenario | Result | Notes |
| --- | --- | --- |
| Select virtual output | Pass | Motiv Mix became the default output and system output. |
| Restore built-in output | Pass | MacBook Pro Speakers became both defaults again. |
| Select virtual input | Pass | Motiv Mix became the default input. |
| Restore built-in input | Pass | MacBook Pro Microphone became the default input again. |
| USB/XLR disconnect and reconnect | Pending | Run on the secondary test Mac with the physical interface. |
| Bluetooth disconnect and reconnect | Pending | Run with AirPods or another Bluetooth headset. |
| HDMI disconnect and reconnect | Pending | Run only when changing the KVM display path is convenient. |

For each physical test, place the removable device first, enable **Automatic
fallback**, disconnect it, confirm the next available device and History entry,
then reconnect it and confirm restoration and the second History entry.
