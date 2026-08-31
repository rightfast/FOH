# FOH

FOH is an open-source macOS audio stage manager for everyday work. It keeps the
right microphone and listening device selected as hardware connects, disconnects,
and workplace apps launch.

The first milestone is a sandboxed feasibility build that discovers Core Audio
devices, reports their capabilities, observes hardware/default-device changes,
and changes the system defaults.

## Download the preview

**[Download FOH for Mac](https://github.com/rightfast/FOH/releases/download/preview/FOH.dmg)**

The preview DMG is a universal build for both Apple Silicon and Intel Macs, so
there is no device-specific download to choose. Open the DMG and drag FOH into
Applications.

The preview is not yet Developer ID signed or notarized. The first time you open
FOH, macOS will block it because Apple cannot verify the developer:

1. Try to open FOH once, then dismiss the warning.
2. Open **System Settings › Privacy & Security**.
3. Scroll to **Security** and click **Open Anyway** for FOH.
4. Confirm **Open**. macOS remembers that choice for this build.

This is Apple's standard override for an app from an unknown developer; it does
not require a Terminal command or disabling Gatekeeper globally. Preview builds
also include a published `FOH.dmg.sha256` checksum on the release page.

## Install from source

Until FOH has a paid Apple Developer membership and a notarized public release,
the cleanest way to install it is to build it directly on the Mac where you will
use it. A local build does not require disabling Gatekeeper or removing quarantine
attributes.

1. Install [Xcode from the Mac App Store](https://apps.apple.com/app/xcode/id497799835),
   open it once, and allow it to finish installing components.
2. Open Terminal and run:

```sh
git clone https://github.com/rightfast/FOH.git
cd FOH
./Scripts/install-from-source.sh
```

The script checks the Mac and Xcode version, builds a Release configuration with
a local ad-hoc signature, verifies the app, installs it in `/Applications`, and
opens FOH. If `/Applications` is not writable, it uses `~/Applications` and tells
you where it installed the app.

To update later:

```sh
cd FOH
git pull --ff-only
./Scripts/install-from-source.sh
```

Quit FOH before updating it. The locally built app will still request normal macOS
permissions for microphone activity and browser automation when you enable those
features. Those prompts are part of the real app behavior.

## Development requirements

- macOS 14 or newer
- Xcode 26 or newer
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Build

```sh
xcodegen generate
xcodebuild -project FOH.xcodeproj -scheme FOH -configuration Debug build
```

## Public distribution

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
