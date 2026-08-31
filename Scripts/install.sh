#!/bin/bash

set -euo pipefail

REPOSITORY="rightfast/FOH"
RELEASE_BASE="https://github.com/$REPOSITORY/releases/latest/download"
INSTALL_DIR="${FOH_INSTALL_DIR:-/Applications}"
TEMP_DIR="$(mktemp -d)"
MOUNT_POINT=""

cleanup() {
  if [[ -n "$MOUNT_POINT" ]]; then
    hdiutil detach "$MOUNT_POINT" -quiet || true
  fi
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

if [[ ! -w "$INSTALL_DIR" ]]; then
  INSTALL_DIR="$HOME/Applications"
  mkdir -p "$INSTALL_DIR"
fi

echo "Downloading FOH…"
curl --fail --location --silent --show-error "$RELEASE_BASE/FOH.dmg" -o "$TEMP_DIR/FOH.dmg"
curl --fail --location --silent --show-error "$RELEASE_BASE/FOH.dmg.sha256" -o "$TEMP_DIR/FOH.dmg.sha256"

(
  cd "$TEMP_DIR"
  shasum -a 256 -c FOH.dmg.sha256
)

MOUNT_POINT="$(hdiutil attach "$TEMP_DIR/FOH.dmg" -nobrowse -readonly | awk '/\/Volumes\// {sub(/^.*\/Volumes\//, "/Volumes/"); print; exit}')"
if [[ -z "$MOUNT_POINT" || ! -d "$MOUNT_POINT/FOH.app" ]]; then
  echo "Could not mount the FOH disk image." >&2
  exit 1
fi

rm -rf "$INSTALL_DIR/FOH.app"
ditto "$MOUNT_POINT/FOH.app" "$INSTALL_DIR/FOH.app"
codesign --verify --deep --strict "$INSTALL_DIR/FOH.app"
spctl --assess --type execute --verbose=2 "$INSTALL_DIR/FOH.app"

echo "FOH is installed in $INSTALL_DIR."
echo "Open it once from Applications, then keep FOH in your menu bar."
