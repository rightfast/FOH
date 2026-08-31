#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/release"
ARCHIVE_PATH="$BUILD_DIR/FOH.xcarchive"
DMG_PATH="$BUILD_DIR/FOH.dmg"
BACKGROUND_PATH="$ROOT_DIR/Design/DMG/FOH-DMG-Background.png"
IDENTITY="Developer ID Application"
ADHOC=false
SKIP_NOTARIZATION=false

usage() {
  echo "Usage: Scripts/build-release.sh [--adhoc] [--skip-notarization]"
  echo ""
  echo "Production environment:"
  echo "  TEAM_ID          Apple Developer team ID"
  echo "  NOTARY_PROFILE   notarytool keychain profile name"
  echo ""
  echo "Use --adhoc only for local packaging tests. It is not distributable."
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --adhoc) ADHOC=true ;;
    --skip-notarization) SKIP_NOTARIZATION=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

for command_name in xcodegen xcodebuild python3 hdiutil shasum; do
  if ! command -v "$command_name" >/dev/null; then
    echo "Missing required tool: $command_name" >&2
    exit 1
  fi
done

if [[ ! -f "$BACKGROUND_PATH" ]]; then
  echo "Missing DMG background: $BACKGROUND_PATH" >&2
  echo "Run Scripts/render-dmg-assets.sh first." >&2
  exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

cd "$ROOT_DIR"
xcodegen generate

archive_args=(
  -project FOH.xcodeproj
  -scheme FOH
  -configuration Release
  -destination "generic/platform=macOS"
  -archivePath "$ARCHIVE_PATH"
  archive
)

if [[ "$ADHOC" == true ]]; then
  xcodebuild "${archive_args[@]}" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=""
else
  : "${TEAM_ID:?Set TEAM_ID to your Apple Developer team ID}"
  if ! security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
    echo "No Developer ID Application certificate is installed." >&2
    echo "Create one in Xcode > Settings > Accounts > Manage Certificates." >&2
    exit 1
  fi
  xcodebuild "${archive_args[@]}" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$IDENTITY" \
    OTHER_CODE_SIGN_FLAGS="--timestamp"
fi

APP_PATH="$ARCHIVE_PATH/Products/Applications/FOH.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Archive did not contain FOH.app" >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

DMGBUILD_VENV="$ROOT_DIR/build/tools/dmgbuild-venv"
DMGBUILD_BIN="$DMGBUILD_VENV/bin/dmgbuild"
if [[ ! -x "$DMGBUILD_BIN" ]]; then
  mkdir -p "$(dirname "$DMGBUILD_VENV")"
  python3 -m venv "$DMGBUILD_VENV"
  "$DMGBUILD_VENV/bin/python" -m pip install --disable-pip-version-check "dmgbuild==1.6.7"
fi

"$DMGBUILD_BIN" \
  -s "$ROOT_DIR/Design/DMG/dmg_settings.py" \
  -D app="$APP_PATH" \
  -D background="$BACKGROUND_PATH" \
  "FOH" "$DMG_PATH"

if [[ "$ADHOC" == false ]]; then
  codesign --force --timestamp --sign "$IDENTITY" "$DMG_PATH"
  codesign --verify --verbose=2 "$DMG_PATH"
fi

if [[ "$ADHOC" == false && "$SKIP_NOTARIZATION" == false ]]; then
  : "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool keychain profile}"
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"
fi

(
  cd "$BUILD_DIR"
  shasum -a 256 "$(basename "$DMG_PATH")" > "$(basename "$DMG_PATH").sha256"
)

echo ""
echo "Built: $DMG_PATH"
echo "SHA-256: $DMG_PATH.sha256"
if [[ "$ADHOC" == true ]]; then
  echo "This ad-hoc build is for local packaging inspection only."
fi
