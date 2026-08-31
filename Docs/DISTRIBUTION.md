# Distribution

FOH's primary direct-download artifact is a Developer ID-signed and Apple-
notarized disk image. The disk image presents FOH beside an Applications folder
shortcut so installation is one drag.

## Trusted preview build

This validates the universal Release archive, DMG artwork, icon placement, and
Applications link. It may be shared with informed testers, but it is not signed
with a Developer ID or notarized by Apple:

```sh
brew install xcodegen
Scripts/render-dmg-assets.sh
Scripts/build-release.sh --adhoc --skip-notarization
```

The artifact is written to `build/release/FOH.dmg`. The manually triggered
`preview.yml` workflow publishes the same ad-hoc artifact to a rolling GitHub
pre-release. Testers must use macOS's per-app **Open Anyway** override on first
launch. Do not present this artifact as a verified public release.

The stable preview download is:

```text
https://github.com/rightfast/FOH/releases/download/preview/FOH.dmg
```

## Production build

Apple requires direct-download apps to use a Developer ID Application
certificate, Hardened Runtime, and notarization. FOH keeps App Sandbox enabled
as an additional constraint.

1. In Xcode, open **Settings > Accounts**, select the Right Fast Studio team,
   open **Manage Certificates**, and create a **Developer ID Application**
   certificate.
2. Create a keychain profile for notarization. App-specific passwords stay in
   Keychain and are never placed in this repository:

   ```sh
   xcrun notarytool store-credentials foh-notary \
     --apple-id "YOUR_APPLE_ID" \
     --team-id "YOUR_TEAM_ID" \
     --password "YOUR_APP_SPECIFIC_PASSWORD"
   ```

3. Build the final artifact:

   ```sh
   TEAM_ID="YOUR_TEAM_ID" NOTARY_PROFILE="foh-notary" Scripts/build-release.sh
   ```

The script archives a universal app, verifies its code signature, builds and
signs the DMG, submits it to Apple's notary service, staples and validates the
ticket, runs Gatekeeper assessment, and writes a SHA-256 checksum.

## GitHub releases

Pushing a version tag such as `v0.1.0` runs `.github/workflows/release.yml`.
Configure these GitHub Actions secrets first:

- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APP_SPECIFIC_PASSWORD`
- `MACOS_CERTIFICATE` — base64-encoded Developer ID `.p12`
- `MACOS_CERTIFICATE_PASSWORD`
- `KEYCHAIN_PASSWORD` — a random password used only for the temporary CI keychain

The workflow publishes `FOH.dmg`, its checksum, the installer script, and a
versioned Homebrew cask.

## Homebrew

Once the first signed GitHub release exists, publish the generated `foh.rb` in
a `rightfast/homebrew-tap` repository. Installation will then be:

```sh
brew install --cask rightfast/tap/foh
```

The cask uses the same notarized DMG and pinned SHA-256 checksum as the GitHub
release. The generated cask should be submitted to Homebrew's main cask
repository only after FOH has stable releases and meets their acceptance rules.

## Shell installer

The release also includes `install.sh`. It downloads the DMG and checksum,
verifies both the checksum and Apple code signature, and installs into
`/Applications` or falls back to `~/Applications` without automatically using
`sudo`.

The readable two-step form is preferred:

```sh
curl -fsSLO https://github.com/rightfast/FOH/releases/latest/download/install.sh
less install.sh
bash install.sh
```

For users who explicitly accept the tradeoff of executing a remote script:

```sh
curl -fsSL https://github.com/rightfast/FOH/releases/latest/download/install.sh | bash
```
