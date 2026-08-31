#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/SourceInstallDerivedData"
BUILT_APP="$DERIVED_DATA/Build/Products/Release/FOH.app"
INSTALL_ROOT="${FOH_INSTALL_DIR:-/Applications}"
OPEN_AFTER_INSTALL=true

usage() {
  echo "Usage: Scripts/install-from-source.sh [--no-open]"
  echo ""
  echo "Builds FOH locally and installs it in /Applications."
  echo "Set FOH_INSTALL_DIR to choose another Applications directory."
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-open) OPEN_AFTER_INSTALL=false ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "FOH can only be built and installed on macOS." >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null; then
  echo "Xcode is required. Install it from the Mac App Store, open it once, then rerun this command." >&2
  exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Xcode is not ready. Open Xcode once and accept any requested license or component installation." >&2
  exit 1
fi

MACOS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
if (( MACOS_MAJOR < 14 )); then
  echo "FOH requires macOS 14 or newer. This Mac is running macOS $(sw_vers -productVersion)." >&2
  exit 1
fi

if pgrep -x FOH >/dev/null; then
  echo "FOH is currently running. Quit it from the menu bar, then rerun this command." >&2
  exit 1
fi

if [[ ! -w "$INSTALL_ROOT" ]]; then
  INSTALL_ROOT="$HOME/Applications"
  mkdir -p "$INSTALL_ROOT"
  echo "/Applications is not writable; FOH will be installed in $INSTALL_ROOT."
fi

INSTALL_APP="$INSTALL_ROOT/FOH.app"
case "$INSTALL_APP" in
  /Applications/FOH.app|"$HOME"/Applications/FOH.app) ;;
  *)
    if [[ -z "${FOH_INSTALL_DIR:-}" ]]; then
      echo "Refusing unexpected install destination: $INSTALL_APP" >&2
      exit 1
    fi
    ;;
esac

echo "Building FOH locally…"
xcodebuild \
  -project "$ROOT_DIR/FOH.xcodeproj" \
  -scheme FOH \
  -configuration Release \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM="" \
  build

if [[ ! -d "$BUILT_APP" ]]; then
  echo "The build completed without producing FOH.app." >&2
  exit 1
fi

codesign --verify --deep --strict "$BUILT_APP"

echo "Installing FOH in ${INSTALL_ROOT}…"
if [[ -e "$INSTALL_APP" ]]; then
  rm -rf "$INSTALL_APP"
fi
ditto "$BUILT_APP" "$INSTALL_APP"
codesign --verify --deep --strict "$INSTALL_APP"

echo "FOH was built on this Mac and installed at $INSTALL_APP."
if [[ "$OPEN_AFTER_INSTALL" == true ]]; then
  echo "Opening FOH…"
  open "$INSTALL_APP"
fi
