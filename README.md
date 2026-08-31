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

## Status

FOH is pre-alpha. It does not capture or transmit audio.

