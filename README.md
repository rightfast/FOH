# FOH

FOH is an open-source macOS audio stage manager for everyday work. It keeps the
right microphone and listening device selected as hardware connects, disconnects,
and workplace apps launch.

The first milestone is a sandboxed feasibility build that discovers Core Audio
devices, reports their capabilities, observes hardware/default-device changes,
and changes the system defaults.

## Requirements

- macOS 14 or newer
- Xcode 26 or newer
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Build

```sh
xcodegen generate
xcodebuild -project FOH.xcodeproj -scheme FOH -configuration Debug build
```

## Install

FOH will ship as a signed and notarized DMG with a drag-to-Applications window.
The same release artifact is prepared for a Right Fast Studio Homebrew tap and
an optional checksum-verifying shell installer. See
[`Docs/DISTRIBUTION.md`](Docs/DISTRIBUTION.md) for the release workflow and the
current Developer ID prerequisite.

## Status

FOH is pre-alpha. Its opt-in waveform analyzes microphone levels locally while
FOH is visible. Audio is never recorded, retained, or transmitted.

The current build supports persistent input and output priority lists,
opt-in automatic fallback, optional restoration when a preferred device
reconnects, and a local session activity history explaining every change. A
Application automations can apply preferred or highest-priority available devices
when a supported work app launches. FOH includes visible presets for Zoom Workplace,
Microsoft Teams, Slack, Cisco Webex, Discord, and FaceTime; presets that are not
installed remain visible but disabled. You can also add any installed macOS app with
the application picker. Automated apps should be configured to use “Same as System.”

The opt-in Browser Meetings rule supports Safari and Google Chrome. It watches only
the frontmost browser tab and applies the selected audio devices when its domain
matches Google Meet, Zoom, Microsoft Teams, Riverside, or a custom domain. Full URLs
are processed locally and are never stored or transmitted. macOS asks for Automation
permission the first time FOH needs to inspect a supported browser.
