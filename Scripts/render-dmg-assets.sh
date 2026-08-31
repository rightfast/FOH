#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT_DIR/Design/DMG/FOH-DMG-Background.svg"
DESTINATION="$ROOT_DIR/Design/DMG/FOH-DMG-Background.png"
sips --setProperty format png "$SOURCE" --out "$DESTINATION" >/dev/null
echo "Rendered $DESTINATION"
