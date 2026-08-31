#!/bin/bash

set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: Scripts/render-cask.sh VERSION SHA256 OUTPUT" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$1"
SHA256="$2"
OUTPUT="$3"

sed \
  -e "s/__VERSION__/$VERSION/g" \
  -e "s/__SHA256__/$SHA256/g" \
  "$ROOT_DIR/Casks/foh.rb.template" > "$OUTPUT"
